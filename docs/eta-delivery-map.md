# Eta delivery map for Leash

Every ticket that came out of the Leash planning and the Eta audit, in the order to deliver them, with what each one unblocks. Hand a row to an implementing agent; the ticket says what must be true when it is done. Tick the box when its repository has the change committed and its gates green.

Story-ID prefixes are stable names: "implement etarpc" means the ticket whose stories are `etarpc-*`.

## Order

| # | Ticket | Repo | Prefix | Depends on | Unblocks | Done |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `docs/issues/docs-package-truth/` | Eta | `etadocs` | — | every agent reading the README | [ ] |
| 2 | `docs/issues/stream-rpc-correlator/` → package `eta_rpc` | Eta | `etarpc` | — | Leash milestone 1 (CDP) | [ ] |
| 3 | `docs/issues/process-scoped-child/` → package `eta_process` | Eta | `etaproc` | — | Leash milestone 1 (Chrome) | [ ] |
| 4 | `docs/issues/ipc-control-listener/` → package `eta_ipc` | Eta | `etaipc` | — | Leash milestone 1 (control socket) | [ ] |
| 5 | `docs/issues/main-door-cause-diagnostics/` | Eta | `etadoor` | — | Leash milestone 6; Pie slice 2 of `piegap` | [ ] |
| 6 | `docs/issues/openrouter-reasoning-enabled/` | Eta | `etaor` | — | Leash milestone 5 (text helper) | [ ] |
| 7 | `docs/issues/ai-openrouter-systemone/` | Eta | `etaso` | — | Leash milestone 5 (JEV) | [ ] |
| 8 | `docs/issues/json-helpers-package/` → package `eta_json` | Eta | `etajson` | — | Leash milestone 1 (CDP decoding without depending on `eta_ai`) | [ ] |
| 9 | `docs/issues/remove-component-family/` | Eta | `etacomp` | — | nothing; removes 6.2k dead lines | [ ] |
| 10 | `docs/issues/remove-linux-input/` | Eta | `etalinput` | — | nothing; removes app code from the framework | [ ] |
| 11 | `docs/issues/stale-eta-gap-workarounds/` | Pie | `piegap` | slice 1 none; slice 2 needs #5 | Pie stops carrying two stale workarounds | [ ] |

Rows 1–10 are independent of each other and can run in parallel. Leash milestone 1 needs 2, 3, 4 (and 8 for comfort); milestone 5 needs 6 and 7; milestone 6 wants 5.

Eta ticket paths are relative to `/home/ribelo/projects/ribelo/ocaml/Eta`; the Pie ticket to `/home/ribelo/projects/ribelo/pie`.

## Definition of done, for every row

- The change is committed on the repository's `master` with a message citing the story IDs.
- Every Requirements bullet has a test that cites its ID, and `dune build @install`, the full test gate and (for Eta) the shipped-package gate are green.
- For a new package: an opam file, a `dune-project` stanza, a row in `docs/packages.md` in the stated tier, and a flake entry.
- Nothing else changed: no drive-by refactors.

## Considered and deliberately not ticketed

- **TLS as a hard dependency of `eta_http_eio`** (`lib/http_eio/openssl.ml` is `include Eta_http_tls_openssl`): every Eio HTTP consumer links OpenSSL even for plaintext or Unix-socket use. Structurally wrong, practically harmless today; inverting it (driver injected through the `eta_http` TLS contract) is a medium refactor with no consumer asking for it. Revisit when one does.
- **Queue / Channel / Pubsub in core versus Mailbox / Sink in `eta_stream`**: different semantics (cross-domain handoff, bounded backpressure, broadcast, lossy producer inbox), not duplicates; a "choosing a buffer" paragraph would help, but it is not a placement error.
- **`eta_exa`** (190 lines, Exa search client): an integration with a real consumer; fine where it is.
- **`eta_crux` and `eta_signal*`** (~16k lines): used by `taumel`; outside Leash's scope and not audited.
- **`Sampler` alone in root `eta`**: the runtime evaluates it, so it stays; the docs ticket explains that.

## Source

Audit with review verdicts: `docs/research/eta-audit-2026-09-26.md`. Design decisions: `docs/adr/`. Leash milestones: `docs/milestones.md`.
