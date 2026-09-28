# Leash

A local browser service for coding agents. Leash runs one headed Chrome on its own profile as a systemd user service, lets any number of agents open, claim, observe, and act on tabs through the `leash` CLI, hands a tab to you when a login or a captcha needs a human, and can drive a tab toward a goal with the JEV decision model.

Status: planning. See `docs/milestones.md`.

## Running it

`leash.service` is a systemd user unit in the graphical session; it runs one headed
Chrome on its own profile and answers the `leash` CLI on the control socket.

```sh
nix build .#leash          # the binary the unit runs
scripts/unit-acceptance    # headless check of the unit's ExecStart line, no install
```

Install, enable, the health check, `journalctl`, uninstall: `docs/install.md`. The niri
window rule is the operator's to add — Leash never edits the niri config:

```kdl
window-rule {
    match app-id="^leash$"
    open-on-workspace "leash"
    open-focused false
}
```

- `CONTEXT.md` — vocabulary
- `docs/adr/` — decisions
- `docs/protocol.md` — control protocol and CLI
- `docs/config.md` — configuration keys, defaults and environment overrides
- `docs/install.md` — the systemd user unit, install and enable, journalctl, the niri rule, uninstall
- `docs/issues/` — milestone specs with story IDs
