(* L13 — expiry and disposition (docs/issues/tab-ownership/01-tab-ownership.md, milestone
   3; ADR-0005). *)

(** The two-stage expiry sweep.

    {!create} starts one fiber on the switch. On every tick it reads every tab's idleness
    from the registry, {!decide} says what each tab is due, and {!Tabs.sweep} applies the
    answer under that tab's lock, so a claim or an action that lands while the sweep runs
    is not overrun. Nothing here is a browser concept: this module decides, {!Tabs}
    applies. *)

val interval : Ox.Duration.t
(** The sweep's period: thirty seconds, which is the cadence both stages run at (own-uo77
    own-hslp). *)

val decide :
  idle:Ox.Duration.t -> unclaimed:Ox.Duration.t -> Tabs.idleness -> Tabs.sweep_step
(** own-uo77 own-hslp own-2zpi own-ay3s: the whole policy, pure and clock-free. An owned
    tab idle for [idle] is released; an unowned tab of agent origin unclaimed for
    [unclaimed] is closed; a human-origin tab, and one the human holds, is left alone
    however long it sits there. *)

type t

val create :
  sw:Eio.Switch.t ->
  ?interval:Ox.Duration.t ->
  idle:Ox.Duration.t ->
  unclaimed:Ox.Duration.t ->
  clock:'clock Eio.Time.clock ->
  logger:Ox_observability.Logger.t ->
  Tabs.t ->
  t
(** Starts the sweep fiber as a daemon of [sw], so it stops with the switch. [interval]
    defaults to {!interval}; [idle] and [unclaimed] are the configured durations
    (own-vhqo), and each pass is recorded at info level with the tab it acted on. The
    live-acceptance gate overrides the period through LEASH_SWEEP_INTERVAL_S (test-only;
    production always uses the 30 s contract default). *)

val sweep : t -> (Protocol.Handle.t * Tabs.sweep_step) list
(** One pass, synchronously: exactly what the fiber runs on a tick, and what a test calls
    to make a pass happen at an instant of its choosing. Returns the tabs the pass acted
    on, in handle order. *)
