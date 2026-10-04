# Drive: missions with the pilot

## State the result and limits

Use `leash drive MISSION` for an outcome, not a list of clicks. Name the answer or action wanted, its concrete values and any limits: which account, which month, which file, whether to stop before purchase. Playbooks are optional.

```sh
leash drive 'Check whether I owe anything on Tauron and tell me what is overdue' --url https://moj.tauron.pl/ --secret login=@/private/login --secret password=@/private/password > reply.json
leash drive 'Find a cafe near the Eiffel Tower with rating over 4 and give me its name and address' --url https://www.google.com/maps > reply.json
leash drive 'Download my latest invoice as PDF; do not pay anything' --tab TAB > reply.json
```

Supply `--url`, an existing `--tab`, or exactly one explicit http(s) URL in the mission. A populated supplied tab is not replaced by the start URL. Use `leash new URL` and retain its handle before drive when you will need independent page reads afterward: without `--tab`, drive normally closes its temporary tab at completion. A handoff keeps it open. `final` is a snapshot, not a live-tab guarantee.

Wait for the mission's reply before acting or reading on its tab. Other tabs can be used meanwhile. The service, not the client shell, needs the OpenRouter key. On a provider error inspect `detail.code` and the partial trace before deciding whether a retry is safe.

## Who decides

The pilot reads the mission, bounded page text (6000 characters), viewport rows (250), previous actions/legs, downloads and procedure candidates. It can issue a navigation leg, quote page text, act on a current row, notify, hand off, finish or fail. A leg is one navigation goal in JEV's language; JEV's DONE/BLOCKED returns control to the pilot.

Only pilot done completes the mission. It must carry `result` and `evidence`. Direct actions include click, select, fill, press and scroll; downloads are clicks. Text can describe controls below the viewport, so scrolling may be needed before acting on a row. Payment, checkout confirmation, sending and deletion require explicit authorization in the mission. Never retry an uncertain submission merely because the reply failed.

## Credentials and human handoff

Pass repeatable `--secret NAME=@FILE`, or `--secret NAME=-` for stdin. Files contain the value, not a NAME=value assignment. Only the names reach the pilot; dispatch resolves them when filling. `--secret NAME=VALUE` is not accepted. A credential deliberately written into the mission is accepted, but then it is model input rather than a protected secret reference.

Handoff asks the human through a notification and waits for resume, normally up to 300 seconds. An unanswered handoff returns `handoff-expired`; `notify` alone is non-blocking. Read `unattended` for these events. Keep notifications enabled. Known defect: dismissing a notification is not yet distinguished from timeout (pilot-9u3q); do not describe an operator's explicit cancellation as inaction.

Generated passwords are intended for `secrets_for_operator`, but the U7 gate found missing delivery and cleartext leakage into reply turns and durable traces (pilot-gn4w, pilot-pw7x). Treat such artifacts as sensitive; do not claim this path is safe or paste generated secrets into chat.

## Read the outcome, then verify it

Exit 0 means the service answered, not that the mission succeeded. Save the full reply privately and inspect:

- `status`: done, planned (dry-run), failed, limit, deadline, handoff-expired or error.
- `result`: the answer or action outcome, including identifiers. `evidence`: the pilot's supporting URLs, facts or download paths—not independent proof.
- `pilot_turns`, `navigator_steps` and `model_calls`: reasoning and navigation work.
- `model_cost`: total only when all calls are priced; otherwise null. `data.reported_cost` is the known subtotal and `data.cost_unreported` counts missing prices.
- `planner_turns` and `procedures`: decisions, offered/chosen candidates, attempted legs and refusals. `mission_expectations` records explicit completion checks.
- `final`, `trace_path` and `unattended`: last observation, durable record and human-facing events.

Verify the requested outcome separately: reread account amounts, inspect the completed download and its contents, check the actual uploaded link, or compare every requested record with the source. A reported result with an empty requested output file is a failure.

`--out FILE` appends tagged JSONL records emitted by validated procedure scripts. It does not serialize the pilot's result text. U8 currently returns collection text while leaving the file empty (pilot-sc9t); U9 lacks a pilot upload action (pilot-h506). These are known unsupported paths, not successful missions.

## Limits and preview

`--deadline-s` bounds the whole mission (default `pilot.deadline_s = 600`); `pilot.turns` defaults to 12, and `--max-steps` bounds each navigator leg (maximum 15). `--max-procedures` is a retained compatibility option, not the pilot-turn control. Pilot reasoning defaults to max. These are execution bounds, not output-token budgets.

`--dry-run` returns the first decision and reasoning summary without executing it or writing records. It still makes billable model calls and can allocate a tab. Add repeatable `--expect SENTENCE` for explicit live-page completion checks; see `leash help expectations`.

## Playbooks as memory

Installed and draft procedures are candidates for the pilot, never mandatory routes. After a done mission, learning auto records successful legs/actions as a proposed procedure. A later pilot-selected, verified replay can install it. Read `leash help playbooks` for validation, review/accept and provenance; there is no compile-from-traces phase.

Measure memory with the same mission, recording first/second pilot turns and cost side by side, and checking which procedure was offered, chosen and installed. A faster authenticated session is not evidence of learning. Review/accept installation is not automatic replay-gated installation. Current live measurements found a cheaper turn count but higher cost on Maps, repeated stale-procedure failures on Flights and the portal, and extra downloads during invoice replay (pilot-z1nr, pilot-exx7).

## Durable traces

`trace_path` names the private durable projection; errors use `detail.trace_path`. Inspect with `leash traces list`, `leash traces show FILE` and `leash traces prune --dry-run`. See `leash help traces` for retention. It is not the full reply or page contents. Protected input values are redacted, but the generated-password defect above means a trace is not a blanket secrecy guarantee.
