---
status: ready-for-agent
milestone: 9
---

# Extract: prepared scripts in playbooks, deterministic batch runs

## Problem Statement

The operator's most valuable browser automation is batch work — collect every product and price from a listing, walk every page of an archive — which today he does by reverse-engineering the site's internal API. Doing it with JEV clicking would be slow and expensive and would give a slightly different answer every time. What is wanted is automation no worse than a reverse-engineered API: written once, run the same way every time, cheap, and inside the logged-in browser so that no token extraction is needed.

## Solution

Playbooks gain a `scripts:` section of prepared JavaScript with a declared output shape. A procedure step may be `script: <name>`; its output is validated and collected as data. Procedures may `repeat` over pages with a bounded next-procedure loop. `leash extract <playbook>/<procedure>` runs a procedure deterministically with no procedure-level JEV and no planner, writing JSON Lines. Scripts may read the DOM or call the site's own endpoints with `fetch` from the page. Scripts are playbook data: written by the operator, or proposed by Luna during `discover` and merged only by `leash playbook accept` — model output never becomes JavaScript at run time.

## User Stories

1. As a playbook author, I want a `scripts:` section where each script has a `name`, `description`, `source` (a JavaScript function body receiving `(args)` and returning a value or a promise), `returns` (a declared shape) and optional `timeout_ms`, so that extraction logic is written once and named. ^extr-d5bv
2. As a playbook author, I want `returns` to declare either a record or a list of records with typed fields (`string`, `number`, `boolean`, `url`, `string?` optional, nested lists), so that output is checked against what I meant. ^extr-zdst
3. As a runner, I want a `script: <name>` step (with `args`) to run the script in the tab's page through `Runtime.callFunctionOn` with `awaitPromise`, validate the result against `returns` fail-closed with the path of the first mismatch, and bound it (default 8 MiB, configurable per script), so that bad or huge output never reaches the caller as data. ^extr-8o1h
4. As a playbook author, I want scripts able to call the site's own endpoints with `fetch` (same origin, the page's cookies), so that an internal API is used from inside the logged-in page without extracting tokens. ^extr-vgir
5. As a playbook author, I want a procedure's `repeat: {next: <slug>, max: N, until: "<expectation sentence>", delay_ms: M, key: "<field>"}` to run the procedure body, then the `next` procedure, until `next`'s expectations fail, `until` holds, or `max` is reached, waiting `delay_ms` (default 500) between pages and de-duplicating records by `key`, so that pagination is bounded and polite without branching in the file. ^extr-ve3k
6. As an operator, I want `leash extract <playbook>/<procedure> [--tab T] [--arg k=v]... [--out file.jsonl] [--max-pages N]` to run the procedure deterministically — no procedure-level JEV, no planner; steps with a `goal` still use the operator-level `drive` — and write one JSON record per line, so that batch runs are cheap and repeatable. ^extr-igqb
7. As an operator, I want a procedure made only of `script` steps and `nav` steps to make zero model calls, and the extract reply to report model calls and cost (zero in that case), so that I can see a batch run is free. ^extr-ugdh
8. As an operator, I want `extract` without `--out` to return a bounded summary (record count, first five records, pages visited) and with `--out` to stream records to the file as pages complete, so that large sets never pass through the control socket whole. ^extr-d9du
9. As an agent, I want extraction procedures to be ordinary procedures to the run loop, their data returned in the run result under `data`, so that a mission like "collect all prices of X on Allegro" can choose them. ^extr-gkj9
10. As a playbook author, I want `leash playbook test <playbook>/<script> --tab T [--arg k=v]` to run one script on the current page and print its validated output or the validation error, so that authoring a script is a fast loop. ^extr-mp5z
11. As an operator, I want scripts to be shown by `playbook show`, checked by `playbook check` (syntax via a dry `new Function` in a blank page, and `returns` well-formed), and never loaded from anywhere but playbook files, so that nothing runs that I have not seen. ^extr-lslp
12. As an operator, I want `discover` with a learning goal about extracting data to let the planner look at the tab's `net` ring and bounded element HTML, propose a script (DOM-based or fetch-based) with its `returns`, run it through `playbook test` semantics, revise on validation failure, and write it only as a proposal merged by `playbook accept`, so that the system learns a site's extraction the way I would reverse-engineer it. ^extr-wua5
13. As an operator, I want the extract trace to record per page: the URL, the script, record count, validation errors and elapsed time, so that a batch that went wrong on page 37 says so. ^extr-p152
14. As a maintainer, I want the model-output rule restated and tested: no code path passes model text to `Runtime.evaluate` or `callFunctionOn`; only scripts from loaded playbook files run, so that the safety default holds with scripts in the system. ^extr-k40c
15. As a maintainer, I want the shipped example playbook for books.toscrape.com (a site made for scraping practice) with a list script, a next-page procedure and a `repeat`, plus a fetch-based script against a local JSON endpoint in tests, so that both kinds of script have a worked example. ^extr-tkco
16. As an agent, I want the `leash` skill to explain when to use `extract` (repeatable data collection) versus `run` (a task needing judgment) versus `eval` (a one-off look), so that I pick the cheap tool first. ^extr-sk3b

## Implementation Decisions

- Scripts are part of the playbook JSON; `source` is a string. Run via `Runtime.callFunctionOn` on the document's global object with `returnByValue` and `awaitPromise`, arguments passed as JSON.
- Shape declaration is a small JSON type language decoded into an OCaml variant; validation is a pure function with table tests.
- `repeat` is interpreted by the runner, bounded by `max` and the run deadline; `until` uses the existing expectation checkers.
- `extract` is a new command in the protocol and CLI; it holds the tab slot for its duration and is cancelled by client disconnect like `drive`.
- Depends on hardening-2's `net` for story 12.

## Testing Decisions

- Pure: shape validation, playbook loading of scripts, repeat termination. Protocol seam: fake browser scripting `callFunctionOn` results per page, including invalid output, oversize output, a failing next page and de-duplication. Live: books.toscrape.com all pages of one category to JSONL with zero model calls; a discovery run proposing a script on a harmless listing.

## Out of Scope

Scripts that write to the page beyond what extraction needs (they can, since `fetch` can POST; the playbook author is responsible, and `discover` never proposes non-GET fetches); scheduling; storing extracted data anywhere but files; scripts in iframes.

## Further Notes

Design from the session of 2026-09-28: the operator's batch-automation use case, scripts as approved playbook data, internal APIs via in-page fetch, and deterministic extraction with zero model calls.
