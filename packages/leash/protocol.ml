(** The version-one control protocol: the wire contract of [docs/protocol.md] as types.

    The envelope does not match the deriver's variant encoding — a request is a ["cmd"]
    name with an ["args"] object, and a reply is [{ok, result}] or [{ok, error}] — so the
    envelope is dispatched here by hand. Every per-command argument record and every
    result record is a plain type with a derived codec. *)

module Json = struct
  type t = Yojson.Safe.t
  (** A value whose shape belongs to the page or to the caller: an [eval] argument, the
      [drive] probabilities, an [eval] result. *)

  let t_of_yojson json = Ok json
  let yojson_of_t json = json
end

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

(** A closed set of wire strings: the constructors are the protocol's, and a value outside
    the set is refused by naming the set. *)
module Closed (Spec : sig
  type t

  val name : string
  val values : (string * t) list
end) : sig
  type t

  val to_string : t -> string
  val of_string : string -> (t, string) result
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end = struct
  type t = Spec.t

  let to_string value =
    match List.find_opt (fun (_, candidate) -> candidate = value) Spec.values with
    | Some (text, _) -> text
    | None -> invalid_arg ("Closed.to_string: value outside " ^ Spec.name)

  let accepted () =
    "one of "
    ^ String.concat ", "
        (List.map (fun (text, _) -> Printf.sprintf "%S" text) Spec.values)

  let of_string text =
    match List.assoc_opt text Spec.values with
    | Some value -> Ok value
    | None -> Error (Printf.sprintf "expected %s, got %S" (accepted ()) text)

  let t_of_yojson = function
    | `String text -> of_string text
    | json ->
        Error
          (Printf.sprintf "expected %s, got %s" (accepted ()) (Yojson.Safe.to_string json))

  let yojson_of_t value = `String (to_string value)
end

module Origin = Closed (struct
  type t = Agent | Human

  let name = "origin"
  let values = [ ("agent", Agent); ("human", Human) ]
end)

module State = Closed (struct
  type t = Unowned | Owned | With_human

  let name = "state"
  let values = [ ("unowned", Unowned); ("owned", Owned); ("with_human", With_human) ]
end)

module Stage = Closed (struct
  type t = Release | Close

  let name = "stage"
  let values = [ ("release", Release); ("close", Close) ]
end)

module Dialog_kind = Closed (struct
  type t = Alert | Confirm | Prompt | Beforeunload

  let name = "dialog kind"

  let values =
    [
      ("alert", Alert);
      ("confirm", Confirm);
      ("prompt", Prompt);
      ("beforeunload", Beforeunload);
    ]
end)

module Row_state = Closed (struct
  type t =
    | Checked
    | Unchecked
    | Mixed
    | Selected
    | Expanded
    | Collapsed
    | Disabled
    | Required
    | Readonly

  let name = "row state"

  let values =
    [
      ("checked", Checked);
      ("unchecked", Unchecked);
      ("mixed", Mixed);
      ("selected", Selected);
      ("expanded", Expanded);
      ("collapsed", Collapsed);
      ("disabled", Disabled);
      ("required", Required);
      ("readonly", Readonly);
    ]
end)

module Debug_kind = Closed (struct
  type t = Console | Exception | Request_failed

  let name = "debug kind"

  let values =
    [ ("console", Console); ("exception", Exception); ("request-failed", Request_failed) ]
end)

module Operation = Closed (struct
  type t = Click | Type_text | Select | Scroll_up | Scroll_down | Wait | Done | Blocked

  let name = "operation"

  let values =
    [
      ("click", Click);
      ("type_text", Type_text);
      ("select", Select);
      ("scroll_up", Scroll_up);
      ("scroll_down", Scroll_down);
      ("wait", Wait);
      ("done", Done);
      ("blocked", Blocked);
    ]
end)

module Direction = Closed (struct
  type t = Up | Down

  let name = "direction"
  let values = [ ("up", Up); ("down", Down) ]
end)

module Answer = Closed (struct
  type t = Accept | Dismiss

  let name = "answer"
  let values = [ ("accept", Accept); ("dismiss", Dismiss) ]
end)

module Drive_status = Closed (struct
  type t = Done | Blocked | Step_cap | Deadline | Error

  let name = "drive status"

  let values =
    [
      ("done", Done);
      ("blocked", Blocked);
      ("step-cap", Step_cap);
      ("deadline", Deadline);
      ("error", Error);
    ]
end)

module Chrome_phase = Closed (struct
  type t = Running | Restarting

  let name = "chrome phase"
  let values = [ ("running", Running); ("restarting", Restarting) ]
end)

module Error_code = Closed (struct
  type t =
    | Invalid_request
    | Not_owner
    | Already_owned
    | With_human
    | Tab_gone
    | Unknown_tab
    | Stale_snapshot
    | No_such_row
    | Row_not_actionable
    | Dialog_open
    | No_dialog
    | Url_refused
    | Tab_cap
    | Timeout
    | Browser_unavailable
    | Model_unavailable
    | Too_large
    | Internal

  let name = "error code"

  let values =
    [
      ("invalid-request", Invalid_request);
      ("not-owner", Not_owner);
      ("already-owned", Already_owned);
      ("with-human", With_human);
      ("tab-gone", Tab_gone);
      ("unknown-tab", Unknown_tab);
      ("stale-snapshot", Stale_snapshot);
      ("no-such-row", No_such_row);
      ("row-not-actionable", Row_not_actionable);
      ("dialog-open", Dialog_open);
      ("no-dialog", No_dialog);
      ("url-refused", Url_refused);
      ("tab-cap", Tab_cap);
      ("timeout", Timeout);
      ("browser-unavailable", Browser_unavailable);
      ("model-unavailable", Model_unavailable);
      ("too-large", Too_large);
      ("internal", Internal);
    ]
end)

(* ---------- Tab, snapshot and drive shapes ---------- *)

type expires = { stage : Stage.t; in_s : int } [@@deriving yojson]
type dialog = { kind : Dialog_kind.t; message : string } [@@deriving yojson]

type tab_info = {
  tab : Handle.t;
  url : string;
  title : string;
  origin : Origin.t;
  state : State.t;
  owner : Owner.t option;
  generation : int;
  expires : expires option;
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
  dialog : dialog option;
}
[@@deriving yojson]

type action_result = {
  tab : Handle.t;
  url : string;
  title : string;
  snapshot : Snapshot_id.t option;
  dialog : dialog option;
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
type probabilities = { op : Json.t; target : Json.t } [@@deriving yojson]

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
[@@deriving yojson]

(* ---------- Per-command arguments ---------- *)

type new_args = { url : string option } [@@deriving yojson]
type list_args = { all : bool [@default false] } [@@deriving yojson]
type tab_args = { tab : Handle.t } [@@deriving yojson]

type snap_args = {
  tab : Handle.t;
  match_ : string option; [@key "match"]
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

type eval_args = { tab : Handle.t; expression : string; argument : Json.t option }
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

type tab_counts = { open_ : int; [@key "open"] cap : int } [@@deriving yojson]

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
type eval_result = { value : Json.t } [@@deriving yojson]
type handoff_result = { resumed : bool; url : string; title : string } [@@deriving yojson]

type drive_result = { status : Drive_status.t; steps : step list; final : snapshot }
[@@deriving yojson]

(* ---------- Errors and replies ---------- *)

type error = { code : Error_code.t; message : string; detail : Json.t option }
[@@deriving yojson]

(** One of the two wire shapes. The result stays raw JSON because the CLI prints it
    without knowing the command's result type; the per-command result records above are
    what the service encodes into it. *)
type reply = Success of Json.t | Failure of error

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
  | Status -> `Assoc []
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
  let empty_object = function
    | `Assoc [] -> Ok ()
    | `Assoc ((key, _) :: _) -> Error (Printf.sprintf "unknown field %s" key)
    | json -> Error (expected "an empty object" json)
  in
  match cmd with
  | "new" -> with_args new_args_of_yojson (fun args -> New args)
  | "list" -> with_args list_args_of_yojson (fun args -> List_tabs args)
  | "claim" -> with_args tab_args_of_yojson (fun args -> Claim args)
  | "release" -> with_args tab_args_of_yojson (fun args -> Release args)
  | "close" -> with_args tab_args_of_yojson (fun args -> Close args)
  | "status" -> with_args empty_object (fun () -> Status)
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
