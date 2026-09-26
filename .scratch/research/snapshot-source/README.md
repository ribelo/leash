# L4 snapshot-source spike (ADR-0004)

**Recommendation, pending operator confirmation:** use Chrome accessibility names and node identities joined to a DOM layout snapshot (candidate C). Throwaway experiment, not production code. Chrome was launched through `Leash.Chrome` and `Leash.Cdp` with `headless=true` (verified `--headless=new`); no network, debugging port, headed window, or default-test Chrome run. Actual browser: **Chrome/152.0.7977.64**. Local HTML fixtures are loaded as percent-encoded `data:text/html` URLs.

Run from the Leash root:

`bash .scratch/research/snapshot-source/run.sh`

The script builds Leash's install artifacts, then builds/runs this *separate* Dune project. It rewrites `measurements.json`, `environment.json`, and `consistency.json`. Root Dune ignores `.scratch`; no `runtest` stanza or test dependency starts Chrome. Since the bundle is ignored by `.gitignore`, stage it explicitly with `git add -f .scratch/research/snapshot-source/...` when the lead commits. This project points at the parent checkout's compiled Leash private module interfaces (rather than changing packages/leash); moving the checkout requires updating the two `-I` paths in `dune`.

## Method

Five independent fixtures: [form](fixtures/form.html) (explicit and enclosing labels), [aria](fixtures/aria.html) (ARIA labels and a custom checkbox), [navigation](fixtures/navigation.html) (visible links and offscreen content), [select](fixtures/select.html) (combobox and radio group), [state](fixtures/state.html) (disabled/checked controls and collapsed details). [labels.json](labels.json) contains **26 manually written expected role/name pairs**, omitting offscreen and hidden content. A role/name pair counts as correct once (multiset matching); excess rows remain visible in row counts. Whitespace in names is normalized when scored. Fixture navigation, attachment, load waiting, and viewport discovery happen before the timer; a fresh tab is used per page. Fifteen repeated samples per page/source alternate source order; times are wall-clock round trips including in-process row conversion, *not* production action latency. The table gives median milliseconds, raw min/max milliseconds, emitted rows, correctly named expected pairs, and snapshot CDP calls. Full **225 individual samples**, row arrays and each sample's raw numbers are in [measurements.json](measurements.json).

- **A DOM:** one `Runtime.evaluate` script enumerates semantic elements in DOM order, reads explicit/implicit names, excludes elements without viewport-intersecting layout boxes, hidden details and aria-hidden ancestry. Its JS name algorithm is intentionally partial, not the accessible-name specification. Rows do **not** have a Chrome `backendDOMNodeId`.
- **B AX:** one `Accessibility.getFullAXTree` call, follow `childIds` in document order, retain named semantic controls/heading and paragraph text; Chrome computes names and returns `backendDOMNodeId`. No viewport geometry in the AX response, so offscreen rows are retained.
- **C AX + layout:** `Accessibility.getFullAXTree` followed by `DOMSnapshot.captureSnapshot` (`computedStyles=["display","visibility"]`, `includeDOMRects=true`), join `nodes.backendNodeId[layout.nodeIndex[i]]` to AX `backendDOMNodeId` and intersect `layout.bounds[i]` with the page's previously measured viewport. Paragraph static text uses its parent paragraph node ID. The pair is **not atomic**. The viewport-read setup call is excluded from all three per-snapshot counts; a dynamic viewport needs its own fresh measurement. No geometry is supplied by `getFullAXTree` itself.

| Page | Source | Median ms (min–max) | Rows | Correct names | Snapshot CDP calls |
| --- | --- | ---: | ---: | ---: | ---: |
| form | A DOM | 0.291 (0.156–2.290) | 5 | 5/5 | 1 |
| form | B AX | 0.600 (0.432–4.016) | 5 | 5/5 | 1 |
| form | C AX + layout | 1.078 (0.604–3.666) | 5 | 5/5 | 2 |
| aria | A DOM | 0.157 (0.100–1.173) | 5 | 5/5 | 1 |
| aria | B AX | 0.379 (0.304–0.897) | 5 | 5/5 | 1 |
| aria | C AX + layout | 0.611 (0.485–2.654) | 5 | 5/5 | 2 |
| navigation | A DOM | 0.166 (0.129–3.518) | 4 | 4/4 | 1 |
| navigation | B AX | 0.410 (0.349–0.807) | **6 (2 offscreen)** | 4/4 | 1 |
| navigation | C AX + layout | 0.657 (0.585–0.733) | 4 | 4/4 | 2 |
| select | A DOM | 0.190 (0.107–1.290) | 6 | 6/6 | 1 |
| select | B AX | 0.521 (0.456–1.076) | 6 | 6/6 | 1 |
| select | C AX + layout | 0.833 (0.743–3.017) | 6 | 6/6 | 2 |
| state | A DOM | 0.121 (0.097–1.181) | 6 | 6/6 | 1 |
| state | B AX | 0.343 (0.308–1.634) | 6 | 6/6 | 1 |
| state | C AX + layout | 0.588 (0.516–2.476) | 6 | 6/6 | 2 |

## Decision and consistency limit

**Recommend C, pending confirmation.** It alone returns Chrome-computed accessible names **and actionable backend node IDs** while filtering the two offscreen rows in the viewport fixture. A is faster but its JS result has no backend node IDs; obtaining them from returned per-element object handles would require e.g. `DOM.describeNode` for **each row** (N extra CDP calls), or a separate DOM snapshot/join, also surrendering the one-call advantage. `DOM.pushNodesByBackendIdsToFrontend` resolves *known backend IDs* in the opposite direction and cannot manufacture them from A's elements. B has identities and names in one call but no viewport bounds, violating the visibility story. The evidence only covers five small local pages, not complex accessible names, transformed/occluded layouts, or large-document scaling. C is roughly 2–6x slower than A here, still below 1.1 ms median per page.

**Spec change required:** relax “one atomic browser call per page” to “one logically consistent observation assembled from multiple calls, failing closed/retrying if freshness changes.” Page loader IDs alone detect navigation but not same-document mutation. A deliberate between-call DOM text mutation on the state fixture changed an installed `MutationObserver` counter from **0 to 1** ([consistency.json](consistency.json)); this probe used 5 CDP calls (observer install, AX, mutate, DOMSnapshot, read counter) and is **not** included in the table. A production guard could install a per-document observer and read its counter and loader ID before/after the pair, retry on change, and revalidate target identity/geometry at action time. Those extra reads are **not benchmarked**. A MutationObserver does not catch every layout change (scroll, animation, property-only updates); therefore this is a recommendation to *resolve the consistency contract*, not proof of true atomicity or a production implementation. Mutation observer setup and cross-navigation lifetime need an explicit design before milestone 2.
