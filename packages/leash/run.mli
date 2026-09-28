(** The run loop: one mission over the installed playbooks (L31;
    docs/issues/run/01-run.md, milestone 7).

    A mission is one sentence of human language. A playbook is a site's file of named
    procedures written in human language. The loop asks three levels of judgment, all JEV:
    which playbook serves the current part of the mission (asked at the start and when the
    site changes, run-kli0), which procedure comes next (asked every turn over the small
    observed state, run-qq3o run-pvmc), and the operator level that drives each step
    (run-d82w — exactly the tested {!Drive} loop, one call per playbook step).
    Expectations are verified by code where a checker applies and by a JEV score where
    only judgment can (run-tny5 run-vbys); DONE is accepted only against a fresh
    verification of the mission's own expectations or, when the mission carries none, of
    the last verified procedure's (run-4j1v, the guard L30's measurement demanded). When
    JEV stops — a BLOCKED answer, a procedure that failed twice, an argument the mission
    does not supply — one planner turn is asked (run-w7ke); L32 fills it with Luna, and
    until then its handler answers [Fail], so such a run ends [blocked] or [failed] naming
    why.

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

type choice = Protocol.run_choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : Protocol.run_usage option;
}
(** One upper-level answer: the chosen criterion and the distribution behind it
    (run-xqh8). *)

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
  max_steps : int;
  deadline_s : int;
}
(** One playbook step as the operator level receives it (run-d82w): the goal with the
    step's hint shaping its text, and the step's own cap and deadline — the procedure's
    when it declares them, the operator's defaults otherwise, always bounded by what is
    left of the run. *)

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

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  site : string option;
  procedures : (string * string) list;
  recent : (string * string) list;
}
(** What a planner turn is asked from: the mission, the point JEV stopped and why, the
    current playbook's procedures and the run so far. L32 adds the page summary, the
    bounded page text and the trace. *)

type levels = {
  choose : deadline:Eta.Duration.t -> question -> (choice, Protocol.error) result;
  score :
    deadline:Eta.Duration.t ->
    sentence:string ->
    state:Yojson.Safe.t ->
    (float, Protocol.error) result;
  plan : deadline:Eta.Duration.t -> plan_request -> (plan_answer, Protocol.error) result;
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
  plan : plan_request -> (plan_answer, Protocol.error) result;
      (** run-w7ke: the planner turn. L31's production answer is the stub's [Fail]; L32
          replaces the handler. *)
  hand_off : reason:string -> (Protocol.tab_info, Protocol.error) result;
      (** run-klp9: a planner's handoff, which leaves the tab [with_human]. *)
}

type args = {
  mission : string;
  max_procedures : int;  (** Default 40 (run-vspj). *)
  deadline_s : int;  (** Default 900 (run-vspj). *)
  dry_run : bool;
  expect : string list;
      (** The mission's own expectations, which DONE is verified against independently of
          the last procedure (run-4j1v). L32's planner attaches them when the mission
          implies them; a caller may state them from L31 on. *)
}

val of_args : Protocol.run_args -> args
(** The wire arguments with their defaults: 40 procedures, 900 seconds, no dry run, no
    mission expectations. *)

val loop :
  handler:handler ->
  now:(unit -> float) ->
  installed:Playbook.loaded list ->
  args ->
  (Protocol.run_result, Protocol.error) result
(** [loop ~handler ~now ~installed args] runs the mission.

    Every ending is a result, never a refusal: [done] when DONE was verified, [blocked] or
    [failed] when the planner answered [Fail], [handoff] when it asked for the human,
    [limit] at the procedure cap, [deadline] at the run's deadline, and [error] when a
    dialog is open on the page (run-klp9). A protocol error is what the run cannot start
    with — the arguments, or a mission expectation the playbook cannot resolve — or a
    model or browser failure, which carries the trace it had completed in
    [detail.procedures] (run-xqh8). *)
