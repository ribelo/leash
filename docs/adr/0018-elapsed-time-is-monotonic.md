# Elapsed time is monotonic

Decision of the operator, 2026-11-05, when Leash moved onto Ox master c440780. That Ox revision (safe-p9cw, safe-8peq, safe-5a9k) runs process grace, timeouts, supervisor backoff and OTLP export cadence on `Eio.Time.Mono`, and its `ox-monotonic-elapsed-time` gate refuses wall-clock values that measure elapsed time. A wall-clock correction (NTP, a manual change) would otherwise shorten or stretch a deadline of a service that runs for days.

Every elapsed budget, sleep and timeout that Leash owns is measured on the monotonic clock: the tab registry's `now`, `sleep`, capture, load and handoff deadlines, idle and tombstone ages, the download-page bootstrap, the models service's drive deadlines, desktop command bounds, Chrome's restart pause and backoff, and the CLI's `--timeout`. The wall clock stays only where a time of day is meant: debug-log timestamps, trace file names and times, and the clocks Ox's own HTTP, RPC, IPC and model clients take. `Tabs.deps` and `Chrome.deps` carry both clocks; `Models.create` takes both.

Tests move both mock clocks together through `Leash_test_support.Mock_time.advance` (etagap-mono-advance in `docs/missing-ox-api.md`) and assert elapsed time with `Mock_time.mono_seconds`. The rejected alternative was to keep wall-clock deadlines and annotate the tests the gate flagged.
