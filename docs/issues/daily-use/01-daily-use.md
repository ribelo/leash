---
status: ready-for-agent
milestone: 10
---

# Daily use: Leash replaces chrome-cdp

## Problem Statement

Leash is built and unused. The operator wants to stop using the chrome-cdp skill and have agents use Leash instead, installed as a systemd service. Agents will be its main users, so help, errors and exit codes must tell an agent what went wrong and what to do next. Three gaps, verified on 2026-09-30:

- **Errors aren't agent-grade.** With the service down, the CLI prints a raw `Eio.Io Fs Not_found Unix_error (…)` and exits 1. Every service error exits 1 whatever its code. `--help` advertises Cmdliner's default 123/124/125, which Leash does not use.
- **The skill isn't bundled.** It lives only in dotfiles and drifts from the binary.
- **The service isn't installed.** nixos-config does not import Leash, and the API key is not wired.

## Solution

Install Leash through nixos-config like Pie and nema. Give every failure a stable code, a documented exit code and a one-line hint, from the CLI as well as the service. Bundle the skill in the binary with `leash skill install`, after nema's installer. Prove it with an agent that knows only the installed skill, working against the installed service. Then delete chrome-cdp.

## User Stories

### Installed as a service

1. As the operator, I want nixos-config to import Leash's flake and home-manager module, enable it, and wire the OpenRouter key the way Pie's and nema's units do (a wrapper reading `/run/agenix/openrouter-api-key`, failing with a clear message if it's unreadable), so that after one rebuild `leash status` answers healthy with the model key present. ^daily-0tl4
2. As the operator, I want the unit to send OTLP to inn (`otlpEnvironment`), stop cleanly with exit 0, restart on failure with a limit, and log to the journal, so that it behaves like the other services on this machine. ^daily-ki34
3. As the operator, I want the installed service headed by default on the desktop, with the niri window rule left out of this milestone, so that I can see what agents do and decide about placement later. ^daily-a341
4. As an agent, I want `leash status` to report the service version, whether Chrome is up and headed, the browser generation, whether a model key is configured, the tab count and cap, and whether the installed skill matches the bundled one, so that one command tells me whether Leash is usable. ^daily-smli

### Errors an agent can act on

5. As an agent, I want every failure the CLI prints to be one JSON object `{code, message, hint, detail?}` on stderr, including client-side failures (`service-unreachable`, `socket-permission`, `config-invalid`, `usage`), and never raw exception text, so that I can parse every error the same way. ^daily-azxe
6. As an agent, I want every error code to carry a one-line `hint` naming the next action (for example `stale-snapshot` → "run `leash snap TAB` again and use its snapshot id"; `service-unreachable` → "`systemctl --user start leash`, or pass --socket"), so that I recover without reading docs. ^daily-6pde
7. As an agent, I want every error code mapped to a distinct, documented exit code in sysexits style, as nema does: usage and invalid requests 64, stale or invalid data 65, unknown tab or request 66, service or browser or model unavailable 69, internal 70, permission (not-owner, with-human, already-owned) 77, retryable (timeout, tab-cap) 75, command-line parse 124. The agent finalizes the table and records it in `docs/protocol.md`. So that the exit status alone tells me what class of problem I have. ^daily-3bwr
8. As an agent, I want `--help` on every command to show its arguments, one or two real examples, and the exit codes it can return, and top-level `--help` to group commands (tabs, observe, act, network and debug, missions, playbooks, service, skill), so that help is enough to use a command correctly the first time. ^daily-iisr
9. As an agent, I want `leash help errors` to print the full table of codes, exit codes, meanings and hints, so that the error model is discoverable from the binary. ^daily-pb5a
10. As a maintainer, I want a table test asserting that every protocol error code has an exit code, a hint, a row in `docs/protocol.md` and a line in `leash help errors`, and that the CLI never prints non-JSON to stderr on failure, so that no new code can ship without all four. ^daily-u1k2

### The skill, bundled

11. As a maintainer, I want the skill's source in the repository (`skill/SKILL.md` plus `skill/references/`) and embedded in the binary at build time, as nema does with `gen_skill_data`, so that the skill and the binary always match. ^daily-fiwd
12. As an agent, I want `leash skill install [PATH] [--dry-run]` to install the bundled skill into PATH, or with no PATH into the agent skill directories it discovers (the same discovery rules as `nema skill install`), printing one JSON outcome per target (`installed`, `replaced`, `current`, `planned-*`), so that the skill can be installed without copying files by hand. ^daily-yd8s
13. As an agent, I want `leash skill show` to print the bundled SKILL.md, and the installed copy to carry a version stamp (Leash version and commit) that `leash status` compares with the bundled one, so that a stale skill is visible. ^daily-ulmi
14. As the operator, I want the skill rewritten from the current dotfiles version to cover the whole surface as it stands after milestone 9: ownership and the DSH owner; minimize output; the snap → action cycle; dialogs and popups; `eval` and `eval --index`; `net`, `debug`, `cookies`, `storage`; `wait` including long and `--changed-since`; `upload`, `hover`; downloads; handoff and resume; `drive` with and without a playbook, `--out`; playbooks and writing scripts with `playbook test`; the error model and exit codes; when to use `drive`, `eval`, or the raw commands. It should stay short with references for depth, so that one skill replaces chrome-cdp completely. ^daily-v6ez
15. As the operator, I want the dotfiles copy of the leash skill replaced by the installed one (the install target is the dotfiles skills directory), so that there is one source of truth: the repository. ^daily-hdex

### Acceptance and cut-over

16. As the operator, I want an acceptance run in which a fresh agent session that knows only the installed skill works against the installed systemd service and completes: open, snap, fill and click a form; read with `text` and bounded `eval`; find an API call in `net` and read its body; handle a dialog and a popup; download a file; one `drive` mission; and recover from three deliberate failures (service stopped, stale snapshot, not-owner) using only the hints. The transcript and any skill or help changes it forced should be recorded, so that Leash is proven as an agent's tool, not just a test suite. ^daily-9ggi
17. As the operator, I want L28/L18's desktop checks (the handoff raises the window and notifies; Done returns control) run on the installed headed service, with my observations recorded, so that the handoff is proven on my desktop. ^daily-n7on
18. As the operator, I want the chrome-cdp skill deleted from dotfiles after acceptance passes, and every reference to it updated: the screenshot skill, the leash skill, the upstream-sync request list (so a sync doesn't bring it back), and any AGENTS.md. So that agents have one browser tool. ^daily-6c5m
19. As the operator, I want the global and project AGENTS.md files that mention browser inspection to name Leash, so that agents reach for it by default. ^daily-mglh

### Operability

20. As an agent, I want `leash status` to succeed with a clear `service-unreachable` hint when the socket exists but the service is dead, and to distinguish "not installed", "stopped" and "Chrome restarting", so that I never mistake a stopped service for a broken page. ^daily-lqqn
21. As the operator, I want `leash config init` to print where it wrote the file, and `leash config check` to report every problem at once with the config path, so that setup mistakes are fixed in one pass. ^daily-9396
22. As a maintainer, I want the stderr ring from Chrome, the generation-lost log and the journal fields checked once on the installed service (Chrome killed with SIGKILL, service recovers, the log names the cause), so that production failure diagnosis is proven where it will happen. ^daily-9zvz
23. As an agent, I want `leash` with no arguments to print a short orientation (is the service running, how to start, the three commands to begin with) rather than the full manual, so that the first contact is useful. ^daily-k9cs
24. As the operator, I want milestone 10 closed only when every tree it touched is clean, Leash is pushed, and chrome-cdp is gone, so that there is no half-cut-over state. ^daily-l082

25. As the operator, I want `skill.roots` to name custom nested skill-library directories, with tilde/environment expansion, install and status inspecting the same roots, and explicit install PATH retaining precedence and consent, so that the bundled skill reaches my actual dotfiles library instead of only conventional agent homes. ^daily-c4cl

## Implementation Decisions

- Exit codes follow sysexits where one fits. The mapping is a single table in the protocol module used by the CLI, `help errors`, and the table test.
- Client-side errors are built in the CLI with the same record type as service errors. The CLI catches connection and decode exceptions at its one entry point.
- The skill embedding reuses nema's approach: a dune generator turns `skill/` into an OCaml module. The installer follows nema's `skill_install` (dispositions, dry-run, JSON outcomes), adapted for capabilities.
- The nixos-config change mirrors nema's unit: the shell-stack pattern, a secret wrapper, and `otlpEnvironment`. The operator rebuilds.

## Testing Decisions

- Control-protocol seam: status fields, error records and hints. CLI tests: exit codes per error class and JSON-only stderr (story 10). Installer: dispositions against a temporary directory, as nema's test does.
- Live: story 16 is an agent-run acceptance recorded in the spec; story 17 is the operator's; story 22 is on the installed service.

## L41 delivery — 2026-09-30

Delivered daily-azxe, daily-6pde, daily-3bwr, daily-iisr, daily-pb5a, daily-u1k2, daily-9396 and daily-k9cs. CLI failures use one compact JSON record on stderr with the canonical code, message and recovery hint, including connection, config, local playbook, permission, parsing and invalid-response failures. Successful JSON and table output are unchanged. The closed table has 30 codes and the agreed exits 64, 65, 66, 69, 70, 75, 77 and 124.

Every command has argument help, examples and applicable exit classes. Top-level help groups the surface, `leash help errors` exposes the complete table, and bare `leash` gives a bounded, read-only orientation. Config checks aggregate structural, semantic, environment and filesystem problems with the config path; config init preserves its success output and classifies permission refusals.

The four-way table test independently scans the declared constructors, so omitting a new code from the iterable table fails too. Strict cram checks parse the entire stderr as exactly one JSON line, exercise every exit class (including `--pretty` failures), verify config aggregation and check successful output and offline help. Existing CLI tests were migrated from the old 0/1/2 contract to these exits and stderr.

All four gates passed in the isolated `_build_l41` directory against pinned ox `76d2596d` (door-5):

- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l41 dune build @install`
- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l41 dune test`
- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l41 dune build @fmt`
- `timeout 900 nix develop -c scripts/caps-gate`

A private service and profile using real Google Chrome 152.0.7977.64 were checked with `--headless=new` confirmed in the Chrome process arguments. With the socket absent, status returned service-unreachable/69; with the service up, status, new, snap and close preserved successful JSON. Deliberate tab-cap/75, unknown-tab/66 and not-owner/77 failures returned the compact canonical records and hints. SIGTERM went to each private Leash process; both stopped with exit 0 and their Chrome children and sockets disappeared. No installed binary or existing service was changed. This is L41 smoke evidence, not the installed-service/skill acceptance reserved for L43–L44.

## L42 repository delivery — 2026-09-30

Delivered daily-fiwd, daily-yd8s, daily-ulmi and daily-v6ez. Dune embeds the complete
repository skill and references into the executable. Local `skill show` prints the
exact installed entrypoint with YAML version/commit metadata; `skill install` uses
Nema's default roots, canonical deduplication, consent/force/no-input rules, truthful
per-target JSON outcomes and staged replacement/rollback. Dry-run neither writes
nor prompts. Permission and other installer failures reuse L41's canonical records,
hints and exits; the closed table remains 30 codes.

Successful CLI `status` preserves service fields and adds local installed-skill
currency, with the compiled version/commit and per-root missing/stale/current
states. It compares all bundled contents, not only the stamp. The service wire
contract is unchanged, and an absent service remains service-unreachable/69.

The standalone entrypoint routes to lifecycle, browser, missions/playbooks and
error-recovery references. Together they cover the current command surface,
headed/headless setup, identity, ownership/human holds, expiry, snapshots/actions,
network/debug observations, handoff, bounded missions, prepared scripts, playbook
validation, JSONL/cost evidence and concrete recovery. A review found the fallback
operator's DONE bypassed caller mission expectations: it now uses the same fresh
DONE guard as the playbook path, records those results, retains the operator trace
and refuses unmet expectations. Without a playbook, named page kinds remain invalid;
concrete text/row/download/dialog expectations work. No-expect fallback behavior and
non-DONE stops are unchanged.

Evidence: 16 temporary-filesystem installer cases; strict CLI cram for raw show,
full-bundle install, identical/current, consent refusal, forced replacement,
permission denial, empty path, discovered roots and no-effect dry-run. A private
protocol peer (not the installed service) checks status missing/current/stale for
old/missing stamps, modified references, multiple roots and force repair while
retaining the service result. The 34-test scripted mission suite adds both missing-
playbook and selected-none DONE cases, passing/failing expectations, fresh final
observation, retained trace, non-DONE stops and invalid page kinds. No browser or
model call was needed for this delivery.

All required gates passed with foreground Dune in `_build_l42`:

- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l42 dune build @install`
- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l42 dune test`
- `timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l42 dune build @fmt`
- `timeout 900 nix develop -c scripts/caps-gate`

`leash skill show` begins with `name: leash` and metadata
`leash-version: "0.0.0"`,
`leash-commit: "a18bc9550d6121d2727868ced02dc1c0b24f3fd3"`.
`leash skill install /tmp/leash-l42-sample-destination --dry-run` returned
`{"action":"planned-install","path":"/tmp/leash-l42-sample-destination/leash"}`
without creating that root. A fixture-backed status after a temporary default-root
install reported `skill.state: "current"` and the same version/commit.

**Scope boundary:** daily-hdex (replacing the dotfiles copy with the installed one)
was deliberately not performed: this request prohibits editing dotfiles, installed
binaries and running services. L42's delivery-map check marks the repository/binary
capability, not that operator cut-over. Actual installation and fresh-agent browser
acceptance remain L43–L44; chrome-cdp remains untouched. No commit was made, and the
isolated build and temporary test/sample files were removed after verification.

## L43 delivery — 2026-09-30

Delivered daily-0tl4, daily-ki34, daily-a341, daily-smli and daily-lqqn up to the
operator rebuild. daily-9zvz is the installed-service check and is not done here.

`leash status` reports version, Chrome phase, generation, pid (null while a
generation is relaunching), headed, key_present (boolean only; secret-shaped
fields are stripped), tab counts and L42's skill field. A missing unit is
`not-installed` (69), an inactive unit is `service-stopped` (69), and an
activating unit, auto-restart, or Chrome generation relaunch is
`service-restarting` (75). An active unit whose socket does not answer stays
`service-unreachable` (69). The closed table is 33 codes. Classification reads
`LEASH_INSTALL_FIXTURE` or `systemctl show`; the cram fixtures do not call the
real systemd.

The desktop unit is nixos-config `388870c` (`home/common/desktop/shell-stack.nix`),
not Leash's home-manager module: that module has no secret wrapper and no OTLP,
and dc14de3 dropped the duplicate module pattern for nema. The wrapper reads
`/run/agenix/openrouter-api-key` into `OPENROUTER_API_KEY` at start. The key is
not in the unit file. `nix eval .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath`
succeeded. `nixos-rebuild` was not run. A `nix build` of the leash package was
not cheap (42 derivations, including the compiler) and was not run.

**Scope boundary:** the operator rebuilds, then the lead checks daily-9zvz on the
installed service. No Leash commit was made in this delivery.

## L44 acceptance repairs — 2026-09-30

### B: single-goal drive and tab lifetime (daily-9ggi, daily-v6ez)

- **Finding → cause → fix:** no-playbook drive stayed on about:blank → the
  operator only chooses row actions, not navigation → bootstrap one explicit
  HTTP(S) mission URL on a blank page before entering the same operator loop.
  Missing or ambiguous starting URLs stop with actionable guidance, without a
  pointless model call. An existing supplied page is not replaced; dry runs
  never navigate. This fallback is for one UI goal, not structured collection:
  collecting records still requires a prepared script/playbook (or caller-owned
  bounded eval/text). The drive reference now makes that distinction explicit.
- **Finding → cause → fix:** blocked replies lacked a reason → terminal operator
  decisions, stalls and dry runs shared a bare blocked return → each now names
  its cause and the caller's next action where relevant.
- **Finding → cause → fix:** a failed fallback expectation produced a planner
  self-note handoff and locked the tab → the shared DONE guard invoked the
  playbook planner even though no playbook was selected → unmet fallback
  expectations now return blocked with their fresh check results, retaining
  ownership and never invoking the planner or human-handoff handler.
- **Finding → cause → fix:** drive-created tabs leaked on every terminal outcome
  → the control dispatcher allocated a tab but never owned its release → the
  dispatcher closes its temporary tab after success, blocked/error replies and
  exception/cancellation; supplied tabs and actual handoffs remain open. The
  final snapshot is retained after closure.
- **Regressions:** daily-9ggi cases in run_test cover blank-page URL bootstrap,
  missing/ambiguous/unsafe URLs, dry-run non-navigation, supplied-page reuse and
  failed expectations with the normal planner budget (not the old zero-budget
  test loophole). drive_test checks all three blocked reasons. control_test
  checks done/blocked/model-error/exception temporary-tab cleanup and preservation
  of caller-supplied tabs and genuine human handoffs. Model timeout trace enrichment
  preserves detail fields, including the call kind, rather than replacing provider
  diagnostics. Planner corrections share the original turn's remaining budget via
  an injected clock; planner_test proves an expired turn makes no correction call.
- **Live evidence:** a private headless Chrome (PID 4051222, private profile/socket
  under /tmp/leash-b-l44-pnucxhr0) and real models via secret-env ai passed: blank
  mission without URL blocked in 0.10 s with its reason and zero model calls; the
  documented Open https://example.com mission with a true body expectation finished
  done in 1.12 s / one model call and its tab was closed; an impossible expectation
  on a supplied Example Domain tab returned blocked in 5.77 s / one model call,
  no planner turns, and the tab remained owned until explicitly closed. Service
  shutdown exited 0. Example Domain is now title-only on the redesigned website;
  the skill example's body expectation now checks “documentation examples” rather
  than asserting absent heading text. Body text was separately observed intact.
- **Gates:** isolated capped @install passed; run (35), drive (14), planner (13)
  and control (31) cases all passed. Full dune test and @fmt were run, with only
  other slices' in-flight error-table/help/formatting differences still failing.
  caps-gate passed. No installed binary, service or Chrome was touched.

### C: CLI/protocol/skill recovery and diagnostics (daily-9ggi, daily-c4cl)

| Finding | Cause | Fix |
| --- | --- | --- |
| `press` key names required trial and error; `Return` looked plausible. | Help omitted the accepted vocabulary; refusal hid it. | Exact named/lowercase/digit/punctuation vocabulary in help, skill and protocol; `invalid-request` hint and `detail.accepted_keys` enumerate accepted keys. |
| Tab/network and playbook clients called a missing service merely unreachable. | Only status consulted the unit/binary state. | All exchange callers share the same classification: not installed, stopped, restarting, or active-but-unreachable. |
| Error recovery reference was a partial summary. | The skill had no exhaustive canonical error catalog. | Every protocol code has its exact exit/meaning/hint in the skill and protocol; a regression compares every row, including `model-timeout` (75). |
| Not-owner and stale-snapshot hints encouraged ineffective retries. | They omitted caller ownership and row identity rules. | Own the newly opened tab, retain explicit owner or `dsh:<DSH_SESSION_ID>`, release only one's own tab, and re-snapshot both ID and index. Stale means document or row-role/name mismatch; native temporal AX roles use the same normalization as snapshots. |
| `playbook list --owner` failed unlike surrounding commands. | The local list term lacked the harmless shared convention. | Accept and ignore `--owner`; output remains unchanged and no service is needed. |
| Download progress omitted byte counts. | The registry discarded CDP progress fields. | Initialize and retain `received_bytes`/`total_bytes`, including completed downloads; both are required protocol fields. |
| Popup replies exposed an empty URL. | Target-created can precede navigated target metadata. | Boundedly refresh newly owned children only while their URL is empty; preserve valid `about:blank` and already-known URLs. |
| Root help suggested buying on Allegro. | A purchase mission was used as a first-contact example. | Replace it with reading the heading on example.com. |
| Immediate `net` polls were empty after page settlement. | CDP response events arrive asynchronously, later than DOM/load settlement. | State the observation-not-barrier contract; wait for a concrete outcome and boundedly retry observations, never repeat a side-effect merely to obtain its network body. |
| Status guessed a Chrome PID; SIGKILL appeared as a negative signal number. | PID came from a profile search, and OCaml portable `Sys.sig*` encodings were printed directly. | Expose the actual supervised child's PID only while running; Chrome-loss failure/log fields show OS names/numbers such as `SIGKILL / 9`. |
| Skill install/status ignored the nested dotfiles library. | Roots were hard-coded to discovery defaults. | Add `skill.roots`; expand tilde/leading environment variables, aggregate indexed config errors for relative/unresolved paths, deduplicate roots, and share configured roots across install/status. Explicit PATH wins; empty roots retain discovery; consent is unchanged. |

**Regressions:** `daily_acceptance_test` cites daily-c4cl/daily-9ggi and covers keys,
native temporal identity and role/name staleness, delayed popup metadata,
download byte progress, the supervised PID and SIGKILL failure/journal fields,
root expansion/type/path/error aggregation, and every canonical skill error row.
The existing `actions_test` popup case 10 also passes, proving known popup URLs
are not overwritten. `daily_acceptance.t` checks exact help, all four client routes
under five unit/binary fixtures, owner-compatible playbook list, and custom-root
dry-run/consent/install/status/explicit-path precedence without touching the
installed service. Gates are recorded by the lead after integration.

### D: model latency and recovery (daily-9ggi, daily-6pde)

- **Finding → cause → fix:** the Books Travel collection attempt timed out in about
  26 seconds with a real key → the failing no-playbook DONE expectation entered
  **Luna**, whose healthy 12.159–19.069 second replies were abandoned by Ox's inherited
  10-second per-attempt cap (two attempts); JEV answered in 0.580–0.792 seconds, and
  no text-helper call occurred → expose independent positive-second
  models.jev_timeout / text_timeout / planner_timeout defaults of **10 / 10 / 60**.
  The caller's total deadline still bounds retries. Text-helper and planner
  corrections now consume its remaining budget, not a fresh one.
- A historical private headless comparison reproduced the original error in
  25.792 and 25.968 seconds. With a raised cap and the same JEV answer replayed,
  real Luna replies at 12.003 and 8.942 seconds no longer timed out; the old path
  instead reported the unsupported no-playbook procedure. Slice B removes that
  accidental planner path. This is not a claim that collection succeeded.
- Timeout failures are now model-timeout (exit 75) with detail.code=timeout and
  detail.model_kind=jev/text/planner. The canonical hint names provider latency and
  models.<kind>_timeout rather than blaming the key. Other failures keep their kinds.
- Adding the fields exposed exponential default-field expansion in Ox's minimal
  JSON deriver (6.0 MiB generated config, roughly 94 GiB native compiler RSS).
  A temporary sequential models codec preserves the flat schema and validation;
  generated config fell to 211 KiB and compiled under an 8 GiB memory cap.
- **Regression:** 10 daily-9ggi/daily-6pde cases added to models_test cover independent
  per-kind budgets, two-attempt bounds, caller total deadline, authentication without
  retries, correction deadline sharing, successful slow replies, and config validation.
  The 16-case model suite passes; the existing text-helper suite also passes.
- **Evidence:** [private headless latency measurements](acceptance/2026-09-30-l44-model-latency.md).
  No installed service, Chrome or binary was changed. All private services exited 0.

## Out of Scope

The niri window rule; making the repository public; new browser capabilities (iframes, raw CDP).

## L44 acceptance repairs — snapshot / reading (daily-9ggi)

- **Finding:** httpbin's visible time input, Comments textarea and Submit button were
  missing; example.com's visible Learn more link was missing. **Cause:** Chrome's
  DOMSnapshot bounds are device-scaled document coordinates, but the snapshot guard
  supplied CSS viewport dimensions and scroll offsets. At 2× scale the viewport join
  discarded the lower controls. Separately, Chrome reports a native time input as
  `InputTime`, outside the role allowlist; textarea and submit already had correct AX
  roles. **Fix:** sample `devicePixelRatio` with the guard and scale both viewport and
  scroll coordinates before clipping; normalize native temporal roles to textbox with
  a shared role mapper for action revalidation. Viewport clipping remains in place:
  genuinely offscreen controls are not presented as visible.
- **Finding:** example.com produced 784 single-character paragraph rows. **Cause:**
  its new multilingual layout wraps each character in a span; every AX StaticText child
  was promoted to a separate paragraph row with the same parent backend. **Fix:** build
  one paragraph row from its descendant text in reading order, preserving whitespace
  and Unicode and retaining independently actionable descendant controls. The six
  language paragraphs remain six rows, not 784 characters; Learn more remains a link.
- **Finding (exposed by the restored time row):** filling a time input returned
  success without changing its value. **Cause:** Chrome's segmented native temporal
  editor ignores `Input.insertText`. **Fix:** detect native temporal inputs from their
  DOM type; validate the supplied value on a detached input, set the target through the
  native value setter, dispatch bubbling input/change events, and verify the resulting
  value. Malformed values leave the old value intact; readonly controls and rejected
  values return errors. Ordinary text controls retain the trusted keyboard path.
  `temporal_fill` in `test/actions_test.ml` cites daily-9ggi and exercises the native
  role, backend resolution, CDP text argument, events and invalid/readonly/rejected
  outcomes. The lead authorized this narrow extension into actions.
- **Regression:** `daily_snapshot` in `test/control_test.ml` cites daily-9ggi and
  replays real Chrome 152 AX/DOMSnapshot replies captured on a private headless service
  at device scale 2 (`test/fixtures/daily-snapshot-chrome.json`). It asserts all 13
  form controls, the time/textarea/submit roles and names, device-scaled scroll clipping,
  six coherent language paragraphs and the actionable Learn more link. The fixture
  removes unused AX inline boxes/name provenance and unused DOM metadata only.
- **Evidence:** unpatched private headless Chrome at scale 1 exposed textarea/submit
  and Learn more but still lost the time input and split paragraphs; scale 2 lost the
  lower controls and reproduced exactly 784 character rows without Learn more.
  Patched private Chrome at scale 2 now exposes all 13 controls (18 rows with labels)
  and seven example.com rows (six paragraphs and Learn more). Indexed textarea fill
  changes Comments; indexed time fill sets delivery.value to "12:30" and emits exactly
  input/change. An invalid time returns invalid-request, preserving both value and event
  count. Clicking Learn more and waiting for its canonical www.iana.org URL succeeds.
  CDP quads/hit-test/mouse dispatch already use correct CSS coordinates: the apparent
  click failure was a wait for the noncanonical host, not a pointer bug; no pointer
  geometry or settlement code changed. Every private service stopped with exit 0.
  Installed binary, service and Chrome were not touched. @install, caps-gate, the
  recorded-page regression, ordinary/temporal fill regressions and existing snapshot
  tests pass. Full dune test and @fmt await only other workers' remaining integration
  repairs (latest: not-owner error-table documentation and unrelated formatting). An
  additional direct full actions run passed cases 0–9, then hung in the unchanged popup
  case; it was stopped and reported to the lead rather than counted as a pass. Private
  profiles, diagnostic scripts and `_build_l44a` were removed after verification.

## L44 run-2 repairs — X: download crash (daily-c4cl)

- **Finding → cause:** every run-2 download crashed Chrome 152.0.7977.64 before
  completion. Fresh private profiles passed; copying the installed profile reproduced
  both headed and headless, with both the installed Nix executable and a local build.
  Profile bisection reduced the trigger to `Default/History` plus
  `Default/shared_proto_db`: completed downloads persisted in both stores. The early
  `Browser.setDownloadBehavior` replaces Chrome’s delegate before history reconciles;
  Chrome 152’s DevTools delegate incorrectly reports no history-loading support.
  Chromium [bug 556160935 / upstream fix](https://github.com/chromium/chromium/commit/34fe0e520e143149b4b8a3faf3736af66442544a)
  forwards `SupportsHistoryLoading` to the original delegate. The byte-count change
  is passive event parsing, not a new CDP call or file stat; `allowAndName` and disabling
  extensions did not fix the reproduced crash.
- **Fix:** before installing the download delegate, open one background
  `chrome://downloads/` setup target and wait for its backend history-list
  acknowledgement (the upgraded `downloads-manager` removes its `loading` attribute).
  Close only that internal target, including failure/timeout paths, and exclude its
  announcements from the tab ledger. No fixed startup sleep, profile cleanup or
  history deletion. A five-second budget logs a warning and continues on failure;
  cleanup has a separate 500 ms bound. Remove this workaround when supported Chrome
  versions all contain the upstream fix.
- **Regressions:** `download_setup_test` cites daily-c4cl and advances a mock clock
  explicitly; it covers pending-to-ready history, background/session isolation,
  cleanup after attach failure, and bounded unresponsive initialization.
  `control_test.download_events` asserts bootstrap-before-override ordering and that
  the setup target never registers as a human tab; existing download byte tests remain.
- **Live verification:** ten independent copies of the complete installed profile
  under `/tmp`, five headed and five headless: `hello.txt` completed every time with
  `received_bytes = total_bytes = 16`; Chrome stayed in generation 1. The minimal
  History/cache reproduction also passed after the fix. Every private service exited
  0; the installed binary, service, Chrome and profile were never modified.

## L44 run-2 repairs — Y: reading and recovery (daily-9ggi)

The [run-2 transcript](acceptance/2026-09-30-l44-run2-transcript.md) names P1–P10.
The repairs below are the non-download slice; X owns the download implementation above.

- **P1 finding → cause → fix:** reads behind an alert timed out → Chrome withholds
  page-reading CDP replies while the dialog is open, and these reads had no modal
  guard/race → text, eval and shot refuse an existing dialog and subscribe before
  each CDP read so a newly opened dialog cancels the withheld read with `dialog-open`
  and its dialog detail. Answering a dialog bypasses that guard and stays possible.
- **P2 finding → cause → fix (guidance only):** crashed downloads left unexplained
  files and `.crdownload` → the skill described only the completed result, not
  profile storage or lost-browser recovery → document the default/custom-profile
  downloads location, completed-state verification, partial-file caveat and bounded
  status/new-tab recovery. Do not retry a crashing download blindly or delete files
  without authorization. The Chrome fix and live verification belong to X above.
- **P3 finding → cause → fix:** snapshot-validity advice contradicted observed input
  behavior → guidance demanded a new snap after every input and confused an action's
  `snapshot: null` reply with invalidation → explain that a newer snap/navigation
  invalidates old IDs, unchanged-page input preserves the current ID, and a changed
  or removed target can still be stale. Re-find the observed row rather than merely
  replacing the ID in an old index.
- **P4 finding → cause → fix:** a submitted click reported the old URL/title → an
  action reply can precede navigation, rather than proving submission failed → the
  entrypoint and browser reference now direct bounded URL/text waits or a fresh snap
  before another action. No action-settlement behavior was redesigned.
- **P5 finding → cause → fix:** stale failures had three messages, omitted current
  IDs and incomplete recovery → action and indexed-eval branches built errors
  independently → one `Protocol.stale_snapshot` supplies the canonical message,
  `detail.snapshot` (current ID or null), and a hint naming re-snap, re-find and
  navigation back. The not-owner branches likewise share one hint and always expose
  `detail.state` / `detail.owner` for both unowned/null and owned/named tabs;
  guidance permits claiming an unowned tab, never impersonating another owner.
- **P6 finding → cause → fix:** `--all` was hard to discover → the top-level help
  and list summary did not name it → both now expose `leash list --all`, and list
  help explicitly includes unowned tabs and other owners.
- **P7 finding → cause → fix:** collection silently produced no records and no site
  playbook was installed → the skill's collection pointer omitted its preparation
  boundary → the entrypoint and a short missions routing note require an installed,
  validated/tested collection playbook before promising JSONL. They point to the
  reference's complete example and the source checkout's `examples/playbooks/`,
  including Books collection; copy scripts too and obtain installation authorization.
  No playbooks are installed automatically, and no drive internals changed in Y.
- **P8 finding → cause → fix:** the stopped-service hint ended at start → it omitted
  the next status probe and normal startup race → the canonical hint says start,
  then status, and retry a brief `service-restarting` (75). The error table,
  help/docs/skill and CLI status golden stay aligned.
- **P9 finding → cause → fix:** generation returned to 1 after a service restart →
  generation and uptime belong to this service instance, not a persistent history →
  lifecycle guidance explains Chrome-generation increments versus service resets,
  and compares saved generation, pid and uptime against elapsed time.
- **P10 finding → cause → fix:** overlapping sessions stopped/started the service
  without a documented diagnostic path → status can expose an interruption but
  cannot attribute it → document comparison of saved status, user-service journal
  evidence and coordination; do not restart the shared service just to diagnose it.
- **Regressions:** `reading_test.modal_reads` cites daily-9ggi and withholds
  text/eval/screenshot CDP replies before opening a dialog; each returns dialog-open
  without advancing time, sends no page reads behind an existing dialog, leaves no
  screenshot and still allows dismissal. `daily_acceptance_test.recovery_details`
  covers missing/current/newer/changed-row/navigated snapshots, unchanged input and
  both owner states. Help and stopped-service Cram pin discoverability/recovery;
  the four-way error table stays green. Fixtures only: the installed binary,
  service and Chrome were not touched; no commit was made.
- **Gates:** `@install`, full `dune test`, `@fmt` and `scripts/caps-gate`
  pass on the integrated tree. Dune ran under the required 900-second / 16-GiB
  compiler cap; Semgrep runs without the compiler VM cap. An initial in-flight
  integration run reached the 900-second limit; after finalizing the fixtures and
  X's setup, all 28 executables completed individually and the full gate passed.
- **Integration finding → cause → fix:** isolated hardening2 disconnect cancellation
  counted a late queued poll (20 → 21) → the same failure reproduces on a clean
  `a46c3e8` worktree; six yields did not acknowledge twenty cancellations or drain
  prior CDP packets → after lead authorization, the fixture waits for all twenty
  listener `disconnected` events (emitted after cancellation/join), then drains
  old packets through a same-transport Cookies reply. Its original no-new-polls
  assertion over eight mock-clock ticks remains. Five isolated executions pass;
  no production cancellation behavior changed. The temporary baseline is removed.

## Further Notes

From the operator on 2026-09-30: the agent is Leash's main user; help and error codes must be excellent; the skill is installed from the binary like nema's; chrome-cdp is deleted (git keeps its history) once Leash works.
