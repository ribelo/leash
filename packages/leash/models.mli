(** The models the drive talks to (L19; drive-e7oi drive-yqxg drive-ls3c).

    One service owns both model clients over one {!Eta_http.Client.t} — the client is
    created with TLS here, on the service's switch, and every endpoint goes through it —
    and the drive's production [Decide] is {!decide}: {!Jev_request.body} shapes the
    request, {!Eta_ai_systemone.Client.evaluate} performs it, and {!Jev_request.decide}
    validates what came back. The text helper step's completion ({!Eta_ai_chat}) is the
    second client on the same transport; {!text_helper} hands it out.

    Cancellation and finalizers: {!create} acquires the HTTP client against [sw] and
    registers nothing else; every call runs in the calling fiber, opens and closes its own
    socket, and is bounded by its deadline. Nothing here probes the network at creation or
    for {!status}: a missing key is a refusal at the call, not a boot failure. *)

type t

val create :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  clock:_ Eio.Time.clock ->
  logger:Eta_observability.Logger.t ->
  Config.models ->
  t
(** [create ~sw ~net ~clock ~logger models] is the models service: one TLS HTTP client on
    [sw] and, when [models.api_key] is present, the System One client pinned to
    [models.jev_model] and pointed at [models.systemone_endpoint], plus the chat client of
    the text helper step pointed at [models.chat_base_url] (L22). Without a key there is
    no client at all and {!decide} refuses before anything is sent. The API key travels as
    a {!Eta_observability.Redact.t} and only {!Eta_ai.Bearer.header} reveals it, on the
    request path; the chat client is pure and synchronous, so it is built here beside the
    System One one and shares the transport. *)

val status : t -> Protocol.models_status
(** What [leash status] reports: [configured] is whether an API key is present, and the
    model ids and endpoints are the configured ones. The key itself is not a field and is
    never read here. *)

val decide :
  ?deadline:Eta.Duration.t ->
  t ->
  Jev_request.request ->
  (Jev_request.decision, Protocol.error) result
(** [decide ~deadline t request] is the drive's production Decide (drive-kh2u drive-e7oi):

    - no key: [model-unavailable] with [detail.code = "missing-key"] at once, nothing
      sent.
    - the System One reply names another model than the configured one, or fails in any of
      {!Eta_ai.Error}'s ways: [model-unavailable] with [detail.code] one of
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

val text_helper : t -> Text_helper.t
(** The text helper over this service's chat client and [models.text_model] (drive-ls3c).
    Every call is a fresh helper: the one-entry memo that reuses an answer when the whole
    helper input is unchanged is a drive's business and must not outlive it, while the
    client underneath is this service's. Without an API key the helper refuses with
    [detail.code = "missing-key"] and nothing is sent. *)
