# Missing Eta APIs used by Leash

Record every workaround for an Eta gap here with an `etagap-*` ID before writing it, and remove it when Eta provides the API. Planned capabilities that are tracked as Eta tickets (`etaproc`, `etarpc`, `etaipc`, `etaso`) are not gaps: Leash waits for them.

## etagap-pl4n — the chat client's usage carries no cost (L32, run-obtt)

Story 31 wants a planner turn's cost logged. `Eta_ai_chat.Types.usage` carries
`prompt_tokens`, `completion_tokens` and `total_tokens` only: the OpenAI-compatible
reply's `usage.cost`, which OpenRouter sends and the System One client already reads, is
dropped by the reply codec. `Planner` therefore reports the tokens in
`planner_turns[].usage` with `cost = 0.`, and the run's cost accounting for a planner
turn is its tokens until eta's chat usage carries the provider's cost; removing this
workaround is reading that field here and deleting the zero.
