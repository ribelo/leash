(** The planner turn — Luna by default (L32, milestone 7; run-w7ke run-rq6i run-2tt3
    run-obtt run-d99l).

    The planner is the level above JEV, and only that: the run asks it where JEV stopped —
    a BLOCKED answer, a procedure that failed its expectations twice, an argument the text
    helper could not fill (run-w7ke) — and never for the work itself. One turn is one
    {!Ox_ai_chat.complete} call with [json_object] on and reasoning at the configured
    effort: the system message is {!Questions.planner}, the user message is the
    {!Run.plan_request} as JSON — the mission, the playbook in its own schema, the trace,
    the arguments known and the observed page with its text bounded — and the reply must
    decode into a supported answer: [procedure] (a new procedure in the playbook's schema,
    to run now), [handoff] (a reason for the human), [fail] (a reason for the operator),
    or [continue] (an optional bounded list of ordinary actions targeting the supplied
    snapshot before returning to JEV). A reply that does not decode, or that names a
    procedure this playbook cannot run, is shown back with its refusal and asked once
    more; a second refusal ends the turn as [model-unavailable] with
    [detail.code = "invalid-response"]. A turn's first reply may also attach the mission's
    expectations (run-2tt3), each of which must resolve against the playbook's own page
    kinds.

    The chat client is the models service's — one transport for every model, as with
    {!Text_helper} — and this module owns the prompt, the fail-closed decode and the
    accounting. The caller supplies its clock as a thunk to bound correction calls. *)

type t = {
  choose : deadline:Ox.Duration.t -> Run.question -> Protocol.playbook_choice;
      (** One bounded choice-only call. Invalid answers are recorded with no key; the
          caller retains JEV's argmax. No correction call or procedure generation. *)
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

val learning_response_metadata : Yojson.Safe.t -> Yojson.Safe.t
(** map-ptnk: allowlisted finish reason, content shape, output budget, tokens and cost; no
    message content, reasoning text, request body or arbitrary provider fields. *)

val learning_prompt_version : string

val learning :
  client:Ox_ai_chat.t ->
  model:string ->
  reasoning:string ->
  logger:Ox_observability.Logger.t ->
  deadline:Ox.Duration.t ->
  Yojson.Safe.t ->
  (Yojson.Safe.t, string) result

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
