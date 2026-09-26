---
status: ready-for-agent
milestone: 6
---

# Run Leash as a service and retire the chrome-cdp script

## Problem Statement

The service is useful only if it is running when an agent needs it, configured once, observable when it misbehaves, and if the agents' skill points at it instead of at the old script.

## Solution

A systemd user unit in the desktop session, a TOML config with fail-fast validation, journal logging, a live-acceptance gate against real Chrome, and a replacement chrome-cdp skill that uses the `leash` CLI.

## User Stories

1. As an operator, I want a systemd user unit that starts Leash in my graphical session with the Wayland environment it needs, so that it is there when agents need it. ^svc-dit8
2. As an operator, I want the service to fail at boot with a precise message on a missing binary, unreadable profile directory, unknown config key, or bad value, so that misconfiguration is obvious. ^svc-ljl3
3. As an operator, I want `OPENROUTER_API_KEY` from the environment to override the config file, so that the key never has to be in a file. ^svc-kzt6
4. As an operator, I want logs in the journal with the tab handle, owner, and command on each line, so that I can follow an agent's session. ^svc-p67t
5. As an operator, I want page content, typed text, and urls with credentials kept out of logs, so that the journal is not a transcript of my logins. ^svc-qilu
6. As an operator, I want `scripts/live-acceptance` to run the real-Chrome checks the specs mark live-only and print a pass/fail report, so that a change is proven against the real thing before I trust it. ^svc-xafg
7. As an operator, I want the Nix flake to build the service and CLI with Eta pinned, exactly like Pie, so that the two services share one build story. ^svc-46f0
8. As an agent, I want the chrome-cdp skill rewritten to use `leash`, with the same minimize-output guidance, so that I do not have to learn a new workflow. ^svc-itcb
9. As an operator, I want `leash status` to be the health check and the unit to restart the service on failure, so that a crashed service does not need me. ^svc-gxhu
10. As an operator, I want the service to refuse to start if another instance owns the control socket, so that two services never fight over one profile. ^svc-5wm8
11. As an operator, I want a `leash config check` command that validates the file without starting the service, so that I can edit safely. ^svc-tkor
12. As an operator, I want optional OTLP export switchable in config, so that I can send traces to the same collector Pie uses when I care. ^svc-f4op

## Implementation Decisions

- Unit is installed by the flake or home-manager as Pie's is; `After=graphical-session.target`, `Restart=on-failure`, environment imported from the session for `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`.
- Config schema in one module with a typed record; unknown keys are errors; defaults are documented in `docs/config.md` generated from the same record.
- Logging through Eta observability with a journal reporter; a redaction rule set keeps `fill` text, `text` results, and userinfo out of records.
- The chrome-cdp skill is replaced in the dotfiles skills library by a `leash` skill; the old script remains until the replacement has passed live acceptance.

## Testing Decisions

- Config: table-driven tests over files and environment overrides at the config module seam: svc-ljl3, svc-kzt6, svc-tkor.
- Logging redaction with the in-memory logger: svc-p67t, svc-qilu.
- Listener conflict: svc-5wm8 (shares fixtures with milestone 1).
- Live-acceptance gate and unit behaviour are verified by running them: svc-dit8, svc-xafg, svc-46f0, svc-gxhu, svc-f4op.
- svc-itcb is verified by an agent completing the existing chrome-cdp workflow through the new skill.

## Out of Scope

Packaging for anyone but this machine, CI, an HTTP adapter.

## Further Notes

- Whether the unit is home-manager managed or a flake output installed by hand follows whatever Pie does today.
