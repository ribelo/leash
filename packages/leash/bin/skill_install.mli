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
  roots:string list ->
  path:string option ->
  force:bool ->
  no_input:bool ->
  dry_run:bool ->
  stdin_is_tty:bool ->
  confirm:(requested_action -> string -> bool) ->
  (outcome list, error) result
(** Suspension: may suspend in the supplied confirmation callback; filesystem work is
    synchronous. Cancellation: propagates, not converted into an installation failure.
    Finalizers: installation cleanup removes staging directories and restores failed
    replacements; completed roots remain installed. Locking: no shared installation mutex;
    sibling paths and renames implement each replacement. Cancellation safety: safe to
    re-run; completed current bundles are recognized before replacement or confirmation.
*)

val show : string
(** The stamped entrypoint, exactly as installed. *)

val status :
  caps:< Ox_caps.Cap.fs_read ; .. > -> home:string -> roots:string list -> Yojson.Safe.t
(** Inspect configured [roots], or discovered defaults when the list is empty, without
    creating directories. A stale stamp, modified content or unreadable install is stale;
    absent installs are missing.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson inspection helpers; filesystem inspection
    is synchronous. Cancellation: propagates, not converted into a stale stamp.
    Finalizers: close owned input channels. Locking: none; inspection does not reserve an
    installation. Cancellation safety: safe to re-run; no files are written. *)
