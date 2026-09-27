(** The text helper a [type_text] step writes its value with (drive-ls3c drive-fh1h).

    L19 defines the seam and leaves [type_text] on the drive's current stub; L22 fills it
    with eta-next's chat client ([Eta_ai_chat.complete] with [json_object] on and
    reasoning off, the pinned [models.text_model], the [models.chat_base_url]) and the
    [{"text": string | null}] parse. Everything the helper needs from a drive is here, so
    the chat client stays out of this module and this module stays out of the drive.

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

type t = { complete : context -> (string option, Protocol.error) result }
(** One configured text helper. [complete] answers the value to type, [Ok None] when the
    model answered [null] — the value is missing, and the drive ends [blocked] naming the
    field — and [Error] with [model-unavailable] when the helper failed. The 4 KiB bound
    and the parse belong to the implementation: a caller sees a value it may type or a
    refusal, never raw model output. *)

val unavailable : t
(** The L19 stub: every call refuses with [model-unavailable] and
    [detail.code = "text-helper-unavailable"], which is what {!Models.text_helper} answers
    until L22 installs the chat client. *)
