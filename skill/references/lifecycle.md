# Service, identity, tabs, and skill installation

## Check the service before browser work

```sh
leash status --owner browser-example
systemctl --user status leash
```

`status` reports Chrome health (`running` or `restarting`), browser generation, its real managed process `pid` (null during restart), uptime, open-tab count/cap, model configuration, and installed-skill currency. It does not print API keys. `models.configured` is relevant to `drive` and `discover`; manual browsing needs no model key.

If the service is down, start the installed user unit when authorized:

```sh
systemctl --user start leash
leash status --owner browser-example
```

A brief `service-restarting` (75) right after start is normal: retry `leash status` after a short delay until running; do not launch a competing service.

For setup problems, `leash config check` reports all problems with the configuration path. `leash config init` writes the default configuration; inspect its help before using it on an existing setup. The default file is `${XDG_CONFIG_HOME:-$HOME/.config}/leash/config.toml`. An absent default file means defaults; an explicitly named missing `--config FILE` is an error. `--config FILE` selects configuration, and `--socket PATH` overrides the control socket for one client call. The default socket is `$XDG_RUNTIME_DIR/leash/control.sock`; it is private to the user's account. Do not weaken its permissions.

`leash serve` runs the service in the foreground. Normally systemd owns it; do not start a competing instance or a second Chrome against the same profile. Stop/restart with `systemctl --user stop leash` / `systemctl --user restart leash` only when the task authorizes interruption: restarting loses live handles and may disrupt other agents. Generation-loss origins render OS-facing signals such as `SIGKILL / 9`, not OCaml's portable negative constants. For logs, use `journalctl --user -u leash -n 50 --no-pager`, keeping private page data out of reports.

### Detect a shared-service interruption

Save `status` generation, `pid` and `uptime_s` before a long run and compare them after a disconnect or unexpected tab loss. A Chrome restart in the same service increases generation and changes pid; a full service restart resets generation (normally back to 1) and resets uptime. Generation 1 alone proves nothing, and sparse samples can miss a restart, so compare uptime against elapsed time too. A lower uptime or changed generation/pid is a reason to re-check handles and re-snap, not to replay a submission.

These fields cannot identify who restarted it. Check `journalctl --user -u leash` around the interruption and coordinate with other users/agents; overlapping sessions may have stopped/started the shared service. Do not restart it yourself merely to diagnose someone else’s interruption.

### Headed versus headless

Production defaults to **headed** Chrome, on Leash's dedicated profile and desktop workspace. That allows the human to log in, inspect the actual page, and use handoff. `chrome.headless = true` in the TOML configuration runs without a visible window; it is useful for unattended work but cannot provide a visible human handoff. This is a service setting, not a `new` or `drive` flag. Do not toggle it or restart a shared service without authorization. The profile, cookies, and logins are shared across Leash's tabs, not with the user's everyday browser.

## Keep one owner identity

Every service request needs an owner. Explicit `--owner NAME` wins over the automatic `dsh:$DSH_SESSION_ID` identity. Outside DSH, choose a unique, stable name and pass it on every call. Do not use another session's name to work around ownership. Local help, configuration, skill installation, and local playbook inspection do not require a service owner.

## Tab lifecycle

| Command | Use |
| --- | --- |
| `leash new [URL]` | Open an owned agent-origin tab; omitted URL starts blank. Read `tab` from the reply. |
| `leash list` | List your tabs, including ones handed to the human. |
| `leash list --all` | Inspect every tab's handle, URL, title, origin, state, owner, and handoff reason. This does not grant access. |
| `leash claim TAB` | Take an unowned tab you are permitted to use. |
| `leash release TAB` | Leave your tab open but unowned. |
| `leash close TAB` | Close your tab. |

Add `--owner NAME` unless using the DSH default. `list --all --table` is convenient for orientation. Page reads as well as actions need ownership. Human-created tabs in the **managed** Chrome are discoverable as `origin: human`, `state: unowned`; claim only the one the user intends you to use. A popup from your tab is normally owned by you; inspect action replies' `popups` and `list` rather than opening a duplicate.

`--force` exists only on `release` and `close` for tab operations. It overrides another owner and a human hold; every use is logged. It is an operator cleanup tool, not an agent recovery shortcut. Ask the owner/operator instead.

### Expiry and lost handles

By default, an idle owned tab is released after 1800 seconds. An unclaimed agent-origin tab is closed after another 3600 seconds. `expires` reports its next stage and remaining seconds; configured durations can differ. Human-origin tabs are never auto-closed; `with_human` pauses expiry. Owner activity resets idleness.

Do not assume a handle survives a long pause or browser restart. `not-owner` after idling may mean the tab was released: inspect `list --all`, then claim it if still unowned and appropriate. `tab-gone` includes `detail.disposition` (`closed_by_owner`, `closed_by_ttl`, `closed_externally`, or `browser_lost`); open a replacement only if the task still requires it. Never replay a potentially completed submission merely because its tab vanished.

## Install or refresh this skill from the binary

```sh
leash skill show
leash skill install --dry-run
```

`skill show` prints the raw stamped entrypoint Markdown, **not JSON**. `skill install [PATH] [--dry-run] [--force]` installs the embedded entrypoint and references. `PATH` is a **skills root**: installation writes `PATH/leash/`, not directly into `PATH`. No checkout or network download is needed.

Without `PATH`, `skill.roots` from the selected configuration is used by both installation and status. For example:

```toml
[skill]
roots = ["~/.dotfiles/skills/engineering/debugging"]
```

`~` and leading environment variables (such as `$HOME`) expand before use; roots must then be absolute, and an unset variable is a `config-invalid` error at its `/skill/roots/N` pointer. `--config FILE` on install/status selects the same roots; an explicit install `PATH` overrides them. Configured roots remain consent-protected: preview with `--dry-run`, then use `--force --no-input` only for an authorized installation. With empty/unset `skill.roots`, installation discovers existing agent homes: `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, and `~/.agents/skills`. Canonical duplicate paths are installed only once. For another harness, supply its registered skills root explicitly. Do not guess its discovery configuration or create an unrelated agent home.

For an explicitly requested new installation into an existing Codex setup, for example:

```sh
leash skill install ~/.codex/skills --dry-run
leash skill install ~/.codex/skills --no-input
```

The dry run never writes or prompts. Its JSON action is `planned-install`, `planned-replace`, or `current`, with a path ending in `/leash`. A live run reports `installed`, `replaced`, or `current` (or `declined` when a human refuses). An explicit new install is non-interactive. Automatically discovered installs and replacement of locally modified content require `--force` or interactive consent. Agents should use `--no-input` rather than wait for a prompt; inspect the plan and obtain authorization before discarding local edits. To apply an authorized refresh:

```sh
leash skill install ~/.codex/skills --force --no-input
```

`leash status` includes `skill.state: missing|stale|current`, the binary's `version` and `commit`, and `installs` with each discovered path, state, installed version, and commit. An existing install must match the binary's content as well as version/revision to be `current`; any locally edited reference makes the overall skill state stale. Absent roots are listed as missing; overall state is current when at least one install is current and none is stale. With configured roots, status checks those same roots, including custom nested skill libraries; an explicit one-off install path is not added to configuration. Refresh the intended roots, then check status again. Do not hand-edit stamped version/commit metadata to make a stale install appear current.
