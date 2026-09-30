(** The text helper a [type_text] step writes its value with (drive-ls3c drive-fh1h).

    L19 defined the seam; L22 fills it with ox's chat client: {!create} is one
    OpenAI-compatible completion over the service's {!Ox_ai_chat} client — [json_object]
    on, reasoning off, [max_tokens] 1024, the pinned [Config.text_model] — whose system
    message is {!Questions.text_value} and whose user message is jev's [field_context].
    The reply must parse as [{"text": string | null}]. Everything the helper needs from a
    drive is here, so the chat client stays out of this module and this module stays out
    of the drive.

    The shape is jev-ultrafast's [field_context] before it is written to the wire: the
    goal, the field the value goes into, the page the field is on, and the recent actions.
    L22 bounds the page text and the window when it shapes the request; this type carries
    what the drive has. *)

type field = { label : string; role : string; value : string }
(** The row the value is typed into: its label, its role, and the value it holds now. *)

type context = {
  goal : string;
  field : field;
  page_title : string;
  page_text : string;
  recent : Jev_request.recent_action list;
}
(** What one [type_text] decision is asked from, in the drive's own order: [recent] is the
    drive's history, oldest first. *)

type t = {
  complete : ?deadline:Ox.Duration.t -> context -> (string option, Protocol.error) result;
}
(** One configured text helper. [complete] answers the value to type, [Ok None] when the
    model answered [null] — the value is missing, and the drive ends [blocked] naming the
    field — and [Error] with [model-unavailable] when the helper failed or answered
    something that cannot be typed (drive-ls3c). The 4 KiB bound and the parse belong to
    the implementation: a caller sees a value it may type or a refusal, never raw model
    output.

    [deadline] bounds the whole call, the client's retries and backoff included (30
    seconds by default); the drive passes what is left of its own deadline, so a slow
    helper cannot outlast the reply the client waits for (drive-ix5t). *)

val create :
  client:Ox_ai_chat.t ->
  now:(unit -> float) ->
  model:string ->
  logger:Ox_observability.Logger.t ->
  unit ->
  t
(** [create ~client ~now ~model ~logger ()] is the helper over the service's one chat
    client, for the configured [model]. One instance serves one drive: it remembers the
    context it last answered and reuses that answer when the identical context comes back
    — what a stale-page retry is (drive-ls3c) — so an instance must not outlive the drive
    it served. Cheap and synchronous: no I/O, no socket, nothing to release. Every
    answered call is logged at info with the model, tokens and reported cost (drive-7tvn);
    a memo reuse makes no call and logs nothing. [now] is the client clock; correction
    calls receive only the remaining caller budget (daily-9ggi). *)

val unavailable : t
(** The L19 refusal for a drive that was given no text helper at all: every call is
    [model-unavailable] with [detail.code = "text-helper-unavailable"]. A models service
    without an API key answers {!missing_key} instead. *)

val missing_key : t
(** No API key: every call refuses with [model-unavailable] and
    [detail.code = "missing-key"], the same refusal {!Models.decide} makes before its
    first System One call (drive-kh2u). *)
