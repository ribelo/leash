# Ox delivery map for Leash

> **Superseding note, 2026-09-26 afternoon.** Ox is being restarted as `eta-next` (worktree `/home/ribelo/projects/ribelo/ocaml/eta-next`, branch `eta-next`; see its `docs/why-next.md`). Leash is the first consumer of eta-next, not of v1. Consequences for this map:
>
> - Rows **2, 3, 4, 5, 6, 7** (`etarpc`, `etaproc`, `etaipc`, `etadoor`, `etaor`, `etaso`) were written for Leash on v1. **Stop them** if not yet started; if in progress, finish only what is pure and copyable (System One wire types and fail-closed decoding, the IPC endpoint-ownership rules, the process fd-mapping findings) and record the rest as not needed. Their *content* is re-specified against eta-next from Leash's stories when milestone 1 starts.
> - Rows **1, 8, 9, 10** (docs truth, `ox_json`, removals) and **11, 12, 13** (`etaidle`, `etawsct`, Pie's `piegap`) stay: they keep v1 honest for Pie, inn, nema, taumel, grip and p-doom, which remain on `v1`.
> - v1 is tagged `v1` on the Ox repository.

Every ticket that came out of the Leash planning and the Ox audit, in the order to deliver them, with what each one unblocks. Hand a row to an implementing agent; the ticket says what must be true when it is done. Tick the box when its repository has the change committed and its gates green.

Story-ID prefixes are stable names: "implement etarpc" means the ticket whose stories are `etarpc-*`.

## Order

| # | Ticket | Repo | Prefix | Depends on | Unblocks | Done |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `docs/issues/docs-package-truth/` | Ox | `etadocs` | — | every agent reading the README | [ ] |
| 2 | `docs/issues/stream-rpc-correlator/` → package `ox_rpc` | Ox | `etarpc` | — | Leash milestone 1 (CDP) | [ ] |
| 3 | `docs/issues/process-scoped-child/` → package `ox_process` | Ox | `etaproc` | — | Leash milestone 1 (Chrome) | [ ] |
| 4 | `docs/issues/ipc-control-listener/` → package `ox_ipc` | Ox | `etaipc` | — | Leash milestone 1 (control socket) | [ ] |
| 5 | `docs/issues/main-door-cause-diagnostics/` | Ox | `etadoor` | — | Leash milestone 6; Pie slice 2 of `piegap` | [ ] |
| 6 | `docs/issues/openrouter-reasoning-enabled/` | Ox | `etaor` | — | Leash milestone 5 (text helper) | [ ] |
| 7 | `docs/issues/ai-openrouter-systemone/` | Ox | `etaso` | — | Leash milestone 5 (JEV) | [ ] |
| 8 | `docs/issues/json-helpers-package/` → package `ox_json` | Ox | `etajson` | — | Leash milestone 1 (CDP decoding without depending on `ox_ai`) | [ ] |
| 9 | `docs/issues/remove-component-family/` | Ox | `etacomp` | — | nothing; removes 6.2k dead lines | [ ] |
| 10 | `docs/issues/remove-linux-input/` | Ox | `etalinput` | — | nothing; removes app code from the framework | [ ] |
| 11 | `docs/issues/openrouter-response-idle-timeout/` | Ox | `etaidle` | — | Pie slice 3 of `piegap`; Leash milestone 5 | [ ] |
| 12 | `docs/issues/ws-connect-timeout/` | Ox | `etawsct` | — | Pie slice 4 of `piegap` | [ ] |
| 13 | `docs/issues/stale-ox-gap-workarounds/` | Pie | `piegap` | slice 0 and 1 none; slice 2 needs #5; slice 3 needs #11; slice 4 needs #12 | Pie stops carrying stale workarounds and the dead `ox_component` declarations | [ ] |

Rows 1–12 are independent of each other and can run in parallel; row 10 edits grip first, then Ox. Leash milestone 1 needs 2, 3, 4 (and 8 for comfort); milestone 5 needs 6 and 7; milestone 6 wants 5.

Ox ticket paths are relative to `/home/ribelo/projects/ribelo/ocaml/ox`; the Pie ticket to `/home/ribelo/projects/ribelo/pie`.

## Rulings on the first round of conflicts (2026-09-26)

1. `ox_linux_input` has a consumer, grip: move it into grip, switch grip, verify grip, then delete from Ox (ticket rewritten; stories `etalinput-fvto`, `etalinput-lmt3`).
2. Stale `ox_component` declarations: Leash's `flake.nix` is already fixed; Pie's four files are slice 0 of `piegap` (row 13). Do them before or with `etacomp`; `etacomp` itself stays Ox-only.
3. No new package mentions `ox_component`; lifetimes are Ox resource scopes. The "component retirement awaits the process" test becomes "closing the owning scope awaits the process". Recorded in `etaproc`; apply the same wording in `etarpc` and `etaipc` while implementing.
4. `etaipc`: the split ingress/egress/handler-budget version (commit `9d6ca197`, story `etaipc-4t2y`) wins; delete the stale single-budget bullet.
5. `etajson`: no alias. `Ox_ai.Json` is deleted and every caller switched (story `etajson-1vw7` replaces retired `etajson-kn62`).
6. `etajson`: `ox_schema` was named in error; it is untouched. Only `ox_schema_yojson` is checked for a private copy.
7. `etaproc`: the supervision helper is required, not optional.
8. Pie work is in scope for delivery (row 13), one worker in the Pie repository, slices gated as the ticket says.

Smaller points accepted as proposed: System One takes a required `Duration.t` deadline (an already-expired deadline returns `TIMEOUT`); OpenRouter `reasoning` becomes a checked constructor; tickets move to `status: completed` when done.

## Definition of done, for every row

- The change is committed on the repository's `master` with a message citing the story IDs.
- Every Requirements bullet has a test that cites its ID, and `dune build @install`, the full test gate and (for Ox) the shipped-package gate are green.
- For a new package: an opam file, a `dune-project` stanza, a row in `docs/packages.md` in the stated tier, and a flake entry.
- Nothing else changed: no drive-by refactors.

## Considered and deliberately not ticketed

- **TLS as a hard dependency of `ox_http_eio`** (`lib/http_eio/openssl.ml` is `include Ox_http_tls_openssl`): every Eio HTTP consumer links OpenSSL even for plaintext or Unix-socket use. Structurally wrong, practically harmless today; inverting it (driver injected through the `ox_http` TLS contract) is a medium refactor with no consumer asking for it. Revisit when one does.
- **Queue / Channel / Pubsub in core versus Mailbox / Sink in `ox_stream`**: different semantics (cross-domain handoff, bounded backpressure, broadcast, lossy producer inbox), not duplicates; a "choosing a buffer" paragraph would help, but it is not a placement error.
- **`ox_exa`** (190 lines, Exa search client): an integration with a real consumer; fine where it is.
- **`ox_crux` and `ox_signal*`** (~16k lines): used by `taumel`; outside Leash's scope and not audited.
- **`Sampler` alone in root `ox`**: the runtime evaluates it, so it stays; the docs ticket explains that.

## Source

Audit with review verdicts: `docs/research/eta-audit-2026-09-26.md`. Design decisions: `docs/adr/`. Leash milestones: `docs/milestones.md`.
