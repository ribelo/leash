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
| L12 | **Origin and discovery.** `Target.setDiscoverTargets`: tabs opened in the Chrome UI or by pages appear as human-origin unowned; a popup whose opener is an agent-owned tab inherits agent origin and that owner (adopted popup); origin never changes. Tombstones on `targetDestroyed` with `Closed_externally` unless Leash issued the close. | own-c0cl, own-ehqa, own-teh1 | L11 | [x] |
| L13 | **Expiry and disposition.** Sweep fiber as `Retry.repeat` on the mock-testable clock every 30 s; stage 1 releases owned tabs idle past `idle` (default 30 min); stage 2 closes agent-origin unowned tabs unclaimed past `unclaimed` (default 60 min); human-origin never auto-closed; any owner action resets idle; `With_human` excluded; `Closed_by_ttl` vs `Closed_by_owner` vs `Closed_externally` vs `Browser_lost` dispositions; `expires` in `TabInfo`; config keys; restart wipes state. | own-uo77, own-hslp, own-2zpi, own-ay3s, own-nbwk, own-vhqo, own-5qoh | L11 | [x] |
| L14 | **Live acceptance for milestone 3** (headless): two CLI owners; a tab opened by CDP outside Leash appears human-origin and is claimable; a `window.open` popup from an owned tab is adopted; `--force` release; a short-`idle` config proves stage 1 then stage 2 on a real clock (seconds, not minutes); a tab closed via CDP reports `closed_externally`. Marks the spec completed. | own-c0cl, own-ehqa, own-teh1, own-uo77, own-hslp | L12, L13 | [x] |

L12 and L13 are independent after L11.

## Milestone 4 — human handoff (`human-handoff/01-human-handoff.md`)

`With_human` exists in the registry (milestone 3); this milestone gives it its wire path. Human-facing parts (window focus, notification) are best effort and configurable; the state machine and the blocking request are the substance.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L15 | **Milestone-3 follow-ups.** Popup-opening input acknowledged by the popup's `targetCreated` racing the withheld reply (remove the 2 s dispatch bound; keep the target-gone probe for self-closing handlers); `eval` settles the same way; claiming a human tab enables event domains so `debug` covers the claim. Fake-browser scripts for a withheld reply followed by `targetCreated`, and for a slow (3 s) ordinary reply that must still succeed. | tab-0ohq, tab-gjo0, tab-a7l3 | — | [x] |
| L16 | **Handoff and resume.** `handoff {tab, reason, timeout_s?}` blocks on an `Eio.Promise` while the tab is `With_human`; `resume {tab}` completes it (owner or `--force`, and the human's `--owner human` is not the owner, so `resume` is authorized for anyone: it only ever helps the owner); timeout restores `Owned` with `timeout`; client disconnect restores `Owned`; browser loss ends it with `tab-gone browser_lost`; `resume` on a tab nobody is waiting on is `no-handoff`; `resume` resets idle; handoff excluded from idle expiry (already true); `list --all` shows the reason. Protocol: add `no-handoff` to the error table. | hand-lz3p, hand-0sja, hand-nisr, hand-lmd5, hand-len8, hand-r4t1, hand-beip, hand-yytf, hand-szz7 | L15 | [x] |
| L17 | **Human-facing side.** `Target.activateTarget`; configurable `handoff.focus_command` and `handoff.notify_command` run through `Eta_process.Child` with a 5 s grace; `notify-send --action done=Done` whose action return runs `resume`; failures become `warnings` in the reply and a log line, never a handoff failure; `warnings` added to the handoff reply in `docs/protocol.md`. Tested with a fake command runner recording spawns. | hand-04rb, hand-phof, hand-rg9h | L16 | [x] |
| L18 | **Live acceptance for milestone 4.** Headless for the state machine (two CLIs: agent hands off, human resumes; timeout; disconnect); one **headed** run on your desktop, by hand, for focus and notification — record what the niri rule did with `--class=leash` and whether the notification action resumed. Marks the spec completed. | hand-lz3p, hand-lmd5, hand-04rb, hand-phof | L16, L17 | [ ] |

## Milestone 5 — drive (`drive/01-drive.md`)

The JEV loop. Depends on three eta-next rows delivered first: `eta_http` client (row 19), `eta_ai` + System One (row 20), chat (row 21). The request contract is jev-ultrafast's at a pinned commit, copied not adapted; the reference sources are in eta-next `docs/issues/ai-systemone/reference/`.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L19 | **Models wiring.** Config `models.{api_key (Redact), systemone_endpoint, jev_model, chat_base_url, text_model}` with `OPENROUTER_API_KEY` override; `Models` Service creating one TLS `eta_http` client and the System One client; the production Decide wired into the drive; `leash status` reports the models configuration (configured / missing key, never the key); the `Text_helper` seam left for L22. | drive-e7oi, drive-yqxg | eta-next 19–21 | [x] |
| L20 | **Request shaping and decision.** From a snapshot: jev's `elements` (label, role, current_value, states, operations per row), `page.text` from the `text` path, `recent_actions`; the `operation` question with jev's labels, per-operation target questions keyed by index; fail-closed validation of the chosen head only; decision record with probabilities. Pure functions, table-tested against the reference shapes. | drive-y37b, drive-zml5 | L19 | [x] |
| L21 | **The loop as an effect computation.** `Observe`/`Decide`/`Act` with a local handler token (eta-next ADR-0006); production handler; scripted test handler; `--dry-run` handler; step cap, deadline, stall rule (three non-wait no-change steps → blocked), stale-target re-decide, `wait` op (bounded settle then re-observe), `scroll_up/down`, `done`/`blocked`, dialog or popup → `error`, model failures → `error` with detail, trace with elapsed_ms, final snapshot, tab slot held for the duration; `resume`-style guards (owner, not `With_human`, no dialog). | drive-y7v8, drive-xjh6, drive-4zlp, drive-ix5t, drive-qwbp, drive-9y2s, drive-8rts, drive-8zh8, drive-kh2u, drive-tfqh, drive-ig84, drive-n3ld, drive-4bhg, drive-l7yk, drive-8n2z | L20 | [x] |
| L22 | **Text helper.** `TYPE_TEXT` step: jev's `field_context`, `Eta_ai_chat.complete` with json_object and reasoning off, `{text: string|null}` parse, null → blocked naming the field, 4 KiB bound, reuse on unchanged input, values from the goal used verbatim. | drive-ls3c, drive-fh1h | L21 | [x] |
| L23 | **Live acceptance for milestone 5** (headless, real models, real key from the environment): jev's own two tasks — the Wikipedia article goal ("Find and open the Wikipedia article about Gödel's incompleteness theorems") and a Google Flights one-way search verified independently by reading the result page — plus a `--dry-run` on each; record steps, elapsed, usage and cost per run in the spec's status. Marks the spec completed. | drive-y7v8, drive-8zh8, drive-7tvn | L22 | [x] |

L19 can start as soon as eta-next row 19 lands (with the System One and chat clients stubbed behind their interfaces); L20 is pure and can start at once from the reference sources.

## Milestone 6 — service packaging (`service-packaging/01-service-packaging.md`)

The last milestone: the thing you leave running. Stories 13–16 were added from the coordinator's own headed run on 2026-09-27.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L24 | **Config and CLI polish.** Defaults for every non-secret field; `leash config init`; `control.socket`; per-command `--help` with positional names and only the options a command uses; title refresh after action navigation. | svc-ljl3, svc-kzt6, svc-tkor, svc-x8rp, svc-o4wt, svc-hi4f | — | [x] |
| L25 | **Diagnostics.** Chrome stderr ring per generation in the `generation lost` entry; journal fields (tab, owner, cmd) verified on every command; redaction test that `fill` text, `text` results, API key and userinfo never reach a log line; optional OTLP export via `eta_otel` switched by config. | svc-p67t, svc-qilu, svc-f4op, svc-qrmc | — | [x] |
| L26 | **Unit and install.** systemd user unit as the spec describes; `nix build .#leash` output installed to the profile the way Pie's is (read Pie's flake/home-manager for the pattern); listener refuses a second instance; `leash status` as the health check; the niri rule documented in `README.md`. | svc-dit8, svc-gxhu, svc-5wm8, svc-46f0 | L24 | [ ] |
| L27 | **The `leash` skill.** New skill at `/home/ribelo/.dotfiles/skills/engineering/debugging/leash/` in the chrome-cdp skill's minimize-output style, covering new/snap/click/fill/text/eval/shot/debug/handoff/drive; the old chrome-cdp skill left in place until L28. Verified by an agent completing the chrome-cdp workflow (open a page, find a control, act, read the result) through `leash` only. | svc-itcb | L24 | [x] |
| L28 | **Live acceptance for milestone 6**, headed, on the operator's desktop with the operator present: install the unit, start it, watch Chrome land on the `leash` workspace, run the L27 workflow from a DSH session, trigger one handoff and click Done, `systemctl --user restart leash`, confirm tabs are gone and the profile's login survived. Together with L18. Marks the spec completed and the project usable. | svc-dit8, svc-xafg, chrome-2y3t, hand-04rb, hand-phof | L25, L26, L27 | [ ] |

L24, L25 and L27 are independent; L26 after L24. L28 needs the operator.

## Later milestones

After milestone 6: the drive-spec follow-ups (tab title after navigation is in L24), an inspector handler for `drive` (pause at `Decide` for a human, jev's "Choose next"), and iframes, each as its own spec when wanted.

## Definition of done, every row

- Every story listed has a test citing its ID by name; `nix develop -c dune build @install`, `nix develop -c dune test` and `nix develop -c dune build @fmt` are green (add `.ocamlformat` in L0, same version as eta-next).
- No test touches a real browser, socket path outside a temp dir, or the network; live checks live only in `scripts/live-acceptance`.
- The safety defaults in `AGENTS.md` hold; anything in `docs/protocol.md` that the implementation forces to change is changed there in the same commit.
- Commit messages cite story IDs; the milestone spec's `status:` goes to `completed` when L3 lands, with the live-acceptance result recorded.
- When something is an effect-shaped resource or lifecycle concern without a browser concept, stop and write an eta-next spec instead of building it here (ADR-0001, ADR-0008).
