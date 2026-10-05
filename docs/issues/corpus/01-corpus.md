---
status: ready-for-agent
milestone: 14
---

# The corpus: one command, one table

## Problem Statement

Every question left — which decision model, whether to send screenshots, how a mission should be written, whether notes or procedures help, whether truncation bites — is empirical. The ten use cases proved the pilot but were run by hand, one at a time, with results pasted into a document. A comparison across models and variants needs one runner, one corpus, one table.

## User Stories

1. As a maintainer, I want `scripts/corpus` to hold missions as files: id, site, mission in three styles (`loose`: 'download my invoice'; `goal`: mission plus 'result: …' naming the expected outcome; `steps`: numbered steps plus result), an independent checker (a script that fetches the truth without Leash, or a fixture's own record), and tags, so that a mission is data. ^corp-667a
2. As a maintainer, I want twenty public missions needing no account: the use cases U5–U10 as they stand, plus navigation and reading missions on books.toscrape.com, automationexercise.com, Wikipedia, Google Maps, Google Flights, the local canvas and the local fixtures, so that the corpus runs unattended. ^corp-v36x
3. As the operator, I want U1 and U2 in the corpus tagged `account:tauron`, skipped unless `~/.config/leash/use-cases/tauron` exists, so that my cases run when I say and never block the rest. ^corp-o5zb
4. As a maintainer, I want `scripts/corpus run --models jev,clef,clef-flash --styles loose,goal,steps --knowledge none,notes,procedures --image off,b,c` to run the matrix (or any subset) on a private headless service with a temporary XDG config, each cell with its own deadline, so that one command produces every comparison. ^corp-c596
5. As a maintainer, I want one table out — rows per mission × cell: pass/fail by the independent check, pilot turns, navigator steps, model calls, cost, wall time, image parts, truncation flag — as Markdown and JSON under `docs/corpus/<date>/`, so that a run is a document. ^corp-5p13
6. As a maintainer, I want the `notes` and `procedures` knowledge variants to use hand-written playbooks committed under `scripts/corpus/playbooks/<site>/` (written by the coordinating agent for the corpus sites), so that the comparison is of knowledge the operator would actually have. ^corp-zeh2
7. As a maintainer, I want U2 (Tauron invoice) to be the first mission authored in all three styles and both knowledge variants, with the operator running that cell, so that the one failing case is the first one measured. ^corp-337k
8. As a maintainer, I want the first full run recorded and its conclusions written in five lines at the top of the table: which model, whether images help and where, which instruction style, whether notes or procedures help — each with the number that says so, so that the decisions are made by the table. ^corp-fplj
9. As a maintainer, I want the defaults in config and the skill's guidance changed to what the table says, in the same row, so that measurement becomes product. ^corp-ex9w
10. As an agent, I want the skill rewritten to say first: for any browser task with a describable outcome, run `leash drive` with the style the corpus found best; use low-level commands for inspection and for what drive reports it cannot do, so that agents reach for drive first. ^corp-a7md
11. As a maintainer, I want the corpus runner to be a shell/Python script in the repo with no new OCaml, so that it costs nothing to change. ^corp-duu0
12. As a maintainer, I want a corpus cell that fails by a Leash defect (not a model's choice) to be filed as a story with its ID, so that the corpus feeds hardening. ^corp-nzkf

## Out of Scope

Automatic tuning; CI; anything needing the operator at the keyboard except the tagged account cells.
