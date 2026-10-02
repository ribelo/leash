# L53 Google live gates — 2026-10-02

**Both sites failed their learning gate; no retries or mission changes.** Maps stopped after mission 2; Flights stopped after mission 1. Later missions were not run because an upstream gate failed, not counted as passes.

## Provenance and isolation

Clean starting commit `6794253bccc65a332844937f191f90705095fcbf`; this commit, not a tarball, is the source provenance. One fresh capped build completed with exit 0:

```sh
timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_l53_google bash -c 'ulimit -v 16777216; exec dune build @install'
```

Binary SHA-256: `e128fc3b671f3b7aa39c8f2a0d661140f780942e44c9509f5bcc63efebd8e6c8`. See [provenance](<provenance.json>) and [build log](<build.log>). The [existing harness](</home/ribelo/projects/ribelo/leash/scripts/live-acceptance-l53.py>) was unmodified; its ten offline tests passed. The [covered-click collector](<collect-covered.py>) only adds immediate read-only eval and screenshots after the Flights covered-click error. It changes no missions, actions, config or gates.

Each site used a separate private headless Leash, temporary XDG roots/profile, no seeded playbooks, learning `auto` with `successes=2`, and a key supplied only through `secret-env ai --`. No real service, user Chrome, user config or real XDG state was changed. No product edits or commit.

## Gates and learning-inclusive costs

| Site | M1 | M2 draft | M3 JEV choice → expectations → install | M4 installed use | Total USD |
|---|---|---|---|---|---:|
| Maps | done; page goal independently passed | page goal passed; **no draft** | not run | not run | 0.004232554 |
| Flights | **error**; final page goal independently passed | not run | not run | not run | 0.000630210 |

| Site / mission | Operator | Text helper | Learning | Total calls | Total USD |
|---|---:|---:|---:|---:|---:|
| Maps 1 | 27 | 1 | 0 | 28 | 0.002915506 |
| Maps 2 | 7 | 2 | 0 | 9 | 0.001317048 |
| Flights 1 | 5 | 0 | 0 | 5 | 0.000630210 |

All costs were reported; learning is included and was zero because compilation was never triggered. Combined total **$0.004862764**. The lower second Maps cost is an unlearned on-the-fly run after consent, not proof of installed-procedure savings. Full accounting: [Maps cost curve](<maps/cost-curve.json>), [Flights cost curve](<flights/cost-curve.json>), [compact summary](<summary.json>).

### Maps: ordered trace paths do not match

Both independent final page checks show **Eiffel Tower** and **Av. Gustave Eiffel, 75007 Paris, France**: [mission 1](<maps/mission-1/after/page.png>) and [mission 2](<maps/mission-2/after/page.png>). Neither rests only on a model DONE.

The two persisted done traces have stable route kinds, but unequal paths:

- [First trace](<maps/checkpoint-2/state/leash/traces/google.com/2026-10-02T16:12:33.530036Z-done.json>): `m → maps → (search-<slug> → place-<slug>) × 6` (consent plus repeated Search clicks).
- [Second trace](<maps/checkpoint-2/state/leash/traces/google.com/2026-10-02T16:12:49.995894Z-done.json>): `maps → search-<slug> → place-<slug>`.

[Path normalization](</home/ribelo/projects/ribelo/leash/packages/leash/learning.ml#L59-L69>) maps `<slug>` to `slug` and removes unknown and *consecutive* duplicate kinds only; [candidate filtering](</home/ribelo/projects/ribelo/leash/packages/leash/learning.ml#L906-L915>) requires the full ordered path to equal the current one. The consent prefix and alternating loops independently prevent the two-trace threshold. All saved action `non_repeatable` flags are false, so the action-scoped safety fix is not blocking this run. No compile call, proposal or installation exists; [status](<maps/checkpoint-2/status.json>) records zero drafts. The additional missing-provenance/classification failures are consequences of the absent draft, not separate compiler-validation failures.

### Flights: invisible transition layer covers Explore

JEV clicks **Explore destinations** successfully, then tries the already-selected **Explore** header link (row 5). [Immediate elementFromPoint evidence](<flights/mission-1/covered-click/element-from-point.json#L23-L99>) at its live DOM content-center **(220.15625, 32)** identifies **DIV.KL4X6e.TuA45b**, not the target or a descendant: full viewport **1366×813**, `opacity:0`, `pointer-events:auto`, `z-index:1`. Its fixed **TRANS-LAYER** parent has `inset:0` and `z-index:1000`. Both content and border centers agree; target transform is none. The [failure screenshot](<flights/mission-1/covered-click/page.png>) shows the transitional Explore view.

A genuine, invisible covering element—not a guessed challenge or selector error—is the supported cause. [Drive](<flights/mission-1/drive.json>) refuses the click with `row-not-actionable: the row is covered at its click point`, status `error`. No action was replayed. The observation is immediately after the drive reply, not an atomic capture inside dispatch; the point is reconstructed from DOM, not logged CDP quads.

The [later independent screenshot](<flights/mission-1/after/page.png>) shows the actual geographical destinations map and numeric flight prices **Paris PLN 185, London PLN 130, Rome PLN 216**. Thus the page goal is met by observation, but the terminal error supplies no successful learning trace and the live gate still **fails**. A bare PLN currency label is not used as proof.

## Audit and cleanup

[Audit](<audit.json>) records exact-key matching in memory under `secret-env ai --` (counts only), capability/temp-path/key-prefix/user-profile pattern scans, JSON validation, and owned-process checks. Both [Maps cleanup](<maps/cleanup.json>) and [Flights cleanup](<flights/cleanup.json>) report service exit 0 and no private-profile processes; owned temporary roots were deleted by the harness. Two pre-existing L53-named archive directories from earlier runs were left untouched; neither is a private runtime/profile. Only four key/failure screenshots are retained; initial screenshots and generated bytecode caches were removed. Raw structured replies, traces and checkpoints remain. Private service logs are empty; diagnosis uses the structured evidence above. End-to-end compile/install/use remains unproven on both Google sites.
