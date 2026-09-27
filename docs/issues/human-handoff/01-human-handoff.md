---
status: completed-pending-headed
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

- Handoff transitions `Owned` to `With_human` holding the reason and an `Eta.Promise` the blocked request awaits; resume completes it. Timeout is `Effect.timeout_as` on the await (not `race`: Eta's race picks the first success, not the first exit) with the state restored to `Owned`. A client disconnect cancels the await and restores `Owned` the same way.
- Focus: `Target.activateTarget` for the tab, then the configured desktop action (default `niri msg action focus-window` matched by the Chrome app id or title determined in milestone 1). Notification: `notify-send --action done=Done` with the reason; the CLI-less resume path is the notification's action return — the action name `done` on its stdout — consumed by the service through the same spawn.
- Both external commands run through Eta's scoped child process, each with its own five-second bound and a five-second retirement grace; their failure is reported in the reply's `warnings` and logged. The focus command is a step the handoff waits for, so it is bounded by five seconds. The notification instead runs for as long as the handoff does and is stopped when the handoff ends by any path — resume, deadline, disconnect, or the tab going away — so a Done action can arrive at any moment.
- `list --all` shows state `with_human` and the reason.
- `resume` (by CLI or notification action) resets the tab's idle clock, so the human's work does not expire the agent's tab a moment later; milestone 3's registry `hand_over` deliberately does not, and `handoff` is the only wire path into `With_human`.
- Focus is best effort (ADR-0003): `Target.activateTarget` first; the desktop command is configurable (`handoff.focus_command`, default `niri msg action focus-window --id {window_id}`), and `notify-send` is configurable the same way (`handoff.notify_command`, default `notify-send --action done=Done {reason}`). A command's argv elements are templates — `{tab}`, `{reason}`, `{url}`, `{title}`, and the focus command's `{window_id}`, the managed Chrome's niri window found by app id `leash` and then by title; a command that asks for a window that is not there is skipped. An empty list turns a step off. Nothing goes through a shell. Both external commands run through `Eta_process.Child`, and their failure is a `warnings` entry, never a handoff failure.

## Testing Decisions

- Protocol seam with two clients (agent and human), the fake browser, a test clock, and a fake command runner recording spawned commands: hand-lz3p, hand-0sja, hand-nisr, hand-lmd5, hand-len8, hand-r4t1, hand-beip, hand-szz7, hand-rg9h.
- Fake browser drops the pipe mid-handoff: hand-yytf.
- Live-acceptance: hand-04rb, hand-phof.

## Out of Scope

A streamed viewer; handoff inside `drive`; a GUI.

## Further Notes

- If notify-send actions prove unreliable under the user's notification daemon, the fallback is notification without action plus `leash resume`.
- L18 headless, 2026-09-27: `scripts/live-acceptance-m4` (+ `.py`) green on real
  headless Chrome through the real CLI/service — agent handoff blocked, human
  (`--owner human`) resume answered url/title, `--timeout-s 3` answered timeout
  with the tab owned again, killing the handoff client restored ownership,
  resume with nobody waiting answered no-handoff, the owner's snap/text were
  refused with-human, the stand-in notifier printing `done` resumed, the
  stand-in focus got the substituted tab/reason/url/title, failing stand-ins
  warned without failing the handoff; SIGTERM exited 0, Chrome gone. No
  defects found, so no code changed.
- Headed run pending the user: `scripts/live-acceptance-m4-headed` (manual,
  headed Chrome, real niri focus + notify-send; do NOT run it headless or from
  an agent). It records whether the tab resumed and what niri did with
  `--class=leash` (windows before/after) into `/tmp/leash-m4-headed-result.txt`.
  When that result is pasted back, flip this status to `completed` and tick L18.
