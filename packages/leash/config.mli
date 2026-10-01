(** The service configuration, decoded and validated by the Door. *)

module Redact = Ox_observability.Redact
(** Secrets travel wrapped: a config file's [api_key] encodes as ["<redacted>"] on every
    rendering path. *)

(** The tab cap: positive by construction. *)
module Tab_cap : sig
  type t

  val of_int : int -> (t, string) result
  val to_int : t -> int
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** An expiry duration in seconds: positive by construction. *)
module Seconds : sig
  type t

  val of_int : int -> (t, string) result
  val to_int : t -> int
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** A finite probability in [0, 1]. *)
module Probability : sig
  type t

  val of_float : float -> (t, string) result
  val to_float : t -> float
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

(** A non-empty text value. *)
module Text : sig
  type t

  val of_string : string -> (t, string) result
  val to_string : t -> string
  val t_of_yojson : Yojson.Safe.t -> (t, string) result
  val yojson_of_t : t -> Yojson.Safe.t
end

type chrome = {
  binary : Text.t;
  profile_dir : Text.t;
  workspace : Text.t;
  headless : bool;
  window_size : Text.t;
}
(** svc-x8rp: [binary] defaults to ["google-chrome-stable"] — a bare name
    {!validate_paths} looks up on [PATH] — and [profile_dir] to
    ["$XDG_DATA_HOME/leash/profile"] ([$HOME/.local/share] when the variable is unset),
    both expanded by {!env}. [headless] defaults to false; production starts a headed
    browser. [window_size] defaults to ["1366,900"] and is only passed to headless Chrome.
*)

type tabs = { cap : Tab_cap.t }
type expiry = { idle_s : Seconds.t; tombstone_s : Seconds.t }

type control = { socket : Text.t }
(** svc-o4wt: the control socket the service listens on and the CLI connects to, a full
    path, defaulting to ["$XDG_RUNTIME_DIR/leash/control.sock"]; {!env} expands the
    variable. *)

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
      (** Per-attempt provider timeouts in seconds (10, 10, 60); the caller deadline
          bounds the entire call including retries. daily-9ggi. *)
  choice_confidence : Probability.t;
      (** Top playbook probability below which Luna reviews the choice; default 0.7. *)
}
(** drive-e7oi drive-yqxg: the models section. [api_key] is absent when the file does not
    carry one and the environment does not either; {!env} fills it from
    [OPENROUTER_API_KEY], and nothing but {!Ox_ai.Bearer.header} ever reveals it.

    [systemone_endpoint] and [chat_base_url] default to OpenRouter's
    [https://openrouter.ai/api/v1/systemone] and [https://openrouter.ai/api/v1];
    TypeSafe's direct endpoint ([https://api.typesafe.ai/v1/systemone]) is accepted
    unchanged because it serves the same contract, so either key works. [jev_model]
    defaults to the pinned [typesafe/jev-1.13-20260917] — the model the reply is checked
    against — and [text_model] to the text helper's [inception/mercury-2.5].

    L32 run-d99l: [planner_model] is the fallback planner's own model, default
    [openai/gpt-6-luna] through the same OpenRouter chat route; [planner_reasoning] is the
    effort that route is asked with — ["high"] by default, and ["none"] turns reasoning
    off — and [planner_endpoint], absent by default, replaces the
    [chat_base_url + "/chat/completions"] route the planner would otherwise share with the
    text helper. All three are [models] keys, flat beside the model ids they tune. *)

type handoff = { focus_command : string list; notify_command : string list }
(** hand-04rb hand-phof hand-rg9h: the two desktop commands a handoff runs, each an argv
    template whose elements may carry [{tab}], [{reason}], [{url}], and [{title}], plus
    [{window_id}] for the focus command ({!Desktop}). The defaults are the spec's:
    [niri msg action focus-window --id {window_id}] and
    [notify-send --action done=Done {reason}]. An empty list turns that step off. *)

type otlp_header = { name : Text.t; value : Redact.t }
(** A collector header; its value is redacted in config output. *)

type otlp = { endpoint : Text.t option; headers : otlp_header list }
(** svc-f4op: no endpoint means no exporter. [headers] defaults to []. TOML uses
    [[otlp.headers]] entries with [name] and [value]. *)

type traces = { enabled : bool; retention : Traces.Retention.t }

val default_traces : traces

type skill = { roots : Text.t list }
(** daily-c4cl: skills roots used by both status and skill install. Empty means automatic
    discovery; paths expand environment placeholders through env. *)

type t = {
  chrome : chrome;
  tabs : tabs;
  expiry : expiry;
  control : control;
  otlp : otlp;
  models : models;
  handoff : handoff;
  skill : skill;
  traces : traces;
}
(** svc-x8rp: every section and every field has a default, so a file that names one
    setting — or a file that is only comments — decodes: it is a configuration in which
    everything else is the default. A file that is not there at all is the Door's
    business, not the decoder's; the CLI reads it as the defaults too. *)

val default : t
(** Every default, as a value: what a file that says nothing decodes to before {!env}.
    [leash config init] writes {!default_toml}, the same values commented out. *)

val default_toml : string
(** The commented default configuration file [leash config init] writes: every setting
    commented out with the default it would set, so the file changes nothing until a line
    is uncommented. *)

type write_error = { path : string; permission : bool; message : string }
(** One operating-system refusal while {!init} creates the file. [path] is the path that
    call refused — the parent directory when creating it fails, otherwise the file.
    [permission] is true when the errno is [EACCES], [EPERM], or [EROFS]. [message] is
    [Unix.error_message] of that errno. *)

type init_error = [ `Exists of string | `Write of write_error ]
(** [`Exists path] is a file already there and no [force]. [`Write] is the operating
    system refusing the directory or the file; [permission] distinguishes a permission
    failure from any other errno. *)

val init :
  caps:< Ox_caps.Cap.fs_write ; .. > ->
  ?force:bool ->
  path:string ->
  unit ->
  (string, init_error) result
(** svc-x8rp: write {!default_toml} to [path], creating the parent directories 0700 and
    the file 0600, and answer the path written. Without [force] an existing file is left
    exactly as it was. *)

val ensure_dir : caps:< Ox_caps.Cap.fs_write ; .. > -> string -> (unit, string) result
(** Create [path] and every missing parent, 0700; an existing path is left alone. The
    service makes the configured profile directory with it before Chrome starts. *)

val t_of_yojson : Yojson.Safe.t -> (t, string) result
(** The derived decoder: an unknown key or a bad value is reported with its dotted path.
    It stops at the first problem. {!decode_all} is the pass that reports every one. *)

val decode_all :
  ?getenv:(string -> string option) ->
  ?fs:_ Eio.Path.t ->
  Yojson.Safe.t ->
  (t, Ox_app.validation_error list) result
(** [decode_all ?getenv ?fs json] is every problem in [json], not the first. ^daily-9396

    The list holds field decode failures (an unknown key, a wrong type, a missing required
    member, a smart-constructor refusal), {!validate_otlp}, and path checks. A relative
    [control.socket] is reported without [getenv]. [getenv] expands the XDG placeholders
    as {!env} does and refuses a placeholder an unset variable left behind. [fs] adds the
    filesystem checks {!validate_paths} makes; when [fs] is passed without [getenv], the
    environment is treated as empty. [Ok] is {!t_of_yojson}'s value, before {!env}, so a
    successful decode is unchanged. Apply {!env} before printing the effective
    configuration. *)

val yojson_of_t : t -> Yojson.Safe.t
(** The derived encoder [config check] prints; the API key renders as ["<redacted>"]. *)

val env : getenv:(string -> string option) -> t -> t
(** Environment overrides: a non-empty [OPENROUTER_API_KEY] replaces the file's key, and
    the XDG placeholders in [chrome.profile_dir] and [control.socket] are expanded — a
    variable that is unset leaves its placeholder for {!validate_paths} to refuse. *)

val spec : t Ox_app.Config.t
(** The Door's bundle: the derived codec above plus {!env}. *)

val chrome_config : chrome -> Chrome.config
(** The [chrome] section as {!Chrome.config}, for the program that creates the service. *)

val validate_otlp : t -> (unit, Ox_app.validation_error list) result
(** Check the optional endpoint and every collector header, without filesystem access. A
    bad endpoint does not hide a bad header. *)

val validate_paths :
  getenv:(string -> string option) ->
  fs:_ Eio.Path.t ->
  t ->
  (unit, Ox_app.validation_error list) result
(** Non-mutating filesystem validation with the filesystem passed explicitly, and the
    environment for a bare [chrome.binary] name's [PATH] lookup ({!validate} passes
    [Cap_sys.getenv_opt] over the Door's powerbox, ^ncaps-4tjy). Every problem is reported
    — {!validate_otlp}, the binary, the socket, then the profile — not only the first.
    Errors carry JSON pointers and messages. *)

val validate :
  Eio_unix.Stdenv.base Ox_app.Env.t -> t -> (unit, Ox_app.validation_error list) result
(** The Door's validator: {!validate_paths} against the environment's filesystem. *)
