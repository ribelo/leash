type chrome = { binary : string; profile_dir : string; workspace : string }
type tabs = { cap : int }
type expiry = { idle_s : int; unclaimed_s : int; tombstone_s : int }
type models = { api_key : string option; jev_model : string; text_model : string }
type t = { chrome : chrome; tabs : tabs; expiry : expiry; models : models }

val schema : t Eta_schema.t
(** Closed TOML configuration; the API key is redacted and may be supplied with
    [OPENROUTER_API_KEY]. Paths are checked at service start by [validate_paths]. *)

type validation_error = { pointer : string; message : string }

val validate_paths : fs:_ Eio.Path.t -> t -> (unit, validation_error list) result
(** Non-mutating filesystem validation. Errors carry JSON pointers and messages. *)
