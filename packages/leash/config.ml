(** The service configuration: one plain record with derived codecs, secret fields typed
    {!Eta_observability.Redact.t}, and constrained values in small modules with smart
    constructors and their own codecs (ADR-0009). *)

module Redact = Eta_observability.Redact

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

type models = {
  api_key : Redact.t option;
  systemone_endpoint : Text.t; [@json.default default_systemone_endpoint]
  jev_model : Text.t; [@json.default default_jev_model]
  chat_base_url : Text.t; [@json.default default_chat_base_url]
  text_model : Text.t; [@json.default default_text_model]
  planner_model : Text.t; [@json.default default_planner_model]
  planner_reasoning : Text.t; [@json.default default_planner_reasoning]
  planner_endpoint : Text.t option;
}
[@@deriving yojson]

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
  }

let default_focus_command =
  [ "niri"; "msg"; "action"; "focus-window"; "--id"; "{window_id}" ]

let default_notify_command = [ "notify-send"; "--action"; "done=Done"; "{reason}" ]

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
# planner_endpoint = "https://openrouter.ai/api/v1/chat/completions"
#                             # default: chat_base_url + /chat/completions
#
# [handoff]
# focus_command = %s
# notify_command = %s
|}
    default_binary default_profile_dir default_workspace default_cap default_idle_s
    default_unclaimed_s default_tombstone_s default_socket default_systemone_endpoint
    default_jev_model default_chat_base_url default_text_model default_planner_model
    default_planner_reasoning
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
  }

let spec : t Eta_app.Config.t = { of_yojson = t_of_yojson; yojson_of_t; env }

let chrome_config (chrome : chrome) =
  Chrome.make
    ~binary:(Text.to_string chrome.binary)
    ~profile_dir:(Text.to_string chrome.profile_dir)
    ~workspace:(Text.to_string chrome.workspace)
    ~headless:chrome.headless
    ~window_size:(Text.to_string chrome.window_size)
    ()

let validate_otlp config =
  let error pointer message = Error [ { Eta_app.Config.pointer; message } ] in
  let ( let* ) = Result.bind in
  let* () =
    match config.otlp.endpoint with
    | None when config.otlp.headers <> [] ->
        error "/otlp/headers" "headers require an endpoint"
    | None -> Ok ()
    | Some endpoint -> (
        match Eta_http.Url.parse (Text.to_string endpoint) with
        | Error _ -> error "/otlp/endpoint" "must be an http(s) URL without userinfo"
        | Ok url when Eta_http.Url.query url <> None || Eta_http.Url.fragment url <> None
          ->
            error "/otlp/endpoint" "query and fragment are not allowed"
        | Ok _ -> Ok ())
  in
  let token c =
    match c with 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' -> true | _ -> false
  in
  let rec headers i = function
    | [] -> Ok ()
    | header :: rest ->
        let name = Text.to_string header.name in
        let value = Redact.expose header.value in
        if not (String.for_all token name) then
          error (Printf.sprintf "/otlp/headers/%d/name" i) "invalid HTTP header name"
        else if String.contains value '\n' || String.contains value '\r' then
          error (Printf.sprintf "/otlp/headers/%d/value" i) "invalid HTTP header value"
        else headers (i + 1) rest
  in
  headers 0 config.otlp.headers

let validate_paths ?(getenv = Sys.getenv_opt) ~fs config =
  let error pointer message = Error [ { Eta_app.Config.pointer; message } ] in
  let check pointer path expected permissions =
    let path = Eio.Path.(fs / path) in
    try
      let stat = Eio.Path.stat ~follow:true path in
      if stat.Eio.File.Stat.kind <> expected then error pointer "wrong file type"
      else if stat.perm land permissions <> permissions then
        error pointer "insufficient permissions"
      else Ok ()
    with Eio.Io _ -> error pointer "path missing or unreadable"
  in
  let executable path =
    try
      let stat = Eio.Path.stat ~follow:true Eio.Path.(fs / path) in
      stat.Eio.File.Stat.kind = `Regular_file && stat.perm land 0o100 <> 0
    with Eio.Io _ -> false
  in
  let ( let* ) = Result.bind in
  let* () = validate_otlp config in
  (* svc-x8rp: the default binary is a bare name — found on PATH — so a name without a
     slash is resolved there first, and one nothing provides is a failure by pointer
     rather than a Chrome that never starts. *)
  let name = Text.to_string config.chrome.binary in
  let on_path =
    Option.bind (getenv "PATH") (fun path ->
        String.split_on_char ':' path
        |> List.filter_map (fun dir ->
            if dir = "" then None else Some (Filename.concat dir name))
        |> List.find_opt executable)
  in
  let* () =
    if String.contains name '/' then check "/chrome/binary" name `Regular_file 0o100
    else
      match on_path with
      | Some path -> check "/chrome/binary" path `Regular_file 0o100
      | None -> error "/chrome/binary" (Printf.sprintf "%s is not on PATH" name)
  in
  (* svc-o4wt: the configured socket goes nowhere until it is a real absolute path; a
     placeholder an unset variable left behind says which field needs the variable. *)
  let* () =
    let socket = Text.to_string config.control.socket in
    if String.contains socket '$' then
      error "/control/socket" "the environment variable in this path is unset"
    else if Filename.is_relative socket then
      error "/control/socket" "must be an absolute path"
    else Ok ()
  in
  let profile = Text.to_string config.chrome.profile_dir in
  let* () =
    if String.contains profile '$' then
      error "/chrome/profile_dir" "the environment variable in this path is unset"
    else Ok ()
  in
  match Eio.Path.kind ~follow:true Eio.Path.(fs / profile) with
  | `Directory -> check "/chrome/profile_dir" profile `Directory 0o700
  | `Not_found ->
      (* svc-x8rp: the default profile is [$XDG_DATA_HOME/leash/profile], which a first
         run has not created yet, so what must be writable is the nearest ancestor that
         does exist; {!ensure_dir} makes the rest before Chrome starts. *)
      let rec nearest path =
        let parent = Filename.dirname path in
        if parent = path then path
        else
          match Eio.Path.kind ~follow:true Eio.Path.(fs / parent) with
          | `Not_found -> nearest parent
          | _ -> parent
      in
      check "/chrome/profile_dir" (nearest profile) `Directory 0o300
  | _ -> error "/chrome/profile_dir" "not a directory"

let validate (env : Eio_unix.Stdenv.base Eta_app.Env.t) config =
  validate_paths ~fs:env.base#fs config

type init_error = [ `Exists of string | `Write of string ]

(* A private directory for the file, 0700 like the runtime one: a config may hold the
   models' API key. Every level up to an existing ancestor. *)
let rec ensure_dir path =
  if path = "" || path = "/" || path = "." then Ok ()
  else if Sys.file_exists path then Ok ()
  else
    match ensure_dir (Filename.dirname path) with
    | Error _ as error -> error
    | Ok () -> (
        try
          Unix.mkdir path 0o700;
          Ok ()
        with Unix.Unix_error (code, _, _) -> Error (Unix.error_message code))

(* svc-x8rp: what `leash config init` writes. Without [force] an existing file is refused
   and left exactly as it was, so a typo cannot cost the operator a configuration. *)
let init ?(force = false) ~path () =
  if (not force) && Sys.file_exists path then Error (`Exists path)
  else
    match ensure_dir (Filename.dirname path) with
    | Error message -> Error (`Write message)
    | Ok () -> (
        try
          let channel =
            open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 path
          in
          Fun.protect
            ~finally:(fun () -> close_out channel)
            (fun () -> output_string channel default_toml);
          Unix.chmod path 0o600;
          Ok path
        with Sys_error message -> Error (`Write message))
