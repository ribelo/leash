(** Managed Chrome: one browser process under a restart schedule, and one CDP connection
    per browser generation.

    [create] runs one {!Ox.Supervisor} child (Permanent, one incarnation per generation,
    ^nactor-d120) whose start builds Chrome's [--remote-debugging-pipe] pair, hands the
    child ends to descriptors 3 and 4 and speaks CDP over the parents' ends. A generation
    ends when its process exits or its transport closes; the supervisor then restarts it
    after the configured backoff (the delay is the schedule's, the attempt limit the
    supervisor's restart intensity). A launch that fails — a typed spawn error or a defect
    — is not a generation that exited and is not retried: the service gives up with that
    cause. Each generation's stderr tail lives in a table owned by an {!Ox.Agent}, because
    the launching fiber and the observer both touch it (^nactor-75ef). Losing the browser
    is an event on {!events}, never a failure of this service: the tab registry answers it
    by tombstoning its tabs. *)

type spawn_error = Ox_process.Child.error
(** [`Invalid_fd] or [`Duplicate_fd] from {!Ox_process.Child.spawn}. *)

type reason = [ `Spawn of spawn_error | `Schedule_exhausted of Ox_process.Child.exit ]
(** Why the supervisor gave up: a spawn that failed, or a schedule that ran out of
    attempts after the last exit. *)

type event =
  | Started of int
  | Lost of int
  | Gave_up of reason Ox.Cause.t
  | Stopped
      (** The lifecycle a consumer such as the tab registry subscribes to. [Started g]
          follows each successful spawn; [Lost g] says generation [g] is gone, whether its
          process exited or its transport closed, and is delivered at most once per
          generation; [Gave_up cause] ends the restart schedule and needs an operator;
          [Stopped] is last, after {!stop} or switch release. *)

type phase = [ `Running | `Restarting | `Gave_up | `Stopped ]

type status = {
  generation : int;
  phase : phase;
  failure : string option;
  headed : bool;
  pid : int option;
}
(** What [leash status] reports: the last generation counted by the supervisor, whether
    Chrome is running or restarting, after a give-up why, and whether this service
    launched a headed browser (daily-a341 daily-smli). *)

type backoff = {
  initial : Ox.Duration.t;
  cap : Ox.Duration.t;
  factor : float;
  attempts : int;
}

val default_backoff : backoff
(** One second, doubling, capped at thirty seconds, ten attempts then give up. *)

type config = {
  binary : string;
  profile_dir : string;
  workspace : string;
  grace : Ox.Duration.t;
  backoff : backoff;
  headless : bool;
  window_size : string;
}

val make :
  binary:string ->
  profile_dir:string ->
  workspace:string ->
  ?grace:Ox.Duration.t ->
  ?backoff:backoff ->
  ?headless:bool ->
  ?window_size:string ->
  unit ->
  config
(** [grace] defaults to five seconds and [headless] to false. The workspace is placement
    intent: a headed Chrome is launched with [--class=leash] and the window is moved by
    hand or by a niri rule. [headless] exists for the live-acceptance gate and for
    operator choice; the service starts a headed browser by default. *)

val argv : config -> string list
(** The exact command line: the dedicated profile, no first-run or crash-restore prompt,
    [--remote-debugging-pipe] with no debugging port,
    [--disable-blink-features=AutomationControlled] (the pipe would otherwise set
    [navigator.webdriver] on every page), [--class=leash], and [--headless=new] and
    [--window-size=1366,900] only when [headless] is true. *)

type caps = < Ox_caps.Cap.fork ; Ox_caps.Cap.exec ; Ox_caps.Cap.fs_write >
(** What Chrome may touch beyond its Eio values: it starts the browser, so it forks and
    execs (^ncaps-4tjy). Nothing else — no environment, no file outside the Eio values it
    is given. *)

type 'clock deps = {
  clock : 'clock Eio.Time.clock;
  mono_clock : Eio.Time.Mono.ty Eio.Resource.t;
      (** Ox's supervisor counts restarts on a monotonic clock. *)
  mgr : Eio_unix.Process.mgr_ty Eio.Resource.t;
  logger : Ox_observability.Logger.t;
  caps : caps;  (** The Door's powerbox narrowed to {!caps} (^ncaps-4tjy). *)
}

type 'clock launch =
  sw:Eio.Switch.t ->
  clock:'clock Eio.Time.clock ->
  mgr:Eio_unix.Process.mgr_ty Eio.Resource.t ->
  config ->
  (Ox_process.Child.t * Cdp.transport, spawn_error) result
(** How one generation's process and transport are created, on the child switch that the
    supervisor releases when the generation ends. *)

val launch_pipe :
  caps:< Ox_caps.Cap.fork ; Ox_caps.Cap.exec ; Ox_caps.Cap.fs_write ; .. > ->
  'clock launch
(** The real one, given the capabilities spawning needs; {!create} passes [deps.caps]. two
    pipes, the child ends on descriptors 3 and 4, the parent ends as the transport. The
    parent closes its copies of the child ends right after the spawn, so the browser's
    exit reaches the CDP reader as end of input.

    Suspension: may suspend when the returned launcher runs during pipe creation and
    process spawn. Cancellation: propagates from the child switch and spawning.
    Finalizers: sw owns both pipe pairs and the managed child; parent copies of child ends
    close after spawn. Locking: none; the supervisor owns generation ordering.
    Cancellation safety: safe to re-run only after releasing the failed generation switch
    and retiring its child. [Invalid_argument] is raised if a pipe flow has no Unix
    descriptor. *)

type t

val create : sw:Eio.Switch.t -> ?launch:'clock launch -> config -> 'clock deps -> t
(** Starts the supervisor and its two supervisor fibers on [sw]. The first spawn is
    asynchronous, so {!connection} answers [`Browser_unavailable] until the first
    [Started]. Spawn failures arrive as [Gave_up]; [Eio.Cancel.Cancelled] can escape
    startup.

    Suspension: may suspend while starting supervisor fibers without waiting for the first
    generation; tail-ledger initializer callback invocation is delegated to
    Ox.Agent.create. Cancellation: propagates from switch-scoped startup; tail-ledger
    initializer callback invocation is delegated to Ox.Agent.create. Finalizers: sw stops
    the supervisor and retires its managed generations. Locking: supervisor state changes
    are owned by its supervisor fibers. Cancellation safety: safe to re-run on a fresh
    switch after the old supervisor and child have stopped. [Invalid_argument] is raised
    for invalid supervisor configuration. *)

val generation : t -> int
(** The supervisor's generation counter: zero before the first successful spawn. *)

val connection : t -> (Cdp.t, [ `Browser_unavailable ]) result
(** The current generation's connection, or [`Browser_unavailable] while Chrome is
    starting, restarting, given up or stopped. Fails fast; callers retry. *)

val events : t -> event Eio.Stream.t
(** Bounded to 32 events; overflow drops the oldest, never blocks. Take until [Stopped].

    Suspension: never suspends; returns the existing event stream. Cancellation: not a
    cancellation point. Finalizers: none registered by this accessor. Locking: none;
    consumers share the same stream. Cancellation safety: safe to re-run; no event is
    consumed. *)

val status : t -> status

val stop : t -> unit
(** Idempotent and cancellation-protected: SIGTERM, the configured grace, SIGKILL if
    needed, reap. Also runs as the releasing finalizer of [sw]. *)
