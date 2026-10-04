type t
(** tab-qmei: one PNG frame from a page's screencast, without activating its tab or
    window. The caller serializes captures and holds operation-scoped focus emulation. *)

val create : unit -> t
val observe : t -> Yojson.Safe.t -> unit
val timeout_error : unit -> Protocol.error

val capture :
  t ->
  call:(string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result) ->
  stop:(unit -> unit) ->
  within:
    ((unit -> (Yojson.Safe.t, Protocol.error) result) ->
    (Yojson.Safe.t, Protocol.error) result) ->
  full_page:bool ->
  (Yojson.Safe.t, Protocol.error) result
(** [within] bounds the complete capture. [stop] is cancellation-protected and must itself
    be bounded. Full-page capture uses CDP's screenshot path, not a viewport frame. *)
