# Google Maps + Flights: first-failure campaign

**Neither site passed all four gates.** Maps stopped after mission 2 with no generated draft; Flights reached mission 4 but the immediate DOM observation was still loading. No retries, rewording, seeded playbooks, product edits or commit.

Frozen clean product revision 91228d4632e753fb02d3b04515cabf49d386bea3; binary SHA-256 8821a2624bba017c3af2fe25ec706de829b0c252714516fa6571e5c7ce60eee6. One authorized fresh capped replacement build (900 s, 16 GiB), following an unused earlier build discarded with approval. Each site used its own headless Chrome/XDG/profile/socket roots, learning auto, unchanged missions, 420 s browser deadline, 50 steps / 15 procedures. Each mission awaited status.learning.pending=0 before tab closure/next mission, bounded at 900 s.

| Site | Gate | Browser calls / USD | New async calls / USD | Inclusive calls / USD | Outcome |
|---|---:|---:|---:|---:|---|
| maps | 1 | 11 / $0.001335860 | 0 / $0.000000000 | 11 / $0.001335860 | page pass |
| maps | 2 | 7 / $0.001136280 | 0 / $0.000000000 | 7 / $0.001136280 | no draft: stop |
| flights | 1 | 7 / $0.001173438 | 0 / $0.000000000 | 7 / $0.001173438 | pass |
| flights | 2 | 7 / $0.001561434 | 1 / $0.005736175 | 8 / $0.007297609 | pass |
| flights | 3 | 4 / $0.000256242 | 0 / $0.000000000 | 4 / $0.000256242 | pass |
| flights | 4 | 4 / $0.000255738 | 2 / $0.003503975 | 6 / $0.003759713 | early DOM fail; partial later map |

**Total:** 43 calls, **$0.014959142** ($0.005718992 browser + $0.009240150 async learning). All observed provider costs are reported. Drive replies/durable traces remain browser-only; the status meter is **last work, not cumulative**, so the unchanged mission-2 meter was not billed again for mission 3. Actual compile waits: Flights M2 90.07 s, M4 50.04 s; all final pending counts were zero.

## First failures

- **Maps M2:** both screenshots independently show Eiffel Tower and its Paris address. Consent is correctly excluded, but remaining matching paths differ: maps → place-slug versus maps → search-slug → place-slug. Exact path cohorting therefore has fewer than two successes; no compile was attempted, no draft/cost was hidden. Missions 3–4 skipped. [Maps evidence](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/maps/README.md>).
- **Flights M4:** M2 generated an actual two-trace repeatable/replay draft; M3 JEV selected it, verified it, and async replay installed it. M4 selected and verified the installed procedure, whose learned expectation is only “the page is travel-slug.” The immediate DOM has Loading results, no flight prices; the subsequent screenshot has cards/PLN prices and map markers, but gray basemap tiles. Preserve this temporal disagreement rather than claim either complete failure to open Explore or a clean full-goal pass. [Flights evidence](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/flights/README.md>).
- **Inclusive savings independently fail too:** M4 added a new draft from M3+M4 after their path gained flights; $0.003759713 inclusive is above M1 $0.001173438, despite browser-only M4 being $0.000255738. The unchanged harness stopped at the DOM gate before its formal savings comparator.

## Checks

Original harness fixtures 10/10; asynchronous accounting fixtures 8/8. Six final goal screenshots inspected independently; before screenshots removed for compactness. Both services exited 0, private profile processes were gone, loopback servers closed. [Final all-byte leak / artifact / cleanup audit](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/audit.json>) validates credentials, capabilities, private paths, JSON/JSONL, links, hashes and run-only/learning-inclusive accounting.

[Machine summary](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/summary.json>) · [Frozen provenance](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/provenance.json>) · [Isolated adapter](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/harness.py>) · [Adapter fixtures](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/harness-test.py>) · [Build log](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/build.log>)
