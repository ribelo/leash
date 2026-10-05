---
status: ready-for-agent
milestone: 15
---

# Revert the pilot: JEV runs the loop again

## Problem Statement

ADR-0012 made the planner own the mission. The operator never decided that; the coordinator wrote it. The corpus shows JEV asked in 12% of cells. `drive.ml`, JEV's loop as designed, still exists; the pilot sits on top in `run.ml` and `planner.ml`.

## User Stories

1. As the operator, I want `drive MISSION` to run JEV's loop (`drive.ml`): one decision-model call per step over the page's element table, the text helper for field values, procedures and scripts offered as operations when a playbook matches, the stall rule, the step cap and deadline — the jev-ultrafast shape — so that the decision model does the work. ^revert-eft1
2. As a maintainer, I want the pilot loop removed: legs, the pilot's own acts, `observe --image` for the pilot, the pilot prompt, `[pilot]` config, `pilot_turns` in the reply, and their tests deleted, so that no second loop exists. ^revert-o3fh
3. As the operator, I want the second model used for exactly one thing — writing the text JEV types into a field (the text helper, `[models] text_model`) — and no planner role of any kind: no BLOCKED hint, no expectation judgment, no end-of-mission answer; `[models] planner_model` removed, so that the model that cannot click never decides. ^revert-24kr
4. As the operator, I want `drive` to end on JEV's DONE or BLOCKED (or cap/deadline) and return the final page — snapshot id, URL, title, bounded text — with `result`/`evidence` removed from the reply, so that the calling agent reads the answer from the page, as in jev-ultrafast. ^revert-bqrq
5. As the operator, I want BLOCKED to end the mission with the final page and JEV's last probabilities, nothing more, so that there is no second loop and no second decider. ^revert-apgf
6. As a maintainer, I want coordinate actions, `--secret`, `notes`, hand-written playbooks, scripts, the decision-model configuration with images (L60) and the corpus (L61) kept unchanged, so that only the inversion is undone. ^revert-k63o
7. As a maintainer, I want ADR-0012 marked withdrawn by ADR-0015, GLOSSARY ('pilot', 'leg' retired), help topics, the skill and milestones.md updated, so that no document says the planner drives. ^revert-wrcc
8. As a maintainer, I want the corpus re-run on the reverted loop (same 20 missions, JEV and Clef, image off/B/C, three styles, none/notes/procedures) with the table under docs/corpus/<date>/ and the five conclusions, so that the design the operator wanted is measured in the same instrument that caught the wrong one. ^revert-3zp1
9. As the operator, I want U1 and U2 run on the reverted build on my Tauron account and recorded, so that the daily case still works. ^revert-kmr3
10. As a maintainer, I want the commit to report lines removed, so that the revert is visible as a removal. ^revert-tjwo

## Out of Scope

Anything new.
