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
  deadline_s : int;
  dry_run : bool;
  script_offers : url:string -> text:string -> Jev_request.offered_script list;
  on_script : url:string -> string -> (Jev_request.script_effect, P.error) result;
  reached : (start_url:string -> P.snapshot -> text:string -> bool) option;
}
(** run-d82w: one playbook step as the operator level receives it — the goal with the
    hint shaping it, and the step's own cap and deadline. *)

type script_outcome =
  | Collected of { value : Yojson.Safe.t; records : int; bytes : int; elapsed_ms : int }
  | Rejected of { reason : string; elapsed_ms : int }
(** extr-8o1h: what a script step came to. [Collected] is a result that fit its shape;
    [Rejected] is a script that threw, whose result did not fit or was too large — the
    procedure's step failed, and the reason is in the trace. *)

type plan_trigger = Blocked | Failed | Arguments
(** run-w7ke (L32 wires the plan; L31 asks it and takes its answer): the three points JEV
    stopped — the procedure level answered BLOCKED, a procedure failed its expectations
    twice, or an argument the mission does not supply could not be filled. *)

type plan_answer = Procedure of Playbook.procedure | Handoff of string | Fail of string

type plan_reply = {
  answer : plan_answer;
  expect : string list;
      (* run-2tt3: the mission's own expectations, which the planner may attach beside its
         answer on its first turn — the sentences DONE is then verified against when the
         caller stated none. Ignored on every later turn. *)
  usage : P.run_usage option;
      (* run-obtt: what the turn cost, provider-reported where the model route reports it
         and otherwise its token counts, carried into the run's trace. *)
  pages : Playbook.page list;  (* run-3vat: newly proposed page kinds. *)
}
(** One planner turn's answer (run-rq6i), what it attached to the mission (run-2tt3) and
    what it cost (run-obtt). *)

type plan_request = {
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
  page_kind : string option;
  title : string;
  url : string;
  text : string;
      (* run-rq6i, the one level page text reaches: the planner gets the page summary plus
         this bounded text, while the two choice levels never see it (run-pvmc). *)
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
    max_steps = Option.value ~default:60 args.P.max_steps;
    start_url = args.P.start_url;
    max_procedures = Option.value ~default:40 args.P.max_procedures;
    deadline_s = Option.value ~default:900 args.P.deadline_s;
    dry_run = Option.value ~default:false args.P.dry_run;
    max_plans = 3;
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
let unsafe_action text =
  let words = String.lowercase_ascii text in
  let has word =
    let n = String.length word in
    let rec loop i =
      i + n <= String.length words
      && (String.sub words i n = word || loop (i + 1))
    in
    loop 0
  in
  if List.exists has [ "payment"; "pay now"; "checkout"; "place order"; "purchase"; "buy now"; "card number" ] then Some "payment"
  else if List.exists has [ "delete"; "remove account"; "close account"; "erase account"; "permanently remove" ] then Some "deletion"
  else if List.exists has [ "send"; "reply"; "message"; "post comment"; "publish comment"; "submit comment" ] then Some "messaging"
  else None

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

let trigger_name = function Blocked -> "blocked" | Failed -> "failed" | Arguments -> "arguments"

let answer_name = function
  | Procedure _ -> "procedure"
  | Handoff _ -> "handoff"
  | Fail _ -> "fail"

let failures (results : P.run_expectation list) =
  results
  |> List.filter (fun (result : P.run_expectation) -> not result.P.passed)
  |> List.map (fun (result : P.run_expectation) -> result.P.sentence)
  |> String.concat "; "

(* ---------- The loop's state ---------- *)

type discovery = { book : Playbook.loaded; max_steps : int; max_cost : float }

(* ncaps-mygj: the observation ID changes on every read; compare the visible page,
   not download history, before deciding an action has already run here. *)
let same_page (a : observation) (b : observation) =
  a.url = b.url && a.title = b.title && a.text = b.text
  && a.rows = b.rows && a.dialog = b.dialog

type state = {
  steps_used : int;
  trace : P.run_procedure list;  (** Newest first. *)
  plans : P.planner_turn list;  (** Newest first. *)
  recent : (string * string) list;  (** Procedure slug and outcome, oldest first. *)
  known : (string * string) list;  (** The arguments the run knows. *)
  visited : string list;  (** Sites the run has served the mission from. *)
  book : Playbook.loaded option;
  checks : (string * Playbook.checker) list;
      (** The last verified procedure's expectations, which the DONE guard re-verifies when
          the mission carries none of its own (run-4j1v). *)
  mission_expect : string list;
      (** run-2tt3: the mission's expectations as the planner attached them on its first
          turn, before they are resolved. A caller's own [expect] list wins over these. *)
  mission_checks : P.run_expectation list;
  verified_pages : (string * string * observation) list;
      (** ncaps-mygj: site, slug and visible page of successful procedures; a second
          selection on the unchanged page must not replay their actions. *)
  playbook_choices : P.playbook_choice list;
  proposals : string list;  (** run-m0r8: the proposal files the run wrote, oldest first. *)
  count : int;  (** Procedures executed, the [use] calls and planner procedures included. *)
  records : Yojson.Safe.t list;
      (** extr-b3u0: at most five truncated display samples, newest first; never
          passed to a model. Full validated records are streamed only. *)
  collected_count : int;
  pages : int;  (** extr-ve3k: verified pages, including the first page. *)
  complete : bool;
      (** extr-b3u0: the last pagination ended because its end condition held or its next
          page did not exist, not because it hit [max] or a limit — the one fact about a
          collection the upper levels need to answer DONE. *)
  collection_pending : bool;
      (** extr-b3u0: a repeat started but has not reached [until] or the expected
           end-of-pagination check. DONE cannot verify a partial collection. *)
  pending_scripts : P.run_script list;
      (** The script calls of the procedure being executed, newest first, moved into its
          trace entry when it is recorded. *)
  switch : bool;  (** The next turn asks the playbook level. *)
  asked_switch : bool;  (** A switch was already asked since the last procedure. *)
  operator_state : P.operator_state option;
  operator_history : Jev_request.recent_action list;
  observation : observation;
}

let finish (st : state) status ?reason () =
  let scripts =
    List.concat_map (fun (entry : P.run_procedure) -> entry.P.scripts) st.trace
    |> List.fold_left (fun acc (entry : P.run_script) ->
         let calls, records = Option.value ~default:(0, 0) (List.assoc_opt entry.script acc) in
         (entry.script, (calls + 1, records + entry.records))
         :: List.remove_assoc entry.script acc) []
    |> List.map (fun (name, (calls, records)) ->
         `Assoc [ ("name", `String name); ("calls", `Int calls); ("records", `Int records) ])
  in
  P.
    {
      status;
      site = Option.map (fun (book : Playbook.loaded) -> book.Playbook.playbook.Playbook.site) st.book;
      procedures = List.rev st.trace;
      mission_expectations = st.mission_checks;
      playbook_choices = List.rev st.playbook_choices;
      planner_turns = List.rev st.plans;
      proposals = List.rev st.proposals;
      collected = st.collected_count;
      data = `Assoc [ ("count", `Int st.collected_count); ("first", `List (List.rev st.records)); ("pages", `Int st.pages); ("scripts", `List scripts) ];
      model_calls = 0;
      model_cost = Some 0.;
      operator_steps = [];
      operator_state = st.operator_state;
      output_kinds = (if st.collected_count > 0 then ["script-record"] else [])
        @ (if st.operator_state <> None then ["operator-state"] else []);
      final = st.observation.snapshot;
      reason;
    }

(* drive-y7v8's rule for a run: a model failure carries the work it had done when it
   failed, so a failed mission is auditable. *)
let with_trace (st : state) (error : P.error) =
  if not (List.mem (P.Error_code.to_string error.P.code) ["model-unavailable"; "model-timeout"]) then error
  else
    let fields =
      match error.P.detail with
      | Some (`Assoc fields) -> fields
      | _ -> ["code", `String "unavailable"]
    in
    {
      error with
      P.detail =
        Some
          (`Assoc
            ([
              ( "site",
                match st.book with
                | Some book -> `String book.Playbook.playbook.Playbook.site
                | None -> `Null );
              ("procedures", `List (List.map P.yojson_of_run_procedure (List.rev st.trace)));
              ("mission_expectations",
                `List (List.map P.yojson_of_run_expectation st.mission_checks));
              ( "playbook_choices",
                `List
                  (List.map P.yojson_of_playbook_choice (List.rev st.playbook_choices)) );
            ] @ fields));
    }

type step_result = Continue of state | Finish of P.run_result

let ( let* ) x f =
  match x with
  | Error error -> Error error
  | Ok (Finish result) -> Ok (Finish result)
  | Ok (Continue st) -> f st

(* ---------- The computation ---------- *)

(* Each judgment has an internal callback and a local-only public use, as the drive's does:
   a token cannot escape the dynamic extent of [loop], and a nested run would have its own
   effect constructors. *)
type token = {
  observe : unit -> (observation, P.error) result;
  navigate : string -> (unit, P.error) result;
  select_playbook : question -> (choice, P.error) result;
  select_procedure : question -> (choice, P.error) result;
  fill_args : Text_helper.context -> (string option, P.error) result;
  execute_step : step_request -> (P.drive_result, P.error) result;
  verify :
    Playbook.page list ->
    (string * Playbook.checker) list ->
    int ->
    (P.run_expectation list * observation, P.error) result;
  plan : plan_request -> (plan_reply, P.error) result;
  propose : string -> Playbook.procedure -> (string, P.error) result;
  hand_off : string -> (P.tab_info, P.error) result;
  run_script :
    Playbook.script -> (string * string) list -> (script_outcome, P.error) result;
}

let observe (t : token @ local) () = t.observe ()
let navigate (t : token @ local) url = t.navigate url
let select_playbook (t : token @ local) question = t.select_playbook question
let select_procedure (t : token @ local) question = t.select_procedure question
let fill_args (t : token @ local) context = t.fill_args context
let execute_step (t : token @ local) request = t.execute_step request
let verify (t : token @ local) ~pages ~checks ~timeout_s =
  ((t.verify pages) checks) timeout_s
let plan (t : token @ local) request = t.plan request
let propose (t : token @ local) ~site proc = (t.propose site) proc
let hand_off (t : token @ local) ~reason = t.hand_off reason
let run_script (t : token @ local) script args = (t.run_script script) args

type fill_outcome = Filled of state * (string * string) list | Unfilled of state * string

type steps_outcome =
  | Steps_done of state * P.run_drive list * string option
      (** The procedure's steps are through. The third member is the reason an [optional]
          [use] was skipped, [None] otherwise. *)
  | Steps_interrupted of state * P.run_drive list * string
      (** extr-8o1h: a non-done operator step prevented remaining steps, with no
           automatic replay or verification of an unfinished page. *)
  | Steps_failed of state * P.run_drive list * string
  | Steps_unfilled of state * string
      (** extr-8o1h: a script step was rejected. The procedure's remaining steps do not
          run and, unlike a failed expectation, nothing is verified: the attempt failed
          for the reason given. *)
  | Steps_finish of P.run_result
      (** The run ended inside a step: a dialog, or a planner turn a called procedure
          asked for. *)

let compute (t : token) ~direct_fill ~direct_script ~on_record ~pause_ms ~now ~installed ?discovery (args : args) : (P.run_result, P.error) result =
  let installed = installed_playbooks installed in
  let started = now () in
  let deadline = started +. float_of_int args.deadline_s in
  let remaining () = max 1 (int_of_float (deadline -. now ())) in
  let empty observation =
    {
      steps_used = 0;
      trace = [];
      playbook_choices = [];
      plans = [];
      recent = [];
      known = [];
      visited = [];
      book = Option.map (fun (d : discovery) -> d.book) discovery;
      checks = [];
      mission_expect = [];
      mission_checks = [];
      verified_pages = [];
      proposals = [];
      count = 0;
        records = [];
        collected_count = 0;
        pages = 0;
        complete = false;
        collection_pending = false;
        pending_scripts = [];
      switch = false;
      asked_switch = false;
      operator_state = None;
      operator_history = [];
      observation;
    }
  in
  let dedupe_key = ref None in
  let seen = Hashtbl.create 128 in
  let accept_record ~book ~procedure ~script item =
    let emit item = on_record (`Assoc [
      ("kind", `String "script-record"); ("source", `String "playbook");
      ("playbook", `String (book_id book)); ("procedure", `String procedure);
      ("script", `String script); ("record", item) ]) in
    match !dedupe_key with
    | None -> Result.map (fun () -> true) (emit item)
    | Some key -> (
        match item with
        | `Assoc fields -> (
            match List.assoc_opt key fields with
            | None -> Error (invalid ("repeat key missing from record: " ^ key))
            | Some identity ->
                let identity = key ^ "=" ^ Yojson.Safe.to_string identity in
                if Hashtbl.mem seen identity then Ok false
                else
                  match emit item with
                  | Error error -> Error error
                  | Ok () -> Hashtbl.add seen identity (); Ok true)
        | _ -> Error (invalid "repeat key requires object records"))
  in

  (* run-pvmc (the L30 shape B, run-snk4): the state an upper level is asked over — the
     mission, the site, the page kind, the title and URL, the last five procedures with
     their outcomes, and the arguments known. Never the page text. *)
  let state_json (st : state) =
    let kind =
      match st.book with
      | Some book -> Playbook.page_kind book.Playbook.playbook.pages ~url:st.observation.url ~text:st.observation.text
      | None -> None
    in
    `Assoc
      ([
        ("mission", `String args.mission);
        ( "site",
          match st.book with
          | Some book -> `String book.Playbook.playbook.site
          | None -> `Null );
        ("page_kind", match kind with Some kind -> `String kind | None -> `Null);
        ("title", `String st.observation.title);
        ("url", `String st.observation.url);
        ( "recent_procedures",
          `List
            (List.map
               (fun (slug, outcome) ->
                 `Assoc [ ("procedure", `String slug); ("outcome", `String outcome) ])
               (last 5 st.recent)) );
        ("arguments", `Assoc (List.map (fun (name, value) -> (name, `String value)) st.known));
        ("collected", `Int st.collected_count);
      ]
      @
      (* extr-b3u0: once something was collected, how far the collection went — pages read
         and whether its pagination ran out — as counts and a flag, never a record. *)
      (if st.observation.url = "about:blank" then [("current_page", `String "Blank page; no site is loaded.")] else [])
      @ if st.collected_count = 0 && not st.complete then []
      else [ ("pages", `Int st.pages); ("collection_complete", `Bool st.complete) ])
  in

  (* run-kli0 run-qq3o: the playbook question's criteria are the installed playbooks by
     site and description plus none; playbooks are selected, never merged, so no choice
     ever carries more than 255 options. *)
  let remember_choice st (choice : choice) =
    let judgments = match choice.judgments with
      | [] -> [P.{ source = "jev"; key = Some choice.key;
          probabilities = choice.probabilities; confidence = Some choice.confidence;
          usage = choice.usage; note = None }]
      | judgments -> judgments in
    { st with playbook_choices = List.rev_append judgments st.playbook_choices }
  in
  let describe_book (book : Playbook.loaded) =
    Printf.sprintf "identity=%s | site %s | entry %s | %s" (book_id book)
      book.playbook.site book.playbook.entry book.playbook.description
  in
  (* fly-95bw: every leaf is retained, NONE is present at every bounded level.
     Balanced groups expose all members rather than silently taking the first 254. *)
  let rec choose_books st books =
    if books = [] then Ok (st, None) else
    let size = List.length books in
    let group_size = max 1 ((size + 253) / 254) in
    let rec take n acc rest = match n, rest with
      | 0, _ | _, [] -> (List.rev acc, rest)
      | n, head :: tail -> take (n - 1) (head :: acc) tail in
    let rec groups n acc = function
      | [] -> List.rev acc
      | remaining -> let members, rest = take group_size [] remaining in
          groups (n + 1) (("group:" ^ string_of_int n, members) :: acc) rest in
    let grouped = groups 1 [] books in
    let candidates = if size <= 254 then
        List.map (fun book -> (book_id book, describe_book book)) books
      else List.map (fun (key, members) -> (key,
        "Choose within these distinct playbooks: " ^
        String.concat "\n" (List.map describe_book members))) grouped in
    let question = { name = "select_playbook";
      instructions = Questions.select_playbook ^
        " Choose a book or group only when it fits the entire mission and current page. NONE means operate directly without a playbook.";
      criteria = candidates @ [("none", "Continue on the current page without a playbook.")];
      state = state_json st } in
    match select_playbook t question with
    | Error error -> Error (with_trace st error)
    | Ok choice ->
        let st = remember_choice st choice in
        if choice.key = "none" then Ok (st, None)
        else if size <= 254 then
          (match List.find_opt (fun book -> book_id book = choice.key) books with
           | Some book -> Ok (st, Some book)
           | None -> Error (internal ("playbook answer names no offered identity: " ^ choice.key)))
        else match List.assoc_opt choice.key grouped with
          | Some members -> choose_books st members
          | None -> Error (internal ("playbook answer names no offered group: " ^ choice.key))
  in

  (* extr-ve3k: next-page procedures belong to their repeats, not to the mission's
     choice list. A model must not run a page-navigation step without its collector. *)
  let selectable_procedures (book : Playbook.loaded) =
    let next_slugs =
      List.filter_map
        (fun (proc : Playbook.procedure) ->
          Option.map (fun (repeat : Playbook.repeat) -> repeat.next) proc.Playbook.repeat)
        book.Playbook.playbook.procedures
    in
    List.filter
      (fun (proc : Playbook.procedure) -> not (List.mem proc.Playbook.slug next_slugs))
      book.Playbook.playbook.procedures
  in

  (* run-qq3o: every turn, selectable procedures plus DONE and BLOCKED. *)
  let procedure_question (st : state) (book : Playbook.loaded) =
    let criteria =
      List.map
        (fun (proc : Playbook.procedure) -> (proc.Playbook.slug, proc.Playbook.description))
        (selectable_procedures book)
      @ [
          ("DONE", "the mission is visibly complete");
          ("NONE", "No offered procedure fits; continue this mission directly on the current page.");
        ]
    in
    if List.length criteria > 255 then
      Error
        (invalid
           (Printf.sprintf "playbook %s offers more than 253 procedures" book.Playbook.playbook.site))
    else
      Ok
        {
          name = "select_procedure";
          instructions = Questions.select_procedure;
          criteria;
          state = state_json st;
        }
  in

  (* run-kli0: the mission or a procedure's description says the next part is elsewhere
     when it names an installed site the run has not served from yet. *)
  let mentions_other_site (st : state) text =
    List.exists
      (fun (book : Playbook.loaded) ->
        let site = book.Playbook.playbook.site in
        let current =
          match st.book with Some current -> current.Playbook.playbook.site = site | None -> false
        in
        (not current) && (not (List.mem site st.visited)) && contains ~needle:site text)
      installed
  in

  let record (st : state) ~(book : Playbook.loaded) ~(proc : Playbook.procedure) ~planned
      ~choice ~drives ~expectations ~outcome ~attempts ~elapsed ~reason =
    let entry =
      P.
        {
          slug = proc.Playbook.slug;
          site = book.Playbook.playbook.site;
          planned;
          attempts;
          choice = wire_choice choice;
          drives;
          scripts = List.rev st.pending_scripts;
          expectations;
          outcome;
          elapsed_ms = elapsed;
          reason;
        }
    in
    {
      st with
      pending_scripts = [];
      trace = entry :: st.trace;
      recent = st.recent @ [ (proc.Playbook.slug, outcome) ];
      count = st.count + 1;
      switch = mentions_other_site st (proc.Playbook.description ^ " " ^ args.mission);
      asked_switch = false;
    }
  in

  (* run-5rll: every argument a procedure declares is resolved before its steps run — from
     what the caller passed (a [use] step's args), from what the run already knows, or from
     one text-helper call — and the values travel with the steps, so a placeholder is
     substituted or the run blocks asking the planner for the missing fact. *)
  let const_string = function
    | `String value -> value
    | `Int n -> string_of_int n
    | `Intlit value -> value
    | `Bool value -> string_of_bool value
    | `Float value ->
        if Float.is_integer value then string_of_int (int_of_float value)
        else string_of_float value
    | other -> Yojson.Safe.to_string other
  in
  let fill_declared ?(ask = fun context -> fill_args t context) ?(carry = true) (st : state) declared ~values ~missing =
    let ask_name st name =
      let context =
        Text_helper.
          {
            goal = args.mission;
            field = { label = name; role = "argument"; value = "" };
            page_title = st.observation.title;
            page_text = st.observation.text;
            recent = [];
          }
      in
      match ask context with
      | Error error -> Error error
      | Ok None -> Ok (Unfilled (st, missing name))
      | Ok (Some value) ->
          Ok (Filled ({ st with known = (name, value) :: st.known }, [ (name, value) ]))
    in
    let rec go st acc = function
      | [] -> Ok (Filled (st, if carry then acc @ values @ st.known else acc))
      | (decl : Playbook.arg_decl) :: rest -> (
          let name = decl.name in
          match decl.source with
          | Playbook.Const json ->
              let value = const_string json in
              let st = { st with known = (name, value) :: List.remove_assoc name st.known } in
              go st (acc @ [ (name, value) ]) rest
          | Playbook.From_mission { optional } -> (
              match (List.assoc_opt name values, List.assoc_opt name st.known) with
              | Some value, _ | None, Some value -> go st (acc @ [ (name, value) ]) rest
              | None, None -> (
                  match ask_name st name with
                  | Error error -> Error error
                  | Ok (Unfilled _) when optional -> go st acc rest
                  | Ok (Unfilled _ as unfilled) -> Ok unfilled
                  | Ok (Filled (st, answered)) -> go st (acc @ answered) rest)))
    in
    go st [] declared
  in
  let fill_arguments (st : state) (proc : Playbook.procedure) ~values =
    fill_declared st
      (Option.value ~default:[] proc.Playbook.args)
      ~values
      ~missing:(fun name ->
        Printf.sprintf "no value for argument %S of procedure %s" name proc.Playbook.slug)
  in

  let resolved_checks (book : Playbook.loaded) (proc : Playbook.procedure) values =
    Playbook.resolved ~values book.Playbook.playbook proc
  in

  let dialog_reason (dialog : P.dialog) = "dialog open: " ^ P.Dialog_kind.to_string dialog.P.kind in

  (* run-w7ke run-rq6i run-2tt3 run-obtt run-klp9: the one planner turn. It is asked only
     at the three triggers JEV stopped at, only while the run's turn cap allows it, and its
     answer maps to the ending the trigger deserves — a procedure that failed twice is
     [failed], anything else [blocked] — with a handoff leaving the tab with the human. The
     first turn may attach the mission's expectations (run-2tt3), which the DONE guard then
     verifies instead of the caller's list; every turn's cost rides in the trace
     (run-obtt). *)
  let rec planner (st : state) ~trigger ~reason =
    if List.length st.plans >= args.max_plans then
      Ok
        (Finish
           (finish st
              (status (if trigger = Failed then "failed" else "blocked"))
              ~reason:
                (Printf.sprintf "%s; the planner turn cap of %d was reached" reason
                   args.max_plans)
              ()))
    else
      let kind =
        match st.book with
        | Some book ->
            Playbook.page_kind book.Playbook.playbook.pages ~url:st.observation.url
              ~text:st.observation.text
        | None -> None
      in
      let request =
        {
          trigger;
          reason;
          mission = args.mission;
          site = Option.map (fun (book : Playbook.loaded) -> book.Playbook.playbook.site) st.book;
          playbook =
            Option.map (fun (book : Playbook.loaded) -> book.Playbook.playbook) st.book;
          recent = st.recent;
          arguments = st.known;
          page_kind = kind;
          title = st.observation.title;
          url = st.observation.url;
          text = st.observation.text;
        }
      in
      match plan t request with
      | Error error -> Error (with_trace st error)
      | Ok reply ->
          let turn =
            P.
              {
                n = List.length st.plans + 1;
                trigger = trigger_name trigger;
                answer = answer_name reply.answer;
                reason =
                  (match reply.answer with
                  | Procedure _ -> None
                  | Handoff why -> Some why
                  | Fail why -> Some why);
                usage = reply.usage;
              }
          in
          (* run-2tt3: only the first turn may attach the mission's expectations. *)
          let st =
            {
              st with
              plans = turn :: st.plans;
              mission_expect =
                (if st.plans = [] && reply.expect <> [] then reply.expect
                 else st.mission_expect);
            }
          in
          let cost = List.fold_left (fun sum (turn : P.planner_turn) -> sum +. Option.fold ~none:0. ~some:(fun (u : P.run_usage) -> u.cost) turn.usage) 0. st.plans in
          if Option.fold ~none:false ~some:(fun d -> cost > d.max_cost) discovery then
            Ok (Finish (finish st (status "limit") ~reason:"reported discovery cost cap was reached" ()))
          else (match reply.answer with
          | Fail why ->
              Ok
                (Finish
                   (finish st
                      (status (if trigger = Failed then "failed" else "blocked"))
                      ~reason:(Printf.sprintf "%s; the planner answered fail: %s" reason why)
                      ()))
          | Handoff why -> (
              match hand_off t ~reason:why with
              | Error error -> Error (with_trace st error)
              | Ok _ -> Ok (Finish (finish st (status "handoff") ~reason:why ())))
          | Procedure proc -> (
              match st.book with
              | None ->
                  Ok
                    (Finish
                       (finish st (status "blocked")
                          ~reason:"the planner wrote a procedure but no playbook is chosen" ()))
              | Some book ->
                  let prepared = match discovery with None -> Ok book | Some _ ->
                    let procedures = List.filter (fun (old : Playbook.procedure) -> old.slug <> proc.slug) book.playbook.procedures @ [proc] in
                    let updated = { book.playbook with pages = book.playbook.pages @ reply.pages; procedures } in
                    (match Playbook.of_json ~file:book.file (Playbook.yojson_of_t updated) with
                    | Ok book -> Ok book
                    | Error why -> Error (internal why)) in
                  match prepared with
                  | Error error -> Error error
                  | Ok book ->
                  let st = { st with book = Some book } in
                  let run_choice choice =
                    let selected = match List.find_opt (fun (candidate : Playbook.procedure) -> candidate.slug = choice.key) book.playbook.procedures with
                    | Some selected -> selected | None -> proc in
                    execute st ~book ~proc:selected ~planned:(selected.slug = proc.slug) ~choice ~optional:false ~values:[] in
                  match discovery with
                  | None -> run_choice { key = proc.slug; probabilities = `Assoc []; confidence = 1.; usage = None; judgments = [] }
                  | Some _ -> (match procedure_question st book with
                      | Error error -> Error error
                      | Ok question -> (match select_procedure t question with
                          | Error error -> Error (with_trace st error)
                          | Ok choice when choice.key = "DONE" -> done_guard st ~pages:book.Playbook.playbook.pages
                          | Ok choice when choice.key = "BLOCKED" -> Ok (Finish (finish st (status "blocked") ~reason:"discovery procedure selection was blocked" ()))
                          | Ok choice -> run_choice choice))))

  (* run-d82w run-prrv extr-8o1h: a procedure's steps in order. An [optional]
     [use] is skipped when its first step ends blocked within two operator steps.
     Otherwise a non-done drive cannot silently skip remaining steps. *)
  and control_script st book name arguments =
    match Playbook.script_named book name with
    | None -> Error (internal ("unknown control script " ^ name))
    | Some script ->
        let call ~records ~bytes ~elapsed_ms ~error =
          P.{ script = name; url = st.observation.url; records; bytes; elapsed_ms; error } in
        (match run_script t script arguments with
        | Error error -> Error error
        | Ok (Rejected { reason; elapsed_ms }) ->
            let st = { st with pending_scripts = call ~records:0 ~bytes:0 ~elapsed_ms ~error:(Some reason) :: st.pending_scripts } in
            Ok (st, Error reason)
        | Ok (Collected { value; records = _; bytes; elapsed_ms }) ->
            let st = { st with pending_scripts = call ~records:0 ~bytes ~elapsed_ms ~error:None :: st.pending_scripts } in
            Ok (st, Ok value))

  and steps (st : state) (book : Playbook.loaded) (proc : Playbook.procedure) values ~optional =
    let first_drive drives = drives = [] in
    let rec go st drives = function
      | [] -> Ok (Steps_done (st, List.rev drives, None))
      | Playbook.Goal goal :: rest ->
          let text = Playbook.substitute values goal.Playbook.goal in
          let goal_text =
            match goal.Playbook.hint with None -> text | Some hint -> text ^ " Hint: " ^ hint
          in
          let first = first_drive drives in
          let cap =
            match proc.Playbook.max_steps with
            | Some n -> if optional && first then min 2 n else n
            | None -> if optional && first then 2 else 30
          in
          let deadline_s =
            min (remaining ()) (Option.value ~default:120 proc.Playbook.deadline_s)
          in
          let cap = min cap (args.max_steps - st.steps_used) in
          let cap = match discovery with None -> cap | Some d -> min cap (d.max_steps - st.steps_used) in
          let started_url = st.observation.url in
          let side = ref st in
          let first_line text =
            match String.index_opt text '\n' with None -> text | Some i -> String.sub text 0 i
          in
          let summary name value =
            match value with
            | `List items -> Printf.sprintf "ran %s: %d records" name (List.length items)
            | other ->
                let fields =
                  match other with
                  | `Assoc pairs ->
                      List.filter_map
                        (fun (key, value) ->
                          match value with
                          | `String s -> Some (key ^ "=" ^ s)
                          | `Int n -> Some (key ^ "=" ^ string_of_int n)
                          | `Intlit s -> Some (key ^ "=" ^ s)
                          | `Float f -> Some (key ^ "=" ^ string_of_float f)
                          | `Bool b -> Some (key ^ "=" ^ string_of_bool b)
                          | _ -> None)
                        pairs
                  | _ -> []
                in
                let text =
                  if fields = [] then Yojson.Safe.to_string other else String.concat ", " fields
                in
                let text = if String.length text <= 120 then text else String.sub text 0 120 in
                Printf.sprintf "ran %s: %s" name text
          in
          (* pbk-hcwy: a script JEV already ran on this address in this step is not run
             again — its records are collected; JEV is told so and can finish. *)
          let already = ref [] in
          let on_script ~url name =
            match Playbook.script_named book name with
            | None -> Error (internal ("unknown script " ^ name))
            | Some _ when List.mem_assoc (name, url) !already ->
                Ok
                  (Jev_request.Script_continue
                     {
                       summary =
                         Printf.sprintf "ran %s: already collected on this page (%s)" name
                           (List.assoc (name, url) !already);
                     })
            | Some script -> (
                match
                  fill_declared ~carry:false ~ask:direct_fill !side script.Playbook.args ~values
                    ~missing:(fun arg -> Printf.sprintf "no value for argument %S" arg)
                with
                | Error error -> Error error
                | Ok (Unfilled (_, reason)) ->
                    let argument =
                      match String.index_opt reason '"' with
                      | None -> reason
                      | Some i ->
                          let rest = String.sub reason (i + 1) (String.length reason - i - 1) in
                          (match String.index_opt rest '"' with
                          | None -> reason
                          | Some j -> String.sub rest 0 j)
                    in
                    Ok (Jev_request.Script_blocked { argument })
                | Ok (Filled (filled, args)) -> (
                    match direct_script script args with
                    | Error error -> Error error
                    | Ok (Rejected { reason; elapsed_ms }) ->
                        side :=
                          { filled with
                            pending_scripts =
                              P.{ script = name; url; records = 0; bytes = 0; elapsed_ms; error = Some reason }
                              :: filled.pending_scripts };
                        Ok (Jev_request.Script_continue { summary = Printf.sprintf "ran %s: failed (%s)" name (first_line reason) })
                    | Ok (Collected { value; records; bytes; elapsed_ms }) ->
                        let items = match value with `List items -> items | one -> [ one ] in
                        let rec collect st = function
                          | [] -> Ok st
                          | item :: rest -> (
                              match accept_record ~book ~procedure:proc.Playbook.slug ~script:name item with
                              | Error error -> Error error
                              | Ok false -> collect st rest
                              | Ok true ->
                                  let sample =
                                    if List.length st.records >= 5 then st.records
                                    else
                                      let text = Yojson.Safe.to_string item in
                                      (if String.length text <= 2048 then item
                                       else `String (String.sub text 0 2048 ^ "..."))
                                      :: st.records
                                  in
                                  collect { st with records = sample; collected_count = st.collected_count + 1 } rest)
                        in
                        match collect filled items with
                        | Error error -> Error error
                        | Ok collected_st ->
                            side :=
                              { collected_st with
                                pending_scripts =
                                  P.{ script = name; url; records; bytes; elapsed_ms; error = None }
                                  :: collected_st.pending_scripts };
                            let line = summary name value in
                            let prefix = "ran " ^ name ^ ": " in
                            already :=
                              ( (name, url),
                                String.sub line (String.length prefix)
                                  (String.length line - String.length prefix) )
                              :: !already;
                            Ok (Jev_request.Script_continue { summary = line })))
          in
          let request =
            { goal = goal_text; hint = goal.Playbook.hint; recent = st.operator_history; max_steps = cap; deadline_s; dry_run = false;
              script_offers = (fun ~url ~text ->
                List.map (fun (script : Playbook.script) -> Jev_request.{ name = script.name; description = script.description })
                  (Playbook.offered_scripts book ~url ~text));
              on_script;
              reached =
                Option.map
                  (fun sentences ~start_url (snapshot : P.snapshot) ~text ->
                    Playbook.until_holds ~values book.Playbook.playbook sentences ~start_url
                      ~url:snapshot.P.url
                      Playbook.
                        {
                          kind =
                            page_kind book.Playbook.playbook.pages ~url:snapshot.P.url ~text;
                          text;
                          dialog = snapshot.P.dialog <> None;
                          rows =
                            List.map (fun (row : P.row) -> (row.P.role, row.P.name)) snapshot.P.rows;
                          downloads = [];
                        })
                  goal.Playbook.until }
          in
          (if cap <= 0 then
             Ok (Steps_finish (finish st (status "limit") ~reason:"the mission action budget was exhausted" ()))
           else match (match discovery with None -> None | Some _ -> unsafe_action goal_text) with
          | Some kind -> Ok (Steps_finish (finish st (status "blocked") ~reason:("discovery stopped before " ^ kind ^ " action") ()))
          | None -> match execute_step t request with
          | Error error when discovery <> None && String.starts_with ~prefix:"discovery stopped before " error.P.message ->
              Ok (Steps_finish (finish st (status "blocked") ~reason:error.P.message ()))
          | Error error -> Error error
          | Ok drive when
              drive_is "blocked" drive.P.status
              && Option.fold ~none:false
                   ~some:(fun reason -> String.starts_with ~prefix:"no value for argument " reason)
                   drive.P.reason ->
              Ok (Steps_unfilled (!side, Option.value ~default:"no value for argument" drive.P.reason))
          | Ok drive ->
              let st = !side in
              let st = { st with steps_used = st.steps_used + drive_actions drive;
                operator_state = drive.operator_state;
                operator_history = st.operator_history @ drive_recent drive.steps } in
              let entry =
                P.{ goal = goal_text; status = drive.P.status; steps = drive.P.steps; reason = drive.P.reason }
              in
              (* The drive's final snapshot is fresher than the run's own observation, and
                 a dialog it stopped on is what ends the run (run-klp9). *)
              let st =
                {
                  st with
                  observation =
                    {
                      st.observation with
                      snapshot = drive.P.final;
                      url = drive.P.final.P.url;
                      title = drive.P.final.P.title;
                      dialog = drive.P.final.P.dialog;
                    };
                }
              in
              (match drive.P.final.P.dialog with
              | Some dialog -> Ok (Steps_finish (finish st (status "error") ~reason:(dialog_reason dialog) ()))
              | None ->
                  if optional && first && rest = []
                     && (drive_is "blocked" drive.P.status || drive_is "step-cap" drive.P.status)
                  then
                    Ok
                      (Steps_done
                         ( st,
                           List.rev (entry :: drives),
                           Some
                             (Printf.sprintf "procedure %s was skipped: its first step ended %s"
                                proc.Playbook.slug (P.Drive_status.to_string drive.P.status)) ))
                  else if drive_is "done" drive.P.status then go st (entry :: drives) rest
                  else if
                    rest <> [] && drive_is "blocked" drive.P.status
                    && drive.P.final.P.url <> started_url
                  then
                    (* pbk-eyya: JEV often answers BLOCKED after the navigation it was asked
                       for, because no further click remains. The page did change, so the
                       pinned steps that follow — the collector — still run. A blocked goal
                       that did not move the page still stops, so a failed click cannot skip
                       a remaining script. *)
                    go st (entry :: drives) rest
                  else if rest <> [] then
                    let reason =
                      Printf.sprintf "procedure %s stopped at step %S (%s): %s; %d step(s) remain"
                        proc.Playbook.slug goal_text
                        (P.Drive_status.to_string drive.P.status)
                        (Option.value ~default:"no reason given" drive.P.reason)
                        (List.length rest)
                    in
                    Ok (Steps_interrupted (st, List.rev (entry :: drives), reason))
                  else Ok (Steps_done (st, List.rev (entry :: drives), None))))
      | Playbook.Navigate step :: rest ->
          let arguments = match step.Playbook.args with
            | Some (`Assoc fields) -> List.filter_map (function name, `String value -> Some (name, Playbook.substitute values value) | _ -> None) fields
            | _ -> [] in
          (match control_script st book step.script arguments with
          | Error error -> Error error
          | Ok (st, Error reason) -> Ok (Steps_failed (st, List.rev drives, reason))
          | Ok (st, Ok value) ->
              match value with
              | `Assoc [ ("url", `String url) ] when
                  String.starts_with ~prefix:"https://" url || String.starts_with ~prefix:"http://" url || url = "about:blank" ->
                  (match navigate t url with
                  | Error error -> Error error
                  | Ok () -> match observe t () with
                    | Error error -> Error error
                    | Ok observation -> go { st with observation } drives rest)
              | _ -> Ok (Steps_failed (st, List.rev drives, "navigation script must return {url: an http(s) URL or about:blank}")))
      | Playbook.Script step :: rest -> (
          match Playbook.script_named book step.Playbook.script with
          | None ->
              Error
                (internal
                   (Printf.sprintf "script step names unknown script %s" step.Playbook.script))
          | Some script -> (
              let args =
                match step.Playbook.args with
                | Some (`Assoc fields) ->
                    List.filter_map
                      (function
                        | name, `String value -> Some (name, Playbook.substitute values value)
                        | _ -> None)
                      fields
                | Some _ | None -> []
              in
              let called url ~records ~bytes ~elapsed_ms ~error =
                P.{ script = step.Playbook.script; url; records; bytes; elapsed_ms; error }
              in
              let url = st.observation.url in
              match run_script t script args with
              | Error error when P.Error_code.to_string error.P.code = "dialog-open" -> (
                  (* A dialog the script opened ends the run as a drive's does. *)
                  match observe t () with
                  | Error error -> Error error
                  | Ok observation -> (
                      let st = { st with observation } in
                      match observation.dialog with
                      | Some dialog ->
                          Ok
                            (Steps_finish
                               (finish st (status "error") ~reason:(dialog_reason dialog) ()))
                      | None -> Error error))
              | Error error -> Error error
              | Ok (Rejected { reason; elapsed_ms }) ->
                  let st =
                    {
                      st with
                      pending_scripts =
                        called url ~records:0 ~bytes:0 ~elapsed_ms ~error:(Some reason)
                        :: st.pending_scripts;
                    }
                  in
                  Ok
                    (Steps_failed
                       ( st,
                         List.rev drives,
                         Printf.sprintf "script %s: %s" step.Playbook.script reason ))
              | Ok (Collected { value; records; bytes; elapsed_ms }) ->
                  let items = match value with `List items -> items | one -> [ one ] in
                  let rec collect st = function
                    | [] -> Ok st
                    | item :: rest -> (
                        match accept_record ~book ~procedure:proc.Playbook.slug ~script:step.Playbook.script item with
                        | Error error -> Error error
                        | Ok false -> collect st rest
                        | Ok true ->
                            let sample =
                              if List.length st.records >= 5 then st.records
                              else
                                let text = Yojson.Safe.to_string item in
                                (if String.length text <= 2048 then item
                                 else `String (String.sub text 0 2048 ^ "...")) :: st.records
                            in
                            collect { st with records = sample; collected_count = st.collected_count + 1 } rest)
                  in
                  (match collect st items with
                  | Error error -> Error error
                  | Ok st ->
                      let st =
                        { st with pending_scripts =
                            called url ~records ~bytes ~elapsed_ms ~error:None
                            :: st.pending_scripts }
                      in
                      go st drives rest)))
      | Playbook.Use use :: rest -> (
          match
            List.find_opt
              (fun (sub : Playbook.procedure) -> sub.Playbook.slug = use.Playbook.use)
              book.Playbook.playbook.procedures
          with
          | None ->
              Error (internal (Printf.sprintf "use of unknown procedure %s" use.Playbook.use))
          | Some sub ->
              let extra =
                match use.Playbook.args with
                | Some (`Assoc fields) ->
                    List.filter_map
                      (function
                        | name, `String value -> Some (name, Playbook.substitute values value)
                        | _ -> None)
                      fields
                | Some _ | None -> []
              in
              let choice =
                { key = sub.Playbook.slug; probabilities = `Assoc []; confidence = 1.; usage = None; judgments = [] }
              in
              (match
                 execute st ~book ~proc:sub ~planned:false ~choice
                   ~optional:(Option.value ~default:false use.Playbook.optional)
                   ~values:extra
               with
              | Error error -> Error error
              | Ok (Finish result) -> Ok (Steps_finish result)
              | Ok (Continue st) -> go st drives rest))
    in
    go st [] proc.Playbook.steps

  (* run-k8bx run-28: the procedure's steps, then its expectations; a failed verification
     replays the whole procedure once and a second failure is reported to the planner. *)
  and execute (st : state) ~(book : Playbook.loaded) ~(proc : Playbook.procedure) ~planned
      ~choice ~optional ~values =
    let proc_started = now () in
    let initial_kind =
      Playbook.page_kind book.Playbook.playbook.pages ~url:st.observation.url
        ~text:st.observation.text
    in
    match fill_arguments st proc ~values with
    | Error error -> Error error
    | Ok (Unfilled (st, reason)) -> planner st ~trigger:Arguments ~reason
    | Ok (Filled (st, values)) ->
        (* extr-ve3k: a repeat's key de-duplicates for the rest of the run, so a page read
           twice — a replayed procedure or repeated page — never streams a record twice. *)
        Option.iter (fun (repeat : Playbook.repeat) -> dedupe_key := Some repeat.key) proc.Playbook.repeat;
        let st =
          if proc.Playbook.repeat = None then st
          else { st with collection_pending = true; complete = false }
        in
        (* run-m0r8: a planner-written procedure that ran and passed its expectations is
           proposed to the operator as a file in XDG state; the run reports the path and
           never touches the playbook the operator authored. *)
        let propose_verified st =
          if not planned then Ok st
          else
            match propose t ~site:book.Playbook.playbook.Playbook.site proc with
            | Error error -> Error (with_trace st error)
            | Ok path ->
                if List.mem path st.proposals then Ok st
                else Ok { st with proposals = st.proposals @ [ path ] }
        in
        (* The end of a procedure that failed — its expectations twice, or a script step
           rejected twice — is recorded, and then the planner is asked unless a delayed
           overlay merely changed the page kind, which the procedure level recovers from. *)
        let fail_procedure st drives ~expectations ~n reason =
          let elapsed = ms (now () -. proc_started) in
          let st =
            record st ~book ~proc ~planned ~choice ~drives ~expectations ~outcome:"failed"
              ~attempts:n ~elapsed ~reason:(Some reason)
          in
          let current_kind =
            Playbook.page_kind book.Playbook.playbook.pages ~url:st.observation.url
              ~text:st.observation.text
          in
          if current_kind <> None && current_kind <> initial_kind then Ok (Continue st)
          else planner st ~trigger:Failed ~reason
        in
        let rec attempt n st previous_drives =
          match steps st book proc values ~optional with
          | Error error -> Error error
          | Ok (Steps_finish result) -> Ok (Finish result)
          | Ok (Steps_interrupted (st, current_drives, reason)) ->
              let st =
                record st ~book ~proc ~planned ~choice
                  ~drives:(previous_drives @ current_drives) ~expectations:[]
                  ~outcome:"failed" ~attempts:n ~elapsed:(ms (now () -. proc_started))
                  ~reason:(Some reason)
              in
              Ok (Finish (finish st (status "blocked") ~reason ()))
          | Ok (Steps_unfilled (st, reason)) -> planner st ~trigger:Arguments ~reason
          | Ok (Steps_failed (st, current_drives, why)) ->
              let drives = previous_drives @ current_drives in
              if n < 2 then attempt (n + 1) st drives
              else
                fail_procedure st drives ~expectations:[] ~n
                  (Printf.sprintf "procedure %s failed twice: %s" proc.Playbook.slug why)
          | Ok (Steps_done (st, current_drives, skip)) -> (
              let drives = previous_drives @ current_drives in
              let elapsed = ms (now () -. proc_started) in
              match skip with
              | Some reason ->
                  Ok
                    (Continue
                       (record st ~book ~proc ~planned ~choice ~drives ~expectations:[]
                          ~outcome:"skipped" ~attempts:n ~elapsed ~reason:(Some reason)))
              | None -> (
                  let checks = resolved_checks book proc values in
                  let timeout_s = Option.value ~default:5 proc.Playbook.expect_timeout_s in
                  match verify t ~pages:book.Playbook.playbook.pages ~checks ~timeout_s with
                  | Error error -> Error (with_trace st error)
                  | Ok (results, observation) when observation.dialog <> None ->
                      let st = { st with observation } in
                      let dialog = Option.get observation.dialog in
                      Ok (Finish (finish st (status "error") ~reason:(dialog_reason dialog) ()))
                  | Ok (results, observation) ->
                      let st = { st with observation } in
                      let passed =
                        List.for_all (fun (result : P.run_expectation) -> result.P.passed) results
                      in
                      if passed then
                        (* run-4j1v: the verified procedure's expectations are what the
                           DONE guard re-verifies when the mission carries none. *)
                        let st = { st with checks } in
                        (match propose_verified st with
                        | Error error -> Error error
                        | Ok st ->
                            let st = { st with pages = st.pages + (if proc.Playbook.repeat = None then 0 else 1);
                              complete = proc.Playbook.repeat = None && not st.collection_pending && st.pending_scripts <> [] } in
                            let site = book.Playbook.playbook.site in
                            let st = { st with verified_pages =
                              (site, proc.Playbook.slug, st.observation)
                              :: List.filter (fun (saved_site, saved_slug, _) ->
                                saved_site <> site || saved_slug <> proc.Playbook.slug)
                                   st.verified_pages } in
                            let st = record st ~book ~proc ~planned ~choice ~drives
                              ~expectations:results ~outcome:"verified" ~attempts:n
                              ~elapsed:(ms (now () -. proc_started)) ~reason:None in
                            (match proc.Playbook.repeat with
                            | None -> auto_mission_done st
                            | Some repeat ->
                                let* st = paginate st ~book ~values ~choice repeat in
                                auto_mission_done st))
                      else if n < 2 then attempt (n + 1) st drives
                      else
                        let reason =
                          Printf.sprintf "procedure %s failed its expectations twice: %s"
                            proc.Playbook.slug (failures results)
                        in
                        (* run-xqh8 run-k8bx, L34: a delayed privacy overlay can change
                           the page kind while an otherwise valid procedure fails;
                           [fail_procedure] lets the procedure level pick the installed
                           recovery procedure before the planner is asked. *)
                        fail_procedure st drives ~expectations:results ~n reason))
        in
        attempt 1 st []

  (* extr-ve3k extr-p7sj: a failed next expectation ends pagination, not a retry. *)
  and paginate st ~book ~values ~choice (repeat : Playbook.repeat) =
    let next = List.find (fun (p : Playbook.procedure) -> p.slug = repeat.next)
      book.Playbook.playbook.procedures in
    let until_name = match repeat.until with Playbook.Expectation sentence -> sentence | Playbook.Script_check name -> "script:" ^ name in
    let check_until st = match repeat.until with
      | Playbook.Expectation sentence ->
          (match Playbook.resolve book.Playbook.playbook.pages sentence with
          | Error reason -> Error (internal reason)
          | Ok checker -> Result.map (fun (results, observation) -> ({ st with observation }, Ok (List.for_all (fun (r : P.run_expectation) -> r.passed) results)))
              (verify t ~pages:book.Playbook.playbook.pages ~checks:[sentence, checker] ~timeout_s:1))
      | Playbook.Script_check name ->
          Result.map (fun (st, result) ->
            let trace = match st.trace with [] -> [] | entry :: rest -> { entry with P.scripts = entry.P.scripts @ List.rev st.pending_scripts } :: rest in
            let st = { st with trace; pending_scripts = [] } in
            st, Result.bind result (function `Assoc [("done", `Bool done_)] -> Ok done_ | _ -> Error "repeat script must return {done: boolean}"))
            (control_script st book name values) in
    let cap_failure st reason =
      let trace =
        match st.trace with
        | [] -> []
        | entry :: rest -> { entry with P.outcome = "failed"; reason = Some reason } :: rest
      in
      let recent =
        match List.rev st.recent with
        | [] -> []
        | (slug, _) :: rest -> List.rev ((slug, "failed") :: rest)
      in
      Finish (finish { st with trace; recent } (status "failed") ~reason ())
    in
    let rec page st index =
      if now () >= deadline then
        Ok (Finish (finish st (status "deadline") ~reason:"repeat deadline" ()))
      else
        match check_until st with
        | Error error -> Error (with_trace st error)
        | Ok (st, Error reason) -> Ok (cap_failure st reason)
        | Ok (st, Ok done_) ->
            if done_ then
              Ok (Continue { st with complete = true; collection_pending = false })
            else if index >= repeat.max then
              let reason = Printf.sprintf "repeat %s reached max %d before %S held"
                repeat.next repeat.max until_name in
              Ok (cap_failure st reason)
            else if st.count >= args.max_procedures then
              let reason = Printf.sprintf "repeat %s reached procedure cap %d before %S held"
                repeat.next args.max_procedures until_name in
              Ok (cap_failure st reason)
            else (
              pause_ms (Option.value ~default:500 repeat.delay_ms);
              if now () >= deadline then
                Ok (Finish (finish st (status "deadline") ~reason:"repeat deadline" ()))
              else match steps st book next values ~optional:false with
              | Error error -> Error error
              | Ok (Steps_finish result) -> Ok (Finish result)
              | Ok (Steps_unfilled (st, reason)) ->
                  Ok (Finish (finish st (status "blocked") ~reason ()))
              | Ok (Steps_interrupted (st, drives, reason))
              | Ok (Steps_failed (st, drives, reason)) ->
                  let st = record st ~book ~proc:next ~planned:false
                    ~choice:{ choice with key = next.slug } ~drives ~expectations:[]
                    ~outcome:"failed" ~attempts:1 ~elapsed:0 ~reason:(Some reason) in
                  Ok (Finish (finish st (status "blocked") ~reason ()))
              | Ok (Steps_done (st, drives, _)) ->
                  let checks = resolved_checks book next values in
                  let timeout_s = Option.value ~default:5 next.Playbook.expect_timeout_s in
                  match verify t ~pages:book.Playbook.playbook.pages ~checks ~timeout_s with
                  | Error error -> Error (with_trace st error)
                  | Ok (results, observation) ->
                      let st = { st with observation } in
                      if not (List.for_all (fun (r : P.run_expectation) -> r.passed) results) then
                        let st = record st ~book ~proc:next ~planned:false
                          ~choice:{ choice with key = next.slug } ~drives ~expectations:results
                          ~outcome:"skipped" ~attempts:1 ~elapsed:0
                          ~reason:(Some "end of pagination: next expectations failed") in
                        Ok (Continue { st with complete = true; collection_pending = false })
                      else
                        let st = { st with checks; pages = st.pages + 1 } in
                        let st = record st ~book ~proc:next ~planned:false
                          ~choice:{ choice with key = next.slug } ~drives ~expectations:results
                          ~outcome:"verified" ~attempts:1 ~elapsed:0 ~reason:None in
                        page st (index + 1))
    in page st 1

  and resolve_mission (st : state) pages =
    let rec go acc = function
      | [] -> Ok (List.rev acc)
      | sentence :: rest -> (
          let sentence = Playbook.substitute st.known sentence in
          match Playbook.resolve pages sentence with
          | Ok checker -> go ((sentence, checker) :: acc) rest
          | Error why -> Error (invalid ("expect: " ^ why)))
    in
    (* run-2tt3: caller expectations take precedence over those the first planner
       turn attached to the mission. *)
    go [] (if args.expect <> [] then args.expect else st.mission_expect)

  (* run-4j1v, the L30 guard: DONE is accepted only against the mission's own expectations,
     verified now on a fresh observation, or — when the mission carries none — against the
     expectations of the procedure that ran last, re-verified the same way. A DONE nothing
     can verify is refused to the planner. *)
  and done_guard (st : state) ~pages =
    if st.collection_pending then
      planner st ~trigger:Blocked
        ~reason:"DONE was refused: the collection is incomplete; pagination has not finished"
    else match resolve_mission st pages with
    | Error error -> Error error
    | Ok [] -> (
        (* The mission carries none: the last verified procedure's expectations are the
           check, re-verified now — and they are not the mission's, so they stay out of
           the result's [mission_expectations]. *)
        match st.checks with
        | [] ->
            planner st ~trigger:Blocked
              ~reason:
                "DONE was answered but nothing can verify it: no procedure has been verified and the mission carries no expectations"
        | checks -> check_done st ~mission:false checks)
    | Ok checks -> check_done st ~mission:true checks

  and check_done ?(auto = false) (st : state) ~mission checks =
    let pages =
      match st.book with Some book -> book.Playbook.playbook.pages | None -> []
    in
    match verify t ~pages ~checks ~timeout_s:5 with
    | Error error -> Error (with_trace st error)
    | Ok (results, observation) when observation.dialog <> None ->
        let st = { st with observation } in
        let dialog = Option.get observation.dialog in
        Ok (Finish (finish st (status "error") ~reason:(dialog_reason dialog) ()))
    | Ok (results, observation) ->
        let st = { st with observation } in
        (* run-xqh8: how the mission's own expectations came out is part of the audit,
           whether they held or not. *)
        let st = if mission then { st with mission_checks = results } else st in
        if List.for_all (fun (result : P.run_expectation) -> result.P.passed) results then
          Ok (Finish (finish st (status "done") ()))
        else if auto then Ok (Continue st)
        else if st.book = None then
          (* daily-9ggi: no-playbook verification is not a planning problem or
             a request for a human. Return control without changing ownership. *)
          Ok (Finish (finish st (status "blocked")
            ~reason:(Printf.sprintf "DONE was refused: %s" (failures results)) ()))
        else
          planner st ~trigger:Blocked
            ~reason:(Printf.sprintf "DONE was refused: %s" (failures results))

  (* ncaps-mygj run-4j1v: completing a verified procedure is enough when a fresh
     observation independently satisfies every mission expectation. Do not spend an
     additional model call just to ask for DONE. A site switch or failed check keeps
     the normal model decision path. *)
  and auto_mission_done (st : state) =
    if discovery <> None || st.collection_pending then Ok (Continue st)
    else match (st.trace, st.book) with
    | { P.outcome = "verified"; _ } :: _, Some book -> (
        match resolve_mission st book.Playbook.playbook.pages with
        | Ok (_ :: _ as checks) -> check_done st ~mission:true ~auto:true checks
        | Ok [] | Error _ -> Ok (Continue st))
    | _ -> Ok (Continue st)

  (* One turn: observe, ask the playbook level when a switch is due, ask the procedure
     level, and run what it chose. *)
  and next (st : state) =
    if now () >= deadline then
      Ok
        (Finish
           (finish st (status "deadline")
              ~reason:(Printf.sprintf "the run deadline of %d s was reached" args.deadline_s)
              ()))
    else if Option.fold ~none:false ~some:(fun d -> st.steps_used >= d.max_steps) discovery then
      Ok (Finish (finish st (status "limit") ~reason:"the discovery step cap was reached" ()))
    else if st.count >= args.max_procedures then
      Ok
        (Finish
           (finish st (status "limit")
              ~reason:(Printf.sprintf "the procedure cap of %d was reached" args.max_procedures)
              ()))
    else
      let* st = observe_state st in
      let* st = if discovery = None then ask_playbook st else Ok (Continue st) in
      let* st = if discovery = None then ask_procedure st else planner st ~trigger:Blocked ~reason:"discovery: propose the next procedure or finish" in
      next st

  and observe_state (st : state) =
    match observe t () with
    | Error error -> Error (with_trace st error)
    | Ok observation -> (
        let st = { st with observation } in
        match observation.dialog with
        | Some dialog ->
            Ok (Finish (finish st (status "error") ~reason:(dialog_reason dialog) ()))
        | None -> Ok (Continue st))

  (* extr-andy: a "none" playbook delegates the entire mission to the existing
     operator loop, not to the planner. It uses the same tab and action lock. *)
  and single_goal (st : state) = single_goal_operator st

  and single_goal_operator (st : state) =
    let route = P.{ source = "route"; key = Some "operator"; probabilities = `Assoc [];
      confidence = None; usage = None;
      note = Some "No fitting playbook/procedure; the full mission continues on the current page without a planner." } in
    let st = { st with book = None; playbook_choices = route :: st.playbook_choices } in
    let request = { goal = args.mission; hint = None; recent = st.operator_history;
      max_steps = max 0 (args.max_steps - st.steps_used); deadline_s = remaining (); dry_run = args.dry_run;
      script_offers = (fun ~url:_ ~text:_ -> []);
      on_script = (fun ~url:_ _ -> Error (internal "on-the-fly missions have no scripts"));
      reached = None } in
    if request.max_steps = 0 then
      Ok (Finish (finish st (status "limit") ~reason:"the mission action budget was exhausted before operator fallback" ()))
    else match execute_step t request with
    | Error error -> Error (with_trace st error)
    | Ok drive ->
        let name = P.Drive_status.to_string drive.P.status in
        let ending = status (match name with
          | "done" -> "done" | "step-cap" -> "limit" | "deadline" -> "deadline"
          | "error" -> "error" | _ -> "blocked") in
        let st = { st with operator_state = drive.operator_state;
          observation = {st.observation with snapshot = drive.final;
            url = drive.final.url; title = drive.final.title; dialog = drive.final.dialog} } in
        let attach = function
          | Finish result -> Finish {result with P.operator_steps = drive.steps}
          | Continue st -> Continue st in
        if name = "done" && not args.dry_run then
          (match resolve_mission st [] with
           | Error error -> Error error
           | Ok [] -> Ok (attach (Finish (finish st ending ?reason:drive.reason ())))
           | Ok checks -> Result.map attach (check_done st ~mission:true checks))
        else Ok (attach (Finish (finish st ending ?reason:drive.reason ())))

  (* run-xh5d: a chosen book opens its entry on this tab unless that book is already
     current. The profile's logins carry over; JEV is not asked to leave about:blank. *)
  and adopt_book (st : state) (book : Playbook.loaded) =
    let current = Option.map book_id st.book in
    let st = { st with book = Some book; switch = false;
      visited = book.playbook.site :: st.visited } in
    (* pbk-eyya: a tab already on the book's site keeps its page — "collect the books on
       this page" means this page, not the entry. *)
    let host url =
      match String.index_opt url ':' with
      | Some i when i + 3 <= String.length url && String.sub url i 3 = "://" ->
          let rest = String.sub url (i + 3) (String.length url - i - 3) in
          let stop =
            List.fold_left
              (fun stop c -> match String.index_opt rest c with Some j -> min stop j | None -> stop)
              (String.length rest) [ '/'; ':'; '?'; '#' ]
          in
          Some (String.lowercase_ascii (String.sub rest 0 stop))
      | _ -> None
    in
    let site = String.lowercase_ascii book.playbook.site in
    let on_site =
      (match host st.observation.url with
       | Some h -> h = site || String.ends_with ~suffix:("." ^ site) h || site = "www." ^ h
       | None -> false)
      || Playbook.page_kind book.playbook.pages ~url:st.observation.url ~text:st.observation.text
         <> None
    in
    if current = Some (book_id book) || on_site then Ok (Continue st)
    else match navigate t book.playbook.entry with
    | Error error -> Error (with_trace st error)
    | Ok _ -> Result.map (fun observation -> Continue { st with observation }) (observe t ())

  (* run-kli0 run-xh5d: asked at the start, after a procedure whose description or the
     mission says the next part is elsewhere, and — through [ask_procedure] — when the
     procedure level is blocked while the mission still names another site. *)
  and ask_playbook (st : state) =
    if st.book <> None && not st.switch then Ok (Continue st)
    else match choose_books st installed with
    | Error error -> Error error
    | Ok (st, None) -> single_goal st
    | Ok (st, Some book) -> adopt_book st book

  and ask_procedure (st : state) =
    match st.book with
    | None -> Error (internal "the run asked the procedure level without a playbook")
    | Some book -> (
        match procedure_question st book with
        | Error error -> Error error
        | Ok question -> (
            match select_procedure t question with
            | Error error -> Error (with_trace st error)
            | Ok choice ->
                let chosen = choice in
                if choice.key = "DONE" then done_guard st ~pages:book.Playbook.playbook.pages
                else if choice.key = "NONE" || choice.key = "BLOCKED" then single_goal st
                else
                  match
                    List.find_opt
                      (fun (proc : Playbook.procedure) -> proc.Playbook.slug = choice.key)
                      (selectable_procedures book)
                  with
                  | None ->
                      Error
                        (internal
                           (Printf.sprintf
                              "the procedure answer names no offered procedure: %s" choice.key))
                  | Some proc ->
                      if List.exists (fun (site, slug, page) ->
                          site = book.Playbook.playbook.site
                          && slug = proc.Playbook.slug
                          && same_page page st.observation) st.verified_pages then
                        (* ncaps-mygj: preserve the model vote without replaying an
                           action already verified on this unchanged page. *)
                        let st = record st ~book ~proc ~planned:false ~choice:chosen
                          ~drives:[] ~expectations:[] ~outcome:"skipped" ~attempts:0
                          ~elapsed:0
                          ~reason:(Some "already verified on this page; treating repeated selection as DONE") in
                        done_guard st ~pages:book.Playbook.playbook.pages
                      else
                        execute st ~book ~proc ~planned:false ~choice:chosen ~optional:false
                          ~values:[]))

  (* run-fp7i: the two levels against the models, the chosen playbook and first procedure
     with its resolved checkers, and no action at all — not even the entry navigation. *)
  and dry_run (st : state) =
    match choose_books st installed with
    | Error error -> Error error
    | Ok (st, None) -> single_goal st
    | Ok (st, Some book) ->
        let st = { st with book = Some book } in
        match procedure_question st book with
                | Error error -> Error error
                | Ok question -> (
                    match select_procedure t question with
                    | Error error -> Error (with_trace st error)
                    | Ok choice ->
                        if choice.key = "NONE" || choice.key = "BLOCKED" then single_goal st
                        else if choice.key = "DONE" then
                          Ok
                            (Finish
                               (finish st (status "blocked")
                                  ~reason:
                                    (Printf.sprintf
                                       "dry run: the procedure level answered %s; nothing was executed"
                                       choice.key)
                                  ()))
                        else
                          match
                            List.find_opt
                              (fun (proc : Playbook.procedure) -> proc.Playbook.slug = choice.key)
                              book.Playbook.playbook.procedures
                          with
                          | None ->
                              Error
                                (internal
                                   (Printf.sprintf
                                      "the procedure answer names no offered procedure: %s"
                                      choice.key))
                          | Some proc ->
                              let checks = resolved_checks book proc st.known in
                              let expectations =
                                List.map
                                  (fun (sentence, checker) ->
                                    P.
                                      {
                                        sentence;
                                        checker = Playbook.checker_name checker;
                                        passed = false;
                                        score = None;
                                      })
                                  checks
                              in
                              let entry =
                                P.
                                  {
                                    slug = proc.Playbook.slug;
                                    site = book.Playbook.playbook.site;
                                    planned = false;
                                    scripts = [];
                                    attempts = 1;
                                    choice = wire_choice choice;
                                    drives = [];
                                    expectations;
                                    outcome = "planned";
                                    elapsed_ms = ms (now () -. started);
                                    reason = Some "dry run: nothing was executed";
                                  }
                              in
                              let st = { st with trace = entry :: st.trace } in
                              Ok
                                (Finish
                                   (finish st (status "blocked")
                                      ~reason:"dry run: nothing was executed" ())))

  in
  (* run-fwl8's refusals are the registry's, before this runs; the first observation is the
     loop's own. *)
  match observe t () with
  | Error error -> Error error
  | Ok observation -> (
      let st = empty observation in
      let missing_start st =
        Ok (Finish (finish st (status "blocked")
          ~reason:"no starting page: provide --url with one HTTP(S) URL without userinfo, one unambiguous URL in the mission, or --tab on an open page" ()))
      in
      (* fly-b6yt fly-xger: a blank tab is not missing a start while an installed book
         can open its entry. Choice runs first. NONE, or no books, still has no page.
         A dry run never navigates, so it does not open an entry either. *)
      let initial () =
        if discovery <> None || observation.url <> "about:blank" then
          if args.dry_run then dry_run st else next st
        else
          let urls = match args.start_url with Some url -> [url]
            | None -> starting_urls args.mission in
          match urls with
          | [url] when valid_start_url url ->
              if args.dry_run then dry_run st
              else Result.bind (navigate t url) (fun () ->
                Result.bind (observe t ()) (fun observation -> next {st with observation}))
          | _ when args.dry_run || installed = [] -> missing_start st
          | _ ->
              match choose_books st installed with
              | Error error -> Error error
              | Ok (st, None) -> missing_start st
              | Ok (st, Some book) ->
                  let* st = adopt_book st book in
                  let* st = ask_procedure st in
                  next st
      in
      match initial () with
      | Error error -> Error error
      | Ok (Finish result) -> Ok result
      | Ok (Continue _) -> Error (internal "the run loop stopped without an ending"))

(* ---------- The handler ---------- *)

let loop ~(handler : handler) ~now ~installed ?discovery ?(on_record = fun _ -> Ok ()) ?(pause_ms = fun _ -> ()) (args : args) =
  if args.max_procedures < 1 || args.deadline_s < 1 || args.max_steps < 1 then
    Error (invalid "run max_steps, max_procedures and deadline_s must be positive")
  else if (match args.start_url with Some url -> not (valid_start_url url) | None -> false) then
    Error (invalid "start_url must be an HTTP(S) URL without userinfo or whitespace")
  else
    let calls = ref 0 and cost = ref 0. in
    let kinds = Hashtbl.create 8 and unreported = ref 0 in
    (* Pure loop tests provide handler replies without provider callbacks; infer their
       historical counts only when the handler emitted no actual request events. *)
    let choice question =
      let before = !calls in
      let result = handler.choose question in
      if !calls = before && not (Model_usage.active ()) then (
        incr calls;
        match result with Ok reply ->
          Option.iter (fun (usage : P.run_usage) -> cost := !cost +. usage.cost) reply.usage
        | Error _ -> ());
      result
    in
    let plan request =
      let before = !calls in
      let result = handler.plan request in
      if !calls = before && not (Model_usage.active ()) then (
        incr calls;
        match result with Ok reply ->
          Option.iter (fun (usage : P.run_usage) -> cost := !cost +. usage.cost) reply.usage
        | Error _ -> ());
      result
    in
    let step request =
      let before = !calls in
      let result = handler.step request in
      if !calls = before && not (Model_usage.active ()) then (
        match result with Ok reply -> calls := !calls + List.length reply.P.steps
        | Error _ -> ());
      result
    in    let module M = struct
      type _ Effect.t += Observe : (observation, P.error) result Effect.t
      type _ Effect.t += Navigate : string -> (unit, P.error) result Effect.t

      type _ Effect.t +=
        Select_playbook : question -> (choice, P.error) result Effect.t

      type _ Effect.t +=
        Select_procedure : question -> (choice, P.error) result Effect.t

      type _ Effect.t +=
        Fill_args : Text_helper.context -> (string option, P.error) result Effect.t

      type _ Effect.t +=
        Execute_step : step_request -> (P.drive_result, P.error) result Effect.t

      type _ Effect.t +=
        Verify :
          Playbook.page list * (string * Playbook.checker) list * int ->
          (P.run_expectation list * observation, P.error) result
          Effect.t

      type _ Effect.t += Plan : plan_request -> (plan_reply, P.error) result Effect.t

      type _ Effect.t +=
        Propose : string * Playbook.procedure -> (string, P.error) result Effect.t

      type _ Effect.t += Hand_off : string -> (P.tab_info, P.error) result Effect.t

      type _ Effect.t +=
        Run_script :
          Playbook.script * (string * string) list -> (script_outcome, P.error) result Effect.t
    end in
    let token =
      {
        observe = (fun () -> Effect.perform M.Observe);
        navigate = (fun url -> Effect.perform (M.Navigate url));
        select_playbook = (fun question -> Effect.perform (M.Select_playbook question));
        select_procedure = (fun question -> Effect.perform (M.Select_procedure question));
        fill_args = (fun context -> Effect.perform (M.Fill_args context));
        execute_step = (fun request -> Effect.perform (M.Execute_step request));
        verify = (fun pages checks timeout_s -> Effect.perform (M.Verify (pages, checks, timeout_s)));
        plan = (fun request -> Effect.perform (M.Plan request));
        propose = (fun site proc -> Effect.perform (M.Propose (site, proc)));
        hand_off = (fun reason -> Effect.perform (M.Hand_off reason));
        run_script = (fun script args -> Effect.perform (M.Run_script (script, args)));
      }
    in
    let meter = function
      | Model_usage.Start kind ->
          incr calls; incr unreported;
          Hashtbl.replace kinds kind
            (1 + Option.value ~default:0 (Hashtbl.find_opt kinds kind))
      | Model_usage.Reported (_, amount) ->
          (match amount with Some value -> cost := !cost +. value; decr unreported
           | None -> ())
    in
    let outcome = Model_usage.with_meter meter (fun () ->
      Effect.Deep.match_with (fun () -> compute token ~direct_fill:handler.text_value ~direct_script:(fun script args -> handler.script script ~args) ~on_record ~pause_ms ~now ~installed ?discovery args) ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            match eff with
            | M.Observe ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.observe ()))
            | M.Navigate url ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.navigate url))
            | M.Select_playbook question ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (choice question))
            | M.Select_procedure question ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (choice question))
            | M.Fill_args context ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.text_value context))
            | M.Execute_step request ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (step request))
            | M.Verify (pages, checks, timeout_s) ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.verify ~pages ~checks ~timeout_s))
            | M.Plan request ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (plan request))
            | M.Propose (site, proc) ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.propose ~site proc))
            | M.Hand_off reason ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.hand_off ~reason))
            | M.Run_script (script, args) ->
                Some
                  (fun (k : (a, (P.run_result, P.error) result) Effect.Deep.continuation) ->
                    Effect.Deep.continue k (handler.script script ~args))
            | _ -> None);
      }) in
    Result.map (fun result ->
      let models = `Assoc (Hashtbl.fold (fun kind n acc -> (kind, `Int n) :: acc) kinds []) in
      let data = match result.P.data with
        | `Assoc fields -> `Assoc (("model_calls_by_kind", models) ::
            ("cost_unreported", `Int !unreported) ::
            ("reported_cost", `Float !cost) :: fields)
        | other -> other in
      { result with P.model_calls = !calls; model_cost = (if !unreported > 0 then None else Some !cost); data }) outcome
    |> fun outcome -> Result.bind outcome (fun result ->
      match result.P.operator_state with
      | Some state when not args.dry_run ->
          Result.map (fun () -> result) (on_record (`Assoc [
            ("kind", `String "operator-state"); ("source", `String "operator"); ("state", state)]))
      | _ -> Ok result)
