---
status: completed
milestone: 14
---

# Cut learning: the pilot writes nothing

## Problem Statement

ADR-0014. Leg memory sometimes halves a mission's cost and sometimes doubles it; the gates, repair and proposal store exist only for it; inferred page kinds exist only for compile-from-traces, already withdrawn. The operator does not want a self-drawing map. What stays must be what a hand-written playbook needs and nothing else.

## User Stories

1. As a maintainer, I want leg memory removed — the pilot's post-mission procedure writing, `proposed/`, the replay and agreement gates, repair and retire, `[learning]` config, `status.learning` — with their stories retired, so that no code path writes a playbook. ^cut-6mvl
2. As a maintainer, I want inferred page kinds removed; a page's kind is the declared one from the playbook or absent, so that the only vocabulary is the author's. ^cut-0oal
3. As a maintainer, I want traces kept exactly as they are (audit), with the `learning`-related header fields dropped, so that evidence stays and learning goes. ^cut-tsk4
4. As a playbook author, I want an optional top-level `notes` string in a playbook (free text about the site for the pilot: where things are, how login works), shown to the pilot on every turn on that site, bounded to 2,000 characters, so that the cheapest form of site knowledge can be measured against procedures. ^cut-yk93
5. As a maintainer, I want procedures and scripts to work exactly as before (three decision-model levels; `run_script`; scripts as pilot acts), so that the cut touches only what wrote playbooks. ^cut-sqlp
6. As a maintainer, I want GLOSSARY, ADR-0011/0012 marked amended by ADR-0014, the help topics and the skill updated, `docs/milestones.md` saying milestone 14, so that no document describes learning as present. ^cut-ncyj
7. As a maintainer, I want the test suites for removed features deleted, not skipped, and the four gates green, so that the tree is as small as the design. ^cut-kifp
8. As a maintainer, I want the removal to reduce `run.ml`, `planner.ml` and `learning*.ml` by the lines that served learning, reported in the commit (before/after), so that the cut is visible. ^cut-xd4h

## Out of Scope

Anything new. This row only removes and renames.
