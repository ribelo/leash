(** The service configuration, decoded and validated by the Door. *)

module Redact = Eta_observability.Redact
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
}
(** [headless] defaults to false when the file does not say; production starts a headed
    browser. *)

type tabs = { cap : Tab_cap.t }
type expiry = { idle_s : Seconds.t; unclaimed_s : Seconds.t; tombstone_s : Seconds.t }
type models = { api_key : Redact.t option; jev_model : Text.t; text_model : Text.t }
type t = { chrome : chrome; tabs : tabs; expiry : expiry; models : models }

val t_of_yojson : Yojson.Safe.t -> (t, string) result
(** The derived decoder: an unknown key or a bad value is reported with its dotted path.
*)

val yojson_of_t : t -> Yojson.Safe.t
(** The derived encoder [config check] prints; the API key renders as ["<redacted>"]. *)

val env : getenv:(string -> string option) -> t -> t
(** Environment overrides: a non-empty [OPENROUTER_API_KEY] replaces the file's key. *)

val spec : t Eta_app.Config.t
(** The Door's bundle: the derived codec above plus {!env}. *)

val chrome_config : chrome -> Chrome.config
(** The [chrome] section as {!Chrome.config}, for the program that creates the service. *)

val validate_paths : fs:_ Eio.Path.t -> t -> (unit, Eta_app.validation_error list) result
(** Non-mutating filesystem validation with the filesystem passed explicitly. Errors carry
    JSON pointers and messages. *)

val validate :
  Eio_unix.Stdenv.base Eta_app.Env.t -> t -> (unit, Eta_app.validation_error list) result
(** The Door's validator: {!validate_paths} against the environment's filesystem. *)
