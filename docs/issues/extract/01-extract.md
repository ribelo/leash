---
status: completed
milestone: 9
---

# Collect: prepared scripts in playbooks, driven by missions

## Status — 2026-10-04

Completed for L37–L40. The current playbook loader validates file/inline scripts and return shapes; the runner executes prepared scripts, validates and deduplicates records, handles repeat termination, and sends records to the CLI's JSONL writer. The recorded L40 cause/fix/repeat acceptance closes `extr-uhnc`; it is not an outstanding follow-up. No open stories in this spec. [ADR-0012 / L56](<../pilot/01-pilot.md>) supersedes the JEV-first mission chooser and trace compiler, not prepared scripts or file output. Pilot-only collection without a prepared script is separately open as L57F `pilot-sc9t` (U8).

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
5. As a runner, I want a `script: <name>` step (with `args`) to run the script in the tab's page through `Runtime.callFunctionOn` with `awaitPromise`, validate the result against `returns` fail-closed with the path of the first mismatch, and bound it (default 8 MiB, one global 8 MiB bound), so that bad or huge output never reaches the caller as data. (Retired 2026-10-03 by map-fm01: per-script max_bytes is removed.) ^extr-8o1h
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
19. As the playbook author, I want the books.toscrape.com playbook to collect three categories of different sizes — including one with 8 or more pages — without wording tuned to one model run, and any failure to be diagnosed to its cause (runner, repeat termination, expectation, page kind, or the model's choice) and fixed at that cause, so that playbooks are robust to phrasing rather than tuned to quirks. ^extr-uhnc

## Implementation Decisions

- Scripts are resolved at playbook load; a missing file or an escaping path refuses the playbook. Run via `Runtime.callFunctionOn` on the document's global object with `returnByValue` and `awaitPromise`, arguments passed as JSON.
- Shape declaration is a small JSON type language decoded into an OCaml variant; validation is a pure function with table tests.
- `repeat` is interpreted by the runner, bounded by `max` and the drive deadline; `until` uses an expectation string or a prepared script returning `{done: boolean}`. The terminal predicate runs before the cap. Prepared `navigate` scripts return `{url: URL}` for native navigation; control results are validated and traced, never collected. (Retired 2026-10-03 by map-fm01: navigate steps are refused; a goal covers navigation.)
- Upper-level JEV state gains only `collected: <count>` and the last procedure's outcome; records are held by the runner.
- Depends on hardening-2 (`net`) for authoring scripts that call internal APIs.

## Testing Decisions

- Pure: playbook directory loading and file resolution, shape validation, repeat termination. Protocol seam: fake browser scripting `callFunctionOn` results per page, including invalid output, oversize output, a failing next page and de-duplication; drive with and without a matching playbook. Live: story 18.

## Out of Scope

A separate `extract` command (rejected: collection goes through `drive`); discovery learning scripts (later; the coordinator writes playbooks); scheduling; storing data anywhere but files; scripts in iframes.

## Further Notes

Design from the session of 2026-09-28, revised the same evening after the operator's pushback: collection goes through `drive` and JEV, not a deterministic side command; `run` folds into `drive`; playbooks are directories so scripts are files; discovery of extraction is deferred because the coordinating agent is the playbook author. Retired story IDs from the first version: the `extract` command, its zero-call and summary stories, the inline-only `scripts:` section, the data-in-run story, and discovery-learns-extraction.

## Live acceptance (L39, 2026-09-28)

`scripts/live-acceptance-m9b` (headless Chrome, real JEV `typesafe/jev-1.13-20260917` and text helper `inception/mercury-2.5`, key only through `secret-env ai`, absent from every CLI output and the service log; SIGTERM exit 0, Chrome gone) against books.toscrape.com and the shipped `examples/playbooks/books.toscrape.com/` playbook. The site's Mystery category has 32 books (20 + 12 on two pages), 10 of them under £20, checked independently by fetching the category pages from the gate itself. Three consecutive runs passed with the same shape:

| | records (site) | model calls (text helper / operator / playbook / procedure) | cost | elapsed |
| --- | --- | --- | --- | --- |
| A: "collect every book title and price in the Mystery category" (`--out`) | 32 (32) | 8 (1 / 4 / 1 / 2) | $0.00099 | 6.4 s |
| B: "collect Mystery books cheaper than £20" (price filled by the text helper) | 10 (10) | 9 (2 / 4 / 1 / 2) | $0.00104 | 7.1 s |

Every JSONL record passed the shape (title, price, url, category, rating, availability), matched the site's title, price and url, and was unique; every record of B was under £20. `playbook test` ran in the same gate: `list-page` 20 records, with `max_price`, and the fetch-based `crawl-category` script 32 records in one call.

The live runs exposed three defects, fixed with tests (`test/run_test.ml`, `test/playbook_test.ml`):

- the mission-level JEV, told only `collected: N`, chose the collection again and again and never DONE (55–116 records, `limit`); the state now also carries `pages` and `collection_complete` once anything was collected (extr-b3u0);
- a page read twice streamed its records twice, because the repeat's dedupe table was cleared per repeat and dropped between procedures; the key now de-duplicates for the whole run (extr-ve3k);
- (playbook, not Leash) the operator level does not scroll to a pager outside the viewport-filtered element table and clicked "Add to basket" instead, and a click step whose done-condition was about navigation ended `blocked`; the example's list script leaves the pager in view and the click goal states its done-condition in words the page shows. The skill records both.

## Robustness diagnosis (L40, extr-uhnc)

The L39 workaround above is historical evidence, not authoring guidance. Plain missions must not depend on a click goal mentioning a particular pager string, on instructions telling JEV not to choose an internal helper, or on book titles not containing “next”.

- **Skipped extraction after a blocked click.** Symptom: navigation can occur but the following list script does not run. Evidence: the L39 live note records the blocked navigation; the former non-done operator branch in `Run.steps` returned `Steps_done` and discarded remaining steps, allowing unrelated procedure expectations to pass. Cause: runner control flow, not mission wording. Fix: fail closed when a non-done operator step has unexecuted steps; retain its drive trace and do not replay dispatched actions.
- **Truncated repeat can look finished.** Evidence: the former repeat loop returned `Continue` at its cap before checking termination, while DONE verification checked only generic page expectations. Cause: repeat termination and completion state. Fix: test the real termination predicate first, then fail explicitly at a cap when more pages remain; refuse DONE for a pending collection. A last page exactly at the cap is successful.
- **Next-page helper offered as a mission action.** Evidence: the former procedure criteria enumerated every procedure, including repeat targets; the example description said “do not choose it”. Cause: procedure eligibility, not JEV phrasing. Fix: repeat targets are internal, excluded structurally from mission-level choices.
- **Book title misclassified as a pager.** Evidence: the former `more-pages` kind had `text_marker: "next"`, a substring of the entire page text, not a pager predicate. Cause: example page-kind design. Fix: category recognition uses its URL and pagination checks the actual pager DOM in a prepared script, independently of title text.
- **Offscreen pager and already-satisfied click goal.** Evidence: L39 needed `scrollIntoView`; the next-page goal accepted any “previous” link, which exists already on page 2 of an eight-page listing. Cause: model-chosen navigation and an invalid step completion condition. Fix: prepared deterministic traversal, never another wording variation. Whole-category fetching does not change the tab DOM or history.

- **Verified one-shot collector repeated thirty times.** Live trace `/tmp/leash-l40-primary-site/Travel.json`: `collect-category` verified 30 times, each `crawl-category` returned 11 records; final `limit`, 330 records, 32 calls, $0.000871704, 23.6 s. Cause: the runner unconditionally reset `complete=false` after a verified non-repeat script, so the small state never advertised collection completion. Fix: a successfully verified one-shot script marks its collection complete; a pending repeat still cannot be completed by an unrelated procedure. No mission or procedure wording changed for this fix.

Primary fetch-based acceptance (2026-09-29): independently fetch every page with Python, compare all six fields by URL and exact record count, then verify each JSONL record against the declared shape. Missions are exactly `collect every book in the <X> category`.

| Category | Independent pages | Collected/site | Model calls | Reported USD | Drive seconds |
|---|---:|---:|---:|---:|---:|
| Travel | 1 | 11/11 | 4 | 0.000122212 | 3.7 |
| Fiction | 4 | 65/65 | 4 | 0.000119676 | 3.6 |
| Default | 8 | 152/152 | 5 | 0.000164724 | 5.5 |

All three runs used real JEV and text helper, no planner, from explicit shop tabs. Secret checks passed for CLI output and service logs; SIGTERM exited 0 and the isolated headless Chrome process was gone. The fetch-only collector does not navigate, so `data.pages=0` is expected: that counter tracks runner repeat pages, not internal fetches. Sanitized traces are in `/tmp/leash-l40-primary-complete/`. Native repeat acceptance also passed: Default 152/152 on eight real pages, 4 calls (JEV 3, helper 1), $0.000121484, 5.2 s. The final tab URL was `/catalogue/category/books/default_15/page-8.html`; `list-page` ran eight times, `last-page` eight times, `next-url` seven times, `category-url` once. Every control trace had zero collected records. There was no DOM/history rewriting: the termination script inspects the real pager and the URL scripts feed native navigation. Evidence: `/tmp/leash-l40-repeat/Default.json`. The alternative shipped `examples/playbooks/books.toscrape.com/repeat.json` replaces `playbook.json` in a copied installation to exercise this path; `LEASH_M9C_REPEAT=1` performs that substitution only in the gate’s disposable XDG directory. The primary playbook retains the fetch collector; both examples use ordinary factual prose.

Blank-tab acceptance initially returned `none` and blocked with zero records. The request did not describe that the current page was blank, and the playbook description described a procedure rather than the site. The state now says `current_page: "Blank page; no site is loaded."` only on `about:blank`; the `none` criterion means "Continue on the current page without a playbook." The site description states its catalogue holdings. Full playbook choice distributions are retained even for `none`. Before confidence escalation, three real blank-tab missions passed: Travel 11/11 (4 calls, $0.000117148, 4.5 s), Fiction 65/65 (4, $0.000115892, 3.8 s), Default 152/152 (4, $0.000119050, 4.1 s). Evidence: `/tmp/leash-l40-blank/`. These successes alone are not robustness evidence: repeated isolated selection still showed about 0.5 probability despite factual descriptions.

**Decision:** ambiguous playbook selection escalates the same finite option set to the planner instead of adding increasingly forceful wording. The configured choice-confidence threshold defaults to 0.7. Both the JEV distribution and bounded planner answer are traced and billed. Malformed planner output cannot invent a playbook: retain the original JEV argmax with an explicit trace note. This targets measured selection uncertainty, not category-specific wording. The post-escalation Travel acceptance and final all-category reruns are recorded below.

Remaining limits: the demo site is read-only and static; these measurements do not establish behaviour under authentication, rate limits, infinite scroll, or a changing catalogue. Provider/model selection remains probabilistic. A fetch collector reports internal site pages separately from runner repeat pages. The independent oracle is another DOM parser and intentionally shares neither extractor code nor model decisions, but both rely on the site representing each book consistently.

## Choice-confidence escalation decision (L40, extr-uhnc run-kli0)

The description was already on the JEV wire; missing metadata was not the defect. Replays with factual blank-page state and the clarified none action still gave P(book) = .47, .61, .53, .52, .53 with the original capability description, and .50, .50, .56, .51, .51 with the final factual site description. One replay selected none; the near-ties do not justify more forceful model-specific wording.

Decision: at the playbook boundary only, compare the maximum JEV probability with validated `models.choice_confidence` (finite [0,1], default 0.7). Strictly below it, ask the configured planner one choice-only question with unchanged instructions, factual state, option names and descriptions. Require exactly one JSON field `choice` naming an offered option; reject extra fields, duplicate fields, unknown names and malformed output. Do not retry or ask for a procedure. A refused/unavailable review retains JEV's validated argmax and a trace note. The review is bounded by the remaining choice deadline and 30 seconds, and actual calls/provider cost count as planner usage. Both original judgments remain in `playbook_choices`; planner answers do not invent probabilities or confidence.

Headless live acceptance on 2026-09-29: three fresh blank-tab missions, each exactly “collect every book in the Travel category”. JEV P(book)/P(none) was .55/.45, .55/.45, .49/.51. The planner was consulted once in every run and chose books.toscrape.com, correcting the third run's none answer. All three ended done with 11 unique full records exactly matching an independent site oracle. Each used 5 model calls (playbook 1, planner 1, procedure 2, text helper 1); costs were USD .000161958, .000163108 and .000167508, with no unreported cost. Durations were 7.4s, 15.9s and 5.7s. This demonstrates the measured fallback, not a statistical reliability guarantee. The isolated headless service exited cleanly and Chrome was gone; keys were absent from captured CLI output and service logs.

Eight scripted HTTP regressions cover review selection, high probability without review, exact configured boundary, malformed/unknown/extra/duplicate answers and config validation, including unchanged question facts and billed review cost. The separate two wire regressions preserve authored descriptions and blank-page facts. Build/install and the full test suite passed with an isolated build directory.

## Final L40 acceptance (2026-09-29)

After integrating choice review, all seven final missions passed, with unchanged exact wording `collect every book in the <X> category`. The gate independently fetched all category pages and compared every field of every unique record, including shape validation. Real models ran only through `secret-env ai -- scripts/live-acceptance-m9c` in owner-bound isolated headless Chrome.

| Start / collector | Category | Site pages | Records / oracle | Calls (JEV/helper/planner) | Cost USD | Seconds |
|---|---|---:|---:|---:|---:|---:|
| Shop / fetch | Travel | 1 | 11/11 | 4 (3/1/0) | 0.000119724 | 4.0 |
| Shop / fetch | Fiction | 4 | 65/65 | 4 (3/1/0) | 0.000119518 | 3.7 |
| Shop / fetch | Default | 8 | 152/152 | 4 (3/1/0) | 0.000116816 | 4.7 |
| Blank / fetch | Travel | 1 | 11/11 | 5 (3/1/1) | 0.000160016 | 10.0 |
| Blank / fetch | Fiction | 4 | 65/65 | 5 (3/1/1) | 0.000163052 | 6.6 |
| Blank / fetch | Default | 8 | 152/152 | 5 (3/1/1) | 0.000165840 | 10.4 |
| Shop / native repeat | Default | 8 | 152/152 | 4 (3/1/0) | 0.000121034 | 5.1 |

Blank Travel is direct correction evidence: JEV chose none with P(none)=.54 versus P(book)=.46; one planner review selected the bookshop. Blank Fiction and Default had P(book)=.59 and .62 and also received exactly one review. Shop-start choices were P(book)=.97 and did not call the planner. All costs were reported.

The native-repeat run performed eight `list-page` calls producing 152 records, eight `last-page` checks, seven `next-url` calls and one `category-url` call. Every control output counted zero records. The final URL was `https://books.toscrape.com/catalogue/category/books/default_15/page-8.html`, where the real pager was absent. No DOM/history rewrite or synthetic completion marker was used. The six fetch runs each invoked `crawl-category` once and correctly reported zero runner-repeat pages.

Sanitized raw traces: `/tmp/leash-l40-final-primary/{Travel,Fiction,Default}.json`, `/tmp/leash-l40-final-blank/{Travel,Fiction,Default}.json`, `/tmp/leash-l40-final-repeat/Default.json`. CLI/log secret checks covered respectively 16/16/8 captured outputs and 4992/5872/2038 service-log bytes. Each service exited 0 on SIGTERM and its isolated Chrome was gone. No API key was printed or persisted in evidence.

Final foreground gates all passed with `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l40`: `dune build @install`, `dune test`, `dune build @fmt`. The formatting gate initially reported layout differences in four changed files; `dune promote` applied only those formatter outputs and the gate then passed. Regression coverage includes native navigation, exact-cap terminal success, rejected/unsafe control results, nonempty and empty one-shot completion, interrupted steps, unfinished-repeat DONE guard, nonterminal cap failure, helper exclusion, typed control codecs, shipped examples, and bounded choice review. The isolated build directory was removed after verification. L40 is delivered in the current tree; this historical gate record does not denote unfinished work.
