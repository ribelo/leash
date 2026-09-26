# Leash delivery map

Each row is one worker's job. The behaviour is specified in the milestone specs (`<slug>/01-<slug>.md`); this map only slices them into deliverable pieces and fixes the order. Read `../../AGENTS.md`, `../../CONTEXT.md`, `../protocol.md`, `../adr/` and the milestone spec before starting a row. eta-next (`/home/ribelo/projects/ribelo/ocaml/eta-next`, rows 0–13 delivered) is the kernel: its `docs/why-next.md`, `docs/modes.md` and the `.mli` files under `lib/` are the interfaces; the milestone-1 spec's "Shape against eta-next" section names which ones each module uses.

## Milestone 1 — managed Chrome (`managed-chrome/01-managed-chrome.md`)

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L0 | **Skeleton and test harness.** Library layout `packages/leash/{config,chrome,cdp,tabs,control,protocol}.ml(i)`, `packages/leash/bin/main.ml` as the Door program, `test/` with `Eta_test`; the **fake browser**: a scripted CDP peer over `Eio_mock.Flow` pairs speaking NUL-delimited JSON, answering `Target.*`/`Page.*` from a table, emitting events on cue, able to drop the pipe. Gates green with a placeholder test. | (harness for all) | — | [ ] |
| L1 | **Config, Door, CLI.** `Config` schema (chrome.binary, profile_dir, workspace, tabs.cap, expiry durations, model keys; secrets and `OPENROUTER_API_KEY` marked); the program skeleton (`Eta_app.run` → services → `serve`); the `leash` Cmdliner client encoding every command in `docs/protocol.md` to one request and printing the reply (`--pretty`, `--table`, `--owner`, `DSH_SESSION_ID` default, exit codes 0/1/2). `leash config check` free from the Door. | chrome-38a4, chrome-fuao (shape), svc-ljl3, svc-kzt6, svc-tkor | L0 | [ ] |
| L2 | **Chrome service and CDP transport.** `Chrome` Service over `Supervised.start` + `Child.spawn ~fds:[(3,_);(4,_)]` with this spec's flags; `Cdp` framing + `Correlator`; generation; `Browser_lost` on transport close; `browser-unavailable` during restart; orderly stop. Tested with the fake process manager and the fake browser; one live-acceptance script launching real Chrome (`scripts/live-acceptance`, on demand). | chrome-p2n4, chrome-9ex7, chrome-2y3t, chrome-qo4q, chrome-2z2z, chrome-6lfk, chrome-b288 | L0 | [ ] |
| L3 | **Tabs registry, basic lifecycle, control socket.** `Tabs` Service: handles, origin, owner = creator, tombstones; `new`, `nav` (load-complete semantics, URL policy), `close` (idempotent), `list`, `status`; tab cap fail-fast; `Control` Service over `Listener.run` with per-command budgets, protocol decode/encode through the schema, `invalid-request` with a pointer. End-to-end: CLI → socket → registry → fake browser. | chrome-qnul, chrome-1yn9, chrome-akz4, chrome-2n8n, chrome-hjw9, chrome-fuao, chrome-fwnu, chrome-38a4, chrome-d4mz, chrome-2z2z | L1, L2 | [ ] |
| L4 | **Snapshot-source spike** (ADR-0004). Tracked research bundle under `.scratch/research/snapshot-source/`: element table from an injected DOM script vs Chrome's accessibility tree, same five pages, measuring latency, rows, CDP calls, name correctness against a hand-labelled list. Ends with a written decision in `tab-observation-and-actions/01-…md` "Further Notes" (the "Snapshot source" line), not code in `lib/`. Needs real Chrome; use L2's launcher. | ADR-0004; unblocks milestone 2 | L2 | [ ] |

L1 and L2 are independent after L0. L3 is the milestone's acceptance: when it is green, milestone 1 is done and `leash new https://example.com && leash list && leash close` works against real Chrome through the live-acceptance script.

## Later milestones

2 `tab-observation-and-actions`, 3 `tab-ownership`, 4 `human-handoff`, 5 `drive`, 6 `service-packaging` — sliced when milestone 1 lands; their specs are complete.

## Definition of done, every row

- Every story listed has a test citing its ID by name; `nix develop -c dune build @install`, `nix develop -c dune test` and `nix develop -c dune build @fmt` are green (add `.ocamlformat` in L0, same version as eta-next).
- No test touches a real browser, socket path outside a temp dir, or the network; live checks live only in `scripts/live-acceptance`.
- The safety defaults in `AGENTS.md` hold; anything in `docs/protocol.md` that the implementation forces to change is changed there in the same commit.
- Commit messages cite story IDs; the milestone spec's `status:` goes to `completed` when L3 lands, with the live-acceptance result recorded.
- When something is an effect-shaped resource or lifecycle concern without a browser concept, stop and write an eta-next spec instead of building it here (ADR-0001, ADR-0008).
