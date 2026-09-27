(* L19 — models wiring (docs/issues/drive/01-drive.md, milestone 5).

   drive-e7oi drive-yqxg: the config's models section becomes one service: a single
   {!Eta_http.Client.t} created with TLS on the service's switch, the System One client
   pinned to the configured model and endpoint, and the production Decide the drive runs.
   eta-next's clients own the retry policy, the bounds and the typed failures; this module
   owns the configuration, the request shaping and the one mapping from an
   {!Eta_ai.Error.t} to the protocol's [model-unavailable]. *)

module P = Protocol
module J = Jev_request

type t = {
  config : Config.models;
  logger : Eta_observability.Logger.t;
  http : Eta_http.Client.t;
      (** One client for every endpoint: the System One client and L22's chat client, so
          the service owns one transport and one TLS configuration. *)
  systemone : Eta_ai_systemone.Client.t option;
      (** [None] without a key: {!decide} refuses before anything is sent. *)
  chat : Eta_ai_chat.t option;
      (** The text helper's chat client, [None] for the same missing key; {!text_helper}
          is the helper a drive takes over it. *)
}

(* drive-yqxg: the chat route is the configured base URL plus the OpenAI-compatible path,
   with the base's trailing slash trimmed as the reference's [.rstrip("/")] does. *)
let chat_endpoint (config : Config.models) =
  let base = Config.Text.to_string config.chat_base_url in
  let rec trim at = if at > 0 && base.[at - 1] = '/' then trim (at - 1) else at in
  String.sub base 0 (trim (String.length base)) ^ "/chat/completions"

let create ~sw ~net ~clock ~logger (config : Config.models) =
  let http = Eta_http.Client.create ~sw ~net ~clock ~tls:(Eta_http.Client.tls ()) () in
  let with_key f = Option.map f config.api_key in
  let systemone =
    with_key (fun api_key ->
        Eta_ai_systemone.Client.create ~http ~clock ~logger
          ~endpoint:(Config.Text.to_string config.systemone_endpoint)
          ~api_key
          ~model:(Config.Text.to_string config.jev_model)
          ())
  in
  (* L22: the chat client is pure and synchronous — no socket, nothing to release — so it
     is built beside the System One client and shared by every drive's helper. *)
  let chat =
    with_key (fun api_key ->
        Eta_ai_chat.create ~http ~clock ~logger ~endpoint:(chat_endpoint config) ~api_key
          ())
  in
  { config; logger; http; systemone; chat }

(* drive-e7oi: the model id is what the client sends and checks the reply against, and the
   two endpoints are the configured ones. Nothing here reads the key. *)
let status (t : t) : P.models_status =
  P.
    {
      configured = Option.is_some t.config.api_key;
      jev_model = Config.Text.to_string t.config.jev_model;
      text_model = Config.Text.to_string t.config.text_model;
      systemone_endpoint = Config.Text.to_string t.config.systemone_endpoint;
      chat_base_url = Config.Text.to_string t.config.chat_base_url;
    }

(* drive-kh2u drive-ls3c: every provider failure, System One's and the chat text
   helper's alike, is {!Model_error}'s one mapping into the protocol's
   [model-unavailable]; this is the one code left that no provider produces — a request
   that did not shape in this tree. *)
let error_code name =
  match P.Error_code.of_string name with Ok code -> code | Error _ -> assert false

(* {!Jev_request.body} writes the two members eta-next's client takes apart again: the
   state it posts untouched and the named questions it re-encodes, each read back
   fail-closed. Both are built here, so a failure is a defect in this tree, not a provider
   failure: it is [internal], and the drive reports it as one. *)
let parts body =
  let member key =
    match body with `Assoc fields -> List.assoc_opt key fields | _ -> None
  in
  match (member "state", member "questions") with
  | Some state, Some (`Assoc questions) ->
      let rec read acc = function
        | [] -> Ok (List.rev acc)
        | (name, json) :: rest -> (
            match Eta_ai_systemone.Codecs.t_of_question json with
            | Ok question -> read ((name, question) :: acc) rest
            | Error why -> Error (Printf.sprintf "questions.%s: %s" name why))
      in
      Result.map (fun questions -> (state, questions)) (read [] questions)
  | _ -> Error "the drive request has no state or questions"

(* drive-7tvn: the provider's own accounting, at info so the operator sees it at the
   default level — eta's clients log the same call at debug. Written for every answered
   call, before the answers are validated, because the tokens were spent either way. *)
let log_usage logger (response : Eta_ai_systemone.Codecs.response) =
  let Eta_ai_systemone.Types.{ input_tokens; output_tokens; cost } =
    response.Eta_ai_systemone.Codecs.usage
  in
  Eta_observability.Logger.info logger
    ~fields:
      [
        ("model", Eta_observability.Logger.String response.Eta_ai_systemone.Codecs.model);
        ("input_tokens", Eta_observability.Logger.Int input_tokens);
        ("output_tokens", Eta_observability.Logger.Int output_tokens);
        ("cost", Eta_observability.Logger.Float cost);
      ]
    "systemone usage"

let default_deadline = Eta.Duration.seconds 30

let decide ?(deadline = default_deadline) (t : t) (request : J.request) =
  match t.systemone with
  | None ->
      Error
        (Model_error.unavailable ~code:"missing-key"
           "no OpenRouter API key: set OPENROUTER_API_KEY or models.api_key")
  | Some client -> (
      match parts (J.body request) with
      | Error why ->
          Error
            P.
              {
                code = error_code "internal";
                message = "the System One request did not shape: " ^ why;
                detail = None;
              }
      | Ok (state, questions) -> (
          match Eta_ai_systemone.Client.evaluate client ~deadline ~state ~questions with
          | Error error -> Error (Model_error.of_eta error)
          | Ok response -> (
              log_usage t.logger response;
              (* The reply's answers object is what {!Jev_request.decide} reads; the
                 client decoded the envelope, the model check included. *)
              let answers =
                `Assoc
                  (List.map
                     (fun (name, answer) ->
                       (name, Eta_ai_systemone.Codecs.yojson_of_answer answer))
                     response.Eta_ai_systemone.Codecs.answers)
              in
              match J.decide request ~answers with
              | Ok decision -> Ok decision
              | Error why -> Error (Model_error.unavailable ~code:"invalid-response" why))
          ))

(* drive-ls3c: a fresh helper per call. The helper carries the one-entry memo the
   stale-page reuse rule needs, so it must not outlive the drive it serves; without a key
   there is no chat client and every call refuses before anything is sent. *)
let text_helper (t : t) : Text_helper.t =
  match t.chat with
  | None -> Text_helper.missing_key
  | Some client ->
      Text_helper.create ~client
        ~model:(Config.Text.to_string t.config.text_model)
        ~logger:t.logger ()
