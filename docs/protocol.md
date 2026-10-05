# Control protocol and the leash CLI

The Leash service listens on the `control.socket` path its configuration names — `$XDG_RUNTIME_DIR/leash/control.sock` by default, mode 0600, in a verified private directory. A client connects, writes one JSON object per line, and reads one JSON object per line in reply. The CLI reads the same configuration file to find it (`--socket PATH` overrides it for one call, `--config FILE` names the file to read). One request per connection is the norm; the CLI opens a connection per command. Long-blocking requests (`handoff`, `drive`, `wait`) hold the connection open until they settle. The socket admits 64 requests at once (hard-b1na); see Concurrency below.

Wire shapes here are the contract; field names are stable across the CLI and any later adapter. Until 1.0 they may still change with the spec. Meaning of each field and error is `leash help`, not this file: [handles](help/handles.md) (tab, handle, origin, label, idle, take), [playbooks](help/playbooks.md) (playbook JSON), [authoring](help/authoring.md) (how to write one), [expectations](help/expectations.md) (checker sentences), [drive](help/drive.md) (mission, lanes, trace), [scripts](help/scripts.md) (script, pages, returns, args), [errors](help/errors.md) (every code).

## Durable drive traces (L51, L53)

A successful trace write adds `trace_path` to the drive result; an error reply
adds `error.detail.trace_path`. The path exists before reply encoding. Disabled
tracing or a failed write omits the field, and persistence failures never replace
the drive outcome. `Protocol.drive_trace` is the version-1 derived safe durable
projection, not the live result type, to exclude handles, page text, records, and
raw state. It records headers, the page-kind path (the selected playbook's declared kinds; nothing is inferred), procedures,
steps, URL/title, `arguments` (`[name, value][]`, default `[]`) and unattended events (default `[]`). Only argument values feeding retained non-redacted typed steps are persisted. Operator and planner
steps share one chronological sequence, renumbered from 1; a failed planner
action is retained with its error code, including on a partial-failure trace.
The safe step shape is:

```
TraceStep = {n: int, operation: string, source: "operator"|"planner",
             non_repeatable: bool, error?: string, target?: {role, label}, text?: string,
             operations: [{key, probability: number}], targets: [{key, probability: number}],
             after: {url, title}, elapsed_ms: int}
```

`source` defaults to `"operator"` and `non_repeatable` to false when decoding an
older trace. Operator operations use the lower-case `Operation` names below;
planner operations use their protocol command names. Planner probability lists
are empty; operator lists retain only finite probabilities for known operations
and numeric row keys or `NONE`. `non_repeatable` marks input that must not be
replayed. Safe means capability-free projection, not anonymization: target
labels and ordinary input text are retained. No full snapshot, snapshot id,
tab handle, command envelope, page text, collected records or operator state
is copied into these steps. See [traces](help/traces.md) for the full schema
and local `traces list/show/prune` commands; those commands do not introduce
wire verbs or contact the service.

## Envelope

Request:

```json
{"v":1,"cmd":"click","args":{"tab":"t_9xk…","index":7}}
```

Reply, one of:

```json
{"ok":true,"result":{…}}
{"ok":false,"error":{"code":"stale-snapshot","message":"snapshot s_3 is stale; snap again","hint":"read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting","detail":{…}}}
```

- A tab handle is the capability (ADR-0010). The envelope has only `v`, `cmd`, and `args`; no caller identity or environment default exists.
- `error.code` is from the closed set below. `message` is one short sentence for the agent. `hint` is always present: one line naming the next action, from that table. `detail?` is optional structured context (for `tab-gone`: the disposition; for `stale-snapshot`: the current snapshot id); it is omitted when the error carries none.

## Commands

Tab lifecycle:

| cmd | args | result |
| --- | --- | --- |
| `new` | `{url?, label?: string}` | `TabInfo` | [errors](help/errors.md) |
| `list` | `{}` | `{tabs: TabListing[]}` | [errors](help/errors.md) |
| `take` | exactly one of `{url}`, `{title}`, `{label}` | `TabInfo` | [errors](help/errors.md) |
| `close` | `{tab}` | `{closed: true}` | [errors](help/errors.md) |
| `status` | `{}` | `{version, generation, pid: int\|null, headed: bool, key_present: bool, tabs: {open, cap}, chrome: "running"\|"restarting", uptime_s, models: Models\|null}` | [errors](help/errors.md) |

`pid` is the actual managed Chrome child PID, not the Leash service PID or a
`/proc` profile search. It is null whenever that child is not running, including
restarts. Chrome-loss logs and failure text name portable signals using the
OS-facing name and number (for example `SIGKILL / 9`), not OCaml’s internal
negative `Sys.sig*` encoding. The CLI enriches status with skill installation
state; install and status use configured `skill.roots`, expanding `~` and a leading
environment variable. Empty/unset roots retain default agent-home discovery.
An explicit `skill install PATH` overrides the roots for that install only.

Observation:

| cmd | args | result |
| --- | --- | --- |
| `snap` | `{tab, match?: string, limit?: int, offset?: int}` | `Snapshot` | [errors](help/errors.md) |
| `downloads` | `{tab}` | `{downloads: Download[]}` | [errors](help/errors.md) |
| `text` | `{tab, index?: int, max_chars?: int}` | `{url, title, text, truncated}` | [errors](help/errors.md) |
| `shot` | `{tab, path, full_page?: bool}` | `{path, bytes}` | [errors](help/errors.md) |
| `debug` | `{tab, limit?: int, clear?: bool}` | `{entries: DebugEntry[]}` | [errors](help/errors.md) |
| `eval` | `{tab, expression, argument?, index?, snapshot?}` | `{value}` | [errors](help/errors.md) |
| `net` | `{tab, match?, limit?, type?}` | `{requests: NetEntry[]}` | [errors](help/errors.md) |
| `net_body` | `{tab, id}` | `{id, body, base64, bytes, truncated}` | [errors](help/errors.md) |
| `net_request` | `{tab, id}` | `{id, method, url, headers, post_data?, base64, truncated}` | [errors](help/errors.md) |
| `cookies` | `{tab}` | `{cookies: Cookie[]}` | [errors](help/errors.md) |
| `storage` | `{tab, area: "local"\|"session"}` | `{origin, area, items, truncated}` | [errors](help/errors.md) |

`net` observes events collected so far; it is not a barrier for pending requests.
DOM/load settlement can precede response events, so a first poll may be empty.
Wait for a concrete page outcome, then retry `net` with bounded polls and a caller
deadline. `net_body` may report `network-unavailable` before completion; retry
after the request completes rather than rerunning a side-effecting action.

Actions (serialized per tab; each returns `ActionResult`):

| cmd | args |
| --- | --- |
| `nav` | `{tab, url}` | [errors](help/errors.md) |
| `click` | `{tab, snapshot, index, snap?, match?, limit?}` | [errors](help/errors.md) |
| `fill` | `{tab, snapshot, index, text, snap?, match?, limit?}` | [errors](help/errors.md) |
| `press` | `{tab, snapshot, index?, key, snap?, match?, limit?}` | [errors](help/errors.md) |
| `select` | `{tab, snapshot, index, option: int, snap?, match?, limit?}` | [errors](help/errors.md) |
| `scroll` | `{tab, direction: "up"\|"down", index?}` | [errors](help/errors.md) |
| `upload` | `{tab, snapshot, index, paths: string[]}` | [errors](help/errors.md) |
| `hover` | `{tab, snapshot, index, snap?, match?, limit?}` | [errors](help/errors.md) |
| `check` | `{tab, snapshot, index, snap?, match?, limit?}` | [errors](help/errors.md) |
| `uncheck` | `{tab, snapshot, index, snap?, match?, limit?}` | [errors](help/errors.md) |
| `wait` | `{tab, until: {url_prefix?, text?, index_gone?: int, dialog?: bool, changed_since?: snapshot}, timeout_ms?}` | [errors](help/errors.md) |
| `dialog` | `{tab, answer: "accept"\|"dismiss", text?}` | [errors](help/errors.md) |

`new` and `nav` register the tab before waiting for load and return `TabInfo` with
`loaded: true` when the load finishes, or `loaded: false` when the 30 s load wait
expires or a dialog interrupts it (field-m5jw). A load timeout is a successful
reply: it retains the handle, current committed URL and title, so the agent can
inspect, shoot, close or hand off the tab. `loaded` is omitted from other TabInfo
replies. A session CDP call that itself stops answering is instead
`renderer-unresponsive`; browser-level CDP calls remain `timeout` (field-cde7).
The diagnosis carries `detail: {tab, url, title, entries: DebugEntry[]}` with the
last 20 debug-ring entries, newest first, without clearing the ring.

`new` and `nav` return `TabInfo` (including the tab handle and any active dialog) even
when a load is interrupted by `Page.javascriptDialogOpening`. A modal interrupts
input settlement and `wait` immediately: action replies carry `dialog`, while `wait`
reports `dialog-open` with the serialized dialog in `error.detail`. Run expectation
waits stop with run status `error` and the dialog in the final observation. A prompt
reports Chrome’s `defaultPrompt` as `default_prompt` (null for other dialog kinds).
Answer the dialog before another command on that tab; an handle-initiated close
automatically accepts its own `beforeunload` dialog. When a handler exhausts its
listener budget, its socket still returns `timeout` with `detail.command` and
`detail.budget_ms` instead of closing without a reply.

Playbooks (milestone 9): the two commands that need a page. `playbook list`, `show` and `accept` are local
to the CLI and read the playbooks directory; nothing on the wire ever carries script text.

| cmd | args | result |
| --- | --- | --- |
| `playbook_test` | `{tab, script: "<playbook>/<script>", args?: {name: string}}` | `{script, value, records, bytes, elapsed_ms, truncated}` | [errors](help/errors.md) |
| `playbook_check` | `{playbook}` | `{playbook, scripts: [{script, ok, error?}]}` | [errors](help/errors.md) |

Human handoff:

| cmd | args | result |
| --- | --- | --- |
| `handoff` | `{tab, reason, timeout_s?}` | `{resumed: true, url, title, warnings?: string[]}` | [errors](help/errors.md) |
| `resume` | `{tab}` | `{resumed: true}` | [errors](help/errors.md) |

Drive (milestone 11, fly-b6yt): one mission. `leash drive MISSION [--tab TAB] [--url URL] [--max-steps N] [--deadline-s S] [--max-procedures N] [--expect SENTENCE]... [--out FILE] [--dry-run]` may select an installed playbook or enter the operator with the whole mission. A playbook is optional routing knowledge, not permission to work. There is no `run` protocol verb.

| cmd | args | result |
| --- | --- | --- |
| `drive` | `{tab?, mission, start_url?, max_steps?, max_procedures?, deadline_s?, dry_run?, expect?: string[], out?: string}` | `{playbook_choices, status, site: string|null, procedures: RunProcedure[], mission_expectations: RunExpectation[], planner_turns: PlannerTurn[], collected: int, data: Data, model_calls: int, model_cost: number|null, operator_steps: Step[], operator_state?: OperatorState, output_kinds: string[], final: Snapshot, reason?: string, trace_path?: string, unattended: UnattendedEvent[], detail?: {challenge: string}}` | [errors](help/errors.md) |

`--url` is `start_url`: an optional explicit `http://` or `https://` URL with no userinfo. It opens a drive-owned tab; it does not replace an already populated `--tab`. The CLI rejects a bad scheme, `about:blank`, userinfo, or a non-positive `--max-steps` before it connects, as `usage` (64), and the message names a correct example. `--max-steps` is the on-the-fly executed-action cap (default 60, omitted on the wire when the caller accepts the default); the prediction cap is twice that value, including discarded stale decisions. `--max-procedures` is the playbook-lane cap (default 40). `--deadline-s` is the whole-mission budget (default 900). All three must be positive when present.

Routing (fly-8xiq fly-mepw fly-yolk fly-2akp): no installed books means no playbook question and no planner call. One book is offered with `NONE` and is never forced. Many books are distinct identities plus `NONE`; an identity is `book:<loaded file>`, so two books for one site stay distinct. Books are never merged. A question holds at most 255 choices including `NONE`; a larger library uses bounded hierarchical choices and still offers `NONE`. Selecting `NONE`, or a procedure-level `NONE`, enters the operator on the current page with the whole mission and retained progress. That is a successful route, not `BLOCKED`, not discovery, and not a planner review. No confidence-triggered planner reinterprets `NONE`.

`output_kinds` is always present. It lists `script-record` when a prepared script produced records, then `pilot-record` when the pilot's accepted `done` carried records, then `operator-state` when the reply carries `operator_state`. `operator_state` is `key?`: omitted when the operator lane did not run. It is the bounded observed page, not validated script records, and the reply carries it without `--out`. On the fly, `data` is not a synthesized record list.

`--out` is JSONL. Each line is one object with `kind` and `source`. Script records stream as pages complete. The operator line is one terminal object, written only when the run is not a dry run:

```
{"kind":"script-record","source":"playbook","playbook":"book:<file>","procedure":string,"script":string,"record":object}
{"kind":"pilot-record","source":"pilot","record":{string: string}}
{"kind":"operator-state","source":"operator","state":OperatorState}
```

A `pilot-record` is one flat text record the pilot returned with `done` (pilot-sc9t). Every value must occur in page text or row names the mission read, or the done is refused and costs a turn. The lines are written only when the done is accepted. A dry run does not create or append the file. Untagged lines are not written. A mixed run that collects by script and then enters the operator writes both kinds, in that order, and lists both in `output_kinds`.

```
OperatorState = {status: string, reason: string|null, error: Error|null,
                 initial_recent_actions: RecentAction[],
                 page: OperatorPage, history: ActionLog[], predictions: Prediction[],
                 text_calls: TextCall[], metrics: OperatorMetrics}
OperatorPage  = {snapshot: Snapshot, url, title, text,
                 page_kind: string|null, page_kind_source: "declared"|null,
                 text_truncated: bool, omitted_elements: int,
                 can_scroll_up: bool, can_scroll_down: bool,
                 coverage: Coverage, bounds: CoverageBounds}
CoverageBounds = {text_truncated: bool, omitted_elements: int,
                  can_scroll_up: bool, can_scroll_down: bool, coverage: Coverage}
Coverage      = "viewport" plus, in this order, only the flags that hold, joined by "+":
                truncated (viewport text cut at 6000 characters),
                omitted (omitted_elements > 0; candidates beyond 250),
                above (can_scroll_up), below (can_scroll_down).
                Examples: "viewport", "viewport+below",
                "viewport+truncated+omitted+above+below".
                page.coverage and bounds.coverage are that same string, not a sentence.
OperatorMetrics = {actions, predictions, text_calls, observation_calls,
                   observation_retries, stale_decisions, bootstrap_ms, observation_ms,
                   prediction_ms, text_helper_ms, input_ms, settle_ms, elapsed_ms}
```

`page.text` is viewport text, at most 6000 characters, including visible titles, prices and records. `omitted_elements` counts action candidates beyond the 250 offered. This is the observation JEV used. It is not a normalized schema, not proof of exhaustive collection across pagination or offscreen content, and not a prepared script result. Prepared script payloads still bypass every model. `history` records executed input, including an uncertain mutation that must not be replayed. `predictions` includes discarded stale decisions. `usage` on a prediction or text call is the provider object, or null when that call reported none.

`model_calls` counts attempted provider requests during the drive, including retries and
failed attempts. `model_cost` sums provider-reported costs of the counted drive
calls, including answers later rejected, and is `null` when any counted call has no valid
reported cost. `null` is unknown, not zero. Text-helper memo hits and deterministic
checks make no model call.

`data.model_calls_by_kind`, `data.reported_cost` and `data.cost_unreported`
are that same drive ledger: attempted requests by provider role (absent roles made no
calls), reported cost sum, and count of unpriced requests. They match the reply totals.
Nested `Usage.cost` is a number with zero substituted for absent provider cost; use
`model_cost`, not that fallback, to distinguish a priced run from unknown cost.

A successful control reply is not proof the mission succeeded. Read `status`, `reason`, `operator_state` and, when present, the tagged file.

## Unattended missions (L55)

The planner owns every interruption; JEV `BLOCKED` routes to it and never directly
notifies or hands off. Planner answers include `notify` with a non-empty, single-line
`message` of at most 1024 bytes, and no actions/procedure/reason; it sends through
`notify.command` and returns to the loop. Commands use argv substitution, never a
shell, and are bounded to five seconds. An empty command disables delivery; command
failure is audited without failing the mission.

Handoffs default to `handoff.timeout_s = 300`. Expiry sends "the agent gave up waiting;
the tab is still open" and ends `handoff-expired`, not a protocol error. Challenge
expiry instead ends `blocked` with `detail.challenge` (origin). The tab stays open,
`with_human` is cleared, and normal idle expiry restarts.

Debug challenge signals and challenge page kinds trigger bounded planner
attempts before JEV. Defaults: `challenges.attempt = true`, `challenges.turns = 2`;
turns must be 1–10. Only ordinary snapshot-row actions are available, at most
the pilot action bound per turn. No JavaScript, invented coordinates or external
solver. Disappearance resumes JEV; disabled/exhausted attempts hand off as `captcha`.

UnattendedEvent is one of:

```text
{kind: "notify", message, elapsed_ms, outcome: "sent"|"failed", error: string|null}
{kind: "handoff", reason, elapsed_ms, outcome: "resumed"|"canceled-by-operator"|"expired"|"failed"}
{kind: "challenge", origin, attempt: bool, turns: int, outcome: string}
```

The ordered `unattended` list is carried by results and safe durable traces; older
wire/trace records decode it as `[]`. Error detail preserves partial unattended
audit too. It contains no handles or raw page state; notification text can include
operator-facing facts such as an order ID. Live reCAPTCHA success rates are separate
acceptance evidence, not implied by scripted protocol-seam tests.

## Types

A field shown as `T|null` is always present, `null` when it has no value; a field shown as
`key?` is omitted when it has no value.

```
PageKind     = {name, source: "declared"}
                 present only when an installed playbook's url_pattern matched (list and
                 snap do not read page text, so a text_marker-only kind is not shown);
                 nothing is inferred (ADR-0014). See leash help handles.
TabListing   = {label: string|null, url, title, page_kind: PageKind, origin: "agent"|"human",
                 age_s: int, idle_s: int, closes_in_s: int|null, with_human: bool}
TabInfo      = {tab, ...TabListing, generation: int, dialog: Dialog|null, reason?: string, loaded?: bool}
PopupInfo    = {tab?: string, ...TabListing, state: "opening"|"blank"|"ready",
                 generation: int, dialog: Dialog|null, reason?: string, opener_url: string}
Snapshot     = {snapshot: id, tab, url, title, page_kind: PageKind, rows: Row[], total: int, offset: int, truncated: bool, settled: bool,
                source: "ax"|"dom" (default "ax" when omitted), reason?: string, dialog: Dialog|null}
Row          = {index: int, role: string, name: string, value?: string, state?: string[],
                options?: [{index: int, label: string, value: string, selected: bool, disabled: bool}]}
                 state ⊆ {checked, unchecked, mixed, selected, expanded, collapsed, disabled, required, readonly, password, cross-origin}
                 a password input (field-8bzc) is role textbox with state password and never a value; the operator's
                 table (what JEV is offered) excludes it, as it excludes file inputs (fly-eoqg)
                 role file-input (hard-2gnf) is an <input type=file>, listed even when the page hides it behind a styled
                 button; only `upload` acts on it
                 options is the option list a select row exposes, in the select's own order, index 0 first
Dialog       = {kind: "alert"|"confirm"|"prompt"|"beforeunload", message: string, default_prompt: string|null}
ActionResult = {tab, url, title, snapshot: Snapshot|null, dialog: Dialog|null, popups: PopupInfo[], via?: "label"}
                 snapshot is null, or a fresh Snapshot (the object, not an id) taken after settlement when the request set snap (field-swvb)
                 via is "label" when the click dispatched on a covering label of the target, and omitted otherwise (field-uls3)
                 popups lists only tabs opened by the acted-on tab (opener); page-opened tabs have human origin and no capability until taken; newly opened target metadata is refreshed after a bounded 1 s wait for its URL (daily-c4cl)
                  an empty/about:blank URL younger than 1 s is state opening; still blank after the settle window is blank; a committed URL is ready (field-drpx)
                  a dialog skips the settle wait and reports an opening popup immediately; opener_url identifies the page that opened it; human hold remains separate from readiness
NetEntry     = {id: string, method, url, status: int|null, type: string, mime: string|null, size: int|null,
                duration_ms: int|null, from_cache: bool, error?: string}
                 one request of the tab's own ring (see the net rules below); type is Chrome's resource type
                 lower-cased (document, xhr, fetch, script, image, ...); size is the encoded size on the wire
Cookie       = {name, value, domain, path, expires: number|null, http_only: bool, secure: bool, same_site: string|null}
                 expires is null for a session cookie, otherwise epoch seconds
Download     = {id: string, suggested_name: string, mime: string, state: "in_progress"|"completed"|"canceled",
                received_bytes: int, total_bytes: int, path: string|null}
                 byte counts begin at zero and follow Chrome downloadProgress receivedBytes/totalBytes (daily-c4cl)
                 path is null until Chrome reports a completed filePath; MIME is inferred from the extension when Chrome does not report one
DebugEntry   = {at: iso8601, kind: "console"|"exception"|"request-failed", level?: string, text: string}
Step         = {n: int, snapshot: id, operation: Operation, index: int|null, probabilities: {op: {..}, target: {..}},
                non_repeatable: bool, target?: {role, label}, text?: string, after: {url, title}, elapsed_ms: int}
                 non_repeatable defaults to false when decoding an older step
Operation    = "click"|"type_text"|"select"|"scroll_up"|"scroll_down"|"wait"|"done"|"blocked"
status (drive) = "done"|"blocked"|"step-cap"|"deadline"|"error"
                 The operator action cap is the mission max_steps (default 60); the
                 prediction cap is twice that. The operator uses the remaining mission
                 deadline_s (default 900), not a hidden 120 s cap. A present max_steps
                 or deadline_s must be positive.
RunProcedure = {slug, site, planned: bool, attempts: int,
                choice: {key: string, probabilities: {..}, confidence: float, usage: Usage|null},
                drives: [{goal, status (drive), steps: Step[], reason?: string}],
                scripts: RunScript[],
                expectations: RunExpectation[],
                outcome: "verified"|"failed"|"skipped"|"planned", elapsed_ms: int, reason?: string}
                drives is empty for "planned" (a dry run executed nothing); attempts is 2 when the
                retry-once rule replayed the procedure; planned is true when a planner turn wrote it
PlaybookChoice = {source: "jev"|"planner"|"route", key: string|null, probabilities: {..}|null, confidence: float|null,
                  usage: Usage|null, note: string|null}
                 drive replies retain playbook_choices in decision order, including a JEV NONE
                 and the route note when the operator is entered directly. NONE is the route:
                 it is not BLOCKED, and no planner review reinterprets it (fly-yolk; the
                 extr-uhnc confidence review does not gate this lane). JEV preserves its own
                 distribution and confidence. A route entry has source "route", key "operator",
                 and a note; its probabilities are empty and its confidence is null.
                 Planner turns remain for applicable installed-playbook escalation and repair,
                 not for initial on-the-fly routing or NONE review. No unvalidated planner text is executable.
RunScript   = {script, url, records: int, bytes: int, elapsed_ms: int, error?: string}
                 one script call of a procedure's `script:` step (extr-8o1h): the page it ran on, the records it produced,
                 the size of its result, and — when the call was rejected — why; empty for a procedure with no script step
RunExpectation = {sentence, checker: "page_kind"|"text"|"download"|"no_dialog"|"row"|"judgment",
                  passed: bool, score: float|null}
                 score is the JEV score a judgment expectation was given, null where code decided it
PlannerTurn = {n: int, trigger: "blocked"|"failed"|"arguments",
               answer: "procedure"|"continue"|"handoff"|"fail", steps: PlannerStep[],
               reason?: string, usage: Usage|null}
                 steps defaults to [] when decoding an older turn
PlannerStep = {n: int, command: "click"|"fill"|"press"|"scroll"|"nav",
               non_repeatable: bool, target?: {role, label}, text?: string,
               after: {url, title}, elapsed_ms: int, error?: string}
                 non_repeatable defaults to false; error is the failed action's protocol error code
Usage       = {input_tokens: int, output_tokens: int, cost: float}
status (run) = "done"|"blocked"|"failed"|"handoff"|"handoff-expired"|"canceled-by-operator"|"limit"|"deadline"|"error"
               max_steps defaults to 60; max_procedures defaults to 40; deadline_s defaults to 900;
               each must be positive when present. model_cost is number|null.
Models       = {configured: bool, jev_model: string, text_model: string,
                systemone_endpoint: string, chat_base_url: string}
                 the models section as configured; configured is whether an API key is present,
                 and no field ever carries the key
```

### Planner Done (map-op10)

The planner may answer:

```json
{"answer":"done","result":"ama Café, Berlin","evidence":["the page shows ama Café"]}
```

`result` is a nonempty single line of at most 1024 bytes; `evidence` is a nonempty
list of sentences in the existing expectation vocabulary. No actions, message,
procedure, reason or expect may be mixed into done. The runner resolves and
verifies those checks, together with the mission expectations, against the live
page before returning `status: "done"` and the optional `answer` result. Failed
evidence records a refusal and consumes a bounded planner turn before continuing.
An active challenge or incomplete collection cannot finish this way. Notify still
sends a message and continues: it is not a completion answer.

### Default-decline consent and unchanged actions (map-op11, map-op12)

Planner and operator accept-all, agree-to-all and allow-all consent clicks are
refused when the same snapshot offers reject, decline or necessary-only. Reject
remains clickable; the refusal reason goes to JEV's recent-actions context.
Mission wording never overrides this always-decline default; explicit acceptance
missions are out of scope. English Accept all / Reject all and Polish
Zaakceptuj wszystko / Odrzuć wszystko are recognized.

An action that leaves the page fingerprint unchanged has its exact operation and
target masked from JEV's next request until the page changes. Other targets and
operations remain offered across row reindexing. WAIT is not masked; the existing
stall and prediction caps still apply.

Three executions of the same operation and target on one URL, without a change
to that target's role/name row set, values or options, also mask it until the URL
changes. Menu expansion and unrelated DOM changes do not reset this oscillation
mask. (map-op12)

For collection goals asking for every/all items, operator DONE is refused while
the page can scroll down or offers an enabled next-page link/button. JEV receives
the reason and can continue; after three refusals another incomplete DONE ends
blocked. This frontier guard does not
prove that records were accumulated. (map-op08, map-bjon)

A row-not-actionable refusal before input dispatch makes the operator re-observe
and re-decide for click, type_text, select and press. A planner continuation stops
its remaining actions and returns to JEV. Dispatched input is never replayed.

Invalid or empty JEV/text-helper provider responses are retried once within the
original deadline. A valid helper `{"text":null}` still means a missing value;
null provider message content is an invalid response. No token caps are added.

### Planner Continue (L53)

The planner model request includes the actual offered `snapshot` and the
configured `planner_actions` cap (default 5, configuration range 1..20).
A reply may be `{"answer":"continue","actions":[...]}`, with each action an
ordinary `{v:1, cmd, args}` request from the five-command `PlannerStep`
allowlist. This is a planner answer, not a new control-socket verb. Only
Continue may carry actions. Missing or empty `actions` returns directly to JEV
on the current page without a planner action.

The whole batch is validated before dispatch and must fit the configured cap
and remaining mission action budget. Every action names the offered tab;
click, fill and press name the offered snapshot and row, and press requires an
index. Scroll may name an offered row. Nav stays on the current HTTP(S)
authority without userinfo. Actions use the ordinary locked protocol paths;
a changed snapshot requires a unique role/name rebind, and protected actions
are refused. A dry run dispatches none. Remaining deadline and action budget
apply between actions. `PlannerTurn.steps` retains ordered action evidence
and errors; after a successful batch a fresh observation returns control to JEV.

Rules:

- `drive` authorizes the handle, then holds the tab action lock across all observations and
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
- `drive` reuses a supplied tab, leaves it open on every outcome, and does not
  overwrite an already populated page with `start_url`. With no tab it opens
  one (`tab` is `key?`; the tab it opened is the one `final` names) and closes
  it on ordinary terminal outcomes. Planner handoff, handoff expiry, and unresolved
  challenge outcomes retain it; resuming a mission handoff never closes it. `start_url`,
  when present, is the explicit http(s) page that tab opens
  before the operator starts. On a blank tab with no `start_url`, one unambiguous http(s)
  URL in the mission is the bootstrap; none or several is `blocked` with the missing-start
  reason, not a playbook failure and not a model call. It authorizes the handle and then holds
  the tab action lock for the whole run. A playbook step is one operator call bounded by
  the procedure and by what is left of the mission. The on-the-fly operator uses
  `max_steps` (default 60 executed actions; prediction cap twice that) and the remaining
  mission deadline. It is refused before it starts on a tab the caller does not own
  (`unknown-tab`), one the human holds (`with-human`), or one with a dialog open
  (`dialog-open`).
- The playbook level is asked when at least one book is installed: at the start, after a
  procedure whose description or the mission names another installed site the run has not
  served yet, and once more when the procedure level answers BLOCKED. An empty library
  skips the question and enters the operator (fly-8xiq). Criteria are book identities
  (`book:<loaded file>`) plus NONE; even one book competes with NONE and is never forced
  (fly-mepw). Books are never merged. A question holds at most 255 choices including NONE;
  a larger library uses bounded hierarchical choices and still offers NONE (fly-95bw).
  Selecting NONE, or a procedure-level NONE or BLOCKED, enters the operator on the current
  page and does not call the planner (fly-yolk). A playbook other than the current one is
  switched to by navigating the same tab to its `entry` URL, so the shared profile's logins
  carry over.
- The procedure level is asked every turn: the current playbook's procedures (slug and
  description) plus `DONE` and `BLOCKED`. The state it and the playbook level are asked
  over is small and semantic — the mission, the site, the page kind (from the playbook's
  `pages`), the page title and URL, the last five procedures with their outcomes, and the
  arguments already known — and, once a script has collected anything, `collected` (the count), `pages` (pages read) and `collection_complete` (the last pagination ran out: its `until` held or its next page did not exist, not `max` or a limit), so that the mission level can tell a finished collection from an unfinished one (extr-b3u0, found by the L39 live gate: told only a count, JEV chose the collection again and never DONE). **Prepared script records never reach any model, and page text does not reach the playbook or procedure levels**; those levels see summaries and counts. The operator sends the mission, URL, title, at most 6000 characters of viewport text (including visible titles, prices and records), indexed elements and the last ten actions to JEV. The text helper may see that page text when filling a field (fly-g0uh fly-iodm).
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
- **Playbook directories and scripts (milestone 9).** A playbook is a directory,
  `$XDG_CONFIG_HOME/leash/playbooks/<name>/playbook.json`, and whatever files sit beside it; a `.json` file left directly
  in the playbooks directory is refused. `playbook.json` may declare `scripts`, an object of script name (a lowercase slug)
  to `{file | source, returns, max_bytes?}`. `file` is relative to the playbook directory, ends in `.js`, has no `..`
  component and is not absolute; it is resolved with symlinks at load and refused when it leaves the directory (a link to
  another file of the playbook is fine), and its text is read once, at load. `source` is a short inline script (at most
  4096 bytes). Exactly one of the two. `returns` is the shape the script's result must have — a record or a list of records:
  a type name (`string`, `number`, `boolean`, `url` — absolute http(s)), an object of field to shape (a field whose name
  ends in `?` is optional, absent or null), or a one-element array for a list, at most eight deep. `max_bytes` bounds the
  serialized result (default 8 MiB, at most 16 MiB). A malformed `returns`, a bad file, both or neither of `file` and
  `source`, or a `script:` step naming a script the playbook does not declare refuses the playbook, with the path of
  `playbook.json` first in the message.
- A script is the body of an async function of `args` (an object of strings), called on the page's global object with
  `Runtime.callFunctionOn`, `returnByValue` and `awaitPromise` (docs/cdp-shapes.md, L37): it may `await fetch(...)` the
  site's own endpoints with the page's cookies. Its result is bounded by `max_bytes` (`too-large`), then validated against
  `returns`, fail-closed: a missing field, an undeclared field, a value of another type, a null where a value is required
  and a URL that is not absolute http(s) are each `script-invalid`, the message naming the path of the first mismatch
  (`$[3].price: expected number, got string`). A script that threw or rejected, or whose value the browser could not
  return, is `script-failed` with what it threw. A script's calls are serialized on the tab like `eval`, bounded by the
  CDP call's 30 s deadline.
- map-fm01: a `navigate` step is refused. Navigation is a goal; the procedure `expect` verifies the landing page. (Retired 2026-10-03 by map-fm01; the former L40 navigate step is gone.) `repeat.until` accepts either an existing expectation string or `{"script":"<name>"}` returning exactly `{done: boolean}`. Control scripts use their declared shape validation and appear in script traces with zero collected records; their values never enter JSONL. Termination is checked before the page cap; a cap with more pages remaining fails explicitly. Repeat targets are internal helpers, not mission choices.
- A `{"script": "<name>", "args": {...}}` step in a procedure runs the playbook's script. `args` is an object of strings with
  `{name}` placeholders substituted from the run's arguments. A rejected script (`script-failed`, `script-invalid`,
  `too-large`) fails that attempt of the procedure — nothing is verified, the whole procedure is replayed once, and a second
  rejection fails it (`outcome: "failed"`) and asks the planner, like a failed expectation; the call is in the procedure's
  `scripts` with its error. A browser failure ends the run, and a dialog the script opened ends it `error` as a drive's
  does. The runner streams each validated record to `--out` as a tagged `script-record` line (`kind`, `source: "playbook"`, playbook identity, procedure, script, record) as pages complete; it keeps only five bounded samples in memory and `collected` is the count. No model sees a prepared script record. A terminal `operator-state` line is separate and is not a script record. A dry run
  runs no script. A procedure may declare `repeat: {next, max, until, delay_ms?, key}`: after its body the runner executes the named next-page procedure up to `max` pages, checks `until` and the next procedure’s expectations, waits `delay_ms` (default 500 ms), and streams each record once by `key` — the key de-duplicates for the rest of the run, so a page read twice (a replayed procedure, a next-page step the mission level chooses itself) never streams a record twice.
- `playbook_test` runs one script of an installed playbook on the tab's page and answers its validated output, so that writing
  a script is a fast loop; it is handle-based and takes the tab's action lock. The script is looked up by name in the
  playbooks directory (`invalid-request` for a playbook or script that is not there; a path is never a playbook name).
  `records` is the length of a list result, or 1; a result over 1 MiB is not echoed whole: `value` is its first five
  records and `truncated` is true. `playbook_check` opens a blank tab for the caller, compiles every script of the
  playbook with `new Function` — never calling it — closes the tab, and answers each script's verdict; it takes no tab, and
  the CLI's `leash playbook check <name>` prints the loader's local checks (the file resolves, no escape, `returns` well
  formed, expectations resolve) beside it and exits 1 when a script does not compile. `leash playbook check <dir>` (a path)
  runs the local checks only.
- **What reaches the page's JavaScript engine.** Only three kinds of text ever reach `Runtime.evaluate` or
  `Runtime.callFunctionOn`: Leash's own fixed expressions, the expression an agent writes into the `eval` command, and a
  script from a loaded playbook directory. No model output is ever any of them: a model chooses a playbook, a procedure, a
  criterion or an argument value, and an argument value travels as JSON in the call's `arguments`, never in the function
  text. A script is a `Playbook.script`, a type only the loader can build, and `Reading.script` is the one function that
  hands one to the browser; a planner answer cannot carry scripts (extr-k40c).
- `dry_run: true` asks the playbook and the procedure levels and reports the chosen
  playbook, the chosen procedure with its choice and resolved checkers, and ends
  `blocked`: it navigates nothing, executes no step, and never calls the text helper.
- The endings are `done` (DONE verified), `blocked` (the loop stopped with nothing that
  can progress), `failed` (a procedure failed twice and the planner failed), `handoff`
  (the planner asked for the human, who resumed), `handoff-expired` (the configured
  wait expired; the tab stays open with `with_human` cleared), `limit` (the procedure
  cap), `deadline` (the run deadline) and `error` (a dialog opened on the page — it is in
  `final.dialog`). A model or browser failure is a protocol **error**; when it is
  `model-unavailable` its `detail` carries the provider `code` and the trace completed so
  far in `detail.procedures`, so a failed mission is auditable.
- **The planner (Luna).** A planner turn is asked exactly where JEV stops — the procedure
  level answered `BLOCKED`, a procedure failed its expectations twice, or a required
  argument could not be filled — and at most three times per run (the trigger that arrives
  with the cap reached ends the run, `blocked` or `failed` naming the cap). It is one
  `chat/completions` call to the configured `planner_endpoint` (default:
  `chat_base_url + "/chat/completions"`) with `json_object` on, reasoning at
  `planner_reasoning` (default `high`, `none` turns it off) and model
  `planner_model` (default `openai/gpt-6-luna`); its messages are the planner instruction
  and the mission, the current playbook in its own schema, the trace so far, the arguments
  known and the observed page — its kind, title, URL and its visible text, bounded, the one
  place page text reaches a level above the operator. It answers exactly one of
  `{"answer": "procedure", "procedure": {...}}`, `{"answer": "handoff", "reason": "..."}`
  or `{"answer": "fail", "reason": "..."}`, decoded fail-closed: an answer that is not one
  of the three, a missing reason, a procedure the playbook cannot run, or a member the
  shape does not name is refused and shown back with the refusal once; a second refusal
  ends the run as `model-unavailable` with `code: "invalid-response"`. Its first turn may
  also attach the mission's expectations (`"expect": [...]`), which the DONE guard then
  verifies when the caller stated none. Every turn's tokens are in `planner_turns[].usage`
  (`cost` is zero: the chat route reports tokens, not the provider's own cost) and logged.
- A run's handler budget is its `deadline_s` plus 75 seconds — the last procedure's own
  bounded expectation wait (at most 30 s), a planner turn's correction call (at most 30 s)
  and the reply — so the listener never cancels a run at the instant it is due to answer.
- `status`'s `models` reports the models section — `configured` is whether an API key
  is present, and the two model ids and two endpoints are the configured ones. It is read
  from the live configuration: no probe, nothing at boot, and never the key. It is
  `null` only in a dispatch with no models service; the service always reports it.
  `key_present` is that same boolean at the top level, and is false when `models` is
  null. `version` is the library version. `pid` is the managed Chrome's process id while
  `chrome` is `running`, and null while a generation is being relaunched. `headed` is
  false only when the service was started headless (daily-smli daily-a341).
- Every tab command authorizes by handle. A missing handle is `invalid-request`, an unknown handle is `unknown-tab`, and a tombstoned handle is `tab-gone` with its disposition. While `with_human` is true, actions refuse with `with-human`; `resume` and dialog answers remain available by handle.
- `list` shows all tabs and never returns handles. A label is nullable display metadata, not a credential. `new [URL] --label TEXT` creates a labelled agent tab.
- `take --url PREFIX | --title TEXT | --label TEXT` requires exactly one selector. Matching is case-insensitive: URL prefix, title substring, whole label. No match returns `no-match`; several return `ambiguous` with handle-free listings in `detail.matches`. A live capability returns `taken` with a sharing hint; a handed-off tab returns `with-human`. A successful take permanently changes origin to agent and returns its new capability. The journal records URL and time, never the capability.
- `downloads` requires the handle and refuses during handoff. Only downloads attributed to the tab main frame appear; files remain under the managed profile downloads directory.
- `handoff HANDLE REASON` waits for handle-based `resume`, notification cancellation/dismissal, the deadline (default 300 seconds), client disconnection, or disappearance. Cancellation immediately returns `canceled-by-operator` (CLI exit 77); a mission returns the same terminal status and durable handoff event, with no pilot retry. The tab stays open. Resume, cancellation, timeout and disconnection restore ordinary use and restart the idle clock; disappearance returns `tab-gone`. Resume outside a handoff returns `no-handoff`. A human hold cannot be bypassed by close or take.
- The human-facing side of a `handoff` runs in the order the story says: `Target.activateTarget`
  for the tab, then `handoff.focus_command`, then `handoff.notify_command`, whose stdout
  carries the action the human took and whose Done action (`done`, what
  `notify-send --action done=Done` prints) is a `resume`. `cancel` on stdout or a successful
  exit without an action means cancellation/dismissal; nonzero exit is a delivery failure.
  The default also offers `--action cancel=Cancel` and requests `--expire-time=0`, so only
  the handoff deadline expires the wait. First settlement wins; later notification events
  cannot affect another handoff. All three are best effort by
  contract: each one that fails is a log line and a `warnings` entry on the successful
  reply — omitted when there is none — and none of them fails the handoff. A handoff that
  ends `timeout` carries the same list in `detail.warnings`, because a human who was never
  told is exactly why nobody answered. Each external command gets five seconds of its own;
  the notification instead runs for as long as the handoff does and is stopped when the
  handoff ends, however it ends.
- Agent tabs close after `expiry.idle_s` without handle use (default 1800 seconds); a sweep runs every 30 seconds. There is no intermediate stage. Handoff pauses expiry. Idle closure leaves `closed_by_idle`; late use returns `tab-gone` and the hint “open a new tab with `leash new`”.
- agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one
- Chrome UI tabs and page popups are human, even with an agent opener. Discovery does not mint a handle. Taking such a tab makes it agent permanently; it then follows the idle rule. External closure leaves `closed_externally`. Attachment is lazy on first observation; restored targets after a browser restart are human and previous-generation handles remain dead.
- Every action except `nav`, `scroll`, `wait`, and `dialog` requires the `snapshot` id it targets; it is refused with `stale-snapshot` if that is not the tab's current snapshot, if the page navigated since, if the row's node no longer resolves, or if its role and name differ from the snapshot's. An indexed `scroll` carries no id and revalidates against the tab's current snapshot.
- A row action also refuses with `row-not-actionable` when the row is disabled, has no layout box, cannot take focus, or is covered at its click point (a hit test that answers with another node than the row or one of its descendants). Clicking reads the row's geometry at that moment; scrolling and animation are never staleness. A covering LABEL whose control is the target, or which contains it, is not a cover: the click is dispatched at that point and the reply carries via "label" (field-uls3).
- An action whose handler closes its own tab (a click on `window.close()`) reports `tab-gone` with `closed_externally` when the browser no longer knows the target; if the reply wins the race the action succeeds and the next command on the handle reports `tab-gone`.
- A trusted input or an `eval` whose handler opens a popup is settled by the popup itself: Chrome withholds the reply of the call whose handler opened it, so Leash waits — with no bound of its own beyond the CDP call's deadline — for whichever comes first: the call's reply, a target Chrome reports with this tab as its `openerId` (an action then lists it in `popups`, and `eval` answers `{value: null}`), or the destruction of this tab's own target (`tab-gone` with `closed_externally`). Nothing is ever dispatched twice.
- `press` with `index` focuses the row first; without it, sends the key to the page (and only the snapshot's currency is checked). Accepted named keys are `Enter`, `Escape`/`Esc`, `Tab`, `Backspace`, `Delete`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `Home`, `End`, `PageUp`, `PageDown`, and `Space`. Single lowercase `a`–`z`, digits `0`–`9`, and punctuation `- = [ ] ; , . / '` are also accepted. `Return`, uppercase letters, chords, and other names are rejected with `invalid-request`; its hint and `detail.accepted_keys` enumerate the vocabulary.
- `select` targets a native `<select>` row (role `combobox` or `listbox`); `option` is its index in the select's observed option order, and an index the select does not have is `invalid-request`. A row that is not a native select is `row-not-actionable`. The observed order is the row's `options`, read from the accessibility tree even while the select is closed — a closed select's options have no layout box and are never rows of their own (tab-5deq): each carries the `index` the action takes, its `label`, the `value` it holds, its label when it holds none, and whether it is `selected` or `disabled`.
- `check` and `uncheck` click the row (following a covering label) and then read its checked state. The row must report a boolean checked or aria-checked; otherwise the answer is `row-not-actionable`. If it was already in the requested state, or the click did not flip it, the answer is `state-unchanged` and an already-correct control is not clicked (field-guda).
- `click`, `fill`, `press`, `select`, `hover`, `check` and `uncheck` take optional `snap`, `match` and `limit`. `snap: true` takes a fresh snapshot after settlement, with the same `match` and `limit` as `snap`, and puts that Snapshot object in `ActionResult.snapshot` (then non-null). Without `snap`, `snapshot` stays null (field-swvb).
- `fill` text is the `text` field. The CLI also accepts it from `--argument-file PATH` or `--stdin`, reading at most 64 KiB. A password row's value is never copied into the reply, a drive trace, or a log line (field-5sdo).
- `ActionResult.snapshot` is null unless the request set `snap`. It is then a Snapshot object, not an id.
- An action reply's `url` and `title` come from `Target.getTargetInfo` read after the action settled. When the action navigated the tab, that read waits — bounded like a load — for the new document to finish, so the reply, a drive step's `after`, and `list` carry the document title rather than the tab strip's formatted URL (chrome-qnul, svc-hi4f).
- `wait` conditions are ANDed; `timeout_ms` defaults to 30 000 and may be up to 3 600 000 — one hour
  (hard-sr9v). The listener's handler budget for a wait is its `timeout_ms` plus one second, and a client
  that disconnects cancels the wait. `changed_since` names a snapshot and holds once the page's main-frame
  loader id, or its mutation guard's epoch or count, differs from what that snapshot saw (hard-sckn); the
  last eight snapshots of a tab are remembered, and their baselines outlive the navigation that clears
  the tab's current table, so a navigated page counts as changed. A snapshot the tab does not remember is
  `stale-snapshot`. A wait takes **no lock of the tab's**: an action on the same tab runs beside it, and its
  polling counts as the handle activity, so an hour-long wait does not idle the tab out.
- `net` (hard-xg6y hard-ovbx hard-vq5s). Chrome delivers network events per tab session, so **every tab has a
  ring of its own** (500 requests, oldest dropped first), handle-based like every tab command. It is fed by
  `Network.requestWillBeSent`, `requestWillBeSentExtraInfo`, `responseReceived`, `requestServedFromCache`,
  `loadingFinished` and `loadingFailed` from the tab's first attachment on, and holds metadata only. `net`
  lists the most recent `limit` (default 100, at most 500) whose URL contains `match` (case-insensitive)
  and whose resource `type` equals the filter, oldest first. A request that redirected stays listed under
  `<id>~<n>` with the redirect's status; the request it became keeps the id. `net_body` returns the response
  body through `Network.getResponseBody`: text, or base64 with `base64: true` where Chrome gives it so; at
  most 1 MiB of it, `truncated` when longer. A request with no response yet, a failed or redirected one, or
  a body Chrome has evicted is `body-unavailable`; an id the ring does not hold is `unknown-request`.
  `net_request` returns the headers (the extra-info headers, cookies included, win over the event's) and,
  through `Network.getRequestPostData`, the post data bounded the same way. On the CLI: `leash net TAB`,
  `leash net TAB body ID`, `leash net TAB request ID`. URLs, headers, bodies, cookie values and storage
  values are page data for the handle holder and are never a log line; the journal's anchors are identifiers only.
- `upload` (hard-o3za hard-qimz hard-2gnf): `paths` are 1 to 10 absolute paths of readable regular files, 10 GiB
  together (`invalid-request`, `too-large`), checked before the browser is asked. The row must be a
  `file-input` (`row-not-actionable` otherwise); it is revalidated like an action — current snapshot, same
  loader — but by node, not by role and name: it must still resolve to an `<input type=file>`, be enabled, and
  take several files only with `multiple`. The files are set with `DOM.setFileInputFiles`. Every other action
  refuses a `file-input` row with `row-not-actionable`.
- `hover` (hard-v1gs): the row is revalidated and hit-tested as a click's is, then one `mouseMoved` is
  dispatched at its point and the page settles two frames; nothing is pressed. Hover menus are in the next `snap`.
- `eval` with `index` and `snapshot` (hard-b20d, both or neither) calls the expression as
  `function(argument, element)`, `element` being the row's node (`DOM.resolveNode` of its backend id). The
  snapshot must be the tab's current one (`stale-snapshot`), the row must exist (`no-such-row`).
- `cookies` and `storage` (hard-ufb7) are read-only. `cookies` is `Network.getCookies` for the tab's URL,
  httpOnly ones included with their flags. `storage` reads `DOMStorage.getDOMStorageItems` for the page's
  security origin (an opaque origin such as about:blank is `invalid-request`); `items` is an object of key to
  value, at most 1000 items and 1 MiB (`truncated`). Nothing writes.
- **Concurrency** (hard-b1na). The listener admits 64 concurrent requests, not ox_ipc's default 16, and replies of
  up to 8 MiB (a 1 MiB body, escaped). Ten agents may run at once — five blocked in hour-long `wait`s on five
  tabs while five act — with nobody queued: a wait holds a connection and a fiber and takes no tab lock. `net`,
  `net_body`, `net_request`, `cookies`, `storage`, `debug` and `dialog` take none either; the actions,
  `eval`, `text`, `shot`, `snap` and `drive` serialize per tab.
- `eval` runs the expression as a function body in the page with `argument` bound; expression, argument, and result are each bounded to 64 KiB.
- `shot` writes a PNG to `path`, which must be an absolute path the service can write; the reply carries no image data.
- `snap` `match` filters rows by case-insensitive substring over role, name, and value; `limit` defaults to 120, `offset` pages; `truncated` is truthful. `settled:true` requires a stable document and at least one interactive AX row, or no possible interactive content in a cheap DOM selector count. Otherwise it retakes twice, then reports `settled:false` with `reason:"ax-tree-empty"` for unpopulated AX, `"document-changing"` for mutations, or `"dialog-open"` for a dialog. An empty AX tree with interactive DOM content falls back to at most 250 visible tag/ARIA-derived rows marked `source:"dom"`; normal rows have `source:"ax"`. Both use the same snapshot IDs and indices. DOM actions revalidate the original backend element identity, never a selector. These snapshots remain usable even when unsettled (field-lp65, field-jkx6).
- Non-password input values come from the live DOM property captured by DOMSnapshot, so the next snapshot reflects a fill that took effect, including React-controlled fields (field-cct4).
- Visible cross-origin iframes are informational `frame` rows named by their src origin with `state:["cross-origin"]`; they expose no inner-frame controls. Known reCAPTCHA, hCaptcha, and Turnstile request/frame loads also enter `debug` as warning-level console entries (field-vji1).
- A row's `name` may be empty: a control with no accessible name (an unlabelled native select, a bare text input, an icon button) is kept with its `role`, an empty `name`, and its `value` or `placeholder`, so it stays addressable by index (tab-zc36). `value` is omitted when the control has neither.
- `new` with a url and `nav` register or retain the handle before waiting for load. Both succeed with `loaded:true` on load, or `loaded:false` after the bounded 30 s load wait (field-m5jw). They refresh the current committed URL — after any redirect — and title in either case; an unfinished load is not a navigation failure. `new` without a url returns at once with `about:blank` and `loaded:true`.
- The CLI prints the `result` (or the error) as compact JSON; `--pretty` indents; `snap` and `list` also accept `--table` for a human-readable rendering. Every command names its positional arguments in its synopsis — `leash click [OPTION]… TAB SNAPSHOT INDEX` — and accepts only the options it uses, so `leash <command> --help` is the whole call; `--pretty`, `--config` and `--socket` are the client options every command shares. Exit status 0 on `ok:true`. A failure exits with its code's class from the error table below, not 1; command-line parse exits 124. `leash help errors` prints that table.

## Bundled agent skill (CLI-local)

These commands need no service, configuration file or caller identity. The executable embeds
all of `skill/`; it never loads the bundle from the caller's checkout or network.

- `leash skill show` prints the complete stamped `SKILL.md` as raw Markdown, not JSON.
- `leash skill install [PATH] [--dry-run] [--force] [--no-input]` installs the
  entrypoint and references under `PATH/leash/`; PATH is a skills root. With no
  PATH it discovers the existing `~/.claude`, `~/.codex`, `~/.pi` and
  `~/.agents` configuration directories and uses their `skills`, `skills`,
  `agent/skills` and `skills` roots, respectively, exactly as Nema does.
  It canonicalizes roots and installs each physical destination only once.
- Each target prints one compact JSON line `{"action":"installed","path":"…/leash"}`.
  Actions are `installed`, `replaced`, `current`, `declined`, `planned-install`
  or `planned-replace`. An exact installed bundle is `current`, without consent.
  A new explicit target requires no prompt; discovered new targets and replacements
  require interactive consent or `--force`. Non-TTY / `--no-input` refuses these
  writes without force. Dry-run neither writes nor prompts, including absent roots.
- Replacement first writes a complete sibling staging tree, renames the old tree
  to a backup, and moves the staged tree into place. Failed moves roll back; symlinks
  in the old tree are removed without following them. Cleanup failures report the
  completed replacement and retained backup path rather than reporting full success.
  Targets are independent: completed outcomes stay on stdout, with one canonical
  combined error on stderr if any target fails. Existing `usage` (64),
  `permission-denied` (77), `internal` (70) and `cli-parse` (124) apply.

The installed entrypoint's YAML `metadata.leash-version` and
`metadata.leash-commit` identify the binary that supplied it. The version is
`Leash.version`; commit is compiled from HEAD for local builds or `LEASH_COMMIT`
for archive/Nix builds (unknown if neither exists). No runtime Git call is made.

After a successful service response, the CLI adds this local field to `leash status`:

`skill = {state: "missing"|"stale"|"current", version: string, commit: string, installs: [{path: string, state: "missing"|"stale"|"current", version: string|null, commit: string|null}]}`

The installs list describes discovered defaults, not arbitrary explicit PATHs.
Absent installs are `missing`; an existing unstamped, unreadable or modified bundle
is `stale`. Any stale existing install makes the overall state stale; otherwise
at least one current install makes it current, and no installed bundle means
missing. Currency compares all embedded content as well as the stamp, so an edited
reference is stale even without a version/commit change. A missing install in
another harness's root does not invalidate an existing current copy. The service wire status carries version, Chrome, pid, headed and key_present. The CLI adds `commit` (the running binary's compiled commit) beside `skill`. A missing unit is `not-installed`; an installed inactive unit is `service-stopped`; an activating unit, an auto-restart, or a service whose Chrome generation is being relaunched is `service-restarting`. An active unit whose socket does not answer stays `service-unreachable` (daily-lqqn).

## Field meaning

Wire shapes stay in the sections above. Each field's meaning is the linked topic.

| Field | Topic |
| --- | --- |
| `v`, `cmd`, `args`, `ok`, `result`, `error.code`, `error.message`, `error.hint`, `error.detail` | [errors](help/errors.md) for codes; this file for the envelope |
| `tab`, `handle`, `origin`, `label`, `age_s`, `idle_s`, `closes_in_s`, `with_human`, `generation`, `reason`, disposition | [handles](help/handles.md) | [errors](help/errors.md) |
| `url`, `title`, `page_kind`, `loaded`, `dialog`, `popups`, `opener_url`, `state` (popup) | [handles](help/handles.md) for origin and page kind; this file for the wire object | [errors](help/errors.md) |
| `snapshot`, `rows`, `index`, `role`, `name`, `value`, `options`, `match`, `limit`, `offset`, `truncated`, `settled`, `source` | this file; acting on a row needs the handle in [handles](help/handles.md) | [errors](help/errors.md) |
| `mission`, `start_url`, `max_steps`, `max_procedures`, `deadline_s`, `dry_run`, `expect`, `out`, `status`, `playbook_choices`, `procedures`, `mission_expectations`, `operator_state`, `operator_steps`, `output_kinds`, `collected`, `model_cost`, `final`, `Step`, `Operation` | [drive](help/drive.md) | [errors](help/errors.md) |
| `site`, `entry`, `pages`, `shapes`, `procedures`, `slug`, `repeat`, `until`, `goal`, `use` | [playbooks](help/playbooks.md) | [errors](help/errors.md) |
| `script`, `file`, `source`, `returns`, `pages` (script), `args`, `records` | [scripts](help/scripts.md) | [errors](help/errors.md) |
| `checker`, `sentence`, `passed`, `score`, page-kind sentences | [expectations](help/expectations.md) | [errors](help/errors.md) |
| how to write a book | [authoring](help/authoring.md) |

## Error codes

A failed reply, and every failure the CLI prints on stderr, is one object `{code, message, hint, detail?}`. `hint` is always present: one line naming the next action, taken from this table. `detail?` is omitted when the error carries none (for `tab-gone`: `detail.disposition`; for `stale-snapshot`: the current snapshot id; for `model-unavailable`: `detail.code`, and on a drive `detail.steps`; for a handoff `timeout`: `detail.warnings`).

Client-side codes (`service-unreachable`, `not-installed`, `service-stopped`, `service-restarting`, `socket-permission`, `permission-denied`, `config-invalid`, `usage`, `cli-parse`, `invalid-response`) are printed by the CLI, not sent by the service. `service-restarting` is also what `leash status` prints when the service answers with `chrome: "restarting"`. They are in the same closed set so one parser handles both. A model's `detail.code` of `invalid-response` is a kind of `model-unavailable`, not the client-side code of the same name.

Exit status is the class below, not 1. `leash help errors` prints this table. The classes are the ones command `--help` documents; an exit outside this set makes help raise:

| class | exit | sysexits | when |
| --- | --- | --- | --- |
| usage | 64 | EX_USAGE | invalid request or invocation |
| data | 65 | EX_DATAERR | configuration, playbook, or stale or invalid page data |
| unknown | 66 | EX_NOINPUT | unknown or gone tab, row, or network request |
| unavailable | 69 | EX_UNAVAILABLE | service, browser, or model cannot be used |
| internal | 70 | EX_SOFTWARE | a defect, or a reply that is not protocol JSON |
| retry | 75 | EX_TEMPFAIL | timed out, or the tab cap is full |
| permission | 77 | EX_NOPERM | filesystem or socket permission, or capability or human-hold refused |
| parse | 124 | — | the command line did not parse; the command did not run |

| code | exit | meaning | hint | topic |
| --- | --- | --- | --- | --- |
| `invalid-request` | 64 | malformed JSON, unknown command, or bad arguments | fix the request; `leash <command> --help` names the arguments and one example | [errors](help/errors.md) |
| `ambiguous` | 66 | take matches several tabs; detail.matches lists them without handles | narrow the URL, title or label selector | [errors](help/errors.md) |
| `no-match` | 66 | take matches no tab | read `leash list` and use a matching URL prefix, title or label | [errors](help/errors.md) |
| `taken` | 77 | the tab already has a live handle | ask the holder for the handle | [errors](help/errors.md) |
| `with-human` | 77 | the tab is handed to the human; commands are refused until resume | the human holds this tab; wait, or return it with `leash resume TAB` | [errors](help/errors.md) |
| `tab-gone` | 66 | the handle names a closed tab; detail.disposition is closed_by_handle, closed_by_idle, closed_externally, or browser_lost | open a new tab with `leash new` | [errors](help/errors.md) |
| `unknown-tab` | 66 | no tab and no tombstone for the handle | that handle is not a tab; open a new tab with `leash new`, or ask the holder for the handle | [errors](help/errors.md) |
| `stale-snapshot` | 65 | the snapshot id or target row no longer matches the current page | read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting | [errors](help/errors.md) |
| `no-such-row` | 66 | the index is not in the snapshot | that index is not in the snapshot; `leash snap TAB` and use a listed index | [errors](help/errors.md) |
| `body-unavailable` | 66 | net body or request has no body to read, or Chrome has evicted it | that body is gone; `leash net TAB` and read a request that still has one | [errors](help/errors.md) |
| `unknown-request` | 66 | the tab's ring holds no request with that id | that id is not in the tab's ring; `leash net TAB` and use a listed id | [errors](help/errors.md) |
| `row-not-actionable` | 65 | the row is not visible, is disabled, is covered, or is the wrong kind of control | pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload` | [errors](help/errors.md) |
| `state-unchanged` | 65 | a check or uncheck did not change the control's checked state | snap and read the row's state; the control did not toggle, so pick another row or click its label | [errors](help/errors.md) |
| `dialog-open` | 65 | a dialog blocks page reads and actions; answer it first | answer it with `leash dialog TAB accept` or `leash dialog TAB dismiss`, then retry | [errors](help/errors.md) |
| `no-dialog` | 64 | dialog was asked with nothing to answer | nothing is open; `leash snap TAB` and call dialog only when a dialog is shown | [errors](help/errors.md) |
| `canceled-by-operator` | 77 | the operator canceled or dismissed the handoff notification | stop this mission; do not retry without a new instruction from the operator | [errors](help/errors.md) |
| `headless` | 69 | a handoff or notification asked for a human, but the browser is headless | nobody can see a headless browser: finish without the human or stop and report what is needed | [errors](help/errors.md) |
| `no-handoff` | 64 | resume on a tab nobody is waiting on | nobody is waiting; `leash handoff TAB REASON` starts one, and only then does `leash resume TAB` finish it | [errors](help/errors.md) |
| `url-refused` | 64 | scheme is not http, https, or about:blank, or the URL has userinfo | use an http or https URL with no userinfo, or about:blank | [errors](help/errors.md) |
| `tab-cap` | 75 | no capacity for a new tab | close a tab with `leash close TAB`, then retry `leash new` | [errors](help/errors.md) |
| `renderer-unresponsive` | 75 | a tab session CDP call exceeded its deadline; detail.entries carries its last debug entries | the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off | [errors](help/errors.md) |
| `timeout` | 75 | wait, handoff, or a bounded operation ran out of time; a handoff's detail.warnings lists the steps that failed | retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB` | [errors](help/errors.md) |
| `browser-unavailable` | 69 | Chrome is restarting | Chrome is restarting; retry `leash status` in a few seconds | [errors](help/errors.md) |
| `model-unavailable` | 69 | System One or the text helper failed, or no API key is configured; detail.code is missing-key, unavailable, timeout, authentication, invalid-response, input-too-large, model-mismatch, or text-helper-unavailable | read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry | [errors](help/errors.md) |
| `model-timeout` | 75 | a model call exceeded its per-call deadline | the model provider timed out; retry, or raise models.<kind>_timeout | [errors](help/errors.md) |
| `too-large` | 65 | expression, argument, result, fill text, or a script result is over its bound | shrink the text, expression, argument, or files under the bound and retry | [errors](help/errors.md) |
| `script-failed` | 65 | an eval expression or playbook script threw, rejected, or could not be compiled; message carries the engine error | read message; fix the expression, script, or page; `leash help scripts` explains function bodies and `leash playbook test` tests installed scripts | [errors](help/errors.md) |
| `script-invalid` | 65 | a playbook script's result does not fit its returns; message is the first mismatch | the result missed its returns shape; message is the first bad path, so fix the script or the returns | [errors](help/errors.md) |
| `playbook-invalid` | 65 | a playbook failed validation (load, check or accept); message names the rule | fix the playbook as the message says, then `leash playbook check ./DIR`; `leash help playbooks` lists the rules | [errors](help/errors.md) |
| `internal` | 70 | a defect; the message carries no page content | a defect, not a page failure; retry once, then report the message | [errors](help/errors.md) |
| `service-unreachable` | 69 | the CLI could not connect to the control socket | `systemctl --user start leash`, or pass --socket | [errors](help/errors.md) |
| `not-installed` | 69 | no leash.service unit is installed | Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash` | [errors](help/errors.md) |
| `service-stopped` | 69 | the leash unit is installed but inactive | `systemctl --user start leash`, then `leash status`; a brief service-restarting (75) right after start is normal - retry; tabs and snapshots from before the stop are gone, so re-open them | [errors](help/errors.md) |
| `service-restarting` | 75 | the leash unit is activating or auto-restarting, or Chrome's generation is being relaunched | Leash is restarting; retry `leash status` in a few seconds | [errors](help/errors.md) |
| `socket-permission` | 77 | the CLI was denied access to the control socket | the control socket is not readable; check its permissions, or pass --socket | [errors](help/errors.md) |
| `permission-denied` | 77 | the CLI was denied access to a filesystem path | check the path's permissions, or pass another path | [errors](help/errors.md) |
| `config-invalid` | 65 | the configuration file is missing, unreadable, or invalid | fix the reported problems; `leash config check` lists every one with the config path | [errors](help/errors.md) |
| `usage` | 64 | the command was invoked wrongly; the arguments do not match its synopsis | `leash <command> --help` shows the arguments and an example | [errors](help/errors.md) |
| `cli-parse` | 124 | Cmdliner rejected the command line; the command did not run | the command line did not parse; `leash <command> --help` shows the accepted form | [errors](help/errors.md) |
| `invalid-response` | 70 | the service reply was not a protocol object the CLI could decode | the service reply was not a protocol object; check `leash status` and retry | [errors](help/errors.md) |
