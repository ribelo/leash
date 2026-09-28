(* L32 — the planner turn (docs/issues/run/01-run.md, milestone 7; run-w7ke run-rq6i
   run-2tt3 run-obtt run-d99l).

   One turn of the level above JEV, over the chat client the models service owns: the
   system message is Questions.planner, the user message is the request as JSON, the reply
   is decoded into the three answers of story 29 fail-closed, and a refusal is shown back
   once so the second answer can correct it (the L32 decisions record). The run caps the
   turns; this module only makes one of them as safe as it can be. *)

module P = Protocol

(* run-rq6i: the three answers, exactly one per reply. The wire words are the protocol's
   own (a planner turn's [answer] in the run's trace); the constructors carry a suffix so
   they never shadow the loop's own answers. *)
type kind =
  | Procedure_answer [@json.name "procedure"]
  | Handoff_answer [@json.name "handoff"]
  | Fail_answer [@json.name "fail"]
[@@deriving yojson]

(* The decoded reply, fail-closed: a member this type does not name is refused by the
   deriver rather than dropped, and every member it does name is optional here because
   which ones are required depends on the answer. *)
type reply = {
  answer : kind;
  procedure : Playbook.procedure option;
  reason : string option;
  expect : string list option;
  pages : Playbook.page list option;
}
[@@deriving yojson]

type t = {
  plan : ?deadline:Eta.Duration.t -> Run.plan_request -> (Run.plan_reply, P.error) result;
}

let default_deadline = Eta.Duration.seconds 30

(* The reply holds a whole procedure: its steps, their goals and its expectations. The
   text helper's 1024 is a value; this is a plan. *)
let max_tokens = 4096

(* The same page bound and character-boundary rule the text helper applies to the text it
   sends (drive-ls3c): a page is data, and a prompt is not the place to send 12 KiB of it. *)
let page_bytes = 6000

let bounded limit text =
  if String.length text <= limit then text
  else begin
    let at = ref limit in
    while !at > 0 && Char.code text.[!at] land 0xc0 = 0x80 do
      decr at
    done;
    String.sub text 0 !at
  end

let trim = String.trim

(* run-obtt: each answered chat call carries provider-reported cost when available. *)
let usage_of (completion : Eta_ai_chat.Codecs.completion) : P.run_usage =
  let Eta_ai_chat.Types.{ prompt_tokens; completion_tokens; cost; total_tokens = _ } =
    completion.Eta_ai_chat.Codecs.usage
  in
  P.
    {
      input_tokens = prompt_tokens;
      output_tokens = completion_tokens;
      cost = Option.value ~default:0. cost;
    }

let add_usage (a : P.run_usage) (b : P.run_usage) : P.run_usage =
  P.
    {
      input_tokens = a.P.input_tokens + b.P.input_tokens;
      output_tokens = a.P.output_tokens + b.P.output_tokens;
      cost = a.P.cost +. b.P.cost;
    }

(* run-obtt: the provider's accounting at info, as the text helper and the drive log
   theirs — one line per call, before the reply is judged, because it was paid for either
   way. *)
let log_usage logger (completion : Eta_ai_chat.Codecs.completion) =
  let Eta_ai_chat.Types.{ prompt_tokens; completion_tokens; total_tokens; cost } =
    completion.Eta_ai_chat.Codecs.usage
  in
  Eta_observability.Logger.info logger
    ~fields:
      [
        ("model", Eta_observability.Logger.String completion.Eta_ai_chat.Codecs.model);
        ("prompt_tokens", Eta_observability.Logger.Int prompt_tokens);
        ("completion_tokens", Eta_observability.Logger.Int completion_tokens);
        ("total_tokens", Eta_observability.Logger.Int total_tokens);
        ("cost", Eta_observability.Logger.Float (Option.value ~default:0. cost));
      ]
    "planner usage"

(* run-rq6i: the request as the planner reads it — the mission, the point the run stopped
   at and why, the playbook in the schema a new procedure must fit, the trace so far, the
   arguments already known, and the page. Story 29 is the one place page text reaches a
   model above the operator, and it is bounded here. *)
let request_json (request : Run.plan_request) =
  let entry (slug, outcome) =
    `Assoc [ ("procedure", `String slug); ("outcome", `String outcome) ]
  in
  `Assoc
    [
      ("mission", `String request.Run.mission);
      ( "stopped",
        `Assoc
          [
            ("trigger", `String (Run.trigger_name request.Run.trigger));
            ("reason", `String request.Run.reason);
          ] );
      ( "playbook",
        match request.Run.playbook with
        | Some book -> Playbook.yojson_of_t book
        | None -> `Null );
      ("trace", `List (List.map entry request.Run.recent));
      ( "arguments",
        `Assoc
          (List.map (fun (name, value) -> (name, `String value)) request.Run.arguments) );
      ( "page",
        `Assoc
          [
            ("url", `String request.Run.url);
            ("title", `String request.Run.title);
            ( "page_kind",
              match request.Run.page_kind with Some kind -> `String kind | None -> `Null
            );
            ("text", `String (bounded page_bytes request.Run.text));
          ] );
    ]

(* run-2tt3: the expectations the planner attached must be verifiable. A sentence the
   grammar does not claim becomes a judgment question, which is fine; a sentence naming a
   page kind the playbook does not declare is an authoring mistake the DONE guard would
   refuse later, so it is refused now, while the retry can still correct the reply. *)
let check_expectations (book : Playbook.t option) sentences =
  let rec go = function
    | [] -> Ok ()
    | sentence :: rest -> (
        if trim sentence = "" then Error "an attached mission expectation is empty"
        else
          match book with
          | None ->
              Error
                (Printf.sprintf
                   "the mission expectation %S cannot be verified: the run has no \
                    playbook"
                   sentence)
          | Some (book : Playbook.t) -> (
              match Playbook.resolve book.Playbook.pages sentence with
              | Ok _ -> go rest
              | Error why ->
                  Error
                    (Printf.sprintf "the mission expectation %S does not resolve: %s"
                       sentence why)))
  in
  go sentences

(* run-rq6i: exactly one answer, and the procedure of a [procedure] answer must be one
   this playbook can run — the loader's own rules, applied before the loop could execute
   it. *)
let answer_of (request : Run.plan_request) (reply : reply) :
    (Run.plan_reply, string) result =
  let expect = Option.value ~default:[] reply.expect in
  let pages = Option.value ~default:[] reply.pages in
  let playbook =
    Option.map
      (fun (book : Playbook.t) -> { book with pages = book.pages @ pages })
      request.Run.playbook
  in
  let validate_pages =
    match playbook with
    | None when pages <> [] -> Error "page kinds require a chosen site"
    | None -> Ok ()
    | Some book ->
        Result.map
          (fun _ -> ())
          (Playbook.of_json ~file:"planner page kinds" (Playbook.yojson_of_t book))
  in
  let one_of_three =
    "answer exactly one of procedure, handoff or fail with the reason it needs"
  in
  match Result.bind validate_pages (fun () -> check_expectations playbook expect) with
  | Error why -> Error why
  | Ok () -> (
      let no_procedure name (procedure : Playbook.procedure option) =
        match procedure with
        | Some _ ->
            Error
              (Printf.sprintf
                 "the answer is %s but the reply also carries a procedure; %s" name
                 one_of_three)
        | None -> Ok ()
      in
      let with_reason name =
        match reply.reason with
        | Some why when trim why <> "" -> Ok why
        | Some _ | None ->
            Error (Printf.sprintf "the answer is %s but the reply carries no reason" name)
      in
      match reply.answer with
      | Procedure_answer -> (
          match (reply.procedure, reply.reason) with
          | None, _ -> Error "the answer is procedure but the reply carries no procedure"
          | Some _, Some _ ->
              Error
                (Printf.sprintf
                   "the answer is procedure but the reply also carries a reason; %s"
                   one_of_three)
          | Some proc, None -> (
              match playbook with
              | None ->
                  Error "the answer is procedure but the run has no playbook to run it in"
              | Some book -> (
                  match
                    Playbook.check_procedure ~file:"the planner's reply" book proc
                  with
                  | Error why -> Error why
                  | Ok () ->
                      Ok Run.{ answer = Run.Procedure proc; expect; usage = None; pages })
              ))
      | Handoff_answer -> (
          match no_procedure "handoff" reply.procedure with
          | Error why -> Error why
          | Ok () ->
              Result.map
                (fun why -> Run.{ answer = Run.Handoff why; expect; usage = None; pages })
                (with_reason "handoff"))
      | Fail_answer -> (
          match no_procedure "fail" reply.procedure with
          | Error why -> Error why
          | Ok () ->
              Result.map
                (fun why -> Run.{ answer = Run.Fail why; expect; usage = None; pages })
                (with_reason "fail")))

(* run-rq6i: the reply as the loop can use it, or the sentence saying why it cannot. The
   content is the model's own text, so both the JSON parse and the derived decode are
   refusals to report back — never an exception and never a guess. *)
let decode (request : Run.plan_request) content : (Run.plan_reply, string) result =
  match Yojson.Safe.from_string content with
  | exception Yojson.Json_error why -> Error ("the reply is not JSON: " ^ why)
  | json -> (
      match reply_of_yojson json with
      | Error why -> Error ("the reply is not the requested answer: " ^ why)
      | Ok reply -> answer_of request reply)

(* run-rq6i: one turn is at most two calls — the answer, and, when it did not decode, the
   same conversation with the reply and its refusal shown back. What the turn cost is the
   sum of what its calls cost (run-obtt). *)
let create ~client ~model ~reasoning ~logger () =
  let reasoning =
    match String.lowercase_ascii (trim reasoning) with
    | "none" | "off" | "disabled" -> `Disabled
    | effort -> `Effort effort
  in
  let ask ~deadline messages =
    Model_usage.start "planner";
    match
      Eta_ai_chat.complete client ~deadline ~model ~messages ~max_tokens ~json_object:true
        ~reasoning ()
    with
    | Error error -> Error (Model_error.of_eta error)
    | Ok completion ->
        log_usage logger completion;
        Model_usage.report "planner" completion.Eta_ai_chat.Codecs.usage.cost;
        Ok completion
  in
  (* run-obtt: the correction call is bounded by the planner's own default deadline as
     well as by what the caller gave, so a turn can never outlast the listener budget the
     run answers within: the first call already has whatever is left of the run, and the
     retry is small by construction. *)
  let retry_deadline (deadline : Eta.Duration.t) =
    Eta.Duration.min deadline default_deadline
  in
  let plan ?(deadline = default_deadline) (request : Run.plan_request) =
    let open Eta_ai_chat.Types in
    let messages =
      [
        { role = System; content = Questions.planner };
        { role = User; content = Yojson.Safe.to_string (request_json request) };
      ]
    in
    match ask ~deadline messages with
    | Error error -> Error error
    | Ok first -> (
        match decode request first.Eta_ai_chat.Codecs.content with
        | Ok reply -> Ok { reply with Run.usage = Some (usage_of first) }
        | Error why -> (
            let retry =
              messages
              @ [
                  { role = Assistant; content = first.Eta_ai_chat.Codecs.content };
                  { role = User; content = Questions.planner_retry why };
                ]
            in
            match ask ~deadline:(retry_deadline deadline) retry with
            | Error error -> Error error
            | Ok second -> (
                match decode request second.Eta_ai_chat.Codecs.content with
                | Ok reply ->
                    Ok
                      {
                        reply with
                        Run.usage = Some (add_usage (usage_of first) (usage_of second));
                      }
                | Error why ->
                    Error (Model_error.unavailable ~code:"invalid-response" why))))
  in
  { plan }
