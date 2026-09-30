type client = {
  read : Eio_unix.source_ty Eio.Resource.t;
  write : Eio_unix.sink_ty Eio.Resource.t;
}

type t = {
  peer_read : Eio_unix.source_ty Eio.Resource.t;
  peer_write : Eio_unix.sink_ty Eio.Resource.t;
  replies : (string, Yojson.Safe.t -> Yojson.Safe.t) Hashtbl.t;
  mutable messages : Yojson.Safe.t list;
  mutable dropped : bool;
  failures : (string, Yojson.Safe.t -> (int * string) option) Hashtbl.t;
  withheld : (string, Yojson.Safe.t -> bool) Hashtbl.t;
  reader_sleep : float -> unit;
  writes : Eio.Mutex.t;
}

let obj fields = `Assoc fields
let str value = `String value

let target_info =
  obj
    [
      ("targetId", str "target-1");
      ("type", str "page");
      ("title", str "");
      ("url", str "about:blank");
      ("attached", `Bool false);
      ("canAccessOpener", `Bool false);
      ("browserContextId", str "browser-context-1");
    ]

let event = function
  | "Target.targetCreated" | "Target.targetInfoChanged" ->
      obj [ ("targetInfo", target_info) ]
  | "Target.targetDestroyed" -> obj [ ("targetId", str "target-1") ]
  | "Target.attachedToTarget" ->
      obj
        [
          ("sessionId", str "session-1");
          ("targetInfo", target_info);
          ("waitingForDebugger", `Bool false);
        ]
  | "Target.detachedFromTarget" ->
      obj [ ("sessionId", str "session-1"); ("targetId", str "target-1") ]
  | "Page.loadEventFired" | "Page.domContentEventFired" ->
      obj [ ("timestamp", `Float 1.0) ]
  | "Page.frameNavigated" ->
      obj
        [
          ( "frame",
            obj
              [
                ("id", str "frame-1");
                ("loaderId", str "loader-1");
                ("url", str "about:blank");
                ("securityOrigin", str "://");
                ("mimeType", str "text/html");
              ] );
        ]
  (* network events of one fixed request, "request-1": shapes recorded from
     Chrome 152 in docs/cdp-shapes.md (L36). *)
  | "Network.requestWillBeSent" ->
      obj
        [
          ("requestId", str "request-1");
          ("loaderId", str "loader-1");
          ("timestamp", `Float 100.0);
          ("type", str "Fetch");
          ( "request",
            obj
              [
                ("url", str "http://127.0.0.1/api/items");
                ("method", str "GET");
                ("headers", obj [ ("Accept", str "*/*") ]);
              ] );
        ]
  | "Network.responseReceived" ->
      obj
        [
          ("requestId", str "request-1");
          ("timestamp", `Float 100.1);
          ("type", str "Fetch");
          ( "response",
            obj
              [
                ("url", str "http://127.0.0.1/api/items");
                ("status", `Int 200);
                ("mimeType", str "application/json");
              ] );
        ]
  | "Network.loadingFinished" ->
      obj
        [
          ("requestId", str "request-1");
          ("timestamp", `Float 100.25);
          ("encodedDataLength", `Int 42);
        ]
  | "Network.loadingFailed" ->
      obj
        [
          ("requestId", str "request-1");
          ("timestamp", `Float 100.25);
          ("type", str "Fetch");
          ("errorText", str "net::ERR_CONNECTION_REFUSED");
        ]
  | name -> invalid_arg ("no default CDP event shape: " ^ name)

let defaults replies =
  List.iter
    (fun (name, result) -> Hashtbl.replace replies name (fun _request -> result))
    [
      ("Target.createTarget", obj [ ("targetId", str "target-1") ]);
      ("Target.attachToTarget", obj [ ("sessionId", str "session-1") ]);
      ("Target.setDiscoverTargets", obj []);
      ("Browser.setDownloadBehavior", obj []);
      ("Target.setAutoAttach", obj []);
      ("Target.getTargets", obj [ ("targetInfos", `List []) ]);
      ("Target.getTargetInfo", obj [ ("targetInfo", target_info) ]);
      ("Target.closeTarget", obj [ ("success", `Bool true) ]);
      (* hand-04rb: Chrome answers the raise of the live view with an empty result. *)
      ("Target.activateTarget", obj []);
      ("Page.enable", obj []);
      ("Runtime.enable", obj []);
      ("Network.enable", obj []);
      ("DOM.enable", obj []);
      ("Emulation.setFocusEmulationEnabled", obj []);
      ("DOM.focus", obj []);
      ("DOM.scrollIntoViewIfNeeded", obj []);
      ("Input.dispatchMouseEvent", obj []);
      ("Input.insertText", obj []);
      ("Input.dispatchKeyEvent", obj []);
      (* L36 (hard-wk6q): what the net, upload, cookies and storage commands call. *)
      ("Network.getResponseBody", obj [ ("body", str ""); ("base64Encoded", `Bool false) ]);
      ("Network.getRequestPostData", obj [ ("postData", str "") ]);
      ("Network.getCookies", obj [ ("cookies", `List []) ]);
      ("DOM.setFileInputFiles", obj []);
      ("DOMStorage.enable", obj []);
      ("DOMStorage.disable", obj []);
      ("DOMStorage.getDOMStorageItems", obj [ ("entries", `List []) ]);
      ( "Page.getLayoutMetrics",
        obj
          [
            ( "cssLayoutViewport",
              obj
                [
                  ("clientWidth", `Int 800);
                  ("clientHeight", `Int 600);
                  ("pageX", `Int 0);
                  ("pageY", `Int 0);
                ] );
            ( "layoutViewport",
              obj
                [
                  ("clientWidth", `Int 800);
                  ("clientHeight", `Int 600);
                  ("pageX", `Int 0);
                  ("pageY", `Int 0);
                ] );
          ] );
      ("Page.addScriptToEvaluateOnNewDocument", obj [ ("identifier", str "1") ]);
      (* chrome-9ex7: the snapshot guard's isolated world. *)
      ("Page.createIsolatedWorld", obj [ ("executionContextId", `Int 7) ]);
      ( "Page.getFrameTree",
        obj
          [
            ( "frameTree",
              obj
                [
                  ( "frame",
                    obj
                      [
                        ("id", str "frame-1");
                        ("loaderId", str "loader-1");
                        ("url", str "about:blank");
                      ] );
                ] );
          ] );
      ("Accessibility.getFullAXTree", obj [ ("nodes", `List []) ]);
      ( "DOMSnapshot.captureSnapshot",
        obj [ ("documents", `List []); ("strings", `List []) ] );
      ("Page.navigate", obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-1") ]);
      ("Runtime.evaluate", obj [ ("result", obj [ ("type", str "undefined") ]) ]);
    ];
  (* daily-c4cl: the download-history bootstrap owns a separate background target. *)
  let get key = function
    | `Assoc fields -> Option.value (List.assoc_opt key fields) ~default:`Null
    | _ -> `Null
  in
  Hashtbl.replace replies "Target.createTarget" (fun request ->
      let id =
        if get "url" (get "params" request) = str "chrome://downloads/" then
          "download-setup-target"
        else "target-1"
      in
      obj [ ("targetId", str id) ]);
  Hashtbl.replace replies "Target.attachToTarget" (fun request ->
      let id =
        if get "targetId" (get "params" request) = str "download-setup-target" then
          "download-setup-session"
        else "session-1"
      in
      obj [ ("sessionId", str id) ]);
  Hashtbl.replace replies "Runtime.evaluate" (fun request ->
      if get "sessionId" request = str "download-setup-session" then
        obj [ ("result", obj [ ("type", str "boolean"); ("value", `Bool true) ]) ]
      else obj [ ("result", obj [ ("type", str "undefined") ]) ])

let read_frame reader =
  if Eio.Buf_read.at_end_of_input reader then None
  else
    let payload = Eio.Buf_read.take_while (fun c -> c <> '\000') reader in
    Eio.Buf_read.char '\000' reader;
    Some (Yojson.Safe.from_string payload)

let send t message =
  Eio.Mutex.use_rw ~protect:true t.writes (fun () ->
      if not t.dropped then
        Eio.Flow.copy_string (Yojson.Safe.to_string message ^ "\000") t.peer_write)

let withheld t method_ request =
  match Hashtbl.find_opt t.withheld method_ with
  | Some matches -> matches request
  | None -> false

let respond t request =
  t.messages <- request :: t.messages;
  let member name =
    match request with `Assoc fields -> List.assoc_opt name fields | _ -> None
  in
  let method_ = match member "method" with Some (`String m) -> m | _ -> "" in
  (* tab-0ohq: a withheld request is one Chrome never answers -- the reader stays free, so
     the rest of the session keeps being served while the caller waits -- and its scripted
     reply is not built at all. *)
  if not (withheld t method_ request) then
    let answer () =
      match Hashtbl.find_opt t.replies method_ with
      | Some builder -> [ ("result", builder request) ]
      | None ->
          [
            ("error", obj [ ("code", `Int (-32601)); ("message", str "Method not found") ]);
          ]
    in
    let result =
      match Hashtbl.find_opt t.failures method_ with
      | Some builder -> (
          match builder request with
          | Some (code, message) ->
              [ ("error", obj [ ("code", `Int code); ("message", str message) ]) ]
          | None -> answer ())
      | None -> answer ()
    in
    let envelope =
      List.filter_map
        (fun name -> Option.map (fun value -> (name, value)) (member name))
        [ "id"; "sessionId" ]
    in
    send t (obj (envelope @ result))

let create ~sw ?sleep () =
  let peer_read, client_write = Eio_unix.pipe sw in
  let client_read, peer_write = Eio_unix.pipe sw in
  let replies = Hashtbl.create 12 in
  defaults replies;
  let failures = Hashtbl.create 4 in
  let t =
    {
      peer_read;
      peer_write;
      replies;
      failures;
      withheld = Hashtbl.create 4;
      reader_sleep =
        (match sleep with
        | Some sleep -> sleep
        | None -> fun _ -> invalid_arg "Fake_browser: no clock was given to create");
      messages = [];
      dropped = false;
      writes = Eio.Mutex.create ();
    }
  in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      let reader = Eio.Buf_read.of_flow ~max_size:1_048_576 peer_read in
      let rec loop () =
        match read_frame reader with
        | None -> ()
        | Some request ->
            respond t request;
            loop ()
      in
      (* own-teh1 hand-yytf: [drop] closes these ends under the reader, so whatever the
         read then raises is the test's own doing, not a defect to report. *)
      (try loop () with ex when t.dropped -> ignore ex);
      `Stop_daemon);
  (t, { read = client_read; write = client_write })

let on_method t name builder = Hashtbl.replace t.replies name builder
let on_failure t name builder = Hashtbl.replace t.failures name builder
let withhold t name matches = Hashtbl.replace t.withheld name matches
let received t = List.rev t.messages
let sleep t seconds = t.reader_sleep seconds

let emit ?session t ~method_ ~params =
  let envelope = [ ("method", str method_); ("params", params) ] in
  let envelope =
    match session with
    | None -> envelope
    | Some id -> envelope @ [ ("sessionId", str id) ]
  in
  send t (obj envelope)

let drop t =
  Eio.Mutex.use_rw ~protect:true t.writes (fun () ->
      if not t.dropped then (
        t.dropped <- true;
        Eio.Resource.close t.peer_write;
        Eio.Resource.close t.peer_read))
