---
status: ready-for-agent
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

## Implementation Decisions

- The loop is an ordinary client of the observation and action layer inside the service, run within the tab's action slot. It uses no CDP directly.
- State sent to System One (from jev-ultrafast, adapted): `{goal, url, title, elements: [[index, role, name, value]...], recent: [last 5 steps as {operation, index, name}]}`. Questions: `operation` (choice over the operations whose targets exist on this page plus `wait`, `done`, `blocked`), `click_target` (choice over clickable rows), `type_text_target` (choice over editable rows), `select_target` (choice over select rows, present only if any). Only the answer matching the chosen operation is used.
- Instruction texts for the questions are a versioned resource in the repository (jev-ultrafast's `questions.py` is the reference); JEV was trained on that framing and the texts are not free to drift.
- Text helper: an OpenRouter chat completion with reasoning explicitly disabled (`reasoning.enabled = false`, Eta ticket `openrouter-reasoning-enabled`; omitting the field leaves the provider default on), default `inception/mercury-2.5`, prompt containing the goal, the target row, the page title, and the recent steps, output required to be `{"text": "..."}` with text under 4 KiB. A generated value is reused for a stale-page retry only if the full helper input is unchanged.
- Step settle waits are the action layer's; the drive adds none.
- Error taxonomy inside the drive is a closed variant mapped to the protocol's `status` and `error`.
- System One access is Eta's `etaso` client; the JEV model id is `typesafe/jev-1.13-20260917` unless configured otherwise.

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

- The exact question texts and the state shape are copied from jev-ultrafast at a pinned commit and recorded in the repository; changes are a decision, not a refactor.
- Whether `recent` should be 5 steps is a guess; jev-ultrafast's value is the reference.
