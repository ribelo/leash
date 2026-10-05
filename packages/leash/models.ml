(* L19 — models wiring (docs/issues/drive/01-drive.md, milestone 5).

   drive-e7oi drive-yqxg: the config's models section becomes one service: a single
   {!Ox_http.Client.t} created with TLS on the service's switch, the System One client
   pinned to the configured model and endpoint, and the production Decide the drive runs.
   ox's clients own the retry policy, the bounds and the typed failures; this module
   owns the configuration, the request shaping and the one mapping from an
   {!Ox_ai.Error.t} to the protocol's [model-unavailable]. *)

module P = Protocol
module J = Jev_request

type t = {
  now : unit -> float;
  config : Config.models;
  logger : Ox_observability.Logger.t;
  http : Ox_http.Client.t;
      (** One client for every endpoint: the System One client and L22's chat client, so
          the service owns one transport and one TLS configuration. *)
  systemone : Ox_ai_systemone.Client.t option;
      (** [None] without a key: {!decide} refuses before anything is sent. *)
  chat : Ox_ai_chat.t option;
      (** The text helper's chat client, [None] for the same missing key; {!text_helper}
          is the helper a drive takes over it. *)
  planner_chat : Ox_ai_chat.t option;
      (** L32 run-d99l: the planner's chat client. Same key, same transport, and the same
          route as [chat] unless [models.planner_endpoint] names another one, so the
          fallback's model, endpoint and reasoning are all the operator's to change. *)
  mutable modalities : string list;
      (** dmod-m3q5: the decision model's input modalities, read once by {!start}; empty
          until then or when the listing could not be read. *)
  mutable tail_read : bool option;
      (** dmod-pjmy: whether the start-up probe's tail was read; [None] until probed. *)
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
  let http = Ox_http.Client.create ~sw ~net ~clock ~tls:(Ox_http.Client.tls ()) () in
  let with_key f = Option.map f config.api_key in
  let systemone =
    with_key (fun api_key ->
        Ox_ai_systemone.Client.create ~http ~clock ~logger
          ~endpoint:(Config.Text.to_string config.systemone_endpoint)
          ~api_key
          ~model:(Config.Text.to_string config.decision_model)
          ~timeout:(Ox.Duration.seconds (Config.Seconds.to_int config.decision_timeout))
          ())
  in
  (* L22: the chat client is pure and synchronous — no socket, nothing to release — so it
     is built beside the System One client and shared by every drive's helper. *)
  let chat =
    with_key (fun api_key ->
        Ox_ai_chat.create ~http ~clock ~logger ~endpoint:(chat_endpoint config) ~api_key
          ~timeout:(Ox.Duration.seconds (Config.Seconds.to_int config.text_timeout))
          ())
  in
  let planner_chat =
    with_key (fun api_key ->
        (* pic-k4ij: the request bound admits one 4 MiB PNG as a base64 image part. *)
        Ox_ai_chat.create ~http ~clock ~logger ~endpoint:(planner_endpoint config)
          ~api_key
          ~timeout:(Ox.Duration.seconds (Config.Seconds.to_int config.planner_timeout))
          ~max_request_bytes:(8 * 1024 * 1024)
          ())
  in
  {
    now = (fun () -> Eio.Time.now clock);
    config;
    logger;
    http;
    systemone;
    chat;
    planner_chat;
    modalities = [];
    tail_read = None;
  }

(* drive-e7oi: the model id is what the client sends and checks the reply against, and the
   two endpoints are the configured ones. Nothing here reads the key. *)
let status (t : t) : P.models_status =
  P.
    {
      configured = Option.is_some t.config.api_key;
      decision_model = Config.Text.to_string t.config.decision_model;
      text_model = Config.Text.to_string t.config.text_model;
      systemone_endpoint = Config.Text.to_string t.config.systemone_endpoint;
      chat_base_url = Config.Text.to_string t.config.chat_base_url;
      decision_modalities = t.modalities;
      decision_tail_read = t.tail_read;
    }

(* drive-kh2u drive-ls3c: every provider failure, System One's and the chat text
   helper's alike, is {!Model_error}'s one mapping into the protocol's
   [model-unavailable]; this is the one code left that no provider produces — a request
   that did not shape in this tree. *)
let error_code name =
  match P.Error_code.of_string name with Ok code -> code | Error _ -> assert false

(* {!Jev_request.body} writes the two members ox's client takes apart again: the
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
            match Ox_ai_systemone.Codecs.t_of_question json with
            | Ok question -> read ((name, question) :: acc) rest
            | Error why -> Error (Printf.sprintf "questions.%s: %s" name why))
      in
      Result.map (fun questions -> (state, questions)) (read [] questions)
  | _ -> Error "the drive request has no state or questions"

(* drive-7tvn: the provider's own accounting, at info so the operator sees it at the
   default level — ox's clients log the same call at debug. Written for every answered
   call, before the answers are validated, because the tokens were spent either way. *)
let log_usage logger (response : Ox_ai_systemone.Codecs.response) =
  let Ox_ai_systemone.Types.{ input_tokens; output_tokens; cost } =
    response.Ox_ai_systemone.Codecs.usage
  in
  Ox_observability.Logger.info logger
    ~fields:
      [
        ("model", Ox_observability.Logger.String response.Ox_ai_systemone.Codecs.model);
        ("input_tokens", Ox_observability.Logger.Int input_tokens);
        ("output_tokens", Ox_observability.Logger.Int output_tokens);
        ("cost", Ox_observability.Logger.Float cost);
      ]
    "systemone usage"

let default_deadline = Ox.Duration.seconds 30

let decide_once ?(deadline = default_deadline) ?(on_usage = fun _ -> ()) (t : t)
    (request : J.request) =
  match t.systemone with
  | None ->
      Error
        (Model_error.unavailable ~code:"missing-key"
           "no OpenRouter API key: set OPENROUTER_API_KEY or models.api_key")
  | Some client -> (
      match parts (J.body request) with
      | Error why ->
          Error
            (P.make_error (error_code "internal")
               ~message:("the System One request did not shape: " ^ why))
      | Ok (state, questions) -> (
          Model_usage.start "operator";
          match Ox_ai_systemone.Client.evaluate client ~deadline ~state ~questions with
          | Error error -> Error (Model_error.of_eta ~kind:"jev" error)
          | Ok response -> (
              log_usage t.logger response;
              let usage = response.Ox_ai_systemone.Codecs.usage in
              on_usage
                (`Assoc
                   [
                     ("input_tokens", `Int usage.input_tokens);
                     ("output_tokens", `Int usage.output_tokens);
                     ("cost", `Float usage.cost);
                     ("retries", `Int 0);
                   ]);
              Model_usage.report "operator"
                (Some response.Ox_ai_systemone.Codecs.usage.cost);
              (* The reply's answers object is what {!Jev_request.decide} reads; the
                 client decoded the envelope, the model check included. *)
              let answers =
                `Assoc
                  (List.map
                     (fun (name, answer) ->
                       (name, Ox_ai_systemone.Codecs.yojson_of_answer answer))
                     response.Ox_ai_systemone.Codecs.answers)
              in
              match J.decide request ~answers with
              | Ok decision -> Ok decision
              | Error why -> Error (Model_error.unavailable ~code:"invalid-response" why))
          ))

(* map-op07: retry malformed replies once within the original deadline.
   This repeats only a model request, never browser input. *)
let retry_invalid t ~deadline call =
  let started = t.now () in
  match call deadline with
  | Error ({ P.detail = Some (`Assoc fields); _ } as error)
    when List.assoc_opt "code" fields = Some (`String "invalid-response") ->
      let remaining = Ox.Duration.to_seconds_float deadline -. (t.now () -. started) in
      if remaining <= 0. then Error error
      else call (Ox.Duration.ms (max 1 (int_of_float (remaining *. 1000.))))
  | answer -> answer

let decide ?(deadline = default_deadline) ?on_usage t request =
  retry_invalid t ~deadline (fun deadline -> decide_once ~deadline ?on_usage t request)

(* drive-ls3c: a fresh helper per call. The helper carries the one-entry memo the
   stale-page reuse rule needs, so it must not outlive the drive it serves; without a key
   there is no chat client and every call refuses before anything is sent. *)
let text_helper ?on_usage (t : t) : Text_helper.t =
  match t.chat with
  | None -> Text_helper.missing_key
  | Some client ->
      let helper =
        Text_helper.create ?on_usage ~client ~now:t.now
          ~model:(Config.Text.to_string t.config.text_model)
          ~logger:t.logger ()
      in
      {
        Text_helper.complete =
          (fun ?deadline context ->
            Result.map_error
              (Model_error.with_kind "text")
              (helper.complete ?deadline context));
      }

(* ---------- L31: the run's upper levels ---------- *)

(* run-7blx run-vj48: every level's answer is validated where the drive's is: the chosen
   key must be one of the offered criteria, and the distribution must be the reference's
   own valid one. The probabilities travel to the trace as the object the model answered. *)
let wire_probabilities probabilities =
  `Assoc (List.map (fun (key, value) -> (key, `Float value)) probabilities)

let usage_of (usage : Ox_ai_systemone.Types.usage) : P.run_usage =
  P.
    {
      input_tokens = usage.Ox_ai_systemone.Types.input_tokens;
      output_tokens = usage.Ox_ai_systemone.Types.output_tokens;
      cost = usage.Ox_ai_systemone.Types.cost;
    }

let invalid_response message = Model_error.unavailable ~code:"invalid-response" message

let missing_key =
  Model_error.unavailable ~code:"missing-key"
    "no OpenRouter API key: set OPENROUTER_API_KEY or models.api_key"

(* run-7blx run-w7ke run-d99l: the one seam a run's upper levels use. The planner turn is
   L32's Luna over the second chat client (run-d99l), with the configured model and
   reasoning; without a key there is no client and the turn refuses before anything is
   sent, as the two choice levels do. *)
let levels (t : t) : Run.levels =
  Run.
    {
      plan =
        (fun ~deadline request ->
          match (t.planner_chat, t.config.planner_model) with
          | None, _ -> Error missing_key
          | _, None ->
              Error
                (Model_error.unavailable ~code:"no-planner"
                   "no [models] planner_model is configured; the planner is never called")
          | Some client, Some model ->
              let planner =
                Planner.create ~client ~now:t.now ~model:(Config.Text.to_string model)
                  ~reasoning:(Config.Text.to_string t.config.planner_reasoning)
                  ~logger:t.logger ()
              in
              Result.map_error
                (Model_error.with_kind "planner")
                (planner.Planner.plan ~deadline request));
    }

let accepts_images t = List.mem "image" t.modalities

let trimmed base =
  let rec trim at = if at > 0 && base.[at - 1] = '/' then trim (at - 1) else at in
  String.sub base 0 (trim (String.length base))

(* dmod-m3q5: OpenRouter's per-model listing; its [architecture.input_modalities] is what
   the model accepts. Read once; a failure leaves the model text-only. *)
let read_modalities t =
  match t.config.api_key with
  | None -> Error "no API key"
  | Some api_key -> (
      let url =
        trimmed (Config.Text.to_string t.config.chat_base_url)
        ^ "/models/"
        ^ Config.Text.to_string t.config.decision_model
        ^ "/endpoints"
      in
      match
        Ox_http.Client.request t.http ~method_:"GET" ~url
          ~headers:(Ox_ai.Bearer.header ~api_key)
          ~deadline:(Ox.Duration.seconds 15) ()
      with
      | Error _ -> Error "the model listing did not answer"
      | Ok { status; body = `Read body; _ } when status = 200 -> (
          match Yojson.Safe.from_string (Bytes.to_string body) with
          | exception Yojson.Json_error why -> Error why
          | json -> (
              let open Yojson.Safe.Util in
              match
                json |> member "data" |> member "architecture"
                |> member "input_modalities"
              with
              | `List items ->
                  Ok (List.filter_map (function `String s -> Some s | _ -> None) items)
              | _ -> Error "the listing has no input_modalities"))
      | Ok { status; _ } -> Error (Printf.sprintf "the model listing answered %d" status))

(* dmod-pjmy: one call whose answer depends on the state's last sentence, after about
   3,000 tokens of filler; a model that reads only the first ~2K tokens cannot see it. *)
let probe_tail ?(deadline = Ox.Duration.seconds 30) t =
  match t.systemone with
  | None -> Error "no API key"
  | Some client -> (
      let filler =
        String.concat " "
          (List.init 300 (fun i ->
               Printf.sprintf "Line %d of the filler names no colour at all." (i + 1)))
      in
      let state = `String (filler ^ " " ^ Questions.probe_tail) in
      let question =
        Ox_ai_systemone.Codecs.Choice_question
          Ox_ai_systemone.Types.
            {
              instructions = `String Questions.probe_question;
              criteria =
                List.map (fun (key, text) -> (key, `String text)) Questions.probe_criteria;
            }
      in
      match
        Ox_ai_systemone.Client.evaluate client ~deadline ~state
          ~questions:[ ("colour", question) ]
      with
      | Error _ -> Error "the probe call failed"
      | Ok response -> (
          log_usage t.logger response;
          match Ox_ai_systemone.Client.answer "colour" response with
          | Some (Ox_ai_systemone.Codecs.Choice { choice; _ }) -> Ok (choice = "green")
          | _ -> Error "the probe has no colour answer"))

(* dmod-m3q5 dmod-pjmy: once per service, on its own fiber: the modalities, then the
   probe, each logged once. Nothing waits on it; until it finishes the model is text-only. *)
let start ~sw t =
  Eio.Fiber.fork ~sw (fun () ->
      (match read_modalities t with
      | Ok modalities -> t.modalities <- modalities
      | Error why ->
          Ox_observability.Logger.warn t.logger
            ("decision model modalities unknown: " ^ why));
      (match probe_tail t with
      | Ok read -> t.tail_read <- Some read
      | Error why ->
          Ox_observability.Logger.warn t.logger
            ("decision model tail probe failed: " ^ why));
      Ox_observability.Logger.info t.logger
        ~fields:
          [
            ( "model",
              Ox_observability.Logger.String
                (Config.Text.to_string t.config.decision_model) );
            ("modalities", Ox_observability.Logger.String (String.concat "," t.modalities));
            ( "tail_read",
              Ox_observability.Logger.String
                (match t.tail_read with Some b -> string_of_bool b | None -> "unknown") );
          ]
        "decision model")
