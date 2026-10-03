type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >
(** pilot-3egp pilot-oijk pilot-c77y: pilot memory and replay gates. *)

type t

val create :
  sw:Eio.Switch.t ->
  caps:< caps ; .. > ->
  config:Config.learning ->
  ?warn:(string -> unit) ->
  unit ->
  t

val config : t -> Config.learning

val record_legs :
  t ->
  site:string ->
  mission:string ->
  args:(string * string) list ->
  legs:string list ->
  expect:string list ->
  unit

val candidates :
  t ->
  site:string ->
  kind:string option ->
  (Playbook.procedure * [ `Installed | `Draft of string ]) list

val after_mission :
  t ->
  site:string ->
  used:(string * [ `Installed | `Draft of string ]) list ->
  outcome:[ `Done | `Failed ] ->
  verified:bool ->
  unit

val books : t -> Playbook.loaded list -> Playbook.loaded list
val drafts : t -> site:string -> kind:string option -> Playbook.draft list
val status : t -> Yojson.Safe.t

val await_pending : t -> unit
(** Wait for service-switch-owned asynchronous writes; for deterministic tests. *)
