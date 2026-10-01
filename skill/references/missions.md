# Missions and playbooks

## Choose drive for bounded browser work

`leash drive MISSION` is the single mission entrypoint. It works with no playbooks, one playbook, many playbooks, and only unrelated playbooks. There is **no `run` command**, and the CLI is not `drive TAB GOAL`. Include the concrete result and any needed values in the mission; do not delegate a broader action than the user authorized.

```sh
leash drive 'Open Travel and return the visible titles and prices' \
  --url https://books.toscrape.com/ --out travel-state.jsonl
leash drive 'Complete this page search and open the matching result' \
  --tab TAB --max-steps 60 --deadline-s 300
```

| Option | Meaning |
| --- | --- |
| `--url URL` | Explicit `http://` or `https://` start, no userinfo. Opens a drive-owned tab. Does not replace an already populated `--tab`. A bad URL is `usage` and names this example; it does not wait for a prompt. |
| `--tab TAB` | Reuse your owned tab and leave it open. Without it Leash opens a temporary tab and closes it when the mission ends, including errors; a human handoff keeps it open. `final` is the last snapshot, not a promise that its tab still exists. |
| `--max-steps N` | On-the-fly executed-action cap, default 60. Must be a positive integer; 0 and negative are `usage`. The prediction cap is twice N. Not the playbook procedure cap. |
| `--expect SENTENCE` | Repeatable expectations for the mission DONE guard, with or without a playbook. Prefer concrete, verifiable results. |
| `--max-procedures N` | Playbook-lane procedure cap, default 40; not the operator action cap. |
| `--deadline-s S` | Whole mission budget, default 900 seconds. |
| `--out FILE` | Append tagged JSONL. `script-record` / `source: playbook` is a validated script record. `operator-state` / `source: operator` is one terminal bounded page observation. Use a deliberate writable path, not an existing valuable file. |
| `--dry-run` | Observe and decide once. No navigation, input, text helper, or `--out` write. Still makes billable model calls and may allocate a blank tab. |

`drive` holds the tab's action slot for the run; the CLI connection stays open until it returns. In a harness, use a tracked background job for a long mission, collect its result, and do independent work on other tabs in the meantime. Do not start another action/read on that tab while it is working. A missing model key or provider failure is `model-unavailable`; inspect its `detail.code` and partial trace before any retry. The service needs its own `OPENROUTER_API_KEY` or configured model credentials: setting a client shell variable does not update an already running systemd service. Do not print keys or change service credentials without authorization.

Playbook availability never blocks a usable browser task and never requires authoring a playbook first.

| Installed books | What happens |
| --- | --- |
| no-playbooks | No playbook question and no planner. The operator runs the whole mission. |
| one-book | JEV is offered that book and `NONE`. A lone book is never forced. |
| many-books | JEV chooses one book identity (`book:<file>`) or `NONE`. Unrelated procedures are not merged. |
| none-matching | `NONE` enters the operator on the current page. It is not `BLOCKED`, not discovery, and not a planner review. A procedure-level `NONE` or `BLOCKED` falls through the same way. |

On a blank tab without a URL, installed playbooks are offered first: a chosen book opens its own `entry` (so `leash drive 'collect every book in the Mystery category'` works with the books playbook installed). Otherwise pass `--url`, or include exactly one explicit `http://` or `https://` URL in the mission. Leash opens that page before the operator starts. With `--tab`, it works from the current page and does not replace an already populated page with `--url`. No URL or several URLs on a blank tab, no `--url` and no chosen book, returns `blocked` with the missing-start reason. That is not a missing playbook and it makes no model call. Do not invent a search engine or ask JEV to navigate from `about:blank`.

**Always pass `--expect`** with a concrete sentence the result must satisfy (`--expect 'the page shows You logged into a secure area'`): without one, `done` is only JEV's opinion, and an on-the-fly run has no answer field — the answer is the page, in `operator_state.page.text`. Code-checked sentence shapes are listed in [authoring](authoring.md#checker-vocabulary); others are judged by JEV. The operator never types a password: fill the password row yourself (`snap` marks it `password`) with `leash fill`, then drive the rest. A drive reply is large (tens of KB); write it to a file and read `status`, `reason`, `collected`, `mission_expectations`, `procedures[].outcome` and `operator_state.page.text` with `jq`.

On the fly, the result is the operator's observed page state: URL, title, at most 6000 characters of viewport text, indexed elements and values, scroll and coverage bounds, action history, predictions and timings. `page.coverage` is a `+`-joined string, always starting with `viewport`, then only the flags that hold: `truncated`, `omitted`, `above`, `below`. That state is bounded. It is not every record across pagination or offscreen content, and it is not a validated script dataset. Visible titles and prices in that viewport do reach JEV and, on `TYPE_TEXT`, the text helper. Prepared script payloads still bypass every model.

`--out` does not require a playbook. An on-the-fly file contains one `{"kind":"operator-state","source":"operator","state":...}` line. A playbook collector streams `{"kind":"script-record","source":"playbook","playbook":…,"procedure":…,"script":…,"record":{…}}` lines; the data is under `.record`. A mixed run writes both and lists both in `output_kinds`. Do not treat operator-state prose as normalized records. A dry run writes neither.

A dry run is a plan check, not evidence that the page works. Supplied mission expectations are verified on a fresh observation before DONE is accepted; named page kinds require a playbook, so use concrete text, row, download or dialog expectations without one. After a live run inspect `status`, `reason`, `operator_state` (coverage included), `output_kinds`, `procedures` and their expectations, `mission_expectations`, and `final`. Protocol success/exit 0 can still contain `blocked`, `failed`, `handoff`, `limit`, `deadline`, or `error`. An operator action cap is `limit`. Even `done` is JEV's opinion unless expectations passed; check the requested outcome independently, especially an external submission. Repeating a form-submit mission is not idempotent: keep executed-input evidence and do not automatically rerun an uncertain mutation.

An unmet expectation in the operator lane returns `blocked` with the failed check. It does not call the planner or hand the tab to the human. In a playbook mission the planner may still ask for the human when a selected procedure fails twice or an argument cannot be filled; use the live headed tab, communicate what is needed, and follow [handoff/resume](browser.md). A dialog must be answered deliberately. A procedure's failed expectations or rejected script can cause the **whole procedure to replay once**; keep payment, messaging, deletion, and other non-idempotent submissions out of a retryable procedure unless their repetition is explicitly safe and authorized.

## Inspect and test a playbook before relying on it

Playbooks are installed at `$XDG_CONFIG_HOME/leash/playbooks/NAME/playbook.json` (normally `~/.config/leash/playbooks/NAME/playbook.json`), with their script files beside them. A standalone JSON file in the playbooks root is not the current format. Examples in this reference must be installed by the operator/agent when the task authorizes that configuration change; they are not guaranteed to ship on this machine.

For validated, reusable records, check `leash playbook list` first. The on-the-fly operator can still return bounded page state without a book; it does not emit `script-record` lines. No site playbooks are installed automatically. Start with the complete example below, a trusted site playbook from the source checkout’s `examples/playbooks/` (for example `books.toscrape.com/` for catalogue collection), or a reviewed discovery proposal. Copy the whole example directory, including scripts, into the configured playbooks root only when authorized; run local validation and test its extraction on a permitted page before using playbook `drive --out`.

| Command | What it does |
| --- | --- |
| `leash playbook list` | List validated installed sites/descriptions; output is tab-separated text. |
| `leash playbook show NAME` | JSON inspection including script text and resolved expectation checkers. |
| `leash playbook check ./DIR` | Local validation of `DIR/playbook.json`, paths, shapes, procedures, and expectations. Script syntax is **skipped** for a directory path. |
| `leash playbook check NAME` | The same checks for an installed name plus JS syntax compilation in a temporary blank tab. Needs the service; it never invokes the scripts and closes its own temporary tab. |
| `leash playbook test NAME/SCRIPT --tab TAB [--arg K=V]` | Execute one prepared script on your tab's actual page and validate its result. Repeat `--arg` for string arguments; this is **not a dry run**. |
| `leash playbook accept FILE` | Validate and install/merge a reviewed proposed playbook or procedure. It preserves existing scripts but can replace same-slug procedures; use only for an authorized persistent update. |

A directory path must contain a slash, for example `./my-playbook`; a bare name means an installed playbook. `test` takes an installed `NAME/SCRIPT`, not a file path or a procedure slug. A successful syntax check does not prove runtime extraction or site permissions. Test on a permitted page, then inspect the shape, sample, and count. Test replies carry `value`, `records`, and `truncated`; list results over 1 MiB are sampled to five records, while an oversized single record is not echoed (`value: null`).

## A small complete collection playbook

For an authorized example installation, save the following as `playbook.json` inside the configured `playbooks/example.com/` directory. It collects only the page title and URL; there is no network mutation or form submission.

```json
{
  "site": "example.com",
  "entry": "https://example.com/",
  "description": "Read the Example Domain page title and URL.",
  "pages": [
    {
      "name": "home",
      "description": "The Example Domain page",
      "url_pattern": "https://example.com/*",
      "text_marker": "Example Domain"
    }
  ],
  "shapes": {
    "page": {"title": "string", "url": "url"}
  },
  "scripts": {
    "page-info": {
      "source": "/** returns: \"page\" */\nreturn {title: document.title, url: location.href};",
      "description": "Collect this page's title and URL.",
      "pages": ["home"]
    }
  },
  "procedures": [
    {
      "slug": "read-page",
      "description": "Confirm the page and collect its title and URL.",
      "steps": [
        {"goal": "Confirm this is the Example Domain page."},
        {"script": "page-info"}
      ],
      "expect": ["the page is home", "no dialog is open"]
    }
  ]
}
```

Once installed, with a permitted running service:

```bash
set -o pipefail
leash playbook show example.com
leash playbook check example.com || exit 1
TAB=$(leash new https://example.com | jq -er '.tab') || exit 1
leash playbook test example.com/page-info --tab "$TAB" || exit 1
leash drive 'Collect the title and URL of https://example.com once'   --tab "$TAB" --out /tmp/leash-page-info.jsonl   --expect 'the page is home' --deadline-s 60 --max-procedures 3
leash close "$TAB"
```

This convenience snippet needs Bash and jq for `.tab`. Without jq, read that returned handle and pass it explicitly. The `--out` path is illustrative; choose a fresh path for your real output. Judge success by the run's status/trace **and** the record, not by the exit code alone.

## Prepared scripts and pagination

For a larger script, declare `"file": "scripts/list-items.js"` instead of `source`. Exactly one is required; inline source is capped at 4096 bytes. Files must be relative `.js` paths inside the playbook, with no `..`; resolved symlinks cannot escape the directory. The script is the body of an async function receiving `args` (an object of strings), not a standalone module. It may use the logged-in page's same-origin `fetch` without extracting session tokens. Keep requests within the task and site permissions.

`returns` sits beside the script, not as an inline shape on the declaration. Put a leading `/** returns: ... */` block in the `.js` file, or `scripts/<name>.returns.json`, or `"returns": "<shape>"` naming an entry of the playbook's `shapes` object. The `...` is a shape or a shape name. A record or a list of records is valid. Shapes use `string`, `number`, `boolean`, `url` (absolute http/https), nested objects, or a one-element array describing list items. A field name ending in `?` is optional (absent/null allowed). Undeclared fields, required nulls, missing fields, and wrong types fail closed with `script-invalid` and the first bad path. Throws/rejections are `script-failed`. Serialized output defaults to an 8 MiB bound; `max_bytes` may increase it only up to 16 MiB. Larger output is `too-large`. Calls are bounded and serialized on the tab.

A script declares `description` in one sentence and optional `pages` (page-kind names; absent means every page of the site; `[]` means never offered — a control script for `repeat.until` only). Inside a playbook procedure, the operator question offers `run_script:<name>` for every script whose pages match the current page kind, beside click, type, select, scroll, wait, done and blocked. The criterion text is the description. JEV can choose the script the way it chooses a click. The runner fills the script's declared args, validates the result, and puts a one-line summary in recent actions (`ran list-page: 20 records`, or scalar fields of at most 120 characters), never the records. A throw or invalid result is `ran <name>: failed (<first line>)` and does not end the procedure; the procedure's `expect` still decides. A script JEV already ran on the same address in the same step is not run again; JEV reads `ran <name>: already collected on this page (…)`. On-the-fly missions have no scripts. A script runs only after the page's document has loaded. A chosen playbook opens its `entry` only when the tab is elsewhere (blank, or another site); a tab already on the site keeps its page, so "collect the books on this page" means this page.

Every script and procedure argument declares its source: `{"from":"mission"}`, `{"from":"mission","optional":true}`, or `{"const":<value>}`. A list of names is refused. `playbook check` and load fail if a script reads `args.<ident>` that is not declared. A required mission arg the text helper cannot fill blocks the run and names the arg. Known values are reused.

The loader refuses a playbook in which no procedure has a goal step, with the message: every procedure is a script; use `leash eval` or `playbook test`, or add the goal steps JEV drives. A script-only procedure is allowed only as a `use:` sub-procedure. `playbook check` refuses a directory with stray JSON beside `playbook.json` (one book file only). Old inline `returns` and undeclared args are refused with a message naming the new form.

Procedures have a lowercase slug, a useful description, declared arguments, steps, and a **nonempty `expect` list**. `{name}` placeholders substitute supplied string arguments. Step forms are:

- `{"goal":"Search for {query}"}`: operator-driven UI goal.
- `{"goal":"Open the next page of this category.","until":["the address changed","the page is category"]}`: the step ends `done` as soon as every `until` sentence holds after an executed action, without asking JEV to judge the page it landed on. Use it for relative goals ("next", "another"). Each sentence is a code checker or `the address changed` (the URL differs from the step's start); a judgment sentence is refused at load.
- `{"use":"another-procedure","args":{"query":"{query}"}}`: compose a known procedure; cycles are refused. `optional: true` permits a blocked subprocedure to be skipped.
- `{"script":"list-items","args":{"brand":"{brand}"}}`: run a prepared collection script.
- `{"navigate":{"script":"next-url"}}`: run a prepared control script returning exactly `{url: string}`, then navigate the real browser tab. Only permitted URL schemes apply.

A procedure's `repeat` can specify `next` (next-page procedure slug), `max` (page cap), `until` (an expectation sentence or `{"script":"last-page"}` returning exactly `{done: boolean}`), `delay_ms` (default 500), and `key` (record field for run-wide deduplication). Termination is checked before the cap; reaching the cap with pages still remaining is explicit failure, not a complete dataset. Control-script values never become collected records. Repeat helper procedures are not offered as mission choices.

Pagination is a goal step JEV drives (see [authoring](authoring.md)); a script reads the page it is on. Use `navigate` from a control script only when a URL cannot be reached by clicking. Do not rewrite the DOM/history to trick page-kind checks. Pagination, deduplication, and endpoint fetching do not remove the need to verify coverage and respect the site's rate limits.

## Read data and cost evidence

With `--out`, read `kind` before interpreting a line. `script-record` lines stream as prepared collection completes. `operator-state` is one terminal object. The reply keeps only up to five bounded script samples, not the entire dataset, and always carries `operator_state` when the operator ran. On failure the file may contain valid **partial** script records or the last operator state; preserve it and report the incomplete run. Do not present a bounded viewport as a complete catalogue.

- `collected` / `data.count`: prepared script record count; `data.first`: bounded sample. Not a count invented from page prose.
- `data.pages`: runner repeat pages, **not** internal fetch count. A one-shot fetch collector can correctly have zero repeat pages.
- `data.scripts`: script names, calls, and record counts; procedure script traces include URL, bytes, elapsed time, and any error.
- `output_kinds`: `script-record`, `operator-state`, both, or neither.
- `model_calls`: actual attempted provider requests, including retries/failed attempts; `data.model_calls_by_kind` breaks them down by role.
- `data.reported_cost`: sum of costs providers returned. `model_cost` is that sum only when every counted call was priced; otherwise `model_cost` is `null`. `data.cost_unreported` counts the unpriced calls. `null` is unknown, not zero.

Leash does not send prepared script records to its models. Viewport text, including visible records, does reach the operator and the text helper. Selection uses bounded semantic state and counts; prepared code does extraction. Report count or coverage, output location, verification, model-call count, and `model_cost` with the null caveat when relevant. `drive` has no `--max-cost` flag.

## Discover and review reusable procedures

```sh
leash discover https://example.com --goal 'Find the documentation link'   --max-turns 5 --max-steps 20 --deadline-s 120 --max-cost 0.25
```

`discover` is live planner-led exploration, not harmless help: it can navigate and act and makes billable calls. Its reported-cost cap cannot account for missing provider cost. Keep the goal within authorization. It writes a proposed playbook; it does not silently install it. Mission-generated procedure proposals are also reported under `proposals` and stored in Leash's XDG state directory. Review their content and resolved checkers before an authorized `playbook accept FILE`. Planner output cannot supply executable JavaScript; only fixed Leash code, agent-authored eval bodies, and prepared loaded scripts reach the page's JS engine.
