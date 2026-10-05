type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >

module Retention : sig
  type t = { count : int; days : int }

  val default : t
  val of_values : count:int -> days:int -> (t, string) result
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

type t

val create : caps:< caps ; .. > -> ?root:string -> ?retention:Retention.t -> unit -> t
(** Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and the local protected-reader
    callback; resolves the root from environment without touching the filesystem.
    Cancellation: not a cancellation point; behavior of the delegated helpers depends on
    the synchronous Stdlib, Unix, Ox_caps and Yojson helpers and the local
    protected-reader callback. Finalizers: none. Locking: none at construction.
    Cancellation safety: safe to re-run; creates only an in-memory trace handle. *)

val root : t -> string
val now : t -> float
val timestamp : float -> string

val site : string -> string option
(** Registrable domain using the frozen PSL. IP literals/local names remain themselves.
    Blank/about URLs have no site; a drive with none uses [unknown]. *)

val read :
  caps:< Ox_caps.Cap.fs_read ; .. > -> string -> (Protocol.drive_trace, string) result
(** Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and the local protected-reader
    callback; filesystem reads are synchronous. Cancellation: not a cancellation point;
    behavior of the delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and
    Yojson helpers and the local let-operator invocation and protected-reader callback.
    Finalizers: owned input channels are closed on exit. Locking: none; reads do not
    reserve filesystem state. Cancellation safety: safe to re-run; reads leave files
    unchanged. [Stdlib.Sys_error] can escape from closing the owned input channel. *)

val list :
  t ->
  ?site:string ->
  ?outcome:string ->
  unit ->
  ((string * Protocol.drive_trace) list, string) result

val prune :
  t -> ?site:string -> dry_run:bool -> now:float -> unit -> (string list, string) result

val write : t -> Protocol.drive_trace -> (string, string) result
(** Atomic private write; bounded UTC sub-microsecond collision retries never replace
    another trace. Files over 8 MiB are refused. Does not prune. *)

type capture

val capture : mission:string -> now:float -> capture

(* kind-4qke kind-dnye: [kind] is the page kind for the path. [pattern] is the
   generalized URL when the kind was inferred; a declared kind passes [None] and is
   not added to the header mapping. *)
val page : capture -> url:string -> kind:string option -> unit

val arguments : capture -> (string * string) list -> unit
(** map-op01: resolved mission arguments; finish retains only non-redacted typed values.
*)

val step : capture -> Protocol.step -> unit
val planner_step : capture -> Protocol.planner_step -> unit

val finish :
  capture ->
  now:float ->
  (Protocol.run_result, Protocol.error) result ->
  Protocol.drive_trace
