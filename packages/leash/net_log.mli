(** The per-tab request ring behind `net` (hard-xg6y hard-ovbx hard-vq5s).

    Chrome delivers network events per tab session, so every tab has a ring of its own and
    the ring is owner-bound like every other tab command: it is reached only through the
    registry's authorization. It is fed by `Network.requestWillBeSent`,
    `requestWillBeSentExtraInfo`, `responseReceived`, `requestServedFromCache`,
    `loadingFinished` and `loadingFailed`, and holds metadata only — bodies and post data
    are fetched from Chrome on demand and never kept.

    Everything in a ring is page data (URLs, headers). It is returned to the owner and
    never becomes a log line. *)

type t

val capacity : int
(** Five hundred requests per tab; the oldest is dropped first. *)

val create : unit -> t

val observe : t -> Yojson.Safe.t -> unit
(** Consume one event of the tab's page session. A response, completion or failure for a
    request the ring never saw (Chrome enabled its domain mid-flight) is ignored. A
    redirect ends the request's hop: the hop stays listed under the id `<id>~<n>` with the
    redirect response's status, and the followed request keeps the plain id. *)

val list : t -> Protocol.net_args -> (Protocol.net_result, Protocol.error) result
(** The most recent [limit] requests that match, oldest first. [invalid-request] for a
    limit outside 0..500. *)

type request = {
  id : string;
  chrome_id : string;  (** Chrome's own request id, which the body calls take. *)
  method_ : string;
  url : string;
  headers : (string * string) list;
  has_post_data : bool;
  has_body : bool;
      (** A response arrived and the request did not fail or redirect: a body can exist.
      *)
}

val find : t -> string -> request option

val clip : int -> string -> string * bool
(** [clip n s] is [s] cut to at most [n] bytes on a UTF-8 character boundary, and whether
    it was cut. *)
