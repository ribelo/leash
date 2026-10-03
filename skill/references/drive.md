# Drive

## Durable traces

Every public drive outcome is saved by default. `trace_path` names its existing
private JSON file; errors return `detail.trace_path`. This is a safe typed
projection, not the full live reply: no page text, handles, raw state, or records;
password text is `[password]`. Inspect offline with `leash traces list`,
`leash traces show FILE`, and `leash traces prune --dry-run`.
`leash help traces` describes the schema, switch, and retention defaults
(20 newest traces per site, 30 days).
A storage failure is logged without changing the drive outcome.

`leash drive MISSION` is the one mission command. It runs on one tab toward one goal until `done`, `blocked`, a cap, a deadline, or an error, and returns the trace and a final snapshot. Only pilot done completes the mission; navigator DONE/BLOCKED always returns to the pilot. There is no `run` command, and the call is not `drive TAB GOAL`. Include the concrete result and any needed values in the mission. Do not delegate a broader action than the user authorized.

```sh
leash drive 'Open Travel and return the visible titles and prices' --url https://books.toscrape.com/ --out /tmp/travel-state.jsonl
leash drive 'Complete this page search and open the matching result' --tab TAB --max-steps 15 --deadline-s 300
```

The connection stays open until the mission returns. A long mission can run in the background while you work on other tabs. Do not start another action or read on that tab while it is working.

Models are OpenRouter. The service needs `OPENROUTER_API_KEY` in its own environment, or `models.api_key` in the configuration. The key is the operator's. Setting a variable in the client shell does not update an already running service. A missing key or a provider failure is `model-unavailable`; read `detail.code` and the partial trace before any retry.

## Pilot decisions and safeguards

The pilot owns the mission from its first turn. It receives the mission, at most 6000 characters of page text, 250 snapshot rows, the page kind, prior navigation legs and learning candidates. A leg is one navigation goal in JEV's language. The operator gets at most 15 steps; both DONE and BLOCKED return to the pilot rather than completing the mission.

Answers are leg, read, act, handoff, notify, done and fail. Read quotes page text. Act uses one current snapshot row: click, select, fill or press; a download is a click. Payment, checkout confirmation, message sending and deletion require a mission that names the action. A refusal is recorded and the pilot continues. Notify never ends a mission. Handoff waits for the human and returns control to the pilot on resume.

Only pilot done completes the mission, with a concrete result and evidence. Explicit mission expectations still run through the existing live-page checkers. A model result is not independent proof of a remote mutation. Keep input evidence; never automatically rerun an uncertain payment or submission.

Use repeated `--secret NAME=@FILE` or `--secret NAME=-` to read a value from a file or stdin. Models receive only names. Fill resolves a name at dispatch; values are redacted from traces and replies. Generated values appear only in `secrets_for_operator`, never page reasoning or traces. Ordinary credentials already in the mission are accepted without a credential warning or preflight.

## Options

| Option | Meaning |
| --- | --- |
| `--url URL` | Explicit http or https start, no userinfo. Opens a drive-owned tab. Does not replace an already populated `--tab`. A bad URL is `usage` and names a correct example. |
| `--tab TAB` | Reuse this tab and leave it open. Without it, Leash opens a temporary tab and closes it when the mission ends, including errors. A human handoff keeps it open. `final` is the last snapshot, not a promise that its tab still exists. |
| `--max-steps N` | Navigation leg cap, at most 15 executed steps. Must be positive. |
| `--max-procedures N` | Playbook-lane procedure cap, default 40. Not the operator action cap. |
| `--deadline-s S` | Whole mission budget, default `pilot.deadline_s = 600` seconds. Must be positive when present. |
| `--expect SENTENCE` | Repeatable mission expectation the DONE guard verifies, with or without a playbook. |
| `--out FILE` | Append tagged JSONL. Use a deliberate writable path, not an existing valuable file. |
| `--dry-run` | Observe and decide once. No navigation, input, text helper, or `--out` write. Still makes billable model calls and may allocate a blank tab. |

Pass `--expect` when a concrete live-page condition must be checked. Code-checked sentences are in `leash help expectations`. Defaults are `pilot.turns = 12`, `pilot.deadline_s = 600`, with pilot reasoning set to `max`.

A drive reply is large. Write it to a file and read the fields below. Do not paste the whole reply into the chat.

## Prefer drive for goals

Prefer drive for mission-level work and manual commands for inspection. Learning defaults to `auto`; when enabled, successful navigation legs can become drafts and verified replay can promote them. Installed and draft procedures are candidates for the pilot, not choices made by JEV. See `leash help playbooks` for learning configuration and provenance.

With `--tab HANDLE`, the supplied tab stays open. Otherwise drive closes its owned tab on ordinary endings. A human handoff keeps it open. Handoff expiry returns `handoff-expired`; normal idle cleanup applies later. Notifications and handoffs are recorded under `unattended`.

## Candidates and navigation

Playbooks are optional. The pilot always runs, with or without installed books. It can select an offered candidate by returning its slug as the leg goal, or ask for a fresh navigation goal. Installed arguments, goals, scripts, nested uses, expectations and bounded repeats remain executable. Missing or failed candidate steps return a blocked leg to the pilot.

Pass `--url`, use an existing `--tab`, or include exactly one explicit http(s) URL in the mission. The pilot does not invent a start URL or navigate a populated tab away before its first decision.

## Reading a trace

Exit 0 means the service answered, not that the mission succeeded. Read:

- `status`: done, planned (dry-run), failed, limit, deadline, handoff-expired or error.
- `result` and `evidence`: the pilot's final answer and supporting facts.
- `pilot_turns` and `navigator_steps`: mission turns and executed operator steps.
- `reasoning_summary`: the first decision's brief explanation in a dry-run.
- `planner_turns`: the pilot decisions, direct row actions and refusals (the retained trace field name).
- `operator_steps`: navigation actions, with their input evidence.
- `mission_expectations`: the live-page DONE guard and verdicts.
- `collected`: validated script records streamed to `--out`.
- `secrets_for_operator`: generated secrets returned only to the caller; do not paste these into chat.
- `final` and `trace_path`: last snapshot and durable safe trace projection.

A dry-run returns the first decision and reasoning summary, without navigation, action, typing or output writes. It still makes a billable model call.
