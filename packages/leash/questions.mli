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

val takeover : headless:bool -> string
(** takeover: the planner's instruction text when it holds the page. On a headless browser
    handoff is not offered (revert-r9ka). *)

val planner_retry : string -> string
(** [planner_retry why] is the follow-up user message of a turn whose first reply was
    refused, naming the refusal so the second answer can correct it. *)

(** dmod-as71: the multimodal additions of the decision-model family. Clef and Clef Flash
    take JEV's texts above verbatim; these are what a model that accepts images is offered
    on top. *)

val look_label : string
(** dmod-mcgn: the LOOK operation's criterion. *)

val click_at_label : string
(** dmod-4ky5: the CLICK_AT operation's criterion. *)

val click_at_rule : string
(** Appended to the operation rules when a screenshot is in the state. *)

val point_x : string

val point_y : string
(** The two score questions that choose a CLICK_AT point, one per axis. *)

val point_levels : axis:string -> int -> string list
(** [point_levels ~axis n] is the [n] equal bands of one axis, in order. *)

val probe_question : string
val probe_criteria : (string * string) list

val probe_tail : string
(** dmod-pjmy: the start-up truncation probe's question, criteria and the state's last
    sentence, which names green. *)
