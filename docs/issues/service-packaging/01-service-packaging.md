---
status: completed
milestone: 6
---

# Run Leash as a service and retire the chrome-cdp script

## Status — 2026-10-04

Completed. Config validation/defaults, environment key override, socket relocation, redacted journal fields, optional OTLP, Chrome stderr diagnostics, flake packaging and the shared user unit are present in the current tree. Installation and cut-over landed through L43/L44; [the operator's desktop acceptance](<../daily-use/01-daily-use.md#operator-desktop-check-daily-n7on-closes-l18l28--2026-10-01>) closes L28. No open stories in this spec. The installed service is currently at `ad5d8e2` with a stale skill: upgrading it to the reconciled HEAD and rerunning U1/U2 is the next delivery step, not an unimplemented packaging feature. Owner-based journal language is superseded by [L49 / ADR-0010](<../handles/01-handles.md>).

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
7. As an operator, I want the Nix flake to build the service and CLI with Ox pinned, exactly like Pie, so that the two services share one build story. ^svc-46f0
8. As an agent, I want the chrome-cdp skill rewritten to use `leash`, with the same minimize-output guidance, so that I do not have to learn a new workflow. ^svc-itcb
9. As an operator, I want `leash status` to be the health check and the unit to restart the service on failure, so that a crashed service does not need me. ^svc-gxhu
10. As an operator, I want the service to refuse to start if another instance owns the control socket, so that two services never fight over one profile. ^svc-5wm8
11. As an operator, I want a `leash config check` command that validates the file without starting the service, so that I can edit safely. ^svc-tkor
12. As an operator, I want optional OTLP export switchable in config, so that I can send traces to the same collector Pie uses when I care. ^svc-f4op
13. As an operator, I want every non-secret config field to have a default and `leash config init` to write a commented config file with those defaults to `$XDG_CONFIG_HOME/leash/config.toml`, so that a first run needs only the Chrome binary path (found on `PATH` if absent). ^svc-x8rp
14. As an operator, I want the control socket path configurable (`control.socket`, default under `$XDG_RUNTIME_DIR/leash/`), so that a test or a second instance can relocate the socket without moving the Wayland socket's directory. ^svc-o4wt
15. As an operator, I want Chrome's last 20 stderr lines kept per generation and included in the `chrome generation lost` log entry, so that a Chrome that dies at start says why (a missing display took three restarts to diagnose on 2026-09-27). ^svc-qrmc
16. As an agent, I want `leash <command> --help` to name each positional argument (`TAB`, `SNAPSHOT`, `INDEX`) and each command to accept only the options it uses, so that the first call is right; and I want the tab title refreshed from `Target.getTargetInfo` after any navigation an action caused, so that traces and `list` show the page, not the tab-strip text. ^svc-hi4f

## Implementation Decisions

- Unit is installed by the flake or home-manager as Pie's is; `After=graphical-session.target`, `Restart=on-failure`, `SuccessExitStatus=130` (Ox's process door returns 130 on SIGTERM interruption, which is a clean stop), environment imported from the session for `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`.
- Defects at the process door are printed only once Ox ticket `main-door-cause-diagnostics` lands; until then the service owner wraps its main effect and renders the full cause with `Ox.Cause.pp` itself, recorded as an `etagap-*` workaround, so a crash never leaves an empty journal.
- Config schema in one module with a typed record; unknown keys are errors; defaults are documented in `docs/config.md` generated from the same record.
- Logging through Ox observability with a journal reporter; a redaction rule set keeps `fill` text, `text` results, and userinfo out of records.
- The chrome-cdp skill is replaced in the dotfiles skills library (`/home/ribelo/.dotfiles/skills/engineering/debugging/`) by a `leash` skill written in the same minimize-output style: `snap --match`, `--limit`, `text`, never a full table when a row will do; the old script remains until the replacement has passed live acceptance with an agent completing the same workflow.
- The niri window rule (`match app-id="^leash$"` → `open-on-workspace "leash"`, `open-focused false`) is documented for the operator to add; Leash does not edit the niri config.
- The systemd unit: `Restart=on-failure`, `SuccessExitStatus=0` (the Door exits 0 on SIGTERM), `After=graphical-session.target`, `PartOf=graphical-session.target`, environment imported from the session (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, `DISPLAY`); installed by home-manager like Pie's, or by a `scripts/install-user-unit` if Pie's is installed by hand.

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
- **svc-dit8 note, 2026-09-28 (L31):** the Door's start subcommand is named `serve`, not
  `run`. L31's story run-9ypy gives `leash run "<mission>"` to the mission command, so
  Ox_app grew `?service_command` (ox napp-d5e4) and Leash passes `"serve"`:
  `ExecStart` is `…/bin/leash serve`, and `docs/install.md`, `packaging/leash-unit.nix`
  and `scripts/unit-acceptance` were moved with it. A bare `leash` still starts the
  same program.
- Historical L28 preparation (closed by L44 on 2026-10-01; the script was removed 2026-10-05, hand-tdkk): `scripts/live-acceptance-m6-headed`, the one
  desktop pass the operator runs by hand: it prints the install steps from
  `docs/install.md`, checks the unit and `leash status`, records niri's placement of
  the `leash` window (rule present? which workspace? focused before/after a handoff),
  runs the L27 skill workflow (`new/snap/fill/click/text/shot/debug/close`) on a page
  it serves on 127.0.0.1 with a DSH-style owner, triggers one handoff and asks about
  focus, the notification and the Done click (L18, whose result file it also writes),
  then restarts and stops the unit and checks the exit status, the socket, Chrome, the
  profile and the journal into `/tmp/leash-m6-headed-result.txt`. `bash -n` and
  `--dry-run` are green (the dry run prints every step and touches nothing), and the
  headed run was pending at that checkpoint. L44's recorded operator desktop check
  subsequently closed L28; it is not pending now.
