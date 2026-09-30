(** One model failure as the protocol's [model-unavailable] (drive-kh2u drive-ls3c).

    The six typed failures of {!Ox_ai.Error.t} are what both AI clients answer with —
    System One's decisions and the chat text helper's completions — and [docs/protocol.md]
    fixes the [detail.code] each one becomes. L19 wrote that table inside {!Models} for
    System One; L22's text helper is the second consumer, so it lives here once and a
    caller reads [detail.code] instead of parsing the sentence. *)

val unavailable : ?code:string -> string -> Protocol.error
(** [unavailable ~code message] is [model-unavailable] with [detail.code = code]
    (["unavailable"] by default). It is how a refusal that no provider produced is
    reported — a missing key, a reply that did not shape, a text that cannot be typed. *)

val with_kind : string -> Protocol.error -> Protocol.error
(** Add [detail.model_kind] at the model wiring boundary (daily-6pde). *)

val of_eta : ?kind:string -> Ox_ai.Error.t -> Protocol.error
(** [of_eta error] is the protocol's [model-unavailable] for an AI client failure: A
    timeout is [model-timeout] (retryable, exit 75); other failures remain
    [model-unavailable]. [kind], when supplied, adds [detail.model_kind]. [detail.code] is
    [error]'s kind (["unavailable"], ["timeout"], ["authentication"],
    ["invalid-response"], ["input-too-large"] or ["model-mismatch"]) and the message is
    {!Ox_ai.Error.to_string}'s provider sentence. *)
