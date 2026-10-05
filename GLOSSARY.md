# Leash

Leash is a local browser service for coding agents. It owns one headed Chrome on a dedicated profile, exposes that browser's tabs to agents over a private Unix socket, and can drive a single tab toward a stated goal with the JEV decision model. Agents get a browser they share with each other and with the human; the human can step in at any moment.

## Language

### Processes and surfaces

**Leash service**:
The long-running process (a systemd user unit) that supervises the managed Chrome, holds all tab state, and serves the control socket.
_Avoid_: daemon, server (unqualified)

**Managed Chrome**:
The one headed Chrome process that the Leash service launches, supervises, and talks to over CDP through a pipe. Nothing else attaches to it.
_Avoid_: the browser (when the distinction from a user's own Chrome matters)

**Browser generation**:
A counter the Leash service increments each time it launches the managed Chrome. Every handle records the generation it was issued in; a handle from an older generation is gone with reason `Browser_lost`.

**Profile**:
The Chrome user-data directory the managed Chrome runs on. One per Leash service, shared by every agent and by the human. It is the only persistent state.

**Control socket**:
The private Unix-domain socket in the user's runtime directory through which every client, including the `leash` CLI, talks to the service. Line-delimited JSON requests and replies.

**Control protocol**:
The set of request and reply shapes accepted on the control socket. The `leash` CLI is a thin encoder for it; there is no other agent-facing API.

**`leash` CLI**:
The command-line client agents and humans use. Every command maps to exactly one control-protocol request.

**Live view**:
The managed Chrome's own window, pinned by a niri window rule to a dedicated workspace. There is no streamed viewer in this version.

### Tabs and handles

**Tab**:
One CDP page target in the managed Chrome, as Leash knows it: a handle or none, an origin, a with-human flag, and the latest snapshot.

**Handle**:
The opaque 128-bit capability that names a tab in the control protocol. Holding it is the only way to act on that tab. `list` never shows one. Bound to one browser generation. Not a bookmark: a handle never outlives the tab or the generation.
_Avoid_: caller identity

**Origin**:
Who a tab belongs to for the close rule. `agent` for a tab opened through the protocol, or a human tab an agent has taken. `human` for a tab opened in the Chrome UI or by a page, until an agent takes it. Taking flips the origin to `agent` and does not flip back.

**Label**:
A free string set by `new` and shown by `list`, so a person can recognise a tab. A label is for finding, never for acting.

**Take**:
The command that mints a handle for exactly one tab matching a URL prefix, a title substring, or an exact label, and sets that tab's origin to `agent`. Several matches are ambiguous. None is no match. A tab that already has a live handle is taken. A tab with the human is not take-able.

**With human**:
A flag on a tab, not a state machine. Handoff sets it; resume clears it. While it is set, commands on the handle are refused and idleness is paused.

**Idle**:
Time since the handle was last used. Handoff pauses it.

**Idle close**:
An agent tab whose handle has not been used for the idle duration is closed. A human tab is never closed by Leash.

**Disposition**:
Why a tab is gone: `closed_by_handle`, `closed_by_idle`, `closed_externally`, or `browser_lost`. Kept as a tombstone so a later request on the handle reports the reason.

**Tab cap**:
The maximum number of open tabs in the managed Chrome. Creating a tab past the cap fails at once; nothing queues.

### Observation and action

**Snapshot**:
One atomic observation of a tab: url, title, and the element table, stamped with a snapshot id. Every snapshot invalidates the previous one for that tab.

**Element table**:
The numbered list of interactive and informative elements on the page in reading order, one row each: index, role, name, value or state. The only observation model Leash has; agents and JEV consume the same table.

**Row**:
One element-table entry. The unit that actions target.

**Target**:
A row index from the current snapshot. Actions accept nothing else: no selectors, no coordinates.

**Stale snapshot**:
A snapshot whose page has since navigated or whose table no longer matches the live DOM. An action against a stale snapshot is refused with `stale-snapshot`; the client snaps again.

**Action**:
One of the operations that changes a tab: navigate, click, fill, press, select, scroll, dialog. Actions on one tab are serialized; different tabs run concurrently.

**Dialog**:
A JavaScript alert/confirm/prompt/beforeunload that blocks the page. Leash never answers one on its own; it is reported and the holder of the handle answers it with the dialog action.

**Debug log**:
A bounded per-tab ring of console messages, uncaught exceptions, and failed requests.

### Human handoff

**Handoff**:
A request, keyed on the handle, that the human do something on that tab: a desktop notification carries the reason, the tab is with the human, and the request blocks until resume or timeout.

**Resume**:
The human's signal (notification action or `leash resume HANDLE`) that clears with-human and returns the tab to whoever holds the handle.

### Drive

**Drive**:
One request that runs the JEV loop on one tab toward one goal until `done`, `blocked`, the step cap, the deadline, or an error, and returns the trace and a final snapshot. Leash never asserts that the goal is achieved.

**Goal**:
The natural-language task the outer agent hands to one drive. A goal is one step; a `run` mission is the multi-step form, which Leash interprets through playbooks (milestone 7).

**JEV**:
TypeSafe's decision model, reached through OpenRouter's System One endpoint. It answers choice questions over a JSON state with probability distributions; it never produces free text.

**Operation**:
What JEV picks each step: `click`, `type_text`, `select`, `scroll_up`, `scroll_down`, `wait`, `done`, `blocked`.

**Speculative target**:
JEV's answer to a target question (which row to click, which row to type into) asked in the same request as the operation. Only the target matching the chosen operation is used.

**Text helper**:
The small OpenRouter language model that writes the text for a `type_text` step. Its output must parse as a small JSON object before it is typed.

**Planner**:
The optional larger model (`[models] planner_model`; absent means never called) that `drive` consults and that never acts (ADR-0015): when JEV answers `BLOCKED` (a hint JEV gets as its next goal, a handoff, a notification or a failure), when an expectation fails, and once at the end of a mission that asks for an answer, for `result`, `evidence` and whether it is done.
_Avoid_: the planner for the outer agent; that is the caller of `leash`

**Notes**:
A playbook's optional top-level free text about its site — where things are, how login works — at most 2,000 characters, shown to the planner when it is consulted on that site (ADR-0014).

**Pilot**, **leg**: _Retired_ with ADR-0012 (withdrawn by ADR-0015). There is no mission owner above JEV and no leg; JEV runs the mission.

**Playbook**:
A directory, `$XDG_CONFIG_HOME/leash/playbooks/<name>/playbook.json` plus the files beside it, that describes one site: its page kinds and its procedures, each a list of human-language steps and expectations, and its scripts. Written by the operator or the coordinating agent, never by a model or a run (ADR-0014).

**Script**:
Prepared JavaScript in a playbook — a `.js` file beside `playbook.json` or a short inline source — that a `script:` step runs in the tab's page, with a declared `returns` shape its result is validated against. Only scripts from loaded playbook directories are ever handed to the page's JavaScript engine by a run; `eval` is the agent's own, one-off expression and is a different thing.
_Avoid_: extraction script generated by a model

**Step**:
One observe, decide, act, settle cycle inside a drive, recorded in the trace.

**Trace**:
The ordered record of a drive's steps: the row chosen, the operation and its probabilities, any typed text, and the page url and title after the step.

### Platform

**Ox**:
The effect-oriented OCaml framework Leash is built on. Anything that is an effect-shaped resource, stream, or lifecycle concern and does not name the browser belongs in Ox, not in Leash. See the ADR on the Ox boundary.

**Service scope**:
The one lexical scope in the Leash service that acquires the managed Chrome, the CDP session, the tab registry, the model clients, and the control listener in dependency order and closes them in reverse. There is no component tree (ADR-0007).
