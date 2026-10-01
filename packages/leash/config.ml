(** The service configuration: one plain record with derived codecs, secret fields typed
    {!Ox_observability.Redact.t}, and constrained values in small modules with smart
    constructors and their own codecs (ADR-0009). *)

module Redact = Ox_observability.Redact

(** The tab cap: a positive whole number of tabs. *)
module Tab_cap = struct
  type t = int

  let of_int n =
    if n > 0 then Ok n else Error (Printf.sprintf "expected a positive integer, got %d" n)

  let to_int t = t

  let t_of_yojson = function
    | `Int n -> of_int n
    | json ->
        Error
          (Printf.sprintf "expected a positive integer, got %s"
             (Yojson.Safe.to_string json))

  let yojson_of_t t = `Int t
end

(** An expiry duration in seconds, positive. *)
module Seconds = struct
  type t = int

  let of_int n =
    if n > 0 then Ok n
    else Error (Printf.sprintf "expected a positive duration in seconds, got %d" n)

  let to_int t = t

  let t_of_yojson = function
    | `Int n -> of_int n
    | json ->
        Error
          (Printf.sprintf "expected a positive duration in seconds, got %s"
             (Yojson.Safe.to_string json))

  let yojson_of_t t = `Int t
end

(** A finite probability threshold in the closed interval [0, 1]. *)
module Probability = struct
  type t = float

  let of_float value =
    if Float.is_finite value && value >= 0. && value <= 1. then Ok value
    else Error "expected a finite probability between 0 and 1"

  let to_float value = value

  let t_of_yojson = function
    | `Float value -> of_float value
    | `Int value -> of_float (float_of_int value)
    | _ -> Error "expected a probability number"

  let yojson_of_t value = `Float value
end

(** A non-empty text value: a path, a workspace name, or a model id. *)
module Text = struct
  type t = string

  let of_string value =
    if String.trim value <> "" then Ok value else Error "must not be empty"

  let to_string t = t

  let t_of_yojson = function
    | `String value -> of_string value
    | json ->
        Error (Printf.sprintf "expected a string, got %s" (Yojson.Safe.to_string json))

  let yojson_of_t t = `String t
end

(* svc-x8rp: every non-secret field has a default, so a file that names one field — or a
   file that is only comments, or no file at all — is a configuration. The two paths that
   belong under an XDG directory carry their variable as a placeholder because the derived
   decoder cannot see the environment; {!env} expands them, once, on every path that
   decodes a config. [binary] may be a bare name: {!validate_paths} looks it up on [PATH]. *)
let default_binary = "google-chrome-stable"
let default_profile_dir = "$XDG_DATA_HOME/leash/profile"
let default_workspace = "leash"
let default_window_size = "1366,900"
let default_socket = "$XDG_RUNTIME_DIR/leash/control.sock"

(* ADR-0005: a tab cap of 32, half an hour idle before stage 1 releases, an hour unclaimed
   before stage 2 closes (own-uo77 own-hslp own-ay3s), and an hour of tombstone
   (chrome-akz4). *)
let default_cap = 32
let default_idle_s = 1800
let default_unclaimed_s = 3600
let default_tombstone_s = 3600

type chrome = {
  binary : Text.t; [@json.default default_binary]
  profile_dir : Text.t; [@json.default default_profile_dir]
  workspace : Text.t; [@json.default default_workspace]
  headless : bool; [@json.default false]
  window_size : Text.t; [@json.default default_window_size]
}
[@@deriving yojson]
(** The browser the service owns. [headless] defaults to false: production runs a headed
    browser on the configured workspace, and only the live-acceptance gate or an operator
    turns it on. *)

type tabs = { cap : Tab_cap.t [@json.default default_cap] } [@@deriving yojson]

type expiry = {
  idle_s : Seconds.t; [@json.default default_idle_s]
  unclaimed_s : Seconds.t; [@json.default default_unclaimed_s]
  tombstone_s : Seconds.t; [@json.default default_tombstone_s]
}
[@@deriving yojson]

(* svc-o4wt: the control socket is a configured path — a test or a second instance
   relocates it without moving the Wayland socket's directory — defaulting under the
   runtime directory as docs/protocol.md says. *)
type control = { socket : Text.t [@json.default default_socket] } [@@deriving yojson]

(* drive-yqxg: the two endpoints default to OpenRouter's, and TypeSafe's direct endpoint is
   accepted as-is because it serves the same contract; the two model ids are the pinned
   defaults the spec names, so a file that says nothing about models still decodes.
   drive-e7oi: [jev_model] is what the System One client sends and what the reply's model
   is checked against. *)
let default_systemone_endpoint = "https://openrouter.ai/api/v1/systemone"
let default_chat_base_url = "https://openrouter.ai/api/v1"
let default_jev_model = "typesafe/jev-1.13-20260917"
let default_text_model = "inception/mercury-2.5"

(* L32 run-d99l: the planner is a fallback, not the driver, so its own model is configured
   on its own: Luna through the same OpenRouter chat route the text helper uses, reasoning
   at "high" as the L32 decisions record, and the route [planner_endpoint] overrides when
   an operator points the planner at another OpenAI-compatible endpoint. *)
let default_planner_model = "openai/gpt-6-luna"
let default_planner_reasoning = "high"

(* daily-9ggi: per-attempt provider budgets, independent of the mission deadline. *)
let default_jev_timeout = 10
let default_text_timeout = 10
let default_planner_timeout = 60

type models = {
  api_key : Redact.t option;
  systemone_endpoint : Text.t;
  jev_model : Text.t;
  chat_base_url : Text.t;
  text_model : Text.t;
  planner_model : Text.t;
  planner_reasoning : Text.t;
  planner_endpoint : Text.t option;
  jev_timeout : Seconds.t;
  text_timeout : Seconds.t;
  planner_timeout : Seconds.t;
  choice_confidence : Probability.t;
}

(* daily-9ggi: the minimal deriver duplicates the remaining decoder for every
   defaulted field (exponential generated code). Keep this wide flat record's
   codec sequential until that upstream defect is fixed. *)
let yojson_of_models (value : models) =
  let optional name encode = function
    | None -> []
    | Some value -> [ (name, encode value) ]
  in
  `Assoc
    (optional "api_key" Redact.yojson_of_t value.api_key
    @ optional "planner_endpoint" Text.yojson_of_t value.planner_endpoint
    @ [
        ("systemone_endpoint", Text.yojson_of_t value.systemone_endpoint);
        ("jev_model", Text.yojson_of_t value.jev_model);
        ("chat_base_url", Text.yojson_of_t value.chat_base_url);
        ("text_model", Text.yojson_of_t value.text_model);
        ("planner_model", Text.yojson_of_t value.planner_model);
        ("planner_reasoning", Text.yojson_of_t value.planner_reasoning);
        ("jev_timeout", Seconds.yojson_of_t value.jev_timeout);
        ("text_timeout", Seconds.yojson_of_t value.text_timeout);
        ("planner_timeout", Seconds.yojson_of_t value.planner_timeout);
        ("choice_confidence", Probability.yojson_of_t value.choice_confidence);
      ])

let models_of_yojson = function
  | `Assoc fields -> (
      let ( let* ) = Result.bind in
      let field name decode default =
        match List.assoc_opt name fields with
        | None -> Ok default
        | Some json ->
            Result.map_error (fun why -> "models." ^ name ^ ": " ^ why) (decode json)
      in
      let optional decode = function
        | `Null -> Ok None
        | json -> Result.map Option.some (decode json)
      in
      let* api_key = field "api_key" (optional Redact.t_of_yojson) None in
      let* systemone_endpoint =
        field "systemone_endpoint" Text.t_of_yojson default_systemone_endpoint
      in
      let* jev_model = field "jev_model" Text.t_of_yojson default_jev_model in
      let* chat_base_url = field "chat_base_url" Text.t_of_yojson default_chat_base_url in
      let* text_model = field "text_model" Text.t_of_yojson default_text_model in
      let* planner_model = field "planner_model" Text.t_of_yojson default_planner_model in
      let* planner_reasoning =
        field "planner_reasoning" Text.t_of_yojson default_planner_reasoning
      in
      let* planner_endpoint = field "planner_endpoint" (optional Text.t_of_yojson) None in
      let* jev_timeout = field "jev_timeout" Seconds.t_of_yojson default_jev_timeout in
      let* text_timeout = field "text_timeout" Seconds.t_of_yojson default_text_timeout in
      let* planner_timeout =
        field "planner_timeout" Seconds.t_of_yojson default_planner_timeout
      in
      let* choice_confidence = field "choice_confidence" Probability.t_of_yojson 0.7 in
      let known =
        [
          "api_key";
          "systemone_endpoint";
          "jev_model";
          "chat_base_url";
          "text_model";
          "planner_model";
          "planner_reasoning";
          "planner_endpoint";
          "jev_timeout";
          "text_timeout";
          "planner_timeout";
          "choice_confidence";
        ]
      in
      match List.find_opt (fun (name, _) -> not (List.mem name known)) fields with
      | Some (name, _) -> Error ("models: unknown field " ^ name)
      | None ->
          Ok
            {
              api_key;
              systemone_endpoint;
              jev_model;
              chat_base_url;
              text_model;
              planner_model;
              planner_reasoning;
              planner_endpoint;
              jev_timeout;
              text_timeout;
              planner_timeout;
              choice_confidence;
            })
  | _ -> Error "models: expected an object"

(* hand-04rb hand-phof hand-rg9h: the two desktop commands a handoff runs, with the spec's
   defaults — niri's window focus for the managed Chrome's window, and notify-send's Done
   action carrying the agent's reason. An element is an argv template: {!Desktop} says
   which placeholders it may carry. An empty command turns that step off. *)
(* drive-yqxg: every field of the models section has a default, so the section itself is
   optional too: a file that says nothing about models decodes to OpenRouter's endpoints
   and the pinned model ids, and [OPENROUTER_API_KEY] alone is enough to run a drive. *)
let default_models =
  {
    api_key = None;
    systemone_endpoint = default_systemone_endpoint;
    jev_model = default_jev_model;
    chat_base_url = default_chat_base_url;
    text_model = default_text_model;
    planner_model = default_planner_model;
    planner_reasoning = default_planner_reasoning;
    planner_endpoint = None;
    choice_confidence = 0.7;
    jev_timeout = default_jev_timeout;
    text_timeout = default_text_timeout;
    planner_timeout = default_planner_timeout;
  }

(* daily-n7on, operator 2026-10-01: a handoff must not take focus — the human is in the
   middle of something else. Raising the window is opt-in (for niri:
   ["niri", "msg", "action", "focus-window", "--id", "{window_id}"]). The notification is
   critical so a daemon keeps it until it is answered; at normal urgency AGS expired it
   after five seconds, before Done could be clicked. *)
let default_focus_command = []

let default_notify_command =
  [
    "notify-send";
    "--urgency=critical";
    "--app-name=Leash";
    "--action";
    "done=Done";
    "Leash needs you";
    "{reason}";
  ]

type handoff = {
  focus_command : string list; [@json.default default_focus_command]
  notify_command : string list; [@json.default default_notify_command]
}
[@@deriving yojson]

let default_handoff =
  { focus_command = default_focus_command; notify_command = default_notify_command }

let default_chrome =
  {
    binary = default_binary;
    profile_dir = default_profile_dir;
    workspace = default_workspace;
    headless = false;
    window_size = default_window_size;
  }

let default_tabs = { cap = default_cap }

let default_expiry =
  {
    idle_s = default_idle_s;
    unclaimed_s = default_unclaimed_s;
    tombstone_s = default_tombstone_s;
  }

let default_control = { socket = default_socket }

(* daily-c4cl: configured roots replace automatic agent-directory discovery. *)
type skill = { roots : Text.t list [@json.default []] } [@@deriving yojson]

let default_skill = { roots = [] }

(* svc-f4op: no exporter is acquired when endpoint is absent. Header values are
   secret-wrapped from decode onward, including config check rendering. *)
type otlp_header = { name : Text.t; value : Redact.t } [@@deriving yojson]

type otlp = { endpoint : Text.t option; headers : otlp_header list [@json.default []] }
[@@deriving yojson]

let default_otlp = { endpoint = None; headers = [] }

type t = {
  chrome : chrome; [@json.default default_chrome]
  tabs : tabs; [@json.default default_tabs]
  expiry : expiry; [@json.default default_expiry]
  control : control; [@json.default default_control]
  otlp : otlp; [@json.default default_otlp]
  models : models; [@json.default default_models]
  handoff : handoff; [@json.default default_handoff]
  skill : skill; [@json.default default_skill]
}
[@@deriving yojson]

let default : t =
  {
    chrome = default_chrome;
    tabs = default_tabs;
    expiry = default_expiry;
    control = default_control;
    otlp = default_otlp;
    models = default_models;
    handoff = default_handoff;
    skill = default_skill;
  }

let toml_array values =
  "[" ^ String.concat ", " (List.map (Printf.sprintf "%S") values) ^ "]"

(* svc-x8rp: the file \`leash config init\` writes — every setting commented out with the
   default it would set, so the file itself changes nothing until a line is uncommented.
   The values are the constants above, never a second copy of them. *)
let default_toml =
  Printf.sprintf
    {|# Leash's configuration. Every setting below is commented out with the default it
# would set, so this file as it stands changes nothing. Uncomment a line to change it;
# an unknown key or a bad value fails at boot and is reported by leash config check.
#
# [chrome]
# binary = %S                # an absolute path, or a bare name found on PATH
# profile_dir = %S
# workspace = %S
# headless = false           # headed; only the live-acceptance gate sets true
#
# [tabs]
# cap = %d
#
# [expiry]
# idle_s = %d                # stage 1 releases a tab idle this long
# unclaimed_s = %d           # stage 2 closes an unclaimed agent tab this long after
# tombstone_s = %d           # a closed handle answers tab-gone this long
#
# [control]
# socket = %S
#
# [otlp]
# endpoint = "https://collector.example.com:4318" # uncomment to enable OTLP/HTTP
# [[otlp.headers]]                            # optional, repeat per header
# name = "Authorization"
# value = "Bearer ..."                         # redacted by config check
#
# [models]
# api_key = "sk-or-..."       # prefer OPENROUTER_API_KEY in the environment
# systemone_endpoint = %S
# jev_model = %S
# chat_base_url = %S
# text_model = %S
# planner_model = %S          # the fallback planner (Luna)
# planner_reasoning = %S      # OpenRouter effort; "none" turns reasoning off
# choice_confidence = 0.7     # review a playbook choice below this top probability
# jev_timeout = %d           # seconds per attempt; caller deadline still bounds all retries
# text_timeout = %d
# planner_timeout = %d
# planner_endpoint = "https://openrouter.ai/api/v1/chat/completions"
#                             # default: chat_base_url + /chat/completions
#
# [skill]
# roots = ["$HOME/.dotfiles/skills/engineering/debugging"]
#                             # empty by default: discover supported agent directories
#
# [handoff]
# focus_command = %s
# notify_command = %s
|}
    default_binary default_profile_dir default_workspace default_cap default_idle_s
    default_unclaimed_s default_tombstone_s default_socket default_systemone_endpoint
    default_jev_model default_chat_base_url default_text_model default_planner_model
    default_planner_reasoning default_jev_timeout default_text_timeout
    default_planner_timeout
    (toml_array default_focus_command)
    (toml_array default_notify_command)

let nonempty = function
  | Some value when String.trim value <> "" -> Some value
  | Some _ | None -> None

(* svc-x8rp svc-o4wt: the XDG-relative defaults are expanded here, wherever a config is
   decoded — the service, `config check` and the CLI read the same value. An unset variable
   leaves its placeholder in place and {!validate_paths} refuses it by pointer, so a
   missing XDG_RUNTIME_DIR is a failure that names the field instead of a socket at the
   filesystem root. *)
let expand ~getenv text =
  match String.split_on_char '/' text with
  | first :: rest when String.length first > 1 && first.[0] = '$' -> (
      let variable = String.sub first 1 (String.length first - 1) in
      let value =
        match variable with
        | "XDG_DATA_HOME" -> (
            (* The base directory spec's fallback. *)
            match nonempty (getenv "XDG_DATA_HOME") with
            | Some path -> Some path
            | None ->
                Option.map
                  (fun home -> Filename.concat home ".local/share")
                  (nonempty (getenv "HOME")))
        | variable -> nonempty (getenv variable)
      in
      match value with
      | Some base -> Filename.concat base (String.concat "/" rest)
      | None -> text)
  | "~" :: rest -> (
      match nonempty (getenv "HOME") with
      | Some home -> Filename.concat home (String.concat "/" rest)
      | None -> text)
  | _ -> text

let env ~getenv config =
  let models =
    match getenv "OPENROUTER_API_KEY" with
    | Some key when String.trim key <> "" ->
        { config.models with api_key = Some (Redact.make key) }
    | Some _ | None -> config.models
  in
  let path text =
    match Text.of_string (expand ~getenv (Text.to_string text)) with
    | Ok path -> path
    | Error _ -> text
  in
  {
    config with
    models;
    chrome = { config.chrome with profile_dir = path config.chrome.profile_dir };
    control = { socket = path config.control.socket };
    skill = { roots = List.map path config.skill.roots };
  }

let spec : t Ox_app.Config.t = { of_yojson = t_of_yojson; yojson_of_t; env }

let chrome_config (chrome : chrome) =
  Chrome.make
    ~binary:(Text.to_string chrome.binary)
    ~profile_dir:(Text.to_string chrome.profile_dir)
    ~workspace:(Text.to_string chrome.workspace)
    ~headless:chrome.headless
    ~window_size:(Text.to_string chrome.window_size)
    ()

(* daily-9396: one refusal must not hide the next. These builders are what
   {!validate_otlp}, {!validate_paths} and {!decode_all} share, so a pointer and a message
   cannot drift between the Door and config check. *)
let issue pointer message = { Ox_app.Config.pointer; message }

let show_json json =
  let text = Yojson.Safe.to_string json in
  if String.length text > 200 then String.sub text 0 200 ^ "..." else text

let pointer_token key =
  let buffer = Buffer.create (String.length key) in
  String.iter
    (function
      | '~' -> Buffer.add_string buffer "~0"
      | '/' -> Buffer.add_string buffer "~1"
      | char -> Buffer.add_char buffer char)
    key;
  Buffer.contents buffer

let child pointer key = pointer ^ "/" ^ pointer_token key
let pointer_index pointer index = pointer ^ "/" ^ string_of_int index

let endpoint_issues endpoint =
  match Ox_http.Url.parse (Text.to_string endpoint) with
  | Error _ -> [ issue "/otlp/endpoint" "must be an http(s) URL without userinfo" ]
  | Ok url when Ox_http.Url.query url <> None || Ox_http.Url.fragment url <> None ->
      [ issue "/otlp/endpoint" "query and fragment are not allowed" ]
  | Ok _ -> []

let otlp_header_token = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' -> true
  | _ -> false

let header_issue index header =
  let name = Text.to_string header.name in
  let value = Redact.expose header.value in
  let name_issue =
    if String.for_all otlp_header_token name then []
    else
      [ issue (Printf.sprintf "/otlp/headers/%d/name" index) "invalid HTTP header name" ]
  in
  let value_issue =
    if String.contains value '\n' || String.contains value '\r' then
      [
        issue (Printf.sprintf "/otlp/headers/%d/value" index) "invalid HTTP header value";
      ]
    else []
  in
  name_issue @ value_issue

let header_issues headers =
  List.concat (List.mapi (fun index header -> header_issue index header) headers)

let otlp_issues config =
  let require =
    match config.otlp.endpoint with
    | None when config.otlp.headers <> [] ->
        [ issue "/otlp/headers" "headers require an endpoint" ]
    | _ -> []
  in
  let endpoint =
    match config.otlp.endpoint with
    | None -> []
    | Some endpoint -> endpoint_issues endpoint
  in
  require @ endpoint @ header_issues config.otlp.headers

let validate_otlp config =
  match otlp_issues config with [] -> Ok () | errors -> Error errors

let stat_issues pointer path expected permissions fs =
  let path = Eio.Path.(fs / path) in
  try
    let stat = Eio.Path.stat ~follow:true path in
    if stat.Eio.File.Stat.kind <> expected then [ issue pointer "wrong file type" ]
    else if stat.perm land permissions <> permissions then
      [ issue pointer "insufficient permissions" ]
    else []
  with Eio.Io _ -> [ issue pointer "path missing or unreadable" ]

let executable ~fs path =
  try
    let stat = Eio.Path.stat ~follow:true Eio.Path.(fs / path) in
    stat.Eio.File.Stat.kind = `Regular_file && stat.perm land 0o100 <> 0
  with Eio.Io _ -> false

(* svc-x8rp: a bare binary name is looked up on PATH; a name nothing provides is a
   failure by pointer rather than a Chrome that never starts. *)
let binary_issues ~getenv ~fs name =
  let on_path =
    Option.bind (getenv "PATH") (fun path ->
        String.split_on_char ':' path
        |> List.filter_map (fun dir ->
            if dir = "" then None else Some (Filename.concat dir name))
        |> List.find_opt (executable ~fs))
  in
  if String.contains name '/' then
    stat_issues "/chrome/binary" name `Regular_file 0o100 fs
  else
    match on_path with
    | Some path -> stat_issues "/chrome/binary" path `Regular_file 0o100 fs
    | None -> [ issue "/chrome/binary" (Printf.sprintf "%s is not on PATH" name) ]

(* svc-o4wt: a placeholder an unset variable left behind names the field, and a relative
   socket is never a place the listener can bind. *)
let socket_issues ~check_unset socket =
  if String.contains socket '$' then
    if check_unset then
      [ issue "/control/socket" "the environment variable in this path is unset" ]
    else []
  else if Filename.is_relative socket then
    [ issue "/control/socket" "must be an absolute path" ]
  else []

(* svc-x8rp: a missing profile is accepted when its nearest existing ancestor is writable;
   {!ensure_dir} creates the rest before Chrome starts. *)
let profile_issues ~check_unset ~fs profile =
  if String.contains profile '$' then
    if check_unset then
      [ issue "/chrome/profile_dir" "the environment variable in this path is unset" ]
    else []
  else
    match fs with
    | None -> []
    | Some fs -> (
        match Eio.Path.kind ~follow:true Eio.Path.(fs / profile) with
        | `Directory -> stat_issues "/chrome/profile_dir" profile `Directory 0o700 fs
        | `Not_found ->
            let rec nearest path =
              let parent = Filename.dirname path in
              if parent = path then path
              else
                match Eio.Path.kind ~follow:true Eio.Path.(fs / parent) with
                | `Not_found -> nearest parent
                | _ -> parent
            in
            stat_issues "/chrome/profile_dir" (nearest profile) `Directory 0o300 fs
        | _ -> [ issue "/chrome/profile_dir" "not a directory" ])

let skill_path_issues ~check_unset index path =
  let pointer = Printf.sprintf "/skill/roots/%d" index in
  let unexpanded = String.contains path '$' || String.starts_with ~prefix:"~" path in
  if check_unset && unexpanded then
    [ issue pointer "the environment variable in this path is unset" ]
  else if Filename.is_relative path && not unexpanded then
    [ issue pointer "must be an absolute path" ]
  else []

let skill_root_issues roots =
  List.concat
    (List.mapi
       (fun index root -> skill_path_issues ~check_unset:true index (Text.to_string root))
       roots)

let validate_paths ~getenv ~fs config =
  (* Order is the old short-circuit order, so a caller that reads the first issue still
     sees the refusal it saw before aggregation: OTLP, binary, socket, profile. *)
  match
    otlp_issues config
    @ binary_issues ~getenv ~fs (Text.to_string config.chrome.binary)
    @ socket_issues ~check_unset:true (Text.to_string config.control.socket)
    @ profile_issues ~check_unset:true ~fs:(Some fs)
        (Text.to_string config.chrome.profile_dir)
    @ skill_root_issues config.skill.roots
  with
  | [] -> Ok ()
  | errors -> Error errors

let validate (env : Eio_unix.Stdenv.base Ox_app.Env.t) config =
  validate_paths
    ~getenv:(Ox_caps.Cap_sys.getenv_opt ~caps:env.caps)
    ~fs:env.base#fs config

let expect_object pointer = function
  | `Assoc fields -> Ok fields
  | json -> Error [ issue pointer ("expected an object, got " ^ show_json json) ]

let unknown_issues pointer ~known fields =
  List.filter_map
    (fun (key, _) ->
      if List.mem key known then None
      else Some (issue (child pointer key) ("unknown field " ^ key)))
    fields

let decode_with pointer of_yojson json =
  match of_yojson json with
  | Ok value -> Ok value
  | Error message -> Error [ issue pointer message ]

let decode_option pointer of_yojson = function
  | `Null -> Ok None
  | json -> (
      match of_yojson json with
      | Ok value -> Ok (Some value)
      | Error message -> Error [ issue pointer message ])

let decode_bool pointer = function
  | `Bool _ -> Ok ()
  | json -> Error [ issue pointer ("expected a bool, got " ^ show_json json) ]

let decode_string_list pointer = function
  | `List items ->
      let rec loop index errors = function
        | [] -> if errors = [] then Ok () else Error (List.rev errors)
        | `String _ :: rest -> loop (index + 1) errors rest
        | item :: rest ->
            loop (index + 1)
              (issue (pointer_index pointer index)
                 ("expected a string, got " ^ show_json item)
              :: errors)
              rest
      in
      loop 0 [] items
  | json -> Error [ issue pointer ("expected an array, got " ^ show_json json) ]

let field_errors pointer key fields decode =
  match List.assoc_opt key fields with
  | None -> []
  | Some json -> (
      match decode (child pointer key) json with Ok _ -> [] | Error errors -> errors)

let field_part pointer key fields decode ~default =
  match List.assoc_opt key fields with
  | None -> (Some default, [])
  | Some json -> (
      match decode (child pointer key) json with
      | Ok value -> (Some value, [])
      | Error errors -> (None, errors))

let decode_header pointer json =
  match expect_object pointer json with
  | Error errors -> Error errors
  | Ok fields -> (
      let unknown = unknown_issues pointer ~known:[ "name"; "value" ] fields in
      let name =
        match List.assoc_opt "name" fields with
        | None -> Error [ issue (child pointer "name") "missing field" ]
        | Some json -> decode_with (child pointer "name") Text.t_of_yojson json
      in
      let value =
        match List.assoc_opt "value" fields with
        | None -> Error [ issue (child pointer "value") "missing field" ]
        | Some json -> decode_with (child pointer "value") Redact.t_of_yojson json
      in
      let errors =
        unknown
        @ (match name with Ok _ -> [] | Error errors -> errors)
        @ match value with Ok _ -> [] | Error errors -> errors
      in
      match (name, value) with
      | Ok name, Ok value -> Ok ({ name; value }, errors)
      | _ -> Error errors)

type collected = {
  errors : Ox_app.validation_error list;
  binary : Text.t option;
  profile_dir : Text.t option;
  socket : Text.t option;
  endpoint_known : bool;
  endpoint : Text.t option;
  headers : (int * otlp_header) list;
  headers_nonempty : bool;
  skill_roots : (int * Text.t) list;
}

let collect_chrome pointer json =
  match expect_object pointer json with
  | Error errors -> (None, None, errors)
  | Ok fields ->
      let unknown =
        unknown_issues pointer
          ~known:[ "binary"; "profile_dir"; "workspace"; "headless"; "window_size" ]
          fields
      in
      let binary, binary_errors =
        field_part pointer "binary" fields
          (fun pointer json -> decode_with pointer Text.t_of_yojson json)
          ~default:default_chrome.binary
      in
      let profile, profile_errors =
        field_part pointer "profile_dir" fields
          (fun pointer json -> decode_with pointer Text.t_of_yojson json)
          ~default:default_chrome.profile_dir
      in
      let rest =
        field_errors pointer "workspace" fields (fun pointer json ->
            decode_with pointer Text.t_of_yojson json)
        @ field_errors pointer "headless" fields decode_bool
        @ field_errors pointer "window_size" fields (fun pointer json ->
            decode_with pointer Text.t_of_yojson json)
      in
      (binary, profile, unknown @ binary_errors @ profile_errors @ rest)

let collect_object pointer json ~known decode_fields =
  match expect_object pointer json with
  | Error errors -> errors
  | Ok fields -> unknown_issues pointer ~known fields @ decode_fields fields

let collect_headers pointer fields =
  let pointer = child pointer "headers" in
  match List.assoc_opt "headers" fields with
  | None -> ([], false, [])
  | Some (`List items) ->
      let parsed =
        List.mapi
          (fun index item ->
            match decode_header (pointer_index pointer index) item with
            | Ok (header, errors) -> (Some (index, header), errors)
            | Error errors -> (None, errors))
          items
      in
      let headers = List.filter_map fst parsed in
      let errors = List.concat (List.map snd parsed) in
      (headers, items <> [], errors)
  | Some json ->
      ([], false, [ issue pointer ("expected an array, got " ^ show_json json) ])

let collect_endpoint pointer fields =
  match List.assoc_opt "endpoint" fields with
  | None -> (true, None, [])
  | Some json -> (
      match decode_option (child pointer "endpoint") Text.t_of_yojson json with
      | Ok endpoint -> (true, endpoint, [])
      | Error errors -> (false, None, errors))

let collect_otlp pointer json =
  match expect_object pointer json with
  | Error errors -> (false, None, [], false, errors)
  | Ok fields ->
      let unknown = unknown_issues pointer ~known:[ "endpoint"; "headers" ] fields in
      let known, endpoint, endpoint_errors = collect_endpoint pointer fields in
      let headers, nonempty, header_errors = collect_headers pointer fields in
      (known, endpoint, headers, nonempty, unknown @ endpoint_errors @ header_errors)

let collect json =
  match json with
  | `Assoc fields ->
      let unknown =
        unknown_issues ""
          ~known:
            [
              "chrome"; "tabs"; "expiry"; "control"; "otlp"; "models"; "handoff"; "skill";
            ]
          fields
      in
      let binary, profile_dir, chrome_errors =
        match List.assoc_opt "chrome" fields with
        | None -> (Some default_chrome.binary, Some default_chrome.profile_dir, [])
        | Some json -> collect_chrome (child "" "chrome") json
      in
      let tabs_errors =
        match List.assoc_opt "tabs" fields with
        | None -> []
        | Some json ->
            collect_object (child "" "tabs") json ~known:[ "cap" ] (fun fields ->
                field_errors (child "" "tabs") "cap" fields (fun pointer json ->
                    decode_with pointer Tab_cap.t_of_yojson json))
      in
      let expiry_errors =
        match List.assoc_opt "expiry" fields with
        | None -> []
        | Some json ->
            collect_object (child "" "expiry") json
              ~known:[ "idle_s"; "unclaimed_s"; "tombstone_s" ] (fun fields ->
                let pointer = child "" "expiry" in
                let seconds pointer json = decode_with pointer Seconds.t_of_yojson json in
                field_errors pointer "idle_s" fields seconds
                @ field_errors pointer "unclaimed_s" fields seconds
                @ field_errors pointer "tombstone_s" fields seconds)
      in
      let socket, control_errors =
        match List.assoc_opt "control" fields with
        | None -> (Some default_control.socket, [])
        | Some json -> (
            match expect_object (child "" "control") json with
            | Error errors -> (None, errors)
            | Ok section ->
                let unknown =
                  unknown_issues (child "" "control") ~known:[ "socket" ] section
                in
                let socket, errors =
                  field_part (child "" "control") "socket" section
                    (fun pointer json -> decode_with pointer Text.t_of_yojson json)
                    ~default:default_control.socket
                in
                (socket, unknown @ errors))
      in
      let endpoint_known, endpoint, headers, headers_nonempty, otlp_errors =
        match List.assoc_opt "otlp" fields with
        | None -> (true, None, [], false, [])
        | Some json -> collect_otlp (child "" "otlp") json
      in
      let models_errors =
        match List.assoc_opt "models" fields with
        | None -> []
        | Some json ->
            let pointer = child "" "models" in
            collect_object pointer json
              ~known:
                [
                  "api_key";
                  "systemone_endpoint";
                  "jev_model";
                  "chat_base_url";
                  "text_model";
                  "planner_model";
                  "planner_reasoning";
                  "planner_endpoint";
                  "choice_confidence";
                  "jev_timeout";
                  "text_timeout";
                  "planner_timeout";
                ] (fun section ->
                let text pointer json = decode_with pointer Text.t_of_yojson json in
                field_errors pointer "api_key" section (fun pointer json ->
                    decode_option pointer Redact.t_of_yojson json)
                @ field_errors pointer "systemone_endpoint" section text
                @ field_errors pointer "jev_model" section text
                @ field_errors pointer "chat_base_url" section text
                @ field_errors pointer "text_model" section text
                @ field_errors pointer "planner_model" section text
                @ field_errors pointer "planner_reasoning" section text
                @ field_errors pointer "planner_endpoint" section (fun pointer json ->
                    decode_option pointer Text.t_of_yojson json)
                @ List.concat_map
                    (fun name ->
                      field_errors pointer name section (fun pointer json ->
                          decode_with pointer Seconds.t_of_yojson json))
                    [ "jev_timeout"; "text_timeout"; "planner_timeout" ]
                @ field_errors pointer "choice_confidence" section (fun pointer json ->
                    decode_with pointer Probability.t_of_yojson json))
      in
      let skill_roots, skill_errors =
        let pointer = child "" "skill" in
        match List.assoc_opt "skill" fields with
        | None -> ([], [])
        | Some json -> (
            match expect_object pointer json with
            | Error errors -> ([], errors)
            | Ok section -> (
                let unknown = unknown_issues pointer ~known:[ "roots" ] section in
                let pointer = child pointer "roots" in
                match List.assoc_opt "roots" section with
                | None -> ([], unknown)
                | Some (`List roots) ->
                    let roots, errors =
                      List.fold_right
                        (fun (index, json) (roots, errors) ->
                          match
                            decode_with (pointer_index pointer index) Text.t_of_yojson
                              json
                          with
                          | Ok root -> ((index, root) :: roots, errors)
                          | Error problems -> (roots, problems @ errors))
                        (List.mapi (fun index json -> (index, json)) roots)
                        ([], [])
                    in
                    (roots, unknown @ errors)
                | Some json ->
                    ( [],
                      unknown
                      @ [ issue pointer ("expected an array, got " ^ show_json json) ] )))
      in
      let handoff_errors =
        match List.assoc_opt "handoff" fields with
        | None -> []
        | Some json ->
            let pointer = child "" "handoff" in
            collect_object pointer json ~known:[ "focus_command"; "notify_command" ]
              (fun section ->
                field_errors pointer "focus_command" section decode_string_list
                @ field_errors pointer "notify_command" section decode_string_list)
      in
      {
        errors =
          unknown @ chrome_errors @ tabs_errors @ expiry_errors @ control_errors
          @ otlp_errors @ models_errors @ handoff_errors @ skill_errors;
        binary;
        profile_dir;
        socket;
        endpoint_known;
        endpoint;
        headers;
        headers_nonempty;
        skill_roots;
      }
  | json ->
      {
        errors = [ issue "" ("expected an object, got " ^ show_json json) ];
        binary = None;
        profile_dir = None;
        socket = None;
        endpoint_known = false;
        endpoint = None;
        headers = [];
        headers_nonempty = false;
        skill_roots = [];
      }

let expand_text ~getenv text =
  match Text.of_string (expand ~getenv (Text.to_string text)) with
  | Ok expanded -> expanded
  | Error _ -> text

let getenv_or_empty = function Some getenv -> getenv | None -> fun _ -> None
let checking_machine getenv fs = Option.is_some getenv || Option.is_some fs

let prepared ~getenv ~fs text =
  if checking_machine getenv fs then expand_text ~getenv:(getenv_or_empty getenv) text
  else text

let indexed_header_issues headers =
  List.concat (List.map (fun (index, header) -> header_issue index header) headers)

let validation ~getenv ~fs collected =
  let otlp =
    if not collected.endpoint_known then indexed_header_issues collected.headers
    else
      let require =
        if
          collected.endpoint = None
          && (collected.headers <> [] || collected.headers_nonempty)
        then [ issue "/otlp/headers" "headers require an endpoint" ]
        else []
      in
      let endpoint =
        match collected.endpoint with
        | None -> []
        | Some endpoint -> endpoint_issues endpoint
      in
      require @ endpoint @ indexed_header_issues collected.headers
  in
  let binary =
    match (collected.binary, fs) with
    | Some text, Some fs ->
        binary_issues ~getenv:(getenv_or_empty getenv) ~fs (Text.to_string text)
    | _ -> []
  in
  let socket =
    match collected.socket with
    | None -> []
    | Some text ->
        socket_issues ~check_unset:(checking_machine getenv fs)
          (Text.to_string (prepared ~getenv ~fs text))
  in
  let profile =
    match collected.profile_dir with
    | None -> []
    | Some text ->
        profile_issues ~check_unset:(checking_machine getenv fs) ~fs
          (Text.to_string (prepared ~getenv ~fs text))
  in
  let skill =
    List.concat_map
      (fun (index, root) ->
        skill_path_issues ~check_unset:(checking_machine getenv fs) index
          (Text.to_string (prepared ~getenv ~fs root)))
      collected.skill_roots
  in
  otlp @ binary @ socket @ profile @ skill

let decode_all ?getenv ?fs json =
  let collected = collect json in
  let errors = collected.errors @ validation ~getenv ~fs collected in
  match errors with
  | [] -> (
      match t_of_yojson json with
      | Ok _ as ok -> ok
      | Error message -> Error [ issue "" message ])
  | errors -> Error errors

type write_error = { path : string; permission : bool; message : string }
(** [path] is the path the operating system refused. [permission] is true for [EACCES],
    [EPERM], and [EROFS]. [message] is [Unix.error_message] of that errno. *)

type init_error = [ `Exists of string | `Write of write_error ]

let permission_errno = function
  | Unix.EACCES | Unix.EPERM | Unix.EROFS -> true
  | _ -> false

let write_error path code =
  { path; permission = permission_errno code; message = Unix.error_message code }

(* A private directory for the file, 0700 like the runtime one: a config may hold the
   models' API key. Every level up to an existing ancestor. The errno stays on the error
   so {!init} can tell a permission failure from any other refusal. *)
let rec mkdir_errno ~caps path =
  if path = "" || path = "/" || path = "." then Ok ()
  else if Sys.file_exists path then Ok ()
  else
    match mkdir_errno ~caps (Filename.dirname path) with
    | Error _ as error -> error
    | Ok () -> (
        try
          Ox_caps.Cap_unix.mkdir ~caps path 0o700;
          Ok ()
        with Unix.Unix_error (code, _, _) -> Error code)

let ensure_dir ~caps path =
  match mkdir_errno ~caps path with
  | Ok () -> Ok ()
  | Error code -> Error (Unix.error_message code)

(* svc-x8rp: what `leash config init` writes. Without [force] an existing file is refused
   and left exactly as it was, so a typo cannot cost the operator a configuration. The
   write goes through [Unix.openfile] so a refusal keeps its errno: {!write_error} says
   whether that errno is a permission class. *)
let init ~caps ?(force = false) ~path () =
  if (not force) && Sys.file_exists path then Error (`Exists path)
  else
    let directory = Filename.dirname path in
    match mkdir_errno ~caps directory with
    | Error code -> Error (`Write (write_error directory code))
    | Ok () -> (
        try
          let fd =
            Ox_caps.Cap_unix.openfile_write ~caps path
              [ Unix.O_CREAT; Unix.O_TRUNC; Unix.O_CLOEXEC ]
              0o600
          in
          Fun.protect
            ~finally:(fun () -> Unix.close fd)
            (fun () ->
              let bytes = Bytes.of_string default_toml in
              let rec write_all offset =
                if offset < Bytes.length bytes then
                  let wrote = Unix.write fd bytes offset (Bytes.length bytes - offset) in
                  if wrote = 0 then raise (Unix.Unix_error (Unix.EIO, "write", path))
                  else write_all (offset + wrote)
              in
              write_all 0);
          Ox_caps.Cap_unix.chmod ~caps path 0o600;
          Ok path
        with Unix.Unix_error (code, _, _) -> Error (`Write (write_error path code)))
