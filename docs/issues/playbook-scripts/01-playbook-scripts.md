---
status: ready-for-agent
milestone: 10
---

# Scripts are JEV's tools; playbooks are procedures, not scripts

## Problem Statement

Reviewed on 2026-09-30, the one installed playbook (`books.toscrape.com`) is a scraper in a playbook's clothes: every procedure is one `fetch`-crawling script, `expect` is a vacuous "no dialog is open", the declared page kinds are never used, and the scripts that would make it a real navigate-collect-paginate procedure (`list-page`, `next-url`, `last-page`) sit beside it unused. It passed L39's gate because a fetch loop always passes; it proved nothing about the three-level design on a real site. The format made this easy: `returns` sits far from its script, args have no declared source (`{category}` is filled by the text helper from the mission, `max_pages` comes from nowhere), and nothing stops a playbook with no JEV-driven step. Separately, JEV has no way to *choose* to run a script: scripts exist only as steps an author pins. That is backwards for what scripts are for — reading a page's cards in bulk, saving a file, parsing HTML — which is exactly what JEV cannot do by clicking and must be able to reach for.

## Solution

A script is a **tool JEV can choose**: at the operator level, the scripts applicable to the current page are offered as options beside click/type/scroll/wait/done/blocked, each with its description; JEV picks one, the runner executes the file, the validated result is collected and a one-line summary (record count, or the returned fields) enters JEV's recent actions. Scripts declare the page kinds they apply to (per-page by default, global if none). Authors can still pin a `script:` step. The format moves `returns` next to the script, declares each arg's source, and the loader refuses a playbook whose procedures have no `goal` step. The books example is rewritten as the real thing and the live gate is re-run on it.

## User Stories

### Scripts as JEV's tools

1. As a playbook author, I want a script to declare `pages: [<kind>...]` (the page kinds it applies to; absent means every page of the site) and a `description` in one sentence, so that the runner knows when to offer it and JEV knows what it does. ^pbk-46fr
2. As a runner, I want the operator-level question, when driving a playbook procedure, to offer JEV every script whose `pages` matches the current page kind as an additional operation `run_script:<name>` with its description, so that JEV can choose a script the way it chooses a click. ^pbk-rai1
3. As a runner, I want a chosen script's args filled the same way a step's are — declared args from the mission via the text helper, already-known values reused — and a script whose required arg cannot be filled reported as `blocked` with the arg named, so that JEV-chosen scripts have the same contract as pinned ones. ^pbk-3cq7
4. As a runner, I want a chosen script's validated result collected exactly as a pinned step's is (records to `data` and `--out`, files to the download inventory), and JEV's recent-actions entry to be a one-line summary (`ran list-page: 20 records` or the returned scalar fields), never the records, so that JEV sees that it ran and what it yielded without the payload. ^pbk-hcwy
5. As a runner, I want a script that throws or fails validation to appear in recent actions as `ran X: failed (<first line>)` and not to end the procedure by itself, so that JEV can choose another action; the procedure's `expect` still decides. ^pbk-9549
6. As a maintainer, I want the JEV request contract's `operation` options extended with `run_script:<name>` entries pinned verbatim in `jev_request.ml` and the spec, with the option count asserted under 255 including scripts, so that the contract is explicit and the ceiling holds. ^pbk-otsl

### The format

7. As a playbook author, I want `returns` declared beside the script — in the script file's leading `/** returns: ... */` block or in `scripts/<name>.returns.json` — and named shapes (`"shapes": {"book": {...}}`, `"returns": "book"`) so that a shape is written once and sits with its script. ^pbk-lvy9
8. As a playbook author, I want each script and procedure arg declared with its source — `{"from": "mission"}` (the text helper fills it from the mission sentence), `{"from": "mission", "optional": true}`, or `{"const": <value>}` — and `playbook check` to fail on any `args.<x>` a script reads that its declaration lacks (a lexical scan of the source for `args.<ident>`), so that where every value comes from is written in the file. ^pbk-lww9
9. As a maintainer, I want the loader to refuse a playbook in which no procedure has a `goal` step (message: "every procedure is a script; use `leash eval` or `playbook test`, or add the goal steps JEV drives"), with script-only procedures allowed only as `use:` sub-procedures, so that a scraper cannot be installed as a playbook. ^pbk-85m1
10. As a maintainer, I want `playbook check` to refuse a playbook directory holding more than one book file or stray JSON beside `playbook.json`, so that `repeat.json` next to `playbook.json` cannot happen again. ^pbk-8n2l

### The honest example and the gate

11. As a maintainer, I want the books.toscrape.com example rewritten as the real thing: procedures `open-category` (goal, expect page is `category`), `collect-page` (script `list-page`, pages `[category]`), `next-page` (goal, expect page is `category`), with `repeat` and `until` from `last-page`; the `crawl-category` fetch script deleted; scripts carrying `pages` and `description`, so that the example teaches the design instead of bypassing it. ^pbk-abr3
12. As a maintainer, I want L39's live gate re-run on the rewritten example (three categories, one of 8+ pages, plus a mission that names no procedure and relies on JEV choosing `run_script:list-page`), with JEV call counts, cost and the procedure trace recorded in this spec, so that the claim 'JEV can drive a playbook and choose scripts' has evidence. ^pbk-eyya
13. As a maintainer, I want the missions reference updated for `run_script`, `pages`, arg sources and the loader rules, so that the skill matches the format. ^pbk-wbhf
14. As a maintainer, I want the previous format's fields (`returns` at playbook top level, undeclared args, script-only procedures) rejected with a message naming the new form, not silently accepted, so that no shim lives on (compatibility before 1.0). ^pbk-i0zl

## Implementation Decisions

- `run_script:<name>` is an operator-level option only inside a playbook procedure (on-the-fly missions have no scripts). The offered set is computed per observation from the current page kind.
- Scripts read `args` as today; declaration is checked lexically at `playbook check` (`args\.([a-zA-Z_][a-zA-Z0-9_]*)`) and at load.
- Named shapes live in `shapes`; a script's `returns` is a shape name or an inline shape. Validation code unchanged.
- The summary line for recent actions is built by the runner from the validated result: list → `N records`; record → its scalar fields, bounded to 120 chars.

## Testing Decisions

- Loader and check: table tests for every refusal (no goal step, undeclared arg, stray JSON, old format). Runner: scripted JEV choosing `run_script`, arg filling, result summary, failure summary. Live: story 12.

## Out of Scope

Scripts writing to the page beyond collection; JEV choosing scripts on-the-fly without a playbook; per-procedure script scoping (page kind is the scope).

## Further Notes

Decided 2026-09-30 after the operator's review: scripts are JEV's tools (an option in the choice, the file executed by the runner), scoped per page kind by default; both JEV-chosen and author-pinned scripts remain. The fetch-crawl example was the agent optimising for a gate that measured the wrong thing; the rewritten gate measures JEV driving.
