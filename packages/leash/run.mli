(** The run loop: one mission over the installed playbooks (L31;
    docs/issues/run/01-run.md, milestone 7).

    A mission is one sentence of human language. A playbook is a site's file of named
    procedures written in human language. The loop asks three levels of judgment through
    JEV with an authoritative NONE candidate (L45 fly-ab3f): which playbook serves the
    current part of the mission (asked at the start and when the site changes, run-kli0),
    which procedure comes next (asked every turn over the small observed state, run-qq3o
    run-pvmc), and the operator level that drives each step (run-d82w — exactly the tested
    {!Drive} loop, one call per playbook step). Expectations are verified by code where a
    checker applies and by a JEV score where only judgment can (run-tny5 run-vbys); DONE
    is accepted only against a fresh verification of the mission's own expectations or,
    when the mission carries none, of the last verified procedure's (run-4j1v, the guard
    L30's measurement demanded). No books, NONE, or a BLOCKED procedure choice continues
    the full original mission on the current page through {!Drive}, preserving prior
    actions and the remaining mission budget, without a planner (L45 fly-fu94 fly-prli).
    Legacy authored-procedure failure recovery remains bounded; a verified recovery
    proposal is reported, never merged into a book. Operator results are bounded page
    evidence, not normalized script records.

    Everything is a handler: production ({!Tabs.run}), a scripted test and a dry run are
    this same computation with different handlers, and the run itself touches no browser,
    model, clock or file. *)

type observation = {
  url : string;
  title : string;
  text : string;
      (** The page's visible text. Checkers and the text helper read it; the upper levels
          never do (run-pvmc). *)
  dialog : Protocol.dialog option;
  rows : (string * string) list;
      (** Role and accessible name of each row, for the [<role> named <text>] checker. *)
  downloads : (string * string * string) list;
      (** Suggested name, MIME and state of each download of the tab, for the download
          checker (run-ykq4). *)
  snapshot : Protocol.snapshot;
}
(** What one observation of the page gives the loop: the same facts the checkers, the text
    helper and the last snapshot of a result need. *)

type choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : Protocol.run_usage option;
  judgments : Protocol.playbook_choice list;
}
(** One upper-level decision (run-xqh8). Probability, confidence and usage describe JEV;
    [key] may be the reviewed choice. [judgments] preserves each original playbook answer
    in decision order, including a refused planner review. Empty for unreviewed answers;
    the run then records JEV directly. *)

type question = {
  name : string;
  instructions : string;
  criteria : (string * string) list;
  state : Yojson.Safe.t;
}
(** One choice question as the loop builds it. [state] is the small semantic state of
    story 18 (run-pvmc) and [criteria] never exceeds 255 entries (the JEV ceiling, the
    reason playbooks are selected rather than merged). *)

type step_request = {
  goal : string;
  hint : string option;
  recent : Jev_request.recent_action list;
  max_steps : int;
  deadline_s : int;
  dry_run : bool;
  script_offers : url:string -> text:string -> Jev_request.offered_script list;
  on_script : url:string -> string -> (Jev_request.script_effect, Protocol.error) result;
  reached : (start_url:string -> Protocol.snapshot -> text:string -> bool) option;
      (** pbk-eyya: the goal step's [until], checked in code after each executed action;
          [true] ends the step [done]. *)
}
(** One playbook step as the operator level receives it (run-d82w): the goal with the
    step's hint shaping its text, and the step's own cap and deadline — the procedure's
    when it declares them, the operator's defaults otherwise, always bounded by what is
    left of the run. *)

type script_outcome =
  | Collected of { value : Yojson.Safe.t; records : int; bytes : int; elapsed_ms : int }
  | Rejected of { reason : string; elapsed_ms : int }
      (** extr-8o1h: what a script step came to. [Collected] is a result that fit its
          [returns] shape and its size bound; [Rejected] is a script that threw, whose
          result did not fit its shape or was too large. A rejection fails the procedure's
          attempt with its reason in the trace (the whole procedure is replayed once, like
          a failed expectation); a protocol error is a browser failure and ends the run.
      *)

type plan_trigger =
  | Blocked
  | Failed
  | Arguments
      (** The three points JEV stopped and a planner turn is asked: the procedure level
          answered BLOCKED, a procedure failed its expectations twice, or a required
          argument could not be filled (run-w7ke). *)

type plan_answer =
  | Procedure of Playbook.procedure
  | Handoff of string
  | Fail of string
      (** What a planner turn may answer (run-rq6i, L32): a procedure to run now, a
          handoff with the reason the human is shown, or a failure with its reason. *)

type plan_reply = {
  answer : plan_answer;
  expect : string list;
  usage : Protocol.run_usage option;
  pages : Playbook.page list;  (** Newly proposed discovery page kinds. *)
}
(** One planner turn's answer with what came beside it (run-rq6i run-2tt3 run-obtt):
    [expect] is the mission's own expectations the planner attached on its first turn —
    the sentences DONE is then verified against, when the caller stated none — and [usage]
    is what the turn cost, carried into the run's trace. *)

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  site : string option;
  playbook : Playbook.t option;
  recent : (string * string) list;
  arguments : (string * string) list;
  page_kind : string option;
  title : string;
  url : string;
  text : string;
}
(** What a planner turn is asked from (run-rq6i, L32): the mission, the point JEV stopped
    and why, the current playbook in its own schema — which is what a new procedure has to
    fit — the trace so far, the arguments already known, and the observed page: its kind,
    title and URL plus its visible text, bounded by the planner. This is the one level
    page text reaches; the two choice levels never see it (run-pvmc). *)

val trigger_name : plan_trigger -> string
(** run-xqh8: the trigger as the trace and the planner's request name it — ["blocked"],
    ["failed"] or ["arguments"]. *)

type levels = {
  choose : deadline:Ox.Duration.t -> question -> (choice, Protocol.error) result;
  score :
    deadline:Ox.Duration.t ->
    sentence:string ->
    state:Yojson.Safe.t ->
    (float, Protocol.error) result;
  plan : deadline:Ox.Duration.t -> plan_request -> (plan_reply, Protocol.error) result;
}
(** run-7blx: the upper levels as one seam over one models service — the two choice
    questions, the score question a judgment checker asks ("how well does the current page
    satisfy: <sentence>?" over the page summary), and the planner turn. Production passes
    {!Models.levels}; a scripted test passes its own record. *)

type handler = {
  observe : unit -> (observation, Protocol.error) result;
  navigate : string -> (unit, Protocol.error) result;
      (** run-xh5d: the entry navigation of a playbook switch, through the same registry
          path the [nav] command uses. *)
  choose : question -> (choice, Protocol.error) result;
      (** Both choice levels: [question]'s [name] says which one. *)
  text_value : Text_helper.context -> (string option, Protocol.error) result;
      (** run-5rll: the text helper, asked once per argument the mission does not supply.
      *)
  step : step_request -> (Protocol.drive_result, Protocol.error) result;
      (** run-d82w: one operator step — exactly one {!Drive} call. *)
  verify :
    pages:Playbook.page list ->
    checks:(string * Playbook.checker) list ->
    timeout_s:int ->
    (Protocol.run_expectation list * observation, Protocol.error) result;
      (** run-l06s run-vbys run-xqh8: each expectation with its verdict, checked by code
          where a checker applies and scored by JEV where none does, with the bounded
          wait. [pages] are the current playbook's page kinds: the [page_kind] checker is
          decided against them. The observation it returns is the one it judged. *)
  plan : plan_request -> (plan_reply, Protocol.error) result;
      (** run-w7ke run-rq6i: the planner turn, asked only at the three triggers and only
          while the turn cap allows it. Production is Luna through {!Models.levels}; a
          scripted test answers with a record of its own. *)
  propose : site:string -> Playbook.procedure -> (string, Protocol.error) result;
      (** run-m0r8: write a planner-written procedure that ran and passed its expectations
          to the XDG state directory and answer the path written. Production writes the
          file; the run only reports it, and nothing merges it but the operator's
          [playbook accept]. *)
  hand_off : reason:string -> (Protocol.tab_info, Protocol.error) result;
      (** run-klp9: a planner's handoff, which leaves the tab [with_human]. *)
  script :
    Playbook.script ->
    args:(string * string) list ->
    (script_outcome, Protocol.error) result;
      (** extr-8o1h extr-k40c: run one of the current playbook's scripts on the page. The
          argument is a {!Playbook.script}, which only the playbook loader makes, so
          nothing a model wrote can reach it; production passes {!Reading.script}'s result
          mapped to a {!script_outcome}. A [dialog-open] error ends the run as a drive's
          dialog does. *)
}

type args = {
  mission : string;
  max_steps : int;
  start_url : string option;
  max_procedures : int;  (** Default 40 (run-vspj). *)
  deadline_s : int;  (** Default 900 (run-vspj). *)
  dry_run : bool;
  max_plans : int;
      (** run-obtt: how many planner turns the run may take, 3 by default. The trigger
          that arrives with the cap reached ends the run instead of asking again. *)
  expect : string list;
      (** The mission's own expectations, which DONE is verified against independently of
          the last procedure (run-4j1v). L32's planner attaches them when the mission
          implies them; a caller may state them from L31 on. *)
}

val of_args : Protocol.run_args -> args
(** The wire arguments with their defaults: 40 procedures, 900 seconds, no dry run, three
    planner turns, no mission expectations. *)

type discovery = { book : Playbook.loaded; max_steps : int; max_cost : float }
(** The seed book is temporary and is never installed by discovery. *)

val unsafe_action : string -> string option
(** The protected action class (payment, deletion, messaging) in a goal or row label. *)

val loop :
  handler:handler ->
  now:(unit -> float) ->
  installed:Playbook.loaded list ->
  ?discovery:discovery ->
  ?on_book:(Playbook.loaded option -> unit) ->
  ?on_record:(Yojson.Safe.t -> (unit, Protocol.error) result) ->
  ?pause_ms:(int -> unit) ->
  args ->
  (Protocol.run_result, Protocol.error) result
(** [loop ~handler ~now ~installed args] runs the mission.

    Every ending is a result, never a refusal: [done] when DONE was verified, [blocked] or
    [failed] when the planner answered [Fail] or its turn cap was reached (run-obtt),
    [handoff] when it asked for the human, [limit] at the procedure cap, [deadline] at the
    run's deadline, and [error] when a dialog is open on the page (run-klp9). A protocol
    error is what the run cannot start with — the arguments, or a mission expectation the
    playbook cannot resolve — or a model or browser failure, which carries the trace it
    had completed in [detail.procedures] (run-xqh8). *)
