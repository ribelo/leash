---
status: ready-for-agent
milestone: 8
---

# Hardening 2: the tools an agent reaches for when debugging a page

## Problem Statement

Compared on 2026-09-28 against what agents actually do with the old chrome-cdp script, Leash lacks six things that come up in the first week of use: seeing what the page requested and what came back (debug records only failures), waiting longer than 30 seconds, uploading a file, hovering to open a menu, running JavaScript against a specific snapshot row, and reading cookies and storage (httpOnly cookies are invisible to `eval`). Each is small; together they are the difference between Leash and the script it replaces.

## Solution

Six additions, each a thin client of existing CDP domains and existing service paths: `net`, a longer and change-aware `wait`, `upload`, `hover`, `eval --index`, and read-only `cookies`/`storage`.

## User Stories

1. As an agent, I want `leash net <tab> [--match TEXT] [--limit N] [--type xhr|fetch|document|...]` to list the recent requests of that tab only (Chrome delivers network events per tab session; each tab has its own ring, owner-bound like every tab command) — id, method, url, status, resource type, mime, encoded size, duration, from cache — from a bounded per-tab ring (500 entries), so that I can see what the page called. ^hard-xg6y
2. As an agent, I want `leash net <tab> body <id>` to return the response body (text, or base64 with a flag for binary) bounded to 1 MiB, and a clear `body-unavailable` when Chrome has evicted it, so that I can read an internal API's JSON. ^hard-ovbx
3. As an agent, I want `leash net <tab> request <id>` to return the request's headers and post data (bounded), so that I can reproduce a call in a playbook script. ^hard-vq5s
4. As an agent, I want `wait` to accept timeouts up to one hour, with the listener's handler budget derived from it and a client disconnect cancelling it, so that I can wait for a build, an upload or a queue without polling. ^hard-sr9v
5. As an agent, I want `wait --changed-since <snapshot>` to return as soon as the page's loader id or mutation counter differs from that snapshot's, so that "tell me when this page changes" is one call. ^hard-sckn
6. As an agent, I want `leash upload <tab> <snapshot> <index> <path>...` to set files on a file-input row (revalidated like any action), with absolute readable paths, at most 10 files and 50 MiB total, so that I can attach files to forms. ^hard-o3za
7. As an agent, I want file inputs to appear in the snapshot table with role `file-input` (they are otherwise easy to miss behind a styled button), so that upload has a target. ^hard-2gnf
8. As an agent, I want `leash hover <tab> <snapshot> <index>` to move the mouse to the row's revalidated point and settle, so that hover menus open and their items appear in the next snapshot. ^hard-v1gs
9. As an agent, I want `eval --index N --snapshot S` to call my expression with the row's element as a second parameter (`(argument, element)`), so that I can inspect or read one element without writing a selector. ^hard-b20d
10. As an agent, I want `leash cookies <tab>` (read-only, for the tab's URL, including httpOnly with its flags) and `leash storage <tab> local|session` (read-only), with values returned to the owner and never logged, so that I can debug authentication. ^hard-ufb7
11. As a maintainer, I want every addition in `docs/protocol.md`, the fake browser scripting the new CDP methods, and one live check per addition in `scripts/live-acceptance-m8`, so that the surface is pinned. ^hard-wk6q
12. As an agent, I want the `leash` skill to cover `net`, the long `wait`, `upload`, `hover`, `eval --index`, `cookies` and `storage` in its minimize-output style, so that I use them instead of reaching for chrome-cdp. ^hard-2cal
13. As an operator, I want ten agents working at once — five blocked in long `wait`s on five different tabs while five others act — to be served without queuing or refusal: `wait` never takes the tab's action lock, the control socket admits 64 concurrent requests (up from eta_ipc's default 16), and a test runs ten concurrent clients over the socket to prove it, so that long waits are cheap for everyone else. ^hard-b1na

## Implementation Decisions

- `net` is fed by `Network.requestWillBeSent`, `responseReceived`, `loadingFinished`, `loadingFailed` (the domain is already enabled per tab); bodies via `Network.getResponseBody`, post data via `Network.getRequestPostData`. The ring holds metadata only; bodies are fetched on demand.
- URLs and bodies are page data returned to the owner; none of it reaches a log line (the existing redaction test is extended).
- `wait` bound becomes 3,600,000 ms; `--changed-since` reuses the snapshot guard's loader id and mutation counter.
- `upload` uses `DOM.setFileInputFiles` on the row's backend node id; `hover` uses `Input.dispatchMouseEvent` `mouseMoved` after the usual revalidation.
- `eval --index` resolves the row's node with `DOM.resolveNode` and passes it to `Runtime.callFunctionOn` as the second argument.
- `cookies` uses `Network.getCookies` with the tab's URL; `storage` uses `DOMStorage.getDOMStorageItems` for the tab's security origin. No write counterparts in this row.

## Testing Decisions

- Protocol-seam tests with the fake browser for each story; the live gate adds a local page with a file input, a hover menu, a fetch to a local JSON endpoint, and a cookie set by the local server with HttpOnly.

## Out of Scope

Writing cookies or storage; network interception or mocking; HAR export; raw CDP; iframes.
