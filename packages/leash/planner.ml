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

(* pilot-x1f3: the pilot names a select option by its label or value as often as by its
   index (U2 on Tauron, 2026-10-04: "option: expected int, got \"Faktury\""); resolve it
   against the offered row's options, case-insensitively. *)
let select_by_label (snapshot : P.snapshot) json =
  let norm s = String.lowercase_ascii (String.trim s) in
  match json with
  | `Assoc fields -> (
      match (List.assoc_opt "cmd" fields, List.assoc_opt "args" fields) with
      | Some (`String "select"), Some (`Assoc args) -> (
          match (List.assoc_opt "option" args, List.assoc_opt "index" args) with
          | Some (`String wanted), Some (`Int index) -> (
              let options =
                List.find_opt (fun (row : P.row) -> row.index = index) snapshot.rows
                |> Fun.flip Option.bind (fun (row : P.row) -> row.options)
                |> Option.value ~default:[]
              in
              match
                List.find_opt
                  (fun (o : P.row_option) ->
                    norm o.label = norm wanted || norm o.value = norm wanted)
                  options
              with
              | Some o ->
                  let args =
                    List.map
                      (fun (k, v) -> if k = "option" then (k, `Int o.index) else (k, v))
                      args
                  in
                  `Assoc
                    (List.map
                       (fun (k, v) -> if k = "args" then (k, `Assoc args) else (k, v))
                       fields)
              | None -> json)
          | _ -> json)
      | _ -> json)
  | json -> json

let trigger_text = function
  | Run.Blocked -> "JEV stopped here (BLOCKED, a stall or its step cap); take over"
  | Run.Final ->
      "JEV reported DONE; give the mission's answer from this page, or take over"
  | Run.Holding -> "you hold the page; your last action came back"

let request_json (request : Run.plan_request) =
  let snapshot =
    match
      P.yojson_of_snapshot
        {
          request.snapshot with
          P.rows = List.filteri (fun i _ -> i < 250) request.snapshot.rows;
        }
    with
    | `Assoc fields ->
        `Assoc
          (List.map
             (function
               | "image", `Assoc image ->
                   ("image", `Assoc (List.filter (fun (key, _) -> key <> "path") image))
               | field -> field)
             fields)
    | json -> json
  in
  let picture =
    match (request.image_input, request.snapshot.image) with
    | Some _, Some image ->
        [
          ( "picture_coordinates",
            `String
              (Printf.sprintf
                 "The attached PNG is %dx%d pixels of a %gx%g CSS viewport: x_css = \
                  x_png / %g, y_css = y_png / %g."
                 image.width image.height image.viewport.width image.viewport.height
                 image.scale image.scale) );
        ]
    | _ -> []
  in
  `Assoc
    ([
       ("asked_because", `String (trigger_text request.trigger));
       ("reason", `String request.reason);
       ("mission", `String request.mission);
       ("secret_names", `List (List.map (fun name -> `String name) request.secret_names));
       ("site", match request.site with Some s -> `String s | None -> `Null);
       ( "history",
         `List
           (List.map
              (fun (what, outcome) ->
                `Assoc [ ("what", `String what); ("outcome", `String outcome) ])
              request.history) );
       ( "downloads",
         `List
           (List.map
              (fun (name, mime, state) ->
                `Assoc
                  [
                    ("file", `String name);
                    ("mime", `String mime);
                    ("state", `String state);
                  ])
              request.downloads) );
       ("url", `String request.url);
       ("title", `String request.title);
       ("text", `String (bounded page_bytes request.text));
       ("snapshot", snapshot);
     ]
    @ picture)

let decode (request : Run.plan_request) content =
  let ( let* ) = Result.bind in
  match Yojson.Safe.from_string content with
  | exception Yojson.Json_error why -> Error ("reply is not JSON: " ^ why)
  | `Assoc fields -> (
      let string key =
        match List.assoc_opt key fields with
        | Some (`String s) when trim s <> "" -> Ok s
        | _ -> Error (key ^ " must be a non-empty string")
      in
      let strings key =
        match List.assoc_opt key fields with
        | None | Some `Null -> Ok []
        | Some (`List values) ->
            Ok (List.filter_map (function `String s -> Some s | _ -> None) values)
        | _ -> Error (key ^ " must be a list of strings")
      in
      let* name = string "answer" in
      match name with
      | "jev" ->
          let* goal = string "goal" in
          Ok Run.{ answer = Jev goal; usage = None }
      | "act" -> (
          match List.assoc_opt "action" fields with
          | None -> Error "act requires action"
          | Some json ->
              let json = select_by_label request.snapshot json in
              let* action = P.planner_action_of_yojson json in
              let* () = P.check_planner_action request.snapshot action in
              Ok Run.{ answer = Act action; usage = None })
      | "read" ->
          let* quote = string "quote" in
          let note =
            match string "note" with
            | Ok n -> n
            | Error _ -> ("" [@ox.allow "ox-discarded-result: the note is optional"])
          in
          Ok Run.{ answer = Read { quote; note }; usage = None }
      | "observe" -> Ok Run.{ answer = Observe_image; usage = None }
      | "notify" ->
          let* message = string "message" in
          Ok Run.{ answer = Notify message; usage = None }
      | "handoff" when request.headless ->
          Error "handoff is not available: the browser is headless"
      | "handoff" ->
          let* reason = string "reason" in
          Ok Run.{ answer = Handoff reason; usage = None }
      | "fail" ->
          let* reason = string "reason" in
          Ok Run.{ answer = Fail reason; usage = None }
      | "done" ->
          let* result = string "result" in
          let* evidence = strings "evidence" in
          let* records =
            match List.assoc_opt "records" fields with
            | None | Some `Null -> Ok []
            | Some (`List values) ->
                Ok
                  (List.filter_map
                     (function
                       | `Assoc pairs ->
                           Some
                             (List.filter_map
                                (fun (k, v) ->
                                  match v with
                                  | `String s -> Some (k, s)
                                  | `Int i -> Some (k, string_of_int i)
                                  | `Float f -> Some (k, Printf.sprintf "%g" f)
                                  | _ -> None)
                                pairs)
                       | _ -> None)
                     values)
            | Some _ -> Error "records must be a list of objects"
          in
          Ok Run.{ answer = Done { result; evidence; records }; usage = None }
      | _ -> Error "answer must be jev, act, read, observe, notify, handoff, done or fail"
      )
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
    let prompt = Questions.takeover ~headless:request.Run.headless in
    (* takeover: a requested screenshot is a real image part of the chat request. *)
    let observation =
      Text (Yojson.Safe.to_string (request_json request))
      :: Option.to_list (Option.map image_png request.Run.image_input)
    in
    let messages =
      [ text_message System prompt; { role = User; content = observation } ]
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
