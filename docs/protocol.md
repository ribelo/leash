# Control protocol and the leash CLI

The Leash service listens on `$XDG_RUNTIME_DIR/leash/control.sock` (owner-only, in a verified private directory). A client connects, writes one JSON object per line, and reads one JSON object per line in reply. One request per connection is the norm; the CLI opens a connection per command. Long-blocking requests (`handoff`, `drive`, `wait`) hold the connection open until they settle.

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
| `status` | `{}` | `{generation, tabs: {open, cap}, chrome: "running"\|"restarting", uptime_s}` |

Observation:

| cmd | args | result |
| --- | --- | --- |
| `snap` | `{tab, match?: string, limit?: int, offset?: int}` | `Snapshot` |
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
| `handoff` | `{tab, reason, timeout_s?}` | `{resumed: true, url, title}` |
| `resume` | `{tab}` | `{resumed: true}` |

Drive:

| cmd | args | result |
| --- | --- | --- |
| `drive` | `{tab, goal, max_steps?, deadline_s?}` | `{status, steps: Step[], final: Snapshot}` |

## Types

A field shown as `T|null` is always present, `null` when it has no value; a field shown as
`key?` is omitted when it has no value.

```
TabInfo      = {tab, url, title, origin: "agent"|"human", state: "unowned"|"owned"|"with_human",
                owner: string|null, generation: int, expires: {stage: "release"|"close", in_s: int}|null}
Snapshot     = {snapshot: id, tab, url, title, rows: Row[], total: int, offset: int, truncated: bool, settled: bool,
                dialog: Dialog|null}
Row          = {index: int, role: string, name: string, value?: string, state?: string[]}
                 state ⊆ {checked, unchecked, mixed, selected, expanded, collapsed, disabled, required, readonly}
Dialog       = {kind: "alert"|"confirm"|"prompt"|"beforeunload", message: string}
ActionResult = {tab, url, title, snapshot: null, dialog: Dialog|null, popups: TabInfo[]}
                 snapshot is always null in this version: no snapshot is taken while an action settles; call snap
                 popups lists only tabs opened by the acted-on tab (opener), owned by the caller
DebugEntry   = {at: iso8601, kind: "console"|"exception"|"request-failed", level?: string, text: string}
Step         = {n: int, snapshot: id, operation: Operation, index: int|null, probabilities: {op: {..}, target: {..}},
                text?: string, after: {url, title}, elapsed_ms: int}
Operation    = "click"|"type_text"|"select"|"scroll_up"|"scroll_down"|"wait"|"done"|"blocked"
status (drive) = "done"|"blocked"|"step-cap"|"deadline"|"error"
```

Rules:

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
- `list` shows the caller's tabs — the ones it owns and the one the human is holding for
  it — and `list --all` every tab with its `origin`, `state`, and `owner`; `owner` is
  null exactly when `state` is `unowned`.
- Every action except `nav`, `scroll`, `wait`, and `dialog` requires the `snapshot` id it targets; it is refused with `stale-snapshot` if that is not the tab's current snapshot, if the page navigated since, if the row's node no longer resolves, or if its role and name differ from the snapshot's. An indexed `scroll` carries no id and revalidates against the tab's current snapshot.
- A row action also refuses with `row-not-actionable` when the row is disabled, has no layout box, cannot take focus, or is covered at its click point (a hit test that answers with another node than the row or one of its descendants). Clicking reads the row's geometry at that moment; scrolling and animation are never staleness.
- `press` with `index` focuses the row first; without it, sends the key to the page (and only the snapshot's currency is checked).
- `select` targets a native `<select>` row (role `combobox` or `listbox`); `option` is its index in the select's observed option order, and an index the select does not have is `invalid-request`. A row that is not a native select is `row-not-actionable`.
- `ActionResult.snapshot` is null unless a snapshot was taken as part of settling; actions do not observe the page again on their own, so a caller that wants a fresh table asks for one.
- `wait` conditions are ANDed; `timeout_ms` is bounded to 30 000.
- `eval` runs the expression as a function body in the page with `argument` bound; expression, argument, and result are each bounded to 64 KiB.
- `shot` writes a PNG to `path`, which must be an absolute path the service can write; the reply carries no image data.
- `snap` `match` filters rows by case-insensitive substring over role, name, and value; `limit` defaults to 120, `offset` pages; `truncated` is truthful. `settled` is false when the page kept mutating during the observation (retaken twice first); the snapshot is still usable and actions revalidate at dispatch.
- A row's `name` may be empty: a control with no accessible name (an unlabelled native select, a bare text input, an icon button) is kept with its `role`, an empty `name`, and its `value` or `placeholder`, so it stays addressable by index (tab-zc36). `value` is omitted when the control has neither.
- `new` with a url navigates and returns when the document has loaded, exactly like `nav`, so `title` is populated; `new` without a url returns at once with `about:blank`. Both report the URL Chrome committed — after any redirect — and the document title, not the requested URL.
- The CLI prints the `result` (or the error) as compact JSON; `--pretty` indents; `snap` and `list` also accept `--table` for a human-readable rendering. Exit status 0 on `ok:true`, 1 on a protocol error, 2 on a CLI usage error.

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
| `url-refused` | scheme not http(s)/about:blank, or userinfo present |
| `tab-cap` | no capacity for `new` |
| `timeout` | `wait`, `handoff`, or a bounded operation ran out of time |
| `browser-unavailable` | Chrome is restarting; try again shortly |
| `model-unavailable` | System One or the text helper failed; `detail.code` carries the provider failure |
| `too-large` | expression, argument, result, or fill text over its bound |
| `internal` | a defect; the message carries no page content |
