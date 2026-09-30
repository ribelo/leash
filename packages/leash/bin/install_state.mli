(** Install-state classification for `leash status` when the control socket does not
    answer (daily-lqqn). A fixture or `systemctl show` text is the only input; this module
    never starts or queries systemd itself. *)

type observation = {
  load_state : string;
  active_state : string;
  sub_state : string;
  binary_present : bool;
}

type diagnosis = Not_installed | Stopped | Restarting | Unreachable

val unit_present : observation -> bool
(** False when the unit load state is missing, not-found, masked, or unknown. *)

val diagnose : observation -> diagnosis
(** No unit is not-installed, whether or not a binary is on PATH. An installed unit that
    is activating, deactivating, or in auto-restart is restarting. Inactive, failed, or
    dead is stopped. Anything else, including an active unit whose socket is dead, is
    unreachable. *)

val code : diagnosis -> string
val message : diagnosis -> observation -> string

val of_fixture : string -> observation
(** `load=`, `active=`, `sub=`, `binary=present|absent`. *)

val of_systemctl : binary_present:bool -> string -> observation
(** `LoadState=`, `ActiveState=`, `SubState=` lines from `systemctl show`. *)
