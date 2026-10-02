type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >
(** L53: compile from independent durable evidence, then replay or agree. *)

type planner = Yojson.Safe.t -> (Yojson.Safe.t, string) result
type t

val create :
  sw:Eio.Switch.t ->
  caps:< caps ; .. > ->
  config:Config.learning ->
  ?planner:planner ->
  ?warn:(string -> unit) ->
  unit ->
  t
(** [sw] owns the fibers that compile, confirm and repair after a drive reply. The reply
    does not wait for them. They are cancelled when [sw] finishes. *)

val config : t -> Config.learning

val path : string list -> string list
(** Distinct kinds in first-visit order, with [unknown] and empty names removed. *)

val matching_path : Trace.t -> string list
(** {!path} of the trace, excluding a kind observed only on a host other than the
    mission's final page. The stored path is not rewritten. Compile and agreement compare
    this list; operations and targets stay exact. *)

val agreement : Trace.t list -> bool
val classify : Playbook.page list -> Trace.t list -> bool * string
val books : t -> Playbook.loaded list -> Playbook.loaded list
val drafts : t -> site:string -> kind:string option -> Playbook.draft list
val status : t -> Yojson.Safe.t

val after_trace :
  t ->
  store:Traces.t ->
  file:string ->
  Trace.t ->
  Protocol.run_result ->
  Protocol.run_result
(** Schedule learning for this trace and return [result] unchanged. Compile, confirmation
    and repair run afterwards on [sw], serialized per site. Their cost is written to
    learning state, proposal provenance and {!status}, not to this reply. *)

val await_pending : t -> unit
(** Wait until every learning fiber scheduled so far has finished. Tests use this to drive
    the async path deterministically. A service does not call it. *)
