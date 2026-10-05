---
status: ready-for-agent
milestone: 16
---

# No playbooks

## Problem Statement

ADR-0016. The corpus shows playbooks do not pay. What remains must be only what a mission needs.

## User Stories

1. As a maintainer, I want playbooks removed entirely: `playbook.ml`, the loader, procedures, scripts and `run_script`, notes, page kinds, `leash playbook *`, `$XDG_CONFIG_HOME/leash/playbooks`, `examples/playbooks`, `scripts/corpus/playbooks`, the help topics `playbooks`, `authoring`, `scripts`, `expectations`, and their tests, so that no code path reads a playbook. ^bare-b71j
2. As a maintainer, I want the decision-model levels above the operator (playbook and procedure selection) removed with them, so that `drive` is one loop: JEV over the page, the text helper for values, the advisor on BLOCKED / at the end. ^bare-u8ot
3. As a maintainer, I want `traces` kept (audit), with every playbook field dropped from the trace, so that evidence stays. ^bare-um71
4. As a maintainer, I want the corpus kept and its knowledge axis removed (`--knowledge` gone; one variant), so that the instrument matches the product. ^bare-vepy
5. As an agent, I want the skill and `help drive` to say: write the mission as a goal with its result ('…; result: the invoice's path and number'), run `drive` first for any task with a describable outcome, use low-level commands for inspection and what drive cannot do, so that the measured best form is the default. ^bare-so5y
6. As a maintainer, I want GLOSSARY, milestones.md, ADR-0011/0014 marked superseded by ADR-0016, and the map updated, so that no document describes playbooks as present. ^bare-f978
7. As a maintainer, I want the commit to report lines removed, and all four gates green, so that the cut is visible. ^bare-xjiw
8. As the operator, I want the corpus re-run once on the cut build (JEV, images off and B, three styles, --parallel 4) with its table, and U1/U2 on my account, so that nothing regressed in the removal. ^bare-oxij

## Out of Scope

Anything new.
