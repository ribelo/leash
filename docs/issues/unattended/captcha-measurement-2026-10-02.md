# reCAPTCHA live measurement — 2026-10-02

L55 / notif-646o. **Pass rate: 0/5 (0%).** All five runs detected a challenge, spent one planner turn, attempted no row actions, handed off as CAPTCHA, then returned blocked after the unanswered 30-second handoff. Neither the checkbox nor the demo form passed.

## Method

- Detached worktree at HEAD `a078217981f547dbe2475530866c421a6b5a2972`; no product changes or commit. Trials recorded on 2026-10-02, 20:04–20:07 UTC (22:04–22:07 Europe/Warsaw).
- Read [repository guidance](<../../../AGENTS.md>), [unattended stories 5–9](<01-unattended.md>), the Leash skill and [L53 private launch harness](<../../../scripts/live-acceptance-l53.py>). Reused its isolated XDG, capability redaction, CLI capture and private-process cleanup pattern.
- Exactly one build, exit 0 (about 8 seconds):

```sh
timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_captcha bash -c 'ulimit -v 16777216; exec dune build @install'
```

- One private Leash service with fresh temporary XDG runtime/config/state/cache/data/downloads and Chrome profile. Confirmed Chrome was headless and used the debugging pipe. Each trial opened a fresh blank agent tab; `drive` navigated it via `--url https://www.google.com/recaptcha/api2/demo`. Tabs were closed after measurement; profile was shared across these five sequential runs, not reset each time.
- Credential injected only through `secret-env ai --`, never displayed or put in config. JEV `typesafe/jev-1.13-20260917`; planner `openai/gpt-6-luna`, reasoning `max`.
- `challenges.attempt=true`, `challenges.turns=2`, `learning.planner_actions=5`; `learning.mode="off"` to avoid cross-run playbook learning. `handoff.timeout_s=30`; focus and notification commands disabled so no desktop disturbance. No human response.
- Mission: “On this page, complete the 'I'm not a robot' check and submit the Google reCAPTCHA demo form exactly once; report the result text. Only ordinary visible row actions are permitted. No solver services, coordinates, JavaScript, or audio workaround. This public demo form submission is authorized; do not submit anything else or retry an uncertain submission.”
- `--expect 'the page shows Verification Success' --deadline-s 240 --max-steps 20`. No solver, coordinate action, script, direct JS, manual checkbox click, form submit or mission retry occurred. Normal internal product snapshot collection was unchanged.

## Results

| Run | Challenge detected | Planner turns / cap | Row actions from trace | Outcome | Handoff expiry | Cost (USD) | Drive wall time (s) |
| --- | --- | --- | --- | --- | --- | ---: | ---: |
| 1 | Yes | 1 / 2 | None (0) | Handed off → blocked | 30.000 s; open, human flag cleared | $0.0004763 | 38.144 |
| 2 | Yes | 1 / 2 | None (0) | Handed off → blocked | 30.000 s; open, human flag cleared | $0.0003472 | 35.144 |
| 3 | Yes | 1 / 2 | None (0) | Handed off → blocked | 30.000 s; open, human flag cleared | $0.0005196 | 38.608 |
| 4 | Yes | 1 / 2 | None (0) | Handed off → blocked | 30.000 s; open, human flag cleared | $0.0003273 | 36.158 |
| 5 | Yes | 1 / 2 | None (0) | Handed off → blocked | 30.000 s; open, human flag cleared | $0.0003671 | 41.753 |

Total reported model cost **$0.0020375**, five calls (all planner); `cost_unreported=0` in every reply. Summed drive wall time **189.807 s**, including 150 s of handoff waiting, excluding service startup and post-run inspection. All drive commands exited 0: protocol success is not mission success.

## What stopped it

Each final AX snapshot was settled, untruncated, and had seven rows: three disabled text fields, a color paragraph, two disabled radios, and Submit. **No checkbox row was exposed.** Durable `steps=[]`, reply `operator_steps=[]`, and planner `steps=[]` confirm no checkbox or submit action. `mission_expectations=[]`: the success expectation was supplied but completion was never reached or accepted.

After expiry, every run emitted “the agent gave up waiting; the tab is still open”; a post-run tab listing independently confirmed the agent demo tab remained open with `with_human=false`. The measurement then closed it.

A separate visual-only diagnostic in another private headless profile confirmed that the demo visibly rendered an unchecked “I'm not a robot” reCAPTCHA v2 widget, while `snap` still exposed the same seven rows and no checkbox. It used no drive/model call or row action and is **not** a sixth trial. Per-trial screenshot commands used an invalid `--out` flag and failed locally after the drive; therefore there are no per-trial pixel captures. The separate diagnostic used the correct positional screenshot path. No image challenge was observed in that diagnostic; the five traces never reached the initial checkbox click, so image-challenge escalation was not tested.

This is consistent with the current [frame observation boundary](<../../../packages/leash/snapshot_source.ml#L558-L627>): frame documents are not inspected, and frame placeholder rows are emitted only for a different origin. It is evidence of a missing actionable checkbox row, **not** evidence that Luna failed to solve an available image puzzle.

**Limitations:** headless Chrome can be challenged more aggressively than headed Chrome. These five runs share a fresh profile/network and are not independent samples of headed or warmed-profile behavior. Since no checkbox was clicked, Google's later challenge difficulty and any headed pass rate remain unknown.

## Per-run trace excerpts

Extracted from each mission reply and checked against its durable trace. Common to all: challenge origin `https://www.google.com`, attempt true, one turn, unattended outcomes `handoff → expired`; zero durable action steps.

### Run 1

```json
{"planner":{"n":1,"trigger":"challenge","answer":"handoff","steps":[],"reason":"The visible snapshot has no reCAPTCHA checkbox or verification control—only disabled form fields and a Submit button. I can’t complete the check or safely submit using the available visible-row actions."},"trace_steps":[],"operator_steps":[],"handoff":{"kind":"handoff","reason":"captcha","elapsed_ms":30000,"outcome":"expired"},"status":"blocked","model_calls_by_kind":{"planner":1}}
```

### Run 2

```json
{"planner":{"n":1,"trigger":"challenge","answer":"handoff","steps":[],"reason":"The visible page snapshot contains no “I’m not a robot” checkbox or other CAPTCHA control, so I can’t complete the check using permitted visible-row actions. I have not submitted the form."},"trace_steps":[],"operator_steps":[],"handoff":{"kind":"handoff","reason":"captcha","elapsed_ms":30000,"outcome":"expired"},"status":"blocked","model_calls_by_kind":{"planner":1}}
```

### Run 3

```json
{"planner":{"n":1,"trigger":"challenge","answer":"handoff","steps":[],"reason":"The current snapshot does not expose an “I’m not a robot” checkbox or any other CAPTCHA control. I have not clicked Submit; a human must make the visible check available before the form can be submitted exactly once."},"trace_steps":[],"operator_steps":[],"handoff":{"kind":"handoff","reason":"captcha","elapsed_ms":30000,"outcome":"expired"},"status":"blocked","model_calls_by_kind":{"planner":1}}
```

### Run 4

```json
{"planner":{"n":1,"trigger":"challenge","answer":"handoff","steps":[],"reason":"The reCAPTCHA checkbox is not exposed as a visible row in the current snapshot, so I cannot complete the check using permitted actions. I did not submit the form."},"trace_steps":[],"operator_steps":[],"handoff":{"kind":"handoff","reason":"captcha","elapsed_ms":30000,"outcome":"expired"},"status":"blocked","model_calls_by_kind":{"planner":1}}
```

### Run 5

```json
{"planner":{"n":1,"trigger":"challenge","answer":"handoff","steps":[],"reason":"The current snapshot has no visible “I’m not a robot” checkbox row, so I can’t complete the check using permitted actions. I have not submitted the form."},"trace_steps":[],"operator_steps":[],"handoff":{"kind":"handoff","reason":"captcha","elapsed_ms":30000,"outcome":"expired"},"status":"blocked","model_calls_by_kind":{"planner":1}}
```

## Isolation and cleanup

Both the five-run service and the visual-only service exited 0; profile-matched process checks after shutdown returned empty lists. Every acquired measurement tab was closed; temporary service/XDG/profile roots were removed. Only private process groups and profile-matched descendants were stopped. No interaction with `leash.service`, real XDG state, the user's Chrome, or the main checkout. This report retains no keys, live capabilities, or temporary paths; redaction/security scan performed before delivery.
