---
status: completed
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
17. As the operator, I want U1 and U2 run by the implementing agent on my real Tauron account with my real login and password (from `~/.config/leash/use-cases/tauron`, passed with `--secret`), headed on my desktop, and the reply's `result` — what is overdue, and the downloaded invoice's path — pasted into `docs/use-cases.md` with the date, so that the thing I actually asked for is the thing that is tested; U3/U4 the same on Allegro when I write that file. ^pilot-sa3f
18. As a maintainer, I want the same ten missions run twice — the second time with the pilot's written procedures installed — and the pilot-turn count and cost compared, so that 'playbooks as memory' is measured, not assumed. ^pilot-ivzx
19. As a maintainer, I want every failure in the gates diagnosed to a cause and filed as a story, never fixed by rewording a mission, so that the use cases improve Leash, not the prompts. ^pilot-lo8y
20. As an agent, I want the skill and `help drive` rewritten for the pilot loop: what a mission should say (the result wanted, the limits), how credentials are passed, what `result`/`evidence` mean, and that playbooks are optional, so that the next agent uses it right. ^pilot-bkw9
21. As a maintainer, I want the pilot prompt versioned in `planner.ml`, under 300 words, stating only: the answers and their shapes, the safety refusals, and 'a leg is one navigation goal in JEV's language', so that the prompt is not a rulebook. ^pilot-r94o
22. As the operator, I want `leash drive --dry-run` to show the pilot's first decision and its reasoning summary without acting, so that I can see what it intends on a new site. ^pilot-cnp5


### Gate findings (2026-10-04)

The L57 gates and operator feedback below found five defects. Each is diagnosed to a cause and filed here, not fixed by rewording a mission (pilot-lo8y). The fixes follow as their own slices.

23. As the operator, I want a password the pilot generates for a mission to be handed to me in the reply's `secrets_for_operator` (and through the notification when one is configured), so that I can actually use the account it just created. U7 on the fixture: the pilot invented `N0rthstar!H7qL_29vR`, typed it into both fields, and returned `secrets_for_operator: []`; the account exists and nobody knows its password. ^pilot-gn4w
24. As the operator, I want a value typed into a password field never to appear in the reply or the durable trace, whoever chose it. The same U7 run wrote the generated password in cleartext into the reply's pilot turns and twice into the trace, although the trace's own rule is that password fills are recorded as `[password]`: redaction covers `--secret` values and `secrets_for_operator`, and nothing marked a value the pilot invented. ^pilot-pw7x
25. As the operator, I want a collection mission that asks for a file (`--out FILE`) to end with that file holding the records, so that "collect every title and price in category Travel to a JSONL file" is a mission and not a paraphrase. U8 returned all eleven Travel title/price pairs in cleartext — verified 11/11 against the category page — and left the `--out` file empty with `output_kinds: []`: only a validated playbook script record can write it, and the pilot's answers (leg, read, act, handoff, notify, done, fail) contain no script answer. ^pilot-sc9t
26. As the operator, I want an explicitly requested upload to attach the named local file through the normal validated upload action and return the resulting link, so that U9 does not require manual completion. The fixture run refused `fill` on a file input, then expired after a 300-second handoff with zero uploads. The pilot advertises click/select/fill/press/scroll, not upload; a filename cannot be typed into a file input. The failure is the missing pilot upload path, not a fixture error. ^pilot-h506

27. As the operator, I want dismissing or canceling a handoff notification to end the handoff immediately with an explicit canceled-by-operator outcome, distinct from expiration and notification delivery failure, so that my refusal is not reported as a timeout. During L57 the operator canceled the notifications, but the run waited and reported expiration. The inspected desktop callback recognizes only the stdout action `done`; notification closure has no cancellation callback into the waiting handoff. This records the operator report and source finding; an end-to-end dismissal regression is still required. Notifications must stay enabled; disabling them is not a fix. ^pilot-9u3q

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

Credentials are the operator's business. `--secret` exists so a value can be kept out of the trace and out of the model's context when the operator wants that; a credential written plainly into a mission is also accepted and used, with no refusal and no warning — Leash does not police what the operator chooses to share. `docs/use-cases.md` is the acceptance list and is edited only by the operator or the coordinator.
## Delivery — L56

Implemented; verified offline at the protocol seam with a scripted pilot and the fake browser (`@install`, `dune test`, `@fmt`, capability gate green at e494f43 and in every commit since):

- The pilot loop in `run.ml`: the planner owns the mission and answers `leg`, `read`, `act`, `handoff`, `notify`, `done{result,evidence}`, `fail`. A leg runs the operator loop with a leg-local cap and ends when the page navigates, so the pilot sees every page. `pilot.turns` 12 and `pilot.deadline_s` 600 bound the mission; the reply carries `result`, `evidence`, `pilot_turns` and `navigator_steps`.
- `--secret NAME=@file|-`: the value lives in the CLI and the request, the pilot sees the name only, `act fill` resolves it at dispatch, and it never reaches a trace, reply or log (the redaction test covers traces, replies and logs). A credential written plainly in a mission is accepted and used, with no check, prompt or warning.
- Refusals: `act` refuses payment, checkout confirmation, sending and deletion unless the mission names that action, matched as whole words (Polish verbs included).
- Compile-from-traces deleted, its stories retired: learning is now "write the legs that worked as a procedure after `done`" plus the replay gate, and drafts are offered to the pilot as candidates, never forced. Each turn records the offered and chosen candidates.
- `--dry-run` shows the pilot's first decision and reasoning summary without acting; the pilot prompt is versioned and under 300 words (tested).

Live evidence, the operator's real Tauron account, 2026-10-04: **U1 and U2 pass**. U1 reported 756,88 zł overdue (544,92 zł + 211,96 zł, due 02.10.2026) and U2 downloaded invoice E/TM2/UG533989/0003/26 of 16.09.2026 as a PDF, both independently verified from the page and the PDF. The failures found on the way — a rejected pilot action shape, a missing act history, an over-eager payment refusal, a label-shaped select, a download the pilot could not see, an unstable first observation, a 30-second wheel ack — are diagnosed with their fixing commits in the ledger at the end of [use-cases.md](../../use-cases.md#results--2026-10-04).
