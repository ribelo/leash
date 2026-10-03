---
status: ready-for-agent
milestone: 13
---

# The pilot drives

## Problem Statement

`drive` is JEV's loop with the planner as a fallback. JEV cannot know when a mission is done; it sees only whether a page looks right. So missions that ask for an answer, a quantifier, or an action with a result end `done` with nothing: Flights five times, Maps four of five. The operator's actual use — "check whether I owe anything on Tauron", "download the invoice", "add the cheapest one to my cart" — is exactly this kind of mission, said ad hoc, without a script and without a playbook. The thing that can reason about the result (Luna) was only asked when JEV gave up, and JEV does not give up — it declares `done`.

## Solution

ADR-0012: the planner holds the mission and the page; JEV drives legs. `drive` becomes a pilot loop: the pilot observes (bounded page text + element table), decides (next leg | read | act | handoff | notify | done with result and evidence | fail), JEV executes a leg as today's operator loop with a leg-local `done`, the pilot observes again. Playbooks are a memory of legs the pilot wrote after a mission; with none, nothing changes but the number of pilot turns. The ten use cases are the acceptance.

## User Stories

### The loop

1. As the operator, I want `drive MISSION` to start with a pilot turn: the planner receives the mission, the page's bounded text (6,000 chars) and element table (250 rows, the same view `snap`/`text` give an agent), the inferred or declared page kind, and the history of legs so far, and answers one of `leg`, `read`, `act`, `handoff`, `notify`, `done`, `fail`, so that the model that can reason owns the mission from the first step. ^pilot-ukoh
2. As the operator, I want a `leg` to be a short navigation goal in JEV's language ("open the invoices page", "click the button named Pobierz", "type {query} in the search box and submit") run by today's operator loop with its own step cap (default 15) and a leg-local `DONE`/`BLOCKED`, after which control returns to the pilot with the new page, so that JEV does what it is good at and nothing more. ^pilot-eu1c
3. As the operator, I want `read` to be the pilot extracting the answer from the page it is shown (no model call beyond the pilot's own; no script), recorded as a reading step with the text it quoted, so that "what is overdue" is answered from the page by the model that read it. ^pilot-x1f3
4. As the operator, I want `act` to be one bounded protocol action the pilot names on a row of the current snapshot (click a download, select an option, fill a non-secret value), through the same revalidation as any action, so that the pilot can finish a task without a leg when one click remains. ^pilot-8csf
5. As the operator, I want `done` to carry `result` (one paragraph: the answer, or the action's outcome with its identifiers) and `evidence` (page kinds/URLs read, files downloaded, the cart's final state), and the drive reply to carry both at top level, so that `done` without a result is impossible by type. ^pilot-gt2h
6. As the operator, I want the pilot to run at `planner_reasoning = max` by default and the loop bounded by `pilot.turns` (default 12), `pilot.deadline_s` (default 600) and the existing cost report, so that a mission is a handful of pilot turns and tens of JEV steps, visible in the reply. ^pilot-s954
7. As the operator, I want JEV's `DONE` never to end a mission — only a leg — and the mission to end only on the pilot's `done`, `fail`, `handoff`-expired, a cap or a deadline, so that nobody who cannot reason declares the mission finished. ^pilot-rdjv

### Credentials and safety

8. As the operator, I want the pilot, on a login page, to answer `handoff` with reason `login` *or* `act fill --stdin` for a field the operator has provided a value for in this call (`drive --secret NAME=@file` or `--secret NAME=-` from stdin), the value never entering the trace, the reply or a log, so that Tauron and Allegro are reachable without the credential passing through any model or transcript. ^pilot-02ij
9. As the operator, I want the pilot's `act` to refuse payment, checkout confirmation, message sending and deletion unless the mission names that action explicitly (text match on the mission plus the page-kind classification of hardening-3 and ADR-0011), with the refusal recorded, so that "add to cart" never becomes "buy". ^pilot-e4sh
10. As the operator, I want a mission that generates a password (U7) to hand the generated value to the operator through the notification and the reply's `secrets_for_operator` (stdout only, never the trace), so that a credential the system created reaches only me. ^pilot-a4ua

### Playbooks as memory

11. As the operator, I want the pilot, after a `done` mission on a site, to write the legs that worked as a procedure (goal steps = the legs, args = the mission's values, expect = what the pilot verified before `done`) to `proposed/`, installed by the existing replay gate on the next mission that uses it, so that the second mission on a site spends fewer pilot turns. ^pilot-3egp
12. As the operator, I want installed procedures offered to the pilot as `leg` candidates ("procedure open-invoices is available for this page") and chosen by the pilot, not forced, so that a stale procedure costs one wasted leg, not a failed mission. ^pilot-oijk
13. As a maintainer, I want ADR-0011's compile-from-traces path removed (learning.ml's segmentation, structural agreement, outline capture, the compile prompt), its stories retired, traces/page kinds/gates/repair kept, and the `[learning]` config reduced to `mode = off | auto` (drafts written by the pilot, installed by replay), so that the learner is the pilot, not a reconstruction. ^pilot-c77y
14. As a maintainer, I want scripts to stay exactly as L46 left them — JEV's tools inside procedures, written by an author or by the pilot for a collection mission from the page it is shown (U8), validated and replay-gated — so that collection keeps the one mechanism that works. ^pilot-ffqa

### Proof

15. As a maintainer, I want U5, U6 and U8 run as the live gate with `result` checked against an independent read (the harness fetches the month view / the place / the category itself), pilot turns and cost recorded per mission, so that 'the pilot answers' is a number. ^pilot-kkq2
16. As a maintainer, I want U7, U9 and U10 run against local fixtures (a registration form with a mailbox stub, an upload endpoint that records one upload, a portal with a login and an inbox), so that the action-with-result cases are proven without a real account. ^pilot-7boq
17. As the operator, I want U1–U4 run by me, headed, with the credentials supplied through `--secret` at the call and the reply's `result` compared with what I see, recorded in `docs/use-cases.md` with the date, so that the daily-life cases are proven on my accounts by me. ^pilot-sa3f
18. As a maintainer, I want the same ten missions run twice — the second time with the pilot's written procedures installed — and the pilot-turn count and cost compared, so that 'playbooks as memory' is measured, not assumed. ^pilot-ivzx
19. As a maintainer, I want every failure in the gates diagnosed to a cause and filed as a story, never fixed by rewording a mission, so that the use cases improve Leash, not the prompts. ^pilot-lo8y
20. As an agent, I want the skill and `help drive` rewritten for the pilot loop: what a mission should say (the result wanted, the limits), how credentials are passed, what `result`/`evidence` mean, and that playbooks are optional, so that the next agent uses it right. ^pilot-bkw9
21. As a maintainer, I want the pilot prompt versioned in `planner.ml`, under 300 words, stating only: the answers and their shapes, the safety refusals, and 'a leg is one navigation goal in JEV's language', so that the prompt is not a rulebook. ^pilot-r94o
22. As the operator, I want `leash drive --dry-run` to show the pilot's first decision and its reasoning summary without acting, so that I can see what it intends on a new site. ^pilot-cnp5

## Implementation Decisions

- The pilot loop is `run.ml`'s mission level with the planner as the chooser; the operator loop is reused unchanged for legs with a leg-local cap. `Done {result; evidence}` and `Continue_actions` already exist as planner answers; `leg` and `read` are added; `Procedure` stays for writing memory.
- The page view given to the pilot is the agent's `snap`/`text` view, bounded identically; no new observation path.
- `--secret NAME=@file|-` values live in the CLI process and the service's request only; the pilot sees the *name*, never the value; `act fill` with a secret name resolves it at dispatch.
- Learning: `learning.ml` shrinks to 'write the legs as a procedure after done' + the replay gate; everything built for compile-from-traces is deleted, not disabled.
- Cost report gains `pilot_turns` and `navigator_steps`.

## Testing Decisions

- Protocol seam with a scripted pilot and the fake browser: each answer kind, caps, secrets never in trace/log, refusals, memory written and offered. Live: stories 15–18.

## Out of Scope

CAPTCHA solving beyond L55; running U1–U4 by anyone but the operator; cross-site missions in one drive.

## Further Notes

Credentials the operator pasted into the design conversation on 2026-10-03 must be rotated before U1/U2 run; the agent never receives them. `docs/use-cases.md` is the acceptance list and is edited only by the operator or the coordinator.
