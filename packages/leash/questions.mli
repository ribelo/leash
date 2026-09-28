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

(** L31 (run-vj48 run-qq3o run-kli0 run-vbys): the three questions the run's upper levels
    ask. They are not JEV-trained texts like jev's own — JEV sees whatever framing it is
    given — so they may be revised; the state they are asked over is the part the L30
    measurement pinned (story 18) and is built by {!Run}. [select_procedure] carries the
    L30 lesson in its instructions: DONE is the mission's end state, not an intermediate
    confirmation. *)

val select_playbook : string
(** The playbook question: the installed playbooks by site and description plus [none]. *)

val select_procedure : string
(** The procedure question, asked every turn over the small observed state. *)

val score : string -> string
(** [score sentence] is the score question's instructions for an expectation no checker
    resolves ("how well does the current page satisfy: <sentence>?"). *)

val score_levels : string list
(** The score question's two levels, in order: the answer's position is the [0, 1] score
    {!Playbook.await} compares against its threshold. *)

(** L32 (run-rq6i run-2tt3 run-obtt): the planner's own texts. The planner is the level
    above JEV, so its framing is ours; it answers in the playbook's schema, may attach the
    mission's expectations at its first turn, and a reply that did not decode is shown
    back with why exactly once. *)

val planner : string
(** The planner's system message: the three answer shapes, the procedure's schema, and the
    mission expectations it may attach. *)

val planner_retry : string -> string
(** [planner_retry why] is the follow-up user message of a turn whose first reply was
    refused, naming the refusal so the second answer can correct it. *)
