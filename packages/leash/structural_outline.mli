val collection : string -> bool
(** map-op09: bounded tag/class evidence for completed collection missions. *)

val expression : string
(** Read-only DOM projection; no text, values, URLs or other attributes. *)

val decode : Yojson.Safe.t -> string option
(** Validate a DOM projection and format at most 4096 bytes. *)
