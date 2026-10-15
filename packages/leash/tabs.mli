type t

(** The command classes the one authorization function distinguishes: [Act] is everything
    that touches the page, [Dialog] answers a page dialog, [Close] closes the tab, and
    [Resume] is the human's answer to a handoff. The only refusal is [with_human].
    hand-qos2 hand-fr87. *)
type access = Act | Dialog | Close | Resume

val authorize : access -> with_human:bool -> (unit, Protocol.error) result

type caps =
  < Ox_caps.Cap.env
  ; Ox_caps.Cap.fs_read
  ; Ox_caps.Cap.fs_write
  ; Ox_caps.Cap.random
  ; Ox_caps.Cap.tmp >
(** What the registry may touch beyond its Eio values (^ncaps-4tjy): [random] for tab and
    snapshot handles, [fs_write] for screenshots and [run --out], [tmp] for private
    picture evidence, [fs_read] for uploads, [env] for the XDG directories those live in.
*)

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Ox_observability.Logger.t;
  desktop : Desktop.t;
      (** The human-facing steps {!handoff} runs (hand-04rb hand-phof). *)
  caps : caps;  (** The Door's powerbox narrowed to {!caps}. *)
}

val create :
  sw:Eio.Switch.t ->
  cap:int ->
  tombstone_s:int ->
  ?download_dir:string ->
  ?notify:(string -> (unit, string) result) ->
  ?handoff_timeout_s:int ->
  ?challenge_attempt:bool ->
  ?challenge_turns:int ->
  ?vision:(unit -> Config.decision option) ->
  ?idle:Ox.Duration.t ->
  'clock deps ->
  t
(** Suspension: may suspend while starting ledger and browser-event fibers; attachment
    runs in the event owner; ledger initializer and handler callback invocation is
    delegated to Ox.Actor.create. Cancellation: propagates from switch-scoped startup;
    ledger initializer and handler callback scheduling and failure ownership are delegated
    to Ox.Actor.create. Finalizers: sw owns ledger/event fibers and agent-tab shutdown;
    human-origin tabs are not closed. Locking: the ledger actor serializes bookkeeping and
    per-tab locks serialize actions. Cancellation safety: safe to re-run only after
    tearing down the previous registry switch and its agent-tab cleanup.
    [Invalid_argument] is raised if [sw] has finished or belongs to another domain when
    Eio.Fiber.fork_daemon checks it during startup. Failures in child ledger and
    browser-event fibers fail [sw], not the calling fiber. *)

val status : t -> Ox_app.Status.t

val report : t -> Protocol.status_result
(** [report.models] is [None]: the models section is the models service's and the control
    listener merges it in (L19). *)

val waits_for_load : string option -> bool
(** The rule [new] applies (chrome-qnul): a url other than [about:blank] is waited for
    until it has loaded, exactly as {!navigate} does; [None] and [about:blank] reply at
    once. The control listener's handler budget asks the same question. *)

val new_tab :
  ?label:string -> t -> url:string option -> (Protocol.tab_info, Protocol.error) result

val hand_over :
  t -> reason:string -> Protocol.Handle.t -> (Protocol.tab_info, Protocol.error) result

val handoff :
  ?secrets:(string * string) list ->
  t ->
  reason:string ->
  timeout_s:int option ->
  Protocol.Handle.t ->
  (Protocol.handoff_result, Protocol.error) result

val handoff_timeout_s : t -> int

val handoff_timeout : ?default:int -> int option -> Ox.Duration.t
(** hand-lmd5: the deadline a handoff runs on: the caller's [timeout_s], or the contract's
    five minutes when it names none. [Control.budget] derives the handler's budget from
    this same function. *)

val close_after_resume : t -> Protocol.Handle.t -> (unit, Protocol.error) result
(** map-puhi: mark a drive-owned tab for closure when its handoff resumes. *)

val resume : t -> Protocol.Handle.t -> (Protocol.resumed_result, Protocol.error) result
val close : t -> Protocol.Handle.t -> (Protocol.closed_result, Protocol.error) result

val downloads :
  t -> Protocol.Handle.t -> (Protocol.downloads_result, Protocol.error) result

val snap : t -> Protocol.snap_args -> (Protocol.snapshot, Protocol.error) result

type meter
(** Per-drive usage and browser timings the operator loop merges (fly-gn5z fly-9363). *)

val meter : unit -> meter

val note_usage : meter -> string -> Yojson.Safe.t -> unit
(** Record the latest usage for ["operator"] or ["text_helper"]. Routing passes this as
    [Models.decide]/[Models.text_helper]'s [on_usage]. *)

val clear_usage : meter -> string -> unit
(** Drop the stored usage for that kind. Production clears it immediately before the
    matching call, so a missing callback cannot report the previous call's usage. *)

val usage : meter -> string -> Yojson.Safe.t option

val telemetry : meter -> unit -> Yojson.Safe.t
(** Cumulative [observation_retries], [input_ms] and [settle_ms]. *)

val drive :
  ?decide:
    (deadline:Ox.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?text_helper:(unit -> Text_helper.t) ->
  ?meter:meter ->
  ?recent:Jev_request.recent_action list ->
  t ->
  model:string ->
  Protocol.drive_args ->
  (Protocol.drive_result, Protocol.error) result
(** drive-8n2z drive-tfqh drive-kh2u drive-ls3c: one tab action lock covers the entire
    effect computation. The optional model decision seam is what production installs
    ({!Models.decide}) and what scripted control tests replace; a drive that is given none
    refuses with model-unavailable. The seam takes the deadline the drive has left, so one
    model call can never outlast the reply the client is waiting for.

    [text_helper] is asked once per drive for the helper a [type_text] step writes with
    ({!Models.text_helper} in production): the helper keeps the answer it last gave and
    reuses it when the whole context comes back, which is a stale-row retry, so a fresh
    instance per drive is the caller's business and the thunk is how it is stated. A
    [type_text] step fills with the value the helper answered, through the same action
    path the [fill] command uses; a null answer is [blocked] naming the field, and a
    refusal over 4 KiB is [model-unavailable] with the steps completed (drive-ls3c). *)

val run :
  ?on_page:(url:string -> unit) ->
  ?on_step:(Protocol.step -> unit) ->
  ?planner:bool ->
  ?levels:Run.levels ->
  ?model:string ->
  ?decide:
    (deadline:Ox.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?text_helper:(unit -> Text_helper.t) ->
  ?meter:meter ->
  t ->
  tab:Protocol.Handle.t ->
  Protocol.run_args ->
  (Protocol.run_result, Protocol.error) result
(** run-9ypy run-shgh run-fwl8 (ADR-0015, ADR-0016): one mission. The run holds the tab's
    action lock for its whole duration; every JEV stint is one [drive_locked] call and the
    planner's turns go through {!Run.loop}'s handler over [levels]. [decide] and
    [text_helper] are the operator's models; [planner] says whether a planner is
    configured. *)

val text : t -> Protocol.text_args -> (Protocol.text_result, Protocol.error) result
val eval : t -> Protocol.eval_args -> (Protocol.eval_result, Protocol.error) result
val shot : t -> Protocol.shot_args -> (Protocol.shot_result, Protocol.error) result
val debug : t -> Protocol.debug_args -> (Protocol.debug_result, Protocol.error) result
val wait : t -> Protocol.wait_args -> (Protocol.action_result, Protocol.error) result

val net : t -> Protocol.net_args -> (Protocol.net_result, Protocol.error) result
(** hard-xg6y: the requests of this tab only; every tab has a ring of its own. *)

val net_body :
  t -> Protocol.net_entry_args -> (Protocol.net_body_result, Protocol.error) result
(** hard-ovbx *)

val net_request :
  t -> Protocol.net_entry_args -> (Protocol.net_request_result, Protocol.error) result
(** hard-vq5s *)

val cookies : t -> Protocol.tab_args -> (Protocol.cookies_result, Protocol.error) result
(** hard-ufb7: read-only. Like [net], [wait] and [debug] it takes no action lock. *)

val storage :
  t -> Protocol.storage_args -> (Protocol.storage_result, Protocol.error) result
(** hard-ufb7 *)

val dialog : t -> Protocol.dialog_args -> (Protocol.action_result, Protocol.error) result

val click : t -> Protocol.click_args -> (Protocol.action_result, Protocol.error) result
(** tab-bw4j tab-j1z2 tab-hxld tab-60kn tab-1lhx tab-tm6c: the row is revalidated at
    action time, the click point hit-tested, and the action dispatched once. *)

val click_at :
  t -> Protocol.point_action_args -> (Protocol.action_result, Protocol.error) result

val dblclick :
  t -> Protocol.point_action_args -> (Protocol.action_result, Protocol.error) result

val scroll_at :
  t -> Protocol.point_scroll_args -> (Protocol.action_result, Protocol.error) result

val drag : t -> Protocol.drag_args -> (Protocol.action_result, Protocol.error) result
val type_text : t -> Protocol.type_args -> (Protocol.action_result, Protocol.error) result

val fill : t -> Protocol.fill_args -> (Protocol.action_result, Protocol.error) result
(** tab-p3x1 tab-0lax: focus, select, [Input.insertText], blur, then a bounded settle;
    text over 64 KiB is a [too-large] error. *)

val press : t -> Protocol.press_args -> (Protocol.action_result, Protocol.error) result
(** tab-luo5: with an index the row is focused first, without one the key goes to the
    page. *)

val select : t -> Protocol.select_args -> (Protocol.action_result, Protocol.error) result
(** tab-5deq: a native select's observed option index. *)

val scroll : t -> Protocol.scroll_args -> (Protocol.action_result, Protocol.error) result
(** tab-8dop: one viewport, from the page's centre or the row's scrollable ancestor. *)

val upload : t -> Protocol.upload_args -> (Protocol.action_result, Protocol.error) result
(** hard-o3za: files onto a file-input row, revalidated like any action. *)

val hover : t -> Protocol.hover_args -> (Protocol.action_result, Protocol.error) result
(** hard-v1gs: the mouse moves to the row's revalidated point and settles. *)

val check : t -> Protocol.click_args -> (Protocol.action_result, Protocol.error) result
(** field-guda: verified check. [state-unchanged] when the control does not become
    checked. *)

val uncheck : t -> Protocol.click_args -> (Protocol.action_result, Protocol.error) result
(** field-guda: verified uncheck. *)

val navigate :
  t -> Protocol.Handle.t -> string -> (Protocol.tab_info, Protocol.error) result

val list : t -> Protocol.list_result
val take : t -> Protocol.take_args -> (Protocol.tab_info, Protocol.error) result

type idleness = {
  handle : Protocol.Handle.t;
  origin : Protocol.Origin.t;
  with_human : bool;
  idle_for_s : float;
}
(** One tab's expiry facts (hand-0ibq hand-ihcg): origin, the human hold, and idle time.
    Human tabs and a tab with the human are never closed by the sweep. *)

type sweep_step = Close_idle | Keep_idle

val idleness : t -> idleness list
(** Every live tab's facts, in handle order, for the caller's policy. *)

val sweep : t -> decide:(idleness -> sweep_step) -> (Protocol.Handle.t * sweep_step) list
val stop : t -> unit
