type t
(** Bounded stderr tail owned by one managed Chrome generation. *)

val create : unit -> t

val read : t -> Eio.Flow.source_ty Eio.Resource.t -> unit
(** Drain until EOF, retaining only the last 20 lines, each at most 1024 bytes.

    Suspension: may suspend waiting for source bytes. Cancellation: propagates; the
    current unterminated line is not flushed. Finalizers: none; source is borrowed and
    remains open. Locking: none; one fiber must own reads and tail updates. Cancellation
    safety: unsafe because data is lost; consumed bytes of the unfinished line remain only
    in the cancelled reader. *)

val lines : t -> string list
