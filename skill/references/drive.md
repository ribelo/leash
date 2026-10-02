# Drive

## Durable traces

Every public drive outcome is saved by default. `trace_path` names its existing
private JSON file; errors return `detail.trace_path`. This is a safe typed
projection, not the full live reply: no page text, handles, raw state, or records;
password text is `[password]`. Inspect offline with `leash traces list`,
`leash traces show FILE`, and `leash traces prune --dry-run`.
`leash help traces` describes the schema, switch, and retention defaults
(20 newest traces per site, 30 days; uncompiled done traces survive both).
A storage failure is logged without changing the drive outcome.

`leash drive MISSION` is the one mission command. It runs on one tab toward one goal until `done`, `blocked`, a cap, a deadline, or an error, and returns the trace and a final snapshot. Leash never asserts that the goal is achieved. There is no `run` command, and the call is not `drive TAB GOAL`. Include the concrete result and any needed values in the mission. Do not delegate a broader action than the user authorized.

```sh
leash drive 'Open Travel and return the visible titles and prices' --url https://books.toscrape.com/ --out /tmp/travel-state.jsonl
leash drive 'Complete this page search and open the matching result' --tab TAB --max-steps 60 --deadline-s 300
```

The connection stays open until the mission returns. A long mission can run in the background while you work on other tabs. Do not start another action or read on that tab while it is working.

Models are OpenRouter. The service needs `OPENROUTER_API_KEY` in its own environment, or `models.api_key` in the configuration. The key is the operator's. Setting a variable in the client shell does not update an already running service. A missing key or a provider failure is `model-unavailable`; read `detail.code` and the partial trace before any retry.

## Options

| Option | Meaning |
| --- | --- |
| `--url URL` | Explicit http or https start, no userinfo. Opens a drive-owned tab. Does not replace an already populated `--tab`. A bad URL is `usage` and names a correct example. |
| `--tab TAB` | Reuse this tab and leave it open. Without it, Leash opens a temporary tab and closes it when the mission ends, including errors. A human handoff keeps it open. `final` is the last snapshot, not a promise that its tab still exists. |
| `--max-steps N` | On-the-fly executed-action cap, default 60. Must be a positive integer. The prediction cap is twice N. Not the playbook procedure cap. |
| `--max-procedures N` | Playbook-lane procedure cap, default 40. Not the operator action cap. |
| `--deadline-s S` | Whole mission budget, default 900 seconds. Must be positive when present. |
| `--expect SENTENCE` | Repeatable mission expectation the DONE guard verifies, with or without a playbook. |
| `--out FILE` | Append tagged JSONL. Use a deliberate writable path, not an existing valuable file. |
| `--dry-run` | Observe and decide once. No navigation, input, text helper, or `--out` write. Still makes billable model calls and may allocate a blank tab. |

Always pass `--expect` with a concrete sentence the result must satisfy. Without one, `done` is only JEV's opinion. Code-checked sentences are in `leash help expectations`. The operator never types a password: fill that row yourself (`snap` marks it `password`) with `leash fill`, then drive the rest.

A drive reply is large. Write it to a file and read the fields below. Do not paste the whole reply into the chat.

## Prefer drive for goals

Drive learns reusable procedures from successful missions; manual commands do not. Use
manual commands for inspection and for steps drive cannot do. Learning matches single-entry-kind operations across independent successful traces, not complete mission paths; consent and off-final-host entry operations do not become procedures. Learned top-level procedures require two goal steps and meaningful result checks. Learning defaults to draft and runs after the reply, so the reply's `model_calls`,
`model_cost`, `proposals` and `installed` do not include that compile. `status` reports
it; `learning.mode = "off"` disables learning.
With `--tab HANDLE`, the supplied tab stays open whatever the outcome. Without `--tab`,
drive opens and closes its own tab on success, failure, blocked, deadline, or error. A
planner handoff waits at most `handoff.timeout_s` (300 seconds by default). On expiry,
the result is `handoff-expired`; the tab stays open as an agent tab, `with_human` is
cleared, and a second notification says "the agent gave up waiting; the tab is still open".
Normal idle cleanup applies later. A resumed mission handoff also leaves the tab open.

The planner can answer `continue` with up to `learning.planner_actions` ordinary
click/fill/press/scroll/nav actions naming rows from its snapshot. They use the public
revalidation path, never raw JavaScript. They appear in `planner_turns[].steps` and in
durable trace steps with `source: "planner"`, including a failed attempt. Control then
returns to JEV on the current page.

JEV only answers `BLOCKED`; the planner owns every interruption. Its `notify` answer
sends one line through `notify.command` without handing over the tab, then returns to
the loop. Notifications and handoff waits are recorded in `unattended`; failed or
unavailable notification commands never fail a mission.

A detected CAPTCHA/bot challenge triggers the planner before JEV. With
`challenges.attempt = true` (default), it may try ordinary actions on visible snapshot
rows, bounded by `learning.planner_actions` per turn and `challenges.turns` (default 2).
No raw JavaScript, invented coordinates, or external solver is allowed. Clearing the
challenge returns to JEV. Disabling attempts or exhausting the bound hands off with
reason `captcha`; its expiry ends `blocked` with `detail.challenge` naming the origin.
Attempts, turns and outcomes are recorded in `unattended`. This is a bounded attempt,
not a claim of measured live CAPTCHA success. Debug-only evidence is conservatively
kept for that document until navigation; unrelated DOM mutations do not prove clearance.

## Lanes

Playbooks are optional. A missing book never blocks a usable browser task and never requires you to author one first.

| Installed books | What happens |
| --- | --- |
| no-playbooks | No playbook question and no planner. The operator runs the whole mission. |
| one-book | JEV is offered that book and `NONE`. A lone book is never forced. |
| many-books | JEV chooses one book identity (`book:<file>`) or `NONE`. Books are not merged. |
| none-matching | `NONE` enters the operator on the current page. It is not `BLOCKED`, not discovery, and not a planner review. A procedure-level `NONE` or `BLOCKED` falls through the same way. |

On a blank tab without a URL, installed playbooks are offered first. A chosen book opens its own `entry`. Otherwise pass `--url`, or include exactly one explicit http or https URL in the mission. With `--tab`, Leash works from the current page and does not replace an already populated page with `--url`. No URL and no chosen book, on a blank tab, returns `blocked` with the missing-start reason. That is not a missing playbook and it makes no model call. Do not invent a search engine or ask JEV to navigate from `about:blank`.

## Reading a trace

A nested `use` child has its own `procedures[]` entry. It finishes before its parent is verified and recorded, so child entries precede the parent: execution order, not just top-level selections. A successfully completed parent remains visible when a child satisfies the mission expectations; caps or failures inside a child can stop before the parent completes. Transient planner procedures may appear as `planned: true`; reviewed candidates are listed under `proposals`, not silently installed.

Exit 0 means the service answered. It does not mean the mission succeeded. Read:

- `status` — `done`, `blocked`, `failed`, `handoff`, `handoff-expired`, `limit`, `deadline`, or `error`. An operator action cap is `limit`.
- `reason` — why it stopped, when present.
- `playbook_choices` — decision order, including a JEV `NONE`.
- `procedures[].slug`, `outcome` (`verified`, `failed`, `skipped`, `planned`), and `expectations`.
- `steps[].operation`, `index`, and `probabilities.op` — what JEV picked and how sure it was.
- `collected` — how many validated script records were streamed.
- `mission_expectations` — the DONE guard, each sentence, checker, and whether it passed.
- `operator_state.page.text` — on the fly, the answer is the page, at most 6000 characters of viewport text. `page.coverage` is a `+`-joined string starting with `viewport`. `page.page_kind` is the kind JEV was shown (`page.page_kind_source` is `declared` or `inferred`); `page.url` and the snapshot retain the actual browser URL.
- `output_kinds` — `script-record`, `operator-state`, or both.
- `model_cost` — the drive's own calls; null when any of those is unpriced. Learning compile cost is not included. `data.reported_cost` is the known subtotal of the same calls.
- `final` — the last snapshot.

`--out` lines are tagged. `{"kind":"script-record","source":"playbook",...}` has the record under `.record`. `{"kind":"operator-state","source":"operator","state":...}` is one terminal bounded observation, not a record list. A dry run writes neither.

An unmet expectation in the operator lane returns `blocked`. It does not call the planner. In a playbook mission the planner may ask for the human when a selected procedure fails twice or an argument cannot be filled. A procedure's failed expectations or a rejected script can cause the whole procedure to replay once. Keep payment, messaging, deletion, and other non-idempotent submissions out of a retryable procedure unless repeating them is explicitly safe and authorized.

Repeating a form-submit mission is not idempotent. Keep the executed-input evidence and do not automatically rerun an uncertain mutation.
