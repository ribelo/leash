# L53 operation fixtures

These six traces are minimized copies of the committed Google2/Google3 acceptance evidence under `docs/issues/map-draws-itself/acceptance/`.

| Fixture | Acceptance run | Mission | Original UTC trace |
| --- | --- | --- | --- |
| google2-maps-1.json | live-2026-10-02-google2/maps | 1 | 2026-10-02T17:35:04.333064Z-done.json |
| google2-maps-2.json | live-2026-10-02-google2/maps | 2 | 2026-10-02T17:35:16.306889Z-done.json |
| google3-maps-1.json | live-2026-10-02-google3/maps | 1 | 2026-10-02T19:31:44.292185Z-done.json |
| google3-maps-2.json | live-2026-10-02-google3/maps | 2 | 2026-10-02T19:31:51.492077Z-done.json |
| google3-flights-1.json | live-2026-10-02-google3/flights | 1 | 2026-10-02T19:32:12.979140Z-done.json |
| google3-flights-2.json | live-2026-10-02-google3/flights | 2 | 2026-10-02T19:32:23.014480Z-done.json |

Each source is below `mission-N/durable/state/leash/traces/google.com/`. Missions, raw kind keys, generalized patterns, actions, targets, typed values, action sources, URL/title observations and errors remain intact. Cost, duration, model-call counts and elapsed/probability metadata are cleared; unattended events are empty. Tests add argument bindings derived from retained input text rather than claiming the older captures recorded them.

Maps proves operation agreement despite different complete paths and consent interstitials (map-op01–map-op05). Flights preserves the real Explore wait/click shape and final title, including the one-action capture that must not produce a one-goal learned top-level procedure (map-op06). Pure and scripted protocol tests do not invoke a browser or model and do not discharge map-op07.
