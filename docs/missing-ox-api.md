# Missing Ox APIs used by Leash

Record every workaround for an Ox gap here with an `etagap-*` ID before writing it, and remove it when Ox provides the API. Planned capabilities that are tracked as Ox tickets (`etaproc`, `etarpc`, `etaipc`, `etaso`) are not gaps: Leash waits for them.

## etagap-mono-advance

- **Gap:** `Ox_test.advance` moves only the mock wall clock of `Ox_test.run`; Ox has no helper that moves its mock monotonic clock by a duration. Since Ox master c440780 (safe-p9cw), `Ox_process.Child` grace, `Ox.Timeout.timeout_mono` and the Chrome restart pause run on the monotonic clock.
- **Workaround:** `test/support/mock_time.ml` (`Leash_test_support.Mock_time.advance`) sets the mock monotonic clock forward with `Eio_mock.Clock.Mono.set_time`, then calls `Ox_test.advance`.
- **Remove when:** Ox_test offers a monotonic advance.
