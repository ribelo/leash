(** Chrome DevTools Protocol over a private pipe: NUL-delimited JSON framing and
    request/reply correlation.

    Chrome talks CDP over its file descriptors 3 (reads) and 4 (writes) when started with
    [--remote-debugging-pipe]. Each message is one UTF-8 JSON object followed by a NUL
    byte. Requests carry a numeric [id] and, in flatten mode, a [sessionId]; the reply
    echoes both. This module owns the framing and delegates correlation to
    {!Ox_rpc.Correlator}, so events and late replies surface as notifications. *)

type transport = {
  read : Eio_unix.source_ty Eio.Resource.t;
  write : Eio_unix.sink_ty Eio.Resource.t;
}
(** The parent's ends of the pipe pair: [read] is the browser's output, [write] its input.
    Both are borrowed; nothing in this module closes them. *)

module Frame : sig
  type t

  val of_flows :
    ?max_size:int ->
    read:Eio_unix.source_ty Eio.Resource.t ->
    write:Eio_unix.sink_ty Eio.Resource.t ->
    unit ->
    t
  (** [max_size] bounds one buffered frame and defaults to one mebibyte. *)

  val encode : Yojson.Safe.t -> string
  (** [encode message] is compact JSON followed by the NUL delimiter. *)

  val read : t -> Yojson.Safe.t option
  (** [None] at end of input.
      @raise Yojson.Json_error on a payload that is not JSON
      @raise End_of_file on a final frame whose NUL never arrived. *)

  val write : t -> Yojson.Safe.t -> unit
end

type t

type error = Ox_rpc.Correlator.error
(** [`Transport_closed reason], [`Write_failed exn], [`Timeout] or [`Id_exhausted]. *)

val create :
  sw:Eio.Switch.t ->
  clock:_ Eio.Time.clock ->
  ?max_size:int ->
  ?max_notifications:int ->
  transport ->
  t
(** One correlator, its reader fiber and its deadline clock, all scoped to [sw]. The
    reader stops on switch teardown; the transport is not closed by this module. *)

val call :
  t ->
  ?session:string ->
  ?deadline:Ox.Duration.t ->
  string ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, error) result
(** [call t ?session ?deadline method params] sends one request and waits for its reply.
    [session] adds [sessionId] to the outgoing message and matches the reply in that flat
    session. [deadline] covers the write and the wait, on the clock given to {!create}. *)

val events : t -> Yojson.Safe.t Ox_rpc.Correlator.notification Eio.Stream.t
(** CDP events, unmatched and late messages, ending with [Closed reason] exactly once,
    last. One consumer; a second reader steals from the first. *)

val closed : t -> Ox_rpc.Correlator.close_reason Eio.Promise.t
(** Resolves at end of input, on a read failure, or on {!close}. It stays pending when
    [sw] is released first, so a waiter is cancelled with the transport's scope instead.
*)

val result : Yojson.Safe.t -> Yojson.Safe.t option
(** The [result] member of a reply, when it has one. *)

val error_of_reply : Yojson.Safe.t -> (int * string) option
(** The [code] and [message] of a reply's [error] member, when it has one. *)

val stats : t -> Ox_rpc.Correlator.stats

val close : t -> unit
(** Rejects further calls, settles pending ones with [`Transport_closed `Closed], joins
    the reader and resolves {!closed}. Idempotent. *)
