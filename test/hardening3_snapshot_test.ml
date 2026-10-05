(* L48: field-cct4 field-lp65 field-jkx6 field-vji1: live values, bounded AX
   readiness and DOM fallback, plus cross-origin iframe visibility. *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let tab json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let code = function
  | P.Failure e -> P.Error_code.to_string e.code
  | _ -> Alcotest.fail "expected failure"

let result = function
  | P.Success json -> json
  | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let request tabs _client command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let check_code label expected reply = Alcotest.(check string) label expected (code reply)

let contains text sub =
  let rec search i =
    i + String.length sub <= String.length text
    && (String.sub text i (String.length sub) = sub || search (i + 1))
  in
  search 0

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?reporter ?download_dir f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch
          ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >)
          ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~caps ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Ox_observability.Logger.create ~service:"leash-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:
            (Option.value reporter
               ~default:(Ox_observability.Logger.Reporter.writer ignore))
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch:(launch ~caps)
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          {
            Chrome.clock = env#clock;
            mono_clock = (env#mono_clock :> Eio.Time.Mono.ty Eio.Resource.t);
            mgr = env#process_mgr;
            logger;
            caps :> Leash.Chrome.caps;
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600 ?download_dir
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
            caps :> Leash.Tabs.caps;
          }
      in
      let rec ready n =
        if n = 0 then Alcotest.fail "no Chrome"
        else if (Chrome.status chrome).phase <> `Running then (
          Eio.Fiber.yield ();
          ready (n - 1))
      in
      ready 1000;
      let fake () = match !current with Some x -> x | None -> Alcotest.fail "no fake" in
      f env sw chrome tabs fake)

let set_reply fake ~method_ reply = Fake.on_method fake method_ (fun _ -> reply)
let value v = obj [ ("value", v) ]

let ax_input =
  obj
    [
      ("nodeId", str "1");
      ("backendDOMNodeId", `Int 41);
      ("role", value (str "textbox"));
      ("name", value (str "Email"));
      ("value", value (str "stale-ax"));
      ("ignored", `Bool false);
    ]

let ax = obj [ ("nodes", `List [ ax_input ]) ]
let empty_ax = obj [ ("nodes", `List []) ]

let dom ~live ~tag ~attrs =
  obj
    [
      ( "strings",
        `List
          (List.map str
             [
               tag;
               "block";
               "visible";
               live;
               "type";
               "password";
               "src";
               "https://hcaptcha.com/frame";
               "value";
               "stale-attribute";
             ]) );
      ( "documents",
        `List
          [
            obj
              [
                ( "nodes",
                  obj
                    [
                      ("backendNodeId", `List [ `Int 41 ]);
                      ("nodeName", `List [ `Int 0 ]);
                      ("attributes", `List [ `List (List.map (fun i -> `Int i) attrs) ]);
                      ( "inputValue",
                        obj [ ("index", `List [ `Int 0 ]); ("value", `List [ `Int 3 ]) ]
                      );
                    ] );
                ( "layout",
                  obj
                    [
                      ("nodeIndex", `List [ `Int 0 ]);
                      ("bounds", `List [ `List [ `Int 5; `Int 5; `Int 100; `Int 20 ] ]);
                      ("styles", `List [ `List [ `Int 1; `Int 2 ] ]);
                    ] );
              ];
          ] );
    ]

let guard =
  obj
    [
      ("epoch", str "test-document");
      ("count", `Int 0);
      ("width", `Int 800);
      ("height", `Int 600);
      ("scrollX", `Int 0);
      ("scrollY", `Int 0);
      ("dpr", `Int 1);
    ]

let evaluate fake count =
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      let expression = get "expression" (get "params" request) in
      if expression = str Leash__Snapshot_source.guard_expression then
        obj [ ("result", value guard) ]
      else if expression = str Leash__Snapshot_source.interactive_count_expression then
        obj [ ("result", value (if count < 0 then `Null else `Int count)) ]
      else if expression = str Leash__Snapshot_source.dom_rows_expression then
        obj [ ("result", obj [ ("objectId", str "fallback") ]) ]
      else obj [ ("result", value (`Bool true)) ])

let fresh tabs = tab (request tabs "alice" (P.New { url = None; label = None }) |> result)

let snap tabs h =
  request tabs "alice"
    (P.Snap
       { tab = h; match_ = None; limit = Some 1000; offset = None; with_image = None })
  |> result

let rows snapshot =
  match get "rows" snapshot with `List rows -> rows | _ -> assert false

let identity fake =
  Fake.on_method fake "DOM.describeNode" (fun request ->
      let backend =
        match field "backendNodeId" (get "params" request) with
        | Some backend -> backend
        | None -> `Int 41
      in
      obj
        [
          ( "node",
            obj
              [
                ("nodeId", `Int 7);
                ("backendNodeId", backend);
                ("nodeName", str "INPUT");
                ("attributes", `List []);
              ] );
        ])

let live_value
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let h = fresh tabs in
      evaluate fake 1;
      set_reply fake ~method_:"Accessibility.getFullAXTree" ax;
      set_reply fake ~method_:"Accessibility.getPartialAXTree" ax;
      let live = ref "before" in
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ ->
          dom ~live:!live ~tag:"INPUT" ~attrs:[ 8; 9 ]);
      identity fake;
      Fake.on_method fake "Input.insertText" (fun request ->
          (live :=
             match get "text" (get "params" request) with
             | `String text -> text
             | _ -> assert false);
          obj []);
      let before = snap tabs h in
      Alcotest.(check bool)
        "live before fill" true
        (get "value" (List.hd (rows before)) = str "before");
      let snapshot = P.Snapshot_id.t_of_yojson (get "snapshot" before) |> Result.get_ok in
      ignore
        (request tabs "alice"
           (P.Fill
              {
                tab = h;
                snapshot;
                index = 1;
                text = "typed@example.org";
                snap = None;
                match_ = None;
                limit = None;
              })
        |> result);
      let after = snap tabs h in
      Alcotest.(check bool)
        "field-cct4 effective fill beats stale AX and value attribute" true
        (get "value" (List.hd (rows after)) = str "typed@example.org");
      set_reply fake ~method_:"DOMSnapshot.captureSnapshot"
        (dom ~live:"secret" ~tag:"INPUT" ~attrs:[ 4; 5 ]);
      Alcotest.(check bool)
        "takeover a filled password shows its value" true
        (field "value" (List.hd (rows (snap tabs h))) = Some (str "secret")))

let live_value_unavailable () =
  let replace key value = function
    | `Assoc fields -> obj ((key, value) :: List.remove_assoc key fields)
    | _ -> assert false
  in
  let base = dom ~live:"" ~tag:"INPUT" ~attrs:[ 8; 9 ] in
  let document =
    match get "documents" base with `List [ doc ] -> doc | _ -> assert false
  in
  let with_sparse sparse =
    replace "documents"
      (`List
         [ replace "nodes" (replace "inputValue" sparse (get "nodes" document)) document ])
      base
  in
  let row_value ax dom =
    let row, _ =
      Leash__Snapshot_source.rows ~ax ~dom ~width:800. ~height:600. ~scroll_x:0.
        ~scroll_y:0.
      |> List.hd
    in
    row.P.value
  in
  List.iter
    (fun sparse ->
      Alcotest.(check (option string))
        "field-cct4 unavailable live value retains AX" (Some "stale-ax")
        (row_value ax (with_sparse sparse)))
    [
      `Null;
      obj [ ("index", `List []); ("value", `List []) ];
      obj [ ("index", `List [ `Int 0 ]); ("value", `List [ `Int 999 ]) ];
    ];
  let no_ax_value = obj [ ("nodes", `List [ replace "value" `Null ax_input ]) ] in
  Alcotest.(check (option string))
    "field-cct4 unavailable live and AX value retains attribute" (Some "stale-attribute")
    (row_value no_ax_value (with_sparse `Null));
  Alcotest.(check (option string))
    "field-cct4 named empty live value does not resurrect AX or attribute" None
    (row_value ax base)

let readiness
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let h = fresh tabs in
      evaluate fake 0;
      let blank = snap tabs h in
      Alcotest.(check bool)
        "field-lp65 actually blank settles" true
        (get "settled" blank = `Bool true);
      Alcotest.(check bool) "reason omitted when ready" true (field "reason" blank = None);
      let legacy =
        match blank with
        | `Assoc fields ->
            `Assoc
              (List.filter (fun (name, _) -> name <> "source" && name <> "reason") fields)
        | _ -> assert false
      in
      let decoded = P.snapshot_of_yojson legacy |> Result.get_ok in
      Alcotest.(check bool)
        "old snapshot source defaults to AX" true
        (decoded.source = P.Ax && decoded.reason = None);
      evaluate fake 1;
      set_reply fake ~method_:"DOMSnapshot.captureSnapshot"
        (dom ~live:"" ~tag:"INPUT" ~attrs:[]);
      let captures = ref 0 in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ ->
          incr captures;
          if !captures = 1 then empty_ax else ax);
      let populated = snap tabs h in
      Alcotest.(check int) "field-lp65 retry empty AX before declaring ready" 2 !captures;
      Alcotest.(check bool)
        "field-lp65 populated AX settles" true
        (get "settled" populated = `Bool true);
      Alcotest.(check bool) "normal source" true (get "source" populated = str "ax");
      let count_reads = ref 0 in
      let scrolled_guard =
        match guard with
        | `Assoc fields ->
            obj (("scrollY", `Int 900) :: List.remove_assoc "scrollY" fields)
        | _ -> assert false
      in
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          let expression = get "expression" (get "params" request) in
          let current =
            if expression = str Leash__Snapshot_source.guard_expression then
              scrolled_guard
            else (
              incr count_reads;
              `Int 1)
          in
          obj [ ("result", obj [ ("value", current) ]) ]);
      let offscreen = snap tabs h in
      Alcotest.(check int)
        "field-lp65 no visible controls after scrolling" 0
        (List.length (rows offscreen));
      Alcotest.(check bool)
        "field-lp65 offscreen AX controls still settle" true
        (get "settled" offscreen = `Bool true && field "reason" offscreen = None);
      Alcotest.(check int) "field-lp65 populated raw AX needs no DOM count" 0 !count_reads)

let fallback
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let h = fresh tabs in
      (* Unknown count is not proof of an empty page. *)
      evaluate fake (-1);
      let captures = ref 0 and descriptions = ref 0 and released = ref false in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ ->
          incr captures;
          empty_ax);
      let metadata =
        List.init 300 (fun index ->
            obj
              [
                ("index", `Int index);
                ("role", str "textbox");
                ("name", str "Email");
                ("value", str "live");
              ])
      in
      Fake.on_method fake "Runtime.callFunctionOn" (fun request ->
          if
            get "functionDeclaration" (get "params" request)
            = str "function(){return this.rows}"
          then obj [ ("result", value (`List metadata)) ]
          else obj [ ("result", obj [ ("objectId", str "elements") ]) ]);
      set_reply fake ~method_:"Runtime.getProperties"
        (obj
           [
             ( "result",
               `List
                 (List.init 300 (fun index ->
                      obj
                        [
                          ("name", str (string_of_int index));
                          ( "value",
                            obj [ ("objectId", str ("element-" ^ string_of_int index)) ]
                          );
                        ])) );
           ]);
      Fake.on_method fake "Runtime.releaseObjectGroup" (fun _ ->
          released := true;
          obj []);
      Fake.on_method fake "DOM.describeNode" (fun request ->
          incr descriptions;
          let backend =
            match field "objectId" (get "params" request) with
            | Some (`String id) ->
                41 + int_of_string (String.sub id 8 (String.length id - 8))
            | _ -> 41
          in
          obj [ ("node", obj [ ("nodeId", `Int 7); ("backendNodeId", `Int backend) ]) ]);
      let snapshot = snap tabs h in
      Alcotest.(check int) "field-jkx6 only two empty-AX retakes" 3 !captures;
      Alcotest.(check bool)
        "field-jkx6 DOM source" true
        (get "source" snapshot = str "dom");
      Alcotest.(check bool)
        "field-lp65 fallback stays unsettled" true
        (get "settled" snapshot = `Bool false);
      Alcotest.(check bool)
        "field-lp65 reason" true
        (get "reason" snapshot = str "ax-tree-empty");
      Alcotest.(check int) "field-jkx6 bounded rows" 250 (List.length (rows snapshot));
      Alcotest.(check int) "field-jkx6 bounded identity calls" 250 !descriptions;
      Alcotest.(check bool) "field-jkx6 remote object group released" true !released;
      Alcotest.(check bool)
        "field-jkx6 normal one-based indices" true
        (get "index" (List.hd (rows snapshot)) = `Int 1
        && get "index" (List.hd (List.rev (rows snapshot))) = `Int 250);
      let snapshot =
        P.Snapshot_id.t_of_yojson (get "snapshot" snapshot) |> Result.get_ok
      in
      ignore
        (request tabs "alice"
           (P.Fill
              {
                tab = h;
                snapshot;
                index = 1;
                text = "live";
                snap = None;
                match_ = None;
                limit = None;
              })
        |> result);
      let inputs () =
        Fake.received fake
        |> List.filter (fun request ->
            field "method" request = Some (str "Input.insertText"))
        |> List.length
      in
      Alcotest.(check int)
        "field-jkx6 exact DOM identity is actionable without AX" 1 (inputs ());
      set_reply fake ~method_:"DOM.describeNode"
        (obj [ ("node", obj [ ("nodeId", `Int 8); ("backendNodeId", `Int 999) ]) ]);
      check_code "field-jkx6 replaced element identity refused" "stale-snapshot"
        (request tabs "alice"
           (P.Fill
              {
                tab = h;
                snapshot;
                index = 1;
                text = "never";
                snap = None;
                match_ = None;
                limit = None;
              }));
      Alcotest.(check int)
        "field-jkx6 identity mismatch dispatches no input" 1 (inputs ());
      set_reply fake ~method_:"DOM.describeNode"
        (obj [ ("node", obj [ ("nodeId", `Int 0); ("backendNodeId", `Int 41) ]) ]);
      check_code "field-jkx6 removed element refused" "stale-snapshot"
        (request tabs "alice"
           (P.Fill
              {
                tab = h;
                snapshot;
                index = 1;
                text = "never";
                snap = None;
                match_ = None;
                limit = None;
              }));
      Alcotest.(check int) "field-jkx6 removed element dispatches no input" 1 (inputs ()))

let iframe () =
  let dom = dom ~live:"" ~tag:"IFRAME" ~attrs:[ 6; 7 ] in
  let frames =
    Leash__Snapshot_source.frame_rows ~url:"https://app.test/" ~dom ~width:800.
      ~height:600. ~scroll_x:0. ~scroll_y:0.
  in
  Alcotest.(check int) "field-vji1 visible cross-origin frame" 1 (List.length frames);
  let row, backend = List.hd frames in
  Alcotest.(check int) "backend identity" 41 backend;
  Alcotest.(check string) "frame role" "frame" row.role;
  Alcotest.(check string) "origin without path" "https://hcaptcha.com" row.name;
  Alcotest.(check bool)
    "cross-origin state" true
    (Option.map (List.map P.Row_state.to_string) row.state = Some [ "cross-origin" ]);
  Alcotest.(check int)
    "same origin omitted" 0
    (List.length
       (Leash__Snapshot_source.frame_rows ~url:"https://hcaptcha.com/" ~dom ~width:800.
          ~height:600. ~scroll_x:0. ~scroll_y:0.));
  Alcotest.(check int)
    "offscreen omitted" 0
    (List.length
       (Leash__Snapshot_source.frame_rows ~url:"https://app.test/" ~dom ~width:800.
          ~height:600. ~scroll_x:0. ~scroll_y:100.))

let challenge
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let h = fresh tabs in
      List.iter
        (fun url ->
          Fake.emit ~session:"session-1" fake ~method_:"Network.requestWillBeSent"
            ~params:
              (obj
                 [
                   ("requestId", str url);
                   ("timestamp", `Float 1.);
                   ("type", str "Script");
                   ( "request",
                     obj [ ("url", str url); ("method", str "GET"); ("headers", obj []) ]
                   );
                 ]))
        [
          "https://www.google.com/recaptcha/api.js";
          "https://js.hcaptcha.com/1/api.js";
          "https://challenges.cloudflare.com/turnstile/v0/api.js";
          "https://hcaptcha.com.evil.test/api.js";
        ];
      let rec collect remaining =
        let debug =
          request tabs "alice" (P.Debug { tab = h; limit = None; clear = None }) |> result
        in
        let entries =
          match get "entries" debug with `List entries -> entries | _ -> []
        in
        if List.length entries >= 3 then entries
        else if remaining = 0 then
          Alcotest.fail "field-vji1 challenge events not observed"
        else (
          Eio.Fiber.yield ();
          collect (remaining - 1))
      in
      let entries = collect 100 in
      Alcotest.(check int) "field-vji1 only known challenge hosts" 3 (List.length entries);
      List.iter
        (fun vendor ->
          Alcotest.(check bool)
            vendor true
            (List.exists
               (fun entry ->
                 match get "text" entry with
                 | `String text -> contains text vendor
                 | _ -> false)
               entries))
        [ "reCAPTCHA"; "hCaptcha"; "Turnstile" ])

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "hardening3-snapshot"
    [
      ( "snapshot",
        [
          Alcotest.test_case "field-cct4 live controlled-input value after fill" `Quick
            (live_value ~caps);
          Alcotest.test_case "field-cct4 unavailable live values retain AX and attributes"
            `Quick live_value_unavailable;
          Alcotest.test_case "field-lp65 AX readiness vs genuinely blank page" `Quick
            (readiness ~caps);
          Alcotest.test_case "field-jkx6 bounded DOM fallback and action identity" `Quick
            (fallback ~caps);
          Alcotest.test_case "field-vji1 cross-origin iframe rows" `Quick iframe;
          Alcotest.test_case "field-vji1 known challenge debug warnings" `Quick
            (challenge ~caps);
        ] );
    ]
