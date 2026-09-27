# Leash delivery map

Each row is one worker's job. The behaviour is specified in the milestone specs (`<slug>/01-<slug>.md`); this map only slices them into deliverable pieces and fixes the order. Read `../../AGENTS.md`, `../../CONTEXT.md`, `../protocol.md`, `../adr/` and the milestone spec before starting a row. eta-next (`/home/ribelo/projects/ribelo/ocaml/eta-next`, rows 0–13 delivered) is the kernel: its `docs/why-next.md`, `docs/modes.md` and the `.mli` files under `lib/` are the interfaces; the milestone-1 spec's "Shape against eta-next" section names which ones each module uses.

## Milestone 1 — managed Chrome (`managed-chrome/01-managed-chrome.md`)

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L0 | **Skeleton and test harness.** Library layout `packages/leash/{config,chrome,cdp,tabs,control,protocol}.ml(i)`, `packages/leash/bin/main.ml` as the Door program, `test/` with `Eta_test`; the **fake browser**: a scripted CDP peer over switch-owned Eio pipes speaking NUL-delimited JSON, answering `Target.*`/`Page.*` from a table, emitting events on cue, able to drop the pipe. Gates green with a placeholder test. | (harness for all) | — | [x] |
| L1 | **Config, Door, CLI** (its `Config` and protocol types wait for eta-next rows 15–16; the Door program and CLI do not). `Config` as a derived-codec record (chrome.binary, profile_dir, workspace, tabs.cap, expiry durations, model keys; secrets as `Redact.t`; constrained values as smart-constructor modules; the Door's `validate` hook and an `env` override function); protocol request/reply types with `[@@deriving yojson]`; the program skeleton (`Eta_app.run` → services → `serve`); the `leash` Cmdliner client encoding every command in `docs/protocol.md` to one request and printing the reply (`--pretty`, `--table`, `--owner`, `DSH_SESSION_ID` default, exit codes 0/1/2). `leash config check` free from the Door. | chrome-38a4, chrome-fuao (shape), svc-ljl3, svc-kzt6, svc-tkor | L0 | [x] |
| L2 | **Chrome service and CDP transport.** `Chrome` Service over `Supervised.start` + `Child.spawn ~fds:[(3,_);(4,_)]` with this spec's flags; `Cdp` framing + `Correlator`; generation; `Browser_lost` on transport close; `browser-unavailable` during restart; orderly stop. Tested with the fake process manager and the fake browser; one live-acceptance script launching real Chrome (`scripts/live-acceptance`, on demand). | chrome-p2n4, chrome-9ex7, chrome-qo4q, chrome-2z2z, chrome-6lfk, chrome-b288; chrome-2y3t is headless-unverifiable and remains best-effort, not delivered | L0 | [x] |
| L3 | **Tabs registry, basic lifecycle, control socket.** `Tabs` Service: handles, origin, owner = creator, tombstones; `new`, `nav` (load-complete semantics, URL policy), `close` (idempotent), `list`, `status`; tab cap fail-fast; `Control` Service over `Listener.run` with per-command budgets, protocol decode/encode through the schema, `invalid-request` with a pointer. End-to-end: CLI → socket → registry → fake browser. | chrome-qnul, chrome-1yn9, chrome-akz4, chrome-2n8n, chrome-hjw9, chrome-fuao, chrome-fwnu, chrome-38a4, chrome-d4mz, chrome-2z2z | L1, L2 | [x] |
| L4 | **Snapshot-source spike** (ADR-0004). Tracked research bundle under `.scratch/research/snapshot-source/`: element table from an injected DOM script vs Chrome's accessibility tree, same five pages, measuring latency, rows, CDP calls, name correctness against a hand-labelled list. Ends with a written decision in `tab-observation-and-actions/01-…md` "Further Notes" (the "Snapshot source" line), not code in `lib/`. Needs real Chrome; use L2's launcher. | ADR-0004; unblocks milestone 2 | L2 | [x] |

L1 and L2 are independent after L0. L3 is the milestone's acceptance: when it is green, milestone 1 is done and `leash new https://example.com && leash list && leash close` works against real Chrome through the live-acceptance script.

## Milestone 2 — observation and actions (`tab-observation-and-actions/01-…md`)

Snapshot source is decided (spec Further Notes): accessibility tree + `DOMSnapshot` joined on backend node id, guarded by loader id and a per-document mutation counter, `settled` flag, action-time revalidation. `docs/protocol.md` is updated.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L5 | **`new` waits for load** when given a url (title populated), same wait as `nav`; live acceptance re-run. Small; do first. | chrome-qnul (behaviour clarified in spec) | — | [x] |
| L6 | **Snapshot.** Mutation-counter script via `Page.addScriptToEvaluateOnNewDocument`; `Accessibility.getFullAXTree` + `DOMSnapshot.captureSnapshot` join; row shaping (index, role, name, value, states) in reading order, viewport filter; guard and retake; `settled`; snapshot ids and invalidation; `snap` with `match`/`limit`/`offset`; dialog reported in the snapshot; `--table` rendering in the CLI. Fake browser extended with AX/DOMSnapshot shapes recorded from real Chrome (extend `docs/cdp-shapes.md`). | tab-of0i, tab-tmoc, tab-1r34, tab-hyap, tab-1rx9, tab-0vh8, tab-ok2i | L5 | [x] |
| L7 | **Actions.** Action-time revalidation (loader id, `describeNode`, `getContentQuads`, hit-test), `click`, `fill` (focus + `Input.insertText`), `press`, `select`, `scroll`, post-action settle (200 ms for combobox suggestions, else two frames/50 ms), `ActionResult` with url/title/popups, per-tab serialization, `dialog-open` refusal, never retried, focus emulation on attach. | tab-bw4j, tab-j1z2, tab-p3x1, tab-luo5, tab-5deq, tab-8dop, tab-tm6c, tab-hxld, tab-60kn, tab-1lhx, tab-8la3 | L6 | [x] |
| L8 | **Reading, waiting, evaluating, diagnosing.** `wait` (ANDed conditions, bounded), `text`, `eval` (function body with argument, 64 KiB bounds), `shot` (PNG to an absolute path, 20 MiB), `debug` ring (console, exceptions, failed requests, 200 entries), `dialog accept|dismiss`, never auto-answered, `too-large`. | tab-9x5e, tab-x4v0, tab-a33o, tab-qmei, tab-5vnm, tab-un75, tab-fepr, tab-0lax | L6 | [x] |
| L9 | **Live acceptance for milestone 2** on public search and labelled native-select pages, plus deterministic local overlay/clock/focus pages (public overlay and mutation timing drift): visibility filter, occlusion refusal, background-tab focus emulation, one snapshot with `settled:false`. Real AX/DOMSnapshot shapes recorded in `docs/cdp-shapes.md`; spec completed. | tab-tmoc, tab-8la3, and occlusion in tab-bw4j | L7, L8 | [x] |

L7 and L8 are independent after L6.

## Milestone 3 — ownership, claim/release, expiry, disposition (`tab-ownership/01-tab-ownership.md`)

Ownership today is "the creator owns it" (milestone 1). This milestone makes owner state a real variant, adds claim/release, the two-stage expiry, human-origin discovery, tombstone dispositions, and the human's `--force`. ADR-0005 is the contract.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L10 | **Milestone-2 follow-ups.** Empty-name controls kept in the table with role and value/placeholder; `popups` exact via `openerId`; `ActionResult.snapshot` documented as always null. Fake browser and one fixture from real Chrome for an unlabelled select. | tab-zc36, tab-8k2g | — | [x] |
| L11 | **Owner state and authorization.** `Unowned | Owned of owner | With_human of owner` in the registry; one authorization function applied before every tab command (act/close/dialog/release require owner; claim requires unowned; `not-owner`, `already-owned`, `with-human`); `claim`, `release`; `list` filtered by owner, `--all` with origin, state, owner; `--force` for `release`/`close` (logged). Two-client protocol tests over every authorization cell. | own-6ndc, own-pmr7, own-jua9, own-0np9, own-2zs7, own-82jd, own-7pzw, own-0pnk | L10 | [x] |
| L12 | **Origin and discovery.** `Target.setDiscoverTargets`: tabs opened in the Chrome UI or by pages appear as human-origin unowned; a popup whose opener is an agent-owned tab inherits agent origin and that owner (adopted popup); origin never changes. Tombstones on `targetDestroyed` with `Closed_externally` unless Leash issued the close. | own-c0cl, own-ehqa, own-teh1 | L11 | [ ] |
| L13 | **Expiry and disposition.** Sweep fiber as `Retry.repeat` on the mock-testable clock every 30 s; stage 1 releases owned tabs idle past `idle` (default 30 min); stage 2 closes agent-origin unowned tabs unclaimed past `unclaimed` (default 60 min); human-origin never auto-closed; any owner action resets idle; `With_human` excluded; `Closed_by_ttl` vs `Closed_by_owner` vs `Closed_externally` vs `Browser_lost` dispositions; `expires` in `TabInfo`; config keys; restart wipes state. | own-uo77, own-hslp, own-2zpi, own-ay3s, own-nbwk, own-vhqo, own-5qoh | L11 | [ ] |
| L14 | **Live acceptance for milestone 3** (headless): two CLI owners; a tab opened by CDP outside Leash appears human-origin and is claimable; a `window.open` popup from an owned tab is adopted; `--force` release; a short-`idle` config proves stage 1 then stage 2 on a real clock (seconds, not minutes); a tab closed via CDP reports `closed_externally`. Marks the spec completed. | own-c0cl, own-ehqa, own-teh1, own-uo77, own-hslp | L12, L13 | [ ] |

L12 and L13 are independent after L11.

## Later milestones

4 `human-handoff`, 5 `drive`, 6 `service-packaging` — sliced when milestone 3 lands; their specs are complete.

## Definition of done, every row

- Every story listed has a test citing its ID by name; `nix develop -c dune build @install`, `nix develop -c dune test` and `nix develop -c dune build @fmt` are green (add `.ocamlformat` in L0, same version as eta-next).
- No test touches a real browser, socket path outside a temp dir, or the network; live checks live only in `scripts/live-acceptance`.
- The safety defaults in `AGENTS.md` hold; anything in `docs/protocol.md` that the implementation forces to change is changed there in the same commit.
- Commit messages cite story IDs; the milestone spec's `status:` goes to `completed` when L3 lands, with the live-acceptance result recorded.
- When something is an effect-shaped resource or lifecycle concern without a browser concept, stop and write an eta-next spec instead of building it here (ADR-0001, ADR-0008).
