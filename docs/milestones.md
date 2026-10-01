# Milestones

The spine of the plan. Each milestone is one spec under `docs/issues/`; each spec lists the Ox tickets it depends on. We are at milestone 0.

**Ox branch (ADR-0008):** Leash builds on `ox`, not v1. The Ox ticket names below refer to v1 tickets that are superseded for Leash; the same capabilities are pulled into ox from Leash's story IDs when milestone 1 starts. `docs/ox-delivery-map.md` carries the details.

| # | Milestone | Spec | Depends on Ox |
| --- | --- | --- | --- |
| 0 | Planning: vocabulary, ADRs, specs, Ox tickets | this document | — |
| 1 | Managed Chrome: launch, supervise, pipe CDP, control socket, `new/list/nav/close`, snapshot-source spike | `docs/issues/managed-chrome/` | `etaproc`, `etarpc`, `etaipc` |
| 2 | Observation and actions: `snap click fill press select scroll wait text eval shot debug dialog` | `docs/issues/tab-observation-and-actions/` | — |
| 3 | Tab attribution and two-stage expiry, superseded by L49 / ADR-0010 | `docs/issues/tab-ownership/` | — |
| 4 | Human handoff: `handoff resume`, niri focus, notification with action | `docs/issues/human-handoff/` | — |
| 5 | Drive: JEV loop, text helper, trace | `docs/issues/drive/` | `etaso`, `etaor` |
| 6 | Service packaging: systemd user unit, config, live-acceptance gate, replacing the chrome-cdp script | `docs/issues/service-packaging/` | `etadoor` (else an `etagap` workaround) |

Order is by dependency, not by value: 3 before 4 because handoff needs a tab; 5 last because it is a client of everything else.

## Ox tickets

Recorded in `/home/ribelo/projects/ribelo/ocaml/ox/docs/issues/`:

- `process-scoped-child/01-process-scoped-child.md` (`etaproc`): scoped child process with inherited fds (Eio 1.3+ox `spawn_unix` supports child fds 3/4), typed exit, SIGTERM-grace-then-SIGKILL release (a bare Eio switch release SIGKILLs at once), supervised restart with a generation counter.
- `stream-rpc-correlator/01-stream-rpc-correlator.md` (`etarpc`): request/reply correlation over a duplex message stream with an injected id extractor/setter and optional session sub-key; notifications as a stream.
- `ipc-control-listener/01-ipc-control-listener.md` (`etaipc`): Unix-socket control listener with Pie's endpoint rules, mode 0600, bounded peers and deadlines.
- `main-door-cause-diagnostics/01-main-door-cause-diagnostics.md` (`etadoor`): `run_main` prints the full cause for defects and composites instead of nothing (found by the audit; milestone 6).
- `openrouter-reasoning-enabled/01-openrouter-reasoning-enabled.md` (`etaor`): `reasoning.enabled = false` for the text helper (milestone 5).
- `ai-openrouter-systemone/01-ai-openrouter-systemone.md` (`etaso`): fail-closed System One client for JEV (the SmartRouter TypeScript client only checks the top-level shape; the Ox one validates the declared contract).

## Later, deliberately not now

- Headless mode with a screencast web viewer (ADR-0003).
- iframes, shadow roots, file upload/download, batch steps, CDP event subscriptions, resource timings.
- An HTTP adapter or a DSH plugin over the control protocol.
- Persisting tab handles across a service restart.
