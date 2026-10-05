(** revert-eft1 (ADR-0015): [drive MISSION] is JEV's loop. The decision model decides
    every step over the element table ({!Drive}); the site playbook's procedures and
    scripts are offered to it as operations. The planner is optional and only consulted:
    when JEV answers BLOCKED or its loop stops, when an expectation fails, and once at the
    end of a mission that asks for an answer. All effects use handlers, so tests and
    dry-run need no browser or model service. *)

type observation = {
  url : string;
  title : string;
  text : string;
      (** The page's visible text. Checkers and the text helper read it; the upper levels
          receive a bounded projection (pilot-ukoh). *)
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
  stop_on_navigation : bool;
  deadline_s : int;
  dry_run : bool;
  script_offers : url:string -> text:string -> Jev_request.offered_script list;
  on_script : url:string -> string -> (Jev_request.script_effect, Protocol.error) result;
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
          leg with its reason in the trace; the pilot receives the failure and chooses the
          next mission step. *)

type plan_trigger =
  | Blocked
  | Expectation
  | Final
      (** revert-24kr: JEV answered BLOCKED or its loop stopped; a procedure's or the
          mission's expectation failed; or the mission asks for an answer at its end. *)

type candidate = Playbook.procedure
(** A procedure of the site's hand-written playbook, offered to JEV as an operation. *)

type plan_answer =
  | Hint of string
  | Handoff of string
  | Notify of string
  | Fail of string
  | Answer of { result : string; evidence : string list; done_ : bool }
      (** revert-apgf revert-bqrq: a hint becomes JEV's goal for its next steps; the
          planner never acts. [Answer] is the end-of-mission judgment. *)

type plan_reply = { answer : plan_answer; usage : Protocol.run_usage option }

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  secret_names : string list;
  site : string option;
  notes : string option;
  history : (string * string) list;
      (** JEV's drives so far: the goal it was given and how it ended, oldest first. *)
  url : string;
  title : string;
  text : string;
  snapshot : Protocol.snapshot;
}
(** What the planner is asked from: why it is asked, the mission, JEV's history, and the
    current page (bounded text and element table). *)

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
      (** run-xflk run-vbys run-xqh8: each expectation with its verdict, checked by code
          where a checker applies and scored by JEV where none does, with the bounded
          wait. [pages] are the current playbook's page kinds: the [page_kind] checker is
          decided against them. The observation it returns is the one it judged. *)
  plan : plan_request -> (plan_reply, Protocol.error) result;
      (** run-w7ke run-rq6i: the planner turn, asked only at the three triggers and only
          while the turn cap allows it. Production is Luna through {!Models.levels}; a
          scripted test answers with a record of its own. *)
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
(** The wire arguments with their defaults: 15 navigator steps, 12 pilot turns, 600
    seconds, no dry run and no mission expectations. *)

val authorises : string -> string -> bool
(** Whether the mission explicitly names the protected action category without a refusal.
*)

val unsafe_action : string -> string option
(** The protected action class (payment, deletion, messaging) in a goal or row label. *)

val loop :
  handler:handler ->
  now:(unit -> float) ->
  installed:Playbook.loaded list ->
  ?planner:bool ->
  ?secrets:(string * string) list ->
  ?on_secrets:((string * string) list -> unit) ->
  ?on_book:(Playbook.loaded option -> unit) ->
  ?on_record:(Yojson.Safe.t -> (unit, Protocol.error) result) ->
  ?notify:(string -> (unit, string) result) ->
  ?on_arguments:((string * string) list -> unit) ->
  ?pause_ms:(int -> unit) ->
  args ->
  (Protocol.run_result, Protocol.error) result
(** [loop ~handler ~now ~installed args] runs the mission as JEV's loop (revert-eft1).
    [planner] says whether a planner model is configured; without one it is never asked, a
    BLOCKED loop ends [blocked], and [result] stays null.

    Endings: [done] when JEV reported DONE, the mission's expectations held and, for a
    mission that asks for an answer, the planner judged it done with a result; [failed]
    when the planner judged it not done or answered fail; [blocked] when JEV stopped and
    no planner helped; [limit] at the consultation cap; [deadline]; [handoff-expired] and
    [canceled-by-operator] after a handoff; [planned] for a dry run; [error] otherwise. A
    model or browser failure is a protocol error carrying the trace in [detail]. *)
