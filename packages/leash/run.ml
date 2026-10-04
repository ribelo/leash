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

type plan_trigger = Blocked | Failed | Arguments | Challenge
(** run-w7ke (L32 wires the plan; L31 asks it and takes its answer): the three points JEV
    stopped — the procedure level answered BLOCKED, a procedure failed its expectations
    twice, or an argument the mission does not supply could not be filled. *)

type leg = { goal : string; outcome : string; steps : P.step list }

type candidate = Playbook.procedure * [ `Installed | `Draft of string ]

type plan_answer = Leg of string | Read of { quote : string; note : string } | Act of Protocol.planner_action | Notify of string | Done of { result : string; evidence : string list } | Handoff of string | Fail of string

type plan_reply = {
  reasoning_summary : string option;
  secrets_for_operator : (string * string) list;
  answer : plan_answer;
  expect : string list;
      (* run-2tt3: the mission's own expectations, which the planner may attach beside its
         answer on its first turn — the sentences DONE is then verified against when the
         caller stated none. Ignored on every later turn. *)
  usage : P.run_usage option;
      (* run-obtt: what the turn cost, provider-reported where the model route reports it
         and otherwise its token counts, carried into the run's trace. *)
}
(** One planner turn's answer (run-rq6i), what it attached to the mission (run-2tt3) and
    what it cost (run-obtt). *)

type plan_request = {
  legs : leg list;
  candidates : candidate list;
  secret_names : string list;
  trigger : plan_trigger;
  reason : string;
  mission : string;
  site : string option;
  playbook : Playbook.t option;
      (* run-rq6i: the current playbook in its own schema — its procedures carry their
         slugs, descriptions, expectations and steps, which is what a new procedure has to
         fit — or [None] when the run has not chosen one. *)
  recent : (string * string) list;
      (* run-rq6i: the trace so far, one procedure slug and its outcome per entry, oldest
         first. *)
  arguments : (string * string) list;
  snapshot : Protocol.snapshot;
  planner_actions : int;
  page_kind : string option;
  title : string;
  url : string;
  text : string;
      (* run-rq6i, the one level page text reaches: the planner gets the page summary plus
         this bounded text, while the two choice levels never see it (run-pvmc). *)
  downloads : (string * string * string) list;
}
(** What one planner turn is asked from (run-rq6i, L32): the mission, the point JEV stopped
    and why, the current playbook, the run so far, the arguments known and the observed
    page. *)

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
  observe : unit -> (observation, P.error) result;
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
      (** run-l06s run-vbys: the checkers first, the JEV score only where no checker
          applies, each expectation with its verdict. [pages] are the current playbook's
          page kinds, which the [page_kind] checker is decided against. The observation it
          returns is the one it judged. *)
  plan : plan_request -> (plan_reply, P.error) result;
      (** run-w7ke run-rq6i: the planner turn — Luna in production, a scripted answer in a
          test — asked only at the three triggers and only while the turn cap allows it. *)
  propose : site:string -> Playbook.procedure -> (string, P.error) result;
      (** run-m0r8: write a planner-written procedure that ran and passed its expectations
          to the XDG state directory, and answer the path written. The run reports it; only
          the operator's [playbook accept] ever merges it into a playbook. *)
  hand_off : reason:string -> (P.tab_info, P.error) result;
      (** run-klp9: a planner's handoff, which leaves the tab with the human. *)
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
  max_plans : int;  (** run-obtt: the planner turn cap, 3 by default. *)
  expect : string list;
      (** run-4j1v: the mission's own expectations, which DONE is verified against
          independently of the last procedure. Empty until L32's planner attaches them —
          and, from L31 on, whatever a caller states directly. *)
}

let of_args (args : P.run_args) : args =
  {
    mission = args.P.mission;
    max_steps = Option.value ~default:15 args.P.max_steps;
    start_url = args.P.start_url;
    max_procedures = Option.value ~default:40 args.P.max_procedures;
    deadline_s = Option.value ~default:600 args.P.deadline_s;
    dry_run = Option.value ~default:false args.P.dry_run;
    max_plans = 12;
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

let trigger_name = function Blocked -> "blocked" | Failed -> "failed" | Arguments -> "arguments" | Challenge -> "challenge"

let answer_name = function
  | Leg _ -> "leg"
  | Read _ -> "read"
  | Act _ -> "act"
  | Notify _ -> "notify"
  | Done _ -> "done"
  | Handoff _ -> "handoff"
  | Fail _ -> "fail"

let pilot_choice_json answer =
  let fields = match answer with
    | Leg goal -> ["goal", `String goal]
    | Read {quote;note} -> ["quote", `String quote; "note", `String note]
    | Act command -> ["action", `Assoc ["cmd", `String (P.command_name command); "args", P.args_to_json command]]
    | Notify message -> ["message", `String message]
    | Handoff reason | Fail reason -> ["reason", `String reason]
    | Done {result;evidence} -> ["result", `String result; "evidence", `List (List.map (fun value -> `String value) evidence)] in
  `Assoc (("answer", `String (answer_name answer)) :: fields)

let failures (results : P.run_expectation list) =
  results
  |> List.filter (fun (result : P.run_expectation) -> not result.P.passed)
  |> List.map (fun (result : P.run_expectation) -> result.P.sentence)
  |> String.concat "; "


(* pilot-ukoh pilot-eu1c pilot-rdjv: only the pilot owns mission completion. *)
let loop ~handler ~now ~installed ?(page_kinds = Page_kind.session ())
    ?(drafts = fun ~site:_ ~kind:_ -> []) ?learning
    ?(secrets = []) ?(on_secrets = fun _ -> ()) ?(on_book = fun _ -> ())
    ?(on_record = fun _ -> Ok ()) ?(notify = fun _ -> Ok ())
    ?(challenge = fun _ -> None) ?(challenge_attempt = true) ?(challenge_turns = 2)
    ?(planner_actions = 5)
    ?(planner_action = fun _ -> Error (invalid "pilot actions unavailable"))
    ?(on_planner_step = fun _ -> ()) ?(on_arguments = fun _ -> ())
    ?(pause_ms = fun _ -> ()) (args : args) =
  let calls = Hashtbl.create 8 and priced = ref 0 and reported_cost = ref 0. in
  let note = function
    | Model_usage.Start kind -> Hashtbl.replace calls kind (1 + Option.value ~default:0 (Hashtbl.find_opt calls kind))
    | Model_usage.Reported (_, Some cost) -> incr priced; reported_cost := !reported_cost +. cost
    | Model_usage.Reported (_, None) -> () in
  Model_usage.with_meter note (fun () ->
  ignore (drafts, challenge, challenge_attempt, challenge_turns, pause_ms);
  let ( let* ) = Result.bind in
  let deadline = now () +. float_of_int args.deadline_s in
  let private_values = ref secrets in
  let scrub text = P.redact_string !private_values text in
  let json value = P.redact_json !private_values value in
  let observe () =
    let* (page : observation) = handler.observe () in
    let* snapshot = match P.snapshot_of_yojson (json (P.yojson_of_snapshot page.snapshot)) with
      | Ok snapshot -> Ok snapshot
      | Error _ -> Error (internal (scrub "secret redaction invalidated page schema")) in
    Ok { url = scrub page.url; title = scrub page.title; text = scrub page.text;
      snapshot; dialog=snapshot.dialog;
      rows = List.map (fun (role, name) -> (scrub role, scrub name)) page.rows;
      downloads = List.map (fun (name, mime, state) -> (scrub name, scrub mime, scrub state)) page.downloads } in
  let turns = ref [] and procedures = ref [] and legs = ref [] in
  let successful = ref [] and used = ref [] and known = ref [] in
  let total_steps = ref 0 and operator_steps = ref [] and operator_state = ref None in
  let generated = ref [] and expectations = ref args.expect and checks = ref [] and unattended = ref [] in
  let records = ref [] and sites = ref [] and current_site = ref None in
  let script_calls = ref [] in
  let reasoning = ref None and current_book = ref None and planned_choice = ref None in
  let remaining () = max 1 (int_of_float (deadline -. now ())) in
  let finish (page : observation) name ?result ?(evidence = []) ?reason () =
    Option.iter (fun memory ->
      List.iter (fun site -> Learning.after_mission memory ~site
        ~used:(List.filter_map (fun (s, item) -> if s = site then Some item else None) !used)
        ~outcome:(if name = "done" then `Done else `Failed)
        ~verified:(name = "done" && List.for_all (fun (c : P.run_expectation) -> c.passed) !checks)) !sites;
      if name = "done" then Option.iter (fun site ->
        Learning.record_legs memory ~site ~mission:(scrub args.mission)
          ~args:(List.map (fun (key,value) -> scrub key,scrub value) !known) ~legs:!successful
          (* pilot-3egp: without an expectation from the pilot, the remembered procedure
             checks where the mission ended (U2 on Tauron finished done and wrote nothing). *)
          ~expect:(List.map scrub (match !expectations with
            | [] -> [ "the mission is complete: " ^ args.mission ]
            | expectations -> expectations))) !current_site) learning;
    let call_count = Hashtbl.fold (fun _ count total -> count+total) calls 0 in
    let unreported = max 0 (call_count - !priced) in
    let by_kind = Hashtbl.fold (fun kind count acc -> (kind, `Int count)::acc) calls [] |> List.sort compare in
    let reply = P.{ result = Option.map scrub result; evidence = List.map scrub evidence;
      pilot_turns = List.length !turns; navigator_steps = !total_steps;
      reasoning_summary = Option.map scrub !reasoning; secrets_for_operator = [];
      unattended = List.rev !unattended; detail = None; playbook_choices = []; status = status name;
      answer = Option.map scrub result; site = !current_site;
      procedures = List.rev !procedures; mission_expectations = !checks;
      planner_turns = List.rev !turns; proposals = []; installed = [];
      collected = List.length !records;
      data = `Assoc (["count", `Int (List.length !records); "first", `List (List.rev !records)]
        @ (match !planned_choice with None -> [] | Some choice -> ["pilot_choice", choice])
        @ ["model_calls_by_kind", `Assoc by_kind; "reported_cost", `Float !reported_cost; "cost_unreported", `Int unreported]);
      model_calls = call_count; model_cost = (if unreported = 0 then Some !reported_cost else None); operator_steps = List.rev !operator_steps;
      operator_state = !operator_state; output_kinds = (if !records=[] then [] else ["script-record"]) @ (if !operator_state=None then [] else ["operator-state"]); final = page.snapshot;
      reason = Option.map scrub reason; trace_path = None } in
    match P.run_result_of_yojson (json (P.yojson_of_run_result reply)) with
    | Ok clean -> Ok { clean with P.secrets_for_operator = !generated }
    | Error why -> Error (internal (scrub why)) in
  let failed error =
    let detail = `Assoc ["planner_turns", `List (List.map P.yojson_of_planner_turn (List.rev !turns));
      "procedures", `List (List.map P.yojson_of_run_procedure (List.rev !procedures))] in
    Error { error with P.message = scrub error.P.message; detail = Some (json detail) } in
  let infer (page : observation) =
    let book = List.find_opt (fun (book : Playbook.loaded) ->
      Page_kind.host page.url = Some book.playbook.site) installed in
    current_book := book; on_book book;
    current_site := Option.map (fun (b : Playbook.loaded) -> b.playbook.site) book;
    if !current_site = None then current_site := Page_kind.host page.url;
    Option.iter (fun site -> if not (List.mem site !sites) then sites := !sites @ [site]) !current_site;
    let declared = Option.bind book (fun b -> Playbook.page_kind b.playbook.pages ~url:page.url ~text:page.text) in
    let kind, _ = Page_kind.classify page_kinds ~declared ~url:page.url ~title:page.title in
    (if kind.name = "" then None else Some kind.name), book in
  let get_candidates kind book =
    match learning, !current_site with
    | Some memory, Some site -> Learning.candidates memory ~site ~kind
    | _ -> Option.fold ~none:[] ~some:(fun (b : Playbook.loaded) ->
        List.map (fun p -> p, `Installed) b.playbook.procedures) book in
  let record_failed_leg goal outcome reason =
    let goal = scrub goal and reason = scrub reason in
    legs := !legs @ [{goal;outcome;steps=[]}];
    procedures := P.{revision=None;slug=goal;site=Option.value ~default:"" !current_site;planned=true;attempts=1;
      choice={key="leg";probabilities=`Null;confidence=1.;usage=None};
      drives=[{goal;status=(match P.Drive_status.of_string "error" with Ok status -> status | Error _ -> assert false);steps=[];reason=Some reason}];
      scripts=[];expectations=[];outcome;elapsed_ms=0;reason=Some reason} :: !procedures in
  let run_leg goal hint =
    let* () = match unsafe_action goal with
      | Some intent when not (authorises args.mission intent) ->
          let reason = "refused " ^ intent ^ ": mission does not name that action" in
          record_failed_leg goal "refused" reason;
          Error (invalid reason)
      | _ -> Ok () in
    let at = now () in
    let request = { goal; hint; recent = []; max_steps = min 15 args.max_steps; stop_on_navigation = true;
      deadline_s = remaining (); dry_run = false; script_offers = (fun ~url:_ ~text:_ -> []);
      on_script = (fun ~url:_ _ -> Error (invalid "leg script unavailable")) } in
    match handler.step request with
    | Error error -> record_failed_leg goal "failed" error.message; Error error
    | Ok raw ->
        let* drive = match P.drive_result_of_yojson (json (P.yojson_of_drive_result raw)) with Ok clean -> Ok clean | Error _ -> Error (internal (scrub "secret redaction invalidated navigator result")) in
        total_steps := !total_steps + List.length drive.P.steps;
        operator_steps := List.rev_append drive.steps !operator_steps;
        operator_state := drive.operator_state;
        let outcome = P.Drive_status.to_string drive.status in
        legs := !legs @ [{ goal; outcome; steps = drive.steps }];
        if outcome = "done" then successful := !successful @ [goal];
        let entry = P.{ revision = None; slug = goal; site = Option.value ~default:"" !current_site;
          planned = true; attempts = 1;
          choice = { key = "leg"; probabilities = `Null; confidence = 1.; usage = None };
          drives = [{ goal; status = drive.status; steps = drive.steps; reason = drive.reason }];
          scripts = []; expectations = []; outcome; elapsed_ms = ms (now () -. at); reason = drive.reason } in
        procedures := entry :: !procedures;
        Ok () in
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
    let url = match observe () with Ok page -> page.url | Error _ -> "" in
    let records, bytes, elapsed_ms, error = match outcome with
      | Ok (Collected value) -> value.records, value.bytes, value.elapsed_ms, None
      | Ok (Rejected value) -> 0, 0, value.elapsed_ms, Some (scrub value.reason)
      | Error error -> 0, 0, ms (now () -. at), Some (scrub error.message) in
    script_calls := P.{script=scrub script.name;url;records;bytes;elapsed_ms;error} :: !script_calls;
    outcome in
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
          let* () = run_leg (Playbook.substitute !known goal.goal) goal.hint in
          if (List.hd (List.rev !legs)).outcome = "done" then steps rest else Ok ()
      | Playbook.Script call :: rest -> (
          match Option.bind book (fun b -> Playbook.script_named b call.script) with
          | None -> Error (invalid ("unknown script " ^ call.script))
          | Some script ->
              let* () = fill_arguments script.args in
              let arguments = match call.args with
                | Some (`Assoc fields) -> List.filter_map (function k, `String v -> Some (k, Playbook.substitute !known v) | _ -> None) fields
                | _ -> [] in
              let arguments = arguments @ List.filter_map (fun (arg : Playbook.arg_decl) -> Option.map (fun value -> arg.name,value) (List.assoc_opt arg.name !known)) script.args in
              let* output = call_script script arguments in
              (match output with
              | Rejected {reason; _} -> Error (invalid reason)
              | Collected {value; _} ->
                  let values = match value with `List values -> values | value -> [value] in
                  let* () = List.fold_left (fun acc record -> let* () = acc in
                    let* duplicate = match !collection_key with
                      | None -> Ok false
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
                  steps rest))
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
            match Option.bind book (fun b -> List.find_opt (fun (p : Playbook.procedure) -> p.slug=repeat.next) b.playbook.procedures) with
            | None -> Error (invalid "unknown repeat next procedure")
            | Some next ->
                Option.iter pause_ms repeat.delay_ms;
                let* ()=execute_candidate (depth+1) next in rounds (n+1) in
        rounds 1 in
    collection_key := previous_key; outcome in
  let command_row = function
    | P.Click a -> Some a.index | P.Fill a -> Some a.index | P.Select a -> Some a.index
    | P.Press a -> a.index | _ -> None in
  let act (page : observation) command =
    let name = P.command_name command in
    let refusal = match P.check_planner_action page.snapshot command with
      | Error why -> Some why
      | Ok () ->
          let row = Option.bind (command_row command) (fun index -> List.find_opt (fun (r : P.row) -> r.index = index) page.snapshot.rows) in
          let intent = Option.bind row (fun row -> unsafe_action row.name) in
          (match intent with Some intent when not (authorises args.mission intent) -> Some ("refused " ^ intent ^ ": mission does not name that action") | _ -> None) in
    let text = match command with P.Fill a -> Some a.text | _ -> None in
    let at = now () in
    let outcome = match refusal with
      | Some why -> Error (invalid why)
      | None -> let command = match command with
          | P.Fill a -> P.Fill { a with text = Option.value ~default:a.text (List.assoc_opt a.text !private_values) }
          | action -> action in planner_action command in
    let step = P.{ non_repeatable = false; n = 1; command = name; target = None;
      text = Option.map scrub text;
      after = {url = page.url; title = page.title}; elapsed_ms = ms (now () -. at);
      error = (match outcome with Ok _ -> None | Error e -> Some (scrub e.message)) } in
    on_planner_step step;
    (* pilot-x1f3: the pilot's own actions are part of the history it is shown, in JEV's
       language, so it knows a field is already filled (U1 on Tauron, 2026-10-04: twelve
       turns filled the login and never moved on). Secret values stay names. *)
    let target = Option.bind (command_row command) (fun index ->
      List.find_opt (fun (r : P.row) -> r.index = index) page.snapshot.rows) in
    let named = match target with
      | Some r -> Printf.sprintf "the %s named %s" r.role (scrub r.name)
      | None -> "the page" in
    let described = match command with
      | P.Click _ -> "Click " ^ named
      | P.Fill a -> Printf.sprintf "Type %s into %s" (scrub a.text) named
      | P.Select _ -> "Choose an option in " ^ named
      | P.Press a -> Printf.sprintf "Press %s on %s" a.key named
      | _ -> name in
    legs := !legs @ [ { goal = described;
      outcome = (match step.error with None -> "done" | Some why -> "refused: " ^ why);
      steps = [] } ];
    (* pilot-3egp: an act that worked is a leg in JEV's language and is remembered, except
       a fill whose text is a secret name — JEV would type the name. *)
    (match step.error, command with
     | None, P.Fill a when List.mem_assoc a.text !private_values -> ()
     | None, (P.Click _ | P.Select _ | P.Press _ | P.Fill _) -> successful := !successful @ [ described ]
     | _ -> ());
    step in
  let rec turn (page : observation) =
    if now () >= deadline then finish page "deadline" ~reason:"pilot deadline reached" ()
    else if List.length !turns >= args.max_plans then finish page "limit" ~reason:"pilot turn cap reached" ()
    else
      let kind, book = infer page in
      let candidates = get_candidates kind book in
      let snapshot = { page.snapshot with P.rows = List.filteri (fun i _ -> i < 250) page.snapshot.rows } in
      let model_candidates=List.filter_map (fun (proc,source) -> match Playbook.procedure_of_yojson (json (Playbook.yojson_of_procedure proc)) with
        | Error _ -> None | Ok proc -> Some (proc,match source with `Installed -> `Installed | `Draft revision -> `Draft (scrub revision))) candidates in
      let request = { legs = List.map (fun (leg : leg) -> {leg with goal=scrub leg.goal}) !legs; candidates=model_candidates; secret_names = List.map fst !private_values;
        trigger = Blocked; reason = "pilot turn"; mission = scrub args.mission;
        site = Option.map scrub !current_site; playbook = None;
        recent = List.map (fun (leg : leg) -> scrub leg.goal, leg.outcome) !legs; arguments = List.map (fun (key,value) -> scrub key,scrub value) !known;
        snapshot; planner_actions; page_kind = Option.map scrub kind; title = page.title; url = page.url;
        text = if String.length page.text > 6000 then String.sub page.text 0 6000 else page.text;
        downloads = List.map (fun (name, mime, state) -> (scrub name, mime, state)) page.downloads } in
      match handler.plan request with
      | Error error when (match error.P.detail with
          | Some (`Assoc fields) -> List.assoc_opt "code" fields = Some (`String "invalid-response")
          | _ -> false) ->
          (* pilot-x1f3: a reply the decoder refused twice costs a turn, not the mission;
             the pilot sees the refusal in its history and answers again (U2 on Tauron
             ended on one refused act). Bounded by the turn cap. *)
          let n = List.length !turns + 1 in
          turns := P.{n; trigger = "pilot"; answer = "invalid";
            steps = []; reason = Some (scrub error.P.message); usage = None} :: !turns;
          legs := !legs @ [ { goal = "(answer refused)"; outcome = "refused: " ^ scrub error.P.message; steps = [] } ];
          (match observe () with Ok page -> turn page | Error error -> failed error)
      | Error error -> failed error
      | Ok reply ->
          private_values := !private_values @ reply.secrets_for_operator;
          on_secrets !private_values;
          generated := !generated @ reply.secrets_for_operator;
          reasoning := reply.reasoning_summary;
          if !expectations = [] then expectations := reply.expect;
          let n = List.length !turns + 1 in
          let recorded steps reason = turns := P.{n; trigger = "pilot"; answer = answer_name reply.answer;
            steps; reason = Option.map scrub (match reply.reasoning_summary, reason with
              | None, reason -> reason
              | Some summary, None -> Some summary
              | Some summary, Some reason when summary = reason -> Some summary
              | Some summary, Some reason -> Some (summary ^ "\n" ^ reason)); usage = reply.usage} :: !turns in
          let next () = match observe () with Ok page -> turn page | Error error -> failed error in
          if args.dry_run then (planned_choice := Some (json (pilot_choice_json reply.answer)); recorded [] reply.reasoning_summary; finish page "planned" ~reason:(answer_name reply.answer) ())
          else match reply.answer with
          | Done {result; evidence} ->
              recorded [] None;
              if String.trim result = "" then finish page "failed" ~reason:"pilot done requires a result" () else
              let verified = if !expectations = [] then Ok ([], page) else
                let pages = Option.fold ~none:[] ~some:(fun (b : Playbook.loaded) -> b.Playbook.playbook.pages) book in
                let resolved = List.map (fun sentence -> sentence, (match Playbook.resolve pages sentence with Ok checker -> checker | Error _ -> Playbook.Judgment sentence)) !expectations in
                handler.verify ~pages ~checks:resolved ~timeout_s:(min 5 (remaining ())) in
              (match verified with
              | Error error -> failed error
              | Ok (verdicts, final) -> checks := verdicts;
                  if List.for_all (fun (v : P.run_expectation) -> v.passed) verdicts then finish final "done" ~result ~evidence ()
                  else next ())
          | Fail reason -> recorded [] (Some reason); finish page "failed" ~reason ()
          | Handoff reason ->
              recorded [] (Some reason);
              let started=now () in
              let outcome=handler.hand_off ~reason:(scrub reason) in
              let expired=match outcome with Error error -> P.Error_code.to_string error.P.code="timeout" | Ok _ -> false in
              unattended := `Assoc ["kind",`String "handoff";"reason",`String (scrub reason);"elapsed_ms",`Int (int_of_float ((now ()-.started)*.1000.));"outcome",`String (if expired then "expired" else if Result.is_ok outcome then "resumed" else "failed")] :: !unattended;
              (match outcome with
              | Error _ when expired -> ignore (notify "the agent gave up waiting; the tab is still open"); finish page "handoff-expired" ~reason:(scrub reason) ()
              | Error error -> failed error
              | Ok _ -> next ())
          | Read {quote; note} ->
              let why = if contains ~needle:quote page.text && quote <> "" then None else Some "read quote is not on the current page" in
              let step = P.{non_repeatable = false; n = 1; command = "read"; target = None;
                text = Some (scrub quote); after = {url=page.url; title=page.title}; elapsed_ms=0; error=why} in
              on_planner_step step; recorded [step] (Some note); next ()
          | Notify message ->
              let outcome = notify (scrub message) in
              unattended := `Assoc ["kind",`String "notify";"message",`String (scrub message);"outcome",`String (if Result.is_ok outcome then "sent" else "failed")] :: !unattended;
              recorded [] (Some (match outcome with Ok () -> message | Error why -> why)); next ()
          | Act action -> let step = act page action in recorded [step] step.error; next ()
          | Leg goal ->
              recorded [] (Some goal);
              let chosen = List.find_opt (fun ((p : Playbook.procedure), _) -> p.slug = goal) candidates in
              let outcome = match chosen with
                | None -> run_leg goal None
                | Some (proc, revision) ->
                    Option.iter (fun site -> used := !used @ [site, (proc.slug, revision)]) !current_site;
                    let before_checks = List.length !candidate_checks in
                    let before=List.length !legs and old_procedures = !procedures and before_scripts=List.length !script_calls and at=now () in
                    let outcome=execute_candidate 0 proc in
                    let additions=List.filteri (fun i _ -> i>=before) !legs in
                    let steps=List.concat_map (fun (leg : leg) -> leg.steps) additions in
                    let status=if Result.is_ok outcome && List.for_all (fun (leg : leg) -> leg.outcome="done") additions then "done" else "blocked" in
                    legs := List.filteri (fun i _ -> i<before) !legs @ [{goal=scrub goal;outcome=status;steps}];
                    let drives = List.filteri (fun i _ -> i < List.length !procedures - List.length old_procedures) !procedures |> List.rev |> List.concat_map (fun (p : P.run_procedure) -> p.drives) in
                    let scripts = List.filteri (fun i _ -> i < List.length !script_calls - before_scripts) !script_calls |> List.rev in
                    let entry=P.{revision=(match revision with `Installed -> None | `Draft value -> Some (scrub value));slug=scrub goal;site=Option.value ~default:"" !current_site;planned=true;attempts=1;
                      choice={key="leg";probabilities=`Null;confidence=1.;usage=None};drives;scripts;expectations=List.filteri (fun i _ -> i>=before_checks) !candidate_checks;outcome=status;elapsed_ms=ms (now () -. at);reason=(match outcome with Ok () -> None | Error error -> Some (scrub error.message))} in
                    procedures := entry::old_procedures; outcome in
              (match outcome with Error error ->
                ignore error; next () | Ok () -> next ())
          in
  on_arguments !known;
  if args.max_plans <= 0 || args.max_steps <= 0 || args.deadline_s <= 0 then Error (invalid "pilot limits must be positive")
  else
    let start = match args.start_url with Some url -> Some url | None -> (match starting_urls args.mission with [url] -> Some url | _ -> None) in
    let* () = match start with None -> Ok () | Some url -> if valid_start_url url then (if args.dry_run then Ok () else handler.navigate url) else Error (invalid "invalid start URL") in
    let* page = observe () in turn page)
