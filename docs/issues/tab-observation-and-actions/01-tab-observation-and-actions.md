---
status: ready-for-agent
milestone: 2
---

# Observe a tab as an element table and act on its rows

## Problem Statement

An agent needs to see what is on a page and do something to it. The existing script offers an accessibility snapshot with stamped references, CSS selectors, semantic locators, and raw CDP, which is several ways to say the same thing and several ways to be stale. Nothing an agent sees is what a decision model would see.

## Solution

One snapshot per observation: url, title, and a numbered element table. Every action targets a row index from that snapshot and is refused if the snapshot is stale. Rendered text, screenshots, a debug log, arbitrary evaluation, bounded waits, and dialog answers complete the set. This is the same table the drive loop feeds to JEV.

## User Stories

1. As an agent, I want `leash snap <tab>` to return a numbered table of the page's interactive and informative elements with role, name, and value or state, so that I can pick what to act on without reading HTML. ^tab-of0i
2. As an agent, I want the table to include only elements that are visible in the layout, with offscreen article bodies and footers left out, so that my context is spent on what matters. ^tab-tmoc
3. As an agent, I want each snapshot to carry an id that the next snapshot invalidates, so that I never act on a table from a page that has changed. ^tab-1r34
4. As an agent, I want `snap --match TEXT` to return only rows whose role, name, or value contains the text, so that I can find one control on a long page cheaply. ^tab-hyap
5. As an agent, I want `snap --limit N --offset M` with truthful `total` and `truncated`, so that I can page through a large table. ^tab-1rx9
6. As an agent, I want a snapshot to report an open dialog with its kind and message, so that I know why the page is not responding. ^tab-0vh8
7. As an agent, I want `leash click <tab> <index>` to click the row after checking it is still present, visible, enabled, and not covered at its click point, so that a click lands where the table said. ^tab-bw4j
8. As an agent, I want `click` on a row the page has replaced to fail with `stale-snapshot`, so that I re-observe instead of clicking whatever is now there. ^tab-j1z2
9. As an agent, I want `leash fill <tab> <index> <text>` to set a text control's value the way a user typing would, so that framework-controlled inputs see the change. ^tab-p3x1
10. As an agent, I want `leash press <tab> <key> [--index N]` to send a key to a row or to the page, so that I can submit with Enter or dismiss with Escape. ^tab-luo5
11. As an agent, I want `leash select <tab> <index> <option>` to choose a native select option by its observed option index, so that dropdowns work without clicking through them. ^tab-5deq
12. As an agent, I want `leash scroll <tab> up|down [--index N]` to scroll the page or the row's nearest scrollable ancestor by one viewport, so that I can bring more rows into view. ^tab-8dop
13. As an agent, I want every action reply to carry the tab's url and title after the action and any popups it opened, so that I notice navigation and new tabs without another call. ^tab-tm6c
14. As an agent, I want actions on one tab to run one at a time in arrival order while other tabs proceed, so that two of my calls cannot interleave on one page. ^tab-hxld
15. As an agent, I want `leash wait <tab> --url-prefix U --text T --timeout MS` to block until all conditions hold or the bounded timeout passes, so that I can wait for a result page without polling. ^tab-9x5e
16. As an agent, I want `leash text <tab> [--index N]` to return rendered inner text of the page or one row, bounded and marked truncated, so that I can read content the table only names. ^tab-x4v0
17. As an agent, I want `leash eval <tab> <expression>` to run JavaScript in the page with an optional argument and return a JSON value bounded to 64 KiB, so that I can inspect or compute what the table cannot express. ^tab-a33o
18. As an agent, I want `leash shot <tab> <path> [--full-page]` to write a PNG and return only the path and size, so that I can look at the page without pushing image bytes through the protocol. ^tab-qmei
19. As an agent, I want `leash debug <tab>` to return the newest console messages, uncaught exceptions, and failed requests since the tab opened, bounded and clearable, so that I can diagnose a page that misbehaves. ^tab-5vnm
20. As an agent, I want any action while a dialog is open to fail with `dialog-open`, so that I answer it deliberately. ^tab-60kn
21. As an agent, I want `leash dialog <tab> accept|dismiss [--text T]` to answer the open dialog and `no-dialog` when there is none, so that I control what the page is told. ^tab-un75
22. As an operator, I want Leash never to answer a dialog on its own, so that a page cannot make an agent confirm something unseen. ^tab-fepr
23. As an agent, I want a failed action never to be replayed by Leash, so that a click whose outcome I do not know is not issued twice. ^tab-1lhx
24. As an agent, I want fill text over 64 KiB, or an eval expression, argument, or result over its bound, refused with `too-large`, so that I get a clear limit instead of a hang. ^tab-0lax
25. As an agent, I want background tabs to keep rendering while I act on them, so that animations and lazy content settle without my tab being the visible one. ^tab-8la3
26. As an operator, I want `leash snap --table` to render the table for a human in one line per row, so that I can follow what an agent sees. ^tab-ok2i

## Implementation Decisions

- The table's rows come from the accessibility tree joined with `DOMSnapshot` (decision under Further Notes). A snapshot is one logically consistent observation from two guarded calls, and every row keeps the backend node id for later resolution; the guard and the action-time revalidation are specified under Further Notes.
- A snapshot records a freshness fingerprint: the frame's loader id plus a digest of the table. `stale-snapshot` is raised when the loader id changed, when the targeted row's node no longer resolves, or when its role/name differ from the snapshot. Animation alone does not make a snapshot stale.
- Click resolves current geometry at action time, rejects a covered click point, and dispatches trusted CDP mouse events. Fill focuses the node, selects its content, and inserts text through `Input.insertText`, then dispatches change semantics by blur; it never assigns `value` directly. Press uses `Input.dispatchKeyEvent` with a small key-name table.
- Post-action settle is bounded as in jev-ultrafast: after typing into a combobox wait for visible suggestions up to 200 ms; otherwise two animation frames or 50 ms. The action reply's fresh snapshot id is set only when a snapshot was taken as part of settling.
- Per-tab serialization is a per-tab `Eta.Semaphore` of one; the registry runs each tab's queue in its own fiber.
- Dialogs: `Page.javascriptDialogOpening` sets the tab's dialog; the dialog action calls `Page.handleJavaScriptDialog`. `beforeunload` is a dialog like any other.
- Debug log is a bounded ring of 200 entries per tab fed by `Runtime.consoleAPICalled`, `Runtime.exceptionThrown`, and `Network.loadingFailed` plus 4xx/5xx responses.
- Screenshots use `Page.captureScreenshot`; full-page captures use `captureBeyondViewport` with the content size; the file is written by the service at the absolute path given, 20 MiB bound.
- Eval wraps the expression as a function body called with the argument via `Runtime.callFunctionOn` with `returnByValue`; the result is re-encoded and bounded.

## Testing Decisions

- Tests script the fake browser's DOM state as the table the snapshot call would produce and its responses to node resolution and input methods; assertions are on protocol replies and on the sequence of CDP messages the fake received.
- Staleness tests change the fake's loader id or node table between snap and action: tab-1r34, tab-j1z2.
- Serialization tests issue overlapping actions on one tab and on two tabs and assert order at the fake: tab-hxld.
- Dialog tests raise the event from the fake mid-action: tab-0vh8, tab-60kn, tab-un75, tab-fepr.
- Bounds tests: tab-1rx9, tab-x4v0, tab-a33o, tab-0lax, tab-5vnm.
- Protocol-seam tests for the rest: tab-of0i, tab-hyap, tab-bw4j, tab-p3x1, tab-luo5, tab-5deq, tab-8dop, tab-tm6c, tab-9x5e, tab-qmei, tab-1lhx, tab-ok2i.
- Live-acceptance only: tab-tmoc (visibility on real layouts), tab-8la3 (focus emulation), and click occlusion on real pages.

## Out of Scope

iframes, shadow roots, canvas, file inputs, drag and drop, hover, batch steps, CDP event subscriptions, network timings, typing at the current focus without a target.

## Further Notes

- Snapshot source — **decided 2026-09-26: the accessibility tree joined with `DOMSnapshot.captureSnapshot` on `backendDOMNodeId`** (L4 spike, `.scratch/research/snapshot-source/README.md`). Reasons: Chrome's computed role and name implement the accessible-name specification, which a DOM script does not (the five local pages could not tell them apart; real sites will); the join yields node ids to act on and layout to filter offscreen rows; the extra half-millisecond is nothing next to a page. Consistency contract, replacing "one atomic browser call": **one logically consistent observation assembled from two calls, guarded**. The guard is the frame's loader id plus a per-document mutation counter installed with `Page.addScriptToEvaluateOnNewDocument` (so it exists in every document without per-snapshot setup), read before the accessibility call and after the layout call; on a change the pair is retaken, at most twice; if it still changes the snapshot is returned with `settled:false` in the reply rather than failing, because pages with perpetual mutation (clocks, ads) must remain observable. Atomicity is not the safety mechanism; action-time revalidation is: before dispatch, the loader id must be unchanged, `DOM.describeNode` on the row's backend node id must succeed with the same role/name, geometry comes from `DOM.getContentQuads` at that moment, and the click point must hit-test to that node or a descendant (`DOM.getNodeForLocation`). Scrolling and animation are never staleness (ADR-0004).
- Whether `state` needs `focused` is open; jev-ultrafast does not carry it and JEV has not seen it.
