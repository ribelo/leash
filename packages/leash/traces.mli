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
val root : t -> string
val now : t -> float
val timestamp : float -> string

val site : string -> string option
(** Registrable domain using the frozen PSL. IP literals/local names remain themselves.
    Blank/about URLs have no site; a drive with none uses [unknown]. *)

val read :
  caps:< Ox_caps.Cap.fs_read ; .. > -> string -> (Protocol.drive_trace, string) result

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
val page : capture -> url:string -> kind:string option -> unit
val step : capture -> Protocol.step -> unit

val finish :
  capture ->
  now:float ->
  (Protocol.run_result, Protocol.error) result ->
  Protocol.drive_trace
