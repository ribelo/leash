(** A scripted stand-in for the desktop commands a handoff runs (hand-04rb hand-phof
    hand-rg9h). It records every command's argv and replays a script per command, which is
    what the real {!Leash.Desktop.process_runner} cannot be asked for without a process:
    the tests that need a child's stdout — the notification's Done action, the niri window
    list — use it. It never starts anything. *)

type step =
  | Print of string  (** one stdout line the command prints before anything else *)
  | Exit of int
  | Failure of string  (** the command cannot be started at all *)
  | Block  (** runs until the handoff ends and its switch is released *)

type t

val make : step list list -> t
(** One script per command, consumed in the order the commands are run; running out is a
    test defect, reported as the command's failure. A script that ends without a
    terminator is a command that printed its lines and exited zero. *)

val runner : t -> Leash.Desktop.runner

val spawns : t -> string list list
(** Every command's argv, in call order. *)
