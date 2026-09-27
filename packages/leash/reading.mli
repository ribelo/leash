type t
(** Browser-specific reading and diagnostics. One state value per tab, never shared across
    tabs. *)

type browser = {
  call : string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result;
  now : unit -> float;
  sleep : float -> unit;
  current : unit -> string * string;
  dialog : unit -> Protocol.dialog option;
  acknowledge : unit -> Dispatch.t;
      (** One pending acknowledgement of this tab (tab-gjo0): taken before the [eval] call
          is issued and woken by the registry when the window it opened appears, or when
          the tab's own target dies. *)
  row : int -> int option;
}

val create : unit -> t

val observe : t -> at:float -> Yojson.Safe.t -> unit
(** Consume a page-session event; never answers a dialog. *)

val debug : t -> Protocol.debug_args -> (Protocol.debug_result, Protocol.error) result

val wait :
  browser -> Protocol.wait_args -> (Protocol.action_result, Protocol.error) result

val text : browser -> Protocol.text_args -> (Protocol.text_result, Protocol.error) result
val eval : browser -> Protocol.eval_args -> (Protocol.eval_result, Protocol.error) result
val shot : browser -> Protocol.shot_args -> (Protocol.shot_result, Protocol.error) result

val dialog :
  browser -> Protocol.dialog_args -> (Protocol.action_result, Protocol.error) result
