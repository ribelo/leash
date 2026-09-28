(** The planner turn — Luna by default (L32, milestone 7; run-w7ke run-rq6i run-2tt3
    run-obtt run-d99l).

    The planner is the level above JEV, and only that: the run asks it where JEV stopped —
    a BLOCKED answer, a procedure that failed its expectations twice, an argument the text
    helper could not fill (run-w7ke) — and never for the work itself. One turn is one
    {!Eta_ai_chat.complete} call with [json_object] on and reasoning at the configured
    effort: the system message is {!Questions.planner}, the user message is the
    {!Run.plan_request} as JSON — the mission, the playbook in its own schema, the trace,
    the arguments known and the observed page with its text bounded — and the reply must
    decode into exactly one of three answers: [procedure] (a new procedure in the
    playbook's schema, to run now), [handoff] (a reason for the human) or [fail] (a reason
    for the operator). A reply that does not decode, or that names a procedure this
    playbook cannot run, is shown back with its refusal and asked once more; a second
    refusal ends the turn as [model-unavailable] with [detail.code = "invalid-response"].
    A turn's first reply may also attach the mission's expectations (run-2tt3), each of
    which must resolve against the playbook's own page kinds.

    The chat client is the models service's — one transport for every model, as with
    {!Text_helper} — and this module owns the prompt, the fail-closed decode and the
    accounting. Nothing here reads a clock or a file. *)

type t = {
  plan :
    ?deadline:Eta.Duration.t ->
    Run.plan_request ->
    (Run.plan_reply, Protocol.error) result;
}
(** One configured planner. [plan] answers one turn: the run's request in, an answer the
    loop can execute or report out, never raw model output. [deadline] (30 seconds by
    default) is what the run passes of its own budget: a turn is at most two calls, the
    first bounded by [deadline] and the correction call by the smaller of [deadline] and
    30 seconds, so a retry that hangs cannot outlast the budget the run answers the
    listener within.

    The cost of a turn rides on the reply (run-obtt): the tokens and provider-reported
    cost summed over the calls the turn took; absent cost contributes zero. *)

val create :
  client:Eta_ai_chat.t ->
  model:string ->
  reasoning:string ->
  logger:Eta_observability.Logger.t ->
  unit ->
  t
(** [create ~client ~model ~reasoning ~logger ()] is the planner over one chat client, for
    the configured [model] (run-d99l). [reasoning] is the configured effort; the word
    ["none"] (also ["off"] or ["disabled"]) turns OpenRouter's reasoning off instead.
    Cheap and synchronous: it opens no socket and registers no finalizer. Every answered
    call is logged at info with the model and the tokens it cost — a turn asked twice logs
    both calls, because both were paid for. *)
