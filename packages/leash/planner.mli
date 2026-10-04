(** Versioned mission-pilot turns (pilot-ukoh pilot-gt2h pilot-r94o). The pilot is called
    from the first mission turn, using bounded page evidence, prior navigation legs and
    candidate procedures. It owns done/fail, not JEV. Strict JSON decoding permits one of
    seven answer shapes. A correction call shares the original deadline and never echoes a
    raw rejected reply. *)

val pilot_prompt : string
(** pilot-02ij: the pilot's whole system prompt — answers, shapes and refusals, under 300
    words. *)

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
    cost summed over the calls the turn took; absent cost contributes zero. *)

val pilot_request_json : Run.plan_request -> Yojson.Safe.t
val decode_pilot : Run.plan_request -> string -> (Run.plan_reply, string) result

val create :
  now:(unit -> float) ->
  client:Ox_ai_chat.t ->
  model:string ->
  reasoning:string ->
  logger:Ox_observability.Logger.t ->
  unit ->
  t
(** [create ~client ~model ~reasoning ~logger ()] is the planner over one chat client, for
    the configured [model] (run-d99l). [reasoning] is the configured effort; the word
    ["none"] (also ["off"] or ["disabled"]) turns OpenRouter's reasoning off instead.
    Cheap and synchronous: it opens no socket and registers no finalizer. Every answered
    call is logged at info with the model and the tokens it cost — a turn asked twice logs
    both calls, because both were paid for. *)
