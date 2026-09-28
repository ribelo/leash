(** The version-one control protocol: the wire contract of [docs/protocol.md] as types.

    A closed set of wire strings is a derived variant whose constructors carry their wire
    name as [@json.name]; [of_string] and [to_string] are that same codec read as a
    string, so a value outside the set is refused by naming the set. A field that
    [docs/protocol.md] shows as [T|null] stays on the wire and reads [null] when it has no
    value; a field it shows as [key?] is omitted when it has none. A field of type
    [Yojson.Safe.t] is a value whose shape belongs to the page or to the caller — an
    [eval] argument or result, an error's [detail], the [drive] probabilities — and passes
    through unchanged.

    The envelope is dispatched by hand — a request is a ["cmd"] name with an ["args"]
    object, a reply is [{ok, result}] or [{ok, error}] — while every per-command argument
    record and every result record is a plain type with a derived codec. A decode failure
    from the deriver names the offending path and value, which is what an
    [invalid-request] reply renders. *)

(** A tab handle: non-empty by construction. *)
module Handle : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** A snapshot id: non-empty by construction. *)
module Snapshot_id : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** The requester: ["dsh:<session>"], ["human"], or an operator's choice. *)
module Owner : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Origin : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module State : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Stage : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Dialog_kind : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Row_state : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Debug_kind : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Operation : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Direction : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Answer : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Drive_status : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** L31 run-9ypy: the closed set a run answers with — [done], [blocked], [failed],
    [handoff], [limit], [deadline], [error]. It is not the drive's set: a run adds
    [handoff] and [failed], and its [error] is a page state or a model or browser failure
    rather than a step that could not act. *)
module Run_status : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Chrome_phase : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** Why a tab is gone: the tombstone's disposition (ADR-0005). It is the closed set
    [closed_by_owner], [closed_by_ttl], [closed_externally], [browser_lost] that a
    [tab-gone] reply carries in [detail.disposition]. *)
module Disposition : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** The closed error-code set of [docs/protocol.md]: [no-handoff] is what [resume] answers
    on a tab nobody is waiting on (hand-szz7). *)
module Error_code : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

type expires = { stage : Stage.t; in_s : int }

val expires_of_yojson : Yojson.Safe.t -> (expires, string) result
val yojson_of_expires : expires -> Yojson.Safe.t

type dialog = { kind : Dialog_kind.t; message : string }

val dialog_of_yojson : Yojson.Safe.t -> (dialog, string) result
val yojson_of_dialog : dialog -> Yojson.Safe.t

type tab_info = {
  tab : Handle.t;
  url : string;
  title : string;
  origin : Origin.t;
  state : State.t;
  owner : Owner.t option;
  generation : int;
  expires : expires option;
  reason : string option;
}
(** [owner] and [expires] are [T|null]: both keys are always on the wire and read [null]
    when there is no value. [reason] is [key?]: it is present exactly while a handoff is
    waiting on the tab and carries the reason the human was given, so [list --all] shows
    which tabs wait on the human and why (hand-r4t1). *)

val tab_info_of_yojson : Yojson.Safe.t -> (tab_info, string) result
val yojson_of_tab_info : tab_info -> Yojson.Safe.t

type row_option = {
  index : int;
  label : string;
  value : string;
  selected : bool;
  disabled : bool;
}
(** One option of a select row: [index] is its position in the select's own option order,
    which is the index the [select] action takes (tab-5deq); [label] is the option's text
    and [value] the value it carries, its label when it carries none. *)

val row_option_of_yojson : Yojson.Safe.t -> (row_option, string) result
val yojson_of_row_option : row_option -> Yojson.Safe.t

type row = {
  index : int;
  role : string;
  name : string;
  value : string option;
  state : Row_state.t list option;
  options : row_option list option;
}
(** [value], [state] and [options] are [key?]: each is omitted when the row has none.
    [options] is the option list of a native select row — role [combobox] or [listbox],
    read from the accessibility tree even while the select is closed — in the select's own
    order; it is absent on every other row. A closed select's options have no layout box
    and never become rows of their own (tab-5deq). *)

val row_of_yojson : Yojson.Safe.t -> (row, string) result
val yojson_of_row : row -> Yojson.Safe.t

type snapshot = {
  snapshot : Snapshot_id.t;
  tab : Handle.t;
  url : string;
  title : string;
  rows : row list;
  total : int;
  offset : int;
  truncated : bool;
  settled : bool;
  dialog : dialog option;
}
(** [dialog] is [T|null]. *)

val snapshot_of_yojson : Yojson.Safe.t -> (snapshot, string) result
val yojson_of_snapshot : snapshot -> Yojson.Safe.t

type action_result = {
  tab : Handle.t;
  url : string;
  title : string;
  snapshot : Snapshot_id.t option;
  dialog : dialog option;
  popups : tab_info list;
}
(** [snapshot] and [dialog] are [T|null]. *)

val action_result_of_yojson : Yojson.Safe.t -> (action_result, string) result
val yojson_of_action_result : action_result -> Yojson.Safe.t

type debug_entry = {
  at : string;
  kind : Debug_kind.t;
  level : string option;
  text : string;
}

val debug_entry_of_yojson : Yojson.Safe.t -> (debug_entry, string) result
val yojson_of_debug_entry : debug_entry -> Yojson.Safe.t

type after = { url : string; title : string }

val after_of_yojson : Yojson.Safe.t -> (after, string) result
val yojson_of_after : after -> Yojson.Safe.t

type probabilities = { op : Yojson.Safe.t; target : Yojson.Safe.t }
(** [op] and [target] are the model's probability objects, whose shape belongs to the
    model. *)

val probabilities_of_yojson : Yojson.Safe.t -> (probabilities, string) result
val yojson_of_probabilities : probabilities -> Yojson.Safe.t

type step = {
  n : int;
  snapshot : Snapshot_id.t;
  operation : Operation.t;
  index : int option;
  probabilities : probabilities;
  text : string option;
  after : after;
  elapsed_ms : int;
}
(** [index] is [T|null]; [text] is [key?]. *)

val step_of_yojson : Yojson.Safe.t -> (step, string) result
val yojson_of_step : step -> Yojson.Safe.t

type new_args = { url : string option }
type list_args = { all : bool }
type tab_args = { tab : Handle.t }

type force_args = { tab : Handle.t; force : bool option }
(** The arguments of the two commands a caller may force (own-0pnk): [force] is honoured
    only for [release] and [close], and is a [key?] field — omitted when the caller does
    not ask for it. *)

val force_args_of_yojson : Yojson.Safe.t -> (force_args, string) result
val yojson_of_force_args : force_args -> Yojson.Safe.t

type snap_args = {
  tab : Handle.t;
  match_ : string option;
  limit : int option;
  offset : int option;
}

type text_args = { tab : Handle.t; index : int option; max_chars : int option }
type shot_args = { tab : Handle.t; path : string; full_page : bool option }
type debug_args = { tab : Handle.t; limit : int option; clear : bool option }
type eval_args = { tab : Handle.t; expression : string; argument : Yojson.Safe.t option }
type nav_args = { tab : Handle.t; url : string }
type click_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int }
type fill_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int; text : string }

type press_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int option;
  key : string;
}

type select_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int; option : int }
type scroll_args = { tab : Handle.t; direction : Direction.t; index : int option }

type wait_until = {
  url_prefix : string option;
  text : string option;
  index_gone : int option;
  dialog : bool option;
}

type wait_args = { tab : Handle.t; until : wait_until; timeout_ms : int option }
type dialog_args = { tab : Handle.t; answer : Answer.t; text : string option }
type handoff_args = { tab : Handle.t; reason : string; timeout_s : int option }

type drive_args = {
  tab : Handle.t;
  goal : string;
  max_steps : int option;
  deadline_s : int option;
  dry_run : bool option;
}
(** The per-command argument records: each is derived, every [key?] field is omitted when
    [None], and [decode_request] refuses a key its record does not name. *)

type run_args = {
  tab : Handle.t option;
  mission : string;
  max_procedures : int option;
  deadline_s : int option;
  dry_run : bool option;
  expect : string list option;
}
(** L31 run-9ypy: one mission over the installed playbooks. [tab] is [key?]: a run given
    one reuses it, after checking ownership and that no dialog is open, and a run given
    none opens a tab of its own — the one the [final] snapshot names — and leaves it open.
    [max_procedures] defaults to 40 and [deadline_s] to 900; [dry_run] asks the two levels
    and reports without acting (run-fp7i). [expect] is the mission's own expectations —
    the sentences DONE is verified against independently of the last procedure (run-4j1v,
    the L30 guard) — which L32's planner attaches on its first turn and which a caller may
    state directly. It is a [key?] list: omitted when the mission carries none. *)

type tab_counts = { open_ : int; cap : int }

val tab_counts_of_yojson : Yojson.Safe.t -> (tab_counts, string) result
val yojson_of_tab_counts : tab_counts -> Yojson.Safe.t

type models_status = {
  configured : bool;
  jev_model : string;
  text_model : string;
  systemone_endpoint : string;
  chat_base_url : string;
}
(** L19 drive-e7oi drive-yqxg: what [status] reports about the models section — whether an
    API key is present, the pinned JEV model, the text helper's model, and the two
    endpoints. It is the configuration and nothing else: it is read from the live config
    without a probe, so nothing here touches the network at boot or at [status], and the
    key itself is not a field — a {!Eta_observability.Redact.t} renders as ["<redacted>"]
    on every path, so no status reply can carry one. *)

val models_status_of_yojson : Yojson.Safe.t -> (models_status, string) result
val yojson_of_models_status : models_status -> Yojson.Safe.t

type status_result = {
  generation : int;
  tabs : tab_counts;
  chrome : Chrome_phase.t;
  uptime_s : float;
  models : models_status option; [@json.null]
}
(** [models] is [T|null]: the service's models section, which every service the Door
    starts has, and [null] only in a dispatch that was given no models service. *)

val status_result_of_yojson : Yojson.Safe.t -> (status_result, string) result
val yojson_of_status_result : status_result -> Yojson.Safe.t

type list_result = { tabs : tab_info list }

type download_info = {
  id : string;
  suggested_name : string;
  mime : string;
  state : string;
  path : string option; [@json.null]
}

type downloads_result = { downloads : download_info list }

val downloads_result_of_yojson : Yojson.Safe.t -> (downloads_result, string) result
val yojson_of_downloads_result : downloads_result -> Yojson.Safe.t
val list_result_of_yojson : Yojson.Safe.t -> (list_result, string) result
val yojson_of_list_result : list_result -> Yojson.Safe.t

type released_result = { released : bool }
type closed_result = { closed : bool }

val yojson_of_released_result : released_result -> Yojson.Safe.t
val yojson_of_closed_result : closed_result -> Yojson.Safe.t

type resumed_result = { resumed : bool }
type text_result = { url : string; title : string; text : string; truncated : bool }

val yojson_of_resumed_result : resumed_result -> Yojson.Safe.t
(** [resumed_result] is the reply [resume] answers with, once the human's signal has
    handed the tab back (hand-0sja). *)

val text_result_of_yojson : Yojson.Safe.t -> (text_result, string) result
val yojson_of_text_result : text_result -> Yojson.Safe.t

type shot_result = { path : string; bytes : int }
type debug_result = { entries : debug_entry list }
type eval_result = { value : Yojson.Safe.t }

val yojson_of_shot_result : shot_result -> Yojson.Safe.t
val yojson_of_debug_result : debug_result -> Yojson.Safe.t
val yojson_of_eval_result : eval_result -> Yojson.Safe.t

type handoff_result = {
  resumed : bool;
  url : string;
  title : string;
  warnings : string list option;
}
(** [warnings] is [key?]: the human-facing steps — [Target.activateTarget], the focus
    command, the notification — that failed. Each is best effort: it is also a log line,
    and none of them fails the handoff (hand-rg9h). *)

val yojson_of_handoff_result : handoff_result -> Yojson.Safe.t
(** What a handoff answers when the human resumes it (hand-lz3p): the page's url and title
    at that moment, which is what the agent re-observes from, and the warnings of the
    human-facing steps that did not complete (hand-rg9h). A handoff that ends any other
    way is an error — [timeout] for the deadline, whose [detail.warnings] carries the same
    list when there is one, and [tab-gone] for a tab that disappeared while the request
    waited (hand-lmd5 hand-yytf). *)

type drive_result = {
  status : Drive_status.t;
  steps : step list;
  final : snapshot;
  reason : string option;
}

val drive_result_of_yojson : Yojson.Safe.t -> (drive_result, string) result
val yojson_of_drive_result : drive_result -> Yojson.Safe.t

type run_usage = { input_tokens : int; output_tokens : int; cost : float }
(** run-xqh8: one upper-level or planner call's provider-reported accounting. *)

val run_usage_of_yojson : Yojson.Safe.t -> (run_usage, string) result
val yojson_of_run_usage : run_usage -> Yojson.Safe.t

type run_choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : run_usage option; [@json.null]
}
(** run-xqh8 run-qq3o: the upper level's answer with the distribution behind it: [key] is
    the criterion it chose — a playbook's site, a procedure's slug, [DONE] or [BLOCKED] —
    and [probabilities] the model's own object, keyed as the model answered it. *)

val run_choice_of_yojson : Yojson.Safe.t -> (run_choice, string) result
val yojson_of_run_choice : run_choice -> Yojson.Safe.t

type run_expectation = {
  sentence : string;
  checker : string;
  passed : bool;
  score : float option; [@json.null]
}
(** run-xqh8: one expectation and how it was verified — the checker's kind (["page_kind"],
    ["text"], ["download"], ["no_dialog"], ["row"] or ["judgment"]) and, where only
    judgment could decide, the JEV score. [score] is [T|null]. *)

val run_expectation_of_yojson : Yojson.Safe.t -> (run_expectation, string) result
val yojson_of_run_expectation : run_expectation -> Yojson.Safe.t

type run_drive = {
  goal : string;
  status : Drive_status.t;
  steps : step list;
  reason : string option;
}
(** run-d82w run-xqh8: one operator step — the single [drive] call a playbook step became
    — with the goal it was given and the drive's own result. *)

val run_drive_of_yojson : Yojson.Safe.t -> (run_drive, string) result
val yojson_of_run_drive : run_drive -> Yojson.Safe.t

type run_procedure = {
  slug : string;
  site : string;
  planned : bool;
  attempts : int;
  choice : run_choice;
  drives : run_drive list;
  expectations : run_expectation list;
  outcome : string;
  elapsed_ms : int;
  reason : string option;
}
(** run-xqh8: one procedure the run executed. [outcome] is one of ["verified"], ["failed"]
    (its second verification failed), ["skipped"] (an optional [use] whose first step
    ended blocked) or ["planned"] (a dry run chose it and executed nothing). [attempts] is
    2 when the retry-once rule replayed the procedure (run-k8bx); [planned] is true when a
    planner turn wrote it (run-m0r8). [drives] is empty for ["planned"] — and, in a dry
    run, for every entry: nothing was executed. [reason] is [key?] and says why a skipped
    or failed procedure ended that way. *)

val run_procedure_of_yojson : Yojson.Safe.t -> (run_procedure, string) result
val yojson_of_run_procedure : run_procedure -> Yojson.Safe.t

type planner_turn = {
  n : int;
  trigger : string;
  answer : string;
  reason : string option;
  usage : run_usage option; [@json.null]
}
(** run-xqh8 run-klp9: one planner turn. [trigger] is ["blocked"], ["failed"] or
    ["arguments"] — the point JEV stopped; [answer] is ["procedure"], ["handoff"] or
    ["fail"]. L31's planner is a stub that answers ["fail"] (L32 is Luna), so [usage] is
    [T|null] there. *)

val planner_turn_of_yojson : Yojson.Safe.t -> (planner_turn, string) result
val yojson_of_planner_turn : planner_turn -> Yojson.Safe.t

type run_result = {
  status : Run_status.t;
  site : string option; [@json.null]
  procedures : run_procedure list;
  mission_expectations : run_expectation list;
  planner_turns : planner_turn list;
  final : snapshot;
  reason : string option;
}
(** run-9ypy: the whole run. [site] is the playbook that served the mission, [T|null] when
    the run never chose one; [procedures] is the trace, oldest first;
    [mission_expectations] is how the mission's own expectations came out at the DONE
    guard (empty when the mission carried none); [final] is the last snapshot the run
    observed — its [dialog] is what ended an [error] (run-klp9); [reason] is [key?] and
    names why the run stopped. *)

val run_result_of_yojson : Yojson.Safe.t -> (run_result, string) result
val yojson_of_run_result : run_result -> Yojson.Safe.t

type error = { code : Error_code.t; message : string; detail : Yojson.Safe.t option }
(** What a failed reply carries: a closed code, one sentence, and optional structured
    context ([key?]: omitted when there is none). *)

val error_of_yojson : Yojson.Safe.t -> (error, string) result
val yojson_of_error : error -> Yojson.Safe.t

val tab_gone : Disposition.t -> error
(** own-teh1: the one [tab-gone] error, carrying the disposition that closed the tab in
    [detail.disposition] — [closed_by_owner], [closed_by_ttl], [closed_externally], or
    [browser_lost]. Every path that reports a closed tab says it this way: a tombstone, a
    dispatch this tab's death settled (tab-0ohq), and the browser lookup that probe makes.
*)

type reply =
  | Success of Yojson.Safe.t
  | Failure of error
      (** One of the two wire shapes; the result is raw JSON because a client that does
          not know the command's result type still prints it. *)

val encode_reply : reply -> Yojson.Safe.t
val decode_reply : Yojson.Safe.t -> (reply, string) result

type command =
  | New of new_args
  | List_tabs of list_args
  | Claim of tab_args
  | Release of force_args
  | Close of force_args
  | Status
  | Snap of snap_args
  | Text of text_args
  | Shot of shot_args
  | Debug of debug_args
  | Eval of eval_args
  | Nav of nav_args
  | Click of click_args
  | Fill of fill_args
  | Press of press_args
  | Select of select_args
  | Scroll of scroll_args
  | Wait of wait_args
  | Dialog of dialog_args
  | Handoff of handoff_args
  | Resume of tab_args
  | Drive of drive_args
  | Downloads of tab_args
  | Run of run_args
      (** The decoded command: one constructor per row of [docs/protocol.md]'s command
          tables, carrying that command's derived argument record. *)

val command_name : command -> string
val args_to_json : command -> Yojson.Safe.t

val command_of_args : cmd:string -> Yojson.Safe.t -> (command, string) result
(** The command table: the wire name, the derived argument decode, and the derived
    argument encode. [Status] takes an empty object and nothing else. *)

type request = { owner : Owner.t; command : command }

val version : int
val encode_request : request -> Yojson.Safe.t

val decode_request : Yojson.Safe.t -> (request, string) result
(** The envelope: ["v"] must be {!version}, ["owner"] must be non-empty, ["cmd"] must be
    one of the commands above, and ["args"] must decode into that command's record. An
    unknown envelope field or argument is refused by name. *)
