type observation = {
  snapshot : Protocol.snapshot;
  text : string;
  can_scroll_down : bool;
  can_scroll_up : bool;
  fingerprint : string;
}
(** L21 (drive-8n2z): domain-owned steps of a drive. [run] alone installs the
    Observe/Decide/Act handler; its token is local and required for each operation, so a
    caller cannot perform an unhandled operation. The continuation remains in this fiber.
    A later inspector can suspend at Decide without changing the loop. *)

type handler = {
  observe : unit -> (observation, Protocol.error) result;
  decide : Jev_request.request -> (Jev_request.decision, Protocol.error) result;
  act :
    observation -> Jev_request.decision -> (Protocol.action_result, Protocol.error) result;
}

val run :
  handler:handler ->
  now:(unit -> float) ->
  model:string ->
  args:Protocol.drive_args ->
  dry_run:bool ->
  (Protocol.drive_result, Protocol.error) result
(** Scripted tests provide [handler] closures; production uses the same computation under
    a tab's action lock. A dry run observes and decides once, never invoking Act. *)
