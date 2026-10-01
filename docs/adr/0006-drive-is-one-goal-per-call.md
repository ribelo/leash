# Drive runs one goal on one tab and reports; the outer agent plans and verifies

`drive` takes one tab, one natural-language goal, a step cap, and a deadline, and runs the jev-ultrafast loop: snapshot, one System One request answering the operation and speculative target questions, act on the matching target, settle, repeat. It stops on `done`, `blocked`, the step cap, the deadline, or an error, and returns the full trace and a final snapshot. `done` is JEV's opinion; Leash never asserts the goal is achieved. `blocked` returns to the caller, who decides whether to hand the tab to the human. Text for `type_text` comes from a configurable OpenRouter text helper whose output must parse as a small JSON object; the goal may carry known values so the helper rarely invents anything. Model output never becomes a selector, a coordinate, shell, or JavaScript.

## Considered options

- **Structured multi-step plans executed by Leash.** Rejected: JEV's state stays small and each drive independently verifiable only if Leash does not carry plan state; the outer agent is a better planner and already has to verify.
- **No text helper; every typed value supplied by the outer agent.** Rejected: search queries and derived form values would force a round trip to the outer agent on every field.
- **Auto-handoff on `blocked`.** Rejected: the outer agent may prefer to retry, change the goal, or give up; blocking on a human inside `drive` hides that choice.

## Consequences

- The System One contract is the one SmartRouter already uses, built into `ox_ai_openrouter` (Ox ticket `etaso`).
- Defaults: 30 steps, 120 seconds. Per-step waits are bounded as in jev-ultrafast (suggestions after typing up to 200 ms, otherwise two frames or 50 ms).
- The trace records probabilities so a human can audit why a step happened.
