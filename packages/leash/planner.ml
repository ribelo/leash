(* revert-24kr revert-apgf revert-bqrq (ADR-0015): the optional planner, consulted and
   never acting. On BLOCKED or a failed expectation it answers a hint JEV is given as its
   goal, or handoff, notify or fail; at the end of a mission that asks for an answer it
   gives result, evidence and whether the mission is done. Strict wire shapes, one
   correction within the original budget. *)

module P = Protocol

type t = {
  plan : ?deadline:Ox.Duration.t -> Run.plan_request -> (Run.plan_reply, P.error) result;
}

let default_deadline = Ox.Duration.seconds 30

(* Operator 2026-10-02: no output token budget on any model call. A capped reply that
   spent its budget on reasoning came back empty and dropped a compile. *)
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
let usage_of (completion : Ox_ai_chat.Codecs.completion) : P.run_usage =
  let Ox_ai_chat.Types.{ prompt_tokens; completion_tokens; cost; total_tokens = _ } =
    completion.Ox_ai_chat.Codecs.usage
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
let log_usage logger (completion : Ox_ai_chat.Codecs.completion) =
  let Ox_ai_chat.Types.{ prompt_tokens; completion_tokens; total_tokens; cost } =
    completion.Ox_ai_chat.Codecs.usage
  in
  Ox_observability.Logger.info logger
    ~fields:
      [
        ("model", Ox_observability.Logger.String completion.Ox_ai_chat.Codecs.model);
        ("prompt_tokens", Ox_observability.Logger.Int prompt_tokens);
        ("completion_tokens", Ox_observability.Logger.Int completion_tokens);
        ("total_tokens", Ox_observability.Logger.Int total_tokens);
        ("cost", Ox_observability.Logger.Float (Option.value ~default:0. cost));
      ]
    "planner usage"

let trigger_text = function
  | Run.Blocked -> "JEV stopped (BLOCKED, a step cap or a stall)"
  | Run.Expectation -> "an expectation failed"
  | Run.Final -> "JEV reported DONE; give the mission's answer"

let request_json (request : Run.plan_request) =
  let snapshot =
    P.yojson_of_snapshot
      {
        request.snapshot with
        P.rows = List.filteri (fun i _ -> i < 250) request.snapshot.rows;
      }
  in
  `Assoc
    [
      ("asked_because", `String (trigger_text request.trigger));
      ("reason", `String request.reason);
      ("mission", `String request.mission);
      ("secret_names", `List (List.map (fun name -> `String name) request.secret_names));
      ("site", match request.site with Some s -> `String s | None -> `Null);
      ("site_notes", match request.notes with Some n -> `String n | None -> `Null);
      ( "jev_history",
        `List
          (List.map
             (fun (goal, outcome) ->
               `Assoc [ ("goal", `String goal); ("outcome", `String outcome) ])
             request.history) );
      ("url", `String request.url);
      ("title", `String request.title);
      ("text", `String (bounded page_bytes request.text));
      ("snapshot", snapshot);
    ]

let decode (request : Run.plan_request) content =
  match Yojson.Safe.from_string content with
  | exception Yojson.Json_error why -> Error ("reply is not JSON: " ^ why)
  | `Assoc fields -> (
      let string key =
        match List.assoc_opt key fields with
        | Some (`String s) when trim s <> "" -> Ok s
        | _ -> Error (key ^ " must be a non-empty string")
      in
      let ( let* ) = Result.bind in
      let* name = string "answer" in
      match (request.trigger, name) with
      | Run.Final, "done" ->
          let* result = string "result" in
          let* evidence =
            match List.assoc_opt "evidence" fields with
            | Some (`List items) ->
                Ok (List.filter_map (function `String s -> Some s | _ -> None) items)
            | None -> Ok []
            | Some _ -> Error "evidence must be a list of strings"
          in
          let* done_ =
            match List.assoc_opt "done" fields with
            | Some (`Bool b) -> Ok b
            | _ -> Error "done must be true or false"
          in
          Ok Run.{ answer = Answer { result; evidence; done_ }; usage = None }
      | Run.Final, "fail" ->
          let* reason = string "reason" in
          Ok Run.{ answer = Fail reason; usage = None }
      | Run.Final, _ -> Error "answer must be done or fail"
      | _, "hint" ->
          let* goal = string "goal" in
          Ok Run.{ answer = Hint goal; usage = None }
      | _, "handoff" ->
          let* reason = string "reason" in
          Ok Run.{ answer = Handoff reason; usage = None }
      | _, "notify" ->
          let* message = string "message" in
          Ok Run.{ answer = Notify message; usage = None }
      | _, "fail" ->
          let* reason = string "reason" in
          Ok Run.{ answer = Fail reason; usage = None }
      | _, _ -> Error "answer must be hint, handoff, notify or fail")
  | _ -> Error "reply must be an object"

let create ~now ~client ~model ~reasoning ~logger () =
  let reasoning =
    match String.lowercase_ascii (trim reasoning) with
    | "none" | "off" | "disabled" -> `Disabled
    | effort -> `Effort effort
  in
  let ask ~deadline messages =
    Model_usage.start "planner";
    match
      Ox_ai_chat.complete client ~deadline ~model ~messages ~json_object:true ~reasoning
        ()
    with
    | Error error -> Error (Model_error.of_eta error)
    | Ok completion ->
        log_usage logger completion;
        Model_usage.report "planner" completion.Ox_ai_chat.Codecs.usage.cost;
        Ok completion
  in
  let plan ?(deadline = default_deadline) (request : Run.plan_request) =
    (* daily-9ggi: a correction spends the same turn budget, not a fresh one. *)
    let expires = now () +. Ox.Duration.to_seconds deadline in
    let retry_deadline () =
      Ox.Duration.min default_deadline
        (Ox.Duration.of_seconds (max 0. (expires -. now ())))
    in
    let open Ox_ai_chat.Types in
    let prompt =
      match request.Run.trigger with
      | Run.Final -> Questions.planner_answer
      | _ -> Questions.planner_hint
    in
    let messages =
      [
        text_message System prompt;
        text_message User (Yojson.Safe.to_string (request_json request));
      ]
    in
    match ask ~deadline messages with
    | Error error -> Error error
    | Ok first -> (
        match decode request first.Ox_ai_chat.Codecs.content with
        | Ok reply -> Ok { reply with Run.usage = Some (usage_of first) }
        | Error why -> (
            let retry = messages @ [ text_message User (Questions.planner_retry why) ] in
            let remaining = retry_deadline () in
            match
              if Ox.Duration.is_zero remaining then Error (Model_error.of_eta `Timeout)
              else ask ~deadline:remaining retry
            with
            | Error error -> Error error
            | Ok second -> (
                match decode request second.Ox_ai_chat.Codecs.content with
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

(* map-bjon map-6xcy map-nh2e: separate versioned compiler turn.
   map-bjon: a final expect that only names the page kind verifies while the
   result is still loading. The result check is required. *)
