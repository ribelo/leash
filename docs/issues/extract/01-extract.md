---
status: ready-for-agent
milestone: 9
---

# Collect: prepared scripts in playbooks, driven by missions

## Problem Statement

The operator's most valuable browser automation is batch collection — "fetch the prices of all graphics cards of brand X between 1000 and 2000 zł" — which today he does by reverse-engineering a site's internal API. Asking the operator-level JEV to click through and read 500 prices would be slow, expensive, would send every price through a model, and would give a slightly different answer each run. Asking a coding agent to inject `eval` each time costs the agent's tokens and needs the agent in the loop. Wanted: one sentence to `leash drive`, JEV deciding the flow, and prepared code doing the collection the same way every time.

## Solution

`leash drive "<mission>"` is the single entry point: when an installed playbook fits, the playbook loop (milestone 7) runs; when none does, the single-goal operator loop runs as today. Playbooks are directories with prepared JavaScript files next to them; a procedure step may run a script whose output is validated against a declared shape and collected as data, and a procedure may `repeat` over pages. JEV chooses playbooks and procedures on a small semantic state and never sees the collected records; the text helper fills arguments (brand, price range) from the mission; records come back in the reply and stream to a JSONL file with `--out`. Scripts are files the operator or the coordinator wrote, never model output.

## How this differs from `eval`

`eval` is a one-off look, written and read by the calling agent. A playbook script is written once and reused: JEV decides when to run it and with which arguments, the output is checked against its shape, the runner handles pages, de-duplication, rate delay and the file, and the records never pass through any model.

## User Stories

1. As an agent, I want `leash drive "<mission>" [--tab T] [--out file.jsonl] [--deadline S] [--dry-run]` to be the one command for work: the playbook level chooses an installed playbook or "none", and "none" runs today's single-goal operator loop, so that I do not have to know which mode a task needs. ^extr-andy
2. As a maintainer, I want `run` folded into `drive` with no alias (compatibility before 1.0 is not a constraint), the protocol, CLI, skill and live gates updated, so that there is one entry point. ^extr-mq0e
3. As a playbook author, I want a playbook to be a directory — `$XDG_CONFIG_HOME/leash/playbooks/<name>/playbook.json` plus any files beside it — and a script to be either `{"file": "scripts/list_prices.js"}` (relative to the playbook directory, resolved at load, no `..` escapes) or a short inline `{"source": "..."}`, so that large scripts live in their own files. ^extr-plaz
4. As a playbook author, I want `returns` to declare a record or a list of records with typed fields (`string`, `number`, `boolean`, `url`, optional with `?`, nested lists), so that output is checked against what I meant. ^extr-zdst
5. As a runner, I want a `script: <name>` step (with `args`) to run the script in the tab's page through `Runtime.callFunctionOn` with `awaitPromise`, validate the result against `returns` fail-closed with the path of the first mismatch, and bound it (default 8 MiB, configurable per script), so that bad or huge output never reaches the caller as data. ^extr-8o1h
6. As a playbook author, I want scripts able to call the site's own endpoints with `fetch` (same origin, the page's cookies), so that an internal API is used from inside the logged-in page without extracting tokens. ^extr-vgir
7. As a playbook author, I want a procedure's `repeat: {next: <slug>, max: N, until: "<expectation sentence>", delay_ms: M, key: "<field>"}` to run the procedure body, then the `next` procedure, until `next`'s expectations fail, `until` holds, or `max` is reached, waiting `delay_ms` (default 500) between pages and de-duplicating records by `key`, so that pagination is bounded and polite without branching in the file. ^extr-ve3k
8. As an operator, I want the mission's parameters (brand, price range, category) filled into procedure arguments by the text helper, and passed either to operator-level steps ("set the price filter to {min_price}–{max_price}") or to scripts as `args` (to build a filtered URL or to filter records), so that one sentence carries the whole query. ^extr-mfmf
9. As a runner, I want collected records to bypass every model — the upper JEV levels see only the count and the procedure outcome in their small state — so that the cost of a collection does not grow with the number of items. ^extr-b3u0
10. As an operator, I want the drive reply to carry `data` as a bounded summary (record count, first five records, pages visited, per-script counts) and, with `--out`, every record streamed to the JSONL file as pages complete, so that large sets never pass through the control socket whole. ^extr-p7sj
11. As an operator, I want the drive reply to report model calls and cost next to the record count, so that I can see a 500-item collection cost a handful of JEV calls. ^extr-5x9e
12. As a playbook author (usually the coordinating agent), I want `leash playbook test <playbook>/<script> --tab T [--arg k=v]` to run one script on the current page and print its validated output or the validation error, so that writing a script is a fast loop. ^extr-mp5z
13. As an operator, I want scripts shown by `playbook show`, checked by `playbook check` (file resolves, syntax via a dry `new Function` in a blank page, `returns` well-formed), and never loaded from anywhere but playbook directories, so that nothing runs that has not been seen. ^extr-lslp
14. As an operator, I want the trace to record per page: the URL, the script, record count, validation errors and elapsed time, so that a collection that went wrong on page 37 says so. ^extr-p152
15. As a maintainer, I want the model-output rule restated and tested: no code path passes model text to `Runtime.evaluate` or `callFunctionOn`; only scripts from loaded playbook directories run, so that the safety default holds with scripts in the system. ^extr-k40c
16. As a maintainer, I want a shipped example playbook for books.toscrape.com (a site made for scraping practice) with a category procedure, a list script in its own file, a next-page procedure and a `repeat`, plus a fetch-based script against a local JSON endpoint in tests, so that both kinds of script have a worked example. ^extr-tkco
17. As an agent, I want the `leash` skill to say when to use `drive` with a playbook (anything asked twice), `drive` without one (a one-off task needing judgment), and `eval` (a one-off look), and how to write a playbook script with `playbook test`, so that the cheap tool is picked first and I can write playbooks for the operator. ^extr-oaci
18. As a maintainer, I want a live gate: `leash drive "collect every book title and price in the Mystery category"` on books.toscrape.com returning all of them to JSONL with the model calls counted, and a filtered mission ("books under £20") proving argument filling, so that the design is proven end to end. ^extr-8ubt

## Implementation Decisions

- Scripts are resolved at playbook load; a missing file or an escaping path refuses the playbook. Run via `Runtime.callFunctionOn` on the document's global object with `returnByValue` and `awaitPromise`, arguments passed as JSON.
- Shape declaration is a small JSON type language decoded into an OCaml variant; validation is a pure function with table tests.
- `repeat` is interpreted by the runner, bounded by `max` and the drive deadline; `until` uses the existing expectation checkers.
- Upper-level JEV state gains only `collected: <count>` and the last procedure's outcome; records are held by the runner.
- Depends on hardening-2 (`net`) for authoring scripts that call internal APIs.

## Testing Decisions

- Pure: playbook directory loading and file resolution, shape validation, repeat termination. Protocol seam: fake browser scripting `callFunctionOn` results per page, including invalid output, oversize output, a failing next page and de-duplication; drive with and without a matching playbook. Live: story 18.

## Out of Scope

A separate `extract` command (rejected: collection goes through `drive`); discovery learning scripts (later; the coordinator writes playbooks); scheduling; storing data anywhere but files; scripts in iframes.

## Further Notes

Design from the session of 2026-09-28, revised the same evening after the operator's pushback: collection goes through `drive` and JEV, not a deterministic side command; `run` folds into `drive`; playbooks are directories so scripts are files; discovery of extraction is deferred because the coordinating agent is the playbook author. Retired story IDs from the first version: the `extract` command, its zero-call and summary stories, the inline-only `scripts:` section, the data-in-run story, and discovery-learns-extraction.
