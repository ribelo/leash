# Control protocol and the leash CLI

The Leash service listens on the `control.socket` path its configuration names — `$XDG_RUNTIME_DIR/leash/control.sock` by default, owner-only, in a verified private directory. A client connects, writes one JSON object per line, and reads one JSON object per line in reply. The CLI reads the same configuration file to find it (`--socket PATH` overrides it for one call, `--config FILE` names the file to read). One request per connection is the norm; the CLI opens a connection per command. Long-blocking requests (`handoff`, `drive`, `run`, `wait`) hold the connection open until they settle.

Wire shapes here are the contract; field names are stable across the CLI and any later adapter. Until 1.0 they may still change with the spec.

## Envelope

Request:

```json
{"v":1,"owner":"dsh:4f2a…","cmd":"click","args":{"tab":"t_9xk…","index":7}}
```

Reply, one of:

```json
{"ok":true,"result":{…}}
{"ok":false,"error":{"code":"stale-snapshot","message":"snapshot s_3 is stale; snap again","detail":{…}}}
```

- `owner` is required on every request. The CLI fills it from `DSH_SESSION_ID` (as `dsh:<id>`) or `--owner`; a human uses `--owner human` or whatever they like.
- `error.code` is from the closed set below. `message` is one short sentence for the agent. `detail?` is optional structured context (for `tab-gone`: the disposition; for `stale-snapshot`: the current snapshot id); it is omitted when the error carries none.

## Commands

Tab lifecycle:

| cmd | args | result |
| --- | --- | --- |
| `new` | `{url?}` | `TabInfo` |
| `list` | `{all?: bool}` | `{tabs: TabInfo[]}` |
| `claim` | `{tab}` | `TabInfo` |
| `release` | `{tab, force?}` | `{released: true}` |
| `close` | `{tab, force?}` | `{closed: true}` |
| `status` | `{}` | `{generation, tabs: {open, cap}, chrome: "running"\|"restarting", uptime_s, models: Models\|null}` |

Observation:

| cmd | args | result |
| --- | --- | --- |
| `snap` | `{tab, match?: string, limit?: int, offset?: int}` | `Snapshot` |
| `downloads` | `{tab}` | `{downloads: Download[]}` |
| `text` | `{tab, index?: int, max_chars?: int}` | `{url, title, text, truncated}` |
| `shot` | `{tab, path, full_page?: bool}` | `{path, bytes}` |
| `debug` | `{tab, limit?: int, clear?: bool}` | `{entries: DebugEntry[]}` |
| `eval` | `{tab, expression, argument?}` | `{value}` |

Actions (serialized per tab; each returns `ActionResult`):

| cmd | args |
| --- | --- |
| `nav` | `{tab, url}` |
| `click` | `{tab, snapshot, index}` |
| `fill` | `{tab, snapshot, index, text}` |
| `press` | `{tab, snapshot, index?, key}` |
| `select` | `{tab, snapshot, index, option: int}` |
| `scroll` | `{tab, direction: "up"\|"down", index?}` |
| `wait` | `{tab, until: {url_prefix?, text?, index_gone?: int, dialog?: bool}, timeout_ms?}` |
| `dialog` | `{tab, answer: "accept"\|"dismiss", text?}` |

Human handoff:

| cmd | args | result |
| --- | --- | --- |
| `handoff` | `{tab, reason, timeout_s?}` | `{resumed: true, url, title, warnings?: string[]}` |
| `resume` | `{tab}` | `{resumed: true}` |

Drive:

| cmd | args | result |
| --- | --- | --- |
| `drive` | `{tab, goal, max_steps?, deadline_s?, dry_run?}` | `{status, steps: Step[], final: Snapshot, reason?: string}` |

Run (milestone 7): one mission over the installed playbooks. `run` is the command
`leash run "<mission>"` sends; the CLI's `--tab` adds the tab field, and `--expect`
repeats a mission expectation (the argument is a list).

| cmd | args | result |
| --- | --- | --- |
| `run` | `{tab, mission, max_procedures?, deadline_s?, dry_run?, expect?: string[]}` | `{status, site: string|null, procedures: RunProcedure[], mission_expectations: RunExpectation[], planner_turns: PlannerTurn[], final: Snapshot, reason?: string}` |

## Types

A field shown as `T|null` is always present, `null` when it has no value; a field shown as
`key?` is omitted when it has no value.

```
TabInfo      = {tab, url, title, origin: "agent"|"human", state: "unowned"|"owned"|"with_human",
                owner: string|null, generation: int, expires: {stage: "release"|"close", in_s: int}|null,
                reason?: string}
Snapshot     = {snapshot: id, tab, url, title, rows: Row[], total: int, offset: int, truncated: bool, settled: bool,
                dialog: Dialog|null}
Row          = {index: int, role: string, name: string, value?: string, state?: string[],
                options?: [{index: int, label: string, value: string, selected: bool, disabled: bool}]}
                 state ⊆ {checked, unchecked, mixed, selected, expanded, collapsed, disabled, required, readonly}
                 options is the option list a select row exposes, in the select's own order, index 0 first
Dialog       = {kind: "alert"|"confirm"|"prompt"|"beforeunload", message: string}
ActionResult = {tab, url, title, snapshot: null, dialog: Dialog|null, popups: TabInfo[]}
                 snapshot is always null in this version: no snapshot is taken while an action settles; call snap
                 popups lists only tabs opened by the acted-on tab (opener), owned by the caller
Download     = {id: string, suggested_name: string, mime: string, state: "in_progress"|"completed"|"canceled", path: string|null}
                 path is null until Chrome reports a completed filePath; MIME is inferred from the extension when Chrome does not report one
DebugEntry   = {at: iso8601, kind: "console"|"exception"|"request-failed", level?: string, text: string}
Step         = {n: int, snapshot: id, operation: Operation, index: int|null, probabilities: {op: {..}, target: {..}},
                text?: string, after: {url, title}, elapsed_ms: int}
Operation    = "click"|"type_text"|"select"|"scroll_up"|"scroll_down"|"wait"|"done"|"blocked"
status (drive) = "done"|"blocked"|"step-cap"|"deadline"|"error"
                 max_steps defaults to 30; deadline_s defaults to 120; both must be positive.
RunProcedure = {slug, site, planned: bool, attempts: int,
                choice: {key: string, probabilities: {..}, confidence: float, usage: Usage|null},
                drives: [{goal, status (drive), steps: Step[], reason?: string}],
                expectations: RunExpectation[],
                outcome: "verified"|"failed"|"skipped"|"planned", elapsed_ms: int, reason?: string}
                drives is empty for "planned" (a dry run executed nothing); attempts is 2 when the
                retry-once rule replayed the procedure; planned is true when a planner turn wrote it
RunExpectation = {sentence, checker: "page_kind"|"text"|"download"|"no_dialog"|"row"|"judgment",
                  passed: bool, score: float|null}
                 score is the JEV score a judgment expectation was given, null where code decided it
PlannerTurn = {n: int, trigger: "blocked"|"failed"|"arguments",
               answer: "procedure"|"handoff"|"fail", reason?: string, usage: Usage|null}
Usage       = {input_tokens: int, output_tokens: int, cost: float}
status (run) = "done"|"blocked"|"failed"|"handoff"|"limit"|"deadline"|"error"
               max_procedures defaults to 40; deadline_s defaults to 900; both must be positive.
Models       = {configured: bool, jev_model: string, text_model: string,
                systemone_endpoint: string, chat_base_url: string}
                 the models section as configured; configured is whether an API key is present,
                 and no field ever carries the key
```

Rules:

- `drive` checks ownership, then holds the tab action lock across all observations and
  actions; no other tab command can interleave. It observes a fresh snapshot, reads
  visible page text and scroll metrics, requests one JEV decision, acts, and records a
  Step. `dry_run: true` makes exactly one Observe/Decide/trace pass and never acts, and
  never calls the text helper. A model failure is a protocol **error**
  (`model-unavailable`) with `detail: {code: string, steps: Step[]}` containing
  completed steps. Drive status `error` is reserved for non-model failures within a step
  (including dialogs or popups), not model failures. It carries `reason` naming the
  cause: the failed action or re-observe with its error code, `dialog open: <kind>`
  (the dialog itself is in the final snapshot), or the popup count. `detail.code`
  is `missing-key`
  when no API key is configured — the drive fails at its first decision and nothing is
  sent — and otherwise the provider failure's kind: `unavailable`, `timeout`,
  `authentication`, `invalid-response`, `input-too-large`, or `model-mismatch` when
  the reply names another model than the configured `jev_model` (drive-e7oi).
- A `type_text` step first asks the configured text helper: jev's `field_context` —
  the goal verbatim, the chosen row, the page's title and its text bounded at 6000 bytes
  on a character boundary, and the last six actions — as the user message of one `chat/completions` request
  to `chat_base_url + "/chat/completions"`, whose reply must parse as
  `{"text": string|null}`. The value is then written through the same action path as
  `fill`; a string over 4 KiB and a reply that is not that object are refused with
  `model-unavailable` and `detail.code: "invalid-response"`. A `null` answer is
  Drive status `blocked` with the field named in `reason` and nothing typed. The helper
  is asked once per unchanged input: a stale-row retry of the same decision reuses the
  value it already answered (drive-ls3c).
- `drive`'s decision is one System One request per step, bounded by what is left of the
  drive's `deadline_s`: the state carries the current element table, the rendered page
  text and the last ten steps' actions; the questions are the operation and one
  `<operation>_target` head per offered operation, and only the head the chosen
  operation selects is validated. A distribution that does not answer the offered
  criteria is `model-unavailable` with `code: "invalid-response"`.
- `run` reuses the tab it is given and opens one when the request names none (`tab` is
  `key?`; the tab it opened is the one `final` names, and it is left open). It checks
  ownership and then holds the tab action lock for the whole run, so no other tab command
  interleaves while it works; every step of it is one `drive` call with the
  procedure's `max_steps` and `deadline_s` (the operator's defaults of 30 and 120 s
  otherwise), bounded by what is left of the run. It is refused before it starts on a tab
  the caller does not own (`not-owner`), one the human holds (`with-human`), or one with a
  dialog open (`dialog-open`).
- The playbook level is asked at the start, after a procedure whose description or the
  mission names another installed site the run has not served yet, and once more when the
  procedure level answers BLOCKED. Its criteria are the installed playbooks by `site` and
  `description` plus `none` — playbooks are selected, never merged, and one choice never
  carries more than 255 options. A playbook other than the current one is switched to by
  navigating the same tab to its `entry` URL, so the shared profile's logins carry over.
- The procedure level is asked every turn: the current playbook's procedures (slug and
  description) plus `DONE` and `BLOCKED`. The state it and the playbook level are asked
  over is small and semantic — the mission, the site, the page kind (from the playbook's
  `pages`), the page title and URL, the last five procedures with their outcomes, and the
  arguments already known. **Page text never reaches the upper levels**; it is the
  operator level's and the checkers'.
- `{name}` placeholders in a goal or an expectation sentence are substituted from the
  run's arguments; an argument the mission does not supply is asked of the text helper
  once, and the value is reused for the rest of the run.
- A procedure's expectations are verified with the bounded wait: the checker the loader
  resolved where one applies (page kind, text, download, no dialog, row), a JEV score
  question where none does. A procedure whose expectations fail is replayed once from its
  first step and a second failure is reported to the planner. A `use` step runs the named
  procedure inline with its own expectations; an `optional` one is skipped when its first
  step ends blocked within two operator steps.
- **The DONE guard.** `DONE` is accepted only against a fresh verification of the
  mission's own expectations (the `expect` list), or — when the mission carries none — of
  the last verified procedure's expectations, re-verified at that moment. The verification
  is independent of the procedure that just ran: a confirmation page that does not show
  the mission's end state fails it, and the run then asks the planner and ends `blocked`
  naming the expectation that failed. A `DONE` nothing can verify is refused the same way.
- `dry_run: true` asks the playbook and the procedure levels and reports the chosen
  playbook, the chosen procedure with its choice and resolved checkers, and ends
  `blocked`: it navigates nothing, executes no step, and never calls the text helper.
- The endings are `done` (DONE verified), `blocked` (the loop stopped with nothing that
  can progress), `failed` (a procedure failed twice and the planner failed), `handoff`
  (the planner asked for the human; the tab is left `with_human`), `limit` (the procedure
  cap), `deadline` (the run deadline) and `error` (a dialog opened on the page — it is in
  `final.dialog`). A model or browser failure is a protocol **error**; when it is
  `model-unavailable` its `detail` carries the provider `code` and the trace completed so
  far in `detail.procedures`, so a failed mission is auditable.
- The planner is L32's (Luna). Until it lands, the production handler answers `fail` with
  the reason that names L32, so a run that stops needing judgment ends `blocked` or
  `failed` saying so.
- A run's handler budget is its `deadline_s` plus 45 seconds — the last procedure's own
  bounded expectation wait (at most 30 s) and the reply — so the listener never cancels a
  run at the instant it is due to answer.
- `status`'s `models` reports the models section — `configured` is whether an API key
  is present, and the two model ids and two endpoints are the configured ones. It is read
  from the live configuration: no probe, nothing at boot, and never the key. It is
  `null` only in a dispatch with no models service; the service always reports it.
- Ownership is checked before every tab command (ADR-0005). The `act` commands — `nav`,
  `snap`, `text`, `eval`, `shot`, `debug`, `wait`, `click`, `fill`, `press`, `select`,
  `scroll` — `dialog`, `release`, and `close` require that the caller owns the tab;
  `claim` requires that nobody does. A tab nobody owns and a tab another caller owns both
  refuse with `not-owner`; a tab handed to the human refuses with `with-human` — its
  owner's commands included, until `resume`.
- `force: true` (the CLI's `--force`) is honoured on `release` and `close` only, where it
  ignores ownership and a human's hold so a human can clean up after an agent that is
  gone; every use is logged. A `force` key on any other command is an unknown field, so
  the request is `invalid-request`.
- `downloads` requires ownership (also refuses with `with-human` during handoff). Only a download whose main frame belongs to that tab is listed; an unattributed browser event is ignored. Downloads live under the managed Chrome profile in `downloads/`, configured through `Browser.setDownloadBehavior` with `eventsEnabled: true`.
- `list` shows the caller's tabs — the ones it owns and the one the human is holding for
  it — and `list --all` every tab with its `origin`, `state`, and `owner`; `owner` is
  null exactly when `state` is `unowned`.
- `expires` is the next stage a tab faces and the whole seconds left before it: an owned
  tab faces `release` after `expiry.idle_s` with no owner action, and an unowned
  agent-origin tab faces `close` after `expiry.unclaimed_s` with nobody claiming it. It is
  `null` for a human-origin tab and for one the human holds, because no timer may take
  them.
- `handoff` hands the tab to the human and blocks while the tab is `with_human`: every
  command on it is refused with `with-human` — its owner's included — and `reason` is on
  every `TabInfo` the service reports for it, which is what `list --all` shows. The request
  ends the first of: a `resume`, which is authorized for anyone because it only ever gives
  the tab back to its owner and answers `{resumed: true, url, title}` with the page as the
  human left it, and which restarts the tab's idle clock; the deadline, `timeout_s` or
  fifteen minutes measured from the request — the human-facing steps below included — which
  answers `timeout` and gives the tab back to its owner; the agent's
  disconnect, which does the same; and the tab's disappearance, which answers `tab-gone`
  with the disposition that closed it. A forced `release` or `close` of the tab the human
  holds ends the handoff there and then rather than at the deadline: the release answers
  `not-owner` — the agent no longer owns the tab — and leaves it unowned with no `reason`,
  and the close answers `tab-gone` with its disposition. `resume` on a tab nobody is
  waiting on is `no-handoff`, so a stale notification cannot do something surprising.
- The human-facing side of a `handoff` runs in the order the story says: `Target.activateTarget`
  for the tab, then `handoff.focus_command`, then `handoff.notify_command`, whose stdout
  carries the action the human took and whose Done action (`done`, what
  `notify-send --action done=Done` prints) is a `resume`. All three are best effort by
  contract: each one that fails is a log line and a `warnings` entry on the successful
  reply — omitted when there is none — and none of them fails the handoff. A handoff that
  ends `timeout` carries the same list in `detail.warnings`, because a human who was never
  told is exactly why nobody answered. Each external command gets five seconds of its own;
  the notification instead runs for as long as the handoff does and is stopped when the
  handoff ends, however it ends.
- Expiry is one sweep every 30 seconds on the service clock. Stage 1 releases an owned tab
  idle for `idle_s`: it stays open, unowned, and claimable. Stage 2 closes an unowned
  agent-origin tab unclaimed for `unclaimed_s` with disposition `closed_by_ttl`. Any action
  its owner is allowed to take resets the idle clock, a human-origin tab is never
  auto-closed whatever its ownership history, and a handed-off tab is exempt while the
  human holds it.
- Tabs Leash did not create are discovered from Chrome's target stream. A tab opened in the
  Chrome UI, or by a page whose opener Leash does not know, appears in `list --all` with
  origin `human` and state `unowned`, and an agent claims it to work on it. A tab a page
  opens from a tab an agent owns is that agent's instead: origin `agent` and state
  `owned`. Origin and owner state are decided when the tab is first seen and never
  change; a later report about the tab moves its url and title. Leash attaches to a
  discovered tab when a command first needs its page — `claim` is such a command, and it
  enables the tab's event domains there, so `debug` covers the tab from the claim on;
  `list`, `release`, and `close` need no attachment. A discovered tab that goes away
  without Leash closing it leaves a tombstone with disposition `closed_externally`.
- Every action except `nav`, `scroll`, `wait`, and `dialog` requires the `snapshot` id it targets; it is refused with `stale-snapshot` if that is not the tab's current snapshot, if the page navigated since, if the row's node no longer resolves, or if its role and name differ from the snapshot's. An indexed `scroll` carries no id and revalidates against the tab's current snapshot.
- A row action also refuses with `row-not-actionable` when the row is disabled, has no layout box, cannot take focus, or is covered at its click point (a hit test that answers with another node than the row or one of its descendants). Clicking reads the row's geometry at that moment; scrolling and animation are never staleness.
- An action whose handler closes its own tab (a click on `window.close()`) reports `tab-gone` with `closed_externally` when the browser no longer knows the target; if the reply wins the race the action succeeds and the next command on the handle reports `tab-gone`.
- A trusted input or an `eval` whose handler opens a popup is settled by the popup itself: Chrome withholds the reply of the call whose handler opened it, so Leash waits — with no bound of its own beyond the CDP call's deadline — for whichever comes first: the call's reply, a target Chrome reports with this tab as its `openerId` (an action then lists it in `popups`, and `eval` answers `{value: null}`), or the destruction of this tab's own target (`tab-gone` with `closed_externally`). Nothing is ever dispatched twice.
- `press` with `index` focuses the row first; without it, sends the key to the page (and only the snapshot's currency is checked).
- `select` targets a native `<select>` row (role `combobox` or `listbox`); `option` is its index in the select's observed option order, and an index the select does not have is `invalid-request`. A row that is not a native select is `row-not-actionable`. The observed order is the row's `options`, read from the accessibility tree even while the select is closed — a closed select's options have no layout box and are never rows of their own (tab-5deq): each carries the `index` the action takes, its `label`, the `value` it holds, its label when it holds none, and whether it is `selected` or `disabled`.
- `ActionResult.snapshot` is null unless a snapshot was taken as part of settling; actions do not observe the page again on their own, so a caller that wants a fresh table asks for one.
- An action reply's `url` and `title` come from `Target.getTargetInfo` read after the action settled. When the action navigated the tab, that read waits — bounded like a load — for the new document to finish, so the reply, a drive step's `after`, and `list` carry the document title rather than the tab strip's formatted URL (chrome-qnul, svc-hi4f).
- `wait` conditions are ANDed; `timeout_ms` is bounded to 30 000.
- `eval` runs the expression as a function body in the page with `argument` bound; expression, argument, and result are each bounded to 64 KiB.
- `shot` writes a PNG to `path`, which must be an absolute path the service can write; the reply carries no image data.
- `snap` `match` filters rows by case-insensitive substring over role, name, and value; `limit` defaults to 120, `offset` pages; `truncated` is truthful. `settled` is false when the page kept mutating during the observation (retaken twice first); the snapshot is still usable and actions revalidate at dispatch.
- A row's `name` may be empty: a control with no accessible name (an unlabelled native select, a bare text input, an icon button) is kept with its `role`, an empty `name`, and its `value` or `placeholder`, so it stays addressable by index (tab-zc36). `value` is omitted when the control has neither.
- `new` with a url navigates and returns when the document has loaded, exactly like `nav`, so `title` is populated; `new` without a url returns at once with `about:blank`. Both report the URL Chrome committed — after any redirect — and the document title, not the requested URL.
- The CLI prints the `result` (or the error) as compact JSON; `--pretty` indents; `snap` and `list` also accept `--table` for a human-readable rendering. Every command names its positional arguments in its synopsis — `leash click [OPTION]… TAB SNAPSHOT INDEX` — and accepts only the options it uses, so `leash <command> --help` is the whole call; `--owner`, `--pretty`, `--config` and `--socket` are the client options every command shares. Exit status 0 on `ok:true`, 1 on a protocol error, 2 on a CLI usage error.

## Error codes

| code | when |
| --- | --- |
| `invalid-request` | malformed JSON, unknown cmd, bad args |
| `not-owner` | the tab is owned by another caller, or unowned and the command needs ownership |
| `already-owned` | `claim` on a tab that is not unowned |
| `with-human` | the tab is handed to the human; every command is refused until `resume` |
| `tab-gone` | the handle names a closed tab; `detail.disposition` is `closed_by_owner`, `closed_by_ttl`, `closed_externally`, or `browser_lost` |
| `unknown-tab` | no tab and no tombstone for the handle |
| `stale-snapshot` | the targeted snapshot is not current |
| `no-such-row` | index not in the snapshot |
| `row-not-actionable` | the row is not visible, is disabled, or is covered at its click point |
| `dialog-open` | a dialog blocks the page; answer it first |
| `no-dialog` | `dialog` with nothing to answer |
| `no-handoff` | `resume` on a tab nobody is waiting on |
| `url-refused` | scheme not http(s)/about:blank, or userinfo present |
| `tab-cap` | no capacity for `new` |
| `timeout` | `wait`, `handoff`, or a bounded operation ran out of time; a handoff's `detail.warnings` lists the human-facing steps that failed |
| `browser-unavailable` | Chrome is restarting; try again shortly |
| `model-unavailable` | System One or the text helper failed, or no API key is configured; `detail.code` carries the kind (`missing-key`, `unavailable`, `timeout`, `authentication`, `invalid-response`, `input-too-large`, `model-mismatch`, `text-helper-unavailable`) and a drive's `detail.steps` the completed steps |
| `too-large` | expression, argument, result, or fill text over its bound |
| `internal` | a defect; the message carries no page content |
