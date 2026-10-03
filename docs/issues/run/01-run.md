---
status: completed
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
2. As a playbook author, I want a playbook to declare `site` (a hostname pattern), `entry` (the URL to navigate to when switching to this site), `description`, `pages` (named page kinds, each with a description and a URL pattern or a text marker), and `procedures`, so that everything a run needs about a site is in one file. ^run-r1e9 (Retired 2026-10-03 by map-fm01: page description is removed.) ^run-r1e9
3. As a playbook author, I want a procedure to have a `slug`, a `description` in human language, optional `args` (names substituted into steps as `{name}`), `steps`, and a mandatory non-empty `expect` list, so that JEV can choose it by description and the runner can verify it. ^run-2lei
4. As a playbook author, I want a step to be either `goal: "<drive goal>"` (with optional `hint`, a selector or label that shapes the goal text and `snap --match`, never a target) or `use: <slug>` (with `args` and `optional: true`), so that procedures compose by calling each other and never branch in the file. ^run-84ds
5. As a playbook author, I want each expectation written as one sentence of human language, so that the file reads as prose. ^run-zmz8
6. As an operator, I want a playbook with a procedure lacking `expect`, a `use` of an unknown slug, a cycle of `use`, an unknown page kind, or more than 200 procedures refused at load with the file, procedure and reason, so that broken playbooks never run. ^run-dbji
7. As an operator, I want `leash playbook list`, `leash playbook show <name>` and `leash playbook check <file>`, so that I can see and validate what a run will use. ^run-fk99
8. As an operator, I want hints, page patterns and entry URLs to be data that shapes observation and navigation, never a target JEV or Luna output can name, so that the safety rule "model output never becomes a selector" holds. ^run-xfxx

### Expectations and verification

9. As a runner, I want each expectation resolved to a checker at load time by matching its sentence against the playbook's page kinds and a small vocabulary — "the page is <kind>", "the page shows <text>", "a file was downloaded" (optionally "a PDF"), "no dialog is open", "a <role> named <text> is present" — so that most expectations are verified by code. ^run-tny5
10. As a runner, I want an expectation that matches no deterministic checker verified by a JEV score question ("how well does the current page satisfy: <sentence>?") over the page summary, with a configurable pass threshold, so that judgment is used only where code cannot decide. ^run-vbys
11. As a runner, I want expectations checked with a bounded wait (default 5 s, the procedure may set `expect_timeout_s`) so that a page still settling does not fail a correct procedure. ^run-l06s (Retired 2026-10-03 by map-fm01: the per-procedure field is gone; the wait is one 5 s constant.) ^run-l06s
12. As a service author, I want Leash to observe downloads through `Browser.setDownloadBehavior` (allow, into `$XDG_DOWNLOAD_DIR/leash/` or the configured path, events on) and `Browser.downloadWillBegin`/`downloadProgress`, keeping a per-tab download inventory (id, suggested name, mime, state, path), so that "a file was downloaded" is a fact, and `leash downloads <tab>` lists it. ^run-ykq4
13. As a runner, I want a procedure whose expectations fail to be retried once from its first step, and on a second failure to be reported as a failed procedure to the loop, so that one flaky page does not end a run and a broken procedure does not loop. ^run-k8bx

### The run loop

14. As an agent, I want `leash run "<mission>" [--tab T] [--max-procedures N] [--deadline S] [--dry-run]` to open or reuse a tab, run the loop, and return status `done | blocked | failed | handoff | limit | deadline | error`, the procedure trace, the planner turns, and the final snapshot, so that one call does a whole task. ^run-9ypy
15. As a runner, I want the playbook level asked only at the start and after a procedure whose description or the mission says the next part is elsewhere (or when the current playbook's procedures are all judged unfit), choosing among the installed playbooks by `site` and `description` plus "none", so that cross-site missions switch sites deliberately and single-site missions never re-ask. ^run-kli0
16. As a runner, I want switching playbooks to navigate the same tab to the new playbook's `entry` URL, so that logins in the shared profile carry across sites. ^run-xh5d
17. As a runner, I want the procedure level asked every turn as a JEV choice whose criteria are the current playbook's procedures (slug and description) plus `DONE` ("the mission is visibly complete") and `BLOCKED` ("no offered procedure can progress"), so that the next step is chosen after seeing where the last one landed. ^run-qq3o
18. As a runner, I want the state sent to the upper levels to be small and semantic — the mission, the current site and page kind (from `pages`), the page title and URL, the last five procedures with their outcomes, and the arguments already known — and never the page text, so that JEV decides on what matters and the request stays cheap. ^run-pvmc
19. As a runner, I want procedure arguments filled from the mission by the existing text helper (`{query}` → "Logitech MX Master 3S"), with the value reused for the run once known, so that the mission's facts reach the steps without a second model. ^run-5rll
20. As a runner, I want each step executed as one `drive` call with its own step cap and deadline (procedure defaults, overridable), holding the tab slot for the whole run, so that the operator level is exactly the tested loop. (Retired 2026-10-03 by map-fm01: procedure max_steps and deadline_s are removed; the operator keeps its own cap and deadline.) ^run-d82w
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

### Discovery — superseded

The discovery spec and its command stories are superseded by [The map draws itself](../map-draws-itself/01-map-draws-itself.md), L53 (`map-gkww`). Exploration now uses `drive`; `discover` is no longer a command.

- **Retired by L53 (`map-gkww`).** As an operator, I want `leash discover <site> "<what to learn>"` to open the site and run the loop with the planner in the lead — proposing a procedure, running it through the operator level, verifying its expectations, revising on failure — until the learning goal is met or a turn cap is reached, writing the result as a proposed playbook, so that a site's know-how is produced by the system, not typed by me. ^run-3vat
- **Retired by L53 (`map-gkww`).** As an operator, I want discovery to stop and hand off at anything that looks like payment, account deletion, or sending a message, unless the learning goal names it, so that learning never spends money or speaks for me. ^run-tt9z
- **Retired by L53 (`map-gkww`).** As an operator, I want a discovery run's cost and turns reported and capped (default 20 planner turns), so that it is bounded like everything else. ^run-xda7

### Architecture and tests

37. As a kernel-minded maintainer, I want the run loop written as a computation performing `Select_playbook`, `Select_procedure`, `Fill_args`, `Execute_step`, `Verify` and `Plan` through a local handler token (ox ADR-0006), with production, scripted-test, dry-run and discovery handlers, so that swapping a model or a level is a handler, not a rewrite. ^run-vj48
38. As a test author, I want the whole loop testable offline with scripted handlers and the fake browser, and each level testable in isolation with recorded JEV answers, so that the loop's logic is proven without models. ^run-4mzm
39. As a maintainer, I want the playbook loader, checker resolution and the page-kind matcher to be pure functions with table tests, so that authoring mistakes are caught by tests before a run. ^run-i89r
40. As a maintainer, I want the state sent to each JEV level measured before the shape is pinned — three state sizes on real playbook page states (title+URL; plus page kind and recent procedures; plus page text), recording which chooses correctly and the transfer limit if Allegro is unavailable — so that story 18's shape is evidence, not belief. ^run-snk4
41. As an operator, I want `run` to reuse `drive`, `wait`, `snap`, `nav`, `handoff` internally through the same service paths the CLI uses, so that nothing in `run` bypasses ownership, budgets or safety defaults. ^run-shgh
42. As an agent, I want the same JEV model and endpoint used for all three levels (configured once), so that there is one model to reason about; if measurement shows the upper levels need the planner instead, that is a handler swap recorded in the spec. ^run-7blx
- **Retired by L53 (`map-gkww`).** As an operator, I want `leash run` and `leash discover` in the `leash` skill with the minimize-output guidance, so that agents use missions where they used to script steps. ^run-tpnf
44. As an operator, I want an example playbook shipped for `allegro.pl` (find product, open offer, add to cart, dismiss upsell, go to cart) and one for a second site used in live acceptance, so that a first run works and the format has a worked example. ^run-seqo

## Implementation Decisions

- **Format.** JSON only, in `<site>.json` files (milestone 9 replaced the file with a directory, `<name>/playbook.json`, so scripts can sit beside it: `extract/01-extract.md`, story `extr-plaz`). Types with `[@@deriving yojson]`; smart-constructor modules for slugs, page kinds and expectation sentences. A `.yaml` file is refused explicitly with a message naming JSON.
- **Checker resolution** is a small grammar over the expectation sentence, tried in order: page kind (`pages` names), "shows"/"contains" text, "downloaded" (+ optional mime word), "no dialog", "<role> named <text>". Anything else → JEV score. Resolution happens at load; the playbook's `check` output shows which checker each sentence got, so an author sees when they fell through to judgment.
- **Page kinds** are the semantic summary's key. A kind matches by URL pattern or by a text marker; the runner labels the current page with the first matching kind or `unknown`. Page text is never sent to the upper levels (story 18); the operator level keeps jev-ultrafast's contract untouched.
- **Questions to JEV** at the upper levels use the same System One client and the same instruction style as the operator level; instruction texts are versioned in `questions.ml` next to jev's, with the 255-option ceiling asserted in code.
- **Planner** through `Ox_ai_chat` with `json_object`, reasoning effort configurable (default `high` for Luna), output decoded into the playbook's procedure type fail-closed; a decode failure counts as a turn and is retried once with the error shown.
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
- **L30 status: measured, 2026-09-28 (story 40).** Allegro home/listing returned HTTP 403 with DataDome; no evasion attempted. The first alternate with the complete workflow, automationexercise.com, supplied five verified headless Leash states (home, submitted search results, offer, successful Added! modal, Blue Top in cart). One real System One call per state per shape, 15 final calls: A title/URL **2/5** correct, 2,767 input/452 output tokens, $0.000116214; B plus page kind/recent procedures **4/5**, 3,065/450, $0.000128730; C plus page text **2/5**, 5,629/451, $0.000236418. Final calls total $0.000481362 provider-reported cost. Per-call choices, probabilities, labels and costs are in .scratch/research/state-measurement/README.md and results.pretty.json. A discarded exploratory pass with a mislabeled login blocker is excluded from these costs. Select B for story 18; no page text at upper levels. Known arguments were not varied or supplied in this probe, and five states from one substitute shop do not establish Allegro behavior or general robustness. At this stage the L34 Allegro path still awaited live headless acceptance; its later Chrome 403 is recorded below, with no evasion and the user-authorized substitute shop accepted instead.
- **L31 safety condition exposed by L30:** B answered DONE on the successful Added! modal, where the correct next procedure is go-to-cart. Existing story 22 allows last-procedure expectations alone to justify DONE, but an add confirmation does not prove item-in-cart. DONE for a cart mission must be gated by mission-level item-in-cart expectations or an equivalent deterministic cart/item check. The modal text-marker page kind must take priority over the offer URL matcher. A planner remains a fallback if further measurement shows upper levels need it.
- **L31 status: delivered, 2026-09-28.** The loop is `Run.loop` (`packages/leash/run.ml`),
  an effect computation over a local handler token: `Select_playbook`, `Select_procedure`,
  `Fill_args`, `Execute_step`, `Verify` and `Plan` are performed through it — story 37
  (`run-vj48`), whose test asserts every one of the six went through the handler — with
  `Observe`, `Navigate` and `Hand_off` as the loop's own perception, its playbook switch
  and a planner's ending. Production builds the handler in `Tabs.run` (the tab's action
  lock held for the whole run, each step one `drive_locked` call — story 41, `run-shgh`),
  `Models.levels` serves the two choice levels and the judgment score through one client
  (story 42, `run-7blx`), and `Control` and `leash run` carry it. A scripted handler
  covers the loop at its own seam (`test/run_test.ml`, thirteen cases) and the fake browser
  covers it at the control seam (`test/control_test.ml`: `run_mission`, `run_refusals`).
- **The state is L30's shape B (story 18, `run-pvmc`)**: the mission, the site, the page
  kind, the title and URL, the last five procedures with their outcomes and the known
  arguments — never page text. The test asserts the keys and the absence.
- **The DONE guard (L30's finding, story 22 `run-4j1v`)**: DONE is accepted only after a
  fresh verification of the mission's own expectations, or of the last verified procedure's
  when the mission carries none; a refused DONE goes to the planner and ends `blocked`
  naming the expectation. L30's Added! modal is the case in both test files: the playbook's
  `post-add` text marker wins over the offer URL matcher, the modal's own expectations
  pass, and the mission's "the page is cart" fails.
- **Mission expectations travel in the run's arguments** (`expect` on the wire, the CLI's
  repeatable `--expect`) until L32's planner attaches them on its first turn (story 30).
  Without them the guard falls back to the last procedure's expectations, which L30 showed
  is not enough for a cart mission; the carrier is the bridge and L32 may drop it.
- **Format addition**: a procedure may declare `max_steps` (1..30) and `deadline_s`
  (1..600) for its steps (story 20's "procedure defaults, overridable"); absent, the
  operator's own defaults apply and the run's remaining budget always bounds them.
- **Planner**: L31 asks the turn at the three points of story 28 and takes its answer —
  procedure, handoff or fail — but production's handler answers `fail` naming L32, so a
  stopped run ends `blocked` (a BLOCKED answer or an unfillable argument) or `failed` (a
  procedure that failed twice). `Run.plan_answer` is the seam L32 fills.
- **CLI naming**: `leash run "<mission>"` is the mission command, so the Door's start
  subcommand is `serve` from L31 on (Ox_app's new `?service_command`, ox
  napp-d5e4); `packaging/leash-unit.nix`, `docs/install.md` and `scripts/unit-acceptance`
  moved with it, and the milestone-6 spec carries a note under svc-dit8.
- Gates `dune build @install`, `dune test` and `dune build @fmt` are green (18 suites).
  L34's live acceptance (real JEV and Luna, Allegro's DataDome 403 included) remains the
  milestone's own row.
- **L32 status: delivered, 2026-09-28.** The planner is `Planner` (`packages/leash/planner.ml`):
  one `Ox_ai_chat.complete` call to the configured planner route with `json_object` on and
  reasoning at `planner_reasoning` (default `high`, `none` disables), whose system message is
  the new `Questions.planner` and whose user message is the plan request as JSON — the
  mission, the current playbook in its own schema, the trace, the arguments known and the
  observed page, its text bounded at 6000 bytes. The reply is a derived type
  (`[@json.name]` for the three answers, strict about members it does not name) decoded
  fail-closed against `Playbook.check_procedure` and, for attached expectations,
  `Playbook.resolve`; a refusal is shown back once with `Questions.planner_retry` and a
  second refusal ends the turn `model-unavailable`/`invalid-response`. `Run` asks it only
  at the three triggers and only while `Run.args.max_plans` (3, `Run.of_args`) allows; the
  turn's tokens ride in `planner_turns[].usage` and are logged at info (run-w7ke run-rq6i
  run-obtt); the correction call is bounded by the planner's own 30 s, so a hung retry
  cannot outlast the listener budget (a run's margin is 75 s, docs/protocol.md). A first-turn `"expect"` list becomes the mission's own expectations, which the
  DONE guard verifies when the caller stated none (run-2tt3, the L30 condition closed
  without `--expect`). A planner procedure that ran and passed is written by
  `Playbook.propose` to `$XDG_STATE_HOME/leash/proposed/<site>-<slug>.json`, reported in
  `run_result.proposals` (protocol and docs/protocol.md updated) and merged only by the new
  `leash playbook accept <file>` (run-m0r8).
- **L32 story → test, all in `test/planner_test.ml`** (the run loop with scripted levels and
  the production planner over a local fake chat server; no model, no browser, no network):
  triggers run-w7ke; answers and the fail-closed decode with its one retry run-rq6i; prompt
  shape run-rq6i; the attached expectations and the first-turn-only rule run-2tt3; the turn
  cap and the trace's cost run-obtt; the proposal file, `accept` merging and the untouched
  playbook run-m0r8; the default and configurable model, effort and endpoint, and the
  keyless refusal run-d99l. `test/run_test.ml` keeps the L31 loop cases with the new
  `plan_reply` shape. Gates green; the suite count is 19.
- **L32 naming decisions.** Story 32's `$XDG_STATE_HOME/leash/proposed/<site>-<slug>.json`
  is the proposal path (not `proposals/`), and the planner's configuration is the three flat
  `[models]` keys `planner_model`, `planner_reasoning` and `planner_endpoint` beside
  `jev_model` and `text_model` — story 33's "its reasoning effort and its endpoint
  configurable" as the section's own shape. A planner turn's `usage.cost` now carries Ox's provider-reported chat cost
  (nchat-qu3j); absent provider cost contributes zero.
- **L34 live acceptance, 2026-09-28 (completed).** The isolated
  `scripts/live-acceptance-m7` gate starts real `--headless=new` Chrome with a fresh
  profile and XDG directories; OpenRouter credentials enter only through
  `secret-env ai --`. It terminates the actual Leash service with SIGTERM (exit 0),
  checks Chrome is gone, and inspects CLI/service logs for credential leaks.
  `scripts/live-acceptance-m7.py` permits independent `LEASH_M7_PHASE=shop|cross|discover`
  reruns, with bounded model and wall-clock budgets. No payment was attempted.
  - Allegro headless home answered **403 in Chrome Navigation Timing**, corroborated
    by curl **403**; a preceding exploratory run timed out in the model after four
    JEV and one text-helper calls (~$0.0001256). No evasion; the headed-operator
    instructions are in `scripts/live-acceptance-m6-headed`. For the confirmed 403
    navigation, JEV=0, planner=0, steps=0, cost=$0.
  - Cross-site mission: public Mozilla PDF.js `tracemonkey.pdf` on github.com, then
    example.com in the same tab. **Done** in 5.7 s, 7 JEV calls (7,792 input/632
    output tokens), 0 planner turns/calls, 2 operator steps, System One
    $0.000327264, chat $0. `github.com/download-pdf` verified a completed
    download (one GUID after deduplication; operator step cap 1), then
    `example.com/verify-example` verified the Example Domain page; both were
    first-attempt procedures, and the final URL was `https://example.com/`. The
    earlier uncapped pass returned ten inventory entries and cost $0.000976080
    (11 JEV, 6 steps, 7.2 s); the single-step pass exposed duplicate Chrome
    begin events for one GUID (two entries, $0.000327264). Story `run-ykq4` now
    deduplicates them, with a scripted CDP regression.
  - Discovery mission on example.com: identify the Example Domain heading without
    external navigation. **Done** in 15.3 s, 5 JEV calls (2,892 input/198
    output tokens), 2 planner turns/calls (2,041 chat tokens), 1 operator step,
    System One $0.000121464, chat $0.000623300, total $0.000744764. Trace:
    proposed `identify-example-domain-heading` passed its heading judgment on
    the first attempt, then the gate explicitly accepted `example.com.json`
    into the isolated XDG config; no automatic acceptance.
  - Shop fallback automationexercise.com is still being exercised; initial real
    HTTP 200 home displayed Products. The first run failed after 79.8 s, 10 JEV
    calls, 3 planner turns/calls, System One $0.001439550 + chat $0.001654530
    = $0.003094080, while retrying `open-offer` on home and reaching the planner
    cap; its reported zero steps was a **trace omission**, not proof no actions
    ran. Stories `run-xqh8` and `run-k8bx` now record both attempts and their
    failed expectation, with red/green regression tests. A later run stopped on
    a strict text-helper `invalid-response` after 2 JEV and 1 helper calls
    ($0.000152458); no typing occurred. Repeated shop attempts with the corrected
    `/products` entry reached the named search button but failed clicks: a 99.6 s
    attempt logged 10 JEV, 2 planner turns, 3 text-helper calls, $0.002625922
    and stopped before an offer. The direct zero-model Chrome probe proved the
    button center hits Font Awesome's `::before` pseudo-element inside the button,
    while the click safety check treated it as an unrelated overlay. Story `tab-bw4j`
    now walks `pseudoElements` as well as `children` in `DOM.describeNode`; the
    action-level fake Chrome regression both dispatches the pseudo-icon click and
    refuses a genuine overlay. A real direct click now navigates to
    `/products?search=Blue%20Top` without bypassing trusted CDP mouse input. One
    subsequent shop run stopped after 4.5 s on another strict text-helper
    `invalid-response` (3 JEV, 0 planner, 2 helper calls, $0.000387970); no value
    from that malformed answer was typed. The subsequent bounded corrective text-helper
    retry can still return invalid JSON; its strict parser rejects the answer rather than
    acting on it (a 5.5 s run: 3 JEV, 3 helper calls, $0.000555678).
  - Desktop headless Chrome now uses the configured `chrome.window_size` (default
    `1366,900`, observed content viewport 1366×813) instead of the small implicit
    window. A direct trusted `View Product` click exposed a second click defect:
    `DOM.getContentQuads` gave a viewport-space center, but Chrome's
    `DOM.getNodeForLocation` requires document-space coordinates. At pageY=550,
    viewport y≈203 returned CDP -32000 while document y≈753 hit backend 192.
    Story `tab-bw4j` adds the current `Page.getLayoutMetrics` page offset only to
    CDP hit testing, retaining viewport-space `Input.dispatchMouseEvent` and
    strict foreign-overlay refusal; an Alcotest scrolled-page regression turned
    red then green, and a direct real `View Product` click succeeded. JEV
    sometimes selected `Add to cart` or the search icon despite the explicit
    `View Product` hint; record this as model behavior, not a click-safety bypass.
  - The first full fallback run after the hit fix reached `/view_cart` and visibly
    showed Blue Top but timed out after 80.3 s (34 JEV calls, 0 planner calls,
    4 helper calls, $0.004457884) because page-kind first-match returned
    `post-add`: its lingering `Added!` marker preceded the exact cart URL.
    Story `run-xqh8` tests this priority red/green. Consent remains first;
    exact `/view_cart` now precedes `post-add`, with no broad cart text marker.
  - **Shop accepted on automationexercise.com.** The isolated real JEV mission
    finished in **38.6 s**, 27 JEV calls (85,177 input/5,600 output tokens),
    0 planner turns/calls, 18 operator steps, and 8,246 helper chat tokens:
    System One $0.003577434 + chat $0.000358330 = **$0.003935764**.
    Trace: `find-product` failed twice on a delayed consent overlay (no
    unsafe click); `dismiss-consent` verified trusted Manage options →
    Confirm choices with toggles left off; resumed `find-product` verified
    search; `open-offer` verified on its second drive after a wrong/covered
    first selection; `add-to-cart` verified the `Added!` success marker
    despite a drive reporting `row-not-actionable` after that mutation;
    `go-to-cart` verified on its first drive. Final URL
    `https://automationexercise.com/view_cart` visibly contained Blue Top;
    page-kind, named product, and `checkout/payment has not started`
    checks passed, then DONE re-verification passed. No account, order,
    checkout or payment was started. SIGTERM exited 0 and Chrome was gone.
    A second shop in the final sequential gate independently verified the same
    seven-procedure trace in 38.3 s, 27 JEV, 0 planner turns, 18 steps,
    System One $0.003573318 + chat $0.000364960 = $0.003938278; the
    initial complete-gate try had first timed out in the shop after 66.9 s,
    17 JEV/0 planner/4 helper calls, $0.002810500.
  - **Full three-mission gate passed** after the bounded rerun: Allegro again
    returned headless Chrome HTTP 403 (JEV=0, planner=0, steps=0, $0; no
    evasion). The cross-site PDF.js `tracemonkey.pdf` GitHub → Example
    Domain switch verified one completed PDF and final URL example.com in
    8.7 s, 7 JEV/0 planner turns/2 steps, System One $0.000484806,
    chat $0. The discovery run proposed a heading procedure, verified it,
    then explicitly accepted `example.com.json` into temporary XDG config:
    12.0 s, 5 JEV/2 planner turns/1 step, System One $0.000121296 +
    chat $0.000459200 = $0.000580496. All 34 CLI outputs and 15,506
    service-log bytes were checked for key leakage; SIGTERM exited 0
    and Chrome disappeared. No account, checkout, payment, message or
    order was attempted.
  - After the successful complete live gate and final formatting, `timeout 900
    nix develop -c env DUNE_BUILD_DIR=_build_l34 dune test`, `dune build
    @install`, and `dune build @fmt` all passed on the final source.
- L29 format decision: `nix develop -c ocamlfind list | grep -i yaml` found no YAML library on the OxCaml 5.4 switch. opam metadata for `yaml` 3.2.0 lists `ctypes` and `bos` (also `dune-configurator`) as dependencies requiring an install into the shared switch, which this job must not disturb. JSON-only `<site>.json` is the shipped format; `.yaml` is refused with an actionable JSON message.
