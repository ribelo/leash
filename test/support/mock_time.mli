(** Moves the mock clocks of [Ox_test.run] together (etagap-mono-advance).

    Ox_test.advance moves only the mock wall clock; since ADR-0018 every elapsed budget,
    sleep and timeout of Leash runs on the monotonic clock, so a test that lets time pass
    must move both. Remove this module when Ox_test offers a monotonic advance. *)

val advance :
  < clock : Eio_mock.Clock.t ; mono_clock : Eio_mock.Clock.Mono.t ; .. > ->
  Ox.Duration.t ->
  unit
(** [advance env duration] moves the mock monotonic clock forward by [duration], then the
    mock wall clock through {!Ox_test.advance}, which yields so due sleepers run.

    Suspension: may suspend at the yield inside Ox_test.advance; the environment's object
    method dispatch and delegated Eio.Time.Mono, Eio_mock.Clock.Mono, Mtime, Mtime.Span,
    Ox.Duration, Ox_test and Stdlib.Int64 operations retain their own behaviour.
    Cancellation: propagates Eio.Cancel.Cancelled from that yield; the environment's
    object method dispatch and delegated Eio.Time.Mono, Eio_mock.Clock.Mono, Mtime,
    Mtime.Span, Ox.Duration, Ox_test and Stdlib.Int64 operations retain their own
    behaviour. Finalizers: none. Locking: none. Cancellation safety: unsafe because
    progress is lost; both clock updates are committed before the yield.

    @raise Invalid_argument if the monotonic time would overflow. *)

val mono_seconds : _ Eio.Time.Mono.t -> float
(** [mono_seconds clock] is [clock]'s current monotonic time in seconds, for elapsed-time
    assertions (safe-p9cw); it is not a timestamp.

    Suspension: never suspends; delegated Eio.Time.Mono, Mtime and Stdlib.Int64 operations
    retain their own behaviour. Cancellation: not a cancellation point; delegated
    Eio.Time.Mono, Mtime and Stdlib.Int64 operations retain their own behaviour.
    Finalizers: none. Locking: none. Cancellation safety: safe to re-run. *)
