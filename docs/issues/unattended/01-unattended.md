---
status: ready-for-agent
milestone: 12
---

# Unattended: notifications that do not block, handoffs that end, CAPTCHAs the agent tries first

## Status — 2026-10-04

Ready for agent only on the undelivered legacy challenge stories listed below. L55 as a separate loop slice is superseded by [L56](<../pilot/01-pilot.md>): non-blocking notify (`notif-7o8j`, `notif-m37y`, `notif-7pha`), bounded handoff expiry (`notif-oslv`) and ordinary validated pilot actions (`notif-tdtz`) are in the pilot loop. Notification cancellation is additionally delivered by L57C.

Not all original L55 claims can be ticked: `Run.loop` currently ignores `challenge`, `challenge_attempt` and `challenge_turns`; the scripted challenge tests choose their own attempt count and handoff. They prove the pilot action path, not a service-enforced challenge policy. Open existing stories:

- `notif-himb` — detected challenges trigger the configured attempt policy.
- `notif-p4yk` — the configured turn bound enforces CAPTCHA handoff and challenge outcome.
- `notif-udh3` — `challenges.attempt`/turns actually govern attempts and their audit.
- `notif-646o` — recorded live reCAPTCHA demo measurement.

These findings are recorded, not repaired in the current L57F case sequence.

## Problem Statement

Leash is meant to run while the operator is away from the computer — he dictates everything, uses the computer with difficulty, and wants the browser automated for that reason. Today the only way the system reaches him is `handoff`, which stops the mission and waits (fifteen minutes by default); there is no way to *tell* him something and continue; and every CAPTCHA is sent to him, although current planner models pass most of them, and a bot acting for its user and doing nothing harmful should not be blocked (the operator's view, and OpenAI's).

## Solution

A non-blocking `notify` the planner (never JEV) can send; handoff deadlines tuned for absence, with what happens on expiry stated; and CAPTCHAs attempted by the planner first — through the normal action path, bounded — with handoff only for the ones it cannot pass.

## User Stories

1. As the operator, I want the planner to have a `notify` answer — a one-line message sent through the configured notification command without stopping the mission — used for 'I ordered the trousers, order 12345' or 'Allegro asked for a login; I am waiting for you' and recorded in the trace, so that I hear from the system without it waiting for me. ^notif-7o8j
2. As the operator, I want JEV never to notify or hand off directly: JEV answers `BLOCKED`, the planner decides whether to `continue`, `notify`, `handoff` or `fail`, so that the choice to interrupt me is made by the model that can read the situation. ^notif-m37y
3. As the operator, I want `handoff` to end at its deadline (default lowered to 5 minutes; `handoff.timeout_s` in config) with the mission ending `handoff-expired`, the tab left open and `with_human` cleared, a second notification 'the agent gave up waiting; the tab is still open', and the trace recording the wait, so that an unattended run never waits forever and I can still finish by hand. ^notif-oslv
4. As the operator, I want a notification's command and urgency configurable (`handoff.notify_command` exists; add `notify.command` for the non-blocking kind, default `notify-send --urgency=normal`), with a test that a failing command never fails the mission, so that the channel can be changed — a phone later — without touching the loop. ^notif-7pha
5. As a runner, I want a CAPTCHA or bot challenge detected (the `debug` challenge signal of hardening-3, or a page kind whose text marks it) to trigger a planner turn first, with the planner allowed to `continue` with up to `learning.planner_actions` actions on the challenge's visible rows — clicking the checkbox, choosing images by their labels, typing the characters it reads — so that the challenges current models pass are passed. ^notif-himb
6. As a runner, I want a challenge the planner did not clear within two turns handed off with reason `captcha` and, if the handoff expires, the mission ended `blocked` with `detail.challenge` naming the origin, so that only the challenges the agent cannot pass reach me. ^notif-p4yk
7. As the operator, I want a config switch `challenges.attempt = true|false` (default true) and the attempt, its turns and the outcome recorded in the trace, so that the behaviour can be turned off and audited. ^notif-udh3
8. As a maintainer, I want the planner's challenge actions to be ordinary protocol actions on snapshot rows (never raw JavaScript, never coordinates the model invents, never a solver service), so that the safety rule holds and the attempt is only what a person could do by hand. ^notif-tdtz
9. As a maintainer, I want a live check on a harmless page with a visible reCAPTCHA v2 demo (Google's own test keys) recorded: the planner's attempt, whether it passed, the turns used, so that the claim 'models pass most of them' is measured before it is relied on. ^notif-646o

## Implementation Decisions

- `notify` and `handoff` are both planner answers; `notify` does not change tab state and returns to the loop.
- Handoff expiry is an ending (`handoff-expired`), not an error code; the tab stays open as an agent tab, so it closes by the idle rule later.
- Challenge detection reuses hardening-3's debug signal and the inferred page kind; the two-turn bound is `challenges.turns` (default 2).

## Testing Decisions

- Protocol seam with a scripted planner: notify, handoff expiry, challenge attempt and fallthrough; failing notify command. Live: story 9.

## Out of Scope

CAPTCHA solving services; notifications to a phone (the command is configurable for it later); JEV-initiated notifications.

## Further Notes

Operator, 2026-10-01: notifications must not wait forever; JEV hands to Luna, Luna may notify; most CAPTCHAs should be attempted by the agent since a bot acting for its user and doing no harm should not be blocked, and he is often away and uses the computer with difficulty.
