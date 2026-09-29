type t
(** Browser-specific reading and diagnostics. One state value per tab, never shared across
    tabs. *)

type page_state = { loader : string; guard : (string * int) option }
(** The two facts a snapshot's currency rests on (hard-sckn): the main frame's loader id,
    and the mutation guard's epoch and count — [None] when the document carries no guard,
    which is a document no snapshot of ours was taken in. *)

type browser = {
  call : string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result;
  now : unit -> float;
  sleep : float -> unit;
  current : unit -> string * string;
  dialog : unit -> Protocol.dialog option;
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
      (** One pending acknowledgement of this tab (tab-gjo0): taken before the [eval] call
          is issued and woken by the registry when the window it opened appears, or when
          the tab's own target dies. *)
  row : int -> int option;
  snapshot_current : Protocol.Snapshot_id.t -> bool;
      (** Whether this is the tab's current snapshot (hard-b20d). *)
  baseline : Protocol.Snapshot_id.t -> page_state option;
      (** What the page looked like when that snapshot was taken: its main-frame loader id
          and mutation guard. Unlike the current snapshot it survives a navigation, which
          is exactly what `wait --changed-since` must notice (hard-sckn). *)
  probe : unit -> (page_state, Protocol.error) result;
      (** The page as it is now, read the way a snapshot reads it. *)
}

val create : unit -> t

val observe : t -> at:float -> Yojson.Safe.t -> unit
(** Consume a page-session event; never answers a dialog. *)

val debug : t -> Protocol.debug_args -> (Protocol.debug_result, Protocol.error) result

val net : t -> Protocol.net_args -> (Protocol.net_result, Protocol.error) result
(** hard-xg6y: the tab's request ring; it needs no browser call. *)

val net_body :
  browser ->
  t ->
  Protocol.net_entry_args ->
  (Protocol.net_body_result, Protocol.error) result
(** hard-ovbx: [unknown-request] for an id the ring does not hold, [body-unavailable] when
    the request has no body to read or Chrome has evicted it. *)

val net_request :
  browser ->
  t ->
  Protocol.net_entry_args ->
  (Protocol.net_request_result, Protocol.error) result
(** hard-vq5s *)

val cookies : browser -> (Protocol.cookies_result, Protocol.error) result
(** hard-ufb7: read-only, for the tab's current URL, httpOnly cookies included. *)

val storage :
  browser -> Protocol.storage_args -> (Protocol.storage_result, Protocol.error) result
(** hard-ufb7: read-only, for the page's security origin. *)

val max_wait_ms : int
(** One hour (hard-sr9v). *)

val wait :
  browser -> Protocol.wait_args -> (Protocol.action_result, Protocol.error) result

val text : browser -> Protocol.text_args -> (Protocol.text_result, Protocol.error) result
val eval : browser -> Protocol.eval_args -> (Protocol.eval_result, Protocol.error) result

val shot :
  caps:< Ox_caps.Cap.fs_write ; .. > ->
  browser ->
  Protocol.shot_args ->
  (Protocol.shot_result, Protocol.error) result
(** Writes the PNG to the caller's path, hence [fs_write] (^ncaps-4tjy). *)

val dialog :
  browser -> Protocol.dialog_args -> (Protocol.action_result, Protocol.error) result

type script_ran = { value : Yojson.Safe.t; records : int; bytes : int; elapsed_ms : int }

val script :
  browser ->
  Playbook.script ->
  args:(string * string) list ->
  (script_ran, Protocol.error) result
(** extr-8o1h extr-vgir extr-k40c: run a playbook script in the tab's page through
    [Runtime.callFunctionOn] with [awaitPromise] and [returnByValue], as the body of an
    async function of [args]; a script may [fetch] the site's own endpoints. This is the
    only function that hands script text to the browser, and it takes a
    {!Playbook.script}, which only the playbook loader makes.

    A script that threw or that the browser could not return is [script-failed]; a result
    over the script's [max_bytes] is [too-large]; a result that does not fit its [returns]
    is [script-invalid] with the path of the first mismatch; a dialog the script opened is
    [dialog-open]. Arguments over 64 KiB are [too-large]. *)

val script_syntax : browser -> Playbook.script -> (string option, Protocol.error) result
(** extr-lslp: compile the script, without calling it, as [new Function] in the page —
    which the caller makes a blank one. [None] parses; [Some message] is the engine's
    syntax error. *)
