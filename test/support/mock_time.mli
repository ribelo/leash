(** Moves the mock clocks of [Ox_test.run] together (etagap-mono-advance).

    Ox_test.advance moves only the mock wall clock; since Ox master c440780 process grace,
    desktop command bounds and Chrome restart pauses run on the monotonic clock, so a test
    that lets time pass must move both. Remove this module when Ox_test offers a monotonic
    advance. *)

val advance :
  < clock : Eio_mock.Clock.t ; mono_clock : Eio_mock.Clock.Mono.t ; .. > ->
  Ox.Duration.t ->
  unit
(** [advance env duration] moves the mock monotonic clock forward by [duration], then the
    mock wall clock through {!Ox_test.advance}, which yields so due sleepers run.

    Suspension: may suspend at the yield inside Ox_test.advance. Cancellation: propagates
    Eio.Cancel.Cancelled from that yield. Finalizers: none. Locking: none. Cancellation
    safety: unsafe because progress is lost; both clock updates are committed before the
    yield.

    @raise Invalid_argument if the monotonic time would overflow. *)
