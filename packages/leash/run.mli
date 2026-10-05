(** ADR-0015 (amended) ADR-0016: [drive MISSION] is JEV's loop over the page. JEV decides
    every step over the element table ({!Drive}); the text helper writes field values.
    When JEV answers BLOCKED, stalls or reaches its step cap, the planner (Luna) takes the
    page over with the mission and what happened so far: it acts, reads, looks at a
    screenshot, notifies, hands off on a headed browser, finishes or fails, and hands
    control back to JEV with a goal string. When JEV reports DONE on a mission that asks
    for an answer, the planner gives the answer from the final page or takes over. Only
    the deadline bounds the planner. All effects use handlers, so tests and dry-run need
    no browser or model service. *)

type observation = {
  url : string;
  title : string;
  text : string;
  dialog : Protocol.dialog option;
  rows : (string * string) list;
  downloads : (string * string * string) list;
      (** Suggested name, MIME and state of each download of the tab. *)
  snapshot : Protocol.snapshot;
  image_input : bytes option;
      (** takeover: private PNG bytes for the planner's image input; never a text field.
      *)
}

type step_request = {
  goal : string;
  recent : Jev_request.recent_action list;
  max_steps : int;
  stop_on_navigation : bool;
  deadline_s : int;
  dry_run : bool;
}
(** One stint of JEV's loop: the goal, its step cap and the mission's remaining deadline.
*)

type plan_trigger =
  | Blocked
  | Final
  | Holding
      (** JEV answered BLOCKED, stalled or reached its step cap; JEV reported DONE on a
          mission that asks for an answer; or the planner holds the page and its last
          action came back. *)

type plan_answer =
  | Jev of string
  | Act of Protocol.planner_action
  | Read of { quote : string; note : string }
  | Observe_image
  | Notify of string
  | Handoff of string
  | Done of {
      result : string;
      evidence : string list;
      records : (string * string) list list;
    }
  | Fail of string
      (** What the planner does while it holds the page. [Jev goal] hands control back to
          JEV with [goal] as its goal. *)

type plan_reply = { answer : plan_answer; usage : Protocol.run_usage option }

type plan_request = {
  trigger : plan_trigger;
  reason : string;
  mission : string;
  secret_names : string list;
  headless : bool;
      (** revert-r9ka: nobody can see the browser; handoff is neither offered nor
          accepted. *)
  site : string option;
  history : (string * string) list;
      (** What happened so far, oldest first: each JEV stint and each planner action. *)
  url : string;
  title : string;
  text : string;
  snapshot : Protocol.snapshot;
  image_input : bytes option;
  downloads : (string * string * string) list;
}

type levels = {
  plan : deadline:Ox.Duration.t -> plan_request -> (plan_reply, Protocol.error) result;
}
(** The planner call, as one seam over the models service, so a scripted test replaces the
    model with a function and production passes {!Models.levels}. *)

type handler = {
  observe : image:bool -> unit -> (observation, Protocol.error) result;
  navigate : string -> (unit, Protocol.error) result;
  step : step_request -> (Protocol.drive_result, Protocol.error) result;
      (** One stint of JEV's loop. *)
  plan : plan_request -> (plan_reply, Protocol.error) result;
  act : Protocol.planner_action -> (Protocol.action_result, Protocol.error) result;
      (** The planner's own action on the page, through the public action path. *)
  hand_off : reason:string -> (Protocol.tab_info, Protocol.error) result;
}

type args = {
  mission : string;
  max_steps : int;  (** JEV's step cap per stint, 256 by default. *)
  start_url : string option;
  deadline_s : int;
  dry_run : bool;
}

val of_args : Protocol.run_args -> args
val trigger_name : plan_trigger -> string

val asks_answer : string -> bool
(** Whether a mission asks for an answer: a question, a [Result:] clause, or a request to
    tell, find, list, check or report. *)

val authorises : string -> string -> bool
(** Whether the mission explicitly names the protected action category without a refusal.
*)

val unsafe_action : string -> string option
(** The protected action class (payment, deletion, messaging) in a goal or row label. *)

val loop :
  handler:handler ->
  now:(unit -> float) ->
  ?planner:bool ->
  ?headless:bool ->
  ?secrets:(string * string) list ->
  ?on_record:(Yojson.Safe.t -> (unit, Protocol.error) result) ->
  ?notify:(string -> (unit, string) result) ->
  args ->
  (Protocol.run_result, Protocol.error) result
(** [loop ~handler ~now args] runs the mission. [planner] says whether a planner model is
    configured; without one it is never asked, a stop ends [blocked], and [result] stays
    null.

    Endings: [done] when JEV reported DONE (and, for a mission that asks for an answer,
    the planner gave it) or the planner finished; [failed] when the planner failed it;
    [blocked] when JEV stopped and no planner is configured; [deadline]; [handoff-expired]
    and [canceled-by-operator] after a handoff; [planned] for a dry run; [error]
    otherwise. A model or browser failure is a protocol error carrying the planner turns
    in [detail]. *)
