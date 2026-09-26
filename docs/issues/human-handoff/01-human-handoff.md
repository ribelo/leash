---
status: ready-for-agent
milestone: 4
---

# Hand a tab to the human and get it back

## Problem Statement

Logins, two-factor codes, captchas, and consequential confirmations need a human. Today the agent either fails or the human has to guess which tab in which window needs attention.

## Solution

`leash handoff <tab> <reason>` raises the live view on that tab, notifies the human with the reason and a Done action, marks the tab `with_human` so the agent's actions are refused, and blocks until the human resumes or the timeout passes.

## User Stories

1. As an agent, I want `leash handoff <tab> <reason>` to block until the human resumes and then return the tab's current url and title, so that I can re-observe and continue. ^hand-lz3p
2. As a human, I want the Chrome window focused on the handed-off tab, so that I land on the right page without hunting. ^hand-04rb
3. As a human, I want a desktop notification with the agent's reason and a Done action, so that I know what is asked and can finish it in one click. ^hand-phof
4. As a human, I want `leash resume <tab>` to work from any terminal, so that I can resume without the notification. ^hand-0sja
5. As an agent, I want my own actions on a handed-off tab refused with `with-human`, so that I cannot fight the human for the page. ^hand-nisr
6. As an agent, I want the handoff to end with `timeout` after the timeout (default 15 minutes), so that an ignored request does not block me forever. ^hand-lmd5
7. As an agent, I want a handed-off tab excluded from idle expiry, so that the human is not raced by a timer. ^hand-len8
8. As a human, I want `leash list --all` to show which tabs are waiting on me and why, so that I can catch up after stepping away. ^hand-r4t1
9. As an agent, I want `handoff` on a tab I do not own to fail with `not-owner`, so that I cannot pull the human onto another agent's page. ^hand-beip
10. As an agent, I want a browser loss during handoff to end it with `tab-gone` `browser_lost`, so that I do not wait on a page that no longer exists. ^hand-yytf
11. As a human, I want resuming a tab nobody is waiting on to fail with a clear error, so that a stale notification does not do something surprising. ^hand-szz7
12. As an operator, I want the notification and focus mechanisms configurable and failures in them reported in the reply but not fatal to the handoff, so that a missing notify-send does not break the agent. ^hand-rg9h

## Implementation Decisions

- Handoff transitions `Owned` to `With_human` holding the reason and an `Eta.Promise` the blocked request awaits; resume completes it. Timeout is `Effect.timeout` on the await with the state restored to `Owned`.
- Focus: `Target.activateTarget` for the tab, then the configured desktop action (default `niri msg action focus-window` matched by the Chrome app id or title determined in milestone 1). Notification: `notify-send --action done=Done` with the reason; the CLI-less resume path is the notification's action return, consumed by the service through the same spawn.
- Both external commands run through Eta's scoped child process with a five-second deadline; their failure is reported in the reply's `warnings` and logged.
- `list --all` shows state `with_human` and the reason.

## Testing Decisions

- Protocol seam with two clients (agent and human), the fake browser, a test clock, and a fake command runner recording spawned commands: hand-lz3p, hand-0sja, hand-nisr, hand-lmd5, hand-len8, hand-r4t1, hand-beip, hand-szz7, hand-rg9h.
- Fake browser drops the pipe mid-handoff: hand-yytf.
- Live-acceptance: hand-04rb, hand-phof.

## Out of Scope

A streamed viewer; handoff inside `drive`; a GUI.

## Further Notes

- If notify-send actions prove unreliable under the user's notification daemon, the fallback is notification without action plus `leash resume`.
