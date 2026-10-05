---
status: completed
milestone: 15
---

# Revert the pilot: JEV runs the loop again

## Problem Statement

ADR-0012 made the planner own the mission. The operator never decided that; the coordinator wrote it. The corpus shows JEV asked in 12% of cells. `drive.ml`, JEV's loop as designed, still exists; the pilot sits on top in `run.ml` and `planner.ml`.

## User Stories

1. As the operator, I want `drive MISSION` to run JEV's loop (`drive.ml`): one decision-model call per step over the page's element table, the text helper for field values, procedures and scripts offered as operations when a playbook matches, the stall rule, the step cap and deadline — the jev-ultrafast shape — so that the decision model does the work. ^revert-eft1
2. As a maintainer, I want the pilot loop removed: legs, the pilot's own acts, `observe --image` for the pilot, the pilot prompt, `[pilot]` config, `pilot_turns` in the reply, and their tests deleted, so that no second loop exists. ^revert-o3fh
3. As the operator, I want the larger model (configured as `[models] planner_model`, optional; absent means never called) consulted only: (a) when JEV answers BLOCKED, (b) when a procedure's expectation fails, (c) once at the end of a mission whose text asks for an answer — given the final page's text and element table, asked for `result` and `evidence` and whether the mission is done — so that reasoning is a fallback and a judge, never the driver. ^revert-24kr
4. As the operator, I want the drive reply to keep `result` and `evidence`, filled by the end judgment when a planner is configured and null otherwise, so that missions with an answer still return one. ^revert-bqrq
5. As the operator, I want BLOCKED handling to give the planner the page and let it answer one of: a short hint JEV is then given as its goal for the next steps, `handoff`, `notify`, or `fail` — never a sequence of actions of its own — so that the planner steers JEV and does not replace it. ^revert-apgf
6. As a maintainer, I want coordinate actions, `--secret`, `notes`, hand-written playbooks, scripts, the decision-model configuration with images (L60) and the corpus (L61) kept unchanged, so that only the inversion is undone. ^revert-k63o
7. As a maintainer, I want ADR-0012 marked withdrawn by ADR-0015, GLOSSARY ('pilot', 'leg' retired), help topics, the skill and milestones.md updated, so that no document says the planner drives. ^revert-wrcc
8. As a maintainer, I want the corpus re-run on the reverted loop (same 20 missions, JEV and Clef, image off/B/C, three styles, none/notes/procedures) with the table under docs/corpus/<date>/ and the five conclusions, so that the design the operator wanted is measured in the same instrument that caught the wrong one. ^revert-3zp1
9. As the operator, I want U1 and U2 run on the reverted build on my Tauron account and recorded, so that the daily case still works. ^revert-kmr3
10. As a maintainer, I want the commit to report lines removed, so that the revert is visible as a removal. ^revert-tjwo

## Found while re-running the corpus

11. As the operator, I want a Clef-family decision model never asked a choice question with a single option, so that a page with one textbox or one link does not end the mission with HTTP 422. Workers AI refuses a choice under two options ("questions: Dictionary should have at least 2 items"); JEV accepts one. The first corpus run on the reverted loop ended 35 of 60 Clef cells this way. ^revert-v1hm

12. As the operator, I want CLICK_AT asked over at most 10 bands per axis, so that a Clef model given a screenshot is not refused. Clef's Decisions API takes at most 10 score criteria (HTTP 422); the default was 20, which ended 22 of the canvas cells. ^revert-ook4


Filed from the corpus run of 2026-10-05 on the reverted loop (docs/corpus/2026-10-05). 13 (53d92af), 14 (9edeb04) and 15 (6ed9b19, verified on U2 2026-10-06) are done; 16 is open:

13. As the operator, I want the planner told when the browser is headless, and never offered a handoff there, so that a stop on a headless browser ends in a hint or a failure, not in error `headless`. The planner chose handoff in 223 of 1,260 public cells and in 13 of the 18 Tauron cells. ^revert-r9ka
14. As the operator, I want JEV's loop able to attach a file the mission names to a file input, so that an upload mission can be driven. JEV has no upload operation; u9 passed 0 of 63. ^revert-31w3
15. As the operator, I want a download JEV already completed in a mission not started again, so that one invoice arrives once. U2 goal/notes downloaded the latest invoice twice. ^revert-3scf
16. As the operator, I want a decision or text-helper call refused for load (HTTP 529, a timeout) told apart from a mission failure in the reply, so that a corpus run under load can be read. 70 cells ended `model-timeout` and many `error` cells were text-helper timeouts or Clef HTTP 529 under about 60 parallel drives. ^revert-8eqf

## Takeover (operator, 2026-10-05)

17. As the operator, I want the page handed to the planner, with the mission and what JEV did, when JEV answers BLOCKED, stalls or reaches its step cap (256 per stint), so that what clicking cannot do still gets done. ^revert-n5wc
18. As the operator, I want the planner able to do everything on the page while it holds it (row actions, typing secrets and passwords, uploads, downloads, coordinate clicks, reading, records for --out, the playbook's procedures and scripts, notify, handoff on a headed browser, done, fail), bounded only by the deadline. ^revert-s3t1
19. As the operator, I want the planner to hand control back to JEV with a goal string, so that JEV clicks again as soon as it can. ^revert-orij
20. As the operator, I want JEV to see password fields and type a --secret into them, so that a login does not stall (the rule field-8bzc is dropped). ^revert-5prc

## Out of Scope

Anything new.
