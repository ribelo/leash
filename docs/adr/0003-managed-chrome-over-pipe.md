# Leash owns one headed Chrome, spoken to over a pipe

The Leash service launches Chrome itself with a dedicated profile directory and `--remote-debugging-pipe`, and is its only CDP client. Chrome runs headed, in the user's desktop session, on a niri workspace reserved for it by a window rule so it never appears on the active workspace when the service starts. If Chrome exits, Leash relaunches it under a schedule, increments the browser generation, and every handle from the old generation is gone with `Browser_lost`.

## Considered options

- **Attach to a Chrome the user starts.** Rejected: Leash could not supervise it, and profile and flags would drift.
- **`--remote-debugging-port` on localhost.** Rejected: any local process could drive the logged-in browser; the socket permissions would no longer be the only door. It also invites tools to bypass Leash. The existing chrome-cdp script keeps its own `/tmp/chrome-debug` instance until Leash replaces it.
- **Headless Chrome plus a screencast web viewer for handoff.** Deferred: a real subsystem (screencast, input forwarding, a page) and a worse surface for logins and 2FA than a real window. It remains the documented route if Leash ever runs without a desktop.
- **Support both headed and headless in v1.** Rejected: Chrome cannot do both in one instance, and a flag nobody uses is complexity.

## Consequences

- The service is a systemd user unit that needs the session's Wayland environment; it fails to start without a display, and that is acceptable.
- CDP focus emulation lets a background tab render and animate while Leash works on it (jev-ultrafast relies on this). Refined 2026-09-30 by operator decision: focus emulation is on only during an agent operation on that page — from the moment a valid snapshot, read, eval, shot, action, drive or run starts touching the page until it has its result — and off otherwise, because the page can see it (`document.hasFocus()`, `visibilityState`).
- The operator uses this browser as their own, for their own accounts, so nothing a page can observe may differ from Chrome started by hand (2026-09-30, Google sign-in). The pipe switch alone turns on Blink's AutomationControlled feature (`navigator.webdriver = true`); the launch disables exactly that feature with `--disable-blink-features=AutomationControlled`. Leash's own page scripts run in an isolated world, never the page's main world. The pipe stays: with those fixes Google's sign-in accepts the browser, so the debugging-port option above remains rejected.
- Window placement on the niri workspace is best effort: one rule on app id, one on title, and if neither matches the operator moves the window by hand after a start. Not worth more.
- Chrome must always be able to come back from a SIGKILL without a prompt; graceful shutdown is a courtesy, never a dependency.
- The profile is the only persistent state. Leash keeps handles, ownership, and snapshots in memory only.
