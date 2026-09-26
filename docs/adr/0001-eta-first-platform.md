# Build platform capabilities in Eta first

Leash is built on Eta and is one of its dogfooding consumers, next to Pie. Several things Leash needs do not exist in Eta yet: a scoped child process with inherited file descriptors, request/response correlation over a duplex message stream, a Unix-socket control listener, and a System One (JEV) client. We decided that each of these is built in Eta first, as a small Eta ticket landed before the Leash milestone that needs it, and that Leash never carries an Eta-shaped shim it would later delete.

The rule for where code lives: a piece belongs in Eta when it is an effect-shaped resource, stream, or lifecycle concern and names no Chrome, CDP, or niri concept. Effect TS and ZIO ship the same kind of platform pieces (Command, Socket, RPC, zio-process), so this is in Eta's declared scope, not scope creep. Everything that knows what a browser is stays in Leash: CDP domain bindings, the element table, tab ownership and expiry, handoff, and the drive loop.

## Considered options

- **Build in Leash behind Eta-shaped interfaces, promote later.** Rejected: promotion is a second job that tends not to happen, and Pie already shows the cost (its control socket is a one-off nobody can reuse).
- **Eta-first except the control listener, copying Pie's server.** Rejected: that would be the third copy of the same hard-won ownership rules.

## Consequences

- Milestone 1 depends on four Eta tickets (`etaproc`, `etarpc`, `etaipc`, `etaso`), recorded in the Eta repository and listed in `docs/milestones.md`.
- Any gap discovered later is recorded in `docs/missing-eta-api.md` with an `etagap-*` ID before a workaround is written, as Pie does.
- Pie migrates to the Eta control listener at its own pace; Leash does not wait for that.
