---
status: ready-for-agent
milestone: 11
---

# Handles are capabilities: no owner, one tab rule

## Problem Statement

On 2026-10-01 the operator read `leash --help` as a newcomer and could not find what `owner` is. It is a string the agent invents, passed on every command, defaulted from `DSH_SESSION_ID`, and checked against nothing: two agents saying `--owner alice` are one agent. It was built for attribution (ADR-0005: a hundred tabs nobody can attribute) and became an access model by accident, costing a flag on every command, two error codes, a claim/release state machine, 300 lines of `tabs.ml`, 1,157 lines of tests and the skill's longest paragraph — and it ties the CLI to one harness's environment variable. Meanwhile the tab handle is already 128 random bits, which is the credential the design needs. Separately, the operator opens tabs himself and tells an agent to work in them; he has no way to obtain a handle and no extension will be shipped; and what happens to such a tab afterwards must be a rule a newcomer can predict.

## Solution

ADR-0010. The handle is the capability: hold it, act; no owner anywhere. Agents find tabs by `list` (labels, URLs, origins, ages, never handles) and act only with a handle they were given by `new` or minted by `take`. One tab rule: agent tabs close when idle; human tabs are never closed until an agent takes one, which makes it an agent tab. `handoff`/`resume` stay, keyed on the handle.

## User Stories

### No owner

1. As an agent, I want every command to take only the tab handle, with no `--owner` option, no owner field in the protocol, and no default read from `DSH_SESSION_ID` or any environment variable, so that holding a handle is the whole story and the tool works from any shell. ^hand-scaz
2. As a maintainer, I want `claim`, `release`, the `not-owner` and `already-owned` codes, the `Unowned`/`Owned` states and the idle-release expiry stage removed, with the authorization matrix reduced to the `With_human` row, so that the model is as small as the rule. ^hand-qos2
3. As a maintainer, I want a handle presented for a tab that does not exist (closed, expired, never existed, or minted in an earlier browser generation) to answer `unknown-tab` or `tab-gone` with the disposition as today, and a handle never to be guessable (128 bits from the system's randomness, asserted by a test), so that the capability is sound. ^hand-mb9s
4. As an agent, I want two holders of one handle (a handle handed over) to have their actions serialized on the tab as today, with a test that interleaved actions from two connections on one handle never overlap, so that sharing by hand-over is safe without the service knowing about it. ^hand-0wo8

### Finding and taking tabs

5. As an agent, I want `list` to show every tab in the browser — `label`, `url`, `title`, `origin`, `age_s`, `idle_s`, `closes_in_s` (agent tabs), `with_human` — and never a handle, so that I can find a tab the human told me about without being able to act on tabs I was not given. ^hand-x3hi
6. As an agent, I want `new [URL] [--label TEXT]` to accept a free label shown in `list`, so that a human reading the list sees `allegro cart (agent: dsh-1234)` instead of a URL alone. ^hand-ryxz
7. As an agent, I want `take --url PREFIX | --title TEXT | --label TEXT` to mint a handle for exactly one matching tab, refuse with `ambiguous` listing the matches when several match and `no-match` when none, and set the tab's origin to `agent` from that moment, so that 'take care of my Allegro cart' is one command and the rule for the tab afterwards is the agent rule. ^hand-okk8
8. As an agent, I want `take` on a tab that already has a live handle (another agent's) to refuse with `taken` and a hint to ask the holder for the handle, so that one tab has one capability at a time unless it is handed over on purpose. ^hand-gjqy
9. As the operator, I want `take`'s origin flip logged with the tab's URL and the time, so that a human tab that later closed can be traced to the take. ^hand-k1ag

### One tab rule

10. As the operator, I want an agent tab (origin `agent`, by `new` or by `take`) closed when its handle has not been used for the idle duration (default 30 minutes; `handoff` pauses the clock), with a tombstone `closed_by_idle`, so that abandoned tabs go away by one rule. ^hand-0ibq
11. As the operator, I want a human tab (origin `human`, never taken) never closed by Leash, not even after the browser has been running for days, so that my own tabs are mine. ^hand-ihcg
12. As the operator, I want the rule stated in `leash help handles`, in `list`'s `--help`, and in the first-run orientation in one sentence — 'agent tabs close after 30 idle minutes; your tabs are never closed unless an agent takes one' — so that it is predictable because it is read. ^hand-3v5u

### Handoff stays

13. As an agent, I want `handoff HANDLE REASON` and `resume HANDLE` unchanged in meaning: the tab is `with_human`, every action on the handle is refused with `with-human` until resume, the notification and the wait as today, so that asking the human to pass a CAPTCHA or a login survives the removal of ownership. ^hand-fr87
14. As an agent, I want a tab in `with_human` to be `take`-able by nobody and to show `with_human: true` in `list`, so that a handoff is visible and uninterruptible. ^hand-0o28

### Everything that mentioned owner

15. As a maintainer, I want `drive`, `discover`, `playbook check NAME`, `playbook test` and every command that opened or used tabs on the caller's behalf to work purely by handle — a `drive` without `--tab` opens an agent tab and closes it at the end as today — so that no command keeps an owner by another name. ^hand-0y04
16. As a maintainer, I want the protocol document, `CONTEXT.md` (Owner, Owner state, Claim/release removed; Handle, Take, Origin rewritten), ADR-0005 marked superseded by ADR-0010, the skill, the error table and `help errors` updated, so that no document describes the old model. ^hand-qy26
17. As a maintainer, I want the 108-cell authorization test replaced by a table of (command × {no handle, bad handle, live handle, with_human handle, closed handle}) outcomes, so that the smaller model is as pinned as the old one. ^hand-oyzl
18. As a maintainer, I want the live gates and the installed service updated, the skill refreshed on this machine, and one fresh-agent run (`subagent_claude_sonnet`, knowing only the skill) that opens a tab, takes a human tab the operator opened, works in both and hands one off, so that the model is proven where it will be used. ^hand-7m8x
19. As the operator, I want the Chrome profile's existing human tabs (the `chrome://newtab` and whatever else is open) untouched by the upgrade, so that the switch does not close anything of mine. ^hand-amp5
20. As a maintainer, I want the removal to be a removal: no `--owner` accepted-and-ignored, no `claim` alias, no `not-owner` kept 'for compatibility' (pre-1.0), so that the old concept leaves no trace an agent can trip on. ^hand-w85z
21. As an agent, I want a handle used after its tab was closed by idle to answer `tab-gone` with `closed_by_idle` and the hint 'open a new tab with `leash new`', so that the one rule is explained at the one moment it bites. ^hand-s4cq
22. As a maintainer, I want the ADR's rejected options (peer credentials, flat pool, labels as access, reverting human tabs) kept in ADR-0010 with their reasons, so that the next person who proposes one finds the answer. ^hand-iyyk

## Implementation Decisions

- The ledger keys tabs by handle; a human tab without a handle has none until `take`. `take` matches on the current URL prefix, title substring, or label (exact), case-insensitive.
- `with_human` is a flag on the tab entry, not a state machine; handoff sets it, resume clears it, idle is paused while set.
- Expiry sweep: for each agent tab, `now - last_use > idle` → close with `closed_by_idle`. Nothing else.
- The CLI keeps `--socket`/`--config`; everything else is positional handles.
- Logs never carry handles (they already do not); `take` logs URL and time.

## Testing Decisions

- Protocol seam: the new outcome table (story 17); `take` ambiguity/no-match/taken; expiry by one rule; handoff refusals; two-connection serialization on one handle; human tabs survive a sweep. Live: story 18.

## Out of Scope

Authentication between agents; a browser extension; reverting a taken tab to human; multi-user.

## Further Notes

Operator, 2026-10-01: 'better wrong but predictable'; sharing between agents is by hand-over or not at all; a lost handle is a closed tab and a new one; human tabs may be taken by agents, not the reverse. Coordinator's two departures, with the operator's trust: `handoff` stays (it is the agent asking the human, keyed on the handle, and the field report needed it twice); `take` exists because the human cannot hold a handle and `list` is the only way to name a tab without an extension.
