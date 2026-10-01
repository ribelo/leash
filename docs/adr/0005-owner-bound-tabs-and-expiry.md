# Tabs are owner-bound, origin-tagged, and expire in two stages

**Superseded by ADR-0010.** The model below is historical. Do not implement it. A handle is the capability; there is no caller name, no claim, and no release.

Every tab has an origin (`Agent` if created through the protocol, `Human` if opened in the Chrome UI or by a page) and an owner state (`Unowned`, `Owned`, `With_human`). Every request that touches a tab carries the caller's owner string; acting, closing, answering dialogs, handing off, and releasing require that the caller owns the tab; claiming requires that nobody does. Listing shows the caller's tabs unless `--all` is asked for. Handles are opaque and unguessable, but ownership is cooperative: it prevents one agent from stomping on another by accident, not a hostile local process.

Expiry runs in two stages. An owned tab idle for the idle duration (default 30 minutes) is released, not closed. An unowned tab of `Agent` origin that stays unclaimed for the unclaimed duration (default 60 minutes) is closed. Human-origin tabs are never auto-closed, even after an agent claimed and released them. Handoff pauses idleness. When a tab is gone, Leash keeps a tombstone with the disposition (`Closed_by_owner`, `Closed_by_ttl`, `Closed_externally`, `Browser_lost`) so a later request reports what happened.

## Considered options

- **A flat pool where any client can use any tab.** Rejected: agents running all day already leave a hundred tabs nobody can attribute.
- **Expiry that closes owned tabs directly.** Rejected: the release stage gives another agent or the human a window to pick the tab up.
- **Expiry that also closes unowned human tabs.** Rejected: a human's tab vanishing because a service timer fired is a betrayal, not housekeeping.
- **Turn-owned tabs (wiser's rejected model).** Rejected for the same reason wiser rejected it: it closes the login page the human was asked to complete.

## Consequences

- CDP cannot distinguish a human closing a tab from `window.close()`; both are `Closed_externally`. The other three dispositions are exact.
- `leash list --all` shows origin, owner state, and time to the next expiry stage so the human can see what is about to happen.
- Tab cap defaults to 32; creating a tab past it fails at once. No queue.
