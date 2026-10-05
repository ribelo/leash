(** The human-facing side of a handoff: the two best-effort desktop steps that raise the
    live view and tell the human what is asked (hand-04rb hand-phof hand-rg9h).

    Both commands come from the [handoff] section of the config, and each argv element is
    a template. [{tab}] is the handle, [{reason}], [{url}] and [{title}] are the tab as
    the handoff found it, and [{window_id}] — the focus command's own placeholder — is the
    niri window id of the managed Chrome, found by app id [leash] and then by title; a
    command that asks for it and a window that cannot be found is skipped. Nothing runs
    through a shell: an element becomes exactly one argument however many spaces or quotes
    it carries, and a value is inserted once, never re-scanned. An empty command list
    turns that step off.

    Focus is bounded: a command that has not exited within five seconds is stopped and the
    step fails. The notification command instead runs for as long as the handoff does, so
    its Done action can arrive at any moment; it is stopped, with the same five-second
    retirement grace, when the handoff ends by any path. That command prints the name of
    the action the human took on its stdout, and a line [done] resumes the tab — which is
    what [notify-send --action done=Done] prints when Done is clicked. *)

type commands = { focus_command : string list; notify_command : string list }

type context = { tab : Protocol.Handle.t; reason : string; url : string; title : string }
(** What a handoff knows when the human-facing steps run: what to substitute into a
    command's argv. *)

type t

type caps = < Ox_caps.Cap.fork ; Ox_caps.Cap.exec ; Ox_caps.Cap.fs_write >
(** The two commands are programs the desktop steps start (^ncaps-4tjy). *)

val create :
  caps:caps ->
  clock:'clock Eio.Time.clock ->
  mgr:'mgr Eio_unix.Process.mgr ->
  commands ->
  t
(** One command's whole life, over {!Ox_process.Child} with a five-second retirement
    grace: spawned on [sw], its stdout lines handed to the step that asked for it, [Ok]
    for a zero exit and [Error reason] for anything else. A command stopped because [sw]
    was released — the handoff it belonged to ended — is cancelled, not reported:
    {!notify} runs on its caller's switch for exactly that reason. A command that cannot
    be started at all — a missing binary, an exec that fails — is an [Error], not a
    defect: the caller turns it into a warning.

    Suspension: never suspends at construction; commands run only through the returned
    methods. Cancellation: not a cancellation point at construction. Finalizers: none
    registered by construction; command methods own their child scopes. Locking: none at
    construction. Cancellation safety: safe to re-run; construction spawns no process. *)

val disabled : t
(** Neither step is configured, so nothing is ever run and no clock or process manager is
    needed. A registry whose tests do not exercise the human-facing side uses it. *)

val focus : t -> context -> (unit, string) result
(** hand-04rb: raise the managed Chrome's window on the tab (or skip when the command asks
    for a window that is not there). *)

val notify :
  t ->
  sw:Eio.Switch.t ->
  context ->
  on_done:(unit -> unit) ->
  on_cancel:(unit -> unit) ->
  (unit, string) result
(** hand-phof: show the human the reason and the Done action, calling [on_done] when the
    Done action's name reaches stdout. [on_cancel] is called for the Cancel action or a
    successful command exit without a selected action (notification dismissal). The first
    action wins. A failed command or fiber cancellation is not dismissal. Blocks for the
    command's whole life: the caller forks it on the handoff's switch so the handoff
    ending stops it.

    Suspension: may suspend while spawning, reading stdout, waiting for the command, or
    running a callback. Cancellation: propagates and is not a notification dismissal.
    Finalizers: sw owns managed process retirement and stdout cleanup. Locking: no shared
    mutex; the first-action flag belongs to this call. Cancellation safety: unsafe because
    progress is lost; an action callback may already have run, so never replay an
    uncertain notification. *)

val notifier :
  caps:caps ->
  clock:'clock Eio.Time.clock ->
  mgr:'mgr Eio_unix.Process.mgr ->
  command:string list ->
  string ->
  (unit, string) result
(** notif-7pha: non-blocking-kind notification, a five-second bounded command with
    [{message}] substituted as one argv element; [] disables it.

    Suspension: may suspend for the bounded command when applying the returned notifier.
    Cancellation: propagates after scoped process retirement. Finalizers: each invocation
    owns a child switch and its managed process. Locking: none; notifications are
    independent commands. Cancellation safety: unsafe because progress is lost; delivery
    may precede cancellation, so repeating can duplicate the notification. *)
