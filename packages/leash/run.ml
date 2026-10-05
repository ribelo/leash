(* L31 run-vj48 run-9ypy run-4mzm (docs/issues/run/01-run.md, milestone 7): the run loop —
   one mission over the installed playbooks.

   The loop is an effect computation over a local handler token, exactly as the drive is
   (drive-8n2z, ox ADR-0006): Select_playbook, Select_procedure, Fill_args,
   Execute_step, Verify and Plan are the six judgments of story 37, performed through a
   token that cannot escape this module; Observe, Navigate and Hand_off are the loop's own
   perception, its playbook switch and the ending a planner's handoff asks for. Production
   builds the handler over the registry and the models service (Tabs.run); a scripted test
   builds its own; a dry run is the same computation with dry_run set. Nothing here touches
   a browser, a model or a clock: now is the caller's.

   OxCaml local mode annotations below are not parsed by ocamlformat 0.29. Keep this file
   in .ocamlformat-ignore until the formatter supports them. *)
module P = Protocol

(* ---------- The loop's vocabulary ---------- *)

type observation = {
  url : string;
  title : string;
  text : string;
      (* run-4j1v run-xqh8: the page's visible text, which the checkers and the text
         helper read. It never reaches the upper levels (run-pvmc). *)
  dialog : P.dialog option;
  rows : (string * string) list;
  downloads : (string * string * string) list;
  snapshot : P.snapshot;
  image_input : bytes option;
      (* takeover: private PNG bytes for Luna's image input, when it asked to see the page. *)
}

type choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : P.run_usage option;
  judgments : P.playbook_choice list;
}
(** An upper-level decision. Probability, confidence and usage describe JEV; [key]
    may be the reviewed choice. [judgments] preserves each original answer in order. *)

let wire_choice (choice : choice) : P.run_choice =
  {
    key = choice.key;
    probabilities = choice.probabilities;
    confidence = choice.confidence;
    usage = choice.usage;
  }

type question = {
  name : string;
  instructions : string;
  criteria : (string * string) list;
  state : Yojson.Safe.t;
}
(** One choice question as the loop asks it: the question's name on the wire, the
    instruction text, the criteria (key, description) and the small state of story 18. *)

type step_request = {
  goal : string;
  hint : string option;
  recent : Jev_request.recent_action list;
  max_steps : int;
  stop_on_navigation : bool;
  deadline_s : int;
  dry_run : bool;
  script_offers : url:string -> text:string -> Jev_request.offered_script list;
  on_script : url:string -> string -> (Jev_request.script_effect, P.error) result;
}
(** run-d82w: one playbook step as the operator level receives it — the goal with the
    hint shaping it, and the step's own cap and deadline. *)

type script_outcome =
  | Collected of { value : Yojson.Safe.t; records : int; bytes : int; elapsed_ms : int }
  | Rejected of { reason : string; elapsed_ms : int }
(** extr-8o1h: what a script step came to. [Collected] is a result that fit its shape;
    [Rejected] is a script that threw, whose result did not fit or was too large — the
    procedure's step failed, and the reason is in the trace. *)

type plan_trigger = Blocked | Expectation | Final | Holding
(** takeover: why Luna is asked. JEV answered BLOCKED, stalled or reached its step cap;
    an expectation failed; JEV reported DONE on a mission that asks for an answer; or
    Luna holds the page and its last action came back. *)

type candidate = Playbook.procedure

type plan_answer =
  | Jev of string
  | Act of Protocol.planner_action
  | Read of { quote : string; note : string }
  | Observe_image
  | Run of string
  | Notify of string
  | Handoff of string
  | Done of { result : string; evidence : string list; records : (string * string) list list }
  | Fail of string
(** takeover: what Luna does while it holds the page. [Jev goal] hands control back to
    JEV with [goal] as its goal; [Run] runs a playbook procedure or script by name. *)

type plan_reply = { answer : plan_answer; usage : P.run_usage option }

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  secret_names : string list;
  headless : bool;
      (* revert-r9ka: nobody can see the browser; handoff is neither offered nor accepted. *)
  site : string option;
  notes : string option;
  history : (string * string) list;
      (* What happened so far, oldest first: each JEV stint and each of Luna's actions. *)
  url : string;
  title : string;
  text : string;
  snapshot : Protocol.snapshot;
  image_input : bytes option;
  downloads : (string * string * string) list;
  offered : (string * string) list;
      (* The site playbook's procedures and scripts Luna may [Run], name and description. *)
}

type levels = {
  choose :
    deadline:Ox.Duration.t -> question -> (choice, P.error) result;
  score :
    deadline:Ox.Duration.t -> sentence:string -> state:Yojson.Safe.t -> (float, P.error) result;
  plan :
    deadline:Ox.Duration.t -> plan_request -> (plan_reply, P.error) result;
}
(** run-7blx: the three upper-level calls as one seam over one models service, so a
    scripted test replaces the model with a function and production passes
    {!Models.levels}: the choice questions of the two levels, the score question the
    judgment checkers ask, and the planner turn. *)

type handler = {
  observe : image:bool -> unit -> (observation, P.error) result;
  navigate : string -> (unit, P.error) result;
      (** run-xh5d: the entry navigation of a playbook switch. *)
  choose : question -> (choice, P.error) result;
  text_value : Text_helper.context -> (string option, P.error) result;
      (** run-5rll: the text helper, one call per argument the mission does not supply. *)
  step : step_request -> (P.drive_result, P.error) result;
      (** run-d82w: the operator level — exactly one drive call per playbook step. *)
  verify :
    pages:Playbook.page list ->
    checks:(string * Playbook.checker) list ->
    timeout_s:int ->
    (P.run_expectation list * observation, P.error) result;
      (** run-xflk run-vbys: the checkers first, the JEV score only where no checker
          applies, each expectation with its verdict. [pages] are the current playbook's
          page kinds, which the [page_kind] checker is decided against. The observation it
          returns is the one it judged. *)
  plan : plan_request -> (plan_reply, P.error) result;
      (** revert-24kr: the optional planner, asked only at {!plan_trigger}'s three points. *)
  act : P.planner_action -> (P.action_result, P.error) result;
      (** takeover: Luna's own action on the page, through the public action path. *)
  hand_off : reason:string -> (P.tab_info, P.error) result;
      (** run-klp9: the planner's handoff, which leaves the tab with the human. *)
  script :
    Playbook.script -> args:(string * string) list -> (script_outcome, P.error) result;
      (** extr-8o1h: run one of the current playbook's scripts on the page. *)
}

type args = {
  mission : string;
  max_steps : int;
  start_url : string option;
  max_procedures : int;
  deadline_s : int;
  dry_run : bool;
  max_plans : int;  (** The planner consultation cap, 6 by default. *)
  expect : string list;
      (** run-4j1v: the mission's own expectations, which DONE is verified against
          independently of the last procedure. Empty until L32's planner attaches them —
          and, from L31 on, whatever a caller states directly. *)
}

let of_args (args : P.run_args) : args =
  {
    mission = args.P.mission;
    max_steps = Option.value ~default:256 args.P.max_steps;
    start_url = args.P.start_url;
    max_procedures = Option.value ~default:40 args.P.max_procedures;
    deadline_s = Option.value ~default:600 args.P.deadline_s;
    dry_run = Option.value ~default:false args.P.dry_run;
    max_plans = 6;
    expect = Option.value ~default:[] args.P.expect;
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

let last n xs =
  let rec drop k = function
    | [] -> []
    | rest when k <= 0 -> rest
    | _ :: tail -> drop (k - 1) tail
  in
  drop (max 0 (List.length xs - n)) xs

(* fly-mepw: file identity, not hostname, keeps same-site knowledge distinct. *)
let book_id (book : Playbook.loaded) = "book:" ^ book.file

let installed_playbooks books =
  List.sort_uniq (fun a b -> String.compare (book_id a) (book_id b)) books

(* The drive's status is a closed wire string in the protocol's interface, so the loop
   compares it by name rather than by constructor. *)
let drive_is name (status : P.Drive_status.t) = P.Drive_status.to_string status = name

let trigger_name = function
  | Blocked -> "blocked" | Expectation -> "expectation" | Final -> "answer" | Holding -> "holding"

let answer_name = function
  | Jev _ -> "jev"
  | Act _ -> "act"
  | Read _ -> "read"
  | Observe_image -> "observe"
  | Run _ -> "run"
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

let failures (results : P.run_expectation list) =
  results
  |> List.filter (fun (result : P.run_expectation) -> not result.P.passed)
  |> List.map (fun (result : P.run_expectation) -> result.P.sentence)
  |> String.concat "; "


(* revert-eft1 revert-24kr revert-apgf revert-bqrq (ADR-0015): drive is JEV's loop. The
   decision model drives every step over the element table (Drive); the playbook's
   procedures and scripts are offered to it as operations. The planner is optional and
   only consulted: on BLOCKED (or a stopped loop), when a procedure's expectation fails,
   and once at the end of a mission that asks for an answer. *)
let loop ~handler ~now ~installed
    ?(planner = true) ?(headless = false) ?(secrets = []) ?(on_secrets = fun _ -> ()) ?(on_book = fun _ -> ())
    ?(on_record = fun _ -> Ok ()) ?(notify = fun _ -> Ok ())
    ?(on_arguments = fun _ -> ()) ?(pause_ms = fun _ -> ()) (args : args) =
  let calls = Hashtbl.create 8 and priced = ref 0 and reported_cost = ref 0. in
  let note = function
    | Model_usage.Start kind -> Hashtbl.replace calls kind (1 + Option.value ~default:0 (Hashtbl.find_opt calls kind))
    | Model_usage.Reported (_, Some cost) -> incr priced; reported_cost := !reported_cost +. cost
    | Model_usage.Reported (_, None) -> () in
  Model_usage.with_meter note (fun () ->
  on_secrets secrets;
  let ( let* ) = Result.bind in
  let deadline = now () +. float_of_int args.deadline_s in
  let scrub text = P.redact_string secrets text in
  let json value = P.redact_json secrets value in
  let observe ?(image = false) () =
    let* (page : observation) = handler.observe ~image () in
    let* snapshot = match P.snapshot_of_yojson (json (P.yojson_of_snapshot page.snapshot)) with
      | Ok snapshot -> Ok snapshot
      | Error _ -> Error (internal (scrub "secret redaction invalidated page schema")) in
    Ok { url = scrub page.url; title = scrub page.title; text = scrub page.text;
      snapshot; dialog=snapshot.dialog; image_input = page.image_input;
      rows = List.map (fun (role, name) -> (scrub role, scrub name)) page.rows;
      downloads = List.map (fun (name, mime, state) -> (scrub name, scrub mime, scrub state)) page.downloads } in
  let turns = ref [] and procedures = ref [] and history = ref [] in
  let known = ref [] in
  (* A playbook procedure that failed in this mission is not offered again in it. *)
  let spent = ref [] in
  let total_steps = ref 0 and operator_steps = ref [] and operator_state = ref None in
  let checks = ref [] and unattended = ref [] in
  let records = ref [] and current_site = ref None and read_evidence = ref [] in
  (* dmod-l44q: over every drive, the screenshots sent to the decision model and each of
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
  let script_calls = ref [] in
  let current_book = ref None in
  let remaining () = max 1 (int_of_float (deadline -. now ())) in
  let accounting () =
    let count = Hashtbl.fold (fun _ count total -> count + total) calls 0 in
    let unreported = max 0 (count - !priced) in
    let by_kind = Hashtbl.fold (fun kind count acc -> (kind, `Int count) :: acc) calls [] |> List.sort compare in
    count, (if unreported = 0 then Some !reported_cost else None),
    ["model_calls_by_kind", `Assoc by_kind; "reported_cost", `Float !reported_cost; "cost_unreported", `Int unreported] in
  let finish (page : observation) name ?result ?(evidence = []) ?reason () =
    let call_count, model_cost, usage_fields = accounting () in
    let reply = P.{ result = Option.map scrub result; evidence = List.map scrub evidence;
      navigator_steps = !total_steps;
      reasoning_summary = None; secrets_for_operator = [];
      unattended = List.rev !unattended; detail = None; playbook_choices = []; status = status name;
      answer = Option.map scrub result; site = !current_site;
      procedures = List.rev !procedures; mission_expectations = !checks;
      planner_turns = List.rev !turns;
      collected = List.length !records;
      data = `Assoc (["count", `Int (List.length !records); "first", `List (List.rev !records)]
        @ ["image_parts", `Int !image_parts;
           "decision_input_tokens", `List (List.map (fun n -> `Int n) !decision_tokens)]
        @ usage_fields);
      model_calls = call_count; model_cost; operator_steps = List.rev !operator_steps;
      operator_state = !operator_state;
      output_kinds = (if !records = [] then [] else ["script-record"]) @ (if !operator_state=None then [] else ["operator-state"]);
      final = page.snapshot; reason = Option.map scrub reason; trace_path = None } in
    match P.run_result_of_yojson (json (P.yojson_of_run_result reply)) with
    | Ok clean -> Ok clean
    | Error why -> Error (internal (scrub why)) in
  let failed error =
    let count, cost, usage_fields = accounting () in
    let original = match error.P.detail with Some (`Assoc fields) -> fields | _ -> [] in
    let fields = usage_fields @ ["model_calls", `Int count; "model_cost", (match cost with Some cost -> `Float cost | None -> `Null);
      "navigator_steps", `Int !total_steps;
      "planner_turns", `List (List.map P.yojson_of_planner_turn (List.rev !turns));
      "procedures", `List (List.map P.yojson_of_run_procedure (List.rev !procedures))] in
    let detail = `Assoc (fields @ List.filter (fun (key, _) -> not (List.mem_assoc key fields)) original) in
    Error { error with P.message = scrub error.P.message; detail = Some (json detail) } in
  let locate (page : observation) =
    let book = List.find_opt (fun (book : Playbook.loaded) ->
      Web_url.host page.url = Some book.playbook.site) installed in
    if book <> !current_book then (current_book := book; on_book book);
    current_site := Option.map (fun (b : Playbook.loaded) -> b.playbook.site) book;
    if !current_site = None then current_site := Web_url.host page.url;
    book in
  let entry ~slug ~key ~drives ~scripts ~expectations ~outcome ~at ~reason =
    P.{ revision = None; slug = scrub slug; site = Option.value ~default:"" !current_site;
      planned = false; attempts = 1;
      choice = { key; probabilities = `Null; confidence = 1.; usage = None };
      drives; scripts; expectations; outcome; elapsed_ms = ms (now () -. at); reason } in
  (* One run of JEV's loop on a goal, recorded in the trace. *)
  let drive ?(script_offers = fun ~url:_ ~text:_ -> []) ?(on_script = fun ~url:_ _ -> Error (invalid "no script runner")) ~stop_on_navigation goal =
    let* () = match unsafe_action goal with
      | Some intent when not (authorises args.mission intent) ->
          Error (invalid ("refused " ^ intent ^ ": mission does not name that action"))
      | _ -> Ok () in
    let request = { goal; hint = None; recent = []; max_steps = args.max_steps; stop_on_navigation;
      deadline_s = remaining (); dry_run = args.dry_run; script_offers; on_script } in
    let* raw = handler.step request in
    let* drive = match P.drive_result_of_yojson (json (P.yojson_of_drive_result raw)) with
      | Ok clean -> Ok clean
      | Error _ -> Error (internal (scrub "secret redaction invalidated the drive result")) in
    total_steps := !total_steps + List.length drive.P.steps;
    operator_steps := List.rev_append drive.steps !operator_steps;
    operator_state := drive.operator_state;
    absorb drive.operator_state;
    history := !history @ [ (scrub goal, P.Drive_status.to_string drive.status ^ Option.fold ~none:"" ~some:(fun r -> ": " ^ scrub r) drive.reason) ];
    Ok drive in
  let fill_arguments (declarations : Playbook.arg_decl list) =
    List.fold_left (fun acc (arg : Playbook.arg_decl) ->
      let* () = acc in
      if List.mem_assoc arg.name !known then Ok () else
      let* value = match arg.source with
        | Playbook.Const (`String value) -> Ok (Some value)
        | Playbook.Const value -> Ok (Some (Yojson.Safe.to_string value))
        | Playbook.From_mission _ -> handler.text_value Text_helper.{
            goal=scrub args.mission; field={label=arg.name;role="argument";value=""};
            page_title="procedure argument";page_text="";recent=[]} in
      match value, arg.source with
      | Some value, _ -> known := (arg.name,value)::!known; on_arguments (List.map (fun (k,v) -> k,scrub v) !known); Ok ()
      | None, Playbook.From_mission {optional=true} -> Ok ()
      | None, _ -> Error (invalid ("missing procedure argument " ^ arg.name))) (Ok ()) declarations in
  let candidate_checks = ref [] and collection_key = ref None and seen_records = Hashtbl.create 32 in
  let call_script (script : Playbook.script) arguments =
    let at = now () in
    let outcome = handler.script script ~args:arguments in
    let url = match observe () with Ok page -> page.url | Error _ -> ("" [@ox.allow "ox-discarded-result: an unobservable page has no URL to report"]) in
    let records, bytes, elapsed_ms, error = match outcome with
      | Ok (Collected value) -> value.records, value.bytes, value.elapsed_ms, None
      | Ok (Rejected value) -> 0, 0, value.elapsed_ms, Some (scrub value.reason)
      | Error error -> 0, 0, ms (now () -. at), Some (scrub error.message) in
    script_calls := P.{script=scrub script.name;url;records;bytes;elapsed_ms;error} :: !script_calls;
    outcome in
  (* Records a script returned go to --out once each (the repeat key, when a procedure
     declares one, deduplicates across pages). *)
  (* pilot-1gv0: a script run again on the same page returns the records it already
     returned; each is written once per mission. Without a declared repeat key a record is
     the same when its script, page URL and content are. *)
  let written = Hashtbl.create 64 in
  let store ~url (script : Playbook.script) book value =
    let values = match value with `List values -> values | value -> [value] in
    List.fold_left (fun acc record -> let* () = acc in
      let* duplicate = match !collection_key with
        | None ->
            let id = (script.name, url, Yojson.Safe.to_string record) in
            let seen = Hashtbl.mem written id in
            Hashtbl.replace written id (); Ok seen
        | Some key -> (match record with
            | `Assoc fields -> (match List.assoc_opt key fields with
                | None | Some `Null -> Error (invalid ("repeat record is missing key " ^ scrub key))
                | Some value -> let id = key, Yojson.Safe.to_string value in
                    let duplicate = Hashtbl.mem seen_records id in
                    Hashtbl.replace seen_records id (); Ok duplicate)
            | _ -> Error (invalid "repeat record must be an object")) in
      if duplicate then Ok () else
      let record = json record in
      let tagged = `Assoc ["kind", `String "script-record"; "source", `String "playbook"; "script", `String script.name; "playbook", `String (Option.fold ~none:"" ~some:book_id book); "record", record] in
      let* () = on_record (json tagged) in records := record :: !records; Ok ()) (Ok ()) values in
  let run_script book (script : Playbook.script) call_args =
    let* () = fill_arguments script.args in
    let arguments = match call_args with
      | Some (`Assoc fields) -> List.filter_map (function k, `String v -> Some (k, Playbook.substitute !known v) | _ -> None) fields
      | _ -> [] in
    let arguments = arguments @ List.filter_map (fun (arg : Playbook.arg_decl) ->
      if List.mem_assoc arg.name arguments then None
      else Option.map (fun value -> arg.name,value) (List.assoc_opt arg.name !known)) script.args in
    let* output = call_script script arguments in
    match output with
    | Rejected {reason; _} -> Error (invalid reason)
    | Collected {value; records = n; _} ->
        let url = match observe () with Ok page -> page.url | Error _ -> ("" [@ox.allow "ox-discarded-result: an unobservable page has no URL; records then compare by script and content"]) in
        let* () = store ~url script book value in Ok n in
  let rec execute_candidate depth (proc : Playbook.procedure) =
    let previous_key = !collection_key in
    Option.iter (fun (repeat : Playbook.repeat) -> collection_key := Some repeat.key) proc.repeat;
    let outcome =
    if depth > 8 then Error (invalid "procedure nesting exceeds eight") else
    let* () = fill_arguments (Option.value ~default:[] proc.args) in
    let book = !current_book in
    let rec steps = function
      | [] -> Ok ()
      | Playbook.Goal goal :: rest ->
          let goal_text = Playbook.substitute !known goal.goal ^ Option.fold ~none:"" ~some:(fun hint -> "\n" ^ hint) goal.hint in
          let* drive = drive ~stop_on_navigation:false goal_text in
          let status = P.Drive_status.to_string drive.P.status in
          if status = "done" then steps rest
          else Error (invalid (Printf.sprintf "goal %S ended %s" goal.goal status))
      | Playbook.Script call :: rest -> (
          match Option.bind book (fun b -> Playbook.script_named b call.script) with
          | None -> Error (invalid ("unknown script " ^ call.script))
          | Some script -> let* _ = run_script book script call.args in steps rest)
      | Playbook.Use call :: rest -> (
          match Option.bind book (fun b -> List.find_opt (fun (p : Playbook.procedure) -> p.slug = call.use) b.playbook.procedures) with
          | None -> if call.optional = Some true then steps rest else Error (invalid ("unknown procedure " ^ call.use))
          | Some p ->
              let saved = !known in
              Option.iter (function `Assoc values -> known := List.filter_map (function key,`String value -> Some (key,Playbook.substitute saved value) | _ -> None) values @ saved | _ -> ()) call.args;
              let outcome = execute_candidate (depth + 1) p in
              known := saved;
              let* () = outcome in steps rest) in
    let* () = steps proc.steps in
    let* page = observe () in
    let pages = Option.fold ~none:[] ~some:(fun (b : Playbook.loaded) -> b.playbook.pages) book in
    let resolved = List.map (fun sentence -> let sentence=Playbook.substitute !known sentence in
      sentence,(match Playbook.resolve pages sentence with Ok checker -> checker | Error _ -> Playbook.Judgment sentence)) proc.expect in
    let* verdicts, _ = if resolved=[] then Ok ([],page) else handler.verify ~pages ~checks:resolved ~timeout_s:(min Playbook.expect_timeout_s (remaining ())) in
    candidate_checks := !candidate_checks @ verdicts;
    if not (List.for_all (fun (v : P.run_expectation) -> v.passed) verdicts) then
      Error (invalid ("procedure expectations failed: " ^ failures verdicts)) else
    match proc.repeat with
    | None -> Ok ()
    | Some repeat ->
        let terminal () = match repeat.until with
          | Playbook.Expectation sentence ->
              let checker=match Playbook.resolve pages sentence with Ok checker -> checker | Error _ -> Playbook.Judgment sentence in
              let* verdicts,_=handler.verify ~pages ~checks:[sentence,checker] ~timeout_s:1 in
              Ok (verdicts<>[] && List.for_all (fun (v : P.run_expectation) -> v.passed) verdicts)
          | Playbook.Script_check name ->
              match Option.bind book (fun b -> Playbook.script_named b name) with
              | None -> Error (invalid ("unknown repeat control " ^ name))
              | Some script ->
                  let* () = fill_arguments script.args in
                  let arguments = List.filter_map (fun (arg : Playbook.arg_decl) -> Option.map (fun value -> arg.name,value) (List.assoc_opt arg.name !known)) script.args in
                  let* output=call_script script arguments in
                  (match output with
                  | Rejected {reason;_} -> Error (invalid reason)
                  | Collected {value=`Assoc fields;_} ->
                      (match List.assoc_opt "done" fields with Some (`Bool done_) -> Ok done_ | _ -> Error (invalid "repeat control must return boolean done"))
                  | Collected _ -> Error (invalid "repeat control must return an object")) in
        let rec rounds n =
          let* done_=terminal () in
          if done_ then Ok () else if n >= repeat.max then Error (invalid "procedure repeat cap")
          else if now () >= deadline then Error (invalid "procedure repeat deadline") else
            match Option.bind !current_book (fun b -> List.find_opt (fun (p : Playbook.procedure) -> p.slug = repeat.next) b.playbook.procedures) with
            | None -> Error (invalid "unknown repeat next procedure")
            | Some next ->
                Option.iter pause_ms repeat.delay_ms;
                let* ()=execute_candidate (depth+1) next in rounds (n+1) in
        rounds 1 in
    collection_key := previous_key; outcome in
  (* revert-eft1: the playbook's procedures and scripts, offered to JEV as operations on
     the page they apply to. *)
  let procedure_prefix = "procedure:" in
  let failed_procedure = ref None in
  let script_offers ~url ~text =
    match !current_book with
    | None -> []
    | Some (book : Playbook.loaded) ->
        let scripts = Playbook.offered_scripts book ~url ~text
          |> List.map (fun (script : Playbook.script) -> Jev_request.{ name = script.name; description = script.description }) in
        let procedures = book.playbook.procedures
          |> List.filter (fun (p : Playbook.procedure) -> not (List.mem p.slug !spent))
          |> List.map (fun (p : Playbook.procedure) -> Jev_request.{ name = procedure_prefix ^ p.slug; description = p.description }) in
        procedures @ scripts in
  let on_script ~url:_ name =
    let book = !current_book in
    if String.starts_with ~prefix:procedure_prefix name then
      let slug = String.sub name (String.length procedure_prefix) (String.length name - String.length procedure_prefix) in
      match Option.bind book (fun b -> List.find_opt (fun (p : Playbook.procedure) -> p.slug = slug) b.playbook.procedures) with
      | None -> Error (invalid ("unknown procedure " ^ slug))
      | Some proc ->
          let at = now () and before_checks = List.length !candidate_checks and before_scripts = List.length !script_calls in
          let outcome = execute_candidate 0 proc in
          let scripts = List.filteri (fun i _ -> i < List.length !script_calls - before_scripts) !script_calls |> List.rev in
          let expectations = List.filteri (fun i _ -> i >= before_checks) !candidate_checks in
          let reason = match outcome with Ok () -> None | Error error -> Some (scrub error.P.message) in
          procedures := entry ~slug ~key:"procedure" ~drives:[] ~scripts ~expectations
            ~outcome:(if Result.is_ok outcome then "done" else "failed") ~at ~reason :: !procedures;
          match outcome with
          | Ok () -> Ok (Jev_request.Script_continue { summary = "procedure " ^ slug ^ " done" })
          | Error error ->
              spent := slug :: !spent;
              failed_procedure := Some (slug, error.P.message);
              Error error
    else
      match Option.bind book (fun b -> Playbook.script_named b name) with
      | None -> Error (invalid ("unknown script " ^ name))
      | Some script ->
          let* n = run_script book script None in
          Ok (Jev_request.Script_continue { summary = Printf.sprintf "%s collected %d records" name n }) in
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
  let offered () =
    match !current_book with
    | None -> []
    | Some (book : Playbook.loaded) ->
        List.map (fun (p : Playbook.procedure) -> (p.slug, p.description)) book.playbook.procedures
        @ List.map (fun (s : Playbook.script) -> (s.name, s.description)) book.scripts in
  (* Luna runs a playbook procedure or script by name. *)
  let run_named name =
    let book = !current_book in
    match Option.bind book (fun b -> List.find_opt (fun (p : Playbook.procedure) -> p.slug = name) b.playbook.procedures) with
    | Some proc -> (match execute_candidate 0 proc with Ok () -> "procedure " ^ name ^ " done" | Error e -> "procedure " ^ name ^ " failed: " ^ scrub e.P.message)
    | None -> (
        match Option.bind book (fun b -> Playbook.script_named b name) with
        | Some script -> (match run_script book script None with Ok n -> Printf.sprintf "script %s returned %d records" name n | Error e -> "script " ^ name ^ " failed: " ^ scrub e.P.message)
        | None -> "no procedure or script named " ^ name) in
  let write_records rows =
    List.fold_left (fun acc record -> let* () = acc in
      let record = `Assoc (List.map (fun (k, v) -> (k, `String v)) record) in
      let* () = on_record (`Assoc [ "kind", `String "planner-record"; "source", `String "planner"; "record", record ]) in
      records := record :: !records; Ok ()) (Ok ()) rows in
  let rec mission goal page =
    if now () >= deadline then finish page "deadline" ~reason:"mission deadline reached" () else
    let _ = locate page in
    failed_procedure := None;
    match drive ~script_offers ~on_script ~stop_on_navigation:false goal with
    | Error error -> failed error
    | Ok drive ->
        let* page = observe () in
        let _ = locate page in
        let status = P.Drive_status.to_string drive.P.status in
        let why = Option.value ~default:status drive.reason in
        if args.dry_run then finish page "planned" ~reason:why ()
        else match status, !failed_procedure with
        | _, Some (slug, message) -> luna Expectation (Printf.sprintf "procedure %s failed: %s" slug message) page
        | "done", _ -> judged page
        | "deadline", _ -> finish page "deadline" ~reason:why ()
        | ("blocked" | "step-cap" | "failed"), _ -> luna Blocked why page
        | _, _ -> finish page "error" ~reason:why ()
  (* takeover: Luna holds the page until it hands it back to JEV or ends the mission;
     only the deadline bounds it. *)
  and luna ?(image = false) trigger reason (page : observation) =
    if not planner then
      (match trigger with Final -> finish page "done" () | _ -> finish page "blocked" ~reason ())
    else if now () >= deadline then finish page "deadline" ~reason:"mission deadline reached" ()
    else
    let* page = if image then observe ~image:true () else Ok page in
    let n = List.length !turns + 1 in
    let request = { trigger; reason = scrub reason; mission = scrub args.mission;
      secret_names = List.map fst secrets; headless; site = Option.map scrub !current_site;
      notes = Option.bind !current_book (fun (b : Playbook.loaded) -> b.playbook.notes);
      history = !history; url = page.url; title = page.title;
      text = (if String.length page.text > 6000 then String.sub page.text 0 6000 else page.text);
      snapshot = { page.snapshot with P.rows = List.filteri (fun i _ -> i < 250) page.snapshot.rows };
      image_input = page.image_input; downloads = page.downloads; offered = offered () } in
    let reply = handler.plan request in
    let record ?(steps = []) answer note usage =
      turns := P.{ candidates = []; chosen = None; n; trigger = trigger_name trigger;
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
        | Run what ->
            let outcome = run_named what in
            history := !history @ [ ("Luna ran " ^ what, outcome) ];
            record name outcome usage;
            let* page = observe () in luna Holding outcome page
        | Notify message ->
            let outcome = notify (scrub message) in
            unattended := `Assoc ["kind",`String "notify";"message",`String (scrub message);"outcome",`String (if Result.is_ok outcome then "sent" else "failed")] :: !unattended;
            record name message usage;
            luna Holding (if Result.is_ok outcome then "the notification was sent" else "the notification failed") page
        | Fail why -> record name why usage; finish page "failed" ~reason:why ()
        | Done { result; evidence; records } ->
            record name result usage;
            let* () = write_records records in
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
             | Ok _ -> let* page = observe () in luna Holding "the human handed the tab back" page)
  and judged page =
    let pages = Option.fold ~none:[] ~some:(fun (b : Playbook.loaded) -> b.Playbook.playbook.pages) !current_book in
    let resolved = List.map (fun sentence -> sentence, (match Playbook.resolve pages sentence with Ok checker -> checker | Error _ -> Playbook.Judgment sentence)) args.expect in
    let* verdicts, page = if resolved = [] then Ok ([], page) else handler.verify ~pages ~checks:resolved ~timeout_s:(min 5 (remaining ())) in
    checks := verdicts;
    if not (List.for_all (fun (v : P.run_expectation) -> v.passed) verdicts) then
      luna Expectation ("mission expectations failed: " ^ failures verdicts) page
    else if planner && asks_answer args.mission then
      luna Final "JEV reported DONE; give the answer from this page, or take over if it is not here" page
    else finish page "done" () in
  on_arguments !known;
  if args.max_steps <= 0 || args.deadline_s <= 0 then Error (invalid "drive limits must be positive")
  else
    let start = match args.start_url with Some url -> Some url | None -> (match starting_urls args.mission with [url] -> Some url | _ -> None) in
    let* () = match start with None -> Ok () | Some url -> if valid_start_url url then (if args.dry_run then Ok () else handler.navigate url) else Error (invalid "invalid start URL") in
    let* page = observe () in mission args.mission page)
