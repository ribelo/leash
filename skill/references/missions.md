# Missions and playbooks

## Choose drive for bounded browser work

`leash drive MISSION` is the single mission entrypoint. It selects an installed site playbook, or falls back to the single-goal operator when none fits. There is **no `run` command**, and the current CLI is not `drive TAB GOAL`. Include the intended site, concrete result, and any needed values in the mission; do not delegate a broader action than the user authorized.

```sh
leash drive 'Open https://example.com and show the Example Domain page'   --expect 'the page contains documentation examples'   --deadline-s 60 --max-procedures 3 --owner browser-example
```

| Option | Meaning |
| --- | --- |
| `--tab TAB` | Reuse your owned tab and leave it open. Without it Leash opens a temporary tab and closes it when the mission ends, including errors; a human handoff keeps it open. `final` is the last snapshot, not a promise that its tab still exists. |
| `--expect SENTENCE` | Repeatable expectations for the mission DONE guard, with or without a playbook. Prefer concrete, verifiable results. |
| `--max-procedures N` | Mission procedure cap, default 40; not an operator step count. |
| `--deadline-s S` | Whole mission budget, default 900 seconds. |
| `--out FILE` | Stream validated collected records as JSONL. Use a deliberate writable output path, not an existing valuable file. |
| `--dry-run` | Ask the decision levels and show the choice/trace without navigation, actions, or scripts. Still makes billable model calls and may allocate a blank tab. |

`drive` holds the tab's action slot for the run; the CLI connection stays open until it returns. In a harness, use a tracked background job for a long mission, collect its result, and do independent work on other tabs in the meantime. Do not start another action/read on that tab while it is working. A missing model key or provider failure is `model-unavailable`; inspect its `detail.code` and partial trace before any retry. The service needs its own `OPENROUTER_API_KEY` or configured model credentials: setting a client shell variable does not update an already running systemd service. Do not print keys or change service credentials without authorization.

Without a playbook, drive is a **single-goal UI operator**, not a collection planner. On a blank tab include exactly one explicit `http://` or `https://` URL; Leash opens that page before asking the operator. With `--tab`, it works from the current page. No URL or several URLs on a blank tab returns `blocked` with guidance rather than guessing a site. The operator can use visible controls and links but does not author extraction scripts or produce structured records for `--out`: install and test a collection playbook for that, or use `text`/bounded `eval` yourself.

A dry run is a plan check, not evidence that the page works. The no-playbook fallback also verifies supplied mission expectations on a fresh observation before accepting DONE; named page kinds require a playbook, so use concrete text, row, download or dialog expectations without one. After a live run inspect `status`, `reason`, `procedures` and their expectations, `mission_expectations`, and `final`. Protocol success/exit 0 can still contain `blocked`, `failed`, `handoff`, `limit`, `deadline`, or `error` rather than a completed mission. A fallback operator step cap is reported as `limit`. Even `done` needs an independent check of the requested outcome, especially an external submission or a collected dataset. Do not rerun a mission blindly after an uncertain dispatch.

An unmet expectation in the no-playbook operator returns `blocked` with the failed check; it does not call the planner or transfer ownership. In a playbook mission the planner may ask for the human; use the live headed tab, communicate what is needed, and follow [handoff/resume](browser.md). A dialog must be answered deliberately. A procedure's failed expectations or rejected script can cause the **whole procedure to replay once**; keep payment, messaging, deletion, and other non-idempotent submissions out of a retryable procedure unless their repetition is explicitly safe and authorized.

## Inspect and test a playbook before relying on it

Playbooks are installed at `$XDG_CONFIG_HOME/leash/playbooks/NAME/playbook.json` (normally `~/.config/leash/playbooks/NAME/playbook.json`), with their script files beside them. A standalone JSON file in the playbooks root is not the current format. Examples in this reference must be installed by the operator/agent when the task authorizes that configuration change; they are not guaranteed to ship on this machine.

For structured collection, check `leash playbook list` before promising records: the no-playbook operator cannot collect JSONL. No site playbooks are installed automatically. Start with the complete example below, a trusted site playbook from the source checkout’s `examples/playbooks/` (for example `books.toscrape.com/` for catalogue collection), or a reviewed discovery proposal. Copy the whole example directory, including scripts, into the configured playbooks root only when authorized; run local validation and test its extraction on a permitted page before using `drive --out`.

| Command | What it does |
| --- | --- |
| `leash playbook list` | List validated installed sites/descriptions; output is tab-separated text. |
| `leash playbook show NAME` | JSON inspection including script text and resolved expectation checkers. |
| `leash playbook check ./DIR` | Local validation of `DIR/playbook.json`, paths, shapes, procedures, and expectations. Script syntax is **skipped** for a directory path. |
| `leash playbook check NAME` | The same checks for an installed name plus JS syntax compilation in a temporary blank tab. Needs the service/owner; it never invokes the scripts and closes its own temporary tab. |
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
  "scripts": {
    "page-info": {
      "source": "return {title: document.title, url: location.href};",
      "returns": {"title": "string", "url": "url"}
    }
  },
  "procedures": [
    {
      "slug": "collect-page-info",
      "description": "Collect this page's title and URL once.",
      "steps": [{"script": "page-info"}],
      "expect": ["the page is home", "no dialog is open"]
    }
  ]
}
```

Once installed, with a permitted running service:

```bash
set -o pipefail
OWNER="collection-example-$$"
leash playbook show example.com
leash playbook check example.com --owner "$OWNER" || exit 1
TAB=$(leash new https://example.com --owner "$OWNER" | jq -er '.tab') || exit 1
leash playbook test example.com/page-info --tab "$TAB" --owner "$OWNER" || exit 1
leash drive 'Collect the title and URL of https://example.com once'   --tab "$TAB" --out /tmp/leash-page-info.jsonl   --expect 'the page is home' --deadline-s 60 --max-procedures 3   --owner "$OWNER"
leash close "$TAB" --owner "$OWNER"
```

This convenience snippet needs Bash and jq for `.tab`. Without jq, read that returned handle and pass it explicitly. The `--out` path is illustrative; choose a fresh path for your real output. Judge success by the run's status/trace **and** the record, not by the exit code alone.

## Prepared scripts and pagination

For a larger script, declare `"file": "scripts/list-items.js"` instead of `source`. Exactly one is required; inline source is capped at 4096 bytes. Files must be relative `.js` paths inside the playbook, with no `..`; resolved symlinks cannot escape the directory. The script is the body of an async function receiving `args` (an object of strings), not a standalone module. It may use the logged-in page's same-origin `fetch` without extracting session tokens. Keep requests within the task and site permissions.

`returns` declares a record or list of records. Shapes use `string`, `number`, `boolean`, `url` (absolute http/https), nested objects, or a one-element array describing list items. A field name ending in `?` is optional (absent/null allowed). Undeclared fields, required nulls, missing fields, and wrong types fail closed with `script-invalid` and the first bad path. Throws/rejections are `script-failed`. Serialized output defaults to an 8 MiB bound; `max_bytes` may increase it only up to 16 MiB. Larger output is `too-large`. Calls are bounded and serialized on the tab.

Procedures have a lowercase slug, a useful description, optional string argument names, steps, and a **nonempty `expect` list**. `{name}` placeholders substitute supplied string arguments. Step forms are:

- `{"goal":"Search for {query}"}`: operator-driven UI goal.
- `{"use":"another-procedure","args":{"query":"{query}"}}`: compose a known procedure; cycles are refused. `optional: true` permits a blocked subprocedure to be skipped.
- `{"script":"list-items","args":{"brand":"{brand}"}}`: run a prepared collection script.
- `{"navigate":{"script":"next-url"}}`: run a prepared control script returning exactly `{url: string}`, then navigate the real browser tab. Only permitted URL schemes apply.

A procedure's `repeat` can specify `next` (next-page procedure slug), `max` (page cap), `until` (an expectation sentence or `{"script":"last-page"}` returning exactly `{done: boolean}`), `delay_ms` (default 500), and `key` (record field for run-wide deduplication). Termination is checked before the cap; reaching the cap with pages still remaining is explicit failure, not a complete dataset. Control-script values never become collected records. Repeat helper procedures are not offered as mission choices.

Use native `navigate` plus extraction for pages that require browser navigation, or a bounded same-origin fetch collector when appropriate. Do not rewrite the DOM/history to trick page-kind checks. Pagination, deduplication, and endpoint fetching do not remove the need to verify coverage and respect the site's rate limits.

## Read data and cost evidence

With `--out`, validated records stream as JSONL as collection completes. The reply keeps only up to five bounded samples, not the entire dataset. On failure the output may contain valid **partial** data; preserve it and report the incomplete run rather than presenting it as complete. Verify file records, uniqueness, expected bounds, and completeness against the task.

- `collected` / `data.count`: collected record count; `data.first`: bounded sample.
- `data.pages`: runner repeat pages, **not** internal fetch count. A one-shot fetch collector can correctly have zero repeat pages.
- `data.scripts`: script names, calls, and record counts; procedure script traces include URL, bytes, elapsed time, and any error.
- `model_calls`: actual attempted provider requests, including retries/failed attempts; `data.model_calls_by_kind` breaks them down by role.
- `model_cost`: sum of costs **reported by providers**; `data.cost_unreported > 0` means a partial total, not free calls.

Leash does not send collected script records to its models. Selection uses bounded semantic state and counts; prepared code does extraction. Report count, output location, verification, model-call count, and reported cost with the missing-cost caveat when relevant. `drive` has no `--max-cost` flag.

## Discover and review reusable procedures

```sh
leash discover https://example.com --goal 'Find the documentation link'   --max-turns 5 --max-steps 20 --deadline-s 120 --max-cost 0.25   --owner browser-example
```

`discover` is live planner-led exploration, not harmless help: it can navigate and act and makes billable calls. Its reported-cost cap cannot account for missing provider cost. Keep the goal within authorization. It writes a proposed playbook; it does not silently install it. Mission-generated procedure proposals are also reported under `proposals` and stored in Leash's XDG state directory. Review their content and resolved checkers before an authorized `playbook accept FILE`. Planner output cannot supply executable JavaScript; only fixed Leash code, agent-authored eval bodies, and prepared loaded scripts reach the page's JS engine.
