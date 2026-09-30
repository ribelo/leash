type requested_action = Install | Replace

type disposition =
  | Installed
  | Replaced
  | Current
  | Declined
  | Planned_install
  | Planned_replace

type outcome = { path : string; disposition : disposition }
type error_kind = Usage | Permission | Internal
type failure = { path : string option; kind : error_kind; message : string }
type error = { completed : outcome list; failures : failure list }

val run :
  caps:< Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. > ->
  home:string ->
  path:string option ->
  force:bool ->
  no_input:bool ->
  dry_run:bool ->
  stdin_is_tty:bool ->
  confirm:(requested_action -> string -> bool) ->
  (outcome list, error) result

val show : string
(** The stamped entrypoint, exactly as installed. *)

val status : caps:< Ox_caps.Cap.fs_read ; .. > -> home:string -> Yojson.Safe.t
(** Inspect the discovered default installs without creating directories. A stale stamp,
    modified content or unreadable install is stale; absent installs are missing. *)
