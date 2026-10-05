(* ADR-0015 (amended) ADR-0016: drive is JEV's loop over the page. JEV decides every step
   over the element table ({!Drive}); the text helper writes field values. When JEV answers
   BLOCKED, stalls or reaches its step cap, the planner (Luna) takes the page over: it acts,
   reads, notifies, hands off on a headed browser, finishes or fails, and hands control back
   to JEV with a goal string. When JEV reports DONE on a mission that asks for an answer, the
   planner gives it or takes over. Only the deadline bounds the planner.

   OxCaml local mode annotations are not parsed by ocamlformat 0.29. Keep this file in
   .ocamlformat-ignore until the formatter supports them. *)
module P = Protocol

type observation = {
  url : string;
  title : string;
  text : string;
  dialog : P.dialog option;
  rows : (string * string) list;
  downloads : (string * string * string) list;
  snapshot : P.snapshot;
  image_input : bytes option;
      (* takeover: private PNG bytes for the planner's image input, when it asked. *)
}

type step_request = {
  goal : string;
  recent : Jev_request.recent_action list;
  max_steps : int;
  stop_on_navigation : bool;
  deadline_s : int;
  dry_run : bool;
}

type plan_trigger = Blocked | Final | Holding

type plan_answer =
  | Jev of string
  | Act of Protocol.planner_action
  | Read of { quote : string; note : string }
  | Observe_image
  | Notify of string
  | Handoff of string
  | Done of { result : string; evidence : string list; records : (string * string) list list }
  | Fail of string

type plan_reply = { answer : plan_answer; usage : P.run_usage option }

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  secret_names : string list;
  headless : bool;
  site : string option;
  history : (string * string) list;
  url : string;
  title : string;
  text : string;
  snapshot : Protocol.snapshot;
  image_input : bytes option;
  downloads : (string * string * string) list;
}

type levels = {
  plan : deadline:Ox.Duration.t -> plan_request -> (plan_reply, P.error) result;
}

type handler = {
  observe : image:bool -> unit -> (observation, P.error) result;
  navigate : string -> (unit, P.error) result;
  step : step_request -> (P.drive_result, P.error) result;
  plan : plan_request -> (plan_reply, P.error) result;
  act : P.planner_action -> (P.action_result, P.error) result;
  hand_off : reason:string -> (P.tab_info, P.error) result;
}

type args = {
  mission : string;
  max_steps : int;
  start_url : string option;
  deadline_s : int;
  dry_run : bool;
}

let of_args (args : P.run_args) : args =
  {
    mission = args.P.mission;
    max_steps = Option.value ~default:256 args.P.max_steps;
    start_url = args.P.start_url;
    deadline_s = Option.value ~default:600 args.P.deadline_s;
    dry_run = Option.value ~default:false args.P.dry_run;
  }

(* ---------- Small helpers ---------- *)

let code name = match P.Error_code.of_string name with Ok x -> x | Error _ -> assert false
let status name = match P.Run_status.of_string name with Ok x -> x | Error _ -> assert false

let invalid message = P.make_error (code "invalid-request") ~message
let internal message = P.make_error (code "internal") ~message
let ms seconds = max 0 (int_of_float (seconds *. 1000.))

let starting_urls mission =
  String.map (function '\n' | '\r' | '\t' | '\'' | '"' | '<' | '>' | '(' | ')' -> ' ' | c -> c) mission
  |> String.split_on_char ' '
  |> List.filter (fun word -> String.starts_with ~prefix:"https://" word || String.starts_with ~prefix:"http://" word)
  |> List.sort_uniq String.compare

let valid_start_url url =
  let start = if String.starts_with ~prefix:"https://" url then 8
    else if String.starts_with ~prefix:"http://" url then 7 else String.length url in
  let rec stop i = if i = String.length url || String.contains "/?#" url.[i]
    then i else stop (i + 1) in
  let last = stop start in
  last > start && not (String.contains (String.sub url start (last - start)) '@')
    && not (String.exists (fun c -> Char.code c <= 32 || Char.code c = 127) url)

let drive_recent (steps : P.step list) =
  List.filter_map (fun (step : P.step) ->
    let operation = P.Operation.to_string step.operation in
    let kind = match operation with "click" -> Some "click" | "type_text" -> Some "fill"
      | "select" -> Some "select" | "scroll_up" | "scroll_down" -> Some "scroll"
      | "wait" -> Some "wait" | _ -> None in
    Option.map (fun kind -> Jev_request.{action = operation;
      kind = Some kind; text = step.text; page_changed = None}) kind) steps
let drive_actions (drive : P.drive_result) =
  match drive.operator_state with
  | Some (`Assoc state) -> (match List.assoc_opt "metrics" state with
      | Some (`Assoc metrics) -> (match List.assoc_opt "actions" metrics with
          | Some (`Int actions) -> actions
          | _ -> List.length (drive_recent drive.steps))
      | _ -> List.length (drive_recent drive.steps))
  | _ -> List.length (drive_recent drive.steps)

let lower = String.lowercase_ascii

(* run-tt9z: fail closed on action intent, including synonyms rather than only exact labels.
   The operator also applies this to the chosen row immediately before dispatch. *)
(* pilot-gt2h: whole words, not substrings — "Open the section showing invoices, payments"
   is navigation, "Pay now" and "Confirm payment" are payment (U1 on Tauron, 2026-10-04,
   refused a leg for containing "payments"). Polish verbs cover the operator's sites. *)
let unsafe_action text =
  let words =
    let lower = String.lowercase_ascii text in
    let buf = Buffer.create 16 and out = ref [] in
    let flush () = if Buffer.length buf > 0 then (out := Buffer.contents buf :: !out; Buffer.clear buf) in
    String.iter (fun c -> match c with
      | 'a' .. 'z' | '0' .. '9' -> Buffer.add_char buf c
      | c when Char.code c >= 128 -> Buffer.add_char buf c
      | _ -> flush ()) lower;
    flush ();
    List.rev !out
  in
  let word w = List.mem w words in
  let phrase ws =
    let n = List.length ws in
    let rec at = function
      | [] -> false
      | _ :: rest as l -> (List.length l >= n && List.filteri (fun i _ -> i < n) l = ws) || at rest
    in
    at words
  in
  let any = List.exists word and phrases = List.exists phrase in
  if any [ "pay"; "buy"; "purchase"; "checkout"; "zapłać"; "zaplac"; "kup"; "kupuję"; "kupuje" ]
     || phrases [ [ "place"; "order" ]; [ "check"; "out" ]; [ "card"; "number" ] ]
     || (any [ "confirm"; "complete"; "potwierdź"; "potwierdz" ]
         && any [ "payment"; "order"; "purchase"; "płatność"; "zamówienie" ])
  then Some "payment"
  else if any [ "delete"; "erase"; "usuń"; "usun" ]
     || phrases [ [ "remove"; "account" ]; [ "close"; "account" ]; [ "permanently"; "remove" ] ]
  then Some "deletion"
  else if any [ "send"; "reply"; "publish"; "wyślij"; "wyslij"; "odpowiedz" ]
     || phrases [ [ "post"; "comment" ]; [ "submit"; "comment" ]; [ "post"; "message" ] ]
  then Some "messaging"
  else None

let authorises mission intent =
  let terms=match intent with "payment" -> ["pay";"buy";"purchase";"checkout";"place order";"payment"] | "deletion" -> ["delete";"remove account";"close account";"erase account"] | _ -> ["send";"reply";"message";"post comment"] in
  let mission=String.lowercase_ascii mission in
  let has text = let n=String.length text in let rec loop i = i+n<=String.length mission && (String.sub mission i n=text || loop (i+1)) in loop 0 in
  List.exists has terms && not (List.exists (fun term -> List.exists (fun prefix -> has (prefix^term)) ["do not ";"don't ";"never ";"without "]) terms)

let contains ~needle haystack =
  let needle = lower needle and haystack = lower haystack in
  let n = String.length needle in
  let rec loop i =
    i + n <= String.length haystack && (String.sub haystack i n = needle || loop (i + 1))
  in
  loop 0

let trigger_name = function Blocked -> "blocked" | Final -> "answer" | Holding -> "holding"

let answer_name = function
  | Jev _ -> "jev"
  | Act _ -> "act"
  | Read _ -> "read"
  | Observe_image -> "observe"
  | Notify _ -> "notify"
  | Handoff _ -> "handoff"
  | Done _ -> "done"
  | Fail _ -> "fail"

(* revert-24kr: a mission asks for an answer when it is a question, names a result, or
   asks to be told, found, listed, checked or collected. *)
let asks_answer mission =
  let m = String.lowercase_ascii mission in
  let has needle = contains ~needle m in
  String.contains m '?' || has "result:"
  || List.exists has [ "tell me"; "what "; "which "; "how many"; "how much"; "who "; "when ";
       "where "; "whether"; "is there"; "list "; "give me"; "find "; "check "; "report " ]

let loop ~handler ~now ?(planner = true) ?(headless = false) ?(secrets = [])
    ?(on_record = fun _ -> Ok ()) ?(notify = fun _ -> Ok ()) (args : args) =
  let calls = Hashtbl.create 8 and priced = ref 0 and reported_cost = ref 0. in
  let note = function
    | Model_usage.Start kind -> Hashtbl.replace calls kind (1 + Option.value ~default:0 (Hashtbl.find_opt calls kind))
    | Model_usage.Reported (_, Some cost) -> incr priced; reported_cost := !reported_cost +. cost
    | Model_usage.Reported (_, None) -> () in
  Model_usage.with_meter note (fun () ->
  let ( let* ) = Result.bind in
  let deadline = now () +. float_of_int args.deadline_s in
  let scrub text = P.redact_string secrets text in
  let observe ?(image = false) () = handler.observe ~image () in
  let turns = ref [] and history = ref [] and unattended = ref [] in
  let total_steps = ref 0 and operator_steps = ref [] and operator_state = ref None in
  let records = ref [] and read_evidence = ref [] and site = ref None in
  (* dmod-l44q: over every stint, the screenshots sent to the decision model and each of
     its calls' input tokens. *)
  let image_parts = ref 0 and decision_tokens = ref [] in
  let absorb = function
    | Some (`Assoc state) ->
        let field key = function `Assoc fields -> List.assoc_opt key fields | _ -> None in
        (match Option.bind (List.assoc_opt "metrics" state) (field "image_parts") with
         | Some (`Int n) -> image_parts := !image_parts + n
         | _ -> ());
        (match List.assoc_opt "predictions" state with
         | Some (`List predictions) ->
             List.iter (fun prediction ->
               match Option.bind (field "usage" prediction) (field "input_tokens") with
               | Some (`Int n) -> decision_tokens := !decision_tokens @ [ n ]
               | _ -> ()) predictions
         | _ -> ())
    | _ -> () in
  let remaining () = max 1 (int_of_float (deadline -. now ())) in
  let accounting () =
    let count = Hashtbl.fold (fun _ count total -> count + total) calls 0 in
    let unreported = max 0 (count - !priced) in
    let by_kind = Hashtbl.fold (fun kind count acc -> (kind, `Int count) :: acc) calls [] |> List.sort compare in
    count, (if unreported = 0 then Some !reported_cost else None),
    ["model_calls_by_kind", `Assoc by_kind; "reported_cost", `Float !reported_cost; "cost_unreported", `Int unreported] in
  let finish (page : observation) name ?result ?(evidence = []) ?reason () =
    let call_count, model_cost, usage_fields = accounting () in
    Ok P.{ result = Option.map scrub result; evidence = List.map scrub evidence;
      navigator_steps = !total_steps;
      reasoning_summary = None; secrets_for_operator = [];
      unattended = List.rev !unattended; detail = None; status = status name;
      answer = Option.map scrub result; site = !site;
      planner_turns = List.rev !turns;
      collected = List.length !records;
      data = `Assoc (["count", `Int (List.length !records); "first", `List (List.rev !records)]
        @ ["image_parts", `Int !image_parts;
           "decision_input_tokens", `List (List.map (fun n -> `Int n) !decision_tokens)]
        @ usage_fields);
      model_calls = call_count; model_cost; operator_steps = List.rev !operator_steps;
      operator_state = !operator_state;
      output_kinds = (if !records = [] then [] else ["planner-record"]) @ (if !operator_state=None then [] else ["operator-state"]);
      final = page.snapshot; reason = Option.map scrub reason; trace_path = None } in
  let failed error =
    let count, cost, usage_fields = accounting () in
    let original = match error.P.detail with Some (`Assoc fields) -> fields | _ -> [] in
    let fields = usage_fields @ ["model_calls", `Int count; "model_cost", (match cost with Some cost -> `Float cost | None -> `Null);
      "navigator_steps", `Int !total_steps;
      "planner_turns", `List (List.map P.yojson_of_planner_turn (List.rev !turns))] in
    let detail = `Assoc (fields @ List.filter (fun (key, _) -> not (List.mem_assoc key fields)) original) in
    Error { error with P.message = scrub error.P.message; detail = Some detail } in
  let locate (page : observation) = site := Web_url.host page.url in
  (* One stint of JEV's loop on a goal. *)
  let drive goal =
    let* () = match unsafe_action goal with
      | Some intent when not (authorises args.mission intent) ->
          Error (invalid ("refused " ^ intent ^ ": mission does not name that action"))
      | _ -> Ok () in
    let* drive = handler.step { goal; recent = []; max_steps = args.max_steps; stop_on_navigation = false;
      deadline_s = remaining (); dry_run = args.dry_run } in
    total_steps := !total_steps + List.length drive.P.steps;
    operator_steps := List.rev_append drive.steps !operator_steps;
    operator_state := drive.operator_state;
    absorb drive.operator_state;
    history := !history @ [ (scrub goal, P.Drive_status.to_string drive.status ^ Option.fold ~none:"" ~some:(fun r -> ": " ^ scrub r) drive.reason) ];
    Ok drive in
  (* takeover: Luna's own action on the page, under the guards every action has: an
     offered row of the current snapshot, consent, unsafe intent, and only files the
     mission names. A secret name is typed as its value. *)
  let command_row = function
    | P.Click a -> Some a.index | P.Fill a -> Some a.index | P.Select a -> Some a.index
    | P.Press a -> a.index | P.Upload a -> Some a.index | _ -> None in
  let act (page : observation) command =
    let refusal = match P.check_planner_action page.snapshot command with
      | Error why -> Some why
      | Ok () ->
          let rows = match command with
            | P.Click_at a -> P.rows_at_point page.snapshot a.at
            | P.Drag a -> P.rows_at_point page.snapshot a.from_ @ P.rows_at_point page.snapshot a.to_
            | _ -> Option.to_list (Option.bind (command_row command) (fun index ->
                List.find_opt (fun (r : P.row) -> r.index = index) page.snapshot.rows)) in
          let intent = List.find_opt (fun intent -> not (authorises args.mission intent))
            (List.filter_map (fun (row : P.row) -> unsafe_action row.name) rows) in
          let unnamed = match command with
            | P.Upload a -> List.find_opt (fun path -> not (contains ~needle:path args.mission)) a.paths
            | _ -> None in
          match unnamed with
          | Some path -> Some ("refused upload: the mission does not name " ^ path)
          | None -> Option.map (fun intent -> "refused " ^ intent ^ ": mission does not name that action") intent in
    let value text = Option.value ~default:text (List.assoc_opt text secrets) in
    let command = match command with
      | P.Fill a -> P.Fill { a with text = value a.text }
      | P.Type a -> P.Type { a with text = value a.text }
      | c -> c in
    let at = now () in
    let outcome = match refusal with Some why -> Error (invalid why) | None -> handler.act command in
    let target = Option.bind (command_row command) (fun index ->
      List.find_opt (fun (r : P.row) -> r.index = index) page.snapshot.rows) in
    let named = match target with
      | Some r -> Printf.sprintf "the %s named %s" r.role (scrub r.name) | None -> "the page" in
    let described = match command with
      | P.Click _ -> "Click " ^ named
      | P.Click_at a -> Printf.sprintf "Click at CSS (%g, %g)" a.at.x a.at.y
      | P.Drag a -> Printf.sprintf "Drag from CSS (%g, %g) to (%g, %g)" a.from_.x a.from_.y a.to_.x a.to_.y
      | P.Type a -> Printf.sprintf "Type %s into the current focus" (scrub a.text)
      | P.Fill a -> Printf.sprintf "Type %s into %s" (scrub a.text) named
      | P.Select _ -> "Choose an option in " ^ named
      | P.Press a -> Printf.sprintf "Press %s on %s" a.key named
      | P.Upload a -> Printf.sprintf "Attach %s to %s" (String.concat ", " a.paths) named
      | c -> P.command_name c in
    let result = match outcome with Ok _ -> "done" | Error e -> "refused: " ^ scrub e.P.message in
    history := !history @ [ ("Luna: " ^ described, result) ];
    let step = P.{ non_repeatable = false; n = 1; command = P.command_name command; target = None;
      text = (match command with P.Fill a -> Some (scrub a.text) | P.Type a -> Some (scrub a.text) | _ -> None);
      after = (match outcome with Ok (r : P.action_result) -> { url = scrub r.P.url; title = scrub r.P.title }
        | Error _ -> { url = page.url; title = page.title });
      elapsed_ms = ms (now () -. at);
      error = (match outcome with Ok _ -> None | Error e -> Some (scrub e.P.message));
      hits = (match outcome with Ok r -> r.P.hits | Error _ -> (None [@ox.allow "ox-discarded-result: a refused act has no hit evidence"]));
      shots = (match outcome with Ok r -> r.P.shots | Error _ -> (None [@ox.allow "ox-discarded-result: a refused act has no screenshots"])) } in
    (described ^ ": " ^ result, step) in
  let write_records rows =
    List.fold_left (fun acc record -> let* () = acc in
      let record = `Assoc (List.map (fun (k, v) -> (k, `String v)) record) in
      let* () = on_record (`Assoc [ "kind", `String "planner-record"; "source", `String "planner"; "record", record ]) in
      records := record :: !records; Ok ()) (Ok ()) rows in
  let rec mission goal page =
    if now () >= deadline then finish page "deadline" ~reason:"mission deadline reached" () else
    let () = locate page in
    match drive goal with
    | Error error -> failed error
    | Ok drive ->
        let* page = observe () in
        let () = locate page in
        let status = P.Drive_status.to_string drive.P.status in
        let why = Option.value ~default:status drive.reason in
        if args.dry_run then finish page "planned" ~reason:why ()
        else match status with
        | "done" ->
            if planner && asks_answer args.mission then
              luna Final "JEV reported DONE; give the answer from this page, or take over if it is not here" page
            else finish page "done" ()
        | "deadline" -> finish page "deadline" ~reason:why ()
        | "blocked" | "step-cap" | "failed" -> luna Blocked why page
        | _ -> finish page "error" ~reason:why ()
  and luna ?(image = false) trigger reason (page : observation) =
    if not planner then
      (match trigger with Final -> finish page "done" () | _ -> finish page "blocked" ~reason ())
    else if now () >= deadline then finish page "deadline" ~reason:"mission deadline reached" ()
    else
    let* page = if image then observe ~image:true () else Ok page in
    let n = List.length !turns + 1 in
    let request = { trigger; reason = scrub reason; mission = scrub args.mission;
      secret_names = List.map fst secrets; headless; site = !site;
      history = !history; url = page.url; title = page.title;
      text = (if String.length page.text > 6000 then String.sub page.text 0 6000 else page.text);
      snapshot = { page.snapshot with P.rows = List.filteri (fun i _ -> i < 250) page.snapshot.rows };
      image_input = page.image_input; downloads = page.downloads } in
    let reply = handler.plan request in
    let record ?(steps = []) answer note usage =
      turns := P.{ n; trigger = trigger_name trigger;
        answer; steps; reason = Some (scrub note); usage } :: !turns in
    match reply with
    | Error error -> record "error" error.P.message None; failed error
    | Ok { answer; usage } ->
        let name = answer_name answer in
        match answer with
        | Jev goal ->
            record name goal usage;
            history := !history @ [ ("Luna handed back to JEV", goal) ];
            mission goal page
        | Act command ->
            let outcome, step = act page command in
            record ~steps:[ step ] name outcome usage;
            let* page = observe () in luna Holding outcome page
        | Read { quote; note } ->
            let found = quote <> "" && contains ~needle:quote page.text in
            let outcome = if found then "read: " ^ quote else "the quote is not on the page" in
            if found then read_evidence := !read_evidence @ [ quote ];
            history := !history @ [ ("Luna read: " ^ note, outcome) ];
            record name outcome usage;
            luna Holding outcome page
        | Observe_image ->
            record name "screenshot" usage;
            luna ~image:true Holding "the screenshot of the current page is attached" page
        | Notify message ->
            let outcome = notify (scrub message) in
            unattended := `Assoc ["kind",`String "notify";"message",`String (scrub message);"outcome",`String (if Result.is_ok outcome then "sent" else "failed")] :: !unattended;
            record name message usage;
            luna Holding (if Result.is_ok outcome then "the notification was sent" else "the notification failed") page
        | Fail why -> record name why usage; finish page "failed" ~reason:why ()
        | Done { result; evidence; records = rows } ->
            record name result usage;
            let* () = write_records rows in
            finish page "done" ~result ~evidence:(evidence @ !read_evidence) ()
        | Handoff why ->
            record name why usage;
            let started = now () in
            let outcome = handler.hand_off ~reason:(scrub why) in
            let code = match outcome with Error error -> P.Error_code.to_string error.P.code | Ok _ -> "" in
            let expired = code = "timeout" and canceled = code = "canceled-by-operator" in
            unattended := `Assoc ["kind",`String "handoff";"reason",`String (scrub why);"elapsed_ms",`Int (ms (now () -. started));"outcome",`String (if canceled then "canceled-by-operator" else if expired then "expired" else if Result.is_ok outcome then "resumed" else "failed")] :: !unattended;
            (match outcome with
             | Error _ when canceled -> finish page "canceled-by-operator" ~reason:"the operator canceled the handoff" ()
             | Error _ when expired ->
                 let _expiry_notification = notify "the agent gave up waiting; the tab is still open" [@@ox.allow "ox-discarded-result: best effort: expiry notification"] in
                 finish page "handoff-expired" ~reason:(scrub why) ()
             | Error error -> failed error
             | Ok _ -> let* page = observe () in luna Holding "the human handed the tab back" page) in
  if args.max_steps <= 0 || args.deadline_s <= 0 then Error (invalid "drive limits must be positive")
  else
    let start = match args.start_url with Some url -> Some url | None -> (match starting_urls args.mission with [url] -> Some url | _ -> None) in
    let* () = match start with None -> Ok () | Some url -> if valid_start_url url then (if args.dry_run then Ok () else handler.navigate url) else Error (invalid "invalid start URL") in
    let* page = observe () in mission args.mission page)
