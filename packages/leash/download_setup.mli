(** Initialize Chrome's persisted download history before replacing its delegate. *)

val prepare :
  clock:_ Eio.Time.clock ->
  cdp:Cdp.t ->
  on_target:(string -> unit) ->
  (unit, [ `Timeout | `Bootstrap of string ]) result
(** Uses a background setup target, closes it even on failure, and waits at most five
    seconds for Chrome's downloads page to acknowledge loading history. [on_target]
    identifies the internal target before attachment so it never enters the tab ledger. *)
