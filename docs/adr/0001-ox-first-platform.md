# Build platform capabilities in Ox first

Leash is built on Ox and is one of its dogfooding consumers, next to Pie. Several things Leash needs do not exist in Ox yet: a scoped child process with inherited file descriptors, request/response correlation over a duplex message stream, a Unix-socket control listener, and a System One (JEV) client. We decided that each of these is built in Ox first, as a small Ox ticket landed before the Leash milestone that needs it, and that Leash never carries an Ox-shaped shim it would later delete.

The rule for where code lives: a piece belongs in Ox when it is an effect-shaped resource, stream, or lifecycle concern and names no Chrome, CDP, or niri concept. Effect TS and ZIO ship the same kind of platform pieces (Command, Socket, RPC, zio-process), so this is in Ox's declared scope, not scope creep. Everything that knows what a browser is stays in Leash: CDP domain bindings, the element table, tab capabilities and expiry, handoff, and the drive loop.

## Considered options

- **Build in Leash behind Ox-shaped interfaces, promote later.** Rejected: promotion is a second job that tends not to happen, and Pie already shows the cost (its control socket is a one-off nobody can reuse).
- **Ox-first except the control listener, copying Pie's server.** Rejected: that would be the third copy of the same hard-won listener lifecycle rules.

## Consequences

- Milestone 1 depends on four Ox tickets (`etaproc`, `etarpc`, `etaipc`, `etaso`), recorded in the Ox repository and listed in `docs/milestones.md`.
- Any gap discovered later is recorded in `docs/missing-ox-api.md` with an `etagap-*` ID before a workaround is written, as Pie does.
- Pie migrates to the Ox control listener at its own pace; Leash does not wait for that.
