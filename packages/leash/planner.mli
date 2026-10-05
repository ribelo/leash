(** revert-24kr revert-apgf revert-bqrq (ADR-0015): the optional planner. It is consulted,
    never acting: on BLOCKED or a failed expectation it answers a hint JEV is given as its
    goal, or handoff, notify or fail; at the end of a mission that asks for an answer it
    gives result, evidence and whether the mission is done. Strict JSON decoding; one
    correction call shares the original deadline and never echoes a raw rejected reply. *)

type t = {
  plan :
    ?deadline:Ox.Duration.t -> Run.plan_request -> (Run.plan_reply, Protocol.error) result;
}
(** One configured planner. [plan] answers one turn: the run's request in, an answer the
    loop can execute or report out, never raw model output. [deadline] (30 seconds by
    default) is what the run passes of its own budget: a turn is at most two calls, the
    first bounded by [deadline] and the correction call by the smaller of the remaining
    turn budget and 30 seconds, so a retry that hangs cannot outlast the budget the run
    answers the listener within.

    The cost of a turn rides on the reply (run-obtt): the tokens and provider-reported
    cost summed over the calls the turn took; absent cost contributes zero.

    Suspension: [plan] may suspend in [Ox_ai_chat.complete] and clock/logging callbacks.
    Cancellation: caller cancellation propagates; both calls share the turn deadline.
    Finalizers: the Ox chat client owns each request; no socket or finalizer is
    transferred. Locking: no Leash lock is acquired; the HTTP owner coordinates its
    transport. Exceptions: cancellation and exceptions from injected clock/logging
    callbacks propagate; provider, decoding and size failures are returned as typed
    errors. *)

val request_json : Run.plan_request -> Yojson.Safe.t
(** The bounded page, mission, JEV's history and secret names the planner is shown. *)

val decode : Run.plan_request -> string -> (Run.plan_reply, string) result
(** One reply: [hint]/[handoff]/[notify]/[fail] for a stop, [done]/[fail] at the end. *)

val create :
  now:(unit -> float) ->
  client:Ox_ai_chat.t ->
  model:string ->
  reasoning:string ->
  logger:Ox_observability.Logger.t ->
  unit ->
  t
(** [create ~client ~model ~reasoning ~logger ()] is the planner over one chat client, for
    the configured [model] (run-d99l). A consultation is one text part. [reasoning] is the
    configured effort; the word ["none"] (also ["off"] or ["disabled"]) turns OpenRouter's
    reasoning off instead. Cheap and synchronous: it opens no socket and registers no
    finalizer. Every answered call is logged at info with the model and the tokens it cost
    — a turn asked twice logs both calls, because both were paid for.

    Suspension: never suspends during local construction; reasoning normalization is
    delegated to Stdlib.String.lowercase_ascii; injected callbacks are retained for
    [plan]. Cancellation: not a cancellation point during local construction; reasoning
    normalization is delegated to Stdlib.String.lowercase_ascii. Finalizers: none; the
    chat client remains owned by its creator. Locking: none during construction. *)
