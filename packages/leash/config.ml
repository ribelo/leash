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

type chrome = {
  binary : Text.t;
  profile_dir : Text.t;
  workspace : Text.t;
  headless : bool; [@default false]
}
[@@deriving yojson]
(** The browser the service owns. [headless] defaults to false: production runs a headed
    browser on the configured workspace, and only the live-acceptance gate or an operator
    turns it on. *)

type tabs = { cap : Tab_cap.t } [@@deriving yojson]

type expiry = { idle_s : Seconds.t; unclaimed_s : Seconds.t; tombstone_s : Seconds.t }
[@@deriving yojson]

type models = { api_key : Redact.t option; jev_model : Text.t; text_model : Text.t }
[@@deriving yojson]

type t = { chrome : chrome; tabs : tabs; expiry : expiry; models : models }
[@@deriving yojson]

let env ~getenv config =
  match getenv "OPENROUTER_API_KEY" with
  | Some key when String.trim key <> "" ->
      { config with models = { config.models with api_key = Some (Redact.make key) } }
  | Some _ | None -> config

let spec : t Eta_app.Config.t = { of_yojson = t_of_yojson; yojson_of_t; env }

let chrome_config (chrome : chrome) =
  Chrome.make
    ~binary:(Text.to_string chrome.binary)
    ~profile_dir:(Text.to_string chrome.profile_dir)
    ~workspace:(Text.to_string chrome.workspace)
    ~headless:chrome.headless ()

let validate_paths ~fs config =
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
  let ( let* ) = Result.bind in
  let* () =
    check "/chrome/binary" (Text.to_string config.chrome.binary) `Regular_file 0o100
  in
  let profile = Text.to_string config.chrome.profile_dir in
  let parent = Filename.dirname profile in
  match Eio.Path.kind ~follow:true Eio.Path.(fs / profile) with
  | `Directory -> check "/chrome/profile_dir" profile `Directory 0o700
  | `Not_found -> check "/chrome/profile_dir" parent `Directory 0o300
  | _ -> error "/chrome/profile_dir" "not a directory"

let validate (env : Eio_unix.Stdenv.base Eta_app.Env.t) config =
  validate_paths ~fs:env.base#fs config
