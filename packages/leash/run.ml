(* L31 run-vj48 run-9ypy run-4mzm (docs/issues/run/01-run.md, milestone 7): the run loop —
   one mission over the installed playbooks.

   The loop is an effect computation over a local handler token, exactly as the drive is
   (drive-8n2z, eta-next ADR-0006): Select_playbook, Select_procedure, Fill_args,
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

type choice = P.run_choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : P.run_usage option;
}
(** One answer of an upper level: the criterion it chose and the distribution behind it.
    It is the protocol's own {!Protocol.run_choice}, so the trace records the answer the
    handler gave without a translation. *)

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
  max_steps : int;
  deadline_s : int;
  dry_run : bool;
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
    deadline:Eta.Duration.t -> question -> (choice, P.error) result;
  score :
    deadline:Eta.Duration.t -> sentence:string -> state:Yojson.Safe.t -> (float, P.error) result;
  plan :
    deadline:Eta.Duration.t -> plan_request -> (plan_reply, P.error) result;
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
    max_procedures = Option.value ~default:40 args.P.max_procedures;
    deadline_s = Option.value ~default:900 args.P.deadline_s;
    dry_run = Option.value ~default:false args.P.dry_run;
    max_plans = 3;
    expect = Option.value ~default:[] args.P.expect;
  }

(* ---------- Small helpers ---------- *)

let code name = match P.Error_code.of_string name with Ok x -> x | Error _ -> assert false
let status name = match P.Run_status.of_string name with Ok x -> x | Error _ -> assert false

let invalid message = P.{ code = code "invalid-request"; message; detail = None }
let internal message = P.{ code = code "internal"; message; detail = None }
let ms seconds = max 0 (int_of_float (seconds *. 1000.))
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

(* The first installed playbook for a site serves it; a second file for the same site is
   not a second criterion (the choice keys are sites). *)
let installed_playbooks books =
  let rec go seen acc = function
    | [] -> List.rev acc
    | (book : Playbook.loaded) :: rest ->
        let site = book.Playbook.playbook.Playbook.site in
        if List.mem site seen then go seen acc rest
        else go (site :: seen) (book :: acc) rest
  in
  go [] [] books

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
  proposals : string list;  (** run-m0r8: the proposal files the run wrote, oldest first. *)
  count : int;  (** Procedures executed, the [use] calls and planner procedures included. *)
  records : Yojson.Safe.t list;
      (** extr-b3u0: at most five truncated display samples, newest first; never
          passed to a model. Full validated records are streamed only. *)
  collected_count : int;
  pages : int;  (** extr-ve3k: verified pages, including the first page. *)
  pending_scripts : P.run_script list;
      (** The script calls of the procedure being executed, newest first, moved into its
          trace entry when it is recorded. *)
  switch : bool;  (** The next turn asks the playbook level. *)
  asked_switch : bool;  (** A switch was already asked since the last procedure. *)
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
      planner_turns = List.rev st.plans;
      proposals = List.rev st.proposals;
      collected = st.collected_count;
      data = `Assoc [ ("count", `Int st.collected_count); ("first", `List (List.rev st.records)); ("pages", `Int st.pages); ("scripts", `List scripts) ];
      model_calls = 0;
      model_cost = 0.;
      operator_steps = [];
      final = st.observation.snapshot;
      reason;
    }

(* drive-y7v8's rule for a run: a model failure carries the work it had done when it
   failed, so a failed mission is auditable. *)
let with_trace (st : state) (error : P.error) =
  if P.Error_code.to_string error.P.code <> "model-unavailable" then error
  else
    let kind =
      match error.P.detail with
      | Some (`Assoc fields) -> (
          match List.assoc_opt "code" fields with Some json -> json | None -> `String "unavailable")
      | _ -> `String "unavailable"
    in
    {
      error with
      P.detail =
        Some
          (`Assoc
            [
              ("code", kind);
              ( "site",
                match st.book with
                | Some book -> `String book.Playbook.playbook.Playbook.site
                | None -> `Null );
              ("procedures", `List (List.map P.yojson_of_run_procedure (List.rev st.trace)));
            ]);
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
  | Steps_failed of state * P.run_drive list * string
      (** extr-8o1h: a script step was rejected. The procedure's remaining steps do not
          run and, unlike a failed expectation, nothing is verified: the attempt failed
          for the reason given. *)
  | Steps_finish of P.run_result
      (** The run ended inside a step: a dialog, or a planner turn a called procedure
          asked for. *)

let compute (t : token) ~on_record ~pause_ms ~now ~installed ?discovery (args : args) : (P.run_result, P.error) result =
  let installed = installed_playbooks installed in
  let started = now () in
  let deadline = started +. float_of_int args.deadline_s in
  let remaining () = max 1 (int_of_float (deadline -. now ())) in
  let empty observation =
    {
      steps_used = 0;
      trace = [];
      plans = [];
      recent = [];
      known = [];
      visited = [];
      book = Option.map (fun (d : discovery) -> d.book) discovery;
      checks = [];
      mission_expect = [];
      mission_checks = [];
      proposals = [];
      count = 0;
        records = [];
        collected_count = 0;
        pages = 0;
        pending_scripts = [];
      switch = false;
      asked_switch = false;
      observation;
    }
  in
  let dedupe_key = ref None in
  let seen = Hashtbl.create 128 in
  let accept_record item =
    match !dedupe_key with
    | None -> Result.map (fun () -> true) (on_record item)
    | Some key -> (
        match item with
        | `Assoc fields -> (
            match List.assoc_opt key fields with
            | None -> Error (invalid ("repeat key missing from record: " ^ key))
            | Some identity ->
                let identity = Yojson.Safe.to_string identity in
                if Hashtbl.mem seen identity then Ok false
                else
                  match on_record item with
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
      [
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
  in

  (* run-kli0 run-qq3o: the playbook question's criteria are the installed playbooks by
     site and description plus none; playbooks are selected, never merged, so no choice
     ever carries more than 255 options. *)
  let playbook_question (st : state) =
    let criteria =
      List.map
        (fun (book : Playbook.loaded) -> (book.Playbook.playbook.site, book.Playbook.playbook.description))
        installed
      @ [ ("none", "no installed playbook serves this part of the mission") ]
    in
    if List.length criteria > 255 then
      Error (invalid "more than 255 playbooks are installed; one choice is bounded at 255")
    else
      Ok
        {
          name = "select_playbook";
          instructions = Questions.select_playbook;
          criteria;
          state = state_json st;
        }
  in

  (* run-qq3o: every turn, the current playbook's procedures plus DONE and BLOCKED. *)
  let procedure_question (st : state) (book : Playbook.loaded) =
    let criteria =
      List.map
        (fun (proc : Playbook.procedure) -> (proc.Playbook.slug, proc.Playbook.description))
        book.Playbook.playbook.procedures
      @ [
          ("DONE", "the mission is visibly complete");
          ("BLOCKED", "no offered procedure can progress");
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
          choice;
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
  let fill_arguments (st : state) (proc : Playbook.procedure) ~values =
    let declared = Option.value ~default:[] proc.Playbook.args in
    let ask st name =
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
      match fill_args t context with
      | Error error -> Error error
      | Ok None ->
          Ok
            (Unfilled
               ( st,
                 Printf.sprintf "no value for argument %S of procedure %s" name
                   proc.Playbook.slug ))
      | Ok (Some value) -> Ok (Filled ({ st with known = (name, value) :: st.known }, [ (name, value) ]))
    in
    let rec go st acc = function
      | [] ->
          (* The caller's values and the run's known arguments travel with the resolved
             ones, so a step of a procedure that declares no argument still sees what the
             mission supplied (run-5rll). *)
          Ok (Filled (st, acc @ values @ st.known))
      | name :: rest -> (
          match (List.assoc_opt name values, List.assoc_opt name st.known) with
          | Some value, _ | None, Some value -> go st (acc @ [ (name, value) ]) rest
          | None, None -> (
              match ask st name with
              | Error error -> Error error
              | Ok (Unfilled _ as unfilled) -> Ok unfilled
              | Ok (Filled (st, answered)) -> go st (acc @ answered) rest))
    in
    go st [] declared
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
                  | None -> run_choice { key = proc.slug; probabilities = `Assoc []; confidence = 1.; usage = None }
                  | Some _ -> (match procedure_question st book with
                      | Error error -> Error error
                      | Ok question -> (match select_procedure t question with
                          | Error error -> Error (with_trace st error)
                          | Ok choice when choice.key = "DONE" -> done_guard st book ~choice
                          | Ok choice when choice.key = "BLOCKED" -> Ok (Finish (finish st (status "blocked") ~reason:"discovery procedure selection was blocked" ()))
                          | Ok choice -> run_choice choice))))

  (* run-d82w run-prrv: a procedure's steps in order. A [use] runs the named procedure
     inline with its own expectations; an [optional] one is skipped when its first step
     ends blocked within two operator steps. A drive that ends anything but [done] ends the
     procedure's remaining steps — the expectations decide what that means (run-k8bx). *)
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
          let cap = match discovery with None -> cap | Some d -> min cap (d.max_steps - st.steps_used) in
          let request =
            { goal = goal_text; hint = goal.Playbook.hint; max_steps = cap; deadline_s; dry_run = false }
          in
          (match (match discovery with None -> None | Some _ -> unsafe_action goal_text) with
          | Some kind -> Ok (Steps_finish (finish st (status "blocked") ~reason:("discovery stopped before " ^ kind ^ " action") ()))
          | None -> match execute_step t request with
          | Error error when discovery <> None && String.starts_with ~prefix:"discovery stopped before " error.P.message ->
              Ok (Steps_finish (finish st (status "blocked") ~reason:error.P.message ()))
          | Error error -> Error error
          | Ok drive ->
              let st = { st with steps_used = st.steps_used + List.length drive.P.steps } in
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
                  if optional && first
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
                  else Ok (Steps_done (st, List.rev (entry :: drives), None))))
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
                        match accept_record item with
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
                { key = sub.Playbook.slug; probabilities = `Assoc []; confidence = 1.; usage = None }
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
        dedupe_key := Option.map (fun (repeat : Playbook.repeat) -> repeat.key) proc.Playbook.repeat;
        (match proc.Playbook.repeat with None -> () | Some _ -> Hashtbl.clear seen);
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
                            let st = { st with pages = st.pages + (if proc.Playbook.repeat = None then 0 else 1) } in
                            let st = record st ~book ~proc ~planned ~choice ~drives
                              ~expectations:results ~outcome:"verified" ~attempts:n
                              ~elapsed:(ms (now () -. proc_started)) ~reason:None in
                            (match proc.Playbook.repeat with
                            | None -> Ok (Continue st)
                            | Some repeat ->
                                let result = paginate st ~book ~values ~choice repeat in
                                dedupe_key := None;
                                result))
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
    let until_checker = match Playbook.resolve book.Playbook.playbook.pages repeat.until with
      | Ok checker -> checker | Error _ -> assert false in
    let rec page st index =
      if index >= repeat.max || st.count >= args.max_procedures then Ok (Continue st)
      else if now () >= deadline then
        Ok (Finish (finish st (status "deadline") ~reason:"repeat deadline" ()))
      else
        match verify t ~pages:book.Playbook.playbook.pages
          ~checks:[ (repeat.until, until_checker) ] ~timeout_s:1 with
        | Error error -> Error (with_trace st error)
        | Ok (until_results, observation) ->
            let st = { st with observation } in
            if List.for_all (fun (r : P.run_expectation) -> r.passed) until_results then Ok (Continue st)
            else (
              pause_ms (Option.value ~default:500 repeat.delay_ms);
              if now () >= deadline then
                Ok (Finish (finish st (status "deadline") ~reason:"repeat deadline" ()))
              else match steps st book next values ~optional:false with
              | Error error -> Error error
              | Ok (Steps_finish result) -> Ok (Finish result)
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
                        Ok (Continue st)
                      else
                        let st = { st with checks; pages = st.pages + 1 } in
                        let st = record st ~book ~proc:next ~planned:false
                          ~choice:{ choice with key = next.slug } ~drives ~expectations:results
                          ~outcome:"verified" ~attempts:1 ~elapsed:0 ~reason:None in
                        page st (index + 1))
    in page st 1

  (* run-4j1v, the L30 guard: DONE is accepted only against the mission's own expectations,
     verified now on a fresh observation, or — when the mission carries none — against the
     expectations of the procedure that ran last, re-verified the same way. A DONE nothing
     can verify is refused to the planner. *)
  and done_guard (st : state) (book : Playbook.loaded) ~choice =
    let mission =
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | sentence :: rest -> (
            let sentence = Playbook.substitute st.known sentence in
            match Playbook.resolve book.Playbook.playbook.pages sentence with
            | Ok checker -> go ((sentence, checker) :: acc) rest
            | Error why -> Error (invalid ("expect: " ^ why)))
      in
      (* run-2tt3: the mission's expectations are the caller's when the caller stated them,
         and otherwise the ones the planner attached on its first turn. *)
      go [] (if args.expect <> [] then args.expect else st.mission_expect)
    in
    match mission with
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

  and check_done (st : state) ~mission checks =
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
        else
          planner st ~trigger:Blocked
            ~reason:(Printf.sprintf "DONE was refused: %s" (failures results))

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
  and single_goal (st : state) =
    let request =
      { goal = args.mission; hint = None; max_steps = 30;
        deadline_s = remaining (); dry_run = args.dry_run }
    in
    match execute_step t request with
    | Error error -> Error error
    | Ok drive ->
        let name = P.Drive_status.to_string drive.P.status in
        let status =
          match name with
          | "done" -> status "done"
          | "step-cap" -> status "limit"
          | "deadline" -> status "deadline"
          | "error" -> status "error"
          | _ -> status "blocked"
        in
        Ok (Finish { (finish { st with book = None } status ?reason:drive.P.reason ()) with
          P.final = drive.P.final; operator_steps = drive.P.steps })

  (* run-kli0 run-xh5d: asked at the start, after a procedure whose description or the
     mission says the next part is elsewhere, and — through [ask_procedure] — when the
     procedure level is blocked while the mission still names another site. A switch
     navigates the same tab to the playbook's entry, so the profile's logins carry over. *)
  and ask_playbook (st : state) =
    if st.book <> None && not st.switch then Ok (Continue st)
    else if installed = [] then
      (* run-tcuz: nothing to choose from, and a question whose only criterion is [none]
         is not worth a model call. *)
      single_goal st
    else
      match playbook_question st with
      | Error error -> Error error
      | Ok question -> (
          match select_playbook t question with
          | Error error -> Error (with_trace st error)
          | Ok choice -> (
              if choice.key = "none" then
                single_goal st
              else
                match
                  List.find_opt
                    (fun (book : Playbook.loaded) -> book.Playbook.playbook.site = choice.key)
                    installed
                with
                | None ->
                    Error
                      (internal
                         (Printf.sprintf "the playbook answer names no installed playbook: %s"
                            choice.key))
                | Some book -> (
                    let current =
                      match st.book with
                      | Some current -> current.Playbook.playbook.site
                      | None -> ""
                    in
                    let st =
                      {
                        st with
                        book = Some book;
                        switch = false;
                        visited = book.Playbook.playbook.site :: st.visited;
                      }
                    in
                    if book.Playbook.playbook.site = current then Ok (Continue st)
                    else
                      match navigate t book.Playbook.playbook.entry with
                      | Error error -> Error (with_trace st error)
                      | Ok _ -> (
                          match observe t () with
                          | Error error -> Error (with_trace st error)
                          | Ok observation -> Ok (Continue { st with observation })))))

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
                if choice.key = "DONE" then done_guard st book ~choice:chosen
                else if choice.key = "BLOCKED" then
                  (* run-kli0: the playbook level gets one last look before the planner —
                     another installed site may serve the next part — and a second BLOCKED
                     from the same playbook goes to the planner. *)
                  if not st.asked_switch then
                    Ok (Continue { st with switch = true; asked_switch = true })
                  else
                    planner st ~trigger:Blocked
                      ~reason:"the procedure level answered BLOCKED"
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
                              "the procedure answer names no offered procedure: %s" choice.key))
                  | Some proc ->
                      execute st ~book ~proc ~planned:false ~choice:chosen ~optional:false
                        ~values:[]))

  (* run-fp7i: the two levels against the models, the chosen playbook and first procedure
     with its resolved checkers, and no action at all — not even the entry navigation. *)
  and dry_run (st : state) =
    if installed = [] then single_goal st else match playbook_question st with
    | Error error -> Error error
    | Ok question -> (
        match select_playbook t question with
        | Error error -> Error (with_trace st error)
        | Ok choice ->
            let book =
              if choice.key = "none" then None
              else
                List.find_opt
                  (fun (book : Playbook.loaded) -> book.Playbook.playbook.site = choice.key)
                  installed
            in
            let st = { st with book } in
            (match book with
            | None -> single_goal st
            | Some book -> (
                match procedure_question st book with
                | Error error -> Error error
                | Ok question -> (
                    match select_procedure t question with
                    | Error error -> Error (with_trace st error)
                    | Ok choice ->
                        if choice.key = "DONE" || choice.key = "BLOCKED" then
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
                                    choice;
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
                                      ~reason:"dry run: nothing was executed" ()))))))

  in
  (* run-fwl8's refusals are the registry's, before this runs; the first observation is the
     loop's own. *)
  match observe t () with
  | Error error -> Error error
  | Ok observation -> (
      let st = empty observation in
      match (if args.dry_run then dry_run st else next st) with
      | Error error -> Error error
      | Ok (Finish result) -> Ok result
      | Ok (Continue _) -> Error (internal "the run loop stopped without an ending"))

(* ---------- The handler ---------- *)

let loop ~(handler : handler) ~now ~installed ?discovery ?(on_record = fun _ -> Ok ()) ?(pause_ms = fun _ -> ()) (args : args) =
  if args.max_procedures < 1 || args.deadline_s < 1 then
    Error (invalid "run max_procedures and deadline_s must be positive")
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
      Effect.Deep.match_with (fun () -> compute token ~on_record ~pause_ms ~now ~installed ?discovery args) ()
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
            ("cost_unreported", `Int !unreported) :: fields)
        | other -> other in
      { result with P.model_calls = !calls; model_cost = !cost; data }) outcome
