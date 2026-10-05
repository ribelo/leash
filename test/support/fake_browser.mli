(* Scripted CDP peer. [create] owns two Eio pipes and its reader fiber on [sw].
    Eio_mock.Flow can script reads but its sink only traces writes; it cannot route
    writes into a peer's read stream or close that stream. Two [Eio_unix.pipe] flows
    provide the actual duplex stream, deterministic without Chrome or a socket.

    Frames are compact JSON followed by NUL. Each complete request is recorded before
    dispatch. Responses echo the request's [id] and, if present, [sessionId]. Unknown
    methods return CDP error [-32601]; [on_method] overrides any default per test.

    Default reply shapes (the empty/default ids are deliberate fixture values):
    - Target.createTarget: {targetId:"target-1"}
    - Target.attachToTarget: {sessionId:"session-1"} (flatten mode)
    - Target.setDiscoverTargets / Target.setAutoAttach: {}
    - Target.getTargets: {targetInfos:[]}
    - Target.getTargetInfo: {targetInfo:{targetId:"target-1",type:"page",title:"",url:"about:blank",…}}
      (the fixture page; override for the document title a load reports, see
      docs/cdp-shapes.md)
    - Target.closeTarget: {success:true}; Target.activateTarget: {}
    - Page.enable: {}; Page.navigate: {frameId:"frame-1",loaderId:"loader-1"}
    - Page.addScriptToEvaluateOnNewDocument: {identifier:"1"}; Page.getFrameTree:
      {frameTree:{frame:{id:"frame-1",loaderId:"loader-1",url:"about:blank"}}}
    - Accessibility.getFullAXTree: {nodes:[]}; DOMSnapshot.captureSnapshot:
      {documents:[],strings:[]}; Runtime.evaluate: {result:{type:"undefined"}}
      Tests override AX, DOMSnapshot and guard with fixtures captured from real Chrome.
    - DOM.enable, DOM.focus, DOM.scrollIntoViewIfNeeded, Input.dispatchMouseEvent,
      Input.insertText, Input.dispatchKeyEvent, Emulation.setFocusEmulationEnabled: {};
      Page.getLayoutMetrics: an 800x600 css layout viewport (the measured shape is in
      docs/cdp-shapes.md).

    - L36 (hard-wk6q): Network.getResponseBody: {body:"",base64Encoded:false};
      Network.getRequestPostData: {postData:""}; Network.getCookies: {cookies:[]};
      DOM.setFileInputFiles: {}; DOMStorage.enable / disable: {};
      DOMStorage.getDOMStorageItems: {entries:[]}.

    Event shapes available through [event] are Target.targetCreated and
    Target.targetInfoChanged
    ({targetInfo:{targetId,type,title,url,attached,canAccessOpener,browserContextId}} —
    the last two are what real Chrome sends, see docs/cdp-shapes.md),
    Target.targetDestroyed ({targetId}), Target.attachedToTarget
    ({sessionId,targetInfo,waitingForDebugger}), Target.detachedFromTarget
    ({sessionId,targetId}), Page.loadEventFired ({timestamp}),
    Page.frameNavigated ({frame:{id,loaderId,url,securityOrigin,mimeType}}), and Page.domContentEventFired
    ({timestamp}), and the four network events of one fixed request ["request-1"]:
    Network.requestWillBeSent, Network.responseReceived, Network.loadingFinished and
    Network.loadingFailed (hard-xg6y). [emit] can also send arbitrary event names and params, which is how a test
    scripts a popup: the Target.attachedToTarget targetInfo then carries the [openerId] the
    default fixture omits, recorded from real Chrome in docs/cdp-shapes.md and
    test/fixtures/unlabelled-controls-chrome.json (tab-8k2g).

    Chrome announces a target with Target.targetCreated before it attaches to it, so a test
    scripts a tab the human opened — or a page's popup — by emitting that announcement with
    the [openerId] and sessionless targetInfo, and lets the attachment follow (own-c0cl
    own-ehqa). The default event shape is the fixture page [target-1]; [emit] papers over
    the rest. *)

val png : string
(** Base64 of a complete 800x600 PNG for viewport capture fixtures. *)

val png_bytes : int

type t

type client = {
  read : Eio_unix.source_ty Eio.Resource.t;
  write : Eio_unix.sink_ty Eio.Resource.t;
}

val create : sw:Eio.Switch.t -> ?sleep:(float -> unit) -> unit -> t * client
(** [sleep] is what a scripted reply may wait on before it is sent, so a test drives a
    slow reply with the clock it passes here ([Eio.Time.sleep] of the mock clock,
    usually); a request whose script never sleeps is answered as soon as it is read.

    Suspension: may suspend creating pipes and starts the switch-owned peer reader.
    Cancellation: propagates from pipe and fiber startup. Finalizers: sw owns pipe ends
    and the peer daemon. Locking: the fake serializes outgoing frames with its write
    mutex. Cancellation safety: safe to re-run on a fresh switch after closing the old
    fake; construction issues no browser action. [Invalid_argument] is raised if [sw] has
    finished or belongs to another domain when Eio.Fiber.fork_daemon checks it during
    startup. Exceptions in the peer daemon fail [sw], not the calling fiber. *)

val on_method : t -> string -> (Yojson.Safe.t -> Yojson.Safe.t) -> unit

val on_failure : t -> string -> (Yojson.Safe.t -> (int * string) option) -> unit
(** [on_failure t name builder] lets [name] answer with a CDP error instead of its
    response: [Some (code, message)] becomes [{"error":{"code":code,"message":message}}]
    and [None] answers as usual. It is how a test fails one request of a sequence, which
    is what "never retried" is asserted on. *)

val withhold : t -> string -> (Yojson.Safe.t -> bool) -> unit
(** [withhold t name matches] makes every [name] request whose params satisfy [matches]
    get no reply at all: it is recorded, and its scripted reply is not built or sent,
    while the reader keeps serving the rest of the session. This is what Chrome does to a
    call whose handler opens a popup (docs/cdp-shapes.md, L10; tab-0ohq). *)

val stop_evaluating : t -> session:string -> unit
(** field-zr9n: this session stops answering Runtime.evaluate. Screenshot and all other
    calls, including evaluations in other sessions, still answer. *)

val sleep : t -> float -> unit
(** Waits on the sleep function {!create} was given; a test advances its mock clock to let
    the delay pass. [Invalid_argument] when [create] was given no sleep. *)

val received : t -> Yojson.Safe.t list
val emit : ?session:string -> t -> method_:string -> params:Yojson.Safe.t -> unit

(* Default event params for the named event. Raises [Invalid_argument] for unknown
    names; [emit] accepts arbitrary params instead. *)
val event : string -> Yojson.Safe.t

val drop : t -> unit
(** Idempotently close both peer ends. The client's [read] reaches EOF and later writes
    fail; [drop] does not close the client's ends. *)
