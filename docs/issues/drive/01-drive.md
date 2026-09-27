---
status: completed
milestone: 5
---

# Drive a tab toward a goal with JEV

## Problem Statement

Each click through a large language model costs seconds and dollars; a page with twenty steps costs a minute of an expensive agent's attention doing things a small decision model does in milliseconds. The outer agent should plan and verify, not click.

## Solution

`leash drive <tab> <goal>` runs the jev-ultrafast loop on the tab: snapshot, one System One request that answers the operation and speculative target questions, act on the matching target, settle, repeat, until `done`, `blocked`, the step cap, the deadline, or an error. Typed text comes from a small text helper. The reply is the full trace and a final snapshot; the outer agent verifies.

## User Stories

1. As an agent, I want `leash drive <tab> <goal>` to run the loop and return `done`, `blocked`, `step-cap`, `deadline`, or `error` with a trace, so that I can verify and decide what next. ^drive-y7v8
2. As an agent, I want each trace step to record the snapshot id, operation with its probabilities, the target row with its probabilities, any typed text, the page url and title after, and elapsed time, so that I and the human can audit why a step happened. ^drive-xjh6
3. As an agent, I want the final snapshot in the reply, so that verification needs no extra call. ^drive-4zlp
4. As an agent, I want `--max-steps` (default 30) and `--deadline` (default 120 s), so that a stuck page costs a bounded amount. ^drive-ix5t
5. As an operator, I want JEV to see only the current table, the goal, the url and title, and a bounded window of recent steps, so that the request stays small and fast. ^drive-y37b
6. As an operator, I want the operation and target questions asked in one System One request with the target heads containing only compatible rows, so that a decision is one round trip. ^drive-zml5
7. As an operator, I want the text for a `type_text` step written by the configured OpenRouter text helper, given the goal, the row, and the recent trace, and accepted only if it parses as a small JSON object with a `text` string, so that a model cannot type something unparseable or huge. ^drive-ls3c
8. As an agent, I want values I put in the goal (a username, a search phrase) used verbatim by the text helper when they fit the row, so that I can supply what I know. ^drive-fh1h
9. As an operator, I want a `wait` operation to wait a bounded time and re-observe, so that loading pages do not trigger blind clicks. ^drive-qwbp
10. As an operator, I want a step whose target turned stale to re-observe and decide again without counting a browser action, but to count toward the step cap, so that a fast page cannot spin forever. ^drive-9y2s
11. As an agent, I want `blocked` to return to me at once with the trace, so that I decide whether to hand off, retry, or give up. ^drive-8rts
12. As an agent, I want `done` reported as JEV's opinion and never as a verified outcome, so that I always verify. ^drive-8zh8
13. As an agent, I want a System One or text-helper failure to end the drive with `error` and `model-unavailable` detail after the client's bounded retries, so that a provider outage is visible and cheap. ^drive-kh2u
14. As an operator, I want a drive to hold the tab's action slot for its duration, so that no other request interleaves with the loop. ^drive-tfqh
15. As an agent, I want the drive to refuse a tab I do not own, one handed to the human, or one with an open dialog, so that it starts only from a state it can act in. ^drive-ig84
16. As an agent, I want the drive to stop with `error` if the page opens a dialog mid-loop, reporting the dialog, so that I answer it deliberately. ^drive-n3ld
17. As an operator, I want the JEV model id pinned in config and the reply model checked against it, so that a provider substitution is caught. ^drive-e7oi
18. As an operator, I want the usage and cost of each drive logged, so that I can see what it costs. ^drive-7tvn
19. As an agent, I want the drive to stop with `blocked` when the last three steps were non-wait actions that changed nothing on the page (jev-ultrafast's stall rule), so that a loop that is not progressing does not spend the whole step cap. ^drive-4bhg
20. As an operator, I want the System One endpoint and the text-helper base URL configurable, defaulting to OpenRouter, with TypeSafe's direct endpoint accepted, so that either key works. ^drive-yqxg
21. As an agent, I want `drive --dry-run` to run exactly one observe-and-decide step against the models and return the decision with probabilities without acting, so that I can test a goal on a page before letting the loop run. ^drive-l7yk
22. As an operator, I want the drive loop written as a computation performing `Observe`, `Decide` and `Act` with the production handler in one fiber, so that the scripted-test handler and a later human-inspector handler are the same loop with a different handler (eta-next ADR-0006). ^drive-8n2z

## Implementation Decisions

- The loop is an ordinary client of the observation and action layer inside the service, run within the tab's action slot. It uses no CDP directly.
- The request is jev-ultrafast's at commit `1231850a` (2026-09-18), copied into eta-next's `docs/issues/ai-systemone/reference/`, not adapted: `state = {page: {url, title, text}, elements: [{index, label, role?, current_value?, checked?, selected?, expanded?, operations: [CLICK|TYPE_TEXT|SELECT]}], recent_actions: last 10 of {action, kind, text, page_changed}}`; `questions.operation` is a choice whose criteria are the operations with targets on this page (`CLICK`, `TYPE_TEXT`, `SELECT` with jev's label strings) plus the controls (`WAIT`, `SCROLL_UP`, `SCROLL_DOWN` with their labels) plus `DONE` and `BLOCKED`, with `instructions = {goal, rules: NEXT_ACTION}`; each `<op>_target` question's criteria are keyed by element index with `{element: "[i] label", current_value, role, checked, selected, expanded}` and `instructions = {goal, operation, rules: [NEXT_ACTION, TARGET]}`. Only the target answer matching the chosen operation is validated and used. `page.text` is the rendered visible text (the `text` command's output, bounded).
- `NEXT_ACTION`, `TARGET` and `TEXT_VALUE` are the exact strings from `questions.py` at that commit, stored verbatim in a `questions.ml` with the commit hash in a comment; JEV was trained on that framing and the texts are not free to drift. `MAX_STEPS` is Leash's `--max-steps`, default 30 (jev's demo uses 60).
- Text helper: `Eta_ai_chat.complete` with `json_object:true`, `max_tokens:1024`, reasoning disabled, default model `inception/mercury-2.5`; system message `TEXT_VALUE`, user message the JSON of jev's `field_context`: `{goal, field: {label, role, value}, page: {title, text[:6000]}, recent_actions: last 6 of {action, text}}`. The reply must parse as `{"text": string | null}`; `null` means the value is missing and the step ends the drive with `blocked` and the field named; text over 4 KiB is refused. A generated value is reused for a stale-page retry only if the full helper input is unchanged.
- Step settle waits are the action layer's; the drive adds none.
- Error taxonomy inside the drive is a closed variant mapped to the protocol's `status` and `error`.
- System One access is eta-next's `Eta_ai_systemone`; the model id is `typesafe/jev-1.13-20260917` on OpenRouter (or `jev-latest` on TypeSafe's endpoint) unless configured otherwise.
- Loop shape (ADR-0006 of eta-next): a computation over three operations, `Observe : unit -> snapshot`, `Decide : request -> decision`, `Act : action -> outcome`, with a `local` handler token; production installs snapshot/System One/actions, tests install a scripted handler, and `--dry-run` installs a handler whose `Act` returns without acting. The computation stays in one fiber; handlers may use Eio.

## Testing Decisions

- Protocol seam with the fake browser scripting page states and a fake System One and text-helper HTTP server scripting answers per request. Assertions on the trace, the CDP messages received, and the requests the model fakes received.
- Loop and outcome: drive-y7v8, drive-xjh6, drive-4zlp, drive-ix5t, drive-8rts, drive-8zh8.
- Request shaping: drive-y37b, drive-zml5, drive-fh1h, drive-e7oi.
- Text helper and validation: drive-ls3c.
- Stale, wait, dialog, failure paths: drive-qwbp, drive-9y2s, drive-kh2u, drive-n3ld, drive-ig84.
- Concurrency: drive-tfqh.
- Logging: drive-7tvn via the in-memory Eta logger.
- Live-acceptance: one real drive on a public page with a recorded goal, compared against an independent check of the outcome, jev-ultrafast style.

## Out of Scope

Multi-step plans, auto-handoff, screenshots in the loop, any operation beyond the eight, tabs beyond the one driven, popups (a popup ends the drive with `error`).

## Further Notes

- Pinned: jev-ultrafast `1231850a0bf1a0c0341fe408ef1668dbbfdfac46` (2026-09-18). Its reference files live in eta-next `docs/issues/ai-systemone/reference/`. Changes to the texts or shapes are a decision, not a refactor.
- jev-ultrafast talks to `api.typesafe.ai` directly; SmartRouter uses OpenRouter's System One proxy. The two are the same contract; the configured endpoint decides.
- Whether `recent` should be 5 steps is a guess; jev-ultrafast's value is the reference.
- L22 (drive-ls3c) delivered the text step as the loop's fourth operation, `Text : field_context -> string | null`, beside `Observe`/`Decide`/`Act` rather than folded into `Act`: it is its own model call, and the scripted and inspector handlers suspend on it the way they suspend on `Decide`. `Act` carries the value it answered, and a `type_text` act writes it through the `fill` path.
- Candidate shape (eta-next ADR-0006): write the loop as a computation performing `Observe`, `Decide`, `Act` with three handlers — production (snapshot, System One, browser action), scripted test (no fake HTTP server needed for the loop's own tests), and a human inspector that pauses each `Decide` like jev-ultrafast's "Choose next". The loop runs in one fiber; handlers may use Eio. Decide when milestone 5 is re-cut against eta-next.
- L23 live acceptance (2026-09-28, headless Chrome, real models via OpenRouter, `scripts/live-acceptance-m5`): both tasks from a fresh tab with `--max-steps 15 --deadline-s 300`, one `--dry-run` each first. Usage comes from drive-7tvn's info lines (`systemone usage` / `text helper usage`) in the service log; the chat usage shape reports tokens but no cost.
  - Wikipedia ("Find and open the Wikipedia article about Gödel's incompleteness theorems" from https://www.wikipedia.org/): **done** in 3 steps, 5.4 s wall. Decisions: type_text/TYPE_TEXT 0.99 on row 12 (the helper typed the goal's phrase verbatim), click/CLICK 0.97 on row 14 (the Search button; navigated straight to the article), done/DONE 0.62. Final https://en.wikipedia.org/wiki/G%C3%B6del%27s_incompleteness_theorems, verified by reading the page text. Model calls: 3 System One (23,553 in / 2,138 out tokens, $0.000989) + 1 text helper (1,115 tokens).
  - Flights ("Search Google Flights for a one-way flight from Warsaw (WAW) to London (LHR) leaving on October 15, 2026." from https://www.google.com/travel/flights): **blocked** in 2 steps, 2.0 s wall. The flights URL redirects to a consent.google.com interstitial ("Before you continue", 7 rows with no Accept/Reject in the table, only a "Sign in" link at row 2). JEV clicked it (CLICK 0.60), landed on accounts.google.com sign-in, and blocked (BLOCKED 0.79) rather than proceed. That is the site, not Leash: Leash observed, acted, settled and reported correctly throughout, and stopping at a sign-in wall is the right call. Model calls: 2 System One (2,471 in / 134 out tokens, $0.000104), no helper call. The reference copies contain no demo task list, so the Flights goal text is the gate's own, in jev's style.
  - Dry runs: one decision each (wikipedia type_text 0.98, flights click 0.61), page untouched (url/title compared before/after), exactly one System One call and no helper call each. SIGTERM exits 0 with Chrome reaped; the gate asserts the key is in no CLI reply and no service log line.
  - Defects found live and fixed in L23: (1) the control listener's 64 KiB reply ceiling silently dropped large replies — a default `text` on a long article closed the connection with no reply; the listener now allows 1 MiB each way and logs dropped peers (tab-x4v0, tab-0lax; regression: a 70 KB text over a real socket). (2) drive `error` carried no cause; it now names the failed action/observe with its code, the dialog kind, or the popup count (drive-y7v8, drive-n3ld; the reason diagnosed (3)). (3) the drive's scroll-metrics query threw on a document mid-navigation (no documentElement yet), failing the step after every navigation-ending action; it is null-safe now (drive-y7v8; the sent query is pinned in the models test). (4) usage/cost had only eta's debug lines, invisible at the default level; Leash logs each answered model call at info (drive-7tvn).
  - Follow-up, not L23: after a click-navigation the tab title sticks at Chrome's tab-strip value (the formatted URL) instead of the document title — the load path refreshes it, the click settle asks too early (chrome-qnul). JEV still decided correctly on url/text; the trace and `list` titles are the casualties.
