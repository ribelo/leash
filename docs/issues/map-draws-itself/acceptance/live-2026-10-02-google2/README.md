# Google live learning gates — 9a3b553

**Failed:** Maps stopped after mission 2 at draft compilation; Flights stopped after mission 1. Later missions were not run. No campaign retry or mission rewording.

One fresh capped build from clean HEAD `9a3b553ec284568fc142e6d66f74d03077ac7813`; [binary](<../../../../../_build_l53_google2/default/packages/leash/bin/main.exe>) SHA-256 `7b53eff0e82e75f9052c57b3f519b49fd3ad214cdcc24b98083807177f811f05`. Build succeeded; unchanged offline harness tests: 10 passed. See [provenance](<provenance.json>).

## First failed gates

**Maps:** both missions reached Eiffel Tower, with **Av. Gustave Eiffel, 75007 Paris, France** visible in the [first](<maps/mission-1/after/page.png>) and [second](<maps/mission-2/after/page.png>) final screenshots. Both traces now match `maps → search-slug → place-slug`, and one learning call occurred: the path fix cleared the earlier eligibility obstruction. The [service diagnostic](<maps/service.redacted.jsonl>) records `finish_reason=length`, `content_kind=null-or-missing`, output cap 4,096, 4,096 completion tokens, all 4,096 reasoning tokens. The compile was dropped without a procedure body. [Persisted compile state](<maps/checkpoint-2/state/leash/learning.json>) and [status](<maps/checkpoint-2/status.json>) confirm the attempt and **zero drafts/installations**. This is token-budget exhaustion, not another path mismatch. Missing draft provenance/repeatable classification checks are downstream consequences. Missions 3–4 skipped.

**Flights:** [drive evidence](<flights/mission-1/drive.json#L563-L746>) records three executed clicks (steps 3–5) on row 21, **button “Explore destinations”**, each with `page_changed=false`. The unchanged-page guard correctly returned `blocked`; the CLI reply itself exited 0. [Final snapshot](<flights/mission-1/after/snapshot.json>) and [screenshot](<flights/mission-1/after/page.png>) show the Flights landing/search page, not the required visible Explore map. The earlier covered-click error did **not** recur; the [read-only observer](<collect-covered.py>) did not fire. Dispatch coordinates/quads and atomic hit-test results are absent for these executed clicks, so the specific input/site-handler failure remains unproved; do not attribute it to the transparent-layer fix from this evidence. Missions 2–4 skipped.

## Costs, including learning

| Gate / mission | Calls | USD | Learning calls / USD |
| --- | ---: | ---: | ---: |
| Maps 1 | 14 | 0.001722856 | 0 / 0 |
| Maps 2 | 7 | 0.003329233 | 1 / 0.002263925 |
| **Maps total** | **21** | **0.005052089** | **1 / 0.002263925** |
| **Flights 1 / total** | **5** | **0.000728028** | **0 / 0** |
| **All runs** | **26** | **0.005780117** | **1 / 0.002263925** |

All costs reported. Full per-mission accounting: [Maps curve](<maps/cost-curve.json>), [Flights curve](<flights/cost-curve.json>); machine result: [summary](<summary.json>).

## Isolation and audit

Separate private XDG roots/headless profiles; learning `auto`, successes 2, no seeded books. Same harness and exact four-mission contracts; each site stopped at its first failed gate. No user Chrome, real configuration, service-unit change, product edit, or commit by this worker. The parent edited source only after the campaigns; those changes were preserved, and the frozen tested binary/harness hashes still match provenance. Both private services exited 0; no owned Chrome/processes or random runtime roots remained. Pre-existing archive roots preserved.

[Audit](<audit.json>) records exact-key/capability/private-path scans across every retained file, JSON/JSONL validation, links, costs, provenance and process/root cleanup. Three final screenshots retained; redundant before screenshots removed. Raw redacted checkpoints/traces, gate results and usage remain under [Maps result](<maps/result.json>) and [Flights result](<flights/result.json>).
