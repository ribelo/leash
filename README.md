# Leash

A local browser service for coding agents. Leash runs one headed Chrome on its own profile as a systemd user service, lets any number of agents open, claim, observe, and act on tabs through the `leash` CLI, hands a tab to you when a login or a captcha needs a human, and can drive a tab toward a goal with the JEV decision model.

Status: planning. See `docs/milestones.md`.

- `CONTEXT.md` — vocabulary
- `docs/adr/` — decisions
- `docs/protocol.md` — control protocol and CLI
- `docs/config.md` — configuration keys, defaults and environment overrides
- `docs/issues/` — milestone specs with story IDs
