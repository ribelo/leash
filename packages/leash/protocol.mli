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

module Origin : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

module Popup_state : sig
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

(** hard-ufb7: which of a page's two web storages `storage` reads: [local] or [session].
*)
module Storage_area : sig
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

(** Why a tab is gone: the tombstone's disposition (ADR-0010). It is the closed set
    [closed_by_handle], [closed_by_idle], [closed_externally], [browser_lost] that a
    [tab-gone] reply carries in [detail.disposition]. *)
module Disposition : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** The closed error-code set of [docs/protocol.md], service codes and the client-side
    codes the CLI prints ([service-unreachable], [not-installed], [service-stopped],
    [service-restarting], [socket-permission], [permission-denied], [config-invalid],
    [usage], [cli-parse], [invalid-response]). [no-handoff] is what [resume] answers on a
    tab nobody is waiting on (hand-szz7). *)
module Error_code : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t

  val all : t list
  (** Every code. The table test compares this list to the declared wire constructors,
      then checks each exit, hint, documentation row and help line (daily-u1k2). *)

  val exit_code : t -> int
  (** Sysexits class, one per class, the set [cli_help] documents: 64 usage, 65 stale or
      invalid data (including configuration and playbook), 66 unknown or gone tab, row, or
      request, 69 unavailable, 70 internal, 75 retryable, 77 permission, 124 command-line
      parse. *)

  val hint : t -> string
  (** One line naming the next action. No tab and no newline (daily-6pde). *)

  val meaning : t -> string
  (** One line: when this code is used. *)

  val error_help : string
  (** Tab-separated table: a [# code exit meaning hint] header, then one line per {!all}
      (daily-pb5a). *)

  val topic_markdown : string
  (** Markdown source of [docs/help/errors.md] and [leash help errors]. Same rows as
      {!error_help}, so the topic cannot drift from this module (hdoc-ztwo). *)
end

type dialog = { kind : Dialog_kind.t; message : string; default_prompt : string option }

val dialog_of_yojson : Yojson.Safe.t -> (dialog, string) result
val yojson_of_dialog : dialog -> Yojson.Safe.t

type page_kind_source =
  | Declared
  | Inferred
      (** kind-tdrv: [Declared] is a loaded playbook's kind. [Inferred] is {!Page_kind}.
      *)

type page_kind_label = { name : string; source : page_kind_source }
(** Shown by [list] and [snap]. [name] is the kind; [source] is [declared] or [inferred].
*)

val page_kind_source_of_yojson : Yojson.Safe.t -> (page_kind_source, string) result
val yojson_of_page_kind_source : page_kind_source -> Yojson.Safe.t
val page_kind_label_of_yojson : Yojson.Safe.t -> (page_kind_label, string) result
val yojson_of_page_kind_label : page_kind_label -> Yojson.Safe.t

type tab_info = {
  tab : Handle.t;
  label : string option;
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option;
  with_human : bool;
  reason : string option;
  generation : int;
  dialog : dialog option;
  loaded : bool option;
}

type tab_listing = {
  label : string option;
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option;
  with_human : bool;
  reason : string option;
}

val tab_listing_of_yojson : Yojson.Safe.t -> (tab_listing, string) result
val yojson_of_tab_listing : tab_listing -> Yojson.Safe.t
val tab_info_of_yojson : Yojson.Safe.t -> (tab_info, string) result
val yojson_of_tab_info : tab_info -> Yojson.Safe.t

type popup_info = {
  tab : Handle.t option;
  label : string option;
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option;
  with_human : bool;
  reason : string option;
  state : Popup_state.t;
  generation : int;
  dialog : dialog option;
  opener_url : string;
}

val popup_info_of_yojson : Yojson.Safe.t -> (popup_info, string) result
val yojson_of_popup_info : popup_info -> Yojson.Safe.t

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

type snapshot_source = Ax | Dom

val snapshot_source_of_yojson : Yojson.Safe.t -> (snapshot_source, string) result
val yojson_of_snapshot_source : snapshot_source -> Yojson.Safe.t

type snapshot = {
  snapshot : Snapshot_id.t;
  tab : Handle.t;
  url : string;
  title : string;
  page_kind : page_kind_label option;
  rows : row list;
  total : int;
  offset : int;
  truncated : bool;
  settled : bool;
  source : snapshot_source;
  reason : string option;
  dialog : dialog option;
}
(** [dialog] is [T|null]. *)

val snapshot_of_yojson : Yojson.Safe.t -> (snapshot, string) result
val yojson_of_snapshot : snapshot -> Yojson.Safe.t

type action_result = {
  tab : Handle.t;
  url : string;
  title : string;
  snapshot : snapshot option;
  dialog : dialog option;
  popups : popup_info list;
  via : string option;
}
(** [snapshot] and [dialog] are [T|null]. [snapshot] is null, or a fresh {!snapshot} taken
    after settlement when the request set [snap] (field-swvb) — a snapshot object, not an
    id. [via] is [key?]: ["label"] when the click dispatched on the target's covering
    label (field-uls3), absent otherwise. *)

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

(* trace-qe8c trace-iqqz trace-lg58: deliberately capability-free projections. *)
type trace_target = {
  target_role : string; [@json.key "role"]
  target_label : string; [@json.key "label"]
}
[@@deriving yojson]

type step = {
  non_repeatable : bool;
  n : int;
  snapshot : Snapshot_id.t;
  operation : Operation.t;
  index : int option;
  probabilities : probabilities;
  target : trace_target option;
  text : string option;
  after : after;
  elapsed_ms : int;
}
(** [index] is [T|null]; [text] is [key?]. *)

val step_of_yojson : Yojson.Safe.t -> (step, string) result
val yojson_of_step : step -> Yojson.Safe.t

type new_args = { url : string option; label : string option }
type take_args = { url : string option; title : string option; label : string option }

val take_args_of_yojson : Yojson.Safe.t -> (take_args, string) result
val yojson_of_take_args : take_args -> Yojson.Safe.t

type tab_args = { tab : Handle.t }

type snap_args = {
  tab : Handle.t;
  match_ : string option;
  limit : int option;
  offset : int option;
}

type text_args = { tab : Handle.t; index : int option; max_chars : int option }
type shot_args = { tab : Handle.t; path : string; full_page : bool option }
type debug_args = { tab : Handle.t; limit : int option; clear : bool option }

type eval_args = {
  tab : Handle.t;
  expression : string;
  argument : Yojson.Safe.t option;
  index : int option;
  snapshot : Snapshot_id.t option;
}
(** hard-b20d: [index] and [snapshot] come together — the expression is then called with
    the row's element as its second parameter, [(argument, element)]. *)

type nav_args = { tab : Handle.t; url : string }

type click_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  snap : bool option;
  match_ : string option;
  limit : int option;
}
(** [snap], [match_] and [limit] are [key?]. [snap] asks for a fresh snapshot in the reply
    after settlement; [match_] and [limit] are the same filters as [snap] (field-swvb).
    [check] and [uncheck] use this record (field-guda). *)

type fill_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  text : string;
  snap : bool option;
  match_ : string option;
  limit : int option;
}

type press_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int option;
  key : string;
  snap : bool option;
  match_ : string option;
  limit : int option;
}

type select_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  option : int;
  snap : bool option;
  match_ : string option;
  limit : int option;
}

type scroll_args = { tab : Handle.t; direction : Direction.t; index : int option }

type wait_until = {
  url_prefix : string option;
  text : string option;
  index_gone : int option;
  dialog : bool option;
  changed_since : Snapshot_id.t option;
}
(** hard-sckn: [changed_since] holds once the page's loader id or mutation counter differs
    from the named snapshot's. *)

type wait_args = { tab : Handle.t; until : wait_until; timeout_ms : int option }
type dialog_args = { tab : Handle.t; answer : Answer.t; text : string option }
type handoff_args = { tab : Handle.t; reason : string; timeout_s : int option }

type net_args = {
  tab : Handle.t;
  match_ : string option;
  limit : int option;
  type_ : string option;
}
(** hard-xg6y: [match_] is a case-insensitive substring of the URL, [limit] keeps the most
    recent N (default 100, at most 500) and [type_] is a resource type such as [xhr],
    [fetch] or [document], compared case-insensitively. *)

type net_entry_args = { tab : Handle.t; id : string }
(** hard-ovbx hard-vq5s: one request of the tab's ring, by the [id] a listing gave. *)

type upload_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  paths : string list;
}
(** hard-o3za hard-qimz: absolute, readable regular files; at most 10 and 10 GiB together.
*)

type hover_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  snap : bool option;
  match_ : string option;
  limit : int option;
}

type storage_args = { tab : Handle.t; area : Storage_area.t }

type playbook_test_args = { tab : Handle.t; script : string; args : Yojson.Safe.t option }
(** extr-mp5z: [script] is [<playbook>/<script>], [args] an object of strings. No script
    text is ever on the wire: the service reads it from the playbook directory. *)

type playbook_check_args = { playbook : string }
(** extr-lslp: the installed playbook's directory name. *)

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
  max_steps : int option;
  start_url : string option;
  max_procedures : int option;
  deadline_s : int option;
  dry_run : bool option;
  expect : string list option;
  out : string option;
}
(** L31 run-9ypy: one mission over the installed playbooks. [tab] is [key?]: a run given
    one reuses it, after checking the handle and that no dialog is open, and a run given
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
    key itself is not a field — a {!Ox_observability.Redact.t} renders as ["<redacted>"]
    on every path, so no status reply can carry one. *)

val models_status_of_yojson : Yojson.Safe.t -> (models_status, string) result
val yojson_of_models_status : models_status -> Yojson.Safe.t

type status_result = {
  generation : int;
  tabs : tab_counts;
  chrome : Chrome_phase.t;
  uptime_s : float;
  models : models_status option; [@json.null]
  version : string;
  pid : int option; [@json.null]
  headed : bool;
  learning : Yojson.Safe.t option;
  key_present : bool;
}
(** [models] is [T|null]: the service's models section, which every service the Door
    starts has, and [null] only in a dispatch that was given no models service. [version]
    is the library version. [pid] is the managed Chrome's process id while it is running,
    and [null] while a generation is being relaunched. [headed] is false only when the
    service was started headless. [key_present] is whether a model key is configured; the
    key itself is never a field (daily-smli). *)

val status_result_of_yojson : Yojson.Safe.t -> (status_result, string) result
val yojson_of_status_result : status_result -> Yojson.Safe.t

type list_result = { tabs : tab_listing list }

type download_info = {
  id : string;
  suggested_name : string;
  mime : string;
  state : string;
  received_bytes : int;
  total_bytes : int;
  path : string option; [@json.null]
}

type downloads_result = { downloads : download_info list }

val downloads_result_of_yojson : Yojson.Safe.t -> (downloads_result, string) result
val yojson_of_downloads_result : downloads_result -> Yojson.Safe.t
val list_result_of_yojson : Yojson.Safe.t -> (list_result, string) result
val yojson_of_list_result : list_result -> Yojson.Safe.t

type closed_result = { closed : bool }

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

type net_entry = {
  id : string;
  method_ : string;
  url : string;
  status : int option;
  type_ : string;
  mime : string option;
  size : int option;
  duration_ms : int option;
  from_cache : bool;
  error : string option;
}
(** hard-xg6y: one request of a tab's ring. [status], [mime], [size] and [duration_ms] are
    [T|null] (a request still in flight or one that failed has no response); [error] is
    [key?] and carries Chrome's error text for a failed load. Everything here is page data
    for the handle holder and never reaches a log line. *)

type net_result = { requests : net_entry list }

type net_body_result = {
  id : string;
  body : string;
  base64 : bool;
  bytes : int;
  truncated : bool;
}
(** hard-ovbx: [body] is text, or base64 when [base64] is true (Chrome's own choice for
    binary content). At most 1 MiB of it is returned: [bytes] is how much was returned and
    [truncated] says the body was longer. *)

type net_request_result = {
  id : string;
  method_ : string;
  url : string;
  headers : Yojson.Safe.t;
  post_data : string option;
  base64 : bool;
  truncated : bool;
}
(** hard-vq5s: the request's headers as an object, and its post data ([key?]) bounded to 1
    MiB — [truncated] when it was longer, [base64] when Chrome gave it as base64. *)

type cookie = {
  name : string;
  value : string;
  domain : string;
  path : string;
  expires : float option;
  http_only : bool;
  secure : bool;
  same_site : string option;
}
(** hard-ufb7: [expires] is [T|null], null for a session cookie; [same_site] is [T|null].
*)

type cookies_result = { cookies : cookie list }

type storage_result = {
  origin : string;
  area : Storage_area.t;
  items : Yojson.Safe.t;
  truncated : bool;
}
(** hard-ufb7: [items] is an object of key to value, in the storage's own order. *)

val yojson_of_net_result : net_result -> Yojson.Safe.t
val yojson_of_net_body_result : net_body_result -> Yojson.Safe.t
val yojson_of_net_request_result : net_request_result -> Yojson.Safe.t
val yojson_of_cookies_result : cookies_result -> Yojson.Safe.t
val yojson_of_storage_result : storage_result -> Yojson.Safe.t

type playbook_test_result = {
  script : string;
  value : Yojson.Safe.t;
  records : int;
  bytes : int;
  elapsed_ms : int;
  truncated : bool;
}
(** extr-mp5z: the output of one script after it was validated against its [returns].
    [bytes] is the size of the whole result; over 1 MiB [value] is its first five records
    and [truncated] is true. *)

type script_syntax = { script : string; ok : bool; error : string option }
type playbook_check_result = { playbook : string; scripts : script_syntax list }

val playbook_test_result_of_yojson :
  Yojson.Safe.t -> (playbook_test_result, string) result

val yojson_of_playbook_test_result : playbook_test_result -> Yojson.Safe.t
val yojson_of_playbook_check_result : playbook_check_result -> Yojson.Safe.t

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

(* fly-9e0f fly-9363: bounded reference-like state, never validated script records. *)
type operator_state = Yojson.Safe.t

type drive_result = {
  status : Drive_status.t;
  steps : step list;
  operator_state : operator_state option;
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

type playbook_choice = {
  source : string;
  key : string option; [@json.null]
  probabilities : Yojson.Safe.t;
  confidence : float option; [@json.null]
  usage : run_usage option; [@json.null]
  note : string option; [@json.null]
}

val yojson_of_playbook_choice : playbook_choice -> Yojson.Safe.t
val playbook_choice_of_yojson : Yojson.Safe.t -> (playbook_choice, string) result

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

type run_script = {
  script : string;
  url : string;
  records : int;
  bytes : int;
  elapsed_ms : int;
  error : string option;
}
(** extr-8o1h extr-p152: one script call of a procedure — the page's URL, the records it
    produced, its result's size and its time; [error] is [key?], the reason a call was
    rejected. *)

val run_script_of_yojson : Yojson.Safe.t -> (run_script, string) result
val yojson_of_run_script : run_script -> Yojson.Safe.t

type run_procedure = {
  revision : string option;
  slug : string;
  site : string;
  planned : bool;
  attempts : int;
  choice : run_choice;
  drives : run_drive list;
  scripts : run_script list;
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

type planner_step = {
  non_repeatable : bool;
  n : int;
  command : string;
  target : trace_target option;
  text : string option;
  after : after;
  elapsed_ms : int;
  error : string option;
}

val planner_step_of_yojson : Yojson.Safe.t -> (planner_step, string) result
val yojson_of_planner_step : planner_step -> Yojson.Safe.t

type planner_turn = {
  n : int;
  trigger : string;
  answer : string;
  steps : planner_step list;
  reason : string option;
  usage : run_usage option; [@json.null]
}
(** run-xqh8 run-klp9 run-obtt: one planner turn. [trigger] is ["blocked"], ["failed"] or
    ["arguments"] — the point JEV stopped; [answer] is ["procedure"], ["handoff"] or
    ["fail"], and [reason] is the sentence a handoff or a failure carries. L32's planner
    is Luna, so [usage] is what its turn cost: the tokens the endpoint reported, summed
    when the reply had to be asked twice, with [cost] zero because the chat route Leash
    speaks reports tokens rather than the provider's own cost (run-obtt). *)

val planner_turn_of_yojson : Yojson.Safe.t -> (planner_turn, string) result
val yojson_of_planner_turn : planner_turn -> Yojson.Safe.t

type run_result = {
  unattended : Yojson.Safe.t list;
  detail : Yojson.Safe.t option;
  playbook_choices : playbook_choice list;
  status : Run_status.t;
  answer : string option; [@json.default None]
  site : string option; [@json.null]
  procedures : run_procedure list;
  mission_expectations : run_expectation list;
  planner_turns : planner_turn list;
  proposals : string list;
  installed : string list;
  collected : int;
  data : Yojson.Safe.t;
  model_calls : int;
  model_cost : float option;
  operator_steps : step list;
  operator_state : operator_state option;
  output_kinds : string list;
  final : snapshot;
  reason : string option;
  trace_path : string option;
}
(** run-9ypy run-m0r8: the whole run. [site] is the playbook that served the mission,
    [T|null] when the run never chose one; [procedures] is the trace, oldest first;
    [mission_expectations] is how the mission's own expectations — the caller's, or the
    ones the planner attached on its first turn — came out at the DONE guard (empty when
    the mission carried none); [planner_turns] is every planner turn with its cost;
    [proposals] lists the proposal files a planner-written procedure was written to,
    oldest first, which the operator merges with `leash playbook accept` and nothing else
    does; [collected] is how many records the run's script steps produced (extr-8o1h);
    [final] is the last snapshot the run observed — its [dialog] is what ended an [error]
    (run-klp9); [reason] is [key?] and names why the run stopped. *)

val run_result_of_yojson : Yojson.Safe.t -> (run_result, string) result
val yojson_of_run_result : run_result -> Yojson.Safe.t

module Trace = Trace

type drive_trace = Trace.t

val drive_trace_of_yojson : Yojson.Safe.t -> (drive_trace, string) result
val yojson_of_drive_trace : drive_trace -> Yojson.Safe.t

type error = {
  code : Error_code.t;
  message : string;
  hint : string;
  detail : Yojson.Safe.t option;
}
(** What a failed reply carries: a closed code, one sentence, the code's one-line hint,
    and optional structured context ([key?]: omitted when there is none). The CLI prints
    the same object for a client-side failure (daily-azxe). *)

val error_of_yojson : Yojson.Safe.t -> (error, string) result
val yojson_of_error : error -> Yojson.Safe.t

val make_error : ?detail:Yojson.Safe.t -> Error_code.t -> message:string -> error
(** Build an error. [hint] is {!Error_code.hint} of the code, so a constructed error
    cannot carry a different hint. *)

val error_help : string
(** Same text as {!Error_code.error_help}. *)

val stale_snapshot : Snapshot_id.t option -> error
(** daily-6pde daily-9ggi: the one stale-snapshot message and hint, with the current id in
    [detail.snapshot], or [null] when no snapshot is current. *)

val tab_gone : Disposition.t -> error
(** own-teh1 hand-s4cq: the one [tab-gone] error, carrying the disposition that closed the
    tab in [detail.disposition] — [closed_by_handle], [closed_by_idle],
    [closed_externally], or [browser_lost]. The hint is [open a new tab with `leash new`].
    Every path that reports a closed tab says it this way: a tombstone, a dispatch this
    tab's death settled (tab-0ohq), and the browser lookup that probe makes. *)

type reply =
  | Success of Yojson.Safe.t
  | Failure of error
      (** One of the two wire shapes; the result is raw JSON because a client that does
          not know the command's result type still prints it. *)

val encode_reply : reply -> Yojson.Safe.t
val decode_reply : Yojson.Safe.t -> (reply, string) result

type command =
  | New of new_args
  | List_tabs
  | Take of take_args
  | Close of tab_args
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
  | Drive of run_args
  | Downloads of tab_args
  | Net of net_args
  | Net_body of net_entry_args
  | Net_request of net_entry_args
  | Upload of upload_args
  | Hover of hover_args
  | Check of click_args
  | Uncheck of click_args
  | Cookies of tab_args
  | Storage of storage_args
  | Playbook_test of playbook_test_args
  | Playbook_check of playbook_check_args
      (** The decoded command: one constructor per row of [docs/protocol.md]'s command
          tables, carrying that command's derived argument record. *)

val command_name : command -> string
val args_to_json : command -> Yojson.Safe.t

val command_of_args : cmd:string -> Yojson.Safe.t -> (command, string) result
(** The command table: the wire name, the derived argument decode, and the derived
    argument encode. [Status] takes an empty object and nothing else. *)

type request = { command : command }

val version : int
val encode_request : request -> Yojson.Safe.t

val decode_request : Yojson.Safe.t -> (request, string) result
(** The envelope: ["v"] must be {!version}, ["cmd"] must be one of the commands above, and
    ["args"] must decode into that command's record. There is no caller field. An unknown
    envelope field or argument is refused by name. hand-scaz hand-w85z. *)

type planner_action = command
(** map-7xrq map-3qag: the existing protocol envelope, restricted to planner actions. *)

val planner_action_of_yojson : Yojson.Safe.t -> (planner_action, string) result
val yojson_of_planner_action : planner_action -> Yojson.Safe.t

val check_consent_click : snapshot -> index:int -> (unit, string) result
(** map-op11: refuse all-consent buttons when a decline alternative is offered. *)

val check_planner_action : snapshot -> planner_action -> (unit, string) result
