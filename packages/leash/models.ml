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
  planner_chat : Eta_ai_chat.t option;
      (** L32 run-d99l: the planner's chat client. Same key, same transport, and the same
          route as [chat] unless [models.planner_endpoint] names another one, so the
          fallback's model, endpoint and reasoning are all the operator's to change. *)
}

(* drive-yqxg: the chat route is the configured base URL plus the OpenAI-compatible path,
   with the base's trailing slash trimmed as the reference's [.rstrip("/")] does. *)
let chat_endpoint (config : Config.models) =
  let base = Config.Text.to_string config.chat_base_url in
  let rec trim at = if at > 0 && base.[at - 1] = '/' then trim (at - 1) else at in
  String.sub base 0 (trim (String.length base)) ^ "/chat/completions"

(* run-d99l: the planner's route — the configured endpoint when the operator set one, and
   otherwise the chat route the text helper uses. *)
let planner_endpoint (config : Config.models) =
  match config.planner_endpoint with
  | Some endpoint -> Config.Text.to_string endpoint
  | None -> chat_endpoint config

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
  let planner_chat =
    with_key (fun api_key ->
        Eta_ai_chat.create ~http ~clock ~logger ~endpoint:(planner_endpoint config)
          ~api_key ())
  in
  { config; logger; http; systemone; chat; planner_chat }

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

(* ---------- L31: the run's upper levels ---------- *)

(* run-7blx run-vj48: every level's answer is validated where the drive's is: the chosen
   key must be one of the offered criteria, and the distribution must be the reference's
   own valid one. The probabilities travel to the trace as the object the model answered. *)
let wire_probabilities probabilities =
  `Assoc (List.map (fun (key, value) -> (key, `Float value)) probabilities)

let usage_of (usage : Eta_ai_systemone.Types.usage) : P.run_usage =
  P.
    {
      input_tokens = usage.Eta_ai_systemone.Types.input_tokens;
      output_tokens = usage.Eta_ai_systemone.Types.output_tokens;
      cost = usage.Eta_ai_systemone.Types.cost;
    }

let invalid_response message = Model_error.unavailable ~code:"invalid-response" message

let missing_key =
  Model_error.unavailable ~code:"missing-key"
    "no OpenRouter API key: set OPENROUTER_API_KEY or models.api_key"

(* run-qq3o run-kli0: one choice question of the two upper levels, through the same System
   One client the operator level's questions go through. A criterion the model did not
   offer, or a distribution the reference validator refuses, is [model-unavailable] with
   [invalid-response]: the loop does nothing with an answer like that. *)
let choose ?(deadline = default_deadline) (t : t) (question : Run.question) =
  match t.systemone with
  | None -> Error missing_key
  | Some client -> (
      let criteria =
        List.map
          (fun (key, description) -> (key, `String description))
          question.Run.criteria
      in
      let wire =
        Eta_ai_systemone.Codecs.choice ~instructions:(`String question.Run.instructions)
          ~criteria
      in
      match
        Eta_ai_systemone.Client.evaluate client ~deadline ~state:question.Run.state
          ~questions:[ (question.Run.name, wire) ]
      with
      | Error error -> Error (Model_error.of_eta error)
      | Ok response -> (
          log_usage t.logger response;
          match Eta_ai_systemone.Client.answer question.Run.name response with
          | Some (Eta_ai_systemone.Codecs.Choice answer) ->
              let chosen = answer.Eta_ai_systemone.Types.choice in
              if not (List.mem_assoc chosen question.Run.criteria) then
                Error
                  (invalid_response
                     (Printf.sprintf "the answer %S is not one of the offered criteria"
                        chosen))
              else if not (Eta_ai_systemone.Codecs.choice_answer_valid answer) then
                Error
                  (invalid_response
                     (Printf.sprintf "the distribution behind %S is not a valid choice"
                        chosen))
              else
                Ok
                  Run.
                    {
                      key = chosen;
                      probabilities =
                        wire_probabilities answer.Eta_ai_systemone.Types.probabilities;
                      confidence = answer.Eta_ai_systemone.Types.confidence;
                      usage = Some (usage_of response.Eta_ai_systemone.Codecs.usage);
                    }
          | _ ->
              Error
                (invalid_response
                   (Printf.sprintf "the reply carries no choice answer named %S"
                      question.Run.name))))

(* run-vbys: the score question a judgment expectation asks, over the page summary the
   registry builds. Its two levels make the answer's position the [0, 1] score the wait's
   threshold compares. *)
let score ?(deadline = default_deadline) (t : t) ~sentence ~state =
  match t.systemone with
  | None -> Error missing_key
  | Some client -> (
      let wire =
        Eta_ai_systemone.Codecs.score
          ~instructions:(`String (Questions.score sentence))
          ~criteria:Questions.score_levels
      in
      match
        Eta_ai_systemone.Client.evaluate client ~deadline ~state
          ~questions:[ ("score", wire) ]
      with
      | Error error -> Error (Model_error.of_eta error)
      | Ok response -> (
          log_usage t.logger response;
          match Eta_ai_systemone.Client.answer "score" response with
          | Some (Eta_ai_systemone.Codecs.Score answer) ->
              let value = answer.Eta_ai_systemone.Types.score in
              if Float.is_finite value && value >= 0. && value <= 1. then Ok value
              else
                Error
                  (invalid_response
                     (Printf.sprintf "the score %g is not inside 0..1" value))
          | _ -> Error (invalid_response "the reply carries no score answer")))

(* run-7blx run-w7ke run-d99l: the one seam a run's upper levels use. The planner turn is
   L32's Luna over the second chat client (run-d99l), with the configured model and
   reasoning; without a key there is no client and the turn refuses before anything is
   sent, as the two choice levels do. *)
let levels (t : t) : Run.levels =
  Run.
    {
      choose = (fun ~deadline question -> choose ~deadline t question);
      score = (fun ~deadline ~sentence ~state -> score ~deadline t ~sentence ~state);
      plan =
        (fun ~deadline request ->
          match t.planner_chat with
          | None -> Error missing_key
          | Some client ->
              let planner =
                Planner.create ~client
                  ~model:(Config.Text.to_string t.config.planner_model)
                  ~reasoning:(Config.Text.to_string t.config.planner_reasoning)
                  ~logger:t.logger ()
              in
              planner.Planner.plan ~deadline request);
    }
