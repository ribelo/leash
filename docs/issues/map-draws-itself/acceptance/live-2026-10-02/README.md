# L53 repaired live acceptance — 2026-10-02 (recovered)

**Mixed: Books PASS, Maps FAIL, Flights FAIL (reevaluated), Form FAIL on learning / PASS on harmlessness.** Prior worker died after campaigns; this report was recovered from files only — no missions, models, or browser reruns. Prior failed campaign is preserved, not overwritten: [live-2026-10-01](../live-2026-10-01/README.md) (binary `58004306…`, no exact source snapshot, 0 drafts/installs).

Machine-readable: [summary.json](./summary.json), [audit.json](./audit.json).

## Verdicts

| Gate | Missions | Total reported cost (run+learning) | Result |
| --- | --- | --- | --- |
| Books Mystery | 4 done | .000434154, .000954754, .000281820, .000282366 | [PASS](./books/result.json) — draft proposed after 2, JEV-chosen + installed on 3, installed used on 4, 4th cheaper than both baselines |
| Maps Eiffel Tower | 2 done, stop | .001881022, .001364670 | [FAIL](./maps/result.json) — no draft: page-kind paths diverge + Search non-repeatable |
| Flights Explore | 1 done, 1 error, stop | .001317624, .000540918 | [FAIL](./flights/result.json) — mission-2 covered click (row-not-actionable), no prices; saved `goal_verified:true` is a false positive (see below) |
| Form loopback | 2 done, stop | .000228166, .002657896 | [FAIL](./form/result.json) on agreement install; harmlessness holds: exactly alpha-test + beta-test, no third |

All four services exited 0 with empty `profile_processes_after_service` in cleanup files. Independent recheck (2026-10-02 ~00:44+02): no harness temp dirs remain (mkdtemp prefix from harness `Gate.__init__`, globbed under the system temp dir), no harness prefix in any `/proc/*/cmdline`; only the real user profile `/home/ribelo/.local/share/leash/profile` and nix-store `leash serve` remain — left untouched.

## Frozen binary and exact prebuild provenance

- Binary: `/home/ribelo/projects/ribelo/leash/_build_l53_repaired_20261002/default/packages/leash/bin/main.exe`, rechecked SHA256 `5176fd7ebeac09ec60c1997f336549a40f60e5866c172a34f63bdec45344006f`, 16039168 bytes, mtime 2026-10-02 00:22:57+02. Old frozen binary still `58004306…`.
- Prebuild manifest captured 2026-10-02 00:22:28+02 ([provenance.json](./provenance.json)): HEAD `b2e1b91…`, 336 files, manifest SHA `60651957…`, archive SHA `6f083c72…`, diff SHA `17286622…` unchanged after build ([build-freeze.json](./build-freeze.json), [source-manifest.json](./source-manifest.json), [build.log](./build.log); full checkout tarball (4490286 B, sha verified) archived pre-landing to system-temp dir leash-l53-build-provenance, file live-2026-10-02-source-before-build.tar.gz, hashes retained in provenance/manifest, not for commit).
- Post-build drift exists: [frozen-learning.ml](./frozen-learning.ml) differs from current `packages/leash/learning.ml` (mtime 00:31:53+02, repeatable/repair classification). Do not attribute the current tree to this binary; provenance is the archived tarball (hashes retained) + manifest, not a later diff.

## Books PASS — evidence

- Contract + accounting: [mission-contract.json](./books/mission-contract.json), [cost-curve.json](./books/cost-curve.json) (accounting scope “total browser run plus learning”, `cost_unreported:0` all missions).
- Mission-2 draft: [proposed/toscrape.com-open-mystery-category.json](./books/checkpoint-2/state/leash/proposed/toscrape.com-open-mystery-category.json) (provenance 2 traces, repeatable, gate replay, JEV luna, tries 0).
- Mission-3: JEV chose `draft:open-mystery-category` (0.96, verified, `the page is books-slug` passed), installed `open-mystery-category` ([drive](./books/mission-3/drive.json)).
- Mission-4: installed `open-mystery-category` used (0.97, verified, expectation passed), cost .000282366 < min(.000434154, .000954754) ([drive](./books/mission-4/drive.json), [playbook](./books/checkpoint-4/config/leash/playbooks/toscrape.com/playbook.json)).
- Isolation/headless: [config](./books/config.toml), [identity](./books/identity.json), [startup-processes](./books/startup-processes.json) (main browser `--headless=new` + `--remote-debugging-pipe`), [userAgent](./books/startup-browser-useragent.json). No seeded playbooks.

## Maps FAIL — no compile

- [result](./maps/result.json): 2 independently done goals, then stop on “no actual generated draft”.
- Path divergence blocks agreement: mission-1 `[m, maps, maps-2, place-<slug>]` (consent → maps → place URL) vs mission-2 `[maps, maps-2, maps-<slug>]` (no consent, `/maps/<slug>/<slug>` pattern): [trace-1](./maps/checkpoint-2/state/leash/traces/google.com/2026-10-01T22:25:06.696748Z-done.json), [trace-2](./maps/checkpoint-2/state/leash/traces/google.com/2026-10-01T22:25:18.009114Z-done.json).
- Search click/type steps are marked `non_repeatable:true` in both traces, further blocking a repeatable replay draft. Service log is empty (no compile attempt): [service](./maps/service.redacted.jsonl).
- Goals themselves verified (Eiffel Tower + Paris/Champ/75007 + `/place/`): [m1-after](./maps/mission-1/after/visible-page.json), [m2-after](./maps/mission-2/after/visible-page.json).

## Flights FAIL — error + false-positive goal flag

- [result](./flights/result.json): mission-2 “drive not done (exit 0, status error, reason the click action … failed (row-not-actionable): the row is covered at its click point)”. Full reason + covered Explore link: [m2-drive](./flights/mission-2/drive.json), [error-trace](./flights/mission-2/durable/state/leash/traces/google.com/2026-10-01T22:25:13.459856Z-error.json).
- No prices on mission-2 after page: [after-visible](./flights/mission-2/after/visible-page.json) shows “Loading results” twice, bare “PLN” currency selector, zero “PLN <amount>”. Mission-1 after page, by contrast, lists ~30 “PLN <amount>” rows: [m1-after](./flights/mission-1/after/visible-page.json).
- Saved [cost-curve](./flights/cost-curve.json) records mission-2 `goal_verified:true` with status error. Recomputed with the current harness priced-amount regex (currency adjacent to digits) it is **false**; the saved true matches only a bare-“PLN” check. Current offline test `test_flights_currency_picker_alone_is_not_destination_prices` (added 00:34+02, after evidence at 00:25+02) explicitly rejects “Explore Flights only PLN Loading”. Label: **failed**, independent of the flag.
- Harness timing caveat: `scripts/live-acceptance-l53.py` mtime 2026-10-02 00:34:48+02 postdates all evidence, so runtime goal logic cannot be proven from the current file alone. The preserved after-visible text is the deciding evidence.

## Form FAIL on install / PASS on harmlessness

- Exactly 2 POSTs, no third: [submissions](./form/submissions.json) (alpha-test 1790893489.69, beta-test 1790893493.62), [m1-sub](./form/mission-1/submissions.json), [m2-sub](./form/mission-2/submissions.json), cleanup `submissions_after_browser_shutdown:2` ([cleanup](./form/cleanup.json)). Server rejected any non alpha/beta token by design (harness `form()`).
- No agreement install: [result](./form/result.json) (“no actual installed agreement procedure reported”), [learning.json](./form/checkpoint-2/state/leash/learning.json) (only `compile:127.0.0.1` timestamp), empty proposals/installed in [m2-drive](./form/mission-2/drive.json).
- Compiler evidence: mission-2 accounting shows 2 learning calls costing .0024266 (initial + retry within one compile), service log has 1 warn “every navigation needs an explicit the page is \<kind\> until expectation” ([service](./form/service.redacted.jsonl)). Both traces share `[message-compose, message-posted]` with non-repeatable type+click steps ([t1](./form/checkpoint-2/state/leash/traces/127.0.0.1/2026-10-01T22:24:50.302115Z-done.json), [t2](./form/checkpoint-2/state/leash/traces/127.0.0.1/2026-10-01T22:24:54.363794Z-done.json)); the planner draft never supplied the required until.

## Meter scope (repaired)

Per-mission `model_cost` is total run+learning from the drive reply (not run-only): Books m2 learning 1 call/.0005206, Form m2 learning 2 calls/.0024266 are included; all missions `cost_unreported:0`, `total_cost_fully_reported:true`. Sums are mission-model spend only (zero-model startup/diagnostic excluded; prior 2026-10-01 campaign excluded). Do not treat as whole-project billing.

## Certainty limits

- Post-mortem recovery; no reruns. Findings rest on preserved files listed above.
- Current harness files postdate evidence; runtime behavior is inferred from evidence + current code/tests, not proven identical.
- Redacted `<PRIVATE_ROOT>` hides exact harness temp-dir paths (prefix + random suffix under the system temp dir); “no processes remain” is a prefix glob + cmdline scan plus per-gate cleanup files, not an exact-path replay from redacted evidence.
- Exact API-key scan passed post-recovery via secret-env over all three acceptance dirs (684 files, 0 hits, key never printed); see audit.
- Google-gate outcomes are point-in-time (consent, layout, loading states).

## Secret/handle scan and commit advice

- Scanned all evidence (see [audit](./audit.json)): 0 invalid JSON/JSONL, 0 capability patterns, 0 unredacted `tab/snapshot/handle`, 0 private-temp-path leaks, 0 API-key-prefix strings, 0 user-profile leaks; 32 files carry expected `<PRIVATE_ROOT>` markers; screenshots are page renders only.
- **Safe to commit this evidence directory on exact-key-scan evidence**, with full checkout tarball archived out of commit (hashes retained, location above); remaining dir about 5.1 MB. Do not substitute the current tree for provenance. No product files were edited; no commits were made here.
