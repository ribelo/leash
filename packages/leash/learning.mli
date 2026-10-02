type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >
(** L53: compile from independent durable evidence, then replay or agree. *)

type planner = Yojson.Safe.t -> (Yojson.Safe.t, string) result
type t

val create :
  caps:< caps ; .. > ->
  config:Config.learning ->
  ?planner:planner ->
  ?warn:(string -> unit) ->
  unit ->
  t

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
