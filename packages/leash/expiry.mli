val interval : Ox.Duration.t
(** hand-0ibq hand-ihcg: agent tabs close when idle; human tabs are never swept. *)

val decide : idle:Ox.Duration.t -> Tabs.idleness -> Tabs.sweep_step

type t

val create :
  sw:Eio.Switch.t ->
  ?interval:Ox.Duration.t ->
  idle:Ox.Duration.t ->
  clock:'clock Eio.Time.clock ->
  logger:Ox_observability.Logger.t ->
  Tabs.t ->
  t
(** Suspension: may suspend while starting a sleeping sweep daemon without waiting for a
    sweep. Cancellation: propagates from daemon startup; switch teardown cancels the
    daemon. Finalizers: sw owns the daemon lifetime. Locking: tab ownership and sweep
    decisions are serialized by Tabs. Cancellation safety: safe to re-run on a fresh
    switch after the previous sweeper stops; never run two sweepers for the same owner.
    [Assert_failure] can escape from an internal tab-registry invariant in the owned sweep
    fiber. [Eio.Cancel.Cancelled] propagates from daemon startup. [Invalid_argument] can
    propagate from schedule execution or the tab sweep in the owned daemon. *)

val sweep : t -> (Protocol.Handle.t * Tabs.sweep_step) list
