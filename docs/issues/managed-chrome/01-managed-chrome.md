---
status: ready-for-agent
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
- Chrome flags: dedicated `--user-data-dir`, `--no-first-run`, `--no-default-browser-check`, `--hide-crash-restore-bubble` (a SIGKILLed Chrome must restart without a prompt; graceful exit is never relied on), `--remote-debugging-pipe`, no `--headless`. Focus emulation is enabled per page session on attach.
- Window placement is best effort and time-boxed: pass `--class=leash` and try one niri window rule on app-id, then on title. If neither matches, the operator moves the window by hand after a service start and the spec records that. No further effort.
- Tab handles are random 128-bit tokens with a short prefix; tombstones keep disposition for one hour after the tab is gone, after which the handle answers `unknown-tab`.
- Navigation completes at `Page.loadEventFired` or `Page.frameNavigated` followed by `Page.domContentEventFired`, bounded by 30 seconds, never network-idle.
- The control listener is eta-next's `eta_ipc`: 16 concurrent peers, one-second ingress deadline for reading a request line, per-command handler budget as above, owner-only socket, endpoint-ownership rules from Pie's ticket. The service itself is an `eta_app` program: Chrome supervisor, tab registry and control listener are `SERVICE` modules created in that order against the root Switch; `leash status` reads their `Status` values.
- Essential readers (the CDP pipe reader) run as named `with_background` children; Eta's `background-stop-provenance` fix is landed, so the workaround Pie's gap note describes is not needed and must not be copied.
- Config is TOML: `chrome.binary`, `chrome.profile_dir`, `chrome.workspace`, `tabs.cap`, plus the expiry and model keys used by later milestones; unknown keys are an error at boot.
- The snapshot-source spike is a tracked research bundle under `.scratch/research/snapshot-source/`: both an injected DOM script and Chrome's accessibility tree produce the element table for the same five pages; measure latency, rows, CDP calls, and name correctness against a hand-labelled list. The winner is recorded in the observation spec before milestone 2 starts.

### Shape against eta-next (re-cut 2026-09-26 after rows 0–9)

The service is an `Eta_app` program. Modules and the eta-next signatures they build on; each is a `SERVICE` (`create : sw:Eio.Switch.t -> config -> deps -> (t, error) result`, `status : t -> Status.t`):

- **`Config`**: a plain record type with `[@@deriving yojson]` (`chrome.binary`, `chrome.profile_dir`, `chrome.workspace`, `tabs.cap`, expiry durations, model keys); secrets typed `Redact.t`; constrained values as small modules with smart constructors (`Tab_cap.of_int`); `validate` and `env` (`OPENROUTER_API_KEY` override) functions handed to `Eta_app.run` (eta-next ADR-0008, row 15). `leash config check` comes free.
- **`Chrome`** (Service): deps = `{ clock; mgr : Eio_unix.Process.mgr; logger }`. `create` starts `Eta_process.Supervised.start ~sw ~clock ~schedule ~spawn` where `spawn ~sw` builds two pipes, calls `Eta_process.Child.spawn ~sw ~clock ~mgr ~argv ~grace ~fds:[ (3, child_read); (4, child_write) ] ()` with the Chrome flags of this spec, and wraps the parent ends as the CDP transport. `schedule` = `Schedule.exponential 1s` capped at 30 s, `recurs 10`. `generation` comes from `Supervised.generation`; the registry subscribes to `Supervised.events` (`Started g | Exited (g, exit) | Gave_up cause | Stopped`, the last after row 11) in a fiber under its own switch.
- **`Cdp`** (module, not a Service): NUL-delimited JSON framing over the pipe flows (`read : unit -> Yojson.Safe.t option`, `write`), and `Eta_rpc.Correlator.create ~sw ~clock ~read ~write ~id ~set_id ~session ()` with `id` reading `"id"`, `session` reading `"sessionId"`. `Cdp.call ?session ?deadline method params` is `Correlator.call`; `Cdp.events` is `Correlator.notifications` (ending with ``Closed` after row 11). One correlator per browser generation; ``Transport_closed` from any call is the registry's signal to tombstone with `Browser_lost`.
- **`Tabs`** (Service): deps = `{ chrome : Chrome.t; clock; logger }`. Owns the registry (handles, origin, owner state, snapshots, tombstones) and the expiry sweep as `Eta.Retry.repeat ~clock (Schedule.spaced 30s)` under its switch. Per-tab serialization is an `Eio.Mutex` per tab. Actions are `result`s with the protocol's error variants.
- **`Control`** (Service): deps = `{ tabs : Tabs.t; status_query : unit -> Status.t list; fs; net; clock; logger }`. `create` calls `Eta_ipc.Listener.run ~sw ~fs ~net ~clock ~path ~decode ~encode ~budget ~handler ()` with `decode`/`encode` through the protocol schema, `budget` = per-command (1 s default; `wait` its timeout; `handoff` its timeout; `drive` its deadline), and `handler` dispatching to `Tabs`. `status_query` exists before `serve` (eta-next row 9).
- **Program**: `Eta_app.run ~name:"leash" ~config:Config.schema ~pp_err @@ fun env config sw -> let* chrome = Chrome.create ~sw … in let* tabs = Tabs.create ~sw … in let query = Eta_app.status_query [Chrome.status chrome; Tabs.status tabs] in let* control = Control.create ~sw … { status_query = query; … } in Eta_app.serve ~sw ()`. Exit 0 on SIGTERM.
- **Logging**: `env.logger` from the Door (`Eta_observability.Logger`, journal reporter); `Context.with_fields [("tab", h); ("owner", o); ("cmd", c)]` around each handled request; typed text and page content never logged (`Redact.t` for the API key).
- **Tests** cross the three seams with eta-next's fakes: `Eta_test.run` with the mock clock for expiry and restart; the fake `Eio.Process.mgr` from `eta_test` for supervision; `Eio_mock.Flow` pairs scripting NUL-delimited CDP frames for the correlator; the control protocol driven in-process through `Eta_app.run_for_test`.

## Testing Decisions

- A good test drives the control protocol in-process and observes replies and the fake browser's received CDP messages; it never inspects registry internals.
- The fake browser is a scripted peer over a pipe pair: it answers `Target.*` and `Page.*` methods from a table, emits events on cue, and can drop the pipe to simulate a crash. This fake is the milestone's main deliverable after the service itself; later milestones extend it.
- Stories covered at the protocol seam: chrome-qnul, chrome-1yn9, chrome-akz4, chrome-2n8n, chrome-hjw9, chrome-fuao, chrome-2z2z, chrome-6lfk, chrome-38a4, chrome-d4mz.
- Stories covered with the fake browser dropping the pipe and an Eta test clock: chrome-qo4q, chrome-2z2z, chrome-6lfk.
- Stories covered by listener tests with private fixtures (existing file, live listener, unsafe directory), following Pie's control-socket tests: chrome-fwnu.
- Stories verified only by the live-acceptance gate against real Chrome: chrome-p2n4, chrome-9ex7, chrome-2y3t, chrome-b288.

## Out of Scope

Observation and actions beyond `nav` (milestone 2), ownership beyond "the creator owns it" (milestone 3), handoff, drive, the systemd unit and packaging (milestone 6).

## Further Notes

- Rows 0–8 of eta-next are delivered; milestone 1 starts after rows 9 and 10 (`status_query` before `serve`; the shared switch on eta-next) and should land before row 12 changes signatures only by mode annotations. Rows 11–13 improve tests and trust but do not block.
- Window placement (chrome-2y3t) is deliberately low value: the service starts rarely, so a manual move is acceptable if the niri rule does not match.
- Ten-failure give-up and the one-hour tombstone are first guesses; both are configurable and revisited with use.
- Eio finding from the Eta ticket work: `Eio_unix.Process.spawn_unix` can map child fds 3 and 4, but releasing a plain Eio switch SIGKILLs the child at once. Chrome's orderly shutdown (chrome-b288) therefore depends on `etaproc`'s SIGTERM-then-grace release, not on switch teardown.
