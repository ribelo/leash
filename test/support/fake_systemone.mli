(* The local System One server the L19 tests drive (drive-e7oi drive-yqxg drive-kh2u).

    Plaintext HTTP/1.1 over a loopback listener on the test's own switch, shaped after
    ox's [test/ai/fake_server.ml]: the accept loop is a daemon of the caller's
    switch, each connection reads one complete request, records it, and answers with what
    the test's [answer] returns. Nothing here reaches the network, and the server answers
    as soon as it has read the request, on the caller's real clock — the tests that use it
    run under [Eio_main.run], because the model client's socket wait and a mock clock
    cannot both make progress in one domain.

    Cancellation and finalizers: the accept loop is a daemon of the caller's switch, so
    the switch's release cancels it; the server registers no finalizer of its own. The
    caller owns the switch and the net. *)

type request = {
  method_ : string;
  target : string;  (** the request target, ["/api/v1/systemone"] for the default path *)
  headers : (string * string) list;  (** lowercased names, in arrival order *)
  body : string;
}

type reply = { status : int; reason : string; body : string }
type t

val ok : string -> reply
(** [ok body] is [200 OK] with [body]. *)

val failure : ?reason:string -> int -> string -> reply
(** [failure status body] is that status with [body]; [reason] defaults to ["Error"]. *)

val serve : net:_ Eio.Net.t -> sw:Eio.Switch.t -> (request -> reply) -> t
(** [serve ~net ~sw answer] listens on a fresh loopback port and answers every connection
    with [answer request]. *)

val requests : t -> request list
(** Every request served, in arrival order. *)

val connections : t -> int
(** How many connections were accepted, answered or not. *)

val port : t -> int

val url : t -> string -> string
(** [url t path] is the endpoint a client is pointed at, [http://127.0.0.1:<port><path>].
*)

val request : t -> request option
(** The first request served, when there is one. *)

val body : t -> string
(** The first request's body, or [""]. *)

val header : string -> request -> string option
(** [header name request] is the request's header, by lowercased name. *)
