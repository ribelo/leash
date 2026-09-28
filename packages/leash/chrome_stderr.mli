type t
(** Bounded stderr tail owned by one managed Chrome generation. *)

val create : unit -> t

val read : t -> Eio.Flow.source_ty Eio.Resource.t -> unit
(** Drain until EOF, retaining only the last 20 lines, each at most 1024 bytes. *)

val lines : t -> string list
