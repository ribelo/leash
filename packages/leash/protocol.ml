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

type error_code =
  | Invalid_request [@json.name "invalid-request"]
  | Not_owner [@json.name "not-owner"]
  | Already_owned [@json.name "already-owned"]
  | With_human [@json.name "with-human"]
  | Tab_gone [@json.name "tab-gone"]
  | Unknown_tab [@json.name "unknown-tab"]
  | Stale_snapshot [@json.name "stale-snapshot"]
  | No_such_row [@json.name "no-such-row"]
  | Row_not_actionable [@json.name "row-not-actionable"]
  | Dialog_open [@json.name "dialog-open"]
  | No_dialog [@json.name "no-dialog"]
  | Url_refused [@json.name "url-refused"]
  | Tab_cap [@json.name "tab-cap"]
  | Timeout [@json.name "timeout"]
  | Browser_unavailable [@json.name "browser-unavailable"]
  | Model_unavailable [@json.name "model-unavailable"]
  | Too_large [@json.name "too-large"]
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
type dialog = { kind : Dialog_kind.t; message : string } [@@deriving yojson]

type tab_info = {
  tab : Handle.t;
  url : string;
  title : string;
  origin : Origin.t;
  state : State.t;
  owner : Owner.t option; [@json.null]
  generation : int;
  expires : expires option; [@json.null]
}
[@@deriving yojson]

type row = {
  index : int;
  role : string;
  name : string;
  value : string option;
  state : Row_state.t list option;
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

type eval_args = { tab : Handle.t; expression : string; argument : Yojson.Safe.t option }
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
}
[@@deriving yojson]

type wait_args = { tab : Handle.t; until : wait_until; timeout_ms : int option }
[@@deriving yojson]

type dialog_args = { tab : Handle.t; answer : Answer.t; text : string option }
[@@deriving yojson]

type handoff_args = { tab : Handle.t; reason : string; timeout_s : int option }
[@@deriving yojson]

type drive_args = {
  tab : Handle.t;
  goal : string;
  max_steps : int option;
  deadline_s : int option;
}
[@@deriving yojson]

(* ---------- Per-command results ---------- *)

type tab_counts = { open_ : int; [@json.key "open"] cap : int } [@@deriving yojson]

type status_result = {
  generation : int;
  tabs : tab_counts;
  chrome : Chrome_phase.t;
  uptime_s : float;
}
[@@deriving yojson]

type list_result = { tabs : tab_info list } [@@deriving yojson]
type released_result = { released : bool } [@@deriving yojson]
type closed_result = { closed : bool } [@@deriving yojson]
type resumed_result = { resumed : bool } [@@deriving yojson]

type text_result = { url : string; title : string; text : string; truncated : bool }
[@@deriving yojson]

type shot_result = { path : string; bytes : int } [@@deriving yojson]
type debug_result = { entries : debug_entry list } [@@deriving yojson]
type eval_result = { value : Yojson.Safe.t } [@@deriving yojson]
type handoff_result = { resumed : bool; url : string; title : string } [@@deriving yojson]

type drive_result = { status : Drive_status.t; steps : step list; final : snapshot }
[@@deriving yojson]

(* ---------- Errors and replies ---------- *)

type error = { code : Error_code.t; message : string; detail : Yojson.Safe.t option }
[@@deriving yojson]

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
  | Release of tab_args
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
  | Drive of drive_args

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

let args_to_json = function
  | New args -> yojson_of_new_args args
  | List_tabs args -> yojson_of_list_args args
  | Claim args -> yojson_of_tab_args args
  | Release args -> yojson_of_tab_args args
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
  | Drive args -> yojson_of_drive_args args

let command_of_args ~cmd args =
  let with_args decoder build = with_path "args" (Result.map build (decoder args)) in
  match cmd with
  | "new" -> with_args new_args_of_yojson (fun args -> New args)
  | "list" -> with_args list_args_of_yojson (fun args -> List_tabs args)
  | "claim" -> with_args tab_args_of_yojson (fun args -> Claim args)
  | "release" -> with_args tab_args_of_yojson (fun args -> Release args)
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
  | "drive" -> with_args drive_args_of_yojson (fun args -> Drive args)
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
