# Handles

## Setup and environment

Offline help does not need the service. For browser commands, run `leash config init`, `leash config check`, then `leash status`. The default TOML file is `$XDG_CONFIG_HOME/leash/config.toml`, falling back to `~/.config/leash/config.toml`. `--config FILE` selects another file; the CLI and service must agree on the socket.

- `XDG_RUNTIME_DIR` supplies `$XDG_RUNTIME_DIR/leash/control.sock`. There is no default when it is unset: use the login session's private runtime directory or configure an absolute `control.socket`.
- `XDG_DATA_HOME` supplies the managed Chrome profile at `$XDG_DATA_HOME/leash/profile`. It falls back to `$HOME/.local/share`. Set either it or `HOME`, or configure an absolute `chrome.profile_dir`. This is not the human's everyday browser profile.
- `HOME` also expands `~/` and `$HOME/` paths. An unresolved path diagnostic names the unset variable and the config field; `XDG_DATA_HOME` in such a diagnostic means both it and its `HOME` fallback are absent.
- `PATH` must contain `google-chrome-stable` by default, or set `chrome.binary` to your Chrome executable's absolute path.
- `OPENROUTER_API_KEY` in the service's environment takes precedence over `models.api_key` in the config. Browser-only commands do not need a model key; missions do. Never print the key.

The service keeps its startup environment: exporting a variable in the agent's shell does not change an already-running service. Set variables in the environment that launches `leash serve` (or its user service), restart it when needed, and check again. There is no playbook install or uninstall command: copy or remove an installed playbook directory yourself; `leash help playbooks` explains where.

## Tab capability

A handle is the only way to act on a tab. It is 128 bits from the system's randomness. Whoever holds it acts. Whoever lacks it cannot. There is no owner string, no claim, no release, and the CLI reads no session identity from the environment. Agents do not interfere because they do not hold each other's handles. Sharing a tab is handing over the handle. The service has no opinion about that.

`leash new` and `leash take` return a handle. Keep it. Losing it loses the tab: an agent tab closes when it has been idle, and a new one is opened. `leash list` shows every tab and never a handle. A label is a free string for finding a tab. It is not a capability.

`list` and `snap` include `page_kind`: `{name, source}`. `source` is `declared` when an installed playbook's URL pattern matches, and `inferred` otherwise. An inferred name comes from the URL path. Digits, long hex, UUIDs, and separator-free mixed alphanumeric tokens of eight or more characters become `<id>`. A content slug (long, hyphenated, capitalized, or ending `_<digits>`) becomes `<slug>`. A short `word-<digits>` such as `page-2` stays `word-<id>`. A `ref=`, `@` coordinate, or `!` blob is dropped. The name is the last static segment plus the placeholders after it, so every product, place, category, or book of one shape shares a kind. The query is dropped. `list --table` adds `PAGE_KIND` and `KIND_SOURCE`. `snap --table` prints the kind above the rows and still omits the snapshot id.

## Origin

Every tab has an origin. `human` means the tab was opened in the Chrome UI or by a page. `agent` means it was opened through the protocol, or a human tab an agent has taken. Taking flips the origin to `agent` and does not flip it back.

agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one

The idle duration is `expiry.idle_s` in the configuration, 1800 seconds by default. Any command on the handle resets the clock. `list` shows `closes_in_s`; it is null for a human tab and for a tab handed to the human. There is no force-close escape hatch.

## Take

`leash take` mints a handle for exactly one tab matching one selector: `--url PREFIX` (case-insensitive URL prefix), `--title TEXT` (case-insensitive title substring), or `--label TEXT` (case-insensitive exact label). Several matches are `ambiguous`. None is `no-match`. A tab that already has a live handle is `taken`: ask the holder for the handle. A tab with the human is not take-able.

Take only a tab the human told you to take. Leash does not ask or notify them. A taken tab is an agent tab from then on and closes after 30 idle minutes. Tell the human when you leave one open for them. Human tabs often have no label, so match on URL or title. `list` reads each tab's current title first, so a tab the human navigated shows its page title.

A popup opened by a page is human and does not inherit its opener's handle. After a browser restart, restored tabs are human and handles from the previous generation are gone with reason `browser_lost`.

## With the human

`handoff` asks the human to do something on the agent's tab: a login, a CAPTCHA, a choice only they can make. It is keyed on the handle. While the tab is with the human, commands on the handle are refused and idleness is paused. `resume` (the notification's Done action, or `leash resume HANDLE`) clears that flag and restarts the idle clock. Anyone with the handle may resume; an agent should do so only after the human says they are finished.

## When a handle is gone

A later request reports why, from a tombstone:

- `closed_by_handle` — `leash close` on this handle
- `closed_by_idle` — the idle duration elapsed
- `closed_externally` — the page or the window closed it
- `browser_lost` — the managed Chrome was replaced; the handle was from an older generation

The hint is to open a new tab with `leash new`. Do not replay a submission because its tab vanished.

## Observe, act, and recover

Use JSON `leash snap TAB` when you need the snapshot id for `click`, `fill`, or `press`. `snap --table` shows rows but omits that id; it is an inspection view, not a complete row-action input. After a stale or refused row action, snap again rather than reusing the old index.

A `click` or `fill` reply's URL may lag an asynchronous navigation. If a destination matters, wait for it explicitly, for example `leash wait TAB --url-prefix https://example.com/cart`, then snap. A refused click can scroll or focus a control before it discovers the obstruction, but must not dispatch the click at that obstruction; its refusal is not a claim that the page had no other effects. Check the page before retrying a consequential action.

An overlay can hide or intercept an otherwise valid row. Read the page and locate its dismiss or consent controls, dismiss it if safe, and snap again. Decline optional tracking by default unless the human asked otherwise. Consent choices persist in the managed Chrome profile, not just the tab, so later visits may not show the same banner. A cross-origin ad frame may be visible in a screenshot without appearing as actionable snapshot rows; do not click blindly through it. Navigation to a known same-site URL can escape a non-consent obstruction, or ask the human with `handoff`. It does not authorize accepting tracking or bypassing access controls.

A screenshot renderer can time out on a page with busy ads. Use `snap`, `text`, and `debug` for independent evidence, and retry a screenshot only when useful; a screenshot timeout does not by itself mean the browser commands are unusable.
