(** A CDP call Chrome may never answer.

    Chrome withholds the reply of the call whose handler opens a popup: the
    [Input.dispatchMouseEvent] that clicked and the [Runtime.callFunctionOn] that
    evaluated an expression calling [window.open] stay unanswered while the popup exists
    (docs/cdp-shapes.md, L10). The popup itself is the acknowledgement. The registry
    watches the target stream, and {!first} settles the call with whichever of the three
    comes first: the call's reply, a target Chrome reports with this tab as its opener, or
    this tab's target destroyed. Nothing is ever sent twice (tab-1lhx), and the only bound
    left is the CDP call's own deadline (tab-0ohq tab-gjo0 own-teh1). *)

type outcome =
  | Popup
      (** A target Chrome reported names this tab as its opener: the call was delivered
          and the popup it opened is in the registry. *)
  | Gone of Protocol.error
      (** This tab's own target was destroyed: the handler closed the tab ([tab-gone] with
          [closed_externally], own-teh1). *)

type t = {
  promise : outcome Eio.Promise.t;  (** Resolved by the registry with the {!outcome}. *)
  release : unit -> unit;
      (** Called once the call has settled, by its reply or by the registry. The registry
          replaces the no-op {!make} leaves here with the closure that drops the waiter,
          so a settled dispatch leaves nothing behind. *)
}

val make : unit -> t * (outcome -> unit)
(** [make ()] is one pending acknowledgement: the value the dispatcher waits on, and the
    function the registry resolves it with. *)

val first : t -> (unit -> 'a) -> [ `Reply of 'a | `Acknowledged of outcome ]
(** [first t call] issues [call ()] and waits for the acknowledgement at the same time.
    Whichever finishes first ends the wait and the other is cancelled: a cancelled
    {!Cdp.call} drops its pending slot, and nothing is retried. *)
