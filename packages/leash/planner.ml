(* pilot-ukoh pilot-gt2h pilot-r94o: versioned bounded mission-pilot turns,
   strict wire shapes and correction within the original budget. *)

module P = Protocol

let pilot_prompt = Questions.pilot

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

(* pilot-ukoh: bounded page and leg memory, with secret names only. *)
let pilot_request_json (request : Run.plan_request) =
  let snapshot =
    P.yojson_of_snapshot
      {
        request.snapshot with
        rows = List.filteri (fun i _ -> i < 250) request.snapshot.rows;
      }
  in
  let snapshot =
    match snapshot with
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
  (* pic-k4ij: the measured scale states the PNG-to-CSS conversion; no HiDPI guess. *)
  let picture =
    match request.snapshot.image with
    | None -> []
    | Some image ->
        [
          ( "picture_coordinates",
            `String
              (Printf.sprintf
                 "The attached PNG is %dx%d pixels of a %gx%g CSS viewport: x_css = \
                  x_png / %g, y_css = y_png / %g. Points and row boxes use viewport CSS \
                  pixels."
                 image.width image.height image.viewport.width image.viewport.height
                 image.scale image.scale) );
        ]
  in
  `Assoc
    ([
       ("mission", `String request.mission);
       ("secret_names", `List (List.map (fun name -> `String name) request.secret_names));
       ( "arguments",
         `Assoc (List.map (fun (name, value) -> (name, `String value)) request.arguments)
       );
       ( "page_kind",
         match request.page_kind with Some kind -> `String kind | None -> `Null );
       ( "site_notes",
         match request.notes with Some notes -> `String notes | None -> `Null );
       ("url", `String request.url);
       ("title", `String request.title);
       ("text", `String (bounded 6000 request.text));
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
       ("snapshot", snapshot);
       ( "legs",
         `List
           (List.map
              (fun (leg : Run.leg) ->
                `Assoc
                  [
                    ("goal", `String leg.goal);
                    ("outcome", `String leg.outcome);
                    ("steps", `List (List.map P.yojson_of_step leg.steps));
                  ])
              request.legs) );
       ("candidates", `List (List.map Playbook.yojson_of_procedure request.candidates));
     ]
    @ picture)

(* pilot-gt2h pilot-r94o: one shape; done cannot omit its result. *)
let decode_pilot (request : Run.plan_request) content =
  let ( let* ) = Result.bind in
  match Yojson.Safe.from_string content with
  | exception Yojson.Json_error _ -> Error "reply is not JSON"
  | `Assoc fields ->
      let string key =
        match List.assoc_opt key fields with
        | Some (`String value) when trim value <> "" -> Ok value
        | _ -> Error ("missing nonempty " ^ key)
      in
      let strings key =
        match List.assoc_opt key fields with
        | None -> Ok []
        | Some (`List values) ->
            List.fold_right
              (fun v result ->
                let* rest = result in
                match v with
                | `String s -> Ok (s :: rest)
                | _ -> Error (key ^ " must be strings"))
              values (Ok [])
        | _ -> Error (key ^ " must be a list")
      in
      let* name = string "answer" in
      let allowed =
        [ "answer"; "expect"; "reasoning_summary"; "secrets_for_operator" ]
        @
        match name with
        | "leg" -> [ "goal" ]
        | "read" -> [ "quote"; "note" ]
        | "act" -> [ "action" ]
        | "observe" -> [ "image" ]
        | "notify" -> [ "message" ]
        | "done" -> [ "result"; "evidence"; "records" ]
        | "handoff" | "fail" -> [ "reason" ]
        | _ -> []
      in
      let* () =
        if List.exists (fun (key, _) -> not (List.mem key allowed)) fields then
          Error "reply mixes answer shapes or has unknown fields"
        else Ok ()
      in
      let* answer =
        match name with
        | "leg" ->
            let* goal = string "goal" in
            Ok (Run.Leg goal)
        | "read" ->
            let* quote = string "quote" in
            let* note = string "note" in
            Ok (Run.Read { quote; note })
        | "act" -> (
            match List.assoc_opt "action" fields with
            | None -> Error "act requires action"
            | Some json ->
                let json = select_by_label request.snapshot json in
                let* action = P.planner_action_of_yojson json in
                let* () = P.check_planner_action request.snapshot action in
                Ok (Run.Act action))
        | "done" ->
            let* result = string "result" in
            let* evidence =
              match List.assoc_opt "evidence" fields with
              | None -> Error "done requires evidence"
              | Some _ -> strings "evidence"
            in
            (* pilot-sc9t: records are flat objects of text, at most 10000. *)
            let* records =
              match List.assoc_opt "records" fields with
              | None | Some `Null -> Ok []
              | Some (`List values) when List.length values <= 10_000 ->
                  List.fold_right
                    (fun value acc ->
                      let* rest = acc in
                      match value with
                      | `Assoc pairs ->
                          let* record =
                            List.fold_right
                              (fun (key, v) acc ->
                                let* rest = acc in
                                match v with
                                | `String s -> Ok ((key, s) :: rest)
                                | `Int i -> Ok ((key, string_of_int i) :: rest)
                                | `Float f -> Ok ((key, Printf.sprintf "%g" f) :: rest)
                                | _ -> Error "a record value must be text")
                              pairs (Ok [])
                          in
                          Ok (record :: rest)
                      | _ -> Error "records must be objects")
                    values (Ok [])
              | Some _ -> Error "records must be a list of at most 10000 objects"
            in
            Ok (Run.Done { result; evidence; records })
        | "handoff" ->
            let* reason = string "reason" in
            Ok (Run.Handoff reason)
        | "fail" ->
            let* reason = string "reason" in
            Ok (Run.Fail reason)
        | "observe" ->
            if List.assoc_opt "image" fields = Some (`Bool true) then Ok Run.Observe_image
            else Error "observe requires image=true"
        | "notify" ->
            let* message = string "message" in
            Ok (Run.Notify message)
        | _ ->
            Error "answer must be leg, read, act, observe, handoff, notify, done or fail"
      in
      let* expect = strings "expect" in
      let* reasoning_summary =
        match List.assoc_opt "reasoning_summary" fields with
        | None | Some `Null -> Ok None
        | Some (`String s) -> Ok (Some s)
        | _ -> Error "reasoning_summary must be text"
      in
      let* secrets_for_operator =
        match List.assoc_opt "secrets_for_operator" fields with
        | None -> Ok []
        | Some (`Assoc values) ->
            List.fold_right
              (fun (name, value) result ->
                let* rest = result in
                match value with
                | `String value -> Ok ((name, value) :: rest)
                | _ -> Error "secret must be a string")
              values (Ok [])
        | _ -> Error "secrets_for_operator must be an object"
      in
      Ok Run.{ answer; expect; usage = None; reasoning_summary; secrets_for_operator }
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
    (* pic-k4ij: the screenshot is a real image part of the Ox chat request. *)
    let observation =
      Text (Yojson.Safe.to_string (pilot_request_json request))
      :: Option.to_list (Option.map image_png request.image_input)
    in
    let messages =
      [ text_message System Questions.pilot; { role = User; content = observation } ]
    in
    match ask ~deadline messages with
    | Error error -> Error error
    | Ok first -> (
        match decode_pilot request first.Ox_ai_chat.Codecs.content with
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
                match decode_pilot request second.Ox_ai_chat.Codecs.content with
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
