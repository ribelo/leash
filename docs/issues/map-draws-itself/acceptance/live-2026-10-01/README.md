# L53 frozen live acceptance — 2026-10-01

**FAIL: no generated draft or installed playbook in any repeatable gate.** All 12 missions independently reached their harmless target, but `done` is not learning acceptance. The nonrepeatable form gate remains **held**, with zero submissions. Machine-readable evidence: [summary.json](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/summary.json>).

## Actual campaign

Each site used its own fresh private service/profile. Four missions were executed sequentially, without seeded playbooks. Every mission exited 0, returned `done`, and passed separate URL/page-text checks. Fourth-mission screenshots were visually checked.

| Site | Calls, missions 1–4 | Reported mission USD, missions 1–4 | Learning result |
| --- | --- | --- | --- |
| Books Mystery | 2, 2, 2, 2 | .000434154, .000434154, .000434154, .000434154 | [FAIL](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/books-r6/result.json>) |
| Google Maps / Eiffel Tower | 12, 7, 7, 6 | .001468054, .001252024, .001245492, .000971374 | [FAIL](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/maps-r3/result.json>) |
| Google Flights / Explore | 8, 5, 3, 7 | .001394190, .001172766, .000629286, .001346478 | [FAIL](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/flights-r3/result.json>) |

All runs report zero procedures, proposals and installations. Nothing proves JEV draft selection, passing draft expectations before installation, or fourth-mission installed use. Maps' lower reported fourth-mission cost cannot be attributed to learning; consent/page state and model choices also changed. Books costs stayed flat; Flights' fourth cost exceeded its second baseline. No learned-cost reduction is accepted.

Observed compiler warnings:

- Books: three rejected compilations: `every navigation needs an explicit the page is <kind> until expectation` — [warning log](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/books-r6/service.redacted.jsonl>).
- Maps: one provider response rejected because `message.content` was null — [warning log](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/maps-r3/service.redacted.jsonl>).
- Flights: one missing-until rejection and one null-content rejection — [warning log](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/flights-r3/service.redacted.jsonl>).

These are observed rejection points, not proof that a single cause explains every missing proposal. No compiler-output repair or product changes were made in this campaign.

## Frozen binary and provenance limits

- Binary: [main.exe](</home/ribelo/projects/ribelo/leash/_build_l53_live/default/packages/leash/bin/main.exe>).
- SHA256: `5800430639fbb9a50c5f758c034036239511d1d0fc01cf2874d9be750efd5fdc`.
- HEAD and service-reported embedded commit: `b2e1b915bbd1fa43fc09e5a1346d0a0245619562`.
- Binary mtime: 2026-10-01 22:00:59 +02:00. Hash rechecked after the campaign and diagnostic; no rebuild occurred.

**Exact dirty build inputs were not captured.** This was an integrated uncommitted tree. Later source changes, including safety fixes by other workers, are not certified by this binary. A later diff/status cannot establish exact inputs; those whole-tree snapshots were removed rather than presented as provenance.

## Isolation, headless proof and cleanup

The harness used private XDG runtime/config/state/cache/data, private downloads/profile and Unix socket, learning `auto`, successes 2, max tries 3, retire-after 5. Models: JEV `typesafe/jev-1.13-20260917`, helper `inception/mercury-2.5`, planner/compiler `openai/gpt-6-luna`; reasoning `max`. Credentials were inherited through `secret-env ai --`, never printed. No real service, user config/profile, or seeded playbook was used.

Each actual campaign saved headless config and normalized main-browser process arguments containing exact `--headless=new` and `--remote-debugging-pipe`. Chrome rewrites argv into one string; renderers inherit pipe flags but are not main browsers. An additional fresh, zero-model session on the identical frozen binary cross-checked `HeadlessChrome/152.0.0.0` through Leash: [userAgent](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/browser-diagnostic/startup-browser-useragent.json>), [main process flags](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/browser-diagnostic/startup-processes.json>). This diagnostic is **not** another acceptance pass or a retroactive UA sample from the three campaigns.

All three actual services exited 0; cleanup recorded no profile processes remaining: [books](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/books-r6/cleanup.json>), [maps](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/maps-r3/cleanup.json>), [flights](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/flights-r3/cleanup.json>). The diagnostic also closed cleanly. Earlier startup-only failures are retained as negative evidence: fixed-budget cold-tab timeout and process-argument normalization/renderer-filter issues. They ran zero missions; do not count them as live target failures or successful learning gates. The form startup attempt likewise ran zero missions.

## Meter limitation

Reported mission costs total **$0.011216280 for 63 metered model calls**. This is **not total campaign spend**: the frozen implementation finalizes its drive-result meter before subsequent learning compilation. Compiler model calls/costs are absent; their Info-level usage rows were filtered by the Warn-only service journal. `cost_unreported=0` means coverage only within that mission meter. Full compiler billing and a learned-versus-on-the-fly cost comparison remain unproven.

## Repeatable harness

Implementation: [live-acceptance-l53.py](</home/ribelo/projects/ribelo/leash/scripts/live-acceptance-l53.py>); wrapper: [live-acceptance-l53](</home/ribelo/projects/ribelo/leash/scripts/live-acceptance-l53>); seven offline checks: [live-acceptance-l53-test.py](</home/ribelo/projects/ribelo/leash/scripts/live-acceptance-l53-test.py>). Run from the Leash repository with a **new** evidence directory:

```sh
python3 scripts/live-acceptance-l53-test.py
bash -n scripts/live-acceptance-l53
secret-env ai -- bash scripts/live-acceptance-l53 books docs/issues/map-draws-itself/acceptance/next-books
secret-env ai -- bash scripts/live-acceptance-l53 maps docs/issues/map-draws-itself/acceptance/next-maps
secret-env ai -- bash scripts/live-acceptance-l53 flights docs/issues/map-draws-itself/acceptance/next-flights
# No missions or paid models:
secret-env ai -- bash scripts/live-acceptance-l53 books docs/issues/map-draws-itself/acceptance/next-diagnostic --startup-only
```

Default executable is the frozen build. Deliberately choose `--leash` for a newly authorized campaign, freeze that artifact, and keep results separate. The form requires explicit `--allow-local-submissions` **after safety fixes and approval**; it was not executed here.

Per mission, preserved evidence includes redacted CLI/operator records, before/after snapshots, page observations and screenshots, and private durable-store copies. Aggregate curves retain raw replies. The [final audit](</home/ribelo/projects/ribelo/leash/docs/issues/map-draws-itself/acceptance/live-2026-10-01/audit.json>) scanned all 370 existing files (8.1 MB), including ignored operator JSONL: zero exact-key leaks, capability identifiers or invalid JSON/JSONL; zero remaining private roots/browser processes. The held-form guard created no service or evidence directory. No product file edits, commits, or pushes were made by this worker.
