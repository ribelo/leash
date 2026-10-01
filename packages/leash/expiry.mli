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

val sweep : t -> (Protocol.Handle.t * Tabs.sweep_step) list
