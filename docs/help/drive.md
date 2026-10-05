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

The pilot reads the mission, bounded page text (6000 characters), viewport rows (250), previous actions/legs, downloads and procedure candidates. It can issue a navigation leg, quote page text, observe an image, act on a revalidated row or a viewport CSS point, type into the focused control, drag, notify, hand off, finish or fail. Empty or unhelpful rows automatically add a real PNG image input; `observe --image` explicitly requests one and consumes a bounded turn. Images retain measured viewport/scale metadata, not private filesystem paths. Coordinates do not require rows and never become row actions. A leg is one navigation goal in JEV's language; JEV's DONE/BLOCKED returns control to the pilot.

Only pilot done completes the mission. It must carry `result` and `evidence`. Direct actions include click, select, fill, press and scroll; downloads are clicks. Text can describe controls below the viewport, so scrolling may be needed before acting on a row. Payment, checkout confirmation, sending and deletion require explicit authorization in the mission. Never retry an uncertain submission merely because the reply failed.

## Credentials and human handoff

Pass repeatable `--secret NAME=@FILE`, or `--secret NAME=-` for stdin. Files contain the value, not a NAME=value assignment. Only the names reach the pilot; dispatch resolves them when filling. `--secret NAME=VALUE` is not accepted. A credential deliberately written into the mission is accepted, but then it is model input rather than a protected secret reference.

Handoff asks the human through a notification and waits for resume, normally up to 300 seconds. On a headless browser the pilot's handoff ends the mission with error `headless` and its notifications are not sent (hand-tdkk). An unanswered handoff returns `handoff-expired`; `notify` alone is non-blocking. Read `unattended` for these events. Keep notifications enabled. Cancel or dismissal immediately ends the handoff and mission as `canceled-by-operator`, releases the human hold and retains the tab. Do not retry without a new operator instruction. Done resumes; delivery failures are warnings, not cancellation. The default notification does not expire on its own; the handoff deadline controls timeout (pilot-9u3q).

A literal the pilot fills into a password field becomes a secret for the rest of the run. It is redacted from the reply and the trace like a `--secret`. If it is not one of the mission's secrets, it is handed to the operator in `secrets_for_operator` as `generated_password` (pilot-gn4w, pilot-pw7x). Typing into a focused field with `type` is not covered, because it names no row. Do not paste generated secrets into chat.

## Read the outcome, then verify it

Exit 0 means the service answered, not that the mission succeeded. Save the full reply privately and inspect:

- `status`: done, planned (dry-run), failed, limit, deadline, handoff-expired, canceled-by-operator or error.
- `result`: the answer or action outcome, including identifiers. `evidence`: the pilot's supporting URLs, facts or download paths—not independent proof.
- `pilot_turns`, `navigator_steps` and `model_calls`: reasoning and navigation work.
- `model_cost`: total only when all calls are priced; otherwise null. `data.reported_cost` is the known subtotal and `data.cost_unreported` counts missing prices.
- `planner_turns` and `procedures`: decisions, offered/chosen candidates, attempted legs and refusals. `mission_expectations` records explicit completion checks.
- `final`, `trace_path` and `unattended`: last observation, durable record and human-facing events.

Verify the requested outcome separately: reread account amounts, inspect the completed download and its contents, check the actual uploaded link, or compare every requested record with the source. A reported result with an empty requested output file is a failure.

`--out FILE` appends tagged JSONL records: `script-record` lines from validated procedure scripts, and `pilot-record` lines the pilot returns with `done` (pilot-sc9t). A pilot record's values must be text the mission read, and they are written only when the done is accepted. The file never holds the pilot's result text. The pilot uploads with the validated `upload` action, and only files whose absolute paths the mission names verbatim (pilot-h506).

## Limits and preview

`--deadline-s` bounds the whole mission (default `pilot.deadline_s = 600`); `pilot.turns` defaults to 12, and `--max-steps` bounds each navigator leg (maximum 15). `--max-procedures` is a retained compatibility option, not the pilot-turn control. Pilot reasoning defaults to max. These are execution bounds, not output-token budgets.

`--dry-run` returns the first decision and reasoning summary without executing it or writing records. It still makes billable model calls and can allocate a tab. Add repeatable `--expect SENTENCE` for explicit live-page completion checks; see `leash help expectations`.

## Playbooks as memory

Installed and draft procedures are candidates for the pilot, never mandatory routes. After a done mission, learning auto records successful legs/actions as a proposed procedure. A later pilot-selected, verified replay can install it. Read `leash help playbooks` for validation, review/accept and provenance; there is no compile-from-traces phase.

Measure memory with the same mission, recording first/second pilot turns and cost side by side, and checking which procedure was offered, chosen and installed. A faster authenticated session is not evidence of learning. Review/accept installation is not automatic replay-gated installation. Current live measurements found a cheaper turn count but higher cost on Maps, repeated stale-procedure failures on Flights and the portal, and extra downloads during invoice replay (pilot-z1nr, pilot-exx7).

## Durable traces

`trace_path` names the private durable projection; errors use `detail.trace_path`. Inspect with `leash traces list`, `leash traces show FILE` and `leash traces prune --dry-run`. See `leash help traces` for retention. It is not the full reply or page contents. Protected input values are redacted, but the generated-password defect above means a trace is not a blanket secrecy guarantee.
