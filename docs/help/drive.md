# Drive: JEV runs the mission

## Drive first, with a goal and its result

For any task with a describable outcome, run `leash drive MISSION` first. Write the mission as a goal with its result: what to achieve, then what to return, for example `…; result: the invoice's path and number`. In the 2026-10-06 corpus that form passed 82% of cells, against 74% for a loose request and 71% for numbered steps. Name concrete values and limits: which account, which month, which file, whether to stop before purchase. Use the low-level commands (`snap`, `text`, `click`, `script run`, …) to inspect, to verify a result independently, and for what drive reports it cannot do.

```sh
leash drive 'Check whether I owe anything on Tauron; result: each overdue amount with its due date' --url https://moj.tauron.pl/ --secret login=@/private/login --secret password=@/private/password > reply.json
leash drive 'Download my latest invoice as PDF and do not pay anything; result: the file path and the invoice number' --tab TAB > reply.json
```

Supply `--url`, an existing `--tab`, or exactly one explicit http(s) URL in the mission. A populated supplied tab is not replaced by the start URL. Use `leash new URL` and keep its handle before drive when you will need independent page reads afterward: without `--tab`, drive normally closes its temporary tab at completion. A handoff keeps it open. `final` is a snapshot, not a live-tab guarantee.

Wait for the mission's reply before acting or reading on its tab. Other tabs can be used meanwhile. The service, not the client shell, needs the OpenRouter key. On a provider error inspect `detail.code` and the partial trace before deciding whether a retry is safe.

## Who decides

JEV runs the mission (ADR-0015, ADR-0016): one decision-model call per step picks the operation and its target over the page's element table, and the text helper writes field values. The stall rule (three identical actions without a page change) and the step cap (`--max-steps`, default 256 per stint) end a stint. JEV sees every row, password fields included, and types a `--secret` by its name.

The planner (`[models] planner_model`, optional; absent means a stop ends the mission `blocked`) takes the page over from JEV when JEV answers BLOCKED, stalls or reaches its step cap. It sees the mission, what JEV and it did so far, the page, and a screenshot when it asks for one. It may act on the page (click, fill, select, press, scroll, upload a file the mission names, type, click at a point), read text, notify, hand off (only on a headed browser), finish with `result`, `evidence` and records for `--out`, or fail. It hands the page back to JEV with a goal string, and JEV then drives toward that goal. When JEV reports DONE on a mission that asks for an answer, the planner gives the answer from the final page or takes over.

The decision model is `[models] decision_model`: any Decisions-API model id (default `typesafe/jev-1.13-20260917`; `cloudflare/clef` and `cloudflare/clef-flash` speak the same contract). When the model's OpenRouter listing says it accepts images, `[decision]` controls what it is shown. The screenshot goes into the state when the page offers fewer than `image_when_rows_below` actionable elements (default 3; 0 never). The model may choose LOOK when `look = true` (default false), at most once per two steps, and the next state carries the screenshot. With a screenshot in the state it may choose CLICK_AT, whose point is two score answers over `point_levels` bands per axis (default and maximum 10, Clef's limit); a point gets the same safety and consent checks as the rows under it. `leash status` shows `models.decision_modalities` and `decision_tail_read`. Drive metrics name the `decision_model` and count `image_parts`.

JEV can attach a file to a file input (UPLOAD) only when the mission names its absolute path verbatim, and only that file. Payment, checkout confirmation, sending and deletion require explicit authorization in the mission. Never retry an uncertain submission merely because the reply failed.

## Credentials and human handoff

Pass repeatable `--secret NAME=@FILE`, or `--secret NAME=-` for stdin. Files contain the value, not a NAME=value assignment. Only the names reach a model; the text helper or the planner answers with a name and Leash types the value. `--secret NAME=VALUE` is not accepted.

Handoff asks the human through a notification and waits for resume, normally up to 300 seconds. On a headless browser the planner is not offered handoff and its notifications are not sent (hand-tdkk, revert-r9ka). An unanswered handoff returns `handoff-expired`; `notify` alone is non-blocking. Read `unattended` for these events. Cancel or dismissal immediately ends the handoff and mission as `canceled-by-operator`, releases the human hold and keeps the tab. Do not retry without a new operator instruction.

## Read the outcome, then verify it

Exit 0 means the service answered, not that the mission succeeded. Save the full reply and inspect:

- `status`: done, planned (dry-run), failed, blocked, deadline, handoff-expired, canceled-by-operator or error.
- `result` and `evidence`: the planner's answer, when a planner is configured and the mission asks for one; null otherwise. Not independent proof.
- `navigator_steps` and `model_calls`: the work done.
- `model_cost`: total only when all calls are priced; otherwise null. `data.reported_cost` is the known subtotal and `data.cost_unreported` counts missing prices.
- `planner_turns`: each planner turn, why it was asked and what it did.
- `final`, `trace_path` and `unattended`: last observation, durable record and human-facing events.

Verify the requested outcome separately: reread account amounts, inspect the completed download and its contents, check the actual uploaded link, or compare every requested record with the source.

`--out FILE` appends tagged JSONL: `planner-record` lines the planner returned with done, and the terminal `operator-state` line. The file never holds the result text. For bulk collection from one page, a script of your own is often simpler: `leash script run TAB FILE --out FILE`.

## Limits and preview

`--deadline-s` bounds the whole mission (default 600) and is the only bound on the planner; `--max-steps` bounds each JEV stint (default 256). These are execution bounds, not output-token budgets.

`--dry-run` returns JEV's first decision without executing it or writing records. It still makes billable model calls and can allocate a tab.

## Durable traces

`trace_path` names the private durable projection; errors use `detail.trace_path`. Inspect with `leash traces list`, `leash traces show FILE` and `leash traces prune --dry-run`. See `leash help traces` for retention. It is not the full reply or page contents.
