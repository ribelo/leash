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

type popup_state =
  | Opening [@json.name "opening"]
  | Blank [@json.name "blank"]
  | Ready [@json.name "ready"]
[@@deriving yojson]

module Popup_state = struct
  type t = popup_state

  let of_string = wire_value popup_state_of_yojson
  let to_string = wire_string yojson_of_popup_state
  let t_of_yojson = popup_state_of_yojson
  let yojson_of_t = yojson_of_popup_state
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
  | Cross_origin [@json.name "cross-origin"]
  | Password [@json.name "password"]
      (** field-8bzc: an [<input type=password>] row; it never carries a value. *)
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
  | Run_planned [@json.name "planned"]
  | Run_blocked [@json.name "blocked"]
  | Run_failed [@json.name "failed"]
  | Run_handoff [@json.name "handoff"]
  | Run_handoff_expired [@json.name "handoff-expired"]
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

(** hand-mb9s hand-0ibq: why a capability stopped naming a live tab. *)
type disposition =
  | Closed_by_handle [@json.name "closed_by_handle"]
  | Closed_by_idle [@json.name "closed_by_idle"]
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
  | Ambiguous [@json.name "ambiguous"]
  | No_match [@json.name "no-match"]
  | Taken [@json.name "taken"]
  | With_human [@json.name "with-human"]
  | Tab_gone [@json.name "tab-gone"]
  | Unknown_tab [@json.name "unknown-tab"]
  | Stale_snapshot [@json.name "stale-snapshot"]
  | No_such_row [@json.name "no-such-row"]
  | Body_unavailable [@json.name "body-unavailable"]
  | Unknown_request [@json.name "unknown-request"]
  | Row_not_actionable [@json.name "row-not-actionable"]
  | State_unchanged [@json.name "state-unchanged"]
  | Dialog_open [@json.name "dialog-open"]
  | No_dialog [@json.name "no-dialog"]
  | No_handoff [@json.name "no-handoff"]
  | Url_refused [@json.name "url-refused"]
  | Tab_cap [@json.name "tab-cap"]
  | Timeout [@json.name "timeout"]
  | Renderer_unresponsive [@json.name "renderer-unresponsive"]
  | Browser_unavailable [@json.name "browser-unavailable"]
  | Model_unavailable [@json.name "model-unavailable"]
  | Model_timeout [@json.name "model-timeout"]
  | Too_large [@json.name "too-large"]
  | Script_failed [@json.name "script-failed"]
  | Script_invalid [@json.name "script-invalid"]
  | Playbook_invalid [@json.name "playbook-invalid"]
  | Internal [@json.name "internal"]
  | Service_unreachable [@json.name "service-unreachable"]
  | Not_installed [@json.name "not-installed"]
  | Service_stopped [@json.name "service-stopped"]
  | Service_restarting [@json.name "service-restarting"]
  | Socket_permission [@json.name "socket-permission"]
  | Permission_denied [@json.name "permission-denied"]
  | Config_invalid [@json.name "config-invalid"]
  | Usage [@json.name "usage"]
  | Cli_parse [@json.name "cli-parse"]
  | Invalid_response [@json.name "invalid-response"]
[@@deriving yojson]

module Error_code = struct
  type t = error_code

  let of_string = wire_value error_code_of_yojson
  let to_string = wire_string yojson_of_error_code
  let t_of_yojson = error_code_of_yojson
  let yojson_of_t = yojson_of_error_code

  (* Exit classes are the ones packages/leash/bin/cli_help.ml documents. An exit
     outside that set makes [leash --help] raise. Configuration is 65, not 78:
     that help text already calls 65 the configuration class. daily-3bwr. *)
  type info = { exit_code : int; meaning : string; hint : string }

  let info exit_code meaning hint = { exit_code; meaning; hint }

  let meta = function
    | Invalid_request ->
        info 64 "malformed JSON, unknown command, or bad arguments"
          "fix the request; `leash <command> --help` names the arguments and one example"
    | Ambiguous ->
        info 66 "take matches several tabs; detail.matches lists them without handles"
          "narrow the URL, title or label selector"
    | No_match ->
        info 66 "take matches no tab"
          "read `leash list` and use a matching URL prefix, title or label"
    | Taken -> info 77 "the tab already has a live handle" "ask the holder for the handle"
    | With_human ->
        info 77 "the tab is handed to the human; commands are refused until resume"
          "the human holds this tab; wait, or return it with `leash resume TAB`"
    | Tab_gone ->
        info 66
          "the handle names a closed tab; detail.disposition is closed_by_handle, \
           closed_by_idle, closed_externally, or browser_lost"
          "open a new tab with `leash new`"
    | Unknown_tab ->
        info 66 "no tab and no tombstone for the handle"
          "that handle is not a tab; open a new tab with `leash new`, or ask the holder \
           for the handle"
    | Stale_snapshot ->
        info 65 "the snapshot id or target row no longer matches the current page"
          "read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; \
           if the row is gone, navigate back or re-find it before acting"
    | No_such_row ->
        info 66 "the index is not in the snapshot"
          "that index is not in the snapshot; `leash snap TAB` and use a listed index"
    | Body_unavailable ->
        info 66 "net body or request has no body to read, or Chrome has evicted it"
          "that body is gone; `leash net TAB` and read a request that still has one"
    | Unknown_request ->
        info 66 "the tab's ring holds no request with that id"
          "that id is not in the tab's ring; `leash net TAB` and use a listed id"
    | Row_not_actionable ->
        info 65
          "the row is not visible, is disabled, is covered, or is the wrong kind of \
           control"
          "pick another row, or `leash snap TAB` if the page moved; a file input takes \
           `leash upload`"
    | State_unchanged ->
        info 65 "a check or uncheck did not change the control's checked state"
          "snap and read the row's state; the control did not toggle, so pick another \
           row or click its label"
    | Dialog_open ->
        info 65 "a dialog blocks page reads and actions; answer it first"
          "answer it with `leash dialog TAB accept` or `leash dialog TAB dismiss`, then \
           retry"
    | No_dialog ->
        info 64 "dialog was asked with nothing to answer"
          "nothing is open; `leash snap TAB` and call dialog only when a dialog is shown"
    | No_handoff ->
        info 64 "resume on a tab nobody is waiting on"
          "nobody is waiting; `leash handoff TAB REASON` starts one, and only then does \
           `leash resume TAB` finish it"
    | Url_refused ->
        info 64 "scheme is not http, https, or about:blank, or the URL has userinfo"
          "use an http or https URL with no userinfo, or about:blank"
    | Tab_cap ->
        info 75 "no capacity for a new tab"
          "close a tab with `leash close TAB`, then retry `leash new`"
    | Timeout ->
        info 75
          "wait, handoff, or a bounded operation ran out of time; a handoff's \
           detail.warnings lists the steps that failed"
          "retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or \
           `leash resume TAB`"
    | Renderer_unresponsive ->
        info 75
          "a tab session CDP call exceeded its deadline; detail.entries carries its last \
           debug entries"
          "the page's renderer is not answering; a bot-detection challenge or a hung \
           script is likely; shot may still work; close the tab or hand off"
    | Browser_unavailable ->
        info 69 "Chrome is restarting"
          "Chrome is restarting; retry `leash status` in a few seconds"
    | Model_timeout ->
        info 75 "a model call exceeded its per-call deadline"
          "the model provider timed out; retry, or raise models.<kind>_timeout"
    | Model_unavailable ->
        info 69
          "System One or the text helper failed, or no API key is configured; \
           detail.code is missing-key, unavailable, timeout, authentication, \
           invalid-response, input-too-large, model-mismatch, or text-helper-unavailable"
          "read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry"
    | Too_large ->
        info 65
          "expression, argument, result, fill text, or a script result is over its bound"
          "shrink the text, expression, argument, or files under the bound and retry"
    | Script_failed ->
        info 65
          "an eval expression or playbook script threw, rejected, or could not be \
           compiled; message carries the engine error"
          "read message; fix the expression, script, or page; `leash help scripts` \
           explains function bodies and `leash playbook test` tests installed scripts"
    | Script_invalid ->
        info 65
          "a playbook script's result does not fit its returns; message is the first \
           mismatch"
          "the result missed its returns shape; message is the first bad path, so fix \
           the script or the returns"
    | Playbook_invalid ->
        info 65
          "a playbook failed validation (load, check or accept); message names the rule"
          "fix the playbook as the message says, then `leash playbook check ./DIR`; \
           `leash help playbooks` lists the rules"
    | Internal ->
        info 70 "a defect; the message carries no page content"
          "a defect, not a page failure; retry once, then report the message"
    | Service_unreachable ->
        info 69 "the CLI could not connect to the control socket"
          "`systemctl --user start leash`, or pass --socket"
    | Not_installed ->
        info 69 "no leash.service unit is installed"
          "Leash is not installed; rebuild NixOS so leash.service exists, then \
           `systemctl --user start leash`"
    | Service_stopped ->
        info 69 "the leash unit is installed but inactive"
          "`systemctl --user start leash`, then `leash status`; a brief \
           service-restarting (75) right after start is normal - retry; tabs and \
           snapshots from before the stop are gone, so re-open them"
    | Service_restarting ->
        info 75
          "the leash unit is activating or auto-restarting, or Chrome's generation is \
           being relaunched"
          "Leash is restarting; retry `leash status` in a few seconds"
    | Socket_permission ->
        info 77 "the CLI was denied access to the control socket"
          "the control socket is not readable; check its permissions, or pass --socket"
    | Permission_denied ->
        info 77 "the CLI was denied access to a filesystem path"
          "check the path's permissions, or pass another path"
    | Config_invalid ->
        info 65 "the configuration file is missing, unreadable, or invalid"
          "fix the reported problems; `leash config check` lists every one with the \
           config path"
    | Usage ->
        info 64 "the command was invoked wrongly; the arguments do not match its synopsis"
          "`leash <command> --help` shows the arguments and an example"
    | Cli_parse ->
        info 124 "Cmdliner rejected the command line; the command did not run"
          "the command line did not parse; `leash <command> --help` shows the accepted \
           form"
    | Invalid_response ->
        info 70 "the service reply was not a protocol object the CLI could decode"
          "the service reply was not a protocol object; check `leash status` and retry"

  let all =
    [
      Invalid_request;
      Ambiguous;
      No_match;
      Taken;
      With_human;
      Tab_gone;
      Unknown_tab;
      Stale_snapshot;
      No_such_row;
      Body_unavailable;
      Unknown_request;
      Row_not_actionable;
      State_unchanged;
      Dialog_open;
      No_dialog;
      No_handoff;
      Url_refused;
      Tab_cap;
      Timeout;
      Renderer_unresponsive;
      Browser_unavailable;
      Model_unavailable;
      Model_timeout;
      Too_large;
      Script_failed;
      Script_invalid;
      Playbook_invalid;
      Internal;
      Service_unreachable;
      Not_installed;
      Service_stopped;
      Service_restarting;
      Socket_permission;
      Permission_denied;
      Config_invalid;
      Usage;
      Cli_parse;
      Invalid_response;
    ]

  let exit_code code = (meta code).exit_code
  let hint code = (meta code).hint
  let meaning code = (meta code).meaning

  let error_help =
    let header = "# code\texit\tmeaning\thint" in
    let line code =
      Printf.sprintf "%s\t%d\t%s\t%s" (to_string code) (exit_code code) (meaning code)
        (hint code)
    in
    String.concat "\n" (header :: List.map line all) ^ "\n"

  (* hdoc-ztwo: the help topic is this markdown, not a hand-kept table. *)
  let topic_markdown =
    let intro =
      String.concat "\n"
        [
          "# Errors";
          "";
          "Each row is one code the service or the CLI can return. The wire object is";
          "`{code,message,hint,detail?}`. Exit status is the class, not 1. Field meaning";
          "is in the other topics; this table is the code, when it is used, and the next";
          "action.";
          "";
        ]
      ^ "\n"
    in
    let header = "| code | exit | meaning | hint |\n| --- | --- | --- | --- |\n" in
    let row code =
      Printf.sprintf "| `%s` | %d | %s | %s |\n" (to_string code) (exit_code code)
        (meaning code) (hint code)
    in
    intro ^ header ^ String.concat "" (List.map row all)
end

let error_help = Error_code.error_help

(* ---------- Tab, snapshot and drive shapes ---------- *)

type dialog = {
  kind : Dialog_kind.t;
  message : string;
  default_prompt : string option; [@json.null]
}
[@@deriving yojson]

type page_kind_source =
  | Declared [@json.name "declared"]
  | Inferred [@json.name "inferred"]
[@@deriving yojson]

type page_kind_label = { name : string; source : page_kind_source } [@@deriving yojson]

type tab_info = {
  tab : Handle.t;
  label : string option; [@json.null]
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option; [@json.null]
  with_human : bool;
  reason : string option;
  generation : int;
  dialog : dialog option; [@json.null]
  loaded : bool option;
}
[@@deriving yojson]

type tab_listing = {
  label : string option; [@json.null]
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option; [@json.null]
  with_human : bool;
  reason : string option;
}
[@@deriving yojson]

type popup_info = {
  tab : Handle.t option; [@json.null]
  label : string option; [@json.null]
  url : string;
  title : string;
  page_kind : page_kind_label option;
  origin : Origin.t;
  age_s : int;
  idle_s : int;
  closes_in_s : int option; [@json.null]
  with_human : bool;
  reason : string option;
  state : Popup_state.t;
  generation : int;
  dialog : dialog option; [@json.null]
  opener_url : string;
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

type snapshot_source = Ax [@json.name "ax"] | Dom [@json.name "dom"] [@@deriving yojson]

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
  source : snapshot_source; [@json.default Ax]
  reason : string option;
  dialog : dialog option; [@json.null]
}
[@@deriving yojson]

type action_result = {
  tab : Handle.t;
  url : string;
  title : string;
  snapshot : snapshot option; [@json.null]
      (** field-swvb: null, or the fresh snapshot taken after settlement when the request
          asked for one. The object is a {!snapshot}, not an id. *)
  dialog : dialog option; [@json.null]
  popups : popup_info list;
  via : string option;
      (** field-uls3: [key?]. ["label"] when a click dispatched on the covering label of
          the target; absent otherwise. *)
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

(* trace-qe8c trace-iqqz trace-lg58: deliberately capability-free projections. *)
type trace_target = {
  target_role : string; [@json.key "role"]
  target_label : string; [@json.key "label"]
}
[@@deriving yojson]

type step = {
  non_repeatable : bool; [@json.default false]
  n : int;
  snapshot : Snapshot_id.t;
  operation : Operation.t;
  index : int option; [@json.null]
  probabilities : probabilities;
  target : trace_target option;
  text : string option;
  after : after;
  elapsed_ms : int;
}
[@@deriving yojson]

(* ---------- Per-command arguments ---------- *)

type new_args = { url : string option; label : string option } [@@deriving yojson]

type take_args = { url : string option; title : string option; label : string option }
[@@deriving yojson]

type tab_args = { tab : Handle.t } [@@deriving yojson]

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

(* field-swvb: [snap], [match_] and [limit] are [key?]. Set [snap] to ask for a
   fresh snapshot in the reply after settlement; [match_] and [limit] are snap's. *)
type click_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  snap : bool option;
  match_ : string option; [@json.key "match"]
  limit : int option;
}
[@@deriving yojson]

type fill_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  text : string;
  snap : bool option;
  match_ : string option; [@json.key "match"]
  limit : int option;
}
[@@deriving yojson]

type press_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int option;
  key : string;
  snap : bool option;
  match_ : string option; [@json.key "match"]
  limit : int option;
}
[@@deriving yojson]

type select_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  option : int;
  snap : bool option;
  match_ : string option; [@json.key "match"]
  limit : int option;
}
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

type hover_args = {
  tab : Handle.t;
  snapshot : Snapshot_id.t;
  index : int;
  snap : bool option;
  match_ : string option; [@json.key "match"]
  limit : int option;
}
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
  secrets : (string * string) list; [@json.default []]
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
  version : string;
  pid : int option; [@json.null]
  headed : bool;
  learning : Yojson.Safe.t option;
  key_present : bool;
}
[@@deriving yojson]

type list_result = { tabs : tab_listing list } [@@deriving yojson]

(* run-ykq4: a download belongs to the tab whose main frame began it. *)
type download_info = {
  id : string;
  suggested_name : string;
  mime : string;
  state : string;
  received_bytes : int;
  total_bytes : int;
  path : string option; [@json.null]
}
[@@deriving yojson]

type downloads_result = { downloads : download_info list } [@@deriving yojson]
type closed_result = { closed : bool } [@@deriving yojson]
type resumed_result = { resumed : bool } [@@deriving yojson]

type text_result = { url : string; title : string; text : string; truncated : bool }
[@@deriving yojson]

type shot_result = { path : string; bytes : int } [@@deriving yojson]
type debug_result = { entries : debug_entry list } [@@deriving yojson]
type eval_result = { value : Yojson.Safe.t } [@@deriving yojson]

(* hard-xg6y: one request of a tab's ring. Everything here is page data returned to the
   handle holder; none of it is ever a log line. *)
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

(* fly-9e0f fly-9363: bounded reference-like state, never validated script records. *)
type operator_state = Yojson.Safe.t [@@deriving yojson]

type drive_result = {
  status : Drive_status.t;
  steps : step list;
  operator_state : operator_state option;
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

(* extr-uhnc run-xqh8: original playbook judgments in order. A planner answer has
   no distribution or confidence; a refused review has no key and explains fallback. *)
type playbook_choice = {
  source : string;
  key : string option; [@json.null]
  probabilities : Yojson.Safe.t;
  confidence : float option; [@json.null]
  usage : run_usage option; [@json.null]
  note : string option; [@json.null]
}
[@@deriving yojson]

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
  revision : string option; [@json.default None]
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
type planner_step = {
  non_repeatable : bool; [@json.default false]
  n : int;
  command : string;
  target : trace_target option;
  text : string option;
  after : after;
  elapsed_ms : int;
  error : string option;
}
[@@deriving yojson]

type planner_turn = {
  n : int;
  trigger : string;
  answer : string;
  steps : planner_step list; [@json.default []]
  reason : string option;
  usage : run_usage option; [@json.null]
}
[@@deriving yojson]

(* run-9ypy run-m0r8: the whole run. [procedures] is the trace, oldest first;
   [proposals] are the files a planner-written procedure was written to, oldest first —
   the run never merges one; [final] is the last snapshot the run observed, whose [dialog]
   is what ended an [error]; [reason] names why the run stopped. *)
type run_result = {
  result : string option;
  evidence : string list;
  pilot_turns : int;
  navigator_steps : int;
  reasoning_summary : string option;
  secrets_for_operator : (string * string) list;
  unattended : Yojson.Safe.t list; [@json.default []]
  detail : Yojson.Safe.t option; [@json.default None]
  playbook_choices : playbook_choice list;
  status : Run_status.t;
  answer : string option; [@json.default None]
  site : string option; [@json.null]
  procedures : run_procedure list;
  mission_expectations : run_expectation list;
  planner_turns : planner_turn list;
  proposals : string list;
  installed : string list; [@json.default []]
  collected : int;
  data : Yojson.Safe.t;
  model_calls : int;
  model_cost : float option; [@json.null]
  operator_steps : step list;
  operator_state : operator_state option;
  output_kinds : string list;
  final : snapshot;
  reason : string option;
  trace_path : string option;
}
[@@deriving yojson]

module Trace = Trace

type drive_trace = Trace.t [@@deriving yojson]

(* ---------- Errors and replies ---------- *)

type error = {
  code : Error_code.t;
  message : string;
  hint : string;
  detail : Yojson.Safe.t option;
}
[@@deriving yojson]

let make_error ?detail code ~message =
  { code; message; hint = Error_code.hint code; detail }

(* daily-6pde daily-9ggi: every stale path names the current id, or null after navigation. *)
let stale_snapshot snapshot : error =
  make_error
    ~detail:
      (`Assoc
         [
           ( "snapshot",
             match snapshot with Some id -> Snapshot_id.yojson_of_t id | None -> `Null );
         ])
    Stale_snapshot ~message:"the snapshot or target row is no longer current"

(* own-teh1 tab-0ohq: the one [tab-gone], whether it comes from a tombstone, from a
   dispatch the target's death settled (tab-0ohq), or from the browser lookup that probe
   makes. The disposition in [detail] is what tells a client why the tab is gone. *)
let tab_gone disposition : error =
  make_error
    ~detail:(`Assoc [ ("disposition", yojson_of_disposition disposition) ])
    Tab_gone ~message:"the tab is gone"

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

let command_name = function
  | New _ -> "new"
  | List_tabs -> "list"
  | Take _ -> "take"
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
  | Net _ -> "net"
  | Net_body _ -> "net_body"
  | Net_request _ -> "net_request"
  | Upload _ -> "upload"
  | Hover _ -> "hover"
  | Check _ -> "check"
  | Uncheck _ -> "uncheck"
  | Cookies _ -> "cookies"
  | Storage _ -> "storage"
  | Playbook_test _ -> "playbook_test"
  | Playbook_check _ -> "playbook_check"

let args_to_json = function
  | New args -> yojson_of_new_args args
  | List_tabs -> `Assoc []
  | Take args -> yojson_of_take_args args
  | Close args -> yojson_of_tab_args args
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
  | Net args -> yojson_of_net_args args
  | Net_body args | Net_request args -> yojson_of_net_entry_args args
  | Upload args -> yojson_of_upload_args args
  | Hover args -> yojson_of_hover_args args
  | Check args | Uncheck args -> yojson_of_click_args args
  | Cookies args -> yojson_of_tab_args args
  | Storage args -> yojson_of_storage_args args
  | Playbook_test args -> yojson_of_playbook_test_args args
  | Playbook_check args -> yojson_of_playbook_check_args args

let command_of_args ~cmd args =
  let with_args decoder build = with_path "args" (Result.map build (decoder args)) in
  match cmd with
  | "new" -> with_args new_args_of_yojson (fun args -> New args)
  | "list" -> (
      match args with `Assoc [] -> Ok List_tabs | _ -> Error "list takes no arguments")
  | "take" -> (
      match with_path "args" (take_args_of_yojson args) with
      | Error message -> Error message
      | Ok args ->
          let n =
            List.length (List.filter Option.is_some [ args.url; args.title; args.label ])
          in
          if n = 1 then Ok (Take args)
          else Error "args: take requires exactly one selector")
  | "close" -> with_args tab_args_of_yojson (fun args -> Close args)
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
  | "net" -> with_args net_args_of_yojson (fun args -> Net args)
  | "net_body" -> with_args net_entry_args_of_yojson (fun args -> Net_body args)
  | "net_request" -> with_args net_entry_args_of_yojson (fun args -> Net_request args)
  | "upload" -> with_args upload_args_of_yojson (fun args -> Upload args)
  | "hover" -> with_args hover_args_of_yojson (fun args -> Hover args)
  | "check" -> with_args click_args_of_yojson (fun args -> Check args)
  | "uncheck" -> with_args click_args_of_yojson (fun args -> Uncheck args)
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

type request = { command : command }
(** The wire's ["v"] is a protocol constant: [decode_request] refuses anything but
    {!version}, and [encode_request] always writes it. *)

let version = 1

let encode_request request =
  `Assoc
    [
      ("v", `Int version);
      ("cmd", `String (command_name request.command));
      ("args", args_to_json request.command);
    ]

let decode_request json =
  let ( let* ) = Result.bind in
  let* fields = object_fields "request" json in
  let* () = reject_unknown "request" [ "v"; "cmd"; "args" ] fields in
  let* version_json = required "request" "v" fields in
  let* () =
    if version_json = `Int version then Ok ()
    else
      Error
        (Printf.sprintf "v: expected version %d, got %s" version
           (Yojson.Safe.to_string version_json))
  in
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
  Ok { command }

(* map-7xrq map-3qag: reuse the public action protocol, never a JS escape hatch. *)
type planner_action = command

(* pilot-x1f3: the pilot writes an action as {cmd, args}; the wire version belongs to
   the control socket, not to the model, so it is supplied here when absent (U1 live run
   2026-10-04 failed on "missing field v" before its first turn). *)
let planner_action_of_yojson json =
  let json =
    match json with
    | `Assoc fields when not (List.mem_assoc "v" fields) ->
        `Assoc (("v", `Int version) :: fields)
    | json -> json
  in
  Result.bind (decode_request json) (fun request ->
      match request.command with
      | Click _ | Fill _ | Select _ | Press _ | Scroll _ | Nav _ -> Ok request.command
      | _ -> Error "act accepts only click, fill, select, press, scroll and nav")

let yojson_of_planner_action command = encode_request { command }

let check_consent_click (page : snapshot) ~index =
  let label name =
    String.lowercase_ascii (String.trim name)
    |> String.map (function '-' | '_' -> ' ' | c -> c)
    |> String.split_on_char ' '
    |> List.filter (( <> ) "")
    |> String.concat " "
  in
  let accepts =
    [
      "accept all";
      "accept all cookies";
      "agree to all";
      "agree to all cookies";
      "allow all";
      "allow all cookies";
      "zaakceptuj wszystko";
    ]
  in
  let rejects =
    [
      "reject all";
      "decline all";
      "reject";
      "decline";
      "necessary only";
      "only necessary";
      "necessary cookies only";
      "only necessary cookies";
      "essential only";
      "only essential";
      "use necessary cookies only";
      "continue without accepting";
      "odrzuć wszystko";
      "tylko niezbędne";
    ]
  in
  let button (row : row) = row.role = "button" in
  match List.find_opt (fun (row : row) -> row.index = index) page.rows with
  | Some target when button target && List.mem (label target.name) accepts -> (
      match
        List.find_opt
          (fun (row : row) ->
            List.mem row.role [ "button"; "link" ]
            && List.mem (label row.name) rejects
            && not (List.mem Disabled (Option.value ~default:[] row.state)))
          page.rows
      with
      | Some alternative ->
          Error
            (Printf.sprintf "consent guard: refuse %S; choose %S instead (always decline)"
               target.name alternative.name)
      | None -> Ok ())
  | _ -> Ok ()

let check_planner_action (page : snapshot) action =
  let named index = List.exists (fun (row : row) -> row.index = index) page.rows in
  let row snapshot index =
    if snapshot <> page.snapshot then Error "continue action names a different snapshot"
    else if not (named index) then Error "continue action names no offered row"
    else Ok ()
  in
  let same_tab tab check =
    if tab <> page.tab then Error "continue action names a different tab" else check ()
  in
  match action with
  | Click args ->
      same_tab args.tab (fun () ->
          Result.bind (row args.snapshot args.index) (fun () ->
              check_consent_click page ~index:args.index))
  | Fill args -> same_tab args.tab (fun () -> row args.snapshot args.index)
  | Select args -> same_tab args.tab (fun () -> row args.snapshot args.index)
  | Press args ->
      same_tab args.tab (fun () ->
          match args.index with
          | Some index -> row args.snapshot index
          | None -> Error "continue press must name an offered row")
  | _ -> Error "pilot act accepts only click, select, fill and press on offered rows"

(* pilot-02ij: redact values before any model, trace or diagnostic boundary. *)
let redact_string secrets text =
  List.fold_left
    (fun text (_, value) ->
      if value = "" then text
      else
        let n = String.length value in
        let out = Buffer.create (String.length text) in
        let rec go i =
          if i >= String.length text then Buffer.contents out
          else if i + n <= String.length text && String.sub text i n = value then (
            Buffer.add_string out "<redacted>";
            go (i + n))
          else (
            Buffer.add_char out text.[i];
            go (i + 1))
        in
        go 0)
    text
    (List.sort
       (fun (_, a) (_, b) -> Int.compare (String.length b) (String.length a))
       secrets)

let rec redact_json secrets = function
  | `String value -> `String (redact_string secrets value)
  | `Assoc fields ->
      `Assoc
        (List.map
           (fun (key, value) -> (redact_string secrets key, redact_json secrets value))
           fields)
  | `List values -> `List (List.map (redact_json secrets) values)
  | json -> json
