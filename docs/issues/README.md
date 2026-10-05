# Leash delivery map

Completed rows record their original contracts. L49 and ADR-0010 supersede earlier
tab-attribution and two-stage expiry clauses; use the current protocol and capability
spec for tab access, discovery, handoff, and closing behavior.

Each row is one worker's job. The behaviour is specified in the milestone specs (`<slug>/01-<slug>.md`); this map only slices them into deliverable pieces and fixes the order. Read `../../AGENTS.md`, `../../GLOSSARY.md`, `../protocol.md`, `../adr/` and the milestone spec before starting a row. Ox (`/home/ribelo/projects/ribelo/ocaml/ox`, branch `master`, formerly ox) is the kernel: its `docs/why-ox.md`, `docs/modes.md` and the `.mli` files under `lib/` are the interfaces; the milestone-1 spec's "Shape against ox" section names which ones each module uses.

## Milestone 1 — managed Chrome (`managed-chrome/01-managed-chrome.md`)

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L0 | **Skeleton and test harness.** Library layout `packages/leash/{config,chrome,cdp,tabs,control,protocol}.ml(i)`, `packages/leash/bin/main.ml` as the Door program, `test/` with `Ox_test`; the **fake browser**: a scripted CDP peer over switch-owned Eio pipes speaking NUL-delimited JSON, answering `Target.*`/`Page.*` from a table, emitting events on cue, able to drop the pipe. Gates green with a placeholder test. | (harness for all) | — | [x] |
| L1 | **Config, Door, CLI** (its `Config` and protocol types wait for ox rows 15–16; the Door program and CLI do not). `Config` as a derived-codec record (chrome.binary, profile_dir, workspace, tabs.cap, expiry durations, model keys; secrets as `Redact.t`; constrained values as smart-constructor modules; the Door's `validate` hook and an `env` override function); protocol request/reply types with `[@@deriving yojson]`; the program skeleton (`Ox_app.run` → services → `serve`); the `leash` Cmdliner client encoding every command in `docs/protocol.md` to one request and printing the reply (`--pretty`, `--table`, `--owner`, `DSH_SESSION_ID` default, exit codes 0/1/2). `leash config check` free from the Door. | chrome-38a4, chrome-fuao (shape), svc-ljl3, svc-kzt6, svc-tkor | L0 | [x] |
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
| L17 | **Human-facing side.** `Target.activateTarget`; configurable `handoff.focus_command` and `handoff.notify_command` run through `Ox_process.Child` with a 5 s grace; `notify-send --action done=Done` whose action return runs `resume`; failures become `warnings` in the reply and a log line, never a handoff failure; `warnings` added to the handoff reply in `docs/protocol.md`. Tested with a fake command runner recording spawns. | hand-04rb, hand-phof, hand-rg9h | L16 | [x] |
| L18 | **Live acceptance for milestone 4.** Headless for the state machine (two CLIs: agent hands off, human resumes; timeout; disconnect); one **headed** run on your desktop, by hand, for focus and notification — record what the niri rule did with `--class=leash` and whether the notification action resumed. Marks the spec completed. | hand-lz3p, hand-lmd5, hand-04rb, hand-phof | L16, L17 | [x] |

## Milestone 5 — drive (`drive/01-drive.md`)

The JEV loop. Depends on three ox rows delivered first: `ox_http` client (row 19), `ox_ai` + System One (row 20), chat (row 21). The request contract is jev-ultrafast's at a pinned commit, copied not adapted; the reference sources are in ox `docs/issues/ai-systemone/reference/`.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L19 | **Models wiring.** Config `models.{api_key (Redact), systemone_endpoint, jev_model, chat_base_url, text_model}` with `OPENROUTER_API_KEY` override; `Models` Service creating one TLS `ox_http` client and the System One client; the production Decide wired into the drive; `leash status` reports the models configuration (configured / missing key, never the key); the `Text_helper` seam left for L22. | drive-e7oi, drive-yqxg | ox 19–21 | [x] |
| L20 | **Request shaping and decision.** From a snapshot: jev's `elements` (label, role, current_value, states, operations per row), `page.text` from the `text` path, `recent_actions`; the `operation` question with jev's labels, per-operation target questions keyed by index; fail-closed validation of the chosen head only; decision record with probabilities. Pure functions, table-tested against the reference shapes. | drive-y37b, drive-zml5 | L19 | [x] |
| L21 | **The loop as an effect computation.** `Observe`/`Decide`/`Act` with a local handler token (ox ADR-0006); production handler; scripted test handler; `--dry-run` handler; step cap, deadline, stall rule (three non-wait no-change steps → blocked), stale-target re-decide, `wait` op (bounded settle then re-observe), `scroll_up/down`, `done`/`blocked`, dialog or popup → `error`, model failures → `error` with detail, trace with elapsed_ms, final snapshot, tab slot held for the duration; `resume`-style guards (owner, not `With_human`, no dialog). | drive-y7v8, drive-xjh6, drive-4zlp, drive-ix5t, drive-qwbp, drive-9y2s, drive-8rts, drive-8zh8, drive-kh2u, drive-tfqh, drive-ig84, drive-n3ld, drive-4bhg, drive-l7yk, drive-8n2z | L20 | [x] |
| L22 | **Text helper.** `TYPE_TEXT` step: jev's `field_context`, `Ox_ai_chat.complete` with json_object and reasoning off, `{text: string|null}` parse, null → blocked naming the field, 4 KiB bound, reuse on unchanged input, values from the goal used verbatim. | drive-ls3c, drive-fh1h | L21 | [x] |
| L23 | **Live acceptance for milestone 5** (headless, real models, real key from the environment): jev's own two tasks — the Wikipedia article goal ("Find and open the Wikipedia article about Gödel's incompleteness theorems") and a Google Flights one-way search verified independently by reading the result page — plus a `--dry-run` on each; record steps, elapsed, usage and cost per run in the spec's status. Marks the spec completed. | drive-y7v8, drive-8zh8, drive-7tvn | L22 | [x] |

L19 can start as soon as ox row 19 lands (with the System One and chat clients stubbed behind their interfaces); L20 is pure and can start at once from the reference sources.

## Milestone 6 — service packaging (`service-packaging/01-service-packaging.md`)

The last milestone: the thing you leave running. Stories 13–16 were added from the coordinator's own headed run on 2026-09-27.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L24 | **Config and CLI polish.** Defaults for every non-secret field; `leash config init`; `control.socket`; per-command `--help` with positional names and only the options a command uses; title refresh after action navigation. | svc-ljl3, svc-kzt6, svc-tkor, svc-x8rp, svc-o4wt, svc-hi4f | — | [x] |
| L25 | **Diagnostics.** Chrome stderr ring per generation in the `generation lost` entry; journal fields (tab, owner, cmd) verified on every command; redaction test that `fill` text, `text` results, API key and userinfo never reach a log line; optional OTLP export via `ox_otel` switched by config. | svc-p67t, svc-qilu, svc-f4op, svc-qrmc | — | [x] |
| L26 | **Unit and install.** systemd user unit as the spec describes; `nix build .#leash` output installed to the profile the way Pie's is (read Pie's flake/home-manager for the pattern); listener refuses a second instance; `leash status` as the health check; the niri rule documented in `README.md`. | svc-dit8, svc-gxhu, svc-5wm8, svc-46f0 | L24 | [x] |
| L27 | **The `leash` skill.** New skill at `/home/ribelo/.dotfiles/skills/engineering/debugging/leash/` in the chrome-cdp skill's minimize-output style, covering new/snap/click/fill/text/eval/shot/debug/handoff/drive; the old chrome-cdp skill left in place until L28. Verified by an agent completing the chrome-cdp workflow (open a page, find a control, act, read the result) through `leash` only. | svc-itcb | L24 | [x] |
| L28 | **Live acceptance for milestone 6**, headed, on the operator's desktop with the operator present: install the unit, start it, watch Chrome land on the `leash` workspace, run the L27 workflow from a DSH session, trigger one handoff and click Done, `systemctl --user restart leash`, confirm tabs are gone and the profile's login survived. Together with L18. Marks the spec completed and the project usable. | svc-dit8, svc-xafg, chrome-2y3t, hand-04rb, hand-phof | L25, L26, L27 | [x] |

L24, L25 and L27 are independent; L26 after L24. L28 needs the operator.

## Milestone 7 — run (`run/01-run.md`)

Missions over playbooks: three JEV levels (playbook, procedure, operator), mandatory human-language expectations verified by code first and JEV score second, Luna as a bounded planner on demand, discovery, propose-and-approve for learned procedures. Read the spec's Further Notes for the design record.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L29 | **Playbooks and checkers.** Format and types, loader with every refusal, `playbook list/show/check`, page-kind matcher, checker resolution grammar, expectation wait, the download observer and `downloads` command (protocol updated), the shipped `allegro.pl` example. Pure tests plus fake-browser download events. | run-tcuz, run-r1e9, run-2lei, run-84ds, run-zmz8, run-dbji, run-fk99, run-xfxx, run-tny5, run-vbys, run-l06s, run-ykq4, run-k8bx, run-seqo | — | [x] |
| L30 | **State measurement.** Allegro 403 recorded without evasion; five real headless Automation Exercise workflow states and matching playbook; 15 System One calls compare title/URL (2/5), plus page kind/recent procedures (4/5), plus page text (2/5), with per-call probabilities, tokens and costs in `.scratch/research/state-measurement/README.md`. Select the middle shape; guard premature DONE before L31. Allegro remains for L34 operator-headed acceptance if needed. | run-snk4 | L29 | [x] |
| L31 | **The loop.** `Select_playbook`/`Select_procedure`/`Fill_args`/`Execute_step`/`Verify`/`Plan` as an effect computation with a local token; production, scripted and dry-run handlers; playbook switching with `entry` navigation; `use`/`optional`; verified DONE; caps, deadline, trace, endings, refusals; `run` in the protocol and CLI. | run-9ypy, run-kli0, run-xh5d, run-qq3o, run-pvmc, run-5rll, run-d82w, run-prrv, run-4j1v, run-vspj, run-fp7i, run-xqh8, run-klp9, run-fwl8, run-vj48, run-4mzm, run-shgh, run-7blx | L29, L30 | [x] |
| L32 | **The planner.** Luna turn on the three triggers, three answers decoded fail-closed, mission-level expectations, turn cap and cost, proposals to XDG state, `playbook accept`, configurable model. | run-w7ke, run-rq6i, run-2tt3, run-obtt, run-m0r8, run-d99l | L31 | [x] |
| L33 | **Discovery — superseded by L53.** `discover` removed; exploration goes through `drive` and learning. | run-3vat, run-tt9z, run-xda7, run-tpnf (retired by map-gkww) | L32 | superseded by L53 (`map-gkww`) |
| L34 | **Live acceptance for milestone 7** (headless, real JEV and Luna): Allegro 403 recorded without evasion; Automation Exercise fallback find → offer → add to anonymous cart → cart, stopping before checkout/payment; one cross-site run with a PDF download and a playbook switch; one discovery run on a harmless site; costs recorded. Marks the spec completed. | run-seqo, and the run stories end to end | L33 | [x] |

L29 first; L30 needs only L29's loader and the models service; L31–L34 in order.

## Milestone 8 — hardening from use (`hardening-1/01-hardening-1.md`; more specs as findings arrive)

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L35 | **Dialogs end waits.** One race helper for every tab wait; `new`/`nav` return the tab with `dialog`; actions return `ActionResult` with `dialog`; `wait` returns `dialog-open`; `beforeunload`; `prompt` text; listener budget → `timeout` reply; fake-browser dialog scripts; live pages; skill line. | hard-6eei, hard-dljv, hard-s719, hard-t6cq, hard-tsva, hard-yi0a, hard-92ik, hard-owci, hard-wo78, hard-fir4 | — | [x] |

| L36 | **Hardening 2** (`hardening-2/01-hardening-2.md`): `net` ring with bodies and request data; `wait` up to 1 h and `--changed-since`; `upload` and file-input rows; `hover`; `eval --index`; read-only `cookies`/`storage`; protocol, fake browser, live gate, skill. | hard-xg6y, hard-ovbx, hard-vq5s, hard-sr9v, hard-sckn, hard-o3za, hard-2gnf, hard-v1gs, hard-b20d, hard-ufb7, hard-wk6q, hard-2cal, hard-b1na | — | [x] |
| L48 | **Hardening 3, the first field report** (`hardening-3/01-hardening-3.md`). Password rows back in `snap` (never their value; `fill --stdin`); `renderer-unresponsive` with the debug tail; `new`/`nav` never lose the handle; `click` follows a covering label, `check`/`uncheck`; `settled` means populated, DOM fallback table for AX-empty pages; cross-origin iframes visible; `--snap` on actions; usage names the argument; registration-form live page. | field-8bzc, field-5sdo, field-sazr, field-cct4, field-cde7, field-m5jw, field-drpx, field-zr9n, field-uls3, field-guda, field-lp65, field-jkx6, field-vji1, field-swvb, field-uqvp, field-i4x0, hard-s4ht, hard-wayp | L44 | [x] |

## Milestone 9 — collect through drive (`extract/01-extract.md`)

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L37 | **Playbook directories and scripts.** Directory layout, `file`/`source` scripts, `returns` shapes and validation, `script:` steps, `playbook test`, `show`/`check`, the safety test. | extr-plaz, extr-zdst, extr-8o1h, extr-vgir, extr-mp5z, extr-lslp, extr-k40c | L36 | [x] |
| L38 | **`drive` is the one entry point.** Fold `run` into `drive` (playbook or none), argument filling for query parameters, records bypass the models, `repeat`, `data` summary and `--out` JSONL, cost reporting, trace. | extr-andy, extr-mq0e, extr-ve3k, extr-mfmf, extr-b3u0, extr-p7sj, extr-5x9e, extr-p152 | L37 | [x] |
| L39 | **Example and live acceptance.** books.toscrape.com playbook directory, fetch-based test script, skill update, live missions (whole category; filtered by price). Marks the spec completed. | extr-tkco, extr-oaci, extr-8ubt | L38 | [x] |

| L40 | **Playbook robustness.** The L39 example was tuned to JEV's quirks and a variant failed on an 8-page category. Collect three categories of different sizes (one ≥ 8 pages) with plain wording; diagnose each failure to its cause and fix it there — not by rephrasing to suit the model. Record the diagnosis in the spec. | extr-uhnc | L39 | [x] |

## Milestone 10 — daily use (`daily-use/01-daily-use.md`)

Leash replaces chrome-cdp. Agents are the main user: help, errors and exit codes are part of the product.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L41 | **Errors and help.** JSON error record with hints for every failure including client-side; sysexits exit-code table; per-command help with examples and exit codes; grouped top-level help; `help errors`; no-argument orientation; config check reporting everything; the four-way table test. | daily-azxe, daily-6pde, daily-3bwr, daily-iisr, daily-pb5a, daily-u1k2, daily-9396, daily-k9cs | — | [x] |
| L42 | **Bundled skill.** `skill/` in the repository, embedded at build; `leash skill install/show` after nema's; version stamp compared by `status`; skill rewritten for the whole surface; the dotfiles copy replaced by the installed one. | daily-fiwd, daily-yd8s, daily-ulmi, daily-v6ez, daily-hdex | L41 | [x] |
| L43 | **Installed.** nixos-config imports and enables Leash with the secret wrapper and OTLP; the operator rebuilds; `status` reports version, Chrome, headed, key, skill; distinguishes not-installed, stopped and restarting; the generation-lost diagnosis checked on the installed service. | daily-0tl4, daily-ki34, daily-a341, daily-smli, daily-lqqn, daily-9zvz | L42 | [x] |
| L44 | **Acceptance and cut-over.** A fresh agent that knows only the installed skill runs the workflow and recovers from three failures; the operator's desktop checks (subsumes L18/L28); chrome-cdp deleted and every reference updated; AGENTS.md files name Leash; all trees clean, Leash pushed. | daily-9ggi, daily-n7on, daily-6c5m, daily-mglh, daily-l082 | L43 | [x] |

L42's original repository-only boundary was closed by the installed cut-over in L44. The current installed binary and skill are stale; updating them is the next step, not an open L42 story. See the [installed acceptance](<daily-use/01-daily-use.md#operator-desktop-check-daily-n7on-closes-l18l28--2026-10-01>).

L43 is delivered: the shared unit, status distinctions and generation-loss diagnostics are implemented; the installed service is running headed with a model key. On 2026-10-04 it reports `ad5d8e2` and a stale skill. Rebuilding to the reconciled HEAD and rerunning U1/U2 is a current deployment step, not unfinished installation scope. See the [L43 evidence](<daily-use/01-daily-use.md#l43-delivery--2026-09-30>).

L18 and L28 are closed by L44 (operator desktop check 2026-10-01).

## Milestone 11 — drive on the fly ([drive-on-the-fly spec](</home/ribelo/projects/ribelo/leash/docs/issues/drive-on-the-fly/01-drive-on-the-fly.md>))

Playbooks are optional knowledge, never permission to work. The operator decision of 2026-09-30 supersedes conflicting earlier clauses: NONE and no books enter the reference-like JEV operator directly, including page-data collection.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L45 | **On-the-fly drive.** All four playbook-availability routes; whole-mission link/form operation; coherent bounded page observation and returned operator state; reference action/prediction budgets; no planner veto of NONE; visible records may reach models; tagged operator/prepared output; preserved indexed-action/ownership boundaries; offline gates and real-site no-book form/collection, one/many-book and no-match acceptance with cost/latency evidence. | fly-b6yt, fly-8xiq, fly-mepw, fly-yolk, fly-2akp, fly-95bw, fly-nolf, fly-xger, fly-iodm, fly-crcc, fly-fl7u, fly-gysl, fly-qr70, fly-4mio, fly-4lmg, fly-2pn7, fly-hc3l, fly-vzzw, fly-8fgl, fly-9e0f, fly-g0uh, fly-9363, fly-mqkr, fly-v0fi, fly-gn5z, fly-u9eg, fly-eoqg, fly-spgh, fly-m9zv, fly-vnf1 | L40; L44 drive repairs only (not operator cut-over) | [x] |

L45 is delivered. The spec names the exact superseded ADR/spec/story clauses, the unseen-page BLOCKED rescue, and the 2026-09-30 live gate. It does not claim normalized all-pages extraction from a browser snapshot.

### Milestone 10, continued (review of 2026-09-30)

L45 was useful but sideways: the direction is the cut-over (L44). The review found the installed playbook to be a fetch scraper that bypassed the design, and the skill silent on authoring.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L46 | **Scripts are JEV's tools; playbooks are procedures** (`playbook-scripts/01-playbook-scripts.md`). `run_script:<name>` as an operator option scoped by page kind; `returns` beside the script, named shapes; args declare their source; loader refuses script-only playbooks and stray files; the honest books example; L39's gate re-run with JEV choosing. | pbk-46fr, pbk-rai1, pbk-3cq7, pbk-hcwy, pbk-9549, pbk-otsl, pbk-lvy9, pbk-lww9, pbk-85m1, pbk-8n2l, pbk-abr3, pbk-eyya, pbk-wbhf, pbk-i0zl; field-8bzc, field-sazr (from L48) | — | [x] |
| L47 | **Authoring reference** (`playbook-authoring/01-playbook-authoring.md`). `skill/references/authoring.md` as a procedure with the worked example; verified by a fresh agent writing a playbook for automationexercise.com. | auth-cv0y, auth-m5ho, auth-47fd, auth-249z, auth-ovd4, auth-avng, auth-v3sc, auth-75l0 | L46 | [x] |

Then **L44 closes**: skill refreshed on this machine, fresh-agent acceptance, chrome-cdp deleted with every reference, L18/L28 ticked.

## Milestone 11 — a tool a newcomer can hold (`handles/01-handles.md`, `help-is-docs/01-help-is-docs.md`)

The operator read the help as a newcomer (2026-10-01): `owner` was unexplained because it was a lock mislabelled as a name, tied to one harness; the playbook format lived only in the skill. ADR-0010 replaces ownership with the handle as capability; the help becomes the documentation.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L49 | **Handles are capabilities.** No owner anywhere; `claim`/`release`/`not-owner`/`already-owned` removed; `list` shows no handles; `new --label`; `take` mints a handle for one matching human tab and flips its origin; one tab rule (agent tabs close idle, human tabs never until taken); handoff keyed on the handle; ADR-0005 superseded; outcome table; fresh-agent run. | hand-scaz, hand-qos2, hand-mb9s, hand-0wo8, hand-x3hi, hand-ryxz, hand-okk8, hand-gjqy, hand-k1ag, hand-0ibq, hand-ihcg, hand-3v5u, hand-fr87, hand-0o28, hand-0y04, hand-qy26, hand-oyzl, hand-7m8x, hand-amp5, hand-w85z, hand-s4cq, hand-iyyk | — | [x] |
| L50 | **The help is the documentation.** `leash help` topics embedded from `docs/help/`, the skill's references generated from the same files, every option documented, first-run orientation, nothing harness-specific, a fresh agent with only the help writes and runs a playbook. | hdoc-ztwo, hdoc-8c12, hdoc-jh7u, hdoc-05q1, hdoc-socc, hdoc-vh8m, hdoc-fixp, hdoc-6vvm, hdoc-65jx, hdoc-2264, hdoc-vqj7, hdoc-em5c | L49 | [x] |

Then field reports (`docs/research/field/`) shape what follows.

## Milestone 12 — the map draws itself (ADR-0011)

Historical milestone-12 plan, superseded by L56 / ADR-0012: compile-from-traces and its hard-site campaign are withdrawn. Trace storage, page kinds and the replay install gate remain; the pilot writes playbooks as memory.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L51 | **Traces are kept** (`traces/01-traces.md`). Every drive persists its trace under XDG state with header, redaction, bounded retention; `traces list/show/prune`; `trace_path` in the reply. | trace-qe8c, trace-iqqz, trace-r7kp, trace-zbb9, trace-uovo, trace-o6ld, trace-lg58, trace-szpg | L49 | [x] |
| L52 | **Page kinds are inferred** (`page-kinds/01-page-kinds.md`). URL shape + title → a stable semantic label on sites without a playbook; shown to JEV, recorded in traces, measured against raw URLs; tables over real URLs. | kind-a7uy, kind-dnye, kind-ir9l, kind-4qke, kind-jdcs, kind-tdrv, kind-s1k2 | L51 | [x] |
| L53 | **Compile, try, install, repair** (`map-draws-itself/01-map-draws-itself.md`). `[learning]` config; compile matching single-entry-kind operations from independent successes (default ≥2); drafts tried by JEV in auto and installed on success; repair on double failure, retire after repeated failure; planner `continue`; drive tab rule; `discover` removed; live loop on books.toscrape.com and two Google sites. | map-0by0, map-w62c, map-bjon, map-6xcy, map-6m3c, map-2l5q, map-tval, map-rz4w, map-igfx, map-2ga3, map-ptnk, map-lnwr, map-h5ym, map-7xrq, map-3qag, map-puhi, map-4fga, map-4lw2, map-ngyr, map-zz7q, map-gkww + map-yzqp, map-wm4v, map-nh2e, map-itbt, map-pd0q, map-b3kk, map-fxra (two install gates: replay for repeatable missions, agreement for non-repeatable ones) , map-op01, map-op02, map-op03, map-op04, map-op05, map-op06, map-op07, map-fm01, map-fm02, map-fm03, map-fm04 | L52 | superseded by L56 / ADR-0012 (withdrawn) |
| L55 | **Unattended** (`unattended/01-unattended.md`). Planner `notify` without blocking; handoff deadline 5 min with `handoff-expired` and the tab left open; planner attempts CAPTCHAs through the action path, hands off only what it cannot pass; measured on a reCAPTCHA demo. | notif-7o8j, notif-m37y, notif-oslv, notif-7pha, notif-himb, notif-p4yk, notif-udh3, notif-tdtz, notif-646o | L53 | superseded by L56; legacy challenge findings remain in the spec |

L53's historical offline compiler coverage never demonstrated its live learn/install/reuse loop. ADR-0012 withdrew that campaign, including map-op07; it is not an open work item. The successor is L56 and the measured L57/L57F use-case campaign. L55's notify/handoff and ordinary action path are in the pilot; its configured challenge policy and live measurement are not implemented, as [the existing challenge stories](<unattended/01-unattended.md#status--2026-10-04>) now state.

## Milestone 13 — the pilot drives (ADR-0012, `docs/use-cases.md`)

L53's compile-from-traces failed three honest rounds; the cause was the loop's shape, not the compiler. Luna owns the mission and reads the page; JEV drives legs. Playbooks are memory the pilot writes. Ten use cases from the operator's daily life are the acceptance. L54 is superseded by U1–U4 (run by the agent on the operator's accounts) and the gates below.

| # | Slice | Stories | Depends on | Done |
| --- | --- | --- | --- | --- |
| L56 | **The pilot loop** (`pilot/01-pilot.md`). Planner-first drive with leg/read/act/handoff/notify/done{result,evidence}/fail; JEV runs legs; `--secret`; refusals; compile-from-traces removed; playbooks as memory via replay gate; prompt under 300 words; `--dry-run` shows intent. | pilot-ukoh, pilot-eu1c, pilot-x1f3, pilot-8csf, pilot-gt2h, pilot-s954, pilot-rdjv, pilot-02ij, pilot-e4sh, pilot-a4ua, pilot-3egp, pilot-oijk, pilot-c77y, pilot-ffqa, pilot-r94o, pilot-cnp5 | L55 | [x] |
| L57 | **Use-case gate campaign** (`docs/use-cases.md`). U5/U6/U8 live with independent checks; U7/U9/U10 fixtures; U1/U2 on the real Tauron account with `--secret`. Passed cases repeated with pilot memory installed; selection, turns and cost recorded, including regressions and setup limits. U3/U4 await supplied Allegro credentials. Skill and help rewritten. Execution complete, **not all cases passing**; open findings are L57F. | pilot-kkq2, pilot-7boq, pilot-sa3f, pilot-ivzx, pilot-lo8y, pilot-bkw9 | L56 | [x] |
| L57F | **Gate findings, in order: U5, U10, U9, U7, U8.** Diagnose, fix, rerun and record each case under its existing IDs. Suppress inapplicable remembered procedures (U5/U10); expose validated upload to the pilot (U9); deliver and redact generated passwords (U7); write pilot-collected records to `--out` (U8). The separate download-leg finding remains recorded, not added to this case sequence. | pilot-gn4w, pilot-pw7x, pilot-sc9t, pilot-h506, pilot-z1nr, pilot-exx7 | L58 | [x] (pilot-exx7 stays open) |
| L57C | **Notification cancellation** (`pilot/01-pilot.md`). Cancel/dismiss immediately returns canceled-by-operator, stops the pilot and preserves the durable outcome; notifications stay enabled. Regression and isolated real-notify-send checks pass. | pilot-9u3q | L57 | [x] |
| L58 | **Operate the picture** ([picture](<picture/01-picture.md>), ADR-0013). First-class CSS-coordinate click/dblclick/scroll/drag and focused type; hit/post-action screenshot evidence; aligned shot metadata and snap images with row boxes; bounded image-aware pilot; skill and help browser; fake-browser tests, live canvas. **Before L57F.** | pic-egvj, pic-f2hy, pic-33hm, pic-ncu1, pic-7nv6, pic-7ozf, pic-k4ij, pic-1jrz, pic-cqcf, pic-iomj | L44, L56, ADR-0013 | [x] |

## Later milestones

After milestone 6: the drive-spec follow-ups (tab title after navigation is in L24), an inspector handler for `drive` (pause at `Decide` for a human, jev's "Choose next"), and iframes, each as its own spec when wanted.

## Definition of done, every row

- Every story listed has a test citing its ID by name; `nix develop -c dune build @install`, `nix develop -c dune test` and `nix develop -c dune build @fmt` are green (add `.ocamlformat` in L0, same version as ox).
- No test touches a real browser, socket path outside a temp dir, or the network; live checks live only in `scripts/live-acceptance`.
- The safety defaults in `AGENTS.md` hold; anything in `docs/protocol.md` that the implementation forces to change is changed there in the same commit.
- Commit messages cite story IDs; the milestone spec's `status:` goes to `completed` when L3 lands, with the live-acceptance result recorded.
- When something is an effect-shaped resource or lifecycle concern without a browser concept, stop and write an ox spec instead of building it here (ADR-0001, ADR-0008).
