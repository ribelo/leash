# Milestones

The spine of the plan. Each milestone is one spec under `docs/issues/`; each spec lists the Eta tickets it depends on. We are at milestone 0.

| # | Milestone | Spec | Depends on Eta |
| --- | --- | --- | --- |
| 0 | Planning: vocabulary, ADRs, specs, Eta tickets | this document | — |
| 1 | Managed Chrome: launch, supervise, pipe CDP, control socket, `new/list/nav/close`, snapshot-source spike | `docs/issues/managed-chrome/` | `etaproc`, `etarpc`, `etaipc` |
| 2 | Observation and actions: `snap click fill press select scroll wait text eval shot debug dialog` | `docs/issues/tab-observation-and-actions/` | — |
| 3 | Ownership, expiry, disposition: `claim release`, two-stage TTL, tombstones, `list --all` | `docs/issues/tab-ownership/` | — |
| 4 | Human handoff: `handoff resume`, niri focus, notification with action | `docs/issues/human-handoff/` | — |
| 5 | Drive: JEV loop, text helper, trace | `docs/issues/drive/` | `etaso` |
| 6 | Service packaging: systemd user unit, config, live-acceptance gate, replacing the chrome-cdp script | `docs/issues/service-packaging/` | — |

Order is by dependency, not by value: 3 before 4 because handoff is an owner state; 5 last because it is a client of everything else.

## Eta tickets

Recorded in `/home/ribelo/projects/ribelo/ocaml/Eta/docs/issues/`:

- `process-scoped-child` (`etaproc`): scoped child process with inherited fds, typed exit, supervised restart.
- `stream-rpc-correlator` (`etarpc`): request/reply correlation over a duplex message stream, notifications as a stream.
- `ipc-control-listener` (`etaipc`): Unix-socket control listener with endpoint ownership and bounded peers.
- `ai-openrouter-systemone` (`etaso`): System One client for JEV.

## Later, deliberately not now

- Headless mode with a screencast web viewer (ADR-0003).
- iframes, shadow roots, file upload/download, batch steps, CDP event subscriptions, resource timings.
- An HTTP adapter or a DSH plugin over the control protocol.
- Persisting ownership across a service restart.
