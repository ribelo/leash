val mapping : ?extra:(string * string) list -> Playbook.t -> (string * string) list
(** map-fmt02: kind mappings come from provenance sidecars, passed as [extra]. The book
    itself no longer carries them. *)

val observations : Trace.t list -> Yojson.Safe.t
(** map-op04: only titles, target labels, and generalized URL patterns; no page text. *)

val name :
  known:(string * string) list ->
  Playbook.t ->
  Yojson.Safe.t ->
  (Playbook.t * (string * string) list, string) result
(** Decode the compiler's kinds object. Known/declared names cannot be changed. *)
