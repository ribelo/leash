# CDP shapes for the milestone-1 fake browser

The test peer in [fake_browser.mli](../test/support/fake_browser.mli) speaks
Chrome's remote-debugging-pipe framing: UTF-8 JSON objects separated by NUL
bytes, not WebSocket frames. This is a **fixture contract for milestone 2**,
not a complete generated CDP schema. The fixture's identifiers and timestamp
are fixed; each test can replace any method's reply builder and can emit an event
with custom parameters. The reply echoes the request's numeric `id` and optional
`sessionId` (flat sessions), even when the method is unknown.

| Request method | Default `result` | Notes |
| --- | --- | --- |
| `Target.createTarget` | `{"targetId":"target-1"}` | `new` now supplies `about:blank` and navigates after `Page.enable`, avoiding a missed load for fast pages. |
| `Target.attachToTarget` | `{"sessionId":"session-1"}` | Request uses `flatten:true`. |
| `Target.setDiscoverTargets` | `{}` | Request uses `discover:true`. |
| `Target.setAutoAttach` | `{}` | Request uses `autoAttach:true,waitForDebuggerOnStart:false,flatten:true`. |
| `Target.getTargets` | `{"targetInfos":[]}` | Tests can override this with page target infos. |
| `Target.getTargetInfo` | `{"targetInfo":{"targetId":"target-1","type":"page","title":"","url":"about:blank",…}}` | The fixture page; override to report the loaded document. |
| `Target.closeTarget` | `{"success":true}` | Target id in request. |
| `Page.enable` | `{}` | Send within the flat session. |
| `Page.navigate` | `{"frameId":"frame-1","loaderId":"loader-1"}` | Navigation may instead return `errorText`; override for errors. |
| `Runtime.evaluate` | `{"result":{"type":"undefined"}}` | CDP remote object; override for concrete values/exception details. |

Unknown methods receive `{"error":{"code":-32601,"message":"Method not found"}}`.
For each row, the envelope is `{"id":N,"sessionId":"...","result":...}`
when the request carried a flat-session id; otherwise it omits `sessionId`.

| Event method | Default `params` | Notes |
| --- | --- | --- |
| `Target.targetCreated`, `Target.targetInfoChanged` | `{"targetInfo":{"targetId":"target-1","type":"page","title":"","url":"about:blank","attached":false,"canAccessOpener":false,"browserContextId":"browser-context-1"}}` | Page `TargetInfo`. Real Chrome always sends `canAccessOpener` and `browserContextId`, and adds `parentId`/`parentFrameId` for child frames; tests can script any of them. |
| `Target.targetDestroyed` | `{"targetId":"target-1"}` | Target is gone. |
| `Target.attachedToTarget` | `{"sessionId":"session-1","targetInfo":{...},"waitingForDebugger":false}` | Flat-session attachment; `targetInfo` is as above. |
| `Target.detachedFromTarget` | `{"sessionId":"session-1","targetId":"target-1"}` | `targetId` can be optional in real CDP. |
| `Page.loadEventFired`, `Page.domContentEventFired` | `{"timestamp":1.0}` | Monotonic timestamp. |
| `Page.frameNavigated` | `{"frame":{"id":"frame-1","loaderId":"loader-1","url":"about:blank","securityOrigin":"://","mimeType":"text/html"}}` | The page's main frame, not a load-complete signal by itself. |

Events carry `{"method":"...","params":{...}}`, plus `sessionId`
for page-session events when requested. Event emission is explicit; a
`Page.navigate` reply does **not** imply a subsequent load event. This lets
navigation tests script `loadEventFired` or
`frameNavigated` followed by `domContentEventFired` independently.

## What real Chrome does (152.0.7977.64, checked by `scripts/live-acceptance`)

The live gate launches Chrome through `Leash.Chrome` on a temporary profile, headless
(`--headless=new`, `Chrome.config.headless`), and speaks over the pipe. Everything below
was recorded from that run, not from documentation.

- **Descriptors 3 and 4 must be blocking.** Chrome reads its commands with a blocking
  read: an `EAGAIN` ends the pipe connection. `Eta_process.Child.spawn` maps child
  descriptors 3 and 4 in blocking mode while leaving the Eio parent ends non-blocking.
  The fake browser is unaffected: it speaks the framing itself.
- **The configured binary is usually a launcher script.** On NixOS
  `google-chrome-stable` is a wrapper; the eventual Chrome executable is under
  `share/google/chrome/chrome`. The L3 headless gate identifies the process by the
  exact temporary `--user-data-dir` argument and `--remote-debugging-pipe` in its argv.
- **Chrome rewrites its own command line.** Launch-time flags remain present in
  the browser argv; descendant processes have their own arguments.
- `Target.getTargets` answers Chrome target infos, not the fixture's empty array.
  A fresh profile may include `browser_ui`, new-tab `page`, `background_page` and
  `service_worker` targets. `Target.createTarget {"url":"about:blank"}` returns a
  `targetId`, and the newly created `page` subsequently appears in `getTargets`.
- The pipe launch does not request a debugging port; the private profile has no
  `DevToolsActivePort` file. SIGTERM process retirement belongs to the live L3 gate.
- A page created with `Target.createTarget {"url":"https://example.com/"}` emits
  `Target.targetCreated` and `Target.targetInfoChanged` with the requested URL and an
  empty title, commits, then emits `Page.frameNavigated`, `Target.targetInfoChanged`,
  `Page.domContentEventFired` and `Page.loadEventFired` in that order (measured in a
  fresh profile at 156 ms, 598 ms, 600 ms, 601 ms and 605 ms). The load wait in `Tabs`
  keys on the last two.
- **The pushed title is the tab strip's, not the document's.** That `targetInfoChanged`
  reported `"title":"example.com"` — the formatted URL — and no later event carried the
  document title, while `Target.getTargetInfo {"targetId":…}` asked right after
  `Page.loadEventFired` reported `"title":"Example Domain"` with
  `"url":"https://example.com/"`. `Page.getNavigationHistory` and
  `Runtime.evaluate {"expression":"document.title","returnByValue":true}` agreed with the
  query. `Tabs` therefore refreshes a tab from `Target.getTargetInfo` once the load is
  done (chrome-qnul), so the reply and `list` report the page rather than the tab strip.

Why pipes rather than `Eio_mock.Flow` pairs: the installed mock supports scripted
`on_read` but only traces sink writes; it has no write-to-peer-read routing or
peer close. Two switch-owned Eio pipes give full-duplex bytes and observable EOF
without using Chrome, any socket path, or the network. They are scoped to
`Eta_test.run` in tests.


## L6 snapshot guards (Chrome/152.0.7977.64, real headless pipe)

Probe: `--headless=new`, `--remote-debugging-pipe`, local HTTP origins, no headed browser. The captured `Page.getFrameTree`, `Accessibility.getFullAXTree`, `DOMSnapshot.captureSnapshot`, `Runtime.evaluate` and `Page.addScriptToEvaluateOnNewDocument` results are in [snapshot-chrome.json](../test/fixtures/snapshot-chrome.json). Volatile Chrome IDs and the ephemeral local port are deliberately retained to make this a recognizable real reply rather than an invented shape.

- `Page.addScriptToEvaluateOnNewDocument {"source":"…"}` returned `{"identifier":"1"}`. With `runImmediately:true`, the already-existing `about:blank` document still did **not** gain the guard in this run. `snap` first reads the guard; when absent it evaluates the installer in the current document, then reads again. The registered script covers subsequent documents.
- After cross-document navigation to an HTTP page, the guard existed with a newly generated epoch and count 1; an actual DOM mutation changed count to 2. `history.pushState` and fragment navigation retained that epoch and count. A second cross-document navigation changed epoch and reset the counter to 1. `Page.getFrameTree` provided a main-frame `loaderId`, also compared around both CDP captures.
- The measured AX reply had `nodeId`, `childIds`, `backendDOMNodeId`, role and name; the DOMSnapshot reply had `documents[].nodes.backendNodeId`, `layout.nodeIndex`, `layout.bounds` and `layout.styles`. Its `documents` array contained a main document and a same-origin `about:srcdoc` child. The child had a separate epoch/counter in its own execution context after the parent session registered the script.
- The source joins the top document's layout backend IDs to AX backend IDs and clips **document-relative** rectangles against the viewport at the sampled `scrollX`/`scrollY`. The guard also samples scroll position and viewport dimensions, but cannot detect pure animation between calls. The observer catches DOM mutations; later action execution must revalidate loader, backend node, and geometry. The current main-frame AX capture does not include child-frame AX rows: same-origin and OOPIF content therefore remain explicit visibility limitations, not silently trusted action targets.
- An HTTP iframe pointing from `localhost` to `127.0.0.1` became an OOPIF with a `Target.getTargets` entry of type `iframe` and `parentFrameId`. Browser-level `Target.setAutoAttach` alone did not attach this child; setting `Target.setAutoAttach {"autoAttach":true,"waitForDebuggerOnStart":false,"flatten":true}` on the **page session** produced flattened `Target.attachedToTarget` notifications for the iframe. Its frame was not listed alongside the `about:srcdoc` child in the main session's `Page.getFrameTree` response. Evaluating the guard in the active OOPIF session returned null even though the parent and same-origin srcdoc had it; a second, earlier child session had already disappeared by evaluation time. Parent-page registration does **not** cover the OOPIF session. L6 deliberately excludes these cross-origin child rows rather than claiming they are guarded.

## L4 snapshot-source spike (Chrome/152.0.7977.64, headless pipe)

The three measured approaches in [snapshot-source](../.scratch/research/snapshot-source/README.md) use these additional page-session requests/replies; the CDP envelope above still applies. Fixture navigation uses browser-session `Target.createTarget {"url":"about:blank"}`, `Target.attachToTarget {"targetId":"…","flatten":true}`, then page-session `Page.navigate {"url":"data:text/html;charset=utf-8,…"}`. Those setup calls are excluded from the per-snapshot count.

| Source | Request params | Relevant `result` shape |
| --- | --- | --- |
| A DOM | `Runtime.evaluate {"expression":"(() => { … })()","returnByValue":true,"awaitPromise":true}` | `{"result":{"type":"object","value":[{"role":"button","name":"Send message","id":"send"},…]}}`; browser backend ids are **absent**. |
| B AX / first call of C | `Accessibility.getFullAXTree {}` | `{"nodes":[{"nodeId":"…","parentId":"…","childIds":["…"],"ignored":false,"role":{"type":"role","value":"button"},"name":{"type":"computedString","value":"Send message"},"backendDOMNodeId":123},…]}`; the returned nodes have no viewport rectangles. |
| Second call of C | `DOMSnapshot.captureSnapshot {"computedStyles":["display","visibility"],"includeDOMRects":true}` | `{"documents":[{"nodes":{"backendNodeId":[…]},"layout":{"nodeIndex":[…],"bounds":[[x,y,width,height],…],"styles":[…],"clientRects":[…]}}],"strings":[…]}`. Join `nodes.backendNodeId[layout.nodeIndex[i]]` to AX `backendDOMNodeId`; rectangle coordinates are CSS pixels. |

C uses two CDP requests, not an atomic CDP operation. A `Runtime.evaluate` setup/read around the pair can install and read a `MutationObserver` counter for same-document DOM mutations; navigation additionally requires a loader-id guard. Neither guard guarantees layout stayed fixed through scrolling/animation, and the guard calls were not included in the measured 2-call count. Action-time visibility/occlusion must be checked separately.

## L8 reading/diagnostics (Chrome/152.0.7977.64, headless pipe)

Captured with `--headless=new --remote-debugging-pipe`, attached page session (`Target.createTarget` then `Target.attachToTarget` with `flatten:true`). These are actual response/event members inside the ordinary CDP `{id,result,sessionId}` envelope:

| Operation | Captured result or event |
| --- | --- |
| `Runtime.evaluate {"expression":"document.body.innerText=…; ({ok:true})","returnByValue":true}` | `{"result":{"type":"object","value":{"ok":true}}}`. Evaluating `globalThis` without `returnByValue` supplies `result.objectId` for subsequent calls. |
| `Runtime.callFunctionOn {"objectId":"…","functionDeclaration":"function(argument) { return {echo:argument}; }","arguments":[{"value":{"n":42}}],"returnByValue":true,"awaitPromise":true}` | `{"result":{"type":"object","value":{"echo":{"n":42}}}}`. The service passes the argument as a CDP value, not interpolation into JavaScript. |
| `Page.captureScreenshot {"format":"png","captureBeyondViewport":true}` | `{"data":"iVBORw0KGgoAAAAN…"}` (3956 base64 characters for blank page). Its PNG bytes live only on CDP; control replies include path and byte count. |
| `Runtime.consoleAPICalled` | `{"type":"warning","args":[{"type":"string","value":"reading-console"}],"timestamp":1790497397382.821,…}`. |
| `Runtime.exceptionThrown` | `{"exceptionDetails":{"text":"Uncaught","exception":{"description":"Error: reading-uncaught\n    at <anonymous>:1:59",…},…}}`. Description carries the useful error message; `text` alone does not. |
| `Network.loadingFailed` | `{"type":"Fetch","errorText":"net::ERR_UNSAFE_PORT","canceled":false,"requestId":"…",…}` from a failed localhost fetch. |
| `Page.javascriptDialogOpening` / `Page.javascriptDialogClosed` | Opening `{"type":"alert","message":"reading-dialog","hasBrowserHandler":true,"defaultPrompt":"",…}`; after explicit `Page.handleJavaScriptDialog {"accept":false}`, closed `{"result":false,"userInput":"",…}` and command result `{}`. No dialog answer was sent until explicit action. |


## L7 actions (Chrome/152.0.7977.64, headless pipe)

Probe: `--headless=new`, `--remote-debugging-pipe`, one attached page session, a
`data:text/html` page with a button wrapping a `<span>`, a text input, a native `<select>`
and a 2000 px filler. The raw replies are in
[probe-results.json](../.scratch/actions/probe-results.json). These are the calls one action
makes, in the order a click makes them.

| Operation | Captured result |
| --- | --- |
| `Page.getFrameTree {}` | `{"frameTree":{"frame":{"id":"7E37…","loaderId":"005A…","url":"data:text/html;charset=utf-8,…"}}}` — the loader id a snapshot and an action compare. |
| `DOM.getContentQuads {"backendNodeId":10}` | `{"quads":[[0,68.9375,200,68.9375,200,108.9375,0,108.9375]]}` — eight numbers per quad (x1,y1,x2,y2,x3,y3,x4,y4), CSS pixels in the viewport, integers and floats mixed. |
| `DOM.getNodeForLocation {"x":100,"y":88.9375,"includeUserAgentShadowDOM":false}` (historical probe; L9 requires integers) | `{"backendNodeId":31,"frameId":"7E37…","nodeId":115}` — the **deepest** node at the point, so a button with a label span answers with the span's backend id, not the button's. Answered the same before and after `DOM.enable`, so the hit test does not depend on the DOM agent being enabled. |
| `DOM.describeNode {"nodeId":115}` and `{"backendNodeId":31}` | `{"node":{"nodeId":115,"backendNodeId":30,"nodeType":1,"nodeName":"SPAN",…}}` — **no `parentId`** for the described node, and children of a subtree describe carry `"parentId":0`. There is no parent chain to walk: descendanthood is decided by `DOM.describeNode {"backendNodeId":row,"depth":-1}` and matching the hit's `backendNodeId` in that subtree (3 nodes for the probe's button). |
| `DOM.focus {"backendNodeId":3}` | `{}`. |
| `Input.dispatchKeyEvent {"type":"keyDown","modifiers":2,"key":"a","code":"KeyA","windowsVirtualKeyCode":65,"nativeVirtualKeyCode":65}`, then the `keyUp` | `{}`; the page's own `keydown` listener saw `["keydown","a","KeyA",65]`, so the modifier reaches the page. |
| `Input.insertText {"text":"hello"}` | `{}`; the input's value became `"hello"` (it was `"old"`), and `Runtime.evaluate "document.activeElement.blur()"` fired the page's `input` then `change` events. |
| `Input.dispatchKeyEvent {"type":"keyDown","key":"Enter","code":"Enter","windowsVirtualKeyCode":13,"nativeVirtualKeyCode":13,"text":"\r"}` | `{}`; the page's listener saw `["keydown","Enter","Enter",13]`. |
| `DOM.resolveNode {"backendNodeId":4}` | `{"object":{"type":"object","subtype":"node","className":"HTMLSelectElement","description":"select#sel","objectId":"-476…"}}`. |
| `Runtime.callFunctionOn {"objectId":"…","functionDeclaration":"function (index) { … }","arguments":[{"value":2}],"returnByValue":true}` | `{"result":{"type":"string","value":"c"}}`; the select's value became `"c"`. |
| `Page.getLayoutMetrics {}` | `{"cssLayoutViewport":{"pageX":0,"pageY":0,"clientWidth":765,"clientHeight":493},…,"cssContentSize":{"x":0,"y":0,"width":765,"height":2109}}`. The fake's fixture is 800x600 for readability; the shape is this one. |
| `Input.dispatchMouseEvent {"type":"mouseWheel","x":400,"y":300,"deltaX":0,"deltaY":600,"pointerType":"mouse"}` | `{}`; `window.scrollY` was still `0` immediately after and `600` some 300 ms later — Chrome animates wheel scrolling, so a settle of two frames does not see the final offset. |
| `Emulation.setFocusEmulationEnabled {"enabled":true}` | `{}`; `document.hasFocus()` was already true in this headless run. |
| `Runtime.evaluate {"expression":"new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => resolve(true))))","returnByValue":true,"awaitPromise":true}` | `{"result":{"type":"string","value":"two-frames"}}` after 15–20 ms. `awaitPromise:true` on a non-promise expression returns its value instead of failing. |
| `Runtime.evaluate` of the suggestions probe | `{"result":{"type":"boolean","value":false}}` on a page with no listbox. |

Two shapes an action depends on but does not control:

- The click landed: dispatching press and release at that quad centre set the button's
  `onclick` result, `document.title = "clicked"`.
- A native `<select>` with no label is the AX `combobox` with an **empty** name, so the
  snapshot's non-empty-name rule leaves it out of the table. `select` therefore targets a
  labelled select, and the L9 acceptance page should label its dropdown (or give it
  `aria-label`).

## L9 live acceptance (headless CLI/service/Chrome pipe)

Run `bash scripts/live-acceptance-m2` for the real-service gate. Public `https://www.wikipedia.org/` exposed a named search input; filling `Ada Lovelace` and pressing Enter navigated to `https://en.wikipedia.org/wiki/Ada_Lovelace`. Public `https://www.w3.org/WAI/tutorials/forms/grouping/` exposed `<select id="course">` as AX `combobox` named `Course:` once scrolled into view; choosing option index 2 yielded value `8.01.2`. Before scroll the select was absent from the visible table; after scroll the initial top navigation disappeared. `DOMSnapshot.layout.bounds` on that long page are document coordinates, not viewport coordinates; `scrollY` reached thousands of CSS pixels and must be added to the viewport clip.

The deterministic local `/overlay` page established `DOM.getNodeForLocation` returned `{"backendNodeId":10,"frameId":"…"}` at the covered target centre `(110,106)`, distinct from its row backend id 9; `click` refused `row-not-actionable`. The uncovered dismiss button had a fractional quad centre `(314.65625,90.5)`: sending those fractions to `DOM.getNodeForLocation` returned CDP error `-32602 Invalid parameters` **in this live service run**, although the earlier L7 probe recorded a fractional request succeeding. Rounded integer `(315,91)` hit the dismiss button; dismissal then allowed the target click and changed the title to `Overlay clicked`. `Input.dispatchMouseEvent` still accepts fractional CSS coordinates. Local fixtures replace the requested public overlay/clock because their occlusion and mutation timing must be repeatable. A background-tab focus button observed `document.hasFocus() == true` and ongoing animation frames; a heavy live clock yielded a visible `settled:false` snapshot after three inconsistent guarded pairs. Service SIGTERM exited 0 and its isolated headless Chrome disappeared.

## L10 empty-name controls and popup openers (Chrome/152.0.7977.64, headless pipe)

Probe: `--headless=new`, `--remote-debugging-pipe`, one attached page session, browser-level
`Target.setDiscoverTargets` and `Target.setAutoAttach` (`flatten:true`), and a
`data:text/html` page with an unlabelled `<select>`, a bare `<input type="text">`, an
`<input type="text" placeholder="Search terms">`, and a `<button>` whose only child is an
`<svg>`. The raw AX tree, DOMSnapshot, guard, frame tree and popup TargetInfos are in
[unlabelled-controls-chrome.json](../test/fixtures/unlabelled-controls-chrome.json).

The measured accessibility table for those controls:

| Element | AX role | AX name | AX `value` | Other members |
| --- | --- | --- | --- | --- |
| unlabelled `<select>` | `combobox` | `""` | `"Alpha"` (the selected option's text) | `properties` `focusable`, `hasPopup:"menu"`, `expanded:false`; one `MenuListPopup` child holding the `option` nodes |
| bare `<input type="text">` | `textbox` | `""` | absent — the node has no `value` member | `properties` `editable:"plaintext"`, `settable:true`, `readonly:false` |
| `<input placeholder="Search terms">` | `textbox` | `"Search terms"` | absent | the same members |
| `<button><svg/></button>` | `button` | `""` | absent | one `image` child with an empty name |

- Chrome computes a text input's accessible name from its `placeholder` when nothing else
  names it, so a placeholder-only input is **not** nameless, and there is no placeholder
  member anywhere in the accessibility reply. A control whose name is empty and which still
  has a placeholder attribute is identified through the DOM half of the join:
  `DOMSnapshot.captureSnapshot` returns `nodes.attributes[i]` as a flat
  `[nameIndex, valueIndex, …]` array of indexes into `strings`, aligned with
  `nodes.backendNodeId[i]`, so the attribute is read on the same backend node id the AX
  tree uses. `Snapshot_source.rows` keeps a control with an empty name and falls back to
  that attribute for the row's `value` (tab-zc36).
- An unnamed icon button is a `button` whose child is an `image` node (not `img`), and the
  unlabelled select's options hang under a `MenuListPopup` node. Neither AX-only role is in
  the L6 role list, so neither becomes a row of its own.

A popup opened from that page (`window.open('about:blank','popwin')` under a user gesture)
appeared as a target whose every pushed TargetInfo carries the opener:

```json
{"targetId":"90FCA3FE…","type":"page","title":"","url":"","attached":true,
 "openerId":"247E5BA9…","canAccessOpener":true,"openerFrameId":"247E5BA9…",
 "browserContextId":"8B419239…"}
```

- `Target.getTargetInfo` answers with the same members and `Target.getTargets` lists the
  popup with `openerId`; `Target.targetCreated`, `Target.targetInfoChanged` and
  `Target.attachedToTarget` all carry it, with `attached` moving `false` → `true` as the
  auto-attach session is created. A target with no opener omits `openerId` entirely and
  reports `canAccessOpener:false`. `openerId` names the opener's **target id**; the popup's
  `openerFrameId` is that same id for a main-frame opener. That field is what `Tabs` adopts
  a page's popup with, and what `Actions` reports a popup by (tab-8k2g).
- **The call that opens a popup gets no reply while the popup exists.** The
  `Runtime.evaluate` running `window.open` was still unanswered when a five-second deadline
  expired, while a second `Runtime.evaluate` on the same page session answered normally in
  that window; the popup target existed, was attached, and stayed at `url:""`, `title:""`
  because nothing had navigated it. `Input.dispatchMouseEvent` for a click whose handler
  called `window.open` behaved the same way. An action that opens a popup therefore waits on
  the browser, not on the action's own settle budget, and the 30-second CDP deadline is what
  bounds it. The control-seam tests script these events, so this timing can only be caught by
  live acceptance.
