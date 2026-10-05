(** ADR-0016 scr-run: a JavaScript file the agent brings to [leash script run], run once
    on a tab's page. Nothing is installed or remembered; no model chooses it. *)

type t = { name : string; code : string; returns : Shape.t option }
(** [code] is the body of an async function of [args]; [returns] is the shape its result
    must fit, from a leading [/** returns: SHAPE */] block, or [None] when there is none.
*)

val max_bytes : int
(** The bound on a result's JSON size: 8 MiB. *)

val returns_comment : string -> (Yojson.Safe.t option, string) result
(** The JSON of a leading [/** returns: ... */] block, if the code opens with one. *)

val of_source : name:string -> string -> (t, string) result
(** A script from its file name and text: at most 1 MiB, with its returns block, if any, a
    valid shape. *)
