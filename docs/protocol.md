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
- `error.code` is from the closed set below. `message` is one short sentence for the agent. `detail` is optional structured context (for `tab-gone`: the disposition; for `stale-snapshot`: the current snapshot id).

## Commands

Tab lifecycle:

| cmd | args | result |
| --- | --- | --- |
| `new` | `{url?}` | `TabInfo` |
| `list` | `{all?: bool}` | `{tabs: TabInfo[]}` |
| `claim` | `{tab}` | `TabInfo` |
| `release` | `{tab}` | `{released: true}` |
| `close` | `{tab}` | `{closed: true}` |
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

```
TabInfo      = {tab, url, title, origin: "agent"|"human", state: "unowned"|"owned"|"with_human",
                owner: string|null, generation: int, expires: {stage: "release"|"close", in_s: int}|null}
Snapshot     = {snapshot: id, tab, url, title, rows: Row[], total: int, offset: int, truncated: bool, settled: bool,
                dialog: Dialog|null}
Row          = {index: int, role: string, name: string, value?: string, state?: string[]}
                 state ⊆ {checked, unchecked, mixed, selected, expanded, collapsed, disabled, required, readonly}
Dialog       = {kind: "alert"|"confirm"|"prompt"|"beforeunload", message: string}
ActionResult = {tab, url, title, snapshot: id|null, dialog: Dialog|null, popups: TabInfo[]}
                 snapshot is the id of the fresh post-action snapshot when one was taken cheaply, else null
DebugEntry   = {at: iso8601, kind: "console"|"exception"|"request-failed", level?: string, text: string}
Step         = {n: int, snapshot: id, operation: Operation, index: int|null, probabilities: {op: {..}, target: {..}},
                text?: string, after: {url, title}, elapsed_ms: int}
Operation    = "click"|"type_text"|"select"|"scroll_up"|"scroll_down"|"wait"|"done"|"blocked"
status (drive) = "done"|"blocked"|"step-cap"|"deadline"|"error"
```

Rules:

- Every action except `nav`, `scroll` without index, `wait`, and `dialog` requires the `snapshot` id it targets; it is refused with `stale-snapshot` if that is not the tab's current snapshot or the page moved since.
- `press` with `index` focuses the row first; without it, sends the key to the page.
- `select` targets a native `<select>` row; `option` is the observed option index carried in the row's value.
- `wait` conditions are ANDed; `timeout_ms` is bounded to 30 000.
- `eval` runs the expression as a function body in the page with `argument` bound; expression, argument, and result are each bounded to 64 KiB.
- `shot` writes a PNG to `path`, which must be an absolute path the service can write; the reply carries no image data.
- `snap` `match` filters rows by case-insensitive substring over role, name, and value; `limit` defaults to 120, `offset` pages; `truncated` is truthful. `settled` is false when the page kept mutating during the observation (retaken twice first); the snapshot is still usable and actions revalidate at dispatch.
- `new` with a url navigates and returns when the document has loaded, exactly like `nav`, so `title` is populated; `new` without a url returns at once with `about:blank`.
- The CLI prints the `result` (or the error) as compact JSON; `--pretty` indents; `snap` and `list` also accept `--table` for a human-readable rendering. Exit status 0 on `ok:true`, 1 on a protocol error, 2 on a CLI usage error.

## Error codes

| code | when |
| --- | --- |
| `invalid-request` | malformed JSON, unknown cmd, bad args |
| `not-owner` | the tab is owned by someone else, or unowned and the command needs ownership |
| `already-owned` | `claim` on a tab someone owns |
| `with-human` | the tab is handed off; the owner's actions are refused until resume |
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
