type observation = {
  snapshot : Protocol.snapshot;
  text : string;
  can_scroll_down : bool;
  can_scroll_up : bool;
  fingerprint : string;
}
(** L21 (drive-8n2z): domain-owned steps of a drive. [run] alone installs the
    Observe/Decide/Text/Act handler; its token is local and required for each operation,
    so a caller cannot perform an unhandled operation. The continuation remains in this
    fiber. A later inspector can suspend at Decide without changing the loop.

    L22 (drive-ls3c) adds [text_value]: a [type_text] step asks the text helper — one more
    model call, so one more operation — and the value it answers is what [act] writes. *)

type handler = {
  observe : unit -> (observation, Protocol.error) result;
  decide : Jev_request.request -> (Jev_request.decision, Protocol.error) result;
  text_value : Text_helper.context -> (string option, Protocol.error) result;
      (** The text helper's one call: [Some value] is the text to type, [None] the model's
          null — the value is missing, and the drive ends [blocked] naming the field — and
          [Error] a helper failure, which ends the drive like any other model failure. A
          dry run and every operation but [type_text] never ask. *)
  act :
    observation ->
    Jev_request.decision ->
    text:string option ->
    (Protocol.action_result, Protocol.error) result;
      (** Performs the chosen operation. [text] is the helper's value for a [type_text]
          step and [None] for every other; a [type_text] act without one is a defect. The
          fill revalidates action-time, so a stale row refuses [stale-snapshot] and the
          loop observes and decides again. *)
}

val run :
  handler:handler ->
  now:(unit -> float) ->
  model:string ->
  args:Protocol.drive_args ->
  dry_run:bool ->
  (Protocol.drive_result, Protocol.error) result
(** Scripted tests provide [handler] closures; production uses the same computation under
    a tab's action lock. A dry run observes and decides once: it never asks the text
    helper and never invokes Act. A [text_value] success is recorded as the step's [text]
    (drive-xjh6), and a value the helper answers for an unchanged context is reused
    (drive-ls3c). *)
