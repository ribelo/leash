(** The models the drive talks to (L19; drive-e7oi drive-yqxg drive-ls3c).

    One service owns every model client over one {!Ox_http.Client.t} — the client is
    created with TLS here, on the service's switch, and every endpoint goes through it —
    and the drive's production [Decide] is {!decide}: {!Jev_request.body} shapes the
    request, {!Ox_ai_systemone.Client.evaluate} performs it, and {!Jev_request.decide}
    validates what came back. The text helper step's completion ({!Ox_ai_chat}) is the
    second client on the same transport; {!text_helper} hands it out. L32 adds the
    planner's own chat client on that same transport, whose model, reasoning and endpoint
    are the models section's to configure (run-d99l); {!levels} is what the run uses.

    Cancellation and finalizers: {!create} acquires the HTTP client against [sw] and
    registers nothing else; every call runs in the calling fiber, opens and closes its own
    socket, and is bounded by its deadline. Nothing here probes the network at creation or
    for {!status}: a missing key is a refusal at the call, not a boot failure.

    daily-9ggi: [models.jev_timeout], [models.text_timeout] and [models.planner_timeout]
    bound individual provider attempts (seconds), not the mission. Ox retains its
    two-attempt retry policy inside the caller deadline. Provider timeouts report
    [model-timeout] with [detail.code = "timeout"] and [detail.model_kind] identifying
    [jev], [text] or [planner]. *)

type t

val create :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  clock:_ Eio.Time.clock ->
  logger:Ox_observability.Logger.t ->
  Config.models ->
  t
(** [create ~sw ~net ~clock ~logger models] is the models service: one TLS HTTP client on
    [sw] and, when [models.api_key] is present, the System One client pinned to
    [models.jev_model] and pointed at [models.systemone_endpoint], plus the chat client of
    the text helper step pointed at [models.chat_base_url] (L22) and the planner's chat
    client, pointed at [models.planner_endpoint] when the operator set one and at the same
    chat route otherwise (run-d99l). Without a key there is no client at all and {!decide}
    refuses before anything is sent. The API key travels as a {!Ox_observability.Redact.t}
    and only {!Ox_ai.Bearer.header} reveals it, on the request path; the chat client is
    pure and synchronous, so it is built here beside the System One one and shares the
    transport. *)

val status : t -> Protocol.models_status
(** What [leash status] reports: [configured] is whether an API key is present, and the
    model ids and endpoints are the configured ones. The key itself is not a field and is
    never read here. *)

val decide :
  ?deadline:Ox.Duration.t ->
  ?on_usage:(Yojson.Safe.t -> unit) ->
  t ->
  Jev_request.request ->
  (Jev_request.decision, Protocol.error) result
(** [decide ~deadline t request] is the drive's production Decide (drive-kh2u drive-e7oi):

    - no key: [model-unavailable] with [detail.code = "missing-key"] at once, nothing
      sent.
    - the System One reply names another model than the configured one, or fails in any of
      {!Ox_ai.Error}'s ways: [model-unavailable] with [detail.code] one of
      ["unavailable"], ["timeout"], ["authentication"], ["invalid-response"],
      ["input-too-large"], ["model-mismatch"], and the provider's own sentence as the
      message.
    - a reply that does not answer the questions the request asked: [model-unavailable]
      with [detail.code = "invalid-response"] and {!Jev_request.decide}'s sentence.

    [deadline] (30 seconds by default) bounds the whole call, both attempts and the
    backoff included; the drive passes what is left of its own deadline.

    Every answered call is logged at info with the model, the input and output token
    counts and the cost the provider reported (drive-7tvn), before the answers are
    validated: the tokens were spent either way. Refusals and failures log nothing. *)

val text_helper : ?on_usage:(Yojson.Safe.t -> unit) -> t -> Text_helper.t
(** The text helper over this service's chat client and [models.text_model] (drive-ls3c).
    Every call is a fresh helper: the one-entry memo that reuses an answer when the whole
    helper input is unchanged is a drive's business and must not outlive it, while the
    client underneath is this service's. Without an API key the helper refuses with
    [detail.code = "missing-key"] and nothing is sent. *)

(* ---------- L31: the run's upper levels (run-7blx run-vj48) ---------- *)

val choose :
  ?deadline:Ox.Duration.t -> t -> Run.question -> (Run.choice, Protocol.error) result
(** [choose ?deadline t question] is one upper-level choice question — the playbook
    level's or the procedure level's — through the same System One client, the same model
    and the same transport the operator level uses (run-7blx). The answer is validated
    fail-closed against the criteria the question offered and the reference's own
    distribution check: a key the question did not offer, or a distribution that is not a
    valid choice, is [model-unavailable] with [detail.code = "invalid-response"]. Without
    a key it is [missing-key] before anything is sent, as {!decide} is.

    [deadline] (30 seconds by default) bounds the whole call, both attempts and the
    backoff included; the run passes what is left of its own deadline. An answered call is
    logged at info with the tokens and cost the provider reported, and those ride on as
    the answer's [usage] so the run's trace carries them (run-xqh8).

    For [select_playbook] only, a top probability below [models.choice_confidence]
    (default 0.7) adds one bounded choice-only planner review over the same state and
    options. [Run.choice.judgments] retains both answers and their own usage. An invalid
    review leaves the validated JEV argmax in force with a trace note. The review is
    capped at 30 seconds and the remaining caller budget, with no correction call. *)

val score :
  ?deadline:Ox.Duration.t ->
  t ->
  sentence:string ->
  state:Yojson.Safe.t ->
  (float, Protocol.error) result
(** run-vbys: the score question one expectation no checker resolves is asked, over the
    page summary the caller builds. The answer is the position on
    {!Questions.score_levels} and must be a finite number in [0, 1]; anything else is
    [invalid-response]. The caller compares it against its threshold. *)

val learning : t -> Config.learning -> Yojson.Safe.t -> (Yojson.Safe.t, string) result

val levels : t -> Run.levels
(** run-7blx run-w7ke run-d99l: the run's three upper-level calls over this one service.
    [plan] is L32's planner turn — {!Planner} over the configured [planner_model], at the
    configured [planner_reasoning], through the planner's own chat client — so a run that
    stops needing judgment gets Luna's answer, and without an API key it is [missing-key]
    before anything is sent. Every answered call is logged at info with its tokens, and
    those ride on as the reply's [usage] so the run's trace carries them (run-obtt). *)
