# Service, identity, tabs, and skill installation

## Check the service before browser work

```sh
leash status
systemctl --user status leash
```

`status` reports Chrome health (`running` or `restarting`), browser generation, its real managed process `pid` (null during restart), uptime, open-tab count/cap, model configuration, and installed-skill currency. It does not print API keys. `models.configured` is relevant to `drive` and `discover`; manual browsing needs no model key.

If the service is down, start the installed user unit when authorized:

```sh
systemctl --user start leash
leash status
```

A brief `service-restarting` (75) right after start is normal: retry `leash status` after a short delay until running; do not launch a competing service.

For setup problems, `leash config check` reports all problems with the configuration path. `leash config init` writes the default configuration; inspect its help before using it on an existing setup. The default file is `${XDG_CONFIG_HOME:-$HOME/.config}/leash/config.toml`. An absent default file means defaults; an explicitly named missing `--config FILE` is an error. `--config FILE` selects configuration, and `--socket PATH` overrides the control socket for one client call. The default socket is `$XDG_RUNTIME_DIR/leash/control.sock`; it is private to the user's account. Do not weaken its permissions.

`leash serve` runs the service in the foreground. Normally systemd owns it; do not start a competing instance or a second Chrome against the same profile. Stop/restart with `systemctl --user stop leash` / `systemctl --user restart leash` only when the task authorizes interruption: restarting loses live handles and may disrupt other agents. Generation-loss origins render OS-facing signals such as `SIGKILL / 9`, not OCaml's portable negative constants. For logs, use `journalctl --user -u leash -n 50 --no-pager`, keeping private page data out of reports.

### Detect a shared-service interruption

Save `status` generation, `pid` and `uptime_s` before a long run and compare them after a disconnect or unexpected tab loss. A Chrome restart in the same service increases generation and changes pid; a full service restart resets generation (normally back to 1) and resets uptime. Generation 1 alone proves nothing, and sparse samples can miss a restart, so compare uptime against elapsed time too. A lower uptime or changed generation/pid is a reason to re-check handles and re-snap, not to replay a submission.

These fields cannot identify who restarted it. Check `journalctl --user -u leash` around the interruption and coordinate with other users/agents; overlapping sessions may have stopped/started the shared service. Do not restart it yourself merely to diagnose someone else’s interruption.

### Headed versus headless

Production defaults to **headed** Chrome, on Leash's dedicated profile and desktop workspace. That allows the human to log in, inspect the actual page, and use handoff. `chrome.headless = true` in the TOML configuration runs without a visible window; it is useful for unattended work but cannot provide a visible human handoff. This is a service setting, not a `new` or `drive` flag. Do not toggle it or restart a shared service without authorization. The profile, cookies, and logins are shared across Leash's tabs, not with the user's everyday browser.

## Tab capabilities

A tab handle is the only credential. Share it intentionally; the CLI neither reads nor sends a session identity. Commands on one tab serialize where they did before, even across connections.

| Command | Use |
| --- | --- |
| `leash new [URL] [--label TEXT]` | Create an agent tab; read its handle from the reply. |
| `leash list [--table]` | All tabs: label, URL, title, origin, age, idle time, seconds to close, and human hold; never handles. |
| `leash take --url PREFIX` | Take exactly one permitted tab matching a case-insensitive URL prefix. |
| `leash take --title TEXT` | Match a case-insensitive title substring. |
| `leash take --label TEXT` | Match the whole label, case-insensitively; labels need not be unique. |
| `leash close TAB` | Close a tab for which you have the handle, unless it is handed to the human. |

`ambiguous` returns handle-free matches; narrow the selector. `no-match` asks you to check the listing. `taken` means a live capability already exists: ask the holder for it. A human hold refuses take. Chrome UI tabs and page popups are human and have no capability until taken; a popup never inherits its opener capability. Taking a human tab changes its origin permanently to agent.

### Expiry and lost handles

agent tabs close after 30 idle minutes; your tabs are never closed unless an agent takes one

Agent tabs close in a single stage after `expiry.idle_s` (default 1800 seconds). Handle use resets idleness; handoff pauses expiry and resume, timeout, or cancellation restarts the clock. `closes_in_s` is null for human or handed-off tabs. There is no force-close escape hatch.

`tab-gone` records `closed_by_handle`, `closed_by_idle`, `closed_externally`, or `browser_lost`. Its hint is “open a new tab with `leash new`”. A restart makes restored targets human and old handles dead. Never replay a potentially completed submission because its tab vanished.

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
