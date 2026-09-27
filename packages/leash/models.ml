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
  http : Eta_http.Client.t;
      (** One client for every endpoint: the System One client today, the chat client of
          L22 next, so the service owns one transport and one TLS configuration. *)
  systemone : Eta_ai_systemone.Client.t option;
      (** [None] without a key: {!decide} refuses before anything is sent. *)
}

let create ~sw ~net ~clock ~logger (config : Config.models) =
  let http = Eta_http.Client.create ~sw ~net ~clock ~tls:(Eta_http.Client.tls ()) () in
  let systemone =
    Option.map
      (fun api_key ->
        Eta_ai_systemone.Client.create ~http ~clock ~logger
          ~endpoint:(Config.Text.to_string config.systemone_endpoint)
          ~api_key
          ~model:(Config.Text.to_string config.jev_model)
          ())
      config.api_key
  in
  { config; http; systemone }

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

let error_code name =
  match P.Error_code.of_string name with Ok code -> code | Error _ -> assert false

let model_unavailable ?(code = "unavailable") message =
  P.
    {
      code = error_code "model-unavailable";
      message;
      detail = Some (`Assoc [ ("code", `String code) ]);
    }

(* The six typed failures of {!Eta_ai.Error.t}, as [detail.code] (docs/protocol.md): a
   caller reads the provider's kind without parsing the sentence. *)
let provider_code (error : Eta_ai.Error.t) =
  match error with
  | `Unavailable _ -> "unavailable"
  | `Timeout -> "timeout"
  | `Authentication _ -> "authentication"
  | `Invalid_response _ -> "invalid-response"
  | `Input_too_large _ -> "input-too-large"
  | `Model_mismatch _ -> "model-mismatch"

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

let default_deadline = Eta.Duration.seconds 30

let decide ?(deadline = default_deadline) (t : t) (request : J.request) =
  match t.systemone with
  | None ->
      Error
        (model_unavailable ~code:"missing-key"
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
          | Error error ->
              Error
                (model_unavailable ~code:(provider_code error)
                   (Eta_ai.Error.to_string error))
          | Ok response -> (
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
              | Error why -> Error (model_unavailable ~code:"invalid-response" why))))

let text_helper (_ : t) : Text_helper.t = Text_helper.unavailable
