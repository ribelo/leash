(** extr-5x9e: per-run provider accounting inherited by verifier child fibers. *)
type event = Start of string | Reported of string * float option

val with_meter : (event -> unit) -> (unit -> 'a) -> 'a
val active : unit -> bool
val start : string -> unit
val report : string -> float option -> unit
