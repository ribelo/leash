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
| `Target.createTarget` | `{"targetId":"target-1"}` | Request normally supplies `url`. |
| `Target.attachToTarget` | `{"sessionId":"session-1"}` | Request uses `flatten:true`. |
| `Target.setDiscoverTargets` | `{}` | Request uses `discover:true`. |
| `Target.setAutoAttach` | `{}` | Request uses `autoAttach:true,waitForDebuggerOnStart:false,flatten:true`. |
| `Target.getTargets` | `{"targetInfos":[]}` | Tests can override this with page target infos. |
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

Why pipes rather than `Eio_mock.Flow` pairs: the installed mock supports scripted
`on_read` but only traces sink writes; it has no write-to-peer-read routing or
peer close. Two switch-owned Eio pipes give full-duplex bytes and observable EOF
without using Chrome, any socket path, or the network. They are scoped to
`Eta_test.run` in tests.

## L4 snapshot-source spike (Chrome/152.0.7977.64, headless pipe)

The three measured approaches in [snapshot-source](../.scratch/research/snapshot-source/README.md) use these additional page-session requests/replies; the CDP envelope above still applies. Fixture navigation uses browser-session `Target.createTarget {"url":"about:blank"}`, `Target.attachToTarget {"targetId":"…","flatten":true}`, then page-session `Page.navigate {"url":"data:text/html;charset=utf-8,…"}`. Those setup calls are excluded from the per-snapshot count.

| Source | Request params | Relevant `result` shape |
| --- | --- | --- |
| A DOM | `Runtime.evaluate {"expression":"(() => { … })()","returnByValue":true,"awaitPromise":true}` | `{"result":{"type":"object","value":[{"role":"button","name":"Send message","id":"send"},…]}}`; browser backend ids are **absent**. |
| B AX / first call of C | `Accessibility.getFullAXTree {}` | `{"nodes":[{"nodeId":"…","parentId":"…","childIds":["…"],"ignored":false,"role":{"type":"role","value":"button"},"name":{"type":"computedString","value":"Send message"},"backendDOMNodeId":123},…]}`; the returned nodes have no viewport rectangles. |
| Second call of C | `DOMSnapshot.captureSnapshot {"computedStyles":["display","visibility"],"includeDOMRects":true}` | `{"documents":[{"nodes":{"backendNodeId":[…]},"layout":{"nodeIndex":[…],"bounds":[[x,y,width,height],…],"styles":[…],"clientRects":[…]}}],"strings":[…]}`. Join `nodes.backendNodeId[layout.nodeIndex[i]]` to AX `backendDOMNodeId`; rectangle coordinates are CSS pixels. |

C uses two CDP requests, not an atomic CDP operation. A `Runtime.evaluate` setup/read around the pair can install and read a `MutationObserver` counter for same-document DOM mutations; navigation additionally requires a loader-id guard. Neither guard guarantees layout stayed fixed through scrolling/animation, and the guard calls were not included in the measured 2-call count. Action-time visibility/occlusion must be checked separately.
