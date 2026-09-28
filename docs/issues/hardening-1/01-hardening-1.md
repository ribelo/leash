---
status: ready-for-agent
milestone: 8
---

# Hardening 1: dialogs end waits

## Problem Statement

Reproduced on 2026-09-28 against real Chrome through Leash with three local pages: a page that calls `alert()` during load makes `new`/`nav` time out after 30 s with "navigation did not load" and **no tab handle**, so the agent cannot even dismiss the dialog; a `confirm()` opened by a click makes the click wait out its whole handler budget (35 s) and the CLI reports "service closed without a reply". Both are the pattern the operator suffered with the old CDP scripts: a popup, no information about it, and a cryptic error that blocks the tab. Dialogs that appear *after* an action settles are already handled well (the snapshot reports them; actions are refused with `dialog-open`); dialogs that appear *during* a wait are not.

## Solution

One rule: a JavaScript dialog opening on a tab ends every wait on that tab at once, and the reply carries the dialog. `new` and `nav` return the tab (with `dialog` set, `title` possibly empty) as soon as the dialog opens; an action whose input opened a dialog returns its `ActionResult` with `dialog` set; `wait` returns `dialog-open`; `drive`/`run` already end with the dialog reported. `beforeunload` gets the same treatment. The control listener's budget is never the thing that reports a dialog.

## User Stories

1. As an agent, I want `new <url>` and `nav` on a page that opens a dialog during load to return within a second with the tab handle and `dialog: {kind, message}`, so that I can answer the dialog instead of losing the tab. ^hard-6eei
2. As an agent, I want a click, fill, press or select whose handler opens a dialog (alert, confirm, prompt) to return its `ActionResult` with `dialog` set as soon as the dialog opens, so that I never wait out a budget on a modal. ^hard-dljv
3. As an agent, I want `wait` to return `dialog-open` with the dialog as soon as one opens, so that a wait never runs out its timeout behind a modal. ^hard-s719
4. As an agent, I want `beforeunload` dialogs (opened by a navigation or close) reported the same way, and `close` on a tab with a `beforeunload` dialog to answer it `accept` and proceed, so that a page cannot hold a tab open. ^hard-t6cq
5. As an agent, I want `dialog <tab> accept|dismiss [--text]` to work on a dialog that opened during load, and the load to continue after the answer (observed by the next `wait` or `snap`), so that the page can finish loading. ^hard-tsva
6. As an agent, I want a request that ends by the listener's budget to be reported as `timeout` with the command and the elapsed time rather than a closed connection, so that "service closed without a reply" never reaches me. ^hard-yi0a
7. As an operator, I want a `prompt()` dialog's default text in the report and `--text` to supply the answer, so that prompts are answerable. ^hard-92ik
8. As a maintainer, I want the fake browser to script dialogs at each moment (during load, on input, on unload) and every command's behaviour under each pinned by a test, so that this class of bug cannot return. ^hard-owci
9. As an operator, I want the live-acceptance gate to include the three local pages from the reproduction (alert on load, late alert after click, confirm on click) and to assert the replies above, so that real Chrome's dialog timing is covered. ^hard-wo78
10. As an agent, I want the `leash` skill to say, in one line, that a `dialog` in any reply must be answered before anything else on that tab, so that agents know what to do when it happens. ^hard-fir4

## Implementation Decisions

- The tab's dialog state is set from `Page.javascriptDialogOpening` (already subscribed). Every wait on a tab — load wait, dispatch reply wait, `wait` conditions, expectation waits in `run` — becomes a race between its own condition and the tab's dialog promise; the dialog wins with a typed outcome the caller maps to its reply shape. One helper, used everywhere; no per-command special cases.
- `new`/`nav` return `TabInfo` with a `dialog` field (added to `docs/protocol.md`; `null` when none).
- Story 6: the listener already cancels a handler at its budget; the cancellation is mapped to a `timeout` reply written before the connection closes. The 35 s row-action budget is reviewed once dialogs can no longer make an action run to it.
- Story 5: after the answer, the pending load either completes (`loadEventFired`) or the page stays as it is; the next `snap` observes whatever is there.

## Testing Decisions

- Fake-browser scripts for each dialog moment (stories 1–5, 7, 8) at the protocol seam; the listener-budget reply (story 6) with a slow scripted handler; the three live pages in `scripts/live-acceptance-m8` (story 9).

## Out of Scope

Auto-answering anything (safety default); dialogs inside iframes; native file-picker dialogs.

## Further Notes

Found by the operator's experience with the old CDP scripts and reproduced by the coordinator on 2026-09-28. Milestone 8 is a hardening milestone: further slices come from real use, not from the plan.
