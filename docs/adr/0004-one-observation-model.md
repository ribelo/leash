# One observation model: the numbered element table

Leash has one observation of a page: a snapshot with a numbered element table, one row per interactive or informative element in reading order, showing index, role, name, and value or state. Agents read it through `leash snap`; JEV receives the same rows as its state. Every action targets a row index from the latest snapshot and nothing else. A stale snapshot is refused with a typed error and the client observes again.

The evidence: a 104-run comparison of agent browser tools found the snapshot-plus-reference pattern, not the interface, decides effectiveness, and that coordinate/screenshot approaches were far behind. Stagehand moved from DOM dumps to the accessibility tree because it halved context and suited small models. jev-ultrafast's speed comes from atomic snapshots with freshness guards, not from being DOM-based. jev-ultrafast's own DOM reader admits it does not implement the accessible-name specification.

## Considered options

- **Keep the accessibility-tree snap with stamped references next to a DOM element table.** Rejected: two reference systems, two staleness rules, twice the surface for the same decision.
- **Accessibility tree only, with JEV consuming it.** Not rejected: the table's rows are accessibility-shaped (role, name, value). Whether rows are sourced from Chrome's computed accessibility tree or from an injected DOM script is an implementation choice.

## Consequences

- Milestone 1 includes a measured spike: both sources on the same five sites, comparing snapshot latency, row count, name correctness, and CDP call count. The spike's result is recorded in the observation spec, not here.
- Shadow roots, iframes, canvas, and file inputs are out of scope until the table has a story for them.
- Screenshots exist for humans and for visual verification, never as an action target.
