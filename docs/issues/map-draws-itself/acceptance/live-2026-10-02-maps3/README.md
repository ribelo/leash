# Google Maps learning acceptance — 2026-10-02 (Maps3)

**Failed after mission 2.** Both browser goals independently passed; the uncapped max-reasoning learning request timed out under the unchanged **60-second planner deadline**. No draft/install, so missions 3–4 were skipped. The first harness failure is incomplete learning-inclusive provider cost; draft/provenance/repeatability failures follow at the same checkpoint. No retries or post-closure browser investigation. Flights was not run.

| Gate | Independent page goal | Calls (browser + learning) | Browser-run USD | Learning-inclusive USD |
| --- | --- | ---: | ---: | ---: |
| Mission 1 | Eiffel Tower / Paris verified | 13 + 0 | $0.001693742 | $0.001693742 |
| Mission 2 | Eiffel Tower / Paris verified; learning timed out | 10 + 1 | $0.001690678 | **Unknown** |
| Missions 3–4 | Skipped at failed gate | — | — | — |

**24 calls:** 20 operator, 3 text-helper, 1 learning. Known browser-run component **$0.003384420**; learning cost and complete total are unknown, not zero. Mission-2 reply and durable trace both record **11 calls and null cost**, confirming learning-inclusive persistence for this failed call (L55).

## Supported diagnosis

The mission-2 successful trace is stamped `18:00:39.625411Z`; the warning `learning: learning compile dropped: timed out` is stamped `18:01:39.627Z` (~60 seconds later). `Models.learning` passes configured `planner_timeout`; its default is 60 seconds and the unchanged harness does not override it. The request no longer sets an output-token cap and uses `openai/gpt-6-luna`, reasoning `max`. One compiler request was attempted, so path eligibility was reached. Provider-internal work, eventual output and charged cost are not proved by retained evidence.

Final screenshots personally reviewed: both show Eiffel Tower, `Av. Gustave Eiffel, 75007 Paris, France`, and Champ de Mars. [Mission 1 screenshot](<maps/mission-1/after/page.png>) · [Mission 2 screenshot](<maps/mission-2/after/page.png>).

## Provenance and evidence

One fresh capped `@install` build in `_build_l53_maps3`; clean HEAD `f983c07964557bf09a211a5834dace240b4e05b1` (descendant of requested `279bbf3`). Binary SHA-256 `14e87b671d4db7f04711e81f4699ba06735e3f6138d594669caf1b060b1b9c4f`. Build exit 0; 10 offline harness tests passed. Same four mission texts, learning `auto`, successes 2, zero seeded playbooks, private headless Chrome/XDG/profile/socket. No product edits, commits or real profile/service changes.

[Provenance](<provenance.json>) · [Build log](<build.log>) · [Offline tests](<offline-tests.log>) · [Summary](<summary.json>) · [Audit](<audit.json>) · [Per-gate raw costs](<maps/cost-curve.json>) · [Harness result](<maps/result.json>) · [Learning warning](<maps/service.redacted.jsonl>) · [Checkpoint status](<maps/checkpoint-2/status.json>) · [Mission 2 drive](<maps/mission-2/drive.json>).

Owned service closed cleanly; no owned profile processes remain and loopback server closed. Two redundant initial screenshots removed; two final screenshots retained. Audit scans all bytes (including PNG), exact authorized key, API-key prefixes, capability tokens/fields and concrete private runtime/real Chrome profile paths, validates JSON/JSONL/links and reconciles costs including the explicitly unknown learning charge. Frozen binary/harness remain the provenance authority; parent checkout changes after campaigns are preserved and recorded separately by the audit.
