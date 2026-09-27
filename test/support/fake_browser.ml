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
  | name -> invalid_arg ("no default CDP event shape: " ^ name)

let defaults replies =
  List.iter
    (fun (name, result) -> Hashtbl.replace replies name (fun _request -> result))
    [
      ("Target.createTarget", obj [ ("targetId", str "target-1") ]);
      ("Target.attachToTarget", obj [ ("sessionId", str "session-1") ]);
      ("Target.setDiscoverTargets", obj []);
      ("Target.setAutoAttach", obj []);
      ("Target.getTargets", obj [ ("targetInfos", `List []) ]);
      ("Target.getTargetInfo", obj [ ("targetInfo", target_info) ]);
      ("Target.closeTarget", obj [ ("success", `Bool true) ]);
      ("Page.enable", obj []);
      ("Page.addScriptToEvaluateOnNewDocument", obj [ ("identifier", str "1") ]);
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
    ]

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

let respond t request =
  t.messages <- request :: t.messages;
  let member name =
    match request with `Assoc fields -> List.assoc_opt name fields | _ -> None
  in
  let method_ = match member "method" with Some (`String m) -> m | _ -> "" in
  let result =
    match Hashtbl.find_opt t.replies method_ with
    | Some builder -> [ ("result", builder request) ]
    | None ->
        [
          ("error", obj [ ("code", `Int (-32601)); ("message", str "Method not found") ]);
        ]
  in
  let envelope =
    List.filter_map
      (fun name -> Option.map (fun value -> (name, value)) (member name))
      [ "id"; "sessionId" ]
  in
  send t (obj (envelope @ result))

let create ~sw () =
  let peer_read, client_write = Eio_unix.pipe sw in
  let client_read, peer_write = Eio_unix.pipe sw in
  let replies = Hashtbl.create 12 in
  defaults replies;
  let t =
    {
      peer_read;
      peer_write;
      replies;
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
      (try loop () with Eio.Io _ when t.dropped -> ());
      `Stop_daemon);
  (t, { read = client_read; write = client_write })

let on_method t name builder = Hashtbl.replace t.replies name builder
let received t = List.rev t.messages

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
