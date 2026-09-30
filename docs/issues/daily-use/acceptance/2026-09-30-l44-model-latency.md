# L44 model latency investigation — 2026-09-30

Stories: daily-9ggi, daily-6pde.

## Isolation and method

No installed binary, service or Chrome was used. Built committed HEAD in a private
/tmp checkout with only model timeout configuration/wiring overlaid (and the old
protocol error code retained for an exact comparison). Each scenario launched its
own headless Chrome, profile, runtime socket and empty playbook/config/state roots.
A loopback HTTP relay forwarded only configured model endpoints to OpenRouter,
recording model id, route, response status and elapsed seconds; credentials came
from secret-env ai and were neither printed nor recorded. The relay continued
reading abandoned requests to measure healthy replies the old cap discarded.
All private services exited 0 on SIGTERM.

Command: create a tab at
https://books.toscrape.com/catalogue/category/books/travel_2/index.html, then:

    drive 'Collect every book title and price on this Travel category page' --tab TAB
      --expect 'the page shows the Travel category' --dry-run --deadline-s 150
      --max-procedures 2 --owner l44d

## Observations

| Scenario | Model call | Provider response latency | Result |
| --- | --- | ---: | --- |
| First reproduction, original 10 s attempt cap | JEV | 0.580 s | HTTP 200 |
| First reproduction | Luna attempt 1 | 12.159 s | HTTP 200, already abandoned |
| First reproduction | complete drive | 25.792 s | original model-unavailable / detail.code timeout |
| Matched comparison, original cap | JEV | 0.792 s | HTTP 200 |
| Matched comparison | Luna attempt 1 | 19.069 s | HTTP 200, already abandoned |
| Matched comparison | Luna attempt 2 | 18.242 s | HTTP 200, already abandoned |
| Matched comparison | complete drive | 25.968 s | original model-unavailable / detail.code timeout |
| Raised cap (120 s experiment) | Luna initial answer | 12.003 s | HTTP 200, accepted by transport |
| Raised cap | Luna formatting/schema correction | 8.942 s | HTTP 200, accepted by transport |

For the raised-cap comparison only, the relay replayed the preceding JEV response
to hold the operator's DONE choice fixed. Both Luna calls were real. An earlier
all-real raised-cap run chose SCROLL_DOWN instead, so dry-run stopped before Luna;
that is not evidence of a timeout repair.

The raised-cap historical run ended after 26.024 s with **invalid-response**, not
timeout: “the answer is procedure but the run has no playbook to run it in”. It did
not collect records. This independently confirms the no-playbook planner bug fixed
by slice B; changing a timeout cannot make an unsupported collection workflow work.

## Cause and repair

This was **Luna/planner**, not JEV or the text helper. The failing text expectation
followed JEV DONE and sent the historical fallback into the planner. All model
clients inherited Ox's 10-second *per-attempt* cap, despite the much larger caller
mission budget. Ox tried twice; both healthy Luna replies arrived after their
attempt had been abandoned. The roughly 26-second total includes the text-check
wait plus JEV and two planner attempts. No authentication or provider outage was
observed.

Leash now configures each model-kind attempt budget independently: JEV 10 s,
text helper 10 s (unchanged), planner 60 s (over three times the observed maximum
19.069 s, while retaining the caller's total deadline). The 120 s experiment
established the response latency; it is not the shipped default. Ox's bounded
two-attempt policy remains. Failures identify detail.model_kind; timeouts become
retryable model-timeout (75), not key/config errors. Text-helper and planner
corrections consume the remaining original budget instead of receiving a fresh
one. Local delayed-provider tests prove independent budgets, bounded retries,
no authentication retry and correction budget sharing.

The added config fields exposed a separate upstream minimal-yojson-deriver defect:
default branches duplicated the entire remaining decode continuation. Generated
config code grew to 6.0 MiB and native compilation reached about 94 GiB RAM. A
sequential models codec keeps the same schema/defaults/redaction/unknown-key rules,
reduces generated config to 211 KiB before later skill-config additions, and passed
an isolated native compile with an 8 GiB virtual-memory cap. The lead owns upstream
repair and removal of this temporary codec workaround.
