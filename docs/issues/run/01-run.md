---
status: ready-for-agent
milestone: 7
---

# Run: missions over playbooks, three JEV levels, Luna on demand

## Problem Statement

`drive` takes one goal on one tab and drives it with JEV until `done` or `blocked`. That is one step of real work. Buying something, filing an invoice and mailing it, or any task that crosses pages and sites is dozens of such steps whose *order* depends on where the previous one landed, whose *success* must be verified rather than believed, and whose know-how — how this site's search works, where its add-to-cart button is — is worth recording once and reusing. Today the outer agent has to do all of that itself, expensively, and learns nothing between runs.

## Solution

A **mission** is one sentence of human language ("buy a Logitech MX Master 3S on Allegro, pay with the saved card"). **Playbooks** are files, one per site, of named **procedures** written in human language: a description, arguments, steps (each a `drive` goal), and a mandatory list of **expectations** verified after the procedure. `leash run "<mission>"` runs a loop with three levels of judgment, all JEV: which playbook serves the current part of the mission (asked only when the site changes), which procedure next (asked every turn), and the operator level that drives each step (today's `drive`). Expectations are checked by code where code can (page kind, text, download, dialog, row), and by a JEV score question where only judgment can. When JEV cannot progress or an expectation fails twice, a **planner** — an LLM, Luna by default — takes one bounded turn: write a new procedure, hand off to the human, or fail with a reason. Luna-written procedures are proposed to the operator, never silently saved. `leash discover <site> "<what to learn>"` runs the same loop with the planner in the lead and writes a playbook. Everything is a handler on one loop, so production, scripted tests, dry runs and the discovery mode are the same code with different handlers.

This follows TypeSafe's own tier discipline for JEV (learnjev.com, "real-time loops"): deterministic code for safety cut-outs and perception, JEV for tactical judgment, an LLM on demand for mission planning; keep the state small and semantic; never more than 255 options in one choice.

## User Stories

### Playbooks

1. As an operator, I want playbooks stored at `$XDG_CONFIG_HOME/leash/playbooks/<site>.json` and loaded on demand, so that `leash run` needs no playbook argument. ^run-tcuz
2. As a playbook author, I want a playbook to declare `site` (a hostname pattern), `entry` (the URL to navigate to when switching to this site), `description`, `pages` (named page kinds, each with a description and a URL pattern or a text marker), and `procedures`, so that everything a run needs about a site is in one file. ^run-r1e9
3. As a playbook author, I want a procedure to have a `slug`, a `description` in human language, optional `args` (names substituted into steps as `{name}`), `steps`, and a mandatory non-empty `expect` list, so that JEV can choose it by description and the runner can verify it. ^run-2lei
4. As a playbook author, I want a step to be either `goal: "<drive goal>"` (with optional `hint`, a selector or label that shapes the goal text and `snap --match`, never a target) or `use: <slug>` (with `args` and `optional: true`), so that procedures compose by calling each other and never branch in the file. ^run-84ds
5. As a playbook author, I want each expectation written as one sentence of human language, so that the file reads as prose. ^run-zmz8
6. As an operator, I want a playbook with a procedure lacking `expect`, a `use` of an unknown slug, a cycle of `use`, an unknown page kind, or more than 200 procedures refused at load with the file, procedure and reason, so that broken playbooks never run. ^run-dbji
7. As an operator, I want `leash playbook list`, `leash playbook show <name>` and `leash playbook check <file>`, so that I can see and validate what a run will use. ^run-fk99
8. As an operator, I want hints, page patterns and entry URLs to be data that shapes observation and navigation, never a target JEV or Luna output can name, so that the safety rule "model output never becomes a selector" holds. ^run-xfxx

### Expectations and verification

9. As a runner, I want each expectation resolved to a checker at load time by matching its sentence against the playbook's page kinds and a small vocabulary — "the page is <kind>", "the page shows <text>", "a file was downloaded" (optionally "a PDF"), "no dialog is open", "a <role> named <text> is present" — so that most expectations are verified by code. ^run-tny5
10. As a runner, I want an expectation that matches no deterministic checker verified by a JEV score question ("how well does the current page satisfy: <sentence>?") over the page summary, with a configurable pass threshold, so that judgment is used only where code cannot decide. ^run-vbys
11. As a runner, I want expectations checked with a bounded wait (default 5 s, the procedure may set `expect_timeout_s`) so that a page still settling does not fail a correct procedure. ^run-l06s
12. As a service author, I want Leash to observe downloads through `Browser.setDownloadBehavior` (allow, into `$XDG_DOWNLOAD_DIR/leash/` or the configured path, events on) and `Browser.downloadWillBegin`/`downloadProgress`, keeping a per-tab download inventory (id, suggested name, mime, state, path), so that "a file was downloaded" is a fact, and `leash downloads <tab>` lists it. ^run-ykq4
13. As a runner, I want a procedure whose expectations fail to be retried once from its first step, and on a second failure to be reported as a failed procedure to the loop, so that one flaky page does not end a run and a broken procedure does not loop. ^run-k8bx

### The run loop

14. As an agent, I want `leash run "<mission>" [--tab T] [--max-procedures N] [--deadline S] [--dry-run]` to open or reuse a tab, run the loop, and return status `done | blocked | failed | handoff | limit | deadline | error`, the procedure trace, the planner turns, and the final snapshot, so that one call does a whole task. ^run-9ypy
15. As a runner, I want the playbook level asked only at the start and after a procedure whose description or the mission says the next part is elsewhere (or when the current playbook's procedures are all judged unfit), choosing among the installed playbooks by `site` and `description` plus "none", so that cross-site missions switch sites deliberately and single-site missions never re-ask. ^run-kli0
16. As a runner, I want switching playbooks to navigate the same tab to the new playbook's `entry` URL, so that logins in the shared profile carry across sites. ^run-xh5d
17. As a runner, I want the procedure level asked every turn as a JEV choice whose criteria are the current playbook's procedures (slug and description) plus `DONE` ("the mission is visibly complete") and `BLOCKED` ("no offered procedure can progress"), so that the next step is chosen after seeing where the last one landed. ^run-qq3o
18. As a runner, I want the state sent to the upper levels to be small and semantic — the mission, the current site and page kind (from `pages`), the page title and URL, the last five procedures with their outcomes, and the arguments already known — and never the page text, so that JEV decides on what matters and the request stays cheap. ^run-pvmc
19. As a runner, I want procedure arguments filled from the mission by the existing text helper (`{query}` → "Logitech MX Master 3S"), with the value reused for the run once known, so that the mission's facts reach the steps without a second model. ^run-5rll
20. As a runner, I want each step executed as one `drive` call with its own step cap and deadline (procedure defaults, overridable), holding the tab slot for the whole run, so that the operator level is exactly the tested loop. ^run-d82w
21. As a runner, I want a `use` step to run the named procedure inline with its own expectations, and an `optional` one to be skipped without failure when its first step ends `blocked` within two operator steps, so that "dismiss the upsell if present" is expressible. ^run-prrv
22. As a runner, I want `DONE` from the procedure level to be accepted only when the mission's own expectations (if the mission carries any, see 30) or the last procedure's expectations hold, so that `done` is verified, not believed. ^run-4j1v
23. As a runner, I want the run to end `limit` at the procedure cap (default 40) and `deadline` at the run deadline (default 15 minutes), so that a wandering run is bounded. ^run-vspj
24. As an agent, I want `--dry-run` to run the playbook and procedure levels against the models and report the chosen playbook, the chosen first procedure with probabilities and the resolved checkers, without acting, so that I can test a mission before a run. ^run-fp7i
25. As an agent, I want the run's trace to record, per procedure: the choice with probabilities, the steps' `drive` results, each expectation and how it was verified (which checker, or the JEV score), elapsed time and model usage, so that a failed run is auditable and a playbook can be improved from it. ^run-xqh8
26. As an agent, I want a dialog opened mid-run to be reported and the run to end `error` with the dialog, and a handoff requested by the planner to end `handoff` with the tab left `With_human`, so that the agent decides what to do next, as with `drive`. ^run-klp9
27. As a runner, I want a run refused on a tab I do not own, one `With_human`, or one with a dialog open, so that it starts from a state it can act in. ^run-fwl8

### The planner (Luna)

28. As a runner, I want a planner turn taken when the procedure level answers `BLOCKED`, when a procedure fails its expectations twice, or when the text helper cannot fill a required argument, so that judgment above JEV's is used exactly at the points JEV stops. ^run-w7ke
29. As a runner, I want the planner to receive the mission, the current playbook (slugs, descriptions, expectations), the trace so far, the page summary plus bounded page text, and to answer exactly one of `procedure` (a new procedure in the playbook's schema, to run now), `handoff` (with a reason), or `fail` (with a reason), validated fail-closed, so that the planner's output is always something the loop can execute or report. ^run-rq6i
30. As a runner, I want the planner also able to attach mission-level expectations at its first turn when the mission implies them ("the order confirmation page is shown"), so that `DONE` at the end has something to verify against. ^run-2tt3
31. As an operator, I want planner turns bounded per run (default 3) and their cost logged, so that Luna is a fallback, not the driver. ^run-obtt
32. As an operator, I want a planner-written procedure that ran and passed its expectations to be written to `$XDG_STATE_HOME/leash/proposed/<site>-<slug>.json` and reported in the run result, and `leash playbook accept <file>` to merge it into the site's playbook, so that the playbook grows from experience under my eye. ^run-m0r8
33. As an operator, I want the planner model, its reasoning effort and its endpoint configurable (`[models].planner`, default `openai/gpt-6-luna` via OpenRouter), so that the fallback can be tuned or replaced. ^run-d99l

### Discovery

34. As an operator, I want `leash discover <site> "<what to learn>"` to open the site and run the loop with the planner in the lead — proposing a procedure, running it through the operator level, verifying its expectations, revising on failure — until the learning goal is met or a turn cap is reached, writing the result as a proposed playbook, so that a site's know-how is produced by the system, not typed by me. ^run-3vat
35. As an operator, I want discovery to stop and hand off at anything that looks like payment, account deletion, or sending a message, unless the learning goal names it, so that learning never spends money or speaks for me. ^run-tt9z
36. As an operator, I want a discovery run's cost and turns reported and capped (default 20 planner turns), so that it is bounded like everything else. ^run-xda7

### Architecture and tests

37. As a kernel-minded maintainer, I want the run loop written as a computation performing `Select_playbook`, `Select_procedure`, `Fill_args`, `Execute_step`, `Verify` and `Plan` through a local handler token (eta-next ADR-0006), with production, scripted-test, dry-run and discovery handlers, so that swapping a model or a level is a handler, not a rewrite. ^run-vj48
38. As a test author, I want the whole loop testable offline with scripted handlers and the fake browser, and each level testable in isolation with recorded JEV answers, so that the loop's logic is proven without models. ^run-4mzm
39. As a maintainer, I want the playbook loader, checker resolution and the page-kind matcher to be pure functions with table tests, so that authoring mistakes are caught by tests before a run. ^run-i89r
40. As a maintainer, I want the state sent to each JEV level measured before the shape is pinned — three state sizes on the Allegro playbook (title+URL; plus page kind and recent procedures; plus page text), recording which chooses correctly — so that story 18's shape is evidence, not belief. ^run-snk4
41. As an operator, I want `run` to reuse `drive`, `wait`, `snap`, `nav`, `handoff` internally through the same service paths the CLI uses, so that nothing in `run` bypasses ownership, budgets or safety defaults. ^run-shgh
42. As an agent, I want the same JEV model and endpoint used for all three levels (configured once), so that there is one model to reason about; if measurement shows the upper levels need the planner instead, that is a handler swap recorded in the spec. ^run-7blx
43. As an operator, I want `leash run` and `leash discover` in the `leash` skill with the minimize-output guidance, so that agents use missions where they used to script steps. ^run-tpnf
44. As an operator, I want an example playbook shipped for `allegro.pl` (find product, open offer, add to cart, dismiss upsell, go to cart) and one for a second site used in live acceptance, so that a first run works and the format has a worked example. ^run-seqo

## Implementation Decisions

- **Format.** JSON only, in `<site>.json` files. Types with `[@@deriving yojson]`; smart-constructor modules for slugs, page kinds and expectation sentences. A `.yaml` file is refused explicitly with a message naming JSON.
- **Checker resolution** is a small grammar over the expectation sentence, tried in order: page kind (`pages` names), "shows"/"contains" text, "downloaded" (+ optional mime word), "no dialog", "<role> named <text>". Anything else → JEV score. Resolution happens at load; the playbook's `check` output shows which checker each sentence got, so an author sees when they fell through to judgment.
- **Page kinds** are the semantic summary's key. A kind matches by URL pattern or by a text marker; the runner labels the current page with the first matching kind or `unknown`. Page text is never sent to the upper levels (story 18); the operator level keeps jev-ultrafast's contract untouched.
- **Questions to JEV** at the upper levels use the same System One client and the same instruction style as the operator level; instruction texts are versioned in `questions.ml` next to jev's, with the 255-option ceiling asserted in code.
- **Planner** through `Eta_ai_chat` with `json_object`, reasoning effort configurable (default `high` for Luna), output decoded into the playbook's procedure type fail-closed; a decode failure counts as a turn and is retried once with the error shown.
- **Downloads**: one `Browser.setDownloadBehavior` per browser generation; events attributed to tabs by `frameId`; inventory kept for the tab's life; `downloads` command and `DownloadInfo` added to `docs/protocol.md`.
- **Discovery** is the run loop with a handler whose `Select_procedure` asks the planner first and JEV only to choose among what the planner has written so far; its `expect` for a drafted procedure must come from the planner too.
- **Storage**: playbooks under XDG config; proposals under XDG state; a run's trace to XDG state as JSON when `--save-trace` is set.
- Everything in `run` is a client of the existing service paths (story 41); nothing new touches CDP except the download observer.

## Testing Decisions

- Seam: the control protocol (`run`, `discover`, `playbook *`, `downloads`) with the fake browser and scripted model handlers, plus pure tests for the loader, checker resolution and page-kind matching. Recorded JEV answers (from the measurement in story 40) drive the level tests so they are deterministic.
- Stories 1–8, 39: loader and `playbook check` table tests, including every refusal.
- Stories 9–13, 12: checker resolution tables; download inventory through fake `Browser.download*` events; expectation wait with the mock clock; retry-once-then-fail.
- Stories 14–27, 37, 38, 41, 42: the loop with scripted handlers — single site, cross-site switch with `entry` navigation, `use` and `optional`, verified `DONE`, caps and deadline, dry run, dialog and handoff endings, refusals.
- Stories 28–33: planner turns with a fake chat server — each of the three answers, decode failure retry, turn cap, proposal file written and `accept` merging it.
- Stories 34–36: discovery with scripted planner and operator handlers, the payment stop.
- Story 40: the measurement, recorded in this spec's status before L31 pins the state shape.
- Live acceptance (story 44 and the map's last row): Allegro find → offer → add to cart → cart (stop before payment), with real JEV and Luna, headless, key from the environment; one cross-site run (a public site with a downloadable PDF → a second site) proving playbook switching and the download checker; costs recorded.

## Out of Scope

Conditional branching in playbooks; parallel tabs in one run; playbook sharing or versioning beyond files; a GUI for accepting proposals; automatic saving of planner-written procedures; running discovery unattended on sites with payments.

## Further Notes

- Design record: the session of 2026-09-28. Two JEV levels above the operator, Luna on demand, mandatory human-language `expect` verified by code first and JEV score second, page kinds as the semantic state, the 255-option ceiling as the reason playbooks are selected rather than merged, and propose-and-approve for learned procedures.
- Open until measured (story 40): whether one JEV model serves all three levels well with the small state; the fallback is the planner at the upper levels, by handler swap.
- L29 format decision: `nix develop -c ocamlfind list | grep -i yaml` found no YAML library on the OxCaml 5.4 switch. opam metadata for `yaml` 3.2.0 lists `ctypes` and `bos` (also `dune-configurator`) as dependencies requiring an install into the shared switch, which this job must not disturb. JSON-only `<site>.json` is the shipped format; `.yaml` is refused with an actionable JSON message.
