(** The version-one control protocol: the wire contract of [docs/protocol.md] as types.

    A closed set of wire strings is a variant whose constructors carry their wire name as
    [@json.name], so the type is the schema and the codec follows from it. A field that
    [docs/protocol.md] shows as [T|null] is an option with [@json.null], which keeps the
    key on the wire as [null]; a field it shows as [key?] is a plain option, which is
    omitted when [None]. A value whose shape belongs to the page or to the caller — an
    [eval] argument or result, an error's [detail], the [drive] probabilities — is a raw
    [Yojson.Safe.t] field, which the deriver passes through unchanged.

    The envelope does not match the deriver's variant encoding — a request is a ["cmd"]
    name with an ["args"] object, and a reply is [{ok, result}] or [{ok, error}] — so the
    envelope is dispatched here by hand. Every per-command argument record and every
    result record is a plain type with a derived codec. *)

let expected what json =
  Printf.sprintf "expected %s, got %s" what (Yojson.Safe.to_string json)

let with_path path = function
  | Ok value -> Ok value
  | Error message -> Error (path ^ ": " ^ message)

(** A tab handle, opaque to everyone but the registry. *)
module Handle = struct
  type t = string

  let of_string value =
    if String.trim value <> "" then Ok value else Error "must not be empty"

  let to_string t = t

  let t_of_yojson = function
    | `String value -> of_string value
    | json -> Error (expected "a tab handle string" json)

  let yojson_of_t t = `String t
end

(** A snapshot id, opaque to everyone but the tab registry. *)
module Snapshot_id = struct
  type t = string

  let of_string value =
    if String.trim value <> "" then Ok value else Error "must not be empty"

  let to_string t = t

  let t_of_yojson = function
    | `String value -> of_string value
    | json -> Error (expected "a snapshot id string" json)

  let yojson_of_t t = `String t
end

(** The requester: ["dsh:<session>"] for an agent, ["human"], or whatever an operator
    chooses. Required on every request. *)
module Owner = struct
  type t = string

  let of_string value =
    if String.trim value <> "" then Ok value else Error "must not be empty"

  let to_string t = t

  let t_of_yojson = function
    | `String value -> of_string value
    | json -> Error (expected "an owner string" json)

  let yojson_of_t t = `String t
end

(* ---------- Closed sets ---------- *)

(** [wire_string] and [wire_value] read the string form of a closed set out of its derived
    codec, whose constructor tags are the wire strings, so the two cannot drift. *)
let wire_string yojson_of_t value =
  match yojson_of_t value with
  | `String text -> text
  | _ -> invalid_arg "a closed set encoded to something that is not a wire string"

let wire_value t_of_yojson text = t_of_yojson (`String text)

(** Every constructor carries the wire string of [docs/protocol.md] as [@json.name]: the
    deriver otherwise speaks the constructor name verbatim, which no wire string here
    matches. *)

type origin = Agent [@json.name "agent"] | Human [@json.name "human"]
[@@deriving yojson]

module Origin = struct
  type t = origin

  let of_string = wire_value origin_of_yojson
  let to_string = wire_string yojson_of_origin
  let t_of_yojson = origin_of_yojson
  let yojson_of_t = yojson_of_origin
end

type state =
  | Unowned [@json.name "unowned"]
  | Owned [@json.name "owned"]
  | With_human [@json.name "with_human"]
[@@deriving yojson]

module State = struct
  type t = state

  let of_string = wire_value state_of_yojson
  let to_string = wire_string yojson_of_state
  let t_of_yojson = state_of_yojson
  let yojson_of_t = yojson_of_state
end

type stage = Release [@json.name "release"] | Close [@json.name "close"]
[@@deriving yojson]

module Stage = struct
  type t = stage

  let of_string = wire_value stage_of_yojson
  let to_string = wire_string yojson_of_stage
  let t_of_yojson = stage_of_yojson
  let yojson_of_t = yojson_of_stage
end

type dialog_kind =
  | Alert [@json.name "alert"]
  | Confirm [@json.name "confirm"]
  | Prompt [@json.name "prompt"]
  | Beforeunload [@json.name "beforeunload"]
[@@deriving yojson]

module Dialog_kind = struct
  type t = dialog_kind

  let of_string = wire_value dialog_kind_of_yojson
  let to_string = wire_string yojson_of_dialog_kind
  let t_of_yojson = dialog_kind_of_yojson
  let yojson_of_t = yojson_of_dialog_kind
end

type row_state =
  | Checked [@json.name "checked"]
  | Unchecked [@json.name "unchecked"]
  | Mixed [@json.name "mixed"]
  | Selected [@json.name "selected"]
  | Expanded [@json.name "expanded"]
  | Collapsed [@json.name "collapsed"]
  | Disabled [@json.name "disabled"]
  | Required [@json.name "required"]
  | Readonly [@json.name "readonly"]
[@@deriving yojson]

module Row_state = struct
  type t = row_state

  let of_string = wire_value row_state_of_yojson
  let to_string = wire_string yojson_of_row_state
  let t_of_yojson = row_state_of_yojson
  let yojson_of_t = yojson_of_row_state
end

type debug_kind =
  | Console [@json.name "console"]
  | Exception [@json.name "exception"]
  | Request_failed [@json.name "request-failed"]
[@@deriving yojson]

module Debug_kind = struct
  type t = debug_kind

  let of_string = wire_value debug_kind_of_yojson
  let to_string = wire_string yojson_of_debug_kind
  let t_of_yojson = debug_kind_of_yojson
  let yojson_of_t = yojson_of_debug_kind
end

type operation =
  | Click [@json.name "click"]
  | Type_text [@json.name "type_text"]
  | Select [@json.name "select"]
  | Scroll_up [@json.name "scroll_up"]
  | Scroll_down [@json.name "scroll_down"]
  | Wait [@json.name "wait"]
  | Done [@json.name "done"]
  | Blocked [@json.name "blocked"]
[@@deriving yojson]

module Operation = struct
  type t = operation

  let of_string = wire_value operation_of_yojson
  let to_string = wire_string yojson_of_operation
  let t_of_yojson = operation_of_yojson
  let yojson_of_t = yojson_of_operation
end

type direction = Up [@json.name "up"] | Down [@json.name "down"] [@@deriving yojson]

module Direction = struct
  type t = direction

  let of_string = wire_value direction_of_yojson
  let to_string = wire_string yojson_of_direction
  let t_of_yojson = direction_of_yojson
  let yojson_of_t = yojson_of_direction
end

(** hard-ufb7: which of a page's two web storages [storage] reads. *)
type storage_area =
  | Local_storage [@json.name "local"]
  | Session_storage [@json.name "session"]
[@@deriving yojson]

module Storage_area = struct
  type t = storage_area

  let of_string = wire_value storage_area_of_yojson
  let to_string = wire_string yojson_of_storage_area
  let t_of_yojson = storage_area_of_yojson
  let yojson_of_t = yojson_of_storage_area
end

type answer = Accept [@json.name "accept"] | Dismiss [@json.name "dismiss"]
[@@deriving yojson]

module Answer = struct
  type t = answer

  let of_string = wire_value answer_of_yojson
  let to_string = wire_string yojson_of_answer
  let t_of_yojson = answer_of_yojson
  let yojson_of_t = yojson_of_answer
end

(** The wire's ["error"] is [Failed] here: a constructor named [Error] would shadow
    [Result.Error] in the by-hand dispatch below. *)
type drive_status =
  | Done [@json.name "done"]
  | Blocked [@json.name "blocked"]
  | Step_cap [@json.name "step-cap"]
  | Deadline [@json.name "deadline"]
  | Failed [@json.name "error"]
[@@deriving yojson]

module Drive_status = struct
  type t = drive_status

  let of_string = wire_value drive_status_of_yojson
  let to_string = wire_string yojson_of_drive_status
  let t_of_yojson = drive_status_of_yojson
  let yojson_of_t = yojson_of_drive_status
end

(** L31 run-9ypy: how a run ended. [Run_done] is a DONE the guard verified, [Run_blocked]
    the loop stopping with nothing that can progress, [Run_failed] a procedure that failed
    its expectations twice, [Run_handoff] a planner turn asking for the human, [Run_limit]
    the procedure cap, [Run_deadline] the run's own deadline, and [Run_error] a page state
    the run cannot work in (a dialog) or a model or browser failure. The constructors
    carry a [Run_] prefix because the wire strings are the operator's and a [Done] here
    would collide with the drive's. *)
type run_status =
  | Run_done [@json.name "done"]
  | Run_blocked [@json.name "blocked"]
  | Run_failed [@json.name "failed"]
  | Run_handoff [@json.name "handoff"]
  | Run_limit [@json.name "limit"]
  | Run_deadline [@json.name "deadline"]
  | Run_error [@json.name "error"]
[@@deriving yojson]

module Run_status = struct
  type t = run_status

  let of_string = wire_value run_status_of_yojson
  let to_string = wire_string yojson_of_run_status
  let t_of_yojson = run_status_of_yojson
  let yojson_of_t = yojson_of_run_status
end

type chrome_phase =
  | Running [@json.name "running"]
  | Restarting [@json.name "restarting"]
[@@deriving yojson]

module Chrome_phase = struct
  type t = chrome_phase

  let of_string = wire_value chrome_phase_of_yojson
  let to_string = wire_string yojson_of_chrome_phase
  let t_of_yojson = chrome_phase_of_yojson
  let yojson_of_t = yojson_of_chrome_phase
end

(** The wire's dispositions (ADR-0005): why a tombstone says a tab is gone.
    [Closed_by_owner] and [Closed_by_ttl] are the two Leash issues itself, when its owner
    closes the tab or the second expiry stage does; [Closed_externally] is anything else
    Chrome reports; [Browser_lost] is a generation that ended. *)
type disposition =
  | Closed_by_owner [@json.name "closed_by_owner"]
  | Closed_by_ttl [@json.name "closed_by_ttl"]
  | Closed_externally [@json.name "closed_externally"]
  | Browser_lost [@json.name "browser_lost"]
[@@deriving yojson]

module Disposition = struct
  type t = disposition

  let of_string = wire_value disposition_of_yojson
  let to_string = wire_string yojson_of_disposition
  let t_of_yojson = disposition_of_yojson
  let yojson_of_t = yojson_of_disposition
end

type error_code =
  | Invalid_request [@json.name "invalid-request"]
  | Not_owner [@json.name "not-owner"]
  | Already_owned [@json.name "already-owned"]
  | With_human [@json.name "with-human"]
  | Tab_gone [@json.name "tab-gone"]
  | Unknown_tab [@json.name "unknown-tab"]
  | Stale_snapshot [@json.name "stale-snapshot"]
  | No_such_row [@json.name "no-such-row"]
  | Body_unavailable [@json.name "body-unavailable"]
  | Unknown_request [@json.name "unknown-request"]
  | Row_not_actionable [@json.name "row-not-actionable"]
  | Dialog_open [@json.name "dialog-open"]
  | No_dialog [@json.name "no-dialog"]
  | No_handoff [@json.name "no-handoff"]
  | Url_refused [@json.name "url-refused"]
  | Tab_cap [@json.name "tab-cap"]
  | Timeout [@json.name "timeout"]
  | Browser_unavailable [@json.name "browser-unavailable"]
  | Model_unavailable [@json.name "model-unavailable"]
  | Too_large [@json.name "too-large"]
  | Script_failed [@json.name "script-failed"]
  | Script_invalid [@json.name "script-invalid"]
  | Internal [@json.name "internal"]
[@@deriving yojson]

module Error_code = struct
  type t = error_code

  let of_string = wire_value error_code_of_yojson
  let to_string = wire_string yojson_of_error_code
  let t_of_yojson = error_code_of_yojson
  let yojson_of_t = yojson_of_error_code
end

(* ---------- Tab, snapshot and drive shapes ---------- *)

type expires = { stage : Stage.t; in_s : int } [@@deriving yojson]

type dialog = {
  kind : Dialog_kind.t;
  message : string;
  default_prompt : string option; [@json.null]
}
[@@deriving yojson]

type tab_info = {
  tab : Handle.t;
  url : string;
  title : string;
  origin : Origin.t;
  state : State.t;
  owner : Owner.t option; [@json.null]
  generation : int;
  dialog : dialog option; [@json.null]
  expires : expires option; [@json.null]
  reason : string option;
      (** Why the human holds this tab, the reason of the live handoff (hand-r4t1); a
          [key?] field, so it is absent from every tab nobody is waiting on. *)
}
[@@deriving yojson]

type row_option = {
  index : int;
  label : string;
  value : string;
  selected : bool;
  disabled : bool;
}
[@@deriving yojson]

type row = {
  index : int;
  role : string;
  name : string;
  value : string option;
  state : Row_state.t list option;
  options : row_option list option;
}
[@@deriving yojson]

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
  dialog : dialog option; [@json.null]
}
[@@deriving yojson]

type action_result = {
  tab : Handle.t;
  url : string;
  title : string;
  snapshot : Snapshot_id.t option; [@json.null]
  dialog : dialog option; [@json.null]
  popups : tab_info list;
}
[@@deriving yojson]

type debug_entry = {
  at : string;
  kind : Debug_kind.t;
  level : string option;
  text : string;
}
[@@deriving yojson]

type after = { url : string; title : string } [@@deriving yojson]
type probabilities = { op : Yojson.Safe.t; target : Yojson.Safe.t } [@@deriving yojson]

type step = {
  n : int;
  snapshot : Snapshot_id.t;
  operation : Operation.t;
  index : int option; [@json.null]
  probabilities : probabilities;
  text : string option;
  after : after;
  elapsed_ms : int;
}
[@@deriving yojson]

(* ---------- Per-command arguments ---------- *)

type new_args = { url : string option } [@@deriving yojson]
type list_args = { all : bool [@json.default false] } [@@deriving yojson]
type tab_args = { tab : Handle.t } [@@deriving yojson]

type force_args = { tab : Handle.t; force : bool option } [@@deriving yojson]
(** The arguments of the two commands a caller may force (own-0pnk): [force] is honoured
    only for [release] and [close], and is a [key?] field, so a request that does not ask
    for it carries no [force] key at all. *)

type snap_args = {
  tab : Handle.t;
  match_ : string option; [@json.key "match"]
  limit : int option;
  offset : int option;
}
[@@deriving yojson]

type text_args = { tab : Handle.t; index : int option; max_chars : int option }
[@@deriving yojson]

type shot_args = { tab : Handle.t; path : string; full_page : bool option }
[@@deriving yojson]

type debug_args = { tab : Handle.t; limit : int option; clear : bool option }
[@@deriving yojson]

(* hard-b20d: [index] and [snapshot] go together — the row's element is the function's second
   parameter. *)
type eval_args = {
  tab : Handle.t;
  expression : string;
  argument : Yojson.Safe.t option;
  index : int option;
  snapshot : Snapshot_id.t option;
}
[@@deriving yojson]

type nav_args = { tab : Handle.t; url : string } [@@deriving yojson]

type click_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int }
[@@deriving yojson]

type fill_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int; text : string }
[@@deriving yojson]

type press_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int option;
  key : string;
}
[@@deriving yojson]

type select_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int; option : int }
[@@deriving yojson]

type scroll_args = { tab : Handle.t; direction : Direction.t; index : int option }
[@@deriving yojson]

type wait_until = {
  url_prefix : string option;
  text : string option;
  index_gone : int option;
  dialog : bool option;
  changed_since : Snapshot_id.t option;
}
[@@deriving yojson]

type wait_args = { tab : Handle.t; until : wait_until; timeout_ms : int option }
[@@deriving yojson]

type dialog_args = { tab : Handle.t; answer : Answer.t; text : string option }
[@@deriving yojson]

type handoff_args = { tab : Handle.t; reason : string; timeout_s : int option }
[@@deriving yojson]

(* hard-xg6y: the filter of a request listing; [match_] is a case-insensitive substring of
   the URL, [type_] a resource type (xhr, fetch, document, ...). *)
type net_args = {
  tab : Handle.t;
  match_ : string option; [@json.key "match"]
  limit : int option;
  type_ : string option; [@json.key "type"]
}
[@@deriving yojson]

(* hard-ovbx hard-vq5s: one request of the tab's ring, by the id `net` listed. *)
type net_entry_args = { tab : Handle.t; id : string } [@@deriving yojson]

type upload_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  paths : string list;
}
[@@deriving yojson]

type hover_args = { tab : Handle.t; snapshot : Snapshot_id.t; index : int }
[@@deriving yojson]

type storage_args = { tab : Handle.t; area : Storage_area.t } [@@deriving yojson]

(* extr-mp5z: run one script of an installed playbook on the tab's page. [script] is
   [<playbook>/<script>]; [args] is an object of strings, [key?]. Nothing on the wire
   carries script text: the service looks the script up in the playbook directory. *)
type playbook_test_args = { tab : Handle.t; script : string; args : Yojson.Safe.t option }
[@@deriving yojson]

(* extr-lslp: check an installed playbook's scripts for syntax in a blank page. *)
type playbook_check_args = { playbook : string } [@@deriving yojson]

type drive_args = {
  tab : Handle.t;
  goal : string;
  max_steps : int option;
  deadline_s : int option;
  dry_run : bool option;
}
[@@deriving yojson]

(* L31 run-9ypy: one mission over the installed playbooks. [expect] is the mission's own
   expectations, which L32's planner attaches on its first turn and which a caller may
   state directly; they are what DONE is verified against, independently of the last
   procedure (run-4j1v, the L30 guard). A [key?] list: omitted when the mission carries
   none. *)
type run_args = {
  tab : Handle.t option;
  mission : string;
  max_procedures : int option;
  deadline_s : int option;
  dry_run : bool option;
  expect : string list option;
  out : string option;
}
[@@deriving yojson]

(* run-3vat run-xda7: the bounded planner-led discovery request. *)
type discover_args = {
  site : string;
  goal : string option;
  max_turns : int option;
  max_steps : int option;
  deadline_s : int option;
  max_cost : float option;
}
[@@deriving yojson]

(* ---------- Per-command results ---------- *)

type tab_counts = { open_ : int; [@json.key "open"] cap : int } [@@deriving yojson]

(* L19 drive-e7oi drive-yqxg: what [status] says about the model configuration. The key is
   not a field: a Redact.t renders as "<redacted>" on every path, so nothing here can
   print it, and the section is the configuration only — no probe, nothing at boot. *)
type models_status = {
  configured : bool;
  jev_model : string;
  text_model : string;
  systemone_endpoint : string;
  chat_base_url : string;
}
[@@deriving yojson]

type status_result = {
  generation : int;
  tabs : tab_counts;
  chrome : Chrome_phase.t;
  uptime_s : float;
  models : models_status option; [@json.null]
}
[@@deriving yojson]

type list_result = { tabs : tab_info list } [@@deriving yojson]

(* run-ykq4: a download belongs to the tab whose main frame began it. *)
type download_info = {
  id : string;
  suggested_name : string;
  mime : string;
  state : string;
  path : string option; [@json.null]
}
[@@deriving yojson]

type downloads_result = { downloads : download_info list } [@@deriving yojson]
type released_result = { released : bool } [@@deriving yojson]
type closed_result = { closed : bool } [@@deriving yojson]
type resumed_result = { resumed : bool } [@@deriving yojson]

type text_result = { url : string; title : string; text : string; truncated : bool }
[@@deriving yojson]

type shot_result = { path : string; bytes : int } [@@deriving yojson]
type debug_result = { entries : debug_entry list } [@@deriving yojson]
type eval_result = { value : Yojson.Safe.t } [@@deriving yojson]

(* hard-xg6y: one request of a tab's ring. Everything here is page data returned to the
   owner; none of it is ever a log line. *)
type net_entry = {
  id : string;
  method_ : string; [@json.key "method"]
  url : string;
  status : int option; [@json.null]
  type_ : string; [@json.key "type"]
  mime : string option; [@json.null]
  size : int option; [@json.null]
  duration_ms : int option; [@json.null]
  from_cache : bool;
  error : string option;
}
[@@deriving yojson]

type net_result = { requests : net_entry list } [@@deriving yojson]

type net_body_result = {
  id : string;
  body : string;
  base64 : bool;
  bytes : int;
  truncated : bool;
}
[@@deriving yojson]

type net_request_result = {
  id : string;
  method_ : string; [@json.key "method"]
  url : string;
  headers : Yojson.Safe.t;
  post_data : string option;
  base64 : bool;
  truncated : bool;
}
[@@deriving yojson]

type cookie = {
  name : string;
  value : string;
  domain : string;
  path : string;
  expires : float option; [@json.null]
  http_only : bool;
  secure : bool;
  same_site : string option; [@json.null]
}
[@@deriving yojson]

type cookies_result = { cookies : cookie list } [@@deriving yojson]

type storage_result = {
  origin : string;
  area : Storage_area.t;
  items : Yojson.Safe.t;
  truncated : bool;
}
[@@deriving yojson]

(* extr-mp5z: the validated output of one script, with its size and time. A result over
   1 MiB is not echoed whole: [value] is then its first five records and [truncated] says
   so. *)
type playbook_test_result = {
  script : string;
  value : Yojson.Safe.t;
  records : int;
  bytes : int;
  elapsed_ms : int;
  truncated : bool;
}
[@@deriving yojson]

(* extr-lslp: one script's syntax verdict. *)
type script_syntax = { script : string; ok : bool; error : string option }
[@@deriving yojson]

type playbook_check_result = { playbook : string; scripts : script_syntax list }
[@@deriving yojson]

(* hand-rg9h: [warnings] is [key?] — the human-facing steps a handoff ran and could not
   complete, omitted when there was nothing to report. *)
type handoff_result = {
  resumed : bool;
  url : string;
  title : string;
  warnings : string list option;
}
[@@deriving yojson]

type drive_result = {
  status : Drive_status.t;
  steps : step list;
  final : snapshot;
  reason : string option;
}
[@@deriving yojson]

(* ---------- L31: the run's result and trace ---------- *)

(* run-xqh8: the provider's own accounting for one upper-level call, so a run's trace
   carries what the mission cost as well as what it did. *)
type run_usage = { input_tokens : int; output_tokens : int; cost : float }
[@@deriving yojson]

(* run-xqh8 run-qq3o: the upper level's answer with the distribution behind it. [key] is
   the criterion the model chose — a playbook's site, a procedure's slug, [DONE] or
   [BLOCKED] — and [probabilities] the model's own object, as the step trace carries one. *)
type run_choice = {
  key : string;
  probabilities : Yojson.Safe.t;
  confidence : float;
  usage : run_usage option; [@json.null]
}
[@@deriving yojson]

(* run-xqh8: one expectation and how it was verified: the checker the loader resolved, and
   the JEV score when no checker applied. *)
type run_expectation = {
  sentence : string;
  checker : string;
  passed : bool;
  score : float option; [@json.null]
}
[@@deriving yojson]

(* run-d82w run-xqh8: one operator step — a single [drive] call — with the goal it was
   given and the drive's own result, so the run's trace holds the operator level's steps
   without renumbering them. *)
type run_drive = {
  goal : string;
  status : Drive_status.t;
  steps : step list;
  reason : string option;
}
[@@deriving yojson]

(* run-xqh8: one procedure the run executed: the choice that picked it, the drive calls its
   steps became, the expectations it was verified against, and how it ended — [verified],
   [failed] (its second verification failed), [skipped] (an optional [use] whose first step
   ended blocked) or [planned] (a dry run chose it and executed nothing). [planned] is true
   when a planner turn wrote it (L32). [attempts] counts the verification rounds, 2 when the
   retry-once rule replayed the procedure. *)
(* extr-8o1h extr-p152: one script call a procedure made — the page it ran on, how many
   records it produced, the size of its result and how long it took; [error] says why a
   call was rejected (it threw, its result did not fit its shape, or it was too large). *)
type run_script = {
  script : string;
  url : string;
  records : int;
  bytes : int;
  elapsed_ms : int;
  error : string option;
}
[@@deriving yojson]

type run_procedure = {
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
[@@deriving yojson]

(* run-xqh8 run-klp9 run-obtt: one planner turn and what it answered — [procedure],
   [handoff] or [fail] — with the trigger it was taken at and what it cost. L32's planner
   is Luna, so [usage] is the tokens and provider-reported cost summed across both
   calls if a correction was needed; absent provider cost contributes zero. *)
type planner_turn = {
  n : int;
  trigger : string;
  answer : string;
  reason : string option;
  usage : run_usage option; [@json.null]
}
[@@deriving yojson]

(* run-9ypy run-m0r8: the whole run. [procedures] is the trace, oldest first;
   [proposals] are the files a planner-written procedure was written to, oldest first —
   the run never merges one; [final] is the last snapshot the run observed, whose [dialog]
   is what ended an [error]; [reason] names why the run stopped. *)
type run_result = {
  status : Run_status.t;
  site : string option; [@json.null]
  procedures : run_procedure list;
  mission_expectations : run_expectation list;
  planner_turns : planner_turn list;
  proposals : string list;
  collected : int;
  data : Yojson.Safe.t;
  model_calls : int;
  model_cost : float;
  operator_steps : step list;
  final : snapshot;
  reason : string option;
}
[@@deriving yojson]

(* ---------- Errors and replies ---------- *)

type error = { code : Error_code.t; message : string; detail : Yojson.Safe.t option }
[@@deriving yojson]

(* own-teh1 tab-0ohq: the one [tab-gone], whether it comes from a tombstone, from a
   dispatch the target's death settled (tab-0ohq), or from the browser lookup that probe
   makes. The disposition in [detail] is what tells a client why the tab is gone. *)
let tab_gone disposition : error =
  {
    code = Tab_gone;
    message = "the tab is gone";
    detail = Some (`Assoc [ ("disposition", yojson_of_disposition disposition) ]);
  }

(** One of the two wire shapes. The result stays raw JSON because the CLI prints it
    without knowing the command's result type; the per-command result records above are
    what the service encodes into it. *)
type reply = Success of Yojson.Safe.t | Failure of error

let encode_reply = function
  | Success result -> `Assoc [ ("ok", `Bool true); ("result", result) ]
  | Failure error -> `Assoc [ ("ok", `Bool false); ("error", yojson_of_error error) ]

let object_fields what = function
  | `Assoc fields -> Ok fields
  | json ->
      Error
        (Printf.sprintf "%s: expected an object, got %s" what (Yojson.Safe.to_string json))

let required what key fields =
  match List.assoc_opt key fields with
  | Some value -> Ok value
  | None -> Error (Printf.sprintf "%s: missing field %s" what key)

let reject_unknown what known fields =
  match List.find_opt (fun (key, _) -> not (List.mem key known)) fields with
  | Some (key, _) -> Error (Printf.sprintf "%s: unknown field %s" what key)
  | None -> Ok ()

let present key fields =
  match List.assoc_opt key fields with
  | Some `Null | None -> None
  | Some value -> Some value

let decode_reply json =
  let ( let* ) = Result.bind in
  let* fields = object_fields "reply" json in
  let* () = reject_unknown "reply" [ "ok"; "result"; "error" ] fields in
  let* ok = required "reply" "ok" fields in
  match ok with
  | `Bool true -> (
      match (present "result" fields, present "error" fields) with
      | Some result, None -> Ok (Success result)
      | Some _, Some _ -> Error "reply: a successful reply must not carry an error"
      | None, _ -> Error "result: missing from a successful reply")
  | `Bool false -> (
      match (present "result" fields, present "error" fields) with
      | Some _, _ -> Error "reply: a failed reply must not carry a result"
      | None, Some error ->
          Result.map
            (fun error -> Failure error)
            (with_path "error" (error_of_yojson error))
      | None, None -> Error "error: missing from a failed reply")
  | json ->
      Error
        (Printf.sprintf "reply.ok: expected a boolean, got %s"
           (Yojson.Safe.to_string json))

(* ---------- Commands ---------- *)

type empty_args = unit [@@deriving yojson] [@@yojson.empty_record]
(** [status] takes an empty object and nothing else: the marker is the one way to write
    that shape, and the derived codec refuses a non-empty object or [null]. *)

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
  | Drive of run_args
  | Downloads of tab_args
  | Discover of discover_args
  | Net of net_args
  | Net_body of net_entry_args
  | Net_request of net_entry_args
  | Upload of upload_args
  | Hover of hover_args
  | Cookies of tab_args
  | Storage of storage_args
  | Playbook_test of playbook_test_args
  | Playbook_check of playbook_check_args

let command_name = function
  | New _ -> "new"
  | List_tabs _ -> "list"
  | Claim _ -> "claim"
  | Release _ -> "release"
  | Close _ -> "close"
  | Status -> "status"
  | Snap _ -> "snap"
  | Text _ -> "text"
  | Shot _ -> "shot"
  | Debug _ -> "debug"
  | Eval _ -> "eval"
  | Nav _ -> "nav"
  | Click _ -> "click"
  | Fill _ -> "fill"
  | Press _ -> "press"
  | Select _ -> "select"
  | Scroll _ -> "scroll"
  | Wait _ -> "wait"
  | Dialog _ -> "dialog"
  | Handoff _ -> "handoff"
  | Resume _ -> "resume"
  | Drive _ -> "drive"
  | Downloads _ -> "downloads"
  | Discover _ -> "discover"
  | Net _ -> "net"
  | Net_body _ -> "net_body"
  | Net_request _ -> "net_request"
  | Upload _ -> "upload"
  | Hover _ -> "hover"
  | Cookies _ -> "cookies"
  | Storage _ -> "storage"
  | Playbook_test _ -> "playbook_test"
  | Playbook_check _ -> "playbook_check"

let args_to_json = function
  | New args -> yojson_of_new_args args
  | List_tabs args -> yojson_of_list_args args
  | Claim args -> yojson_of_tab_args args
  | Release args -> yojson_of_force_args args
  | Close args -> yojson_of_force_args args
  | Status -> yojson_of_empty_args ()
  | Snap args -> yojson_of_snap_args args
  | Text args -> yojson_of_text_args args
  | Shot args -> yojson_of_shot_args args
  | Debug args -> yojson_of_debug_args args
  | Eval args -> yojson_of_eval_args args
  | Nav args -> yojson_of_nav_args args
  | Click args -> yojson_of_click_args args
  | Fill args -> yojson_of_fill_args args
  | Press args -> yojson_of_press_args args
  | Select args -> yojson_of_select_args args
  | Scroll args -> yojson_of_scroll_args args
  | Wait args -> yojson_of_wait_args args
  | Dialog args -> yojson_of_dialog_args args
  | Handoff args -> yojson_of_handoff_args args
  | Resume args -> yojson_of_tab_args args
  | Drive args -> yojson_of_run_args args
  | Downloads args -> yojson_of_tab_args args
  | Discover args -> yojson_of_discover_args args
  | Net args -> yojson_of_net_args args
  | Net_body args | Net_request args -> yojson_of_net_entry_args args
  | Upload args -> yojson_of_upload_args args
  | Hover args -> yojson_of_hover_args args
  | Cookies args -> yojson_of_tab_args args
  | Storage args -> yojson_of_storage_args args
  | Playbook_test args -> yojson_of_playbook_test_args args
  | Playbook_check args -> yojson_of_playbook_check_args args

let command_of_args ~cmd args =
  let with_args decoder build = with_path "args" (Result.map build (decoder args)) in
  match cmd with
  | "new" -> with_args new_args_of_yojson (fun args -> New args)
  | "list" -> with_args list_args_of_yojson (fun args -> List_tabs args)
  | "claim" -> with_args tab_args_of_yojson (fun args -> Claim args)
  | "release" -> with_args force_args_of_yojson (fun args -> Release args)
  | "close" -> with_args force_args_of_yojson (fun args -> Close args)
  | "status" -> with_args empty_args_of_yojson (fun () -> Status)
  | "snap" -> with_args snap_args_of_yojson (fun args -> Snap args)
  | "text" -> with_args text_args_of_yojson (fun args -> Text args)
  | "shot" -> with_args shot_args_of_yojson (fun args -> Shot args)
  | "debug" -> with_args debug_args_of_yojson (fun args -> Debug args)
  | "eval" -> with_args eval_args_of_yojson (fun args -> Eval args)
  | "nav" -> with_args nav_args_of_yojson (fun args -> Nav args)
  | "click" -> with_args click_args_of_yojson (fun args -> Click args)
  | "fill" -> with_args fill_args_of_yojson (fun args -> Fill args)
  | "press" -> with_args press_args_of_yojson (fun args -> Press args)
  | "select" -> with_args select_args_of_yojson (fun args -> Select args)
  | "scroll" -> with_args scroll_args_of_yojson (fun args -> Scroll args)
  | "wait" -> with_args wait_args_of_yojson (fun args -> Wait args)
  | "dialog" -> with_args dialog_args_of_yojson (fun args -> Dialog args)
  | "handoff" -> with_args handoff_args_of_yojson (fun args -> Handoff args)
  | "resume" -> with_args tab_args_of_yojson (fun args -> Resume args)
  | "drive" -> with_args run_args_of_yojson (fun args -> Drive args)
  | "downloads" -> with_args tab_args_of_yojson (fun args -> Downloads args)
  | "discover" -> with_args discover_args_of_yojson (fun args -> Discover args)
  | "net" -> with_args net_args_of_yojson (fun args -> Net args)
  | "net_body" -> with_args net_entry_args_of_yojson (fun args -> Net_body args)
  | "net_request" -> with_args net_entry_args_of_yojson (fun args -> Net_request args)
  | "upload" -> with_args upload_args_of_yojson (fun args -> Upload args)
  | "hover" -> with_args hover_args_of_yojson (fun args -> Hover args)
  | "cookies" -> with_args tab_args_of_yojson (fun args -> Cookies args)
  | "storage" -> with_args storage_args_of_yojson (fun args -> Storage args)
  | "playbook_test" ->
      with_args playbook_test_args_of_yojson (fun args -> Playbook_test args)
  | "playbook_check" ->
      with_args playbook_check_args_of_yojson (fun args -> Playbook_check args)
  | other ->
      Error
        (Printf.sprintf "cmd: unknown command %s" (Yojson.Safe.to_string (`String other)))

(* ---------- The request envelope ---------- *)

type request = { owner : Owner.t; command : command }
(** The wire's ["v"] is a protocol constant: [decode_request] refuses anything but
    {!version}, and [encode_request] always writes it. *)

let version = 1

let encode_request request =
  `Assoc
    [
      ("v", `Int version);
      ("owner", Owner.yojson_of_t request.owner);
      ("cmd", `String (command_name request.command));
      ("args", args_to_json request.command);
    ]

let decode_request json =
  let ( let* ) = Result.bind in
  let* fields = object_fields "request" json in
  let* () = reject_unknown "request" [ "v"; "owner"; "cmd"; "args" ] fields in
  let* version_json = required "request" "v" fields in
  let* () =
    if version_json = `Int version then Ok ()
    else
      Error
        (Printf.sprintf "v: expected version %d, got %s" version
           (Yojson.Safe.to_string version_json))
  in
  let* owner_json = required "request" "owner" fields in
  let* owner = with_path "owner" (Owner.t_of_yojson owner_json) in
  let* cmd_json = required "request" "cmd" fields in
  let* cmd =
    match cmd_json with
    | `String cmd -> Ok cmd
    | json ->
        Error
          (Printf.sprintf "cmd: expected a string, got %s" (Yojson.Safe.to_string json))
  in
  let* args = required "request" "args" fields in
  let* command = command_of_args ~cmd args in
  Ok { owner; command }
