---
status: completed
milestone: 12
---

# Traces are kept

## Problem Statement

A `drive` returns its trace in the reply and forgets it. Every step already records the snapshot, the operation, the target, JEV's probabilities over every option, the typed text and the outcome — the raw material of a procedure — and it dies with the connection. Nothing learned yesterday exists today, and there is no audit log of what agents did in the browser.

## Solution

Every drive writes its trace to `$XDG_STATE_HOME/leash/traces/<site>/<timestamp>-<outcome>.json` with the mission, the page-kind path, outcome, cost and duration; retention is bounded; `leash traces list|show|prune` read it; the compiler (milestone 12's third row) reads from here.

## User Stories

1. As the operator, I want every `drive` — on the fly or through a playbook, any outcome — to write its full trace to `$XDG_STATE_HOME/leash/traces/<site>/<utc-timestamp>-<outcome>.json` after the run ends, with `site`, `mission`, `outcome`, `cost`, `duration_ms`, `model_calls`, `page_kind_path` (the ordered list of page kinds visited, inferred or declared), `procedures` chosen and `steps`, so that a run is evidence after it is over. ^trace-qe8c
2. As the operator, I want traces never to contain page text, typed secrets (password fills are recorded as `[password]`), cookies or handles, with the existing redaction test extended to the trace file, so that the audit log is safe to keep. ^trace-iqqz
3. As the operator, I want retention bounded per site — keep every `done` trace not yet compiled, the last 20 traces of any outcome, and nothing older than 30 days unless uncompiled — with `traces.retention` in config, so that state does not grow without limit. ^trace-dqr2
4. As an agent, I want `leash traces list [--site S] [--outcome O]` (tab-separated: time, site, outcome, cost, steps, mission) and `leash traces show FILE` (the JSON), so that a past run can be read without the reply that carried it. ^trace-zbb9
5. As the operator, I want `leash traces prune [--site S] [--dry-run]` to apply retention now and report what it removed, so that the store can be emptied by hand. ^trace-uovo
6. As an agent, I want the drive reply to carry `trace_path`, so that the run and its file are linked. ^trace-o6ld
7. As a maintainer, I want the trace file's shape to be the protocol's `drive_result` plus the header fields, decoded by the same type (`[@@deriving yojson]`), so that there is one trace shape. ^trace-lg58
8. As a maintainer, I want `traces` to require no model and no browser (pure file reads), and a config key `traces.enabled` (default true) for the write, so that the store is cheap and switchable. ^trace-szpg

## Implementation Decisions

- Site = the registrable domain of the first non-blank URL in the run (`allegro.pl`, `toscrape.com` for `books.toscrape.com`; frozen Mozilla PSL including private suffixes); on-the-fly runs across sites write one trace per run under the first site.
- Approved deviation: persistence completes synchronously before reply encoding in the run's own scope. This ensures `trace_path` already exists; a write failure is logged, never returned as a drive failure. No asynchronous queue or Ox changes.
- Approved deviation from trace-lg58: the live reply and durable file share derived typed codecs, but the file is a separate safe `Protocol.drive_trace` projection. The live reply contains handles, raw state, and records forbidden by trace-uovo.
- Retention defaults to count 20 (1..10000) and days 30 (1..3650), per site. Keep the newest count within the age bound; exempt uncompiled done traces from both. `compiled` defaults false and may become true only after a compiler durably accepts the resulting procedure. L51 never marks it.
- UTC microsecond filenames, directories 0700, files 0600. Failed drives without an observed HTTP(S) host use `unknown`. Offline commands refuse symlinks, malformed files, and files larger than 8 MiB.

## Testing Decisions

- Protocol seam: a scripted drive writes the file with the expected header; redaction; retention table with a mock clock; `traces list/show/prune` over a temporary state dir.

## Out of Scope

Remote storage; traces of non-drive commands.

## Live verification — 2026-10-01

Both public drive lanes wrote private redacted trace files with matching costs and calls; offline list/show/prune worked after service shutdown. See [live evidence](live-2026-10-01.md). Subsequent regressions preserve uppercase JEV operation probabilities and resolve relative output paths against the caller.
