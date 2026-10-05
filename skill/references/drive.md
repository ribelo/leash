# Drive: JEV runs the mission

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

JEV runs the mission (ADR-0015): one decision-model call per step picks the operation and its target over the page's element table; the text helper writes field values; the site playbook's procedures and scripts are offered to it as operations. The stall rule, the step cap (`--max-steps`, default 60) and the deadline bound it.

The planner is optional: `[models] planner_model`; absent means it is never called. It is only consulted, never acts: when JEV answers BLOCKED or its loop stops (it answers a short hint JEV is given as its next goal, or handoff, notify or fail; on a headless browser handoff is neither offered nor accepted); when a procedure's or the mission's expectation fails; and once at the end of a mission that asks for an answer, to read `result` and `evidence` from the final page and judge whether the mission is done. The playbook's `notes` are shown to the planner.

The decision model is `[models] decision_model`: any Decisions-API model id (default `typesafe/jev-1.13-20260917`; `cloudflare/clef` and `cloudflare/clef-flash` speak the same contract). When the model's OpenRouter listing says it accepts images, `[decision]` controls what it is shown. The screenshot goes into the state when the page offers fewer than `image_when_rows_below` actionable elements (default 3; 0 never). The model may choose LOOK when `look = true` (default false), at most once per two steps, and the next state carries the screenshot. With a screenshot in the state it may choose CLICK_AT, whose point is two score answers over `point_levels` bands per axis (default and maximum 10, Clef's limit); a point gets the same safety and consent checks as the rows under it. `leash status` shows `models.decision_modalities` and `decision_tail_read`. Drive metrics name the `decision_model` and count `image_parts`.

Payment, checkout confirmation, sending and deletion require explicit authorization in the mission. Never retry an uncertain submission merely because the reply failed.

## Credentials and human handoff

Pass repeatable `--secret NAME=@FILE`, or `--secret NAME=-` for stdin. Files contain the value, not a NAME=value assignment. Only the names reach a model; the text helper answers with a name and Leash types the value. `--secret NAME=VALUE` is not accepted. A credential deliberately written into the mission is accepted, but then it is model input rather than a protected secret reference.

Handoff asks the human through a notification and waits for resume, normally up to 300 seconds. On a headless browser a handoff ends the mission with error `headless` and its notifications are not sent (hand-tdkk). An unanswered handoff returns `handoff-expired`; `notify` alone is non-blocking. Read `unattended` for these events. Keep notifications enabled. Cancel or dismissal immediately ends the handoff and mission as `canceled-by-operator`, releases the human hold and retains the tab. Do not retry without a new operator instruction. Done resumes; delivery failures are warnings, not cancellation. The default notification does not expire on its own; the handoff deadline controls timeout (pilot-9u3q).


## Read the outcome, then verify it

Exit 0 means the service answered, not that the mission succeeded. Save the full reply privately and inspect:

- `status`: done, planned (dry-run), failed, blocked, limit, deadline, handoff-expired, canceled-by-operator or error.
- `result` and `evidence`: the planner's answer from the final page, when a planner is configured and the mission asks for one; null otherwise. Not independent proof.
- `navigator_steps` and `model_calls`: the work done.
- `model_cost`: total only when all calls are priced; otherwise null. `data.reported_cost` is the known subtotal and `data.cost_unreported` counts missing prices.
- `planner_turns` and `procedures`: each planner consultation (why and what it answered) and each procedure JEV ran. `mission_expectations` records explicit completion checks.
- `final`, `trace_path` and `unattended`: last observation, durable record and human-facing events.

Verify the requested outcome separately: reread account amounts, inspect the completed download and its contents, check the actual uploaded link, or compare every requested record with the source. A reported result with an empty requested output file is a failure.

`--out FILE` appends tagged JSONL `script-record` lines from validated procedure scripts. The file never holds the result text.

## Limits and preview

`--deadline-s` bounds the whole mission (default 600); `--max-steps` bounds JEV's steps (default 60); the planner is consulted at most 6 times. These are execution bounds, not output-token budgets.

`--dry-run` returns JEV's first decision without executing it or writing records. It still makes billable model calls and can allocate a tab. Add repeatable `--expect SENTENCE` for explicit live-page completion checks; see `leash help expectations`.

## Hand-written playbooks

The procedures and scripts of the site's installed playbook are offered to JEV as operations, never mandatory routes. A procedure that failed in a mission is not offered again in it. The playbook's `notes` are shown to the planner. Nothing writes into playbooks (ADR-0014). Read `leash help playbooks` for the format.

## Durable traces

`trace_path` names the private durable projection; errors use `detail.trace_path`. Inspect with `leash traces list`, `leash traces show FILE` and `leash traces prune --dry-run`. See `leash help traces` for retention. It is not the full reply or page contents. Protected input values are redacted, but the generated-password defect above means a trace is not a blanket secrecy guarantee.
