(* L20 — the reference texts of the JEV request (docs/issues/drive/01-drive.md,
   milestone 5); drive-y37b drive-zml5). *)

(** jev-ultrafast's instruction texts, copied verbatim from [questions.py] at the pinned
    commit. JEV was trained on this framing, so a change to any of these strings is a
    decision, not a refactor: the test pins all three byte for byte against the source
    lines. {!next_action} and {!target} are the request's [rules]; {!text_value} is the
    text helper's system message (drive-ls3c, milestone 5's text helper step). *)

val commit : string
(** The pinned jev-ultrafast commit the texts were copied from. *)

val next_action : string
(** [NEXT_ACTION]: the operation question's rule. *)

val target : string
(** [TARGET]: the second rule of every [<operation>_target] question. *)

val text_value : string
(** [TEXT_VALUE]: what the text helper is asked for. *)
