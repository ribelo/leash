# Handles

A handle is the only way to act on a tab. It is 128 bits from the system's randomness. Whoever holds it acts. Whoever lacks it cannot. There is no owner string, no claim, no release, and the CLI reads no session identity from the environment. Agents do not interfere because they do not hold each other's handles. Sharing a tab is handing over the handle. The service has no opinion about that.

`leash new` and `leash take` return a handle. Keep it. Losing it loses the tab: an agent tab closes when it has been idle, and a new one is opened. `leash list` shows every tab and never a handle. A label is a free string for finding a tab. It is not a capability.

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
