(* L36 hardening 2 (milestone 8): hard-xg6y hard-ovbx hard-vq5s hard-sr9v hard-sckn
   hard-o3za hard-2gnf hard-v1gs hard-b20d hard-ufb7 hard-wk6q hard-b1na. Everything runs
   at the control-protocol seam against the scripted CDP peer; the concurrency story also
   crosses the real control socket. hard-2cal (the leash skill's lines) lives outside this
   repository. *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let int n = `Int n
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.failf "missing %s" key

let text key json =
  match get key json with `String s -> s | _ -> Alcotest.failf "%s is not text" key

let count key json =
  match get key json with `Int n -> n | _ -> Alcotest.failf "%s is not an int" key

let list key json =
  match get key json with `List xs -> xs | _ -> Alcotest.failf "%s is not a list" key

let owner name =
  match P.Owner.of_string name with Ok x -> x | Error e -> Alcotest.fail e

let handle_of json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let snapshot_of json =
  match P.Snapshot_id.t_of_yojson (get "snapshot" json) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let code = function
  | P.Failure e -> P.Error_code.to_string e.code
  | P.Success _ -> Alcotest.fail "expected a failure"

let result = function
  | P.Success json -> json
  | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let check_code label expected reply = Alcotest.(check string) label expected (code reply)

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec scan at = at + n <= h && (String.sub haystack at n = needle || scan (at + 1)) in
  n = 0 || scan 0

let rig ?(cap = 14) f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw ~sleep:(Eio.Time.sleep clock) () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Ox_observability.Logger.create ~service:"leash-hardening-2" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-hardening-2-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap ~tombstone_s:3600
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
          }
      in
      let rec ready n =
        if n = 0 then Alcotest.fail "no Chrome"
        else
          match Chrome.connection chrome with
          | Ok _ -> ()
          | Error _ ->
              Eio.Fiber.yield ();
              ready (n - 1)
      in
      ready 1000;
      let fake () =
        match !current with Some fake -> fake | None -> Alcotest.fail "no fake"
      in
      f env sw tabs fake)

let eventually what predicate =
  let rec loop n =
    if predicate () then ()
    else if n = 0 then Alcotest.failf "never happened: %s" what
    else (
      Eio.Fiber.yield ();
      loop (n - 1))
  in
  loop 200_000

(* The registry hands every tab a page session of its own: target-N is attached as
   session-N, so a test can feed each tab's ring separately. *)
let many_tabs fake =
  let created = ref 0 in
  Fake.on_method fake "Target.createTarget" (fun _ ->
      incr created;
      obj [ ("targetId", str (Printf.sprintf "target-%d" !created)) ]);
  Fake.on_method fake "Target.attachToTarget" (fun request ->
      let target =
        match field "params" request with
        | Some params -> (
            match field "targetId" params with Some (`String s) -> s | _ -> "")
        | None -> ""
      in
      let n = String.sub target 7 (String.length target - 7) in
      obj [ ("sessionId", str ("session-" ^ n)) ])

let enum_area name =
  match P.Storage_area.of_string name with Ok x -> x | Error e -> Alcotest.fail e

let new_tab tabs who = handle_of (result (request tabs who (P.New { url = None })))

(* ---------- The page the fake answers ---------- *)

type spot = {
  backend : int;
  role : string;
  name : string;
  box : float * float * float * float;
}

let buttons =
  [
    { backend = 11; role = "button"; name = "Send"; box = (10., 10., 100., 30.) };
    { backend = 12; role = "button"; name = "Menu"; box = (10., 50., 100., 30.) };
  ]

(* hard-2gnf: the file input is hidden — no accessibility node, no layout box — the way a
   styled upload button leaves it. *)
let file_backend = 21
let num x = `Float x

let ax_page =
  obj
    [
      ( "nodes",
        `List
          (List.map
             (fun spot ->
               obj
                 [
                   ("nodeId", str (string_of_int spot.backend));
                   ("role", obj [ ("type", str "role"); ("value", str spot.role) ]);
                   ( "name",
                     obj [ ("type", str "computedString"); ("value", str spot.name) ] );
                   ("backendDOMNodeId", int spot.backend);
                   ("ignored", `Bool false);
                   ("childIds", `List []);
                   ("properties", `List []);
                 ])
             buttons) );
    ]

(* strings: 0 block, 1 INPUT, 2 BUTTON, 3 type, 4 file, 5 multiple, 6 empty, 7 id, 8 avatar *)
let dom_page =
  let index n = int n in
  obj
    [
      ( "documents",
        `List
          [
            obj
              [
                ( "nodes",
                  obj
                    [
                      ("backendNodeId", `List [ int 11; int 12; int file_backend ]);
                      ("nodeName", `List [ index 2; index 2; index 1 ]);
                      ( "attributes",
                        `List
                          [
                            `List [];
                            `List [];
                            `List [ index 3; index 4; index 5; index 6; index 7; index 8 ];
                          ] );
                    ] );
                ( "layout",
                  obj
                    [
                      ("nodeIndex", `List [ int 0; int 1 ]);
                      ( "bounds",
                        `List
                          (List.map
                             (fun spot ->
                               let x, y, w, h = spot.box in
                               `List [ num x; num y; num w; num h ])
                             buttons) );
                      ("styles", `List [ `List [ int 0 ]; `List [ int 0 ] ]);
                    ] );
              ];
          ] );
      ( "strings",
        `List
          (List.map str
             [
               "block"; "INPUT"; "BUTTON"; "type"; "file"; "multiple"; ""; "id"; "avatar";
             ]) );
    ]

type page = {
  mutable loader : string;
  mutable epoch : string;
  mutable mutations : int;
  mutable ready : bool;
  mutable hit : int option;
  mutable url : string;
  mutable origin : string;
}

let fresh_page () =
  {
    loader = "loader-1";
    epoch = "epoch-1";
    mutations = 1;
    ready = false;
    hit = None;
    url = "about:blank";
    origin = "://";
  }

let spot_of backend = List.find (fun spot -> spot.backend = backend) buttons

let quad spot =
  let x, y, w, h = spot.box in
  `List (List.map num [ x; y; x +. w; y; x +. w; y +. h; x; y +. h ])

let param name request =
  match field "params" request with Some params -> field name params | None -> None

let backend_param request =
  match param "backendNodeId" request with
  | Some (`Int n) -> n
  | _ -> Alcotest.fail "no backend id"

let script fake (page : page) =
  Fake.on_method fake "Page.getFrameTree" (fun _ ->
      obj
        [
          ( "frameTree",
            obj
              [
                ( "frame",
                  obj
                    [
                      ("id", str "frame-1");
                      ("loaderId", str page.loader);
                      ("url", str page.url);
                      ("securityOrigin", str page.origin);
                    ] );
              ] );
        ]);
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> ax_page);
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> dom_page);
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      let expression =
        match param "expression" request with Some (`String s) -> s | _ -> ""
      in
      let value v = obj [ ("result", obj [ ("type", str "boolean"); ("value", v) ]) ] in
      if contains expression "leashSnapshotGuard" then
        obj
          [
            ( "result",
              obj
                [
                  ("type", str "object");
                  ( "value",
                    obj
                      [
                        ("epoch", str page.epoch);
                        ("count", int page.mutations);
                        ("width", int 800);
                        ("height", int 600);
                      ] );
                ] );
          ]
      else if contains expression "Boolean(document.body" then value (`Bool page.ready)
      else if contains expression "globalThis" then
        obj [ ("result", obj [ ("type", str "object"); ("objectId", str "window") ]) ]
      else if contains expression "querySelectorAll" then value (`Bool true)
      else if contains expression "requestAnimationFrame" then value (`Bool true)
      else obj [ ("result", obj [ ("type", str "undefined") ]) ]);
  Fake.on_method fake "Accessibility.getPartialAXTree" (fun request ->
      let spot = spot_of (backend_param request) in
      obj
        [
          ( "nodes",
            `List
              [
                obj
                  [
                    ("role", obj [ ("type", str "role"); ("value", str spot.role) ]);
                    ( "name",
                      obj [ ("type", str "computedString"); ("value", str spot.name) ] );
                  ];
              ] );
        ]);
  Fake.on_method fake "DOM.describeNode" (fun request ->
      let backend = backend_param request in
      let deep = match param "depth" request with Some (`Int n) -> n < 0 | _ -> false in
      if backend = file_backend then
        obj
          [
            ( "node",
              obj
                [
                  ("nodeId", int 121);
                  ("backendNodeId", int backend);
                  ("nodeName", str "INPUT");
                  ( "attributes",
                    `List
                      (List.map str [ "type"; "file"; "multiple"; ""; "id"; "avatar" ]) );
                ] );
          ]
      else
        obj
          [
            ( "node",
              obj
                [
                  ("nodeId", int (100 + backend));
                  ("backendNodeId", int backend);
                  ("nodeName", str "BUTTON");
                  ( "children",
                    if deep then
                      `List
                        [
                          obj
                            [
                              ("nodeId", int 900);
                              ("backendNodeId", int (backend + 100));
                              ("nodeName", str "SPAN");
                            ];
                        ]
                    else `List [] );
                ] );
          ]);
  Fake.on_method fake "DOM.getContentQuads" (fun request ->
      obj [ ("quads", `List [ quad (spot_of (backend_param request)) ]) ]);
  Fake.on_method fake "DOM.getNodeForLocation" (fun request ->
      let x = match param "x" request with Some (`Int n) -> n | _ -> 0
      and y = match param "y" request with Some (`Int n) -> n | _ -> 0 in
      let backend =
        match page.hit with
        | Some backend -> backend
        | None -> (
            let inside spot =
              let left, top, w, h = spot.box in
              float x >= left
              && float x <= left +. w
              && float y >= top
              && float y <= top +. h
            in
            match List.find_opt inside buttons with
            | Some spot -> spot.backend
            | None -> 11)
      in
      obj [ ("backendNodeId", int backend); ("nodeId", int (100 + backend)) ]);
  Fake.on_method fake "DOM.resolveNode" (fun _ ->
      obj [ ("object", obj [ ("objectId", str "element-1"); ("type", str "object") ]) ]);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      obj [ ("result", obj [ ("type", str "string"); ("value", str "called") ]) ]);
  Fake.on_method fake "Target.getTargetInfo" (fun _ ->
      obj
        [
          ( "targetInfo",
            obj
              [
                ("targetId", str "target-1");
                ("type", str "page");
                ("title", str "Page");
                ("url", str page.url);
              ] );
        ])

let calls fake method_ =
  Fake.received fake |> List.filter (fun json -> field "method" json = Some (str method_))

let params json = match field "params" json with Some p -> p | None -> obj []

let snap tabs handle =
  result
    (request tabs "alice"
       (P.Snap { tab = handle; match_ = None; limit = None; offset = None }))

(* ---------- hard-xg6y hard-ovbx hard-vq5s: the net ring ---------- *)

let net_event fake ~session name params = Fake.emit ~session fake ~method_:name ~params

let started ?(method_ = "GET") ?(kind = "Fetch") ?(t = 100.) ?(headers = []) ?(extra = [])
    fake ~session id url =
  net_event fake ~session "Network.requestWillBeSent"
    (obj
       [
         ("requestId", str id);
         ("timestamp", num t);
         ("type", str kind);
         ( "request",
           obj
             ([
                ("url", str url);
                ("method", str method_);
                ("headers", obj (List.map (fun (k, v) -> (k, str v)) headers));
              ]
             @ extra) );
       ])

let answered ?(status = 200) ?(mime = "application/json") ?(cached = false) fake ~session
    id =
  net_event fake ~session "Network.responseReceived"
    (obj
       [
         ("requestId", str id);
         ("type", str "Fetch");
         ( "response",
           obj
             [
               ("status", int status);
               ("mimeType", str mime);
               ("fromDiskCache", `Bool cached);
             ] );
       ])

let finished ?(size = 42) ?(t = 100.25) fake ~session id =
  net_event fake ~session "Network.loadingFinished"
    (obj [ ("requestId", str id); ("timestamp", num t); ("encodedDataLength", int size) ])

let net_list ?match_ ?limit ?type_ tabs who handle =
  request tabs who (P.Net { tab = handle; match_; limit; type_ })

let requests reply = list "requests" (result reply)
let ids reply = List.map (text "id") (requests reply)

let net_ring () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      many_tabs fake;
      let a = new_tab tabs "alice" and b = new_tab tabs "alice" in
      started fake ~session:"session-1" "r1" "http://127.0.0.1:8080/index.html"
        ~kind:"Document";
      answered fake ~session:"session-1" "r1" ~mime:"text/html";
      finished fake ~session:"session-1" "r1" ~size:1200 ~t:100.25;
      started fake ~session:"session-1" "r2" "http://127.0.0.1:8080/api/items";
      answered fake ~session:"session-1" "r2" ~cached:true;
      finished fake ~session:"session-1" "r2";
      started fake ~session:"session-1" "r3" "http://127.0.0.1:8080/api/xhr" ~kind:"XHR";
      net_event fake ~session:"session-1" "Network.loadingFailed"
        (obj
           [
             ("requestId", str "r3");
             ("timestamp", num 100.5);
             ("errorText", str "net::ERR_CONNECTION_REFUSED");
           ]);
      started fake ~session:"session-2" "other" "http://127.0.0.1:8080/elsewhere";
      eventually "both rings fed" (fun () ->
          List.length (requests (net_list tabs "alice" a)) = 3
          && List.length (requests (net_list tabs "alice" b)) = 1
          && text "id" (List.nth (requests (net_list tabs "alice" a)) 2) = "r3"
          && get "error" (List.nth (requests (net_list tabs "alice" a)) 2) <> `Null);
      (* hard-xg6y: the ring is the tab's own. *)
      Alcotest.(check (list string))
        "hard-xg6y tab A's requests" [ "r1"; "r2"; "r3" ]
        (ids (net_list tabs "alice" a));
      Alcotest.(check (list string))
        "hard-xg6y tab B's requests" [ "other" ]
        (ids (net_list tabs "alice" b));
      let listed = requests (net_list tabs "alice" a) in
      let first = List.nth listed 0
      and second = List.nth listed 1
      and third = List.nth listed 2 in
      Alcotest.(check string) "hard-xg6y method" "GET" (text "method" first);
      Alcotest.(check string)
        "hard-xg6y url" "http://127.0.0.1:8080/index.html" (text "url" first);
      Alcotest.(check int) "hard-xg6y status" 200 (count "status" first);
      Alcotest.(check string) "hard-xg6y resource type" "document" (text "type" first);
      Alcotest.(check string) "hard-xg6y mime" "text/html" (text "mime" first);
      Alcotest.(check int) "hard-xg6y encoded size" 1200 (count "size" first);
      Alcotest.(check int) "hard-xg6y duration in ms" 250 (count "duration_ms" first);
      Alcotest.(check bool)
        "hard-xg6y not from cache" true
        (get "from_cache" first = `Bool false);
      Alcotest.(check bool)
        "hard-xg6y from cache" true
        (get "from_cache" second = `Bool true);
      Alcotest.(check bool)
        "hard-xg6y a failed load has no status" true
        (get "status" third = `Null);
      Alcotest.(check string)
        "hard-xg6y the failure is named" "net::ERR_CONNECTION_REFUSED"
        (text "error" third);
      (* The filters. *)
      Alcotest.(check (list string))
        "hard-xg6y match" [ "r2"; "r3" ]
        (ids (net_list tabs "alice" a ~match_:"/API/"));
      Alcotest.(check (list string))
        "hard-xg6y type" [ "r3" ]
        (ids (net_list tabs "alice" a ~type_:"XHR"));
      Alcotest.(check (list string))
        "hard-xg6y limit keeps the most recent" [ "r3" ]
        (ids (net_list tabs "alice" a ~limit:1));
      check_code "hard-xg6y limit bound" "invalid-request"
        (net_list tabs "alice" a ~limit:501);
      (* Owner-bound like every tab command. *)
      check_code "hard-xg6y owner-bound" "not-owner" (net_list tabs "bob" a);
      (* A redirect ends its hop; the followed request keeps the id. *)
      started fake ~session:"session-2" "hop" "http://127.0.0.1:8080/old";
      net_event fake ~session:"session-2" "Network.requestWillBeSent"
        (obj
           [
             ("requestId", str "hop");
             ("timestamp", num 101.);
             ("type", str "Document");
             ( "redirectResponse",
               obj [ ("status", int 302); ("mimeType", str "text/plain") ] );
             ( "request",
               obj
                 [
                   ("url", str "http://127.0.0.1:8080/new");
                   ("method", str "GET");
                   ("headers", obj []);
                 ] );
           ]);
      eventually "redirect seen" (fun () ->
          List.exists
            (fun row -> text "url" row = "http://127.0.0.1:8080/new")
            (requests (net_list tabs "alice" b)));
      let hops = requests (net_list tabs "alice" b ~match_:"/old") in
      Alcotest.(check int)
        "hard-xg6y the redirected hop stays listed" 1 (List.length hops);
      Alcotest.(check int)
        "hard-xg6y with the redirect's status" 302
        (count "status" (List.hd hops));
      Alcotest.(check bool)
        "hard-xg6y under its own id" true
        (text "id" (List.hd hops) <> "hop");
      (* Bounded: five hundred, oldest first out. *)
      for n = 0 to 504 do
        started fake ~session:"session-1" (Printf.sprintf "bulk-%d" n)
          (Printf.sprintf "http://127.0.0.1:8080/bulk/%d" n)
      done;
      eventually "ring full" (fun () ->
          let all = ids (net_list tabs "alice" a ~limit:500) in
          all <> [] && List.nth all (List.length all - 1) = "bulk-504");
      let all = ids (net_list tabs "alice" a ~limit:500) in
      Alcotest.(check int) "hard-xg6y the ring holds 500" 500 (List.length all);
      Alcotest.(check string) "hard-xg6y the oldest went first" "bulk-5" (List.hd all))

let net_body () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let a = new_tab tabs "alice" in
      started fake ~session:"session-1" "json" "http://127.0.0.1:8080/api/items";
      answered fake ~session:"session-1" "json";
      finished fake ~session:"session-1" "json";
      started fake ~session:"session-1" "png" "http://127.0.0.1:8080/logo.png";
      answered fake ~session:"session-1" "png" ~mime:"image/png";
      finished fake ~session:"session-1" "png";
      started fake ~session:"session-1" "big" "http://127.0.0.1:8080/big";
      answered fake ~session:"session-1" "big";
      finished fake ~session:"session-1" "big";
      started fake ~session:"session-1" "gone" "http://127.0.0.1:8080/evicted";
      answered fake ~session:"session-1" "gone";
      finished fake ~session:"session-1" "gone";
      started fake ~session:"session-1" "pending" "http://127.0.0.1:8080/slow";
      Fake.on_method fake "Network.getResponseBody" (fun request ->
          match param "requestId" request with
          | Some (`String "json") ->
              obj [ ("body", str "{\"items\":[1,2]}"); ("base64Encoded", `Bool false) ]
          | Some (`String "png") ->
              obj [ ("body", str "iVBORw0KGgo="); ("base64Encoded", `Bool true) ]
          | Some (`String "big") ->
              obj
                [
                  ("body", str (String.make 1_048_577 'x')); ("base64Encoded", `Bool false);
                ]
          | _ -> obj [ ("body", str ""); ("base64Encoded", `Bool false) ]);
      Fake.on_failure fake "Network.getResponseBody" (fun request ->
          match param "requestId" request with
          | Some (`String "gone") ->
              Some (-32000, "No resource with given identifier found")
          | _ -> None);
      eventually "ring fed" (fun () ->
          List.length (requests (net_list tabs "alice" a)) = 5);
      let body id = request tabs "alice" (P.Net_body { tab = a; id }) in
      let json = result (body "json") in
      Alcotest.(check string)
        "hard-ovbx the text body" "{\"items\":[1,2]}" (text "body" json);
      Alcotest.(check bool)
        "hard-ovbx text is not base64" true
        (get "base64" json = `Bool false);
      Alcotest.(check bool)
        "hard-ovbx not truncated" true
        (get "truncated" json = `Bool false);
      let png = result (body "png") in
      Alcotest.(check bool)
        "hard-ovbx binary comes as base64" true
        (get "base64" png = `Bool true);
      Alcotest.(check string) "hard-ovbx the base64 body" "iVBORw0KGgo=" (text "body" png);
      let big = result (body "big") in
      Alcotest.(check int) "hard-ovbx bounded to 1 MiB" 1_048_576 (count "bytes" big);
      Alcotest.(check bool) "hard-ovbx and said so" true (get "truncated" big = `Bool true);
      check_code "hard-ovbx evicted by Chrome" "body-unavailable" (body "gone");
      check_code "hard-ovbx still in flight" "body-unavailable" (body "pending");
      check_code "hard-ovbx unknown id" "unknown-request" (body "nothing");
      check_code "hard-ovbx owner-bound" "not-owner"
        (request tabs "bob" (P.Net_body { tab = a; id = "json" })))

let net_request () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let a = new_tab tabs "alice" in
      started fake ~session:"session-1" "post" ~method_:"POST"
        ~headers:[ ("Content-Type", "application/json") ]
        ~extra:[ ("hasPostData", `Bool true) ]
        "http://127.0.0.1:8080/api/save";
      net_event fake ~session:"session-1" "Network.requestWillBeSentExtraInfo"
        (obj
           [
             ("requestId", str "post");
             ( "headers",
               obj [ ("cookie", str "sid=abc"); ("Content-Type", str "application/json") ]
             );
           ]);
      started fake ~session:"session-1" "plain" "http://127.0.0.1:8080/api/list";
      Fake.on_method fake "Network.getRequestPostData" (fun request ->
          match param "requestId" request with
          | Some (`String "post") -> obj [ ("postData", str "{\"name\":\"Ada\"}") ]
          | _ -> obj [ ("postData", str "") ]);
      eventually "ring fed" (fun () ->
          match requests (net_list tabs "alice" a) with [ _; _ ] -> true | _ -> false);
      (* The extra-info event carries the headers Chrome really sent. *)
      eventually "extra info merged" (fun () ->
          match request tabs "alice" (P.Net_request { tab = a; id = "post" }) with
          | P.Success json -> field "cookie" (get "headers" json) <> None
          | P.Failure _ -> false);
      let post = result (request tabs "alice" (P.Net_request { tab = a; id = "post" })) in
      Alcotest.(check string) "hard-vq5s method" "POST" (text "method" post);
      Alcotest.(check string)
        "hard-vq5s url" "http://127.0.0.1:8080/api/save" (text "url" post);
      Alcotest.(check string)
        "hard-vq5s header" "application/json"
        (text "Content-Type" (get "headers" post));
      Alcotest.(check string)
        "hard-vq5s post data" "{\"name\":\"Ada\"}" (text "post_data" post);
      Alcotest.(check bool) "hard-vq5s whole" true (get "truncated" post = `Bool false);
      let plain =
        result (request tabs "alice" (P.Net_request { tab = a; id = "plain" }))
      in
      Alcotest.(check bool)
        "hard-vq5s a GET has no post data" true
        (field "post_data" plain = None);
      Alcotest.(check bool)
        "hard-vq5s and none was asked for the GET" true
        (List.for_all
           (fun call -> param "requestId" call = Some (`String "post"))
           (calls fake "Network.getRequestPostData"));
      Fake.on_failure fake "Network.getRequestPostData" (fun _ ->
          Some (-32000, "Request content was evicted from inspector cache"));
      check_code "hard-vq5s evicted post data" "body-unavailable"
        (request tabs "alice" (P.Net_request { tab = a; id = "post" }));
      check_code "hard-vq5s unknown id" "unknown-request"
        (request tabs "alice" (P.Net_request { tab = a; id = "nothing" }));
      check_code "hard-vq5s owner-bound" "not-owner"
        (request tabs "bob" (P.Net_request { tab = a; id = "post" })))

(* ---------- waits: hard-sr9v hard-sckn ---------- *)

let async ~sw f =
  let cell = ref None in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      cell := Some (f ());
      `Stop_daemon);
  cell

let pump env cell =
  let rec loop n =
    match !cell with
    | Some reply -> reply
    | None ->
        if n = 0 then Alcotest.fail "the request never replied"
        else (
          Eio.Fiber.yield ();
          Ox_test.advance env#clock (Ox.Duration.ms 300);
          loop (n - 1))
  in
  loop 5_000

let quiet env cell rounds =
  for _ = 1 to rounds do
    Eio.Fiber.yield ();
    Ox_test.advance env#clock (Ox.Duration.ms 300)
  done;
  Alcotest.(check bool) "still waiting" true (!cell = None)

let wait_args ?(until = None) ?(timeout_ms = 60_000) handle =
  let until =
    match until with
    | Some until -> until
    | None ->
        P.
          {
            url_prefix = None;
            text = None;
            index_gone = None;
            dialog = None;
            changed_since = None;
          }
  in
  P.Wait { tab = handle; until; timeout_ms = Some timeout_ms }

let long_wait () =
  (* hard-sr9v: an hour is the bound, and the listener's budget follows it. *)
  let budget command =
    match Leash.Control.budget (Ok P.{ owner = owner "alice"; command }) with
    | Some d -> Ox.Duration.to_ms d
    | None -> Alcotest.fail "no budget"
  in
  let handle =
    match P.Handle.of_string "t_00000000000000000000000000000000" with
    | Ok h -> h
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check int)
    "hard-sr9v an hour plus a second" 3_601_000
    (budget (wait_args ~timeout_ms:3_600_000 handle));
  Alcotest.(check int)
    "hard-sr9v the default stays 30 s" 31_000
    (budget
       (P.Wait
          {
            tab = handle;
            until =
              {
                url_prefix = None;
                text = None;
                index_gone = None;
                dialog = None;
                changed_since = None;
              };
            timeout_ms = None;
          }));
  Alcotest.(check int)
    "hard-sr9v longer than an hour is bounded" 3_601_000
    (budget (wait_args ~timeout_ms:9_000_000 handle));
  rig (fun env sw tabs fake ->
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      check_code "hard-sr9v beyond the hour is refused" "invalid-request"
        (request tabs "alice" (wait_args ~timeout_ms:3_600_001 a));
      let until =
        Some
          P.
            {
              url_prefix = None;
              text = Some "ready";
              index_gone = None;
              dialog = None;
              changed_since = None;
            }
      in
      let waiting =
        async ~sw (fun () ->
            request tabs "alice" (wait_args ~until ~timeout_ms:3_600_000 a))
      in
      quiet env waiting 20;
      page.ready <- true;
      ignore (result (pump env waiting));
      page.ready <- false;
      (* hard-sr9v: polling is the owner's activity. The wait below outlasts the idle clock's
         thirty minutes twice over and the tab is still counting down from a recent poll,
         not from the start. *)
      let hour =
        async ~sw (fun () ->
            request tabs "alice" (wait_args ~until ~timeout_ms:3_600_000 a))
      in
      for _ = 1 to 34 do
        for _ = 1 to 12 do
          Eio.Fiber.yield ()
        done;
        Ox_test.advance env#clock (Ox.Duration.seconds 60)
      done;
      let info =
        List.hd
          (list "tabs"
             (P.yojson_of_list_result
                (Leash.Tabs.list tabs ~owner:(owner "alice") ~all:false)))
      in
      (match !hour with
      | None -> ()
      | Some (P.Success _) -> Alcotest.fail "the wait succeeded early"
      | Some (P.Failure e) ->
          Alcotest.failf "the wait ended: %s %s" (P.Error_code.to_string e.code) e.message);
      Alcotest.(check bool)
        (Printf.sprintf "hard-sr9v a wait counts as owner activity (%d s left)"
           (count "in_s" (get "expires" info)))
        true
        (count "in_s" (get "expires" info) > 1000);
      page.ready <- true;
      ignore (result (pump env hour)))

let changed_since () =
  rig (fun env sw tabs fake ->
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      let s1 = snapshot_of (snap tabs a) in
      let until snapshot =
        Some
          P.
            {
              url_prefix = None;
              text = None;
              index_gone = None;
              dialog = None;
              changed_since = Some snapshot;
            }
      in
      let wait snapshot = request tabs "alice" (wait_args ~until:(until snapshot) a) in
      (* hard-sckn: the page has not changed, so the wait holds. *)
      let holding = async ~sw (fun () -> wait s1) in
      quiet env holding 10;
      (* The mutation counter moved. *)
      page.mutations <- 2;
      ignore (result (pump env holding));
      (* A new snapshot is the new baseline; a new loader id is a change too. *)
      let s2 = snapshot_of (snap tabs a) in
      let holding = async ~sw (fun () -> wait s2) in
      quiet env holding 5;
      page.loader <- "loader-2";
      ignore (result (pump env holding));
      (* A new document with a new epoch changes it as well. *)
      let s3 = snapshot_of (snap tabs a) in
      let holding = async ~sw (fun () -> wait s3) in
      quiet env holding 5;
      page.epoch <- "epoch-2";
      ignore (result (pump env holding));
      (* A navigation clears the tab's current snapshot, and the older baseline still
         answers: the page moved on. *)
      let s4 = snapshot_of (snap tabs a) in
      Fake.emit ~session:"session-1" fake ~method_:"Page.frameNavigated"
        ~params:(Fake.event "Page.frameNavigated");
      page.loader <- "loader-3";
      ignore (result (pump env (async ~sw (fun () -> wait s4))));
      check_code "hard-sckn a snapshot the tab never took" "stale-snapshot"
        (request tabs "alice"
           (wait_args
              ~until:
                (until
                   (match P.Snapshot_id.of_string "s_nothing" with
                   | Ok s -> s
                   | Error e -> Alcotest.fail e))
              a));
      (* Unchanged and bounded: it times out. *)
      let s5 = snapshot_of (snap tabs a) in
      let timed =
        async ~sw (fun () ->
            request tabs "alice" (wait_args ~until:(until s5) ~timeout_ms:1_000 a))
      in
      check_code "hard-sckn nothing changed" "timeout" (pump env timed);
      (* It ANDs with the other conditions. *)
      let s6 = snapshot_of (snap tabs a) in
      page.mutations <- 9;
      let anded =
        async ~sw (fun () ->
            request tabs "alice"
              (wait_args
                 ~until:
                   (Some
                      P.
                        {
                          url_prefix = None;
                          text = Some "ready";
                          index_gone = None;
                          dialog = None;
                          changed_since = Some s6;
                        })
                 a))
      in
      quiet env anded 5;
      page.ready <- true;
      ignore (result (pump env anded)))

(* ---------- hard-2gnf hard-o3za: file inputs and upload ---------- *)

let temp_file ?(size = 5) () =
  let path = Filename.temp_file "leash-upload-" ".bin" in
  let fd = Unix.openfile path [ Unix.O_WRONLY ] 0o600 in
  Unix.ftruncate fd size;
  Unix.close fd;
  path

let row_named rows role =
  match List.find_opt (fun row -> text "role" row = role) rows with
  | Some row -> row
  | None -> Alcotest.failf "no %s row" role

let upload () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      let table = snap tabs a in
      let s = snapshot_of table in
      let rows = list "rows" table in
      (* hard-2gnf: the hidden file input is a row, with the author's name for it. *)
      let input = row_named rows "file-input" in
      Alcotest.(check string) "hard-2gnf the row is named" "avatar" (text "name" input);
      Alcotest.(check int)
        "hard-2gnf after the controls before it" 3 (count "index" input);
      let upload ?(index = 3) ?(who = "alice") paths =
        request tabs who (P.Upload { tab = a; snapshot = s; index; paths })
      in
      let one = temp_file () and two = temp_file () in
      let reply = result (upload [ one; two ]) in
      Alcotest.(check string)
        "hard-o3za the reply is an action result" "Page" (text "title" reply);
      let sent = params (List.hd (calls fake "DOM.setFileInputFiles")) in
      Alcotest.(check int)
        "hard-o3za set on the row's node" file_backend (count "backendNodeId" sent);
      Alcotest.(check (list string))
        "hard-o3za the files" [ one; two ]
        (List.map (function `String s -> s | _ -> "") (list "files" sent));
      (* The limits, all before the browser is asked. *)
      let before = List.length (calls fake "DOM.setFileInputFiles") in
      check_code "hard-o3za relative path" "invalid-request" (upload [ "relative.txt" ]);
      check_code "hard-o3za unreadable path" "invalid-request"
        (upload [ "/nonexistent/leash-file" ]);
      check_code "hard-o3za a directory" "invalid-request"
        (upload [ Filename.get_temp_dir_name () ]);
      check_code "hard-o3za no files" "invalid-request" (upload []);
      check_code "hard-o3za at most ten files" "invalid-request"
        (upload (List.init 11 (fun _ -> one)));
      let big = temp_file ~size:(26 * 1024 * 1024) () in
      check_code "hard-o3za at most 50 MiB" "too-large" (upload [ big; big ]);
      Sys.remove big;
      check_code "hard-o3za owner-bound" "not-owner" (upload ~who:"bob" [ one ]);
      Alcotest.(check int)
        "hard-o3za nothing reached the browser" before
        (List.length (calls fake "DOM.setFileInputFiles"));
      (* Revalidated like any action. *)
      check_code "hard-o3za a button is not a file input" "row-not-actionable"
        (upload ~index:1 [ one ]);
      check_code "hard-o3za no such row" "no-such-row" (upload ~index:9 [ one ]);
      check_code "hard-2gnf a click on a file input is refused" "row-not-actionable"
        (request tabs "alice" (P.Click { tab = a; snapshot = s; index = 3 }));
      check_code "hard-2gnf and so is a fill" "row-not-actionable"
        (request tabs "alice" (P.Fill { tab = a; snapshot = s; index = 3; text = "x" }));
      Alcotest.(check int)
        "hard-2gnf no pointer input for it" 0
        (List.length (calls fake "Input.dispatchMouseEvent"));
      page.loader <- "loader-2";
      check_code "hard-o3za the page navigated" "stale-snapshot" (upload [ one ]);
      page.loader <- "loader-1";
      Fake.on_method fake "DOM.describeNode" (fun _ ->
          obj
            [
              ( "node",
                obj
                  [
                    ("nodeId", int 121);
                    ("backendNodeId", int file_backend);
                    ("nodeName", str "INPUT");
                    ("attributes", `List (List.map str [ "type"; "file" ]));
                  ] );
            ]);
      check_code "hard-o3za several files need multiple" "invalid-request"
        (upload [ one; two ]);
      ignore (result (upload [ one ]));
      Fake.on_method fake "DOM.describeNode" (fun _ ->
          obj
            [
              ( "node",
                obj
                  [
                    ("nodeId", int 121);
                    ("backendNodeId", int file_backend);
                    ("nodeName", str "DIV");
                  ] );
            ]);
      check_code "hard-o3za the node is no longer a file input" "stale-snapshot"
        (upload [ one ]);
      Sys.remove one;
      Sys.remove two)

(* ---------- hard-v1gs: hover ---------- *)

let hover () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      let s = snapshot_of (snap tabs a) in
      let hover ?(who = "alice") index =
        request tabs who (P.Hover { tab = a; snapshot = s; index })
      in
      let reply = result (hover 2) in
      Alcotest.(check string)
        "hard-v1gs the reply is an action result" "Page" (text "title" reply);
      let moves = calls fake "Input.dispatchMouseEvent" in
      Alcotest.(check int) "hard-v1gs one mouse event" 1 (List.length moves);
      let move = params (List.hd moves) in
      Alcotest.(check string) "hard-v1gs the mouse moves" "mouseMoved" (text "type" move);
      Alcotest.(check bool)
        "hard-v1gs to the row's centre" true
        (match (get "x" move, get "y" move) with
        | `Float x, `Float y -> abs_float (x -. 60.) < 0.01 && abs_float (y -. 65.) < 0.01
        | `Int x, `Int y -> x = 60 && y = 65
        | _ -> false);
      Alcotest.(check bool)
        "hard-v1gs nothing is pressed" true
        (get "buttons" move = int 0);
      (* A covered row would not receive the hover. *)
      page.hit <- Some 99;
      check_code "hard-v1gs covered row" "row-not-actionable" (hover 2);
      page.hit <- None;
      check_code "hard-v1gs no such row" "no-such-row" (hover 9);
      check_code "hard-v1gs owner-bound" "not-owner" (hover ~who:"bob" 2);
      page.loader <- "loader-2";
      check_code "hard-v1gs the page navigated" "stale-snapshot" (hover 2);
      Alcotest.(check int)
        "hard-v1gs and nothing more was dispatched" 1
        (List.length (calls fake "Input.dispatchMouseEvent")))

(* ---------- hard-b20d: eval --index ---------- *)

let eval_index () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      let s = snapshot_of (snap tabs a) in
      let eval ?(snapshot = Some s) ?(index = Some 1) () =
        request tabs "alice"
          (P.Eval
             {
               tab = a;
               expression = "return [argument, element.tagName]";
               argument = Some (str "arg");
               index;
               snapshot;
             })
      in
      let reply = result (eval ()) in
      Alcotest.(check string)
        "hard-b20d the function's value" "called" (text "value" reply);
      let call = params (List.hd (calls fake "Runtime.callFunctionOn")) in
      Alcotest.(check bool)
        "hard-b20d called as (argument, element)" true
        (contains (text "functionDeclaration" call) "function(argument, element)");
      (match list "arguments" call with
      | [ argument; element ] ->
          Alcotest.(check bool)
            "hard-b20d the argument" true
            (get "value" argument = str "arg");
          Alcotest.(check string)
            "hard-b20d the row's element" "element-1" (text "objectId" element)
      | _ -> Alcotest.fail "hard-b20d two arguments");
      let resolved = params (List.hd (calls fake "DOM.resolveNode")) in
      Alcotest.(check int)
        "hard-b20d resolved from the row's node" 11
        (count "backendNodeId" resolved);
      check_code "hard-b20d index needs snapshot" "invalid-request"
        (eval ~snapshot:None ());
      check_code "hard-b20d snapshot needs index" "invalid-request" (eval ~index:None ());
      check_code "hard-b20d no such row" "no-such-row" (eval ~index:(Some 9) ());
      Fake.on_failure fake "DOM.resolveNode" (fun _ ->
          Some (-32000, "No node with given id found"));
      check_code "hard-b20d the row no longer resolves" "stale-snapshot" (eval ());
      Fake.on_failure fake "DOM.resolveNode" (fun _ -> None);
      ignore (snap tabs a);
      check_code "hard-b20d an older snapshot" "stale-snapshot" (eval ());
      (* Without a row it is the eval it always was. *)
      let plain =
        result
          (request tabs "alice"
             (P.Eval
                {
                  tab = a;
                  expression = "return 1";
                  argument = None;
                  index = None;
                  snapshot = None;
                }))
      in
      Alcotest.(check string) "hard-b20d plain eval" "called" (text "value" plain);
      let last = List.nth (calls fake "Runtime.callFunctionOn") 1 in
      Alcotest.(check bool)
        "hard-b20d one parameter" true
        (contains (text "functionDeclaration" (params last)) "function(argument) {"))

(* ---------- hard-ufb7: cookies and storage ---------- *)

let cookies_and_storage () =
  rig (fun _ sw tabs fake ->
      ignore sw;
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      Fake.on_method fake "Page.navigate" (fun request ->
          let session =
            match field "sessionId" request with Some (`String s) -> s | _ -> ""
          in
          Fake.emit ~session fake ~method_:"Page.loadEventFired"
            ~params:(Fake.event "Page.loadEventFired");
          obj []);
      page.url <- "http://127.0.0.1:8080/app";
      page.origin <- "http://127.0.0.1:8080";
      let a = handle_of (result (request tabs "alice" (P.New { url = Some page.url }))) in
      Fake.on_method fake "Network.getCookies" (fun _ ->
          obj
            [
              ( "cookies",
                `List
                  [
                    obj
                      [
                        ("name", str "sid");
                        ("value", str "secret-session");
                        ("domain", str "127.0.0.1");
                        ("path", str "/");
                        ("expires", num (-1.));
                        ("httpOnly", `Bool true);
                        ("secure", `Bool false);
                        ("session", `Bool true);
                        ("sameSite", str "Lax");
                      ];
                    obj
                      [
                        ("name", str "theme");
                        ("value", str "dark");
                        ("domain", str "127.0.0.1");
                        ("path", str "/app");
                        ("expires", num 1900000000.5);
                        ("httpOnly", `Bool false);
                        ("secure", `Bool true);
                        ("session", `Bool false);
                      ];
                  ] );
            ]);
      let cookies =
        list "cookies" (result (request tabs "alice" (P.Cookies { tab = a })))
      in
      Alcotest.(check int) "hard-ufb7 both cookies" 2 (List.length cookies);
      let sid = List.hd cookies and theme = List.nth cookies 1 in
      Alcotest.(check string) "hard-ufb7 value" "secret-session" (text "value" sid);
      Alcotest.(check bool)
        "hard-ufb7 httpOnly is visible with its flags" true
        (get "http_only" sid = `Bool true);
      Alcotest.(check bool)
        "hard-ufb7 a session cookie has no expiry" true
        (get "expires" sid = `Null);
      Alcotest.(check string) "hard-ufb7 same site" "Lax" (text "same_site" sid);
      Alcotest.(check bool)
        "hard-ufb7 a dated cookie" true
        (get "expires" theme = `Float 1900000000.5);
      Alcotest.(check bool) "hard-ufb7 secure" true (get "secure" theme = `Bool true);
      Alcotest.(check bool) "hard-ufb7 no same site" true (get "same_site" theme = `Null);
      let asked = params (List.hd (calls fake "Network.getCookies")) in
      Alcotest.(check (list string))
        "hard-ufb7 for the tab's URL" [ page.url ]
        (List.map (function `String s -> s | _ -> "") (list "urls" asked));
      check_code "hard-ufb7 cookies are owner-bound" "not-owner"
        (request tabs "bob" (P.Cookies { tab = a }));
      (* Storage. *)
      Fake.on_method fake "DOMStorage.getDOMStorageItems" (fun request ->
          let local =
            match param "storageId" request with
            | Some id -> field "isLocalStorage" id = Some (`Bool true)
            | None -> false
          in
          if local then
            obj
              [
                ( "entries",
                  `List
                    [
                      `List [ str "token"; str "secret-token" ];
                      `List [ str "k"; str "v" ];
                    ] );
              ]
          else obj [ ("entries", `List [ `List [ str "draft"; str "hello" ] ]) ]);
      let area name = enum_area name in
      let storage who name = request tabs who (P.Storage { tab = a; area = area name }) in
      let local = result (storage "alice" "local") in
      Alcotest.(check string)
        "hard-ufb7 the page's origin" "http://127.0.0.1:8080" (text "origin" local);
      Alcotest.(check string)
        "hard-ufb7 local value" "secret-token"
        (text "token" (get "items" local));
      Alcotest.(check string) "hard-ufb7 local keys" "v" (text "k" (get "items" local));
      let session = result (storage "alice" "session") in
      Alcotest.(check string)
        "hard-ufb7 session storage" "hello"
        (text "draft" (get "items" session));
      let asked = params (List.hd (calls fake "DOMStorage.getDOMStorageItems")) in
      Alcotest.(check string)
        "hard-ufb7 by security origin" "http://127.0.0.1:8080"
        (text "securityOrigin" (get "storageId" asked));
      check_code "hard-ufb7 storage is owner-bound" "not-owner" (storage "bob" "local");
      (* Read-only: nothing here writes. *)
      let written =
        Fake.received fake
        |> List.filter_map (fun json ->
            match field "method" json with Some (`String m) -> Some m | _ -> None)
        |> List.filter (fun m ->
            List.mem m
              [
                "Network.setCookie";
                "Network.setCookies";
                "Network.deleteCookies";
                "Network.clearBrowserCookies";
                "DOMStorage.setDOMStorageItem";
                "DOMStorage.removeDOMStorageItem";
                "DOMStorage.clear";
              ])
      in
      Alcotest.(check (list string)) "hard-ufb7 read-only" [] written;
      (* An opaque origin has no storage. *)
      page.origin <- "://";
      check_code "hard-ufb7 no storage origin" "invalid-request" (storage "alice" "local"))

(* ---------- hard-b1na: ten agents at once ---------- *)

let tab_lock () =
  rig (fun env sw tabs fake ->
      ignore env;
      let fake = fake () in
      let page = fresh_page () in
      script fake page;
      let a = new_tab tabs "alice" in
      (* An eval whose call never returns holds the tab's action lock. *)
      Fake.withhold fake "Runtime.callFunctionOn" (fun _ -> true);
      let holding =
        async ~sw (fun () ->
            request tabs "alice"
              (P.Eval
                 {
                   tab = a;
                   expression = "return 1";
                   argument = None;
                   index = None;
                   snapshot = None;
                 }))
      in
      eventually "the eval is in flight" (fun () ->
          calls fake "Runtime.callFunctionOn" <> []);
      (* hard-b1na: a wait on that very tab does not queue behind the action. *)
      let waited = request tabs "alice" (wait_args ~timeout_ms:1_000 a) in
      Alcotest.(check string)
        "hard-b1na the wait ran beside the action" "about:blank"
        (text "url" (result waited));
      Alcotest.(check bool)
        "hard-b1na while the action still held the lock" true (!holding = None);
      (* The action lock is what a second action would queue on. *)
      let queued =
        async ~sw (fun () ->
            request tabs "alice"
              (P.Eval
                 {
                   tab = a;
                   expression = "return 2";
                   argument = None;
                   index = None;
                   snapshot = None;
                 }))
      in
      for _ = 1 to 50 do
        Eio.Fiber.yield ()
      done;
      Alcotest.(check int)
        "hard-b1na a second action queues on the lock" 1
        (List.length (calls fake "Runtime.callFunctionOn"));
      Alcotest.(check bool) "hard-b1na" true (!queued = None);
      (* The reads that take no lock answer as well. *)
      ignore
        (result
           (request tabs "alice"
              (P.Net { tab = a; match_ = None; limit = None; type_ = None })));
      ignore (result (request tabs "alice" (P.Cookies { tab = a }))))

let with_runtime f =
  let runtime = Filename.temp_file "leash-h2-" "" in
  Unix.unlink runtime;
  Unix.mkdir runtime 0o700;
  Fun.protect
    ~finally:(fun () ->
      let dir = Filename.concat runtime "leash" in
      let unlink path = if Sys.file_exists path then Unix.unlink path in
      unlink (Filename.concat dir "control.sock");
      unlink (Filename.concat dir "control.sock.lock");
      if Sys.file_exists dir then Unix.rmdir dir;
      Unix.chmod runtime 0o700;
      Unix.rmdir runtime)
    (fun () -> f runtime)

let listen ~runtime env sw tabs =
  match
    Leash.Control.create ~sw
      ~path:(Filename.concat (Filename.concat runtime "leash") "control.sock")
      {
        Leash.Control.tabs;
        status_query = (fun () -> []);
        models_status =
          (fun () ->
            P.
              {
                configured = false;
                jev_model = "unconfigured";
                text_model = "";
                systemone_endpoint = "";
                chat_base_url = "";
              });
        fs = env#fs;
        net = env#net;
        clock = env#clock;
        logger =
          Ox_observability.Logger.create ~service:"h2-socket" ~clock:env#clock
            ~mono_clock:env#mono_clock
            ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
            ();
      }
  with
  | Ok _ -> Filename.concat (Filename.concat runtime "leash") "control.sock"
  | Error _ -> Alcotest.fail "the listener refused"

(* One request as a client sends it over the socket: a connection, a line, a line. *)
let connect env sw path = Eio.Net.connect ~sw env#net (`Unix path)

let send_line flow command who =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  Eio.Flow.copy_string (wire ^ "\n") flow

let read_reply reader =
  match P.decode_reply (Yojson.Safe.from_string (Eio.Buf_read.line reader)) with
  | Ok reply -> reply
  | Error e -> Alcotest.fail e

let policy_peers () =
  Alcotest.(check int)
    "hard-b1na sixty-four concurrent requests" 64
    Leash.Control.policy.Ox_ipc.Listener.peers

let ten_clients () =
  with_runtime (fun runtime ->
      rig (fun env sw tabs fake ->
          let fake = fake () in
          many_tabs fake;
          let page = fresh_page () in
          script fake page;
          let path = listen ~runtime env sw tabs in
          let handles = List.init 10 (fun _ -> new_tab tabs "alice") in
          let waiters = List.filteri (fun i _ -> i < 5) handles in
          let actors = List.filteri (fun i _ -> i >= 5) handles in
          let until =
            Some
              P.
                {
                  url_prefix = None;
                  text = Some "ready";
                  index_gone = None;
                  dialog = None;
                  changed_since = None;
                }
          in
          (* Five clients block in an hour-long wait, each on a tab of its own. *)
          let waits =
            List.map
              (fun handle ->
                async ~sw (fun () ->
                    let flow = connect env sw path in
                    send_line flow (wait_args ~until ~timeout_ms:3_600_000 handle) "alice";
                    read_reply (Eio.Buf_read.of_flow ~max_size:1_048_576 flow)))
              waiters
          in
          eventually "all five waits are polling" (fun () ->
              let sessions =
                calls fake "Runtime.evaluate"
                |> List.filter (fun json ->
                    contains
                      (match param "expression" json with
                      | Some (`String s) -> s
                      | _ -> "")
                      "Boolean(document.body")
                |> List.filter_map (fun json -> field "sessionId" json)
                |> List.sort_uniq compare
              in
              List.length sessions = 5);
          (* Five others act meanwhile, and are served. *)
          let actions =
            List.map
              (fun handle ->
                async ~sw (fun () ->
                    let flow = connect env sw path in
                    let reader = Eio.Buf_read.of_flow ~max_size:1_048_576 flow in
                    send_line flow
                      (P.Snap { tab = handle; match_ = None; limit = None; offset = None })
                      "alice";
                    let snapshot = result (read_reply reader) in
                    let flow = connect env sw path in
                    let reader = Eio.Buf_read.of_flow ~max_size:1_048_576 flow in
                    send_line flow
                      (P.Click
                         { tab = handle; snapshot = snapshot_of snapshot; index = 1 })
                      "alice";
                    let clicked = read_reply reader in
                    let flow = connect env sw path in
                    let reader = Eio.Buf_read.of_flow ~max_size:1_048_576 flow in
                    send_line flow
                      (P.Hover
                         { tab = handle; snapshot = snapshot_of snapshot; index = 2 })
                      "alice";
                    (clicked, read_reply reader)))
              actors
          in
          eventually "the five actors are served" (fun () ->
              List.for_all (fun cell -> !cell <> None) actions);
          List.iter
            (fun cell ->
              match !cell with
              | Some (clicked, hovered) ->
                  ignore (result clicked);
                  ignore (result hovered)
              | None -> ())
            actions;
          Alcotest.(check bool)
            "hard-b1na while the five waits are still in flight" true
            (List.for_all (fun cell -> !cell = None) waits);
          (* The waits end when their condition holds, not before. *)
          page.ready <- true;
          List.iter (fun cell -> ignore (result (pump env cell))) waits))

let many_waiters () =
  with_runtime (fun runtime ->
      rig (fun env sw tabs fake ->
          let fake = fake () in
          let page = fresh_page () in
          script fake page;
          let path = listen ~runtime env sw tabs in
          let a = new_tab tabs "alice" in
          let until =
            Some
              P.
                {
                  url_prefix = None;
                  text = Some "never";
                  index_gone = None;
                  dialog = None;
                  changed_since = None;
                }
          in
          (* Twenty connections held open at once is more than ox_ipc's default sixteen. *)
          let flows =
            List.init 20 (fun _ ->
                let flow = connect env sw path in
                send_line flow (wait_args ~until ~timeout_ms:3_600_000 a) "alice";
                flow)
          in
          let polls () =
            calls fake "Runtime.evaluate"
            |> List.filter (fun json ->
                contains
                  (match param "expression" json with Some (`String s) -> s | _ -> "")
                  "Boolean(document.body")
            |> List.length
          in
          eventually "all twenty waits are running" (fun () -> polls () >= 20);
          (* A twenty-first client is served at once. *)
          let flow = connect env sw path in
          send_line flow P.Status "alice";
          let status =
            result (read_reply (Eio.Buf_read.of_flow ~max_size:1_048_576 flow))
          in
          Alcotest.(check bool)
            "hard-b1na a 21st client is served" true
            (get "tabs" status <> `Null);
          (* hard-sr9v: the clients go away and the waits stop with them. *)
          List.iter Eio.Flow.close flows;
          for _ = 1 to 6 do
            Eio.Fiber.yield ();
            Ox_test.advance env#clock (Ox.Duration.ms 300)
          done;
          let settled = polls () in
          for _ = 1 to 8 do
            Eio.Fiber.yield ();
            Ox_test.advance env#clock (Ox.Duration.ms 300)
          done;
          Alcotest.(check int)
            "hard-sr9v a disconnect cancels the wait" settled (polls ())))

(* ---------- hard-wk6q: the surface is pinned in docs/protocol.md ---------- *)

let documented () =
  let doc = In_channel.with_open_bin "../docs/protocol.md" In_channel.input_all in
  List.iter
    (fun name ->
      Alcotest.(check bool)
        (Printf.sprintf "hard-wk6q %s is in docs/protocol.md" name)
        true
        (contains doc (Printf.sprintf "`%s`" name)))
    [
      "net";
      "net_body";
      "net_request";
      "upload";
      "hover";
      "cookies";
      "storage";
      "changed_since";
      "body-unavailable";
      "unknown-request";
      "file-input";
    ];
  Alcotest.(check bool)
    "hard-wk6q the fake browser scripts the new methods" true
    (List.for_all
       (fun meth ->
         contains
           (In_channel.with_open_bin "support/fake_browser.ml" In_channel.input_all)
           meth)
       [
         "Network.getResponseBody";
         "Network.getRequestPostData";
         "Network.getCookies";
         "DOM.setFileInputFiles";
         "DOMStorage.getDOMStorageItems";
       ])

let test name speed case = Alcotest.test_case name speed case

let () =
  Alcotest.run "L36 hardening 2"
    [
      ( "net",
        [
          test "hard-xg6y per-tab ring" `Quick net_ring;
          test "hard-ovbx bodies" `Quick net_body;
          test "hard-vq5s request data" `Quick net_request;
        ] );
      ( "wait",
        [
          test "hard-sr9v an hour" `Quick long_wait;
          test "hard-sckn changed since" `Quick changed_since;
        ] );
      ( "actions",
        [
          test "hard-2gnf hard-o3za file inputs and upload" `Quick upload;
          test "hard-v1gs hover" `Quick hover;
          test "hard-b20d eval --index" `Quick eval_index;
        ] );
      ("state", [ test "hard-ufb7 cookies and storage" `Quick cookies_and_storage ]);
      ( "concurrency",
        [
          test "hard-b1na the action lock" `Quick tab_lock;
          test "hard-b1na sixty-four peers" `Quick policy_peers;
          test "hard-b1na ten clients over the socket" `Quick ten_clients;
          test "hard-b1na hard-sr9v twenty waiters, then gone" `Quick many_waiters;
        ] );
      ("docs", [ test "hard-wk6q the surface is pinned" `Quick documented ]);
    ]
