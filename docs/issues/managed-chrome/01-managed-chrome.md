---
status: completed
milestone: 1
---

# Managed Chrome: launch, supervise, and reach it over a pipe

## Problem Statement

Agents today drive a Chrome that a script starts ad hoc on a debugging port, with nobody supervising it and any local process able to attach. When it dies, the agent finds out by a hung command. There is no service that owns the browser, restarts it, keeps its profile separate from the human's, and offers a single private door.

## Solution

The Leash service launches one headed Chrome on its own profile with `--remote-debugging-pipe`, keeps it alive under a restart schedule, and is its only CDP client. It serves the control socket with the tab-lifecycle commands (`new`, `list`, `nav`, `close`, `status`) so an agent can open a page and see it in the live view before any richer observation exists. The milestone also runs the snapshot-source spike that ADR-0004 defers.

## User Stories

1. As an operator, I want the service to launch Chrome itself with the configured binary and a dedicated profile directory, so that agents never touch my own browser profile. ^chrome-p2n4
2. As an operator, I want Chrome launched with `--remote-debugging-pipe` and no debugging port, so that nothing but Leash can attach to a browser that holds my logins. ^chrome-9ex7
3. As an operator, I want Chrome's window to open on the configured niri workspace without taking focus, so that starting the service does not interrupt what I am doing. ^chrome-2y3t
4. As an agent, I want `leash new [url]` to create a tab and return its handle, url, and title, so that I can start working on a page in one call. ^chrome-qnul
5. As an agent, I want `leash nav <tab> <url>` to navigate and return when the document has loaded, so that my next observation sees the new page. ^chrome-1yn9
6. As an agent, I want `leash nav` and `leash new` to refuse any url that is not http(s) or about:blank, or that carries userinfo, so that I cannot be tricked into opening a local file or a javascript url. ^chrome-akz4
7. As an agent, I want `leash close <tab>` to close the tab and be idempotent for a tab I already closed, so that cleanup is safe to repeat. ^chrome-2n8n
8. As an agent, I want `leash list` to show my tabs with url and title, so that I can find the page I was working on. ^chrome-hjw9
9. As an agent, I want `leash status` to report the browser generation, open-tab count and cap, and whether Chrome is running or restarting, so that I can tell a browser problem from a page problem. ^chrome-fuao
10. As an operator, I want Chrome relaunched under a bounded backoff schedule when it exits, so that one crash does not take the service down for the day. ^chrome-qo4q
11. As an agent, I want every handle from before a relaunch to answer `tab-gone` with disposition `browser_lost`, so that I know my page is gone and why, rather than acting on a stranger's tab. ^chrome-2z2z
12. As an agent, I want requests during a relaunch to fail fast with `browser-unavailable`, so that I can retry shortly instead of hanging. ^chrome-6lfk
13. As an operator, I want the control socket created owner-only in a verified private runtime directory and never to replace a live listener or a non-socket file, so that a second instance or a stray file cannot hijack it. ^chrome-fwnu
14. As an agent, I want a malformed request to get `invalid-request` with a one-sentence reason, so that I can correct my call without reading logs. ^chrome-38a4
15. As an operator, I want `leash new` to fail at once with `tab-cap` when the cap is reached, so that a runaway agent cannot exhaust memory. ^chrome-d4mz
16. As an operator, I want the service to stop cleanly on SIGTERM: closing agent-origin tabs, leaving human-origin tabs, and terminating Chrome with a grace period, so that a restart is orderly. ^chrome-b288

## Implementation Decisions

- The service is one lexical owner composing scoped resources in order (ADR-0007): the Chrome supervisor (owning the process and the CDP session, exposing a generation and a lifecycle event stream), the tab registry (consuming the supervisor), and the control listener (consuming the registry). Chrome loss is an event on the supervisor's stream that the registry answers by bumping the generation and tombstoning every tab; siblings are never torn down for it.
- Control-protocol requests and replies are plain types with `[@@deriving yojson]` matching `docs/protocol.md`; `invalid-request` renders the deriver's error with the offending subtree. CDP messages stay raw `Yojson` (`Eta_json`) because their shape is Chrome's, not ours.
- The listener's handler budget (Eta ticket `etaipc`, story `etaipc-4t2y`) is derived per decoded command: one second for everything except `wait` (its own bounded timeout), `handoff` (its timeout, default 15 minutes) and `drive` (its deadline). The one-second ingress deadline on reading the request line protects against stalled peers regardless. A client disconnect cancels the running handler as Eta interruption: a `handoff` returns the tab to `Owned`; a `drive` stops after the in-flight action settles and never re-issues it.
- Chrome is spawned through eta-next's `eta_process` (`Child` with fds 3 and 4, `Supervised` for restart; eta-next spec `process`) with a pipe pair on child fds 3 and 4; the supervisor restarts it under an `Eta.Schedule` with exponential backoff capped at 30 seconds and a give-up after ten consecutive failures inside five minutes, after which `status` reports `restarting` with the failure and an operator must intervene.
- CDP framing over the pipe is NUL-delimited JSON (Leash's own ten lines over the pipe flows). Correlation is eta-next's `eta_rpc` correlator keyed on `id` and sub-keyed on `sessionId`; CDP events are its notification stream. `Target.setAutoAttach` with flatten mode gives one session per page; `Target.setDiscoverTargets` surfaces tabs opened by the human or by pages so the registry can tag them `Human`.
- Chrome flags: dedicated `--user-data-dir`, `--no-first-run`, `--no-default-browser-check`, `--hide-crash-restore-bubble`, `--remote-debugging-pipe`; headed by default. The live gate explicitly sets `chrome.headless = true` and launches with `--headless=new`. No headed browser is started during acceptance.
- Window placement is best-effort operator configuration: Chrome receives `--class=leash` and a configured workspace is retained as intent, but the service does not install or verify a niri rule. The acceptance gate is headless, so chrome-2y3t cannot be verified there and must not be reported as delivered.
- Tab handles are random 128-bit tokens with a short prefix; tombstones keep disposition for one hour after the tab is gone, after which the handle answers `unknown-tab`.
- Navigation completes at `Page.loadEventFired` or `Page.frameNavigated` followed by `Page.domContentEventFired`, bounded by 30 seconds, never network-idle. `new` with a url applies the same wait before replying (decided after the milestone-1 live run returned an empty title); `new` without a url replies at once.
- `chrome.headless` exists for the live-acceptance gate only (it runs without a display); the supported mode is headed (ADR-0003). chrome-2y3t (workspace placement) stays best effort and is checked by hand when a headed run is convenient.
- The control listener is eta-next's `eta_ipc`: 16 concurrent peers, one-second ingress deadline for reading a request line, per-command handler budget as above, owner-only socket, endpoint-ownership rules from Pie's ticket. The service itself is an `eta_app` program: Chrome supervisor, tab registry and control listener are `SERVICE` modules created in that order against the root Switch; `leash status` reads their `Status` values.
- Essential readers (the CDP pipe reader) run as named `with_background` children; Eta's `background-stop-provenance` fix is landed, so the workaround Pie's gap note describes is not needed and must not be copied.
- Config is TOML: `chrome.binary`, `chrome.profile_dir`, `chrome.workspace`, `tabs.cap`, plus the expiry and model keys used by later milestones; unknown keys are an error at boot.
- The snapshot-source spike is a tracked research bundle under `.scratch/research/snapshot-source/`: both an injected DOM script and Chrome's accessibility tree produce the element table for the same five pages; measure latency, rows, CDP calls, and name correctness against a hand-labelled list. The winner is recorded in the observation spec before milestone 2 starts.

### Shape against eta-next (as implemented for L3)

The service is an `Eta_app` program. Its components are scoped on the root Eio switch; Chrome and Tabs expose their own lifecycle rather than all implementing `Eta_app.SERVICE`:

- **`Config`**: a plain record type with `[@@deriving yojson]` (`chrome.binary`, `chrome.profile_dir`, `chrome.workspace`, `tabs.cap`, expiry durations, model keys); secrets typed `Redact.t`; constrained values as small modules with smart constructors (`Tab_cap.of_int`); `validate` and `env` (`OPENROUTER_API_KEY` override) functions handed to `Eta_app.run` (eta-next ADR-0008, row 15). `leash config check` comes free.
- **`Chrome`**: `create ~sw ?launch config {clock; mgr; logger} : t` starts an `Eta_process.Supervised`. `launch_pipe` builds two pipes, passes their child ends as blocking descriptors 3 and 4 via `Eta_process.Child.spawn`, and wraps the parent ends as a CDP transport. The default backoff doubles from one second to a 30-second cap for ten attempts. The registry consumes `Chrome.events` (`Started generation | Lost generation | Gave_up cause | Stopped`), rather than internal supervisor events. `connection` fails fast when the browser is not running.
- **`Cdp`**: NUL-delimited JSON framing over the two pipe flows, with one `Eta_rpc.Correlator` per browser generation. `Cdp.call` correlates replies by `id` and `sessionId`; `Cdp.events` exposes notifications. Chrome signals generation loss when the transport closes, and Tabs converts its `Lost` event to `browser_lost` tombstones.
- **`Tabs`**: `create ~sw ~cap ~tombstone_s {chrome; clock; logger} : t` owns handles, origin, creator ownership, generation, and disposition tombstones; it consumes Chrome lifecycle and CDP target/page events. Per-tab serialization is an `Eio.Mutex`. `stop` closes agent-origin targets through CDP and preserves human-origin targets. Snapshot and expiry sweep behavior belongs to later milestones, not this L3 implementation.
- **`Control`** (Service): deps = `{ tabs : Tabs.t; status_query : unit -> Status.t list; fs; net; clock; logger }`. `create` calls `Eta_ipc.Listener.run ~sw ~fs ~net ~clock ~path ~decode ~encode ~budget ~handler ()` with `decode`/`encode` through the protocol schema, `budget` = per-command (1 s default; `wait` its timeout; `handoff` its timeout; `drive` its deadline), and `handler` dispatching to `Tabs`. `status_query` exists before `serve` (eta-next row 9).
- **Program**: `Eta_app.run` composes `Chrome.create`, `Tabs.create`, `Eta_app.status_query`, `Control.create`, and `Eta_app.serve` on one switch; a switch finalizer calls `Tabs.stop`. SIGTERM exit-0 and Chrome retirement remain subject to the headless live gate.
- **Logging**: `env.logger` from the Door (`Eta_observability.Logger`, journal reporter); `Context.with_fields [("tab", h); ("owner", o); ("cmd", c)]` around each handled request; typed text and page content never logged (`Redact.t` for the API key).
- **Tests** use `Eta_test.run`, the fake Chrome process manager, an in-process fake CDP browser, `Control.handle` for protocol dispatch, and a temporary UNIX socket for listener ownership and a real request/reply. They cover restart, isolation, navigation completion, malformed requests, and human-tab retention; the real Chrome path is reserved for the headless live gate.

## Testing Decisions

- A good test drives the control protocol in-process and observes replies and the fake browser's received CDP messages; it never inspects registry internals.
- The fake browser is a scripted peer over a pipe pair: it answers `Target.*` and `Page.*` methods from a table, emits events on cue, and can drop the pipe to simulate a crash. This fake is the milestone's main deliverable after the service itself; later milestones extend it.
- Stories covered at the protocol seam: chrome-qnul, chrome-1yn9, chrome-akz4, chrome-2n8n, chrome-hjw9, chrome-fuao, chrome-2z2z, chrome-6lfk, chrome-38a4, chrome-d4mz.
- Stories covered with the fake browser dropping the pipe and an Eta test clock: chrome-qo4q, chrome-2z2z, chrome-6lfk.
- Stories covered by listener tests with private fixtures (existing file, live listener, unsafe directory), following Pie's control-socket tests: chrome-fwnu.
- Stories verified only by the headless live-acceptance gate against real Chrome: chrome-p2n4, chrome-9ex7, chrome-b288. Window placement (chrome-2y3t) is not achievable or verifiable headless; `--class=leash` is best-effort intent, not delivery of workspace placement.

## Live acceptance result

Ran `scripts/live-acceptance` with explicit `chrome.headless = true`, a private temporary profile and runtime directory, and the real Door socket. The result was:

```text
new: {"tab":"t_4d4e52e982cc6dbf73203b6c91415bb3","url":"https://example.com","title":"","origin":"agent","state":"owned","owner":"live","generation":1,"expires":null}
list: {"tabs":[{"tab":"t_4d4e52e982cc6dbf73203b6c91415bb3","url":"https://example.com","title":"","origin":"agent","state":"owned","owner":"live","generation":1,"expires":null}]}
close: {"closed":true}
SIGTERM: Leash exited 0
Chrome: gone; live acceptance passed (headless)
```

The gate verified the browser process was running before close and absent after SIGTERM. It does not verify workspace placement: chrome-2y3t remains best-effort/operator configured, **not delivered** by this headless gate.

L5 (`new` with a url waits for the load, chrome-qnul) re-ran the same gate afterwards:

```text
new: {"tab":"t_c6bd5ad17b8d041a835633804ec21602","url":"https://example.com/","title":"Example Domain","origin":"agent","state":"owned","owner":"live","generation":1,"expires":null}
list: {"tabs":[{"tab":"t_c6bd5ad17b8d041a835633804ec21602","url":"https://example.com/","title":"Example Domain","origin":"agent","state":"owned","owner":"live","generation":1,"expires":null}]}
close: {"closed":true}
SIGTERM: Leash exited 0
Chrome: gone; live acceptance passed (headless)
```

Chrome's *pushed* `Target.targetInfoChanged` title is the tab strip's (`"example.com"`);
the document title comes from the `Target.getTargetInfo` query the registry makes once
the load is done (recorded in `docs/cdp-shapes.md`).

## Out of Scope

Observation and actions beyond `nav` (milestone 2), ownership beyond "the creator owns it" (milestone 3), handoff, drive, the systemd unit and packaging (milestone 6).

## Further Notes

- Eta-next provides the scoped Door, process supervisor, RPC correlator, and private listener consumed above. Keep signal shutdown at the Door/child lifecycle seam rather than adding an ad hoc signal handler to Leash.
- Window placement (chrome-2y3t) is deliberately low value: the service starts rarely, so a manual move is acceptable if the niri rule does not match.
- Ten-failure give-up and the one-hour tombstone are first guesses; both are configurable and revisited with use.
- Eio finding from the Eta ticket work: `Eio_unix.Process.spawn_unix` can map child fds 3 and 4, but releasing a plain Eio switch SIGKILLs the child at once. Chrome's orderly shutdown (chrome-b288) therefore depends on `etaproc`'s SIGTERM-then-grace release, not on switch teardown.
