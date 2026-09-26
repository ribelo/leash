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
| `Target.targetCreated`, `Target.targetInfoChanged` | `{"targetInfo":{"targetId":"target-1","type":"page","title":"","url":"about:blank","attached":false}}` | Page `TargetInfo`; real events can include further optional fields. |
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

Why pipes rather than `Eio_mock.Flow` pairs: the installed mock supports scripted
`on_read` but only traces sink writes; it has no write-to-peer-read routing or
peer close. Two switch-owned Eio pipes give full-duplex bytes and observable EOF
without using Chrome, any socket path, or the network. They are scoped to
`Eta_test.run` in tests.
