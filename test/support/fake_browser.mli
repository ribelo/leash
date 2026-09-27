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
    - Target.closeTarget: {success:true}
    - Page.enable: {}; Page.navigate: {frameId:"frame-1",loaderId:"loader-1"}
    - Page.addScriptToEvaluateOnNewDocument: {identifier:"1"}; Page.getFrameTree:
      {frameTree:{frame:{id:"frame-1",loaderId:"loader-1",url:"about:blank"}}}
    - Accessibility.getFullAXTree: {nodes:[]}; DOMSnapshot.captureSnapshot:
      {documents:[],strings:[]}; Runtime.evaluate: {result:{type:"undefined"}}
      Tests override AX, DOMSnapshot and guard with fixtures captured from real Chrome.

    Event shapes available through [event] are Target.targetCreated and
    Target.targetInfoChanged
    ({targetInfo:{targetId,type,title,url,attached,canAccessOpener,browserContextId}} —
    the last two are what real Chrome sends, see docs/cdp-shapes.md),
    Target.targetDestroyed ({targetId}), Target.attachedToTarget
    ({sessionId,targetInfo,waitingForDebugger}), Target.detachedFromTarget
    ({sessionId,targetId}), Page.loadEventFired ({timestamp}),
    Page.frameNavigated ({frame:{id,loaderId,url,securityOrigin,mimeType}}), and Page.domContentEventFired
    ({timestamp}). [emit] can also send arbitrary event names and params. *)

type t

type client = {
  read : Eio_unix.source_ty Eio.Resource.t;
  write : Eio_unix.sink_ty Eio.Resource.t;
}

val create : sw:Eio.Switch.t -> unit -> t * client
val on_method : t -> string -> (Yojson.Safe.t -> Yojson.Safe.t) -> unit
val received : t -> Yojson.Safe.t list
val emit : ?session:string -> t -> method_:string -> params:Yojson.Safe.t -> unit

(* Default event params for the named event. Raises [Invalid_argument] for unknown
    names; [emit] accepts arbitrary params instead. *)
val event : string -> Yojson.Safe.t

val drop : t -> unit
(** Idempotently close both peer ends. The client's [read] reaches EOF and later writes
    fail; [drop] does not close the client's ends. *)
