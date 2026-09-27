---
status: completed
milestone: 3
---

# Own, claim, release, and expire tabs

## Problem Statement

Agents left running all day leave a hundred tabs nobody can attribute, eating memory, and the human cannot find the tabs that matter. Meanwhile the human sometimes wants to prepare a page (log in, pass a captcha) and hand it to an agent, and one agent must not close or act on another's tab by accident.

## Solution

Every tab has an origin and an owner state; every request carries the caller's owner string and is checked against the tab. Unowned tabs can be claimed, owned tabs released. Expiry is in two stages, releases before it closes, and never closes a human's tab. A closed tab leaves a tombstone that says why it is gone.

## User Stories

1. As an agent, I want the tab I create to be owned by me, so that nothing else acts on it. ^own-6ndc
2. As an agent, I want any act, close, dialog, handoff, or release on a tab I do not own to fail with `not-owner`, so that I cannot damage another agent's work by a mistaken handle. ^own-pmr7
3. As a human, I want tabs I open in the Chrome UI to appear in `leash list --all` as unowned with origin `human`, so that an agent can pick one up. ^own-c0cl
4. As an agent, I want `leash claim <tab>` to take an unowned tab for me, so that I can work on a page the human prepared. ^own-jua9
5. As an agent, I want `claim` on a tab someone owns to fail with `already-owned`, so that I do not steal it. ^own-0np9
6. As an agent, I want `leash release <tab>` to make my tab unowned without closing it, so that another agent or the human can take it later. ^own-2zs7
7. As a human, I want popups and tabs opened by pages to be tagged by origin `human` unless opened from an agent's tab, in which case they are agent-origin and owned by that agent, so that ownership follows cause. ^own-ehqa
8. As an agent, I want `leash list` to show only my tabs and `--all` to show every tab with origin, owner state, owner, and the next expiry stage with seconds remaining, so that I see what I need and the human sees everything. ^own-82jd
9. As an operator, I want an owned tab idle for the idle duration to be released, so that a forgotten tab becomes available instead of hoarded. ^own-uo77
10. As an operator, I want an unowned agent-origin tab unclaimed for the unclaimed duration to be closed, so that the day's leftovers clean themselves up. ^own-hslp
11. As a human, I want a human-origin tab never to be auto-closed, whatever its ownership history, so that a service timer never takes my page away. ^own-2zpi
12. As an agent, I want any owner action on a tab to reset its idle clock, so that a tab I am using stays mine. ^own-ay3s
13. As an agent, I want a request on a closed tab to fail with `tab-gone` carrying `closed_by_owner`, `closed_by_ttl`, `closed_externally`, or `browser_lost`, so that I know whether I, a timer, the human or a page, or a crash ended it. ^own-teh1
14. As an agent, I want a tab I released and that expiry later closed to report `closed_by_ttl`, so that I can tell it from one the human closed. ^own-nbwk
15. As an operator, I want the idle and unclaimed durations and the tab cap to be configurable, so that I can tune them to how I work. ^own-vhqo
16. As an agent, I want `close` on a tab I own to be idempotent and `close` on a tab owned by another to be `not-owner`, so that cleanup is safe and bounded to what is mine. ^own-7pzw
17. As a human, I want to release or close any tab from the CLI with `--owner` matching its owner, or with `--force`, so that I can clean up after an agent that is gone. ^own-0pnk
18. As an agent, I want ownership state to be lost on a service restart with all handles answering `tab-gone` `browser_lost`, so that the rule is simple and nothing pretends to remember. ^own-5qoh

## Implementation Decisions

- The registry holds per tab: handle, target id, generation, origin, owner state, owner, last-activity instant, and the current snapshot. Owner state is a closed variant: `Unowned`, `Owned of owner`, `With_human of owner`.
- Authorization is one function applied before any tab command: it maps (command, caller owner, tab state) to allow or a typed refusal. `--force` is a protocol flag honoured only for `release` and `close`, intended for humans; it is logged.
- Origin for discovered targets: a target whose opener is an agent-owned tab inherits agent origin and that owner (wiser's adopted popup); any other discovered target is human origin, unowned.
- Expiry runs as one sweep fiber on an Eta schedule every 30 seconds using the Eta clock, so tests drive it with a test clock. Stage 1 releases; stage 2 closes agent-origin unowned tabs whose unowned-since instant is older than the unclaimed duration. Handoff sets no last-activity and is excluded from stage 1.
- Tombstones: on any target destroyed event the registry records disposition `Closed_externally` unless it issued the close itself (`Closed_by_owner` or `Closed_by_ttl`); generation bump records `Browser_lost` for every live tab. Tombstones live one hour.
- Nothing is persisted; the profile is the only state that survives.

## Testing Decisions

- All at the protocol seam with the fake browser and a test clock. Two clients with different owners exercise every authorization cell: own-6ndc, own-pmr7, own-jua9, own-0np9, own-2zs7, own-7pzw, own-0pnk.
- Fake browser emits target-created events with and without an opener: own-c0cl, own-ehqa, own-82jd.
- Clock-driven sweeps: own-uo77, own-hslp, own-2zpi, own-ay3s, own-nbwk, own-vhqo.
- Fake emits target-destroyed and drops the pipe: own-teh1, own-5qoh.

## Out of Scope

Transferring ownership directly to a named owner (release then claim covers it), per-owner caps, persistence.

## Further Notes

- `--force` is the one place a human overrides ownership; it exists because agents die without releasing. If it gets abused by agents, gate it on `owner = human`.

## Live acceptance (L14, headless Chrome 152, scripts/live-acceptance-m3)

Three phases, one service each, all green: ownership (two CLI owners, cross-owner
refusals, release/claim cycle, the outside tab, `--force`), popups (adoption, a
self-closing popup), expiry (stage 1 then stage 2 on a real clock with a 1 s sweep via
the test-only LEASH_SWEEP_INTERVAL_S; a bad value fails fast before Chrome launches).
SIGTERM exits 0 and the managed Chrome is gone after every phase.

- own-c0cl: the outside tab is Chrome's own initial chrome://newtab/ target, announced
  on the target stream with no openerId and adopted as human-origin unowned; it is
  claimable and, claimed then released, survives both expiry stages. A page's
  window.open with 'noopener' was tried for this route and rejected: Chrome still
  reports openerId, so Leash adopts that popup.
- own-ehqa: the adopted popup is verified on the hard path -- an opener-holding
  window.open whose navigation stalls while Chrome withholds the dispatch reply (the
  L10 finding, confirmed: the click got no reply at all before the fix). The opening
  click now answers in about 2 s through the bounded-dispatch fix, with the popup
  listed agent/owned by the opener's owner.
- own-teh1: a loaded (noopener) popup closes itself via a clicked window.close button
  and the handle reports tab-gone closed_externally. The self-closing click wins or
  loses the reply race nondeterministically; the loss reports tab-gone with
  closed_externally from the killing command itself.
- own-uo77, own-hslp: with idle 5 s and unclaimed 12 s, the owned tab is released but
  still open after 9 s, and gone with closed_by_ttl after 22 s; the human tab is
  untouched throughout. The 30 s contract default stands in production.
- own-2zpi is the survival above; own-0pnk is proved by cross-owner --force release
  and close (a force-close reports closed_by_owner).
- Live-only Chrome behaviours found while gating are recorded in docs/cdp-shapes.md
  (L14): the opener-holding/noopener split, session impairment after a withheld
  dispatch, late uncloseable popup debris, and the force-installed extension's stray
  tab. None changes the protocol except one clarification: an action that closes its
  own tab reports tab-gone (docs/protocol.md).
