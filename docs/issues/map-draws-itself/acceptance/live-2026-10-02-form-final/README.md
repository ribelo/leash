# L53 form-only acceptance — 2026-10-02-form-final (PASS)

PASS: harmless nonrepeatable form gate after the explicit-port fix. Two authorized synthetic loopback submissions (alpha-test, beta-test), agreement procedure installed with two-trace provenance, no third replay. Mission wording unchanged; no product code edits by this run (built the tree as found, port fix already present).

Machine-readable: summary.json, audit.json. Prior failing evidence preserved: live-2026-10-01 (FAIL, 0 installs), live-2026-10-02 (Books PASS, Maps/Flights/Form FAIL).

## Result

- Mission 1 alpha-test: done, goal true, 4 calls (text_helper 1, operator 3), cost .000230486, 0 proposals, none installed.
- Mission 2 beta-test: done, goal true, 5 calls (text_helper 1, operator 3, learning 1), cost .001497376 (run .000228826 + learning .00126855), 1 proposal, installed post-test-message.
- Total: 9 model calls, 0.001727862 USD, all fully reported (cost_unreported 0). result.json passed, 0 failures, elapsed 31.1 s. Harness exit 0.

## Agreement install and provenance

- Installed playbook: form/checkpoint-2/config/leash/playbooks/127.0.0.1/playbook.json, slug post-test-message.
- Provenance: 2 traces, model luna, tries 0, path [message-compose, message-posted], repeatable false, reason irreversible submission, gate agreement, repair false. Meets harness check (agreement + nonrepeatable + exactly 2 traces).
- Explicit untils (the prior failure): step 1 the page is message-compose, step 2 the page is message-posted, expect the page is message-posted. Service log empty (no compile warnings): form/service.redacted.jsonl.
- Port fix visible: page patterns carry the loopback port (http://127.0.0.1:41943/message-compose, .../message-posted) from frozen-page_kind.ml (patterns keep origin ports, kind-jdcs map-bjon). Frozen inputs: frozen-learning.ml sha faa9e8fa, frozen page-kind sha b650deaa.

## No third replay

- submissions.json: exactly alpha-test then beta-test; mission-1 1 entry, mission-2 2 entries.
- cleanup.json: service exit 0, empty profile processes, loopback closed, submissions_after_browser_shutdown 2.
- Harness checks passed: no nonrepeatable draft offered/replayed either mission, no install before agreement, final exactly two POSTs and no third replay.

## Binary and exact prebuild provenance

- Build: one capped command (timeout 900, DUNE_BUILD_DIR _build_form_final, dune build at install -j 2), exit 0, build.log.
- Binary: _build_form_final/default/packages/leash/bin/main.exe, SHA b1c03e61f3afbfe237d009c0343ff71beb10eca3c8c95b4a2a5a8b1b863da635, 16039808 bytes, mtime 2026-10-02 01:35:04+02 (build-freeze.json).
- Manifest captured 2026-10-02 01:34:34+02 (provenance.json): HEAD b2e1b91, 336 files, manifest sha b4cf1563, archive sha 8dfe3589 (source-manifest.json; full checkout tarball 4474624 B archived pre-landing to system-temp dir leash-l53-build-provenance, file live-2026-10-02-form-final-source-before-build.tar.gz, hashes retained, not for commit), diff sha b98bd1c2 stable across build, 0 mismatches on recheck.

## Isolation

Private XDG/config/state/cache/data/downloads/profile/socket per harness; headless main browser with remote-debugging pipe (form/config.toml, form/identity.json binary sha matches, form/startup-processes.json); key via secret-env ai, never printed; no seeded playbooks; no real profile/service changes. Independent recheck: no harness temp dirs, no harness prefix in process cmdlines (self-match only); user service left untouched.

## Limits and commit advice

- Form-only; Books/Maps/Flights not rerun. Loopback port is per-gate (41943 here); patterns are port-scoped by design.
- Exact-key scan passed via secret-env over all three acceptance dirs (684 files, 0 hits, key never printed); pattern scan also clean — see audit.json: 0 invalid JSON/JSONL, 0 capability-pattern, unredacted-handle, temp-path-leak, key-prefix, or user-profile hits.
- Safe to commit this directory on exact-key-scan evidence; tarball archived out (hashes retained), remaining dir about 0.3 MB. No product edits, no commits made here.
