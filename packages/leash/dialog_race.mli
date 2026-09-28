type t = {
  current : unit -> Protocol.dialog option;
  subscribe : (Protocol.dialog -> unit) -> unit -> unit;
}
(** A tab's dialog-opening notification and current state. Registrations are removed when
    the wait settles, including when its fiber is cancelled. *)

val first : t -> (unit -> 'a) -> [ `Dialog of Protocol.dialog | `Value of 'a ]
(** Race one wait against the next opening on the same tab. The opening interrupts
    blocking CDP calls and sleeps; the caller maps the captured dialog to its reply. *)
