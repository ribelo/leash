(* L7 actions: tab-bw4j tab-j1z2 tab-p3x1 tab-luo5 tab-5deq tab-8dop tab-tm6c tab-hxld
   tab-60kn tab-1lhx tab-8la3 tab-0lax, and L15's settlement stories tab-0ohq own-ehqa
   own-teh1. The fake answers the page the snapshot is taken from and the CDP methods an
   action uses; assertions are on the protocol replies and on the sequence of CDP messages
   the fake received. *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module E = Eta_json

let o fields = E.object_ (List.map (fun (k, v) -> (k, Some v)) fields)
let s = E.string
let i = E.int
let b = E.bool
let num value = match E.float value with Some json -> json | None -> assert false
let null = Yojson.Safe.from_string "null"
let list json = Yojson.Safe.Util.to_list json

let member key json =
  match E.member key json with
  | Some value -> value
  | None -> Alcotest.fail ("missing " ^ key)

let text key json =
  match E.string_member key json with
  | Some value -> value
  | None -> Alcotest.fail ("not a string: " ^ key)

let integer key json =
  match E.int_member key json with
  | Some value -> value
  | None -> Alcotest.fail ("not an integer: " ^ key)

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec scan at = at + n <= h && (String.sub haystack at n = needle || scan (at + 1)) in
  n = 0 || scan 0

let owner name =
  match P.Owner.of_string name with Ok value -> value | Error e -> Alcotest.fail e

let direction name =
  match P.Direction.of_string name with Ok value -> value | Error e -> Alcotest.fail e

let tab json =
  match P.Handle.t_of_yojson (member "tab" json) with
  | Ok value -> value
  | Error e -> Alcotest.fail e

let snapshot_id json =
  match P.Snapshot_id.t_of_yojson (member "snapshot" json) with
  | Ok value -> value
  | Error e -> Alcotest.fail e

let code = function
  | P.Failure error -> P.Error_code.to_string error.code
  | P.Success _ -> Alcotest.fail "expected a failure"

let result = function
  | P.Success json -> json
  | P.Failure error ->
      Alcotest.failf "%s: %s" (P.Error_code.to_string error.code) error.message

let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok reply -> reply
  | Error e -> Alcotest.fail e

let check_code label expected reply = Alcotest.(check string) label expected (code reply)

let rig f =
  Eta_test.run (fun env sw ->
      let mgr =
        Eta_test.Process.make
          [ Block_until_signal; Block_until_signal; Block_until_signal ]
      in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw ~sleep:(Eio.Time.sleep clock) () in
        current := Some fake;
        match
          Eta_process.Child.spawn ~sw ~clock ~mgr:(Eta_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Eta.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Eta_observability.Logger.create ~service:"leash-actions-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-actions-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:3 ~tombstone_s:3600
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
      f env sw chrome tabs fake)

(* The page the fake answers: the rows the snapshot table is built from, boxes in CSS
   pixels inside the 800x600 viewport the guard reports. *)
type spot = {
  backend : int;
  frontend : int;
  role : string;
  name : string;
  box : float * float * float * float;
  disabled : bool;
}

let page =
  [
    {
      backend = 11;
      frontend = 101;
      role = "button";
      name = "Send";
      box = (10., 10., 100., 30.);
      disabled = false;
    };
    {
      backend = 12;
      frontend = 102;
      role = "textbox";
      name = "Name";
      box = (10., 50., 200., 30.);
      disabled = false;
    };
    {
      backend = 13;
      frontend = 103;
      role = "combobox";
      name = "Pick";
      box = (10., 90., 120., 30.);
      disabled = false;
    };
    {
      backend = 14;
      frontend = 104;
      role = "combobox";
      name = "Choose";
      box = (10., 130., 120., 30.);
      disabled = false;
    };
    {
      backend = 15;
      frontend = 105;
      role = "button";
      name = "Sub";
      box = (10., 170., 300., 30.);
      disabled = false;
    };
    {
      backend = 16;
      frontend = 106;
      role = "button";
      name = "Off";
      box = (10., 210., 100., 30.);
      disabled = true;
    };
  ]

let spot_of_backend backend = List.find (fun spot -> spot.backend = backend) page

let quad spot =
  let x, y, w, h = spot.box in
  E.array
    [ num x; num y; num (x +. w); num y; num (x +. w); num (y +. h); num x; num (y +. h) ]

(* DOMSnapshot bounds are [x, y, width, height], not a quad. *)
let bounds spot =
  let x, y, w, h = spot.box in
  E.array [ num x; num y; num w; num h ]

let ax_page =
  o
    [
      ( "nodes",
        E.array
          (List.map
             (fun spot ->
               o
                 [
                   ("nodeId", s (string_of_int spot.backend));
                   ("role", o [ ("type", s "role"); ("value", s spot.role) ]);
                   ("name", o [ ("type", s "computedString"); ("value", s spot.name) ]);
                   ("backendDOMNodeId", i spot.backend);
                   ("ignored", b false);
                   ("childIds", E.array []);
                   ( "properties",
                     E.array
                       (if spot.disabled then
                          [
                            o
                              [
                                ("name", s "disabled");
                                ("value", o [ ("type", s "boolean"); ("value", b true) ]);
                              ];
                          ]
                        else []) );
                 ])
             page) );
    ]

let dom_page =
  o
    [
      ( "documents",
        E.array
          [
            o
              [
                ( "nodes",
                  o
                    [
                      ( "backendNodeId",
                        E.array (List.map (fun spot -> i spot.backend) page) );
                    ] );
                ( "layout",
                  o
                    [
                      ("nodeIndex", E.array (List.mapi (fun index _ -> i index) page));
                      ("bounds", E.array (List.map (fun spot -> bounds spot) page));
                      ("styles", E.array (List.map (fun _ -> E.array [ i 0 ]) page));
                    ] );
              ];
          ] );
      ("strings", E.array [ s "block" ]);
    ]

let frame_tree loader =
  o
    [
      ( "frameTree",
        o
          [
            ( "frame",
              o
                [
                  ("id", s "frame-1");
                  ("loaderId", s loader);
                  ("url", s "https://example.com/");
                ] );
          ] );
    ]

let guard =
  o
    [
      ( "result",
        o
          [
            ("type", s "object");
            ( "value",
              o
                [
                  ("epoch", s "document-1");
                  ("count", i 1);
                  ("width", i 800);
                  ("height", i 600);
                ] );
          ] );
    ]

let evaluate_reply ?(suggestions = true) request =
  let expression =
    match E.string_member "expression" (member "params" request) with
    | Some expression -> expression
    | None -> ""
  in
  if contains expression "leashSnapshotGuard" then guard
  else if contains expression "querySelectorAll" then
    o [ ("result", o [ ("type", s "boolean"); ("value", b suggestions) ]) ]
  else if contains expression "requestAnimationFrame" then
    o [ ("result", o [ ("type", s "boolean"); ("value", b true) ]) ]
  else o [ ("result", o [ ("type", s "undefined") ]) ]

(* [hit] overrides the hit test: the row under the click point by default, a descendant of
   the row to prove the descendant case, a foreign node for what an overlay looks like. *)
let script_page fake ?(loader = "loader-1") ?(suggestions = true) ?hit () =
  Fake.on_method fake "Page.getFrameTree" (fun _ -> frame_tree loader);
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> ax_page);
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> dom_page);
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      evaluate_reply ~suggestions request);
  Fake.on_method fake "Accessibility.getPartialAXTree" (fun request ->
      let spot = spot_of_backend (integer "backendNodeId" (member "params" request)) in
      o
        [
          ( "nodes",
            E.array
              [
                o
                  [
                    ("role", o [ ("type", s "role"); ("value", s spot.role) ]);
                    ("name", o [ ("type", s "computedString"); ("value", s spot.name) ]);
                    ("backendDOMNodeId", i spot.backend);
                    ("ignored", b false);
                  ];
              ] );
        ]);
  Fake.on_method fake "DOM.describeNode" (fun request ->
      let params = member "params" request in
      match E.int_member "backendNodeId" params with
      | Some backend ->
          let spot = spot_of_backend backend in
          (* A subtree describe is what the descendant check walks; every row here has one
             child, the way a button has its label span. *)
          let children =
            if Option.value ~default:0 (E.int_member "depth" params) < 0 then
              E.array
                [
                  o
                    [
                      ("nodeId", i 111);
                      ("backendNodeId", i (backend + 100));
                      ("nodeName", s "SPAN");
                    ];
                ]
            else E.array []
          in
          o
            [
              ( "node",
                o
                  [
                    ("nodeId", i spot.frontend);
                    ("backendNodeId", i spot.backend);
                    ("nodeName", s (String.uppercase_ascii spot.role));
                    ("parentId", i 1);
                    ("children", children);
                  ] );
            ]
      | None ->
          let node = Option.value ~default:0 (E.int_member "nodeId" params) in
          o
            [
              ("node", o [ ("nodeId", i node); ("parentId", i 1); ("nodeName", s "DIV") ]);
            ]);
  Fake.on_method fake "DOM.getContentQuads" (fun request ->
      let spot = spot_of_backend (integer "backendNodeId" (member "params" request)) in
      o [ ("quads", E.array [ quad spot ]) ]);
  Fake.on_method fake "DOM.getNodeForLocation" (fun request ->
      let params = member "params" request in
      match hit with
      | Some foreign -> foreign
      | None ->
          let x = Option.value ~default:0 (E.int_member "x" params) in
          let y = Option.value ~default:0 (E.int_member "y" params) in
          let px = float_of_int x and py = float_of_int y in
          let inside spot =
            let left, top, width, height = spot.box in
            px >= left && px <= left +. width && py >= top && py <= top +. height
          in
          let spot =
            match List.filter inside page with
            | spot :: _ -> spot
            | [] -> spot_of_backend 15
          in
          o [ ("backendNodeId", i spot.backend); ("nodeId", i spot.frontend) ]);
  Fake.on_method fake "Page.getLayoutMetrics" (fun _ ->
      o
        [
          ( "cssLayoutViewport",
            o
              [
                ("clientWidth", i 800);
                ("clientHeight", i 600);
                ("pageX", i 0);
                ("pageY", i 0);
              ] );
          ( "layoutViewport",
            o
              [
                ("clientWidth", i 800);
                ("clientHeight", i 600);
                ("pageX", i 0);
                ("pageY", i 0);
              ] );
        ]);
  Fake.on_method fake "DOM.resolveNode" (fun _ ->
      o [ ("object", o [ ("objectId", s "object-1"); ("type", s "object") ]) ]);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      o [ ("result", o [ ("type", s "string"); ("value", s "c") ]) ])

let calls fake method_ =
  Fake.received fake
  |> List.filter (fun json -> E.string_member "method" json = Some method_)

let methods fake =
  Fake.received fake |> List.filter_map (fun json -> E.string_member "method" json)

let params json = member "params" json

let session json =
  match E.string_member "sessionId" json with Some id -> id | None -> ""

let new_tab_for tabs who = tab (result (request tabs who (P.New { url = None })))
let new_tab tabs = new_tab_for tabs "alice"

let snap tabs handle =
  result
    (request tabs "alice"
       (P.Snap { tab = handle; match_ = None; limit = None; offset = None }))

let await ~sw what cell =
  let rec loop n =
    match !cell with
    | Some value -> value
    | None ->
        if n = 0 then Alcotest.fail (what ^ " never replied")
        else (
          Eio.Fiber.yield ();
          loop (n - 1))
  in
  loop 100_000

let kinds json_list =
  List.map
    (fun json -> Option.value ~default:"" (E.string_member "type" (params json)))
    json_list

(* tab-bw4j tab-j1z2 tab-tm6c tab-1lhx *)
let click () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      (* tab-bw4j: real Chrome returns fractional quad centres but rejects them as
         DOM.getNodeForLocation parameters (-32602). Keep mouse coordinates exact. *)
      Fake.on_method fake "DOM.getContentQuads" (fun _ ->
          o
            [
              ( "quads",
                E.array
                  [
                    E.array
                      (List.map num
                         [ 10.25; 10.25; 110.5; 10.25; 110.5; 40.75; 10.25; 40.75 ]);
                  ] );
            ]);
      Fake.on_method fake "Target.getTargetInfo" (fun _ ->
          o
            [
              ( "targetInfo",
                o
                  [
                    ("targetId", s "target-1");
                    ("type", s "page");
                    ("title", s "After the click");
                    ("url", s "https://example.com/after");
                  ] );
            ]);
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let before = List.length (Fake.received fake) in
      let reply =
        result (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 }))
      in
      let during = Fake.received fake |> List.filteri (fun index _ -> index >= before) in
      Alcotest.(check string)
        "tab-tm6c url after the action" "https://example.com/after" (text "url" reply);
      Alcotest.(check string)
        "tab-tm6c title after the action" "After the click" (text "title" reply);
      Alcotest.(check bool)
        "tab-tm6c no fresh snapshot" true
        (member "snapshot" reply = null);
      Alcotest.(check bool) "tab-tm6c no dialog" true (member "dialog" reply = null);
      Alcotest.(check int)
        "tab-tm6c no popups" 0
        (List.length (list (member "popups" reply)));
      let hit = List.hd (calls fake "DOM.getNodeForLocation") |> params in
      Alcotest.(check (pair int int))
        "tab-bw4j rounds fractional quad centre for CDP hit test" (60, 26)
        (integer "x" hit, integer "y" hit);
      let events = calls fake "Input.dispatchMouseEvent" in
      Alcotest.(check (list string))
        "tab-bw4j press then release, once"
        [ "mousePressed"; "mouseReleased" ]
        (kinds events);
      Alcotest.(check bool)
        "tab-bw4j mouse dispatch retains fractional quad centre" true
        (match member "x" (params (List.hd events)) with
        | `Float x -> abs_float (x -. 60.375) < 0.000001
        | _ -> false);
      Alcotest.(check int)
        "tab-bw4j the press carries the left button down" 1
        (integer "buttons" (params (List.hd events)));
      Alcotest.(check int)
        "tab-bw4j the release carries it up" 0
        (integer "buttons" (params (List.nth events 1)));
      Alcotest.(check string)
        "tab-bw4j revalidation reads the loader before anything is dispatched"
        "Page.getFrameTree"
        (Option.value ~default:"" (E.string_member "method" (List.hd during)));
      Alcotest.(check bool)
        "tab-p3x1 a two-frame settle follows the click" true
        (List.exists
           (fun json ->
             contains (text "expression" (params json)) "requestAnimationFrame")
           (calls fake "Runtime.evaluate"));
      (* The snapshot stays current while revalidation keeps passing: a second click on
         the same table is allowed, and it is a second dispatch, not a replay. *)
      ignore
        (result
           (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      Alcotest.(check int)
        "tab-1lhx one dispatch per click" 4
        (List.length (calls fake "Input.dispatchMouseEvent"));
      (* The page replaced the row: the current snapshot still describes the table, but
         the row's accessible name no longer matches. *)
      Fake.on_method fake "Accessibility.getPartialAXTree" (fun request ->
          let spot =
            spot_of_backend (integer "backendNodeId" (member "params" request))
          in
          o
            [
              ( "nodes",
                E.array
                  [
                    o
                      [
                        ("role", o [ ("type", s "role"); ("value", s spot.role) ]);
                        ( "name",
                          o [ ("type", s "computedString"); ("value", s "Replaced") ] );
                      ];
                  ] );
            ]);
      let replaced = snapshot_id (snap tabs handle) in
      check_code "tab-j1z2 replaced row" "stale-snapshot"
        (request tabs "alice" (P.Click { tab = handle; snapshot = replaced; index = 1 }));
      Alcotest.(check int)
        "tab-j1z2 no dispatch for a stale row" 4
        (List.length (calls fake "Input.dispatchMouseEvent"));
      ignore (script_page fake ());
      let fresh = snapshot_id (snap tabs handle) in
      (* An overlay at the click point: the hit test answers with another node. *)
      Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
          o [ ("backendNodeId", i 999); ("nodeId", i 999) ]);
      check_code "tab-bw4j covered row" "row-not-actionable"
        (request tabs "alice" (P.Click { tab = handle; snapshot = fresh; index = 1 }));
      Alcotest.(check int)
        "tab-bw4j no dispatch for a covered row" 4
        (List.length (calls fake "Input.dispatchMouseEvent"));
      (* The hit test may answer with a descendant of the row, and that counts. *)
      Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
          o [ ("backendNodeId", i 111); ("nodeId", i 111) ]);
      ignore
        (result
           (request tabs "alice" (P.Click { tab = handle; snapshot = fresh; index = 1 })));
      Alcotest.(check int)
        "tab-bw4j a descendant of the row is a hit" 6
        (List.length (calls fake "Input.dispatchMouseEvent"));
      (* A navigation between the snapshot and the click. *)
      ignore (script_page fake ~loader:"loader-2" ());
      check_code "tab-j1z2 loader moved" "stale-snapshot"
        (request tabs "alice" (P.Click { tab = handle; snapshot = fresh; index = 1 }));
      check_code "tab-of0i row outside the table" "no-such-row"
        (request tabs "alice" (P.Click { tab = handle; snapshot = fresh; index = 99 }));
      check_code "tab-bw4j disabled row" "row-not-actionable"
        (request tabs "alice" (P.Click { tab = handle; snapshot = fresh; index = 6 }));
      Alcotest.(check int)
        "tab-1lhx a refusal dispatches nothing" 6
        (List.length (calls fake "Input.dispatchMouseEvent")))

(* tab-1lhx: a dispatch that fails after the press makes the action fail, and the press
   is never issued again. *)
let never_retried () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      Fake.on_failure fake "Input.dispatchMouseEvent" (fun request ->
          if
            Option.value ~default:"" (E.string_member "type" (params request))
            = "mouseReleased"
          then Some (-32000, "the page refused the release")
          else None);
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let reply =
        request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })
      in
      Alcotest.(check string) "tab-1lhx the action failed" "internal" (code reply);
      let events = calls fake "Input.dispatchMouseEvent" in
      Alcotest.(check (list string))
        "tab-1lhx the press is not replayed"
        [ "mousePressed"; "mouseReleased" ]
        (kinds events);
      Alcotest.(check int)
        "tab-1lhx exactly one press was sent" 1
        (List.length
           (List.filter
              (fun json -> E.string_member "type" (params json) = Some "mousePressed")
              events)))

(* tab-p3x1 tab-0lax *)
let fill () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ~suggestions:false ();
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      ignore
        (result
           (request tabs "alice"
              (P.Fill { tab = handle; snapshot = id; index = 2; text = "hello" })));
      let texted = calls fake "Input.insertText" in
      Alcotest.(check int) "tab-p3x1 one insertText" 1 (List.length texted);
      Alcotest.(check string)
        "tab-p3x1 the text" "hello"
        (text "text" (params (List.hd texted)));
      Alcotest.(check int)
        "tab-p3x1 focused the row first" 1
        (List.length (calls fake "DOM.focus"));
      let keys = calls fake "Input.dispatchKeyEvent" in
      Alcotest.(check (list string))
        "tab-p3x1 selects the content with ctrl+a" [ "keyDown"; "keyUp" ] (kinds keys);
      Alcotest.(check int)
        "tab-p3x1 ctrl is held while selecting" 2
        (integer "modifiers" (params (List.hd keys)));
      Alcotest.(check bool)
        "tab-p3x1 blur dispatches the change semantics" true
        (List.exists
           (fun json -> contains (text "expression" (params json)) "blur")
           (calls fake "Runtime.evaluate"));
      (* A fill into a combobox waits for visible suggestions: bounded to ten probes when
         none ever appear. *)
      let probes_since before =
        calls fake "Runtime.evaluate"
        |> List.filteri (fun index _ -> index >= before)
        |> List.filter (fun json ->
            contains (text "expression" (params json)) "querySelectorAll")
      in
      let before = List.length (calls fake "Runtime.evaluate") in
      ignore
        (result
           (request tabs "alice"
              (P.Fill { tab = handle; snapshot = id; index = 3; text = "pi" })));
      Alcotest.(check int)
        "tab-p3x1 suggestions polled, bounded" 10
        (List.length (probes_since before));
      ignore (script_page fake ~suggestions:true ());
      let before = List.length (calls fake "Runtime.evaluate") in
      ignore
        (result
           (request tabs "alice"
              (P.Fill { tab = handle; snapshot = id; index = 3; text = "pi" })));
      Alcotest.(check int)
        "tab-p3x1 stops when a suggestion is visible" 1
        (List.length (probes_since before));
      let count = List.length (Fake.received fake) in
      check_code "tab-0lax fill text over 64 KiB" "too-large"
        (request tabs "alice"
           (P.Fill
              { tab = handle; snapshot = id; index = 2; text = String.make 65_537 'x' }));
      Alcotest.(check int)
        "tab-0lax a too-large fill touches no browser" count
        (List.length (Fake.received fake));
      check_code "tab-p3x1 a button is not a text control" "row-not-actionable"
        (request tabs "alice"
           (P.Fill { tab = handle; snapshot = id; index = 1; text = "x" })))

(* tab-luo5 *)
let press () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      ignore
        (result
           (request tabs "alice"
              (P.Press { tab = handle; snapshot = id; index = Some 1; key = "Enter" })));
      Alcotest.(check int)
        "tab-luo5 the row is focused first" 1
        (List.length (calls fake "DOM.focus"));
      let keys = calls fake "Input.dispatchKeyEvent" in
      Alcotest.(check (list string))
        "tab-luo5 a key is a press and a release" [ "keyDown"; "keyUp" ] (kinds keys);
      Alcotest.(check string)
        "tab-luo5 enter" "Enter"
        (text "key" (params (List.hd keys)));
      Alcotest.(check int)
        "tab-luo5 enter's virtual key code" 13
        (integer "windowsVirtualKeyCode" (params (List.hd keys)));
      ignore
        (result
           (request tabs "alice"
              (P.Press { tab = handle; snapshot = id; index = None; key = "Escape" })));
      Alcotest.(check int)
        "tab-luo5 without an index the page gets the key" 1
        (List.length (calls fake "DOM.focus"));
      Alcotest.(check int)
        "tab-luo5 escape's virtual key code" 27
        (integer "windowsVirtualKeyCode"
           (params (List.nth (calls fake "Input.dispatchKeyEvent") 2)));
      check_code "tab-luo5 unknown key" "invalid-request"
        (request tabs "alice"
           (P.Press { tab = handle; snapshot = id; index = None; key = "Frobnicate" })))

(* tab-5deq *)
let select () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      ignore
        (result
           (request tabs "alice"
              (P.Select { tab = handle; snapshot = id; index = 4; option = 2 })));
      let chosen = calls fake "Runtime.callFunctionOn" in
      Alcotest.(check int) "tab-5deq one call" 1 (List.length chosen);
      Alcotest.(check int)
        "tab-5deq the observed option index" 2
        (match list (member "arguments" (params (List.hd chosen))) with
        | argument :: _ -> integer "value" argument
        | [] -> Alcotest.fail "no argument");
      Alcotest.(check int)
        "tab-5deq resolves the select first" 1
        (List.length (calls fake "DOM.resolveNode"));
      Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
          o
            [
              ( "result",
                o [ ("type", s "object"); ("subtype", s "null"); ("value", null) ] );
            ]);
      check_code "tab-5deq an option the select does not have" "invalid-request"
        (request tabs "alice"
           (P.Select { tab = handle; snapshot = id; index = 4; option = 9 }));
      check_code "tab-5deq a button is not a select" "row-not-actionable"
        (request tabs "alice"
           (P.Select { tab = handle; snapshot = id; index = 1; option = 0 })))

(* tab-8dop *)
let scroll () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let handle = new_tab tabs in
      ignore (snap tabs handle);
      ignore
        (result
           (request tabs "alice"
              (P.Scroll { tab = handle; direction = direction "down"; index = None })));
      let wheels = calls fake "Input.dispatchMouseEvent" in
      Alcotest.(check int) "tab-8dop one wheel" 1 (List.length wheels);
      let wheel = List.hd wheels in
      Alcotest.(check string)
        "tab-8dop a wheel event" "mouseWheel"
        (text "type" (params wheel));
      Alcotest.(check int)
        "tab-8dop from the page's centre" 400
        (integer "x" (params wheel));
      Alcotest.(check int)
        "tab-8dop one viewport down" 600
        (integer "deltaY" (params wheel));
      ignore
        (result
           (request tabs "alice"
              (P.Scroll { tab = handle; direction = direction "up"; index = None })));
      Alcotest.(check int)
        "tab-8dop one viewport up" (-600)
        (integer "deltaY" (params (List.nth (calls fake "Input.dispatchMouseEvent") 1)));
      Alcotest.(check int)
        "tab-8dop the page scroll needs no geometry" 0
        (List.length (calls fake "DOM.getContentQuads"));
      ignore
        (result
           (request tabs "alice"
              (P.Scroll { tab = handle; direction = direction "down"; index = Some 5 })));
      let wheel = List.nth (calls fake "Input.dispatchMouseEvent") 2 in
      Alcotest.(check int) "tab-8dop aimed at the row" 160 (integer "x" (params wheel));
      Alcotest.(check int)
        "tab-8dop the row's geometry is read now" 1
        (List.length (calls fake "DOM.getContentQuads")))

(* The popup shapes are the ones headless Chrome 152 sends: a TargetInfo with openerId,
   canAccessOpener and openerFrameId (test/fixtures/unlabelled-controls-chrome.json, see
   docs/cdp-shapes.md). The test supplies the ids, the fixture supplies the shape. *)
let chrome_fixture () =
  let load path = Yojson.Safe.from_file path in
  try load "fixtures/unlabelled-controls-chrome.json"
  with Sys_error _ -> load "test/fixtures/unlabelled-controls-chrome.json"

(* The TargetInfo of a popup as headless Chrome sends it, with this test's ids in it. *)
let popup_target_info fixture ~target_id ~opener_id ~url ~title =
  let attached =
    member "popup" fixture |> fun popup -> member "attached_to_target" popup
  in
  let fields =
    match member "targetInfo" attached with
    | `Assoc fields -> fields
    | _ -> Alcotest.fail "the fixture has no popup targetInfo"
  in
  let set key value fields = (key, value) :: List.remove_assoc key fields in
  let fields = set "targetId" (s target_id) fields in
  let fields = set "openerId" (s opener_id) fields in
  let fields = set "url" (s url) fields in
  let fields = set "title" (s title) fields in
  o fields

(* The attachment Chrome pushes for a popup right after announcing it. *)
let popup_params fixture ~session ~target_id ~opener_id ~url ~title =
  o
    [
      ("sessionId", s session);
      ("waitingForDebugger", b false);
      ("targetInfo", popup_target_info fixture ~target_id ~opener_id ~url ~title);
    ]

(* The announcement itself: tab-0ohq's acknowledgement. *)
let popup_announcement fixture ~target_id ~opener_id ~url ~title =
  o [ ("targetInfo", popup_target_info fixture ~target_id ~opener_id ~url ~title) ]

let popups () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let fixture = chrome_fixture () in
      let created = ref 0 in
      Fake.on_method fake "Target.createTarget" (fun _ ->
          incr created;
          o [ ("targetId", s (Printf.sprintf "target-%d" !created)) ]);
      let handle = new_tab tabs in
      let opener = Printf.sprintf "target-%d" !created in
      Fake.on_method fake "Input.dispatchMouseEvent" (fun request ->
          if
            Option.value ~default:"" (E.string_member "type" (params request))
            = "mousePressed"
          then
            Fake.emit fake ~method_:"Target.attachedToTarget"
              ~params:
                (popup_params fixture ~session:"session-2" ~target_id:"target-9"
                   ~opener_id:opener ~url:"https://example.com/popup" ~title:"Popup");
          o []);
      let id = snapshot_id (snap tabs handle) in
      let reply =
        result (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 }))
      in
      Alcotest.(check int)
        "tab-tm6c the popup is reported" 1
        (List.length (list (member "popups" reply)));
      let popup =
        match list (member "popups" reply) with
        | popup :: _ -> popup
        | [] -> Alcotest.fail "no popup"
      in
      Alcotest.(check string)
        "tab-tm6c the popup's url" "https://example.com/popup" (text "url" popup);
      Alcotest.(check string) "tab-8k2g owned by the caller" "alice" (text "owner" popup);
      Alcotest.(check string)
        "tab-8k2g inherits the opener's origin" "agent" (text "origin" popup))

(* tab-8k2g: a tab another agent's tab opened while this action was in flight is not this
   caller's popup, even though it appeared in the same moment. *)
let popups_exact () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let fixture = chrome_fixture () in
      let created = ref 0 in
      Fake.on_method fake "Target.createTarget" (fun _ ->
          incr created;
          o [ ("targetId", s (Printf.sprintf "target-%d" !created)) ]);
      let sessions = ref 0 in
      Fake.on_method fake "Target.attachToTarget" (fun _ ->
          incr sessions;
          o [ ("sessionId", s (Printf.sprintf "session-%d" !sessions)) ]);
      let alice = new_tab_for tabs "alice" in
      let acted_on = Printf.sprintf "target-%d" !created in
      let bob = new_tab_for tabs "bob" in
      Alcotest.(check bool) "tab-8k2g two owners, two tabs" true (alice <> bob);
      let id = snapshot_id (snap tabs alice) in
      Fake.on_method fake "Input.dispatchMouseEvent" (fun request ->
          if
            Option.value ~default:"" (E.string_member "type" (params request))
            = "mousePressed"
          then (
            Fake.emit fake ~method_:"Target.attachedToTarget"
              ~params:
                (popup_params fixture ~session:"session-3" ~target_id:"target-3"
                   ~opener_id:acted_on ~url:"https://example.com/alice-popup"
                   ~title:"Alice");
            Fake.emit fake ~method_:"Target.attachedToTarget"
              ~params:
                (popup_params fixture ~session:"session-4" ~target_id:"target-4"
                   ~opener_id:"target-2" ~url:"https://example.com/bob-popup" ~title:"Bob"));
          o []);
      let reply =
        result (request tabs "alice" (P.Click { tab = alice; snapshot = id; index = 1 }))
      in
      let popups = list (member "popups" reply) in
      Alcotest.(check int) "tab-8k2g only the acted tab's popup" 1 (List.length popups);
      let popup = List.hd popups in
      Alcotest.(check string)
        "tab-8k2g it is the acted tab's popup" "https://example.com/alice-popup"
        (text "url" popup);
      Alcotest.(check string) "tab-8k2g owned by the caller" "alice" (text "owner" popup);
      let list_of who =
        result (request tabs who (P.List_tabs { all = false })) |> member "tabs" |> list
      in
      Alcotest.(check int)
        "tab-8k2g the popup is alice's tab too" 2
        (List.length (list_of "alice"));
      Alcotest.(check int)
        "tab-8k2g the peer keeps its own popup" 2
        (List.length (list_of "bob")))

(* tab-60kn: a dialog blocks the page, so every action refuses until it is answered. *)
let dialog () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      Fake.emit ~session:"session-1" fake ~method_:"Page.javascriptDialogOpening"
        ~params:
          (o
             [
               ("type", s "alert");
               ("message", s "stay here");
               ("url", s "https://example.com/");
               ("hasBrowserHandler", b true);
             ]);
      let rec wait n =
        if n = 0 then Alcotest.fail "the dialog was not delivered"
        else
          match
            Leash.Tabs.snap tabs ~owner:(owner "alice")
              { tab = handle; match_ = None; limit = None; offset = None }
          with
          | Ok snapshot when snapshot.dialog <> None -> ()
          | _ ->
              Eio.Fiber.yield ();
              wait (n - 1)
      in
      wait 1000;
      let before = List.length (Fake.received fake) in
      check_code "tab-60kn click" "dialog-open"
        (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 }));
      check_code "tab-60kn fill" "dialog-open"
        (request tabs "alice"
           (P.Fill { tab = handle; snapshot = id; index = 2; text = "x" }));
      check_code "tab-60kn press" "dialog-open"
        (request tabs "alice"
           (P.Press { tab = handle; snapshot = id; index = None; key = "Escape" }));
      check_code "tab-60kn select" "dialog-open"
        (request tabs "alice"
           (P.Select { tab = handle; snapshot = id; index = 4; option = 0 }));
      check_code "tab-60kn scroll" "dialog-open"
        (request tabs "alice"
           (P.Scroll { tab = handle; direction = direction "down"; index = None }));
      let after = Fake.received fake |> List.filteri (fun index _ -> index >= before) in
      Alcotest.(check int)
        "tab-60kn nothing reaches the page" 0
        (List.length
           (List.filter
              (fun json ->
                match E.string_member "method" json with
                | Some method_ -> contains method_ "Input."
                | None -> false)
              after)))

(* tab-hxld: one tab's actions run one at a time in arrival order; another tab's do not
   wait for them. *)
let serialization () =
  rig (fun _ sw _ tabs fake ->
      let fake = fake () in
      script_page fake ~suggestions:false ();
      let sessions = ref [ "session-1"; "session-2" ] in
      Fake.on_method fake "Target.attachToTarget" (fun _ ->
          let session = List.hd !sessions in
          sessions := List.tl !sessions;
          o [ ("sessionId", s session) ]);
      let first = new_tab tabs in
      let second = new_tab tabs in
      let first_snapshot = snapshot_id (snap tabs first) in
      let second_snapshot = snapshot_id (snap tabs second) in
      (* One tab: a click issued while another click is in flight is served after it, and
         the two dispatches do not interleave. Both clicks target the same tab, so both
         carry its session and only the rows tell them apart. *)
      let cell = ref None in
      let start = List.length (Fake.received fake) in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Click { tab = first; snapshot = first_snapshot; index = 1 })));
      Eio.Fiber.yield ();
      ignore
        (result
           (request tabs "alice"
              (P.Click { tab = first; snapshot = first_snapshot; index = 5 })));
      ignore (result (await ~sw "the first click" cell));
      let after = Fake.received fake |> List.filteri (fun index _ -> index >= start) in
      let events =
        List.filter
          (fun json -> E.string_member "method" json = Some "Input.dispatchMouseEvent")
          after
      in
      Alcotest.(check (list string))
        "tab-hxld one tab's actions do not interleave"
        [ "session-1"; "session-1"; "session-1"; "session-1" ]
        (List.map session events);
      Alcotest.(check (list int))
        "tab-hxld the first click's dispatch finishes before the second starts"
        [ 60; 60; 160; 160 ]
        (List.map (fun json -> integer "x" (params json)) events);
      Alcotest.(check bool) "tab-hxld the first click had finished" true (!cell <> None);
      (* Another tab: its request is served while a long action still holds the first
         tab's lock, so the second tab's traffic reaches the fake in the middle of it. *)
      ignore (script_page fake ~suggestions:false ());
      let cell = ref None in
      let start = List.length (Fake.received fake) in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Fill
                    { tab = first; snapshot = first_snapshot; index = 3; text = "pi" })));
      Eio.Fiber.yield ();
      ignore
        (result
           (request tabs "alice"
              (P.Click { tab = second; snapshot = second_snapshot; index = 5 })));
      let after = Fake.received fake |> List.filteri (fun index _ -> index >= start) in
      let last_of who =
        let rec scan index found = function
          | [] -> found
          | json :: rest ->
              let found =
                if E.string_member "sessionId" json = Some who then index else found
              in
              scan (index + 1) found rest
        in
        scan 0 (-1) after
      in
      let first_of who =
        let rec scan index = function
          | [] -> -1
          | json :: rest ->
              if E.string_member "sessionId" json = Some who then index
              else scan (index + 1) rest
        in
        scan 0 after
      in
      Alcotest.(check bool)
        "tab-hxld the second tab was served while the first acted" true
        (first_of "session-2" >= 0 && last_of "session-1" > first_of "session-2");
      ignore (result (await ~sw "the fill" cell));
      let events =
        List.filter
          (fun json -> E.string_member "method" json = Some "Input.dispatchMouseEvent")
          after
      in
      Alcotest.(check (list string))
        "tab-hxld the second tab's click is one press and one release"
        [ "mousePressed"; "mouseReleased" ]
        (kinds events))

(* tab-8la3 *)
let focus_emulation () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      ignore (new_tab tabs);
      let focused =
        List.filter
          (fun json ->
            E.string_member "method" json = Some "Emulation.setFocusEmulationEnabled")
          (Fake.received fake)
      in
      Alcotest.(check int)
        "tab-8la3 focus emulation is on for the tab" 1 (List.length focused);
      Alcotest.(check bool)
        "tab-8la3 enabled" true
        (E.member "enabled" (params (List.hd focused)) = Some (b true));
      Alcotest.(check string)
        "tab-8la3 in the tab's own session" "session-1"
        (session (List.hd focused));
      Alcotest.(check bool)
        "tab-bw4j the DOM agent is enabled for action-time geometry" true
        (List.mem "DOM.enable" (methods fake)))

(* L15 (tab-0ohq tab-1lhx): Chrome withholds the reply of the trusted input whose handler
   opens a popup (docs/cdp-shapes.md, L10), so the input is settled by whichever comes
   first -- its own reply, the popup Chrome reports with this tab as its opener, or this
   tab's target destroyed. The fake withholds the press's reply; the popup's own
   Target.targetCreated is the acknowledgement. *)
let wait_for_press fake =
  let rec loop n =
    let pressed =
      List.exists
        (fun json -> E.string_member "type" (params json) = Some "mousePressed")
        (calls fake "Input.dispatchMouseEvent")
    in
    if pressed then ()
    else if n = 0 then Alcotest.fail "tab-0ohq the press was never sent"
    else (
      Eio.Fiber.yield ();
      loop (n - 1))
  in
  loop 100_000

(* The requests the fake recorded between the press and the release: a settlement that had
   to probe the page or the target would show up here, and a re-issued press would too. *)
let between_press_and_release fake =
  let rec after_press = function
    | [] -> []
    | json :: rest ->
        if E.string_member "type" (params json) = Some "mousePressed" then rest
        else after_press rest
  in
  let rec until_release acc = function
    | [] -> List.rev acc
    | json :: rest ->
        if E.string_member "type" (params json) = Some "mouseReleased" then List.rev acc
        else until_release (json :: acc) rest
  in
  until_release [] (after_press (Fake.received fake))

(* own-teh1: a handle that names a closed tab answers tab-gone, and its detail says
   why. *)
let check_disposition label expected reply =
  match reply with
  | P.Failure e -> (
      Alcotest.(check string)
        (label ^ " is tab-gone") "tab-gone"
        (P.Error_code.to_string e.code);
      match e.detail with
      | Some json -> Alcotest.(check string) label expected (text "disposition" json)
      | None -> Alcotest.failf "%s: tab-gone with no disposition" label)
  | P.Success _ -> Alcotest.failf "%s: expected tab-gone" label

let popup_acknowledged () =
  rig (fun _ sw _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let fixture = chrome_fixture () in
      Fake.withhold fake "Input.dispatchMouseEvent" (fun request ->
          E.string_member "type" (member "params" request) = Some "mousePressed");
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      wait_for_press fake;
      Fake.emit fake ~method_:"Target.targetCreated"
        ~params:
          (popup_announcement fixture ~target_id:"popup-target" ~opener_id:"target-1"
             ~url:"https://example.com/popup" ~title:"Popup");
      let reply = result (await ~sw "tab-0ohq the popup-opening click" cell) in
      let popups = list (member "popups" reply) in
      Alcotest.(check int)
        "tab-0ohq the popup is the action's acknowledgement" 1 (List.length popups);
      let popup = List.hd popups in
      Alcotest.(check string)
        "tab-0ohq the popup it opened" "https://example.com/popup" (text "url" popup);
      Alcotest.(check string) "tab-8k2g owned by the caller" "alice" (text "owner" popup);
      Alcotest.(check (list string))
        "tab-1lhx press then release, once each"
        [ "mousePressed"; "mouseReleased" ]
        (kinds (calls fake "Input.dispatchMouseEvent"));
      Alcotest.(check (list string))
        "tab-0ohq nothing settled the press but the popup" []
        (List.filter_map
           (fun json -> E.string_member "method" json)
           (between_press_and_release fake)))

(* tab-0ohq tab-1lhx: a slow reply is still a reply. The fake takes three seconds of the
   mock clock before answering the press; the click must succeed when that answer arrives,
   not turn into browser-unavailable at some bound of its own, and the input is sent exactly
   once. Nothing but the release reached the browser while the reply was outstanding. *)
let slow_reply_settles () =
  rig (fun env sw _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      Fake.on_method fake "Input.dispatchMouseEvent" (fun request ->
          if E.string_member "type" (member "params" request) = Some "mousePressed" then
            Fake.sleep fake 3.
          else ();
          o []);
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      wait_for_press fake;
      Eta_test.advance env#clock (Eta.Duration.seconds 3);
      ignore (result (await ~sw "tab-1lhx the slow reply" cell));
      Alcotest.(check (list string))
        "tab-1lhx the slow reply is not a second dispatch"
        [ "mousePressed"; "mouseReleased" ]
        (kinds (calls fake "Input.dispatchMouseEvent"));
      Alcotest.(check (list string))
        "tab-0ohq the reply alone settled the press" []
        (List.filter_map
           (fun json -> E.string_member "method" json)
           (between_press_and_release fake)))

(* tab-0ohq tab-1lhx own-ehqa: the CDP deadline is the only bound a dispatch has left. A
   page that answers neither the input nor the liveness probe is browser-unavailable, and
   the clock runs out the call's own 30 seconds and the two probes after it. *)
let silent_page_unavailable () =
  rig (fun env sw _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let never, _ = Eio.Promise.create () in
      let pressed = ref false in
      Fake.on_method fake "Page.getFrameTree" (fun _ ->
          if !pressed then Eio.Promise.await never;
          frame_tree "loader-1");
      Fake.on_method fake "Input.dispatchMouseEvent" (fun _ ->
          pressed := true;
          Eio.Promise.await never;
          o []);
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      wait_for_press fake;
      (* One second at a time, as control_test's load timeout does: the dispatch deadline
         and the two probes after it expire in turn while the fiber runs. *)
      let rec spin n =
        match !cell with
        | Some _ -> ()
        | None ->
            if n = 0 then Alcotest.fail "tab-0ohq the silent click never replied"
            else (
              Eta_test.advance env#clock (Eta.Duration.seconds 1);
              (* The probes between two bounds are round trips through the fake; yielding
                 once per virtual second would expire their deadlines before their answers
                 are read. *)
              for _ = 1 to 20 do
                Eio.Fiber.yield ()
              done;
              spin (n - 1))
      in
      spin 45;
      check_code "tab-0ohq a silent page stays browser-unavailable" "browser-unavailable"
        (await ~sw "tab-0ohq the silent click" cell))

(* tab-0ohq own-teh1: a dispatch whose handler closes the tab destroys its own reply; the
   tab's own death settles it, and the click reports tab-gone with closed_externally -- the
   same answer the handle gives afterwards. Nothing is replayed: the release of a click
   whose press failed is never sent. *)
let self_closing_click_reports_tab_gone () =
  rig (fun _ sw _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      Fake.withhold fake "Input.dispatchMouseEvent" (fun request ->
          E.string_member "type" (member "params" request) = Some "mousePressed");
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      wait_for_press fake;
      Fake.emit fake ~method_:"Target.targetDestroyed"
        ~params:(o [ ("targetId", s "target-1") ]);
      check_disposition "own-teh1 the self-closing click" "closed_externally"
        (await ~sw "own-teh1 the self-closing click" cell);
      Alcotest.(check (list string))
        "tab-1lhx the failed click sends no release" [ "mousePressed" ]
        (kinds (calls fake "Input.dispatchMouseEvent"));
      check_disposition "own-teh1 the tombstone agrees" "closed_externally"
        (request tabs "alice" (P.Debug { tab = handle; limit = None; clear = None })))

(* own-teh1 tab-0ohq: the target-gone probe stays for the handler that closes its own tab
   when the death report does not arrive first. The press is never answered, the page does
   not answer Page.getFrameTree any more, and the browser no longer knows the target: the
   click reports tab-gone with closed_externally rather than browser-unavailable. *)
let self_closing_click_probe () =
  rig (fun env sw _ tabs fake ->
      let fake = fake () in
      script_page fake ();
      Fake.withhold fake "Input.dispatchMouseEvent" (fun request ->
          E.string_member "type" (member "params" request) = Some "mousePressed");
      let handle = new_tab tabs in
      let id = snapshot_id (snap tabs handle) in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Click { tab = handle; snapshot = id; index = 1 })));
      wait_for_press fake;
      (* Every request of the revalidation is answered before the press is read, so from
         here on the page session and the target lookup fail, as they do once the tab's
         target is gone. *)
      Fake.on_failure fake "Page.getFrameTree" (fun _ ->
          Some (404, "No session with given id"));
      Fake.on_failure fake "Target.getTargetInfo" (fun _ ->
          Some (404, "No target with given id"));
      let rec spin n =
        match !cell with
        | Some _ -> ()
        | None ->
            if n = 0 then Alcotest.fail "own-teh1 the self-closing click never replied"
            else (
              Eta_test.advance env#clock (Eta.Duration.seconds 1);
              for _ = 1 to 20 do
                Eio.Fiber.yield ()
              done;
              spin (n - 1))
      in
      spin 40;
      check_disposition "own-teh1 the probe finds the target gone" "closed_externally"
        (await ~sw "own-teh1 the self-closing click" cell))

let () =
  Alcotest.run "L7 actions"
    [
      ( "actions",
        [
          Alcotest.test_case "tab-bw4j tm6c j1z2 1lhx" `Quick click;
          Alcotest.test_case "tab-1lhx" `Quick never_retried;
          Alcotest.test_case "tab-p3x1 0lax" `Quick fill;
          Alcotest.test_case "tab-luo5" `Quick press;
          Alcotest.test_case "tab-5deq" `Quick select;
          Alcotest.test_case "tab-8dop" `Quick scroll;
          Alcotest.test_case "tab-tm6c" `Quick popups;
          Alcotest.test_case "tab-8k2g" `Quick popups_exact;
          Alcotest.test_case "tab-60kn" `Quick dialog;
          Alcotest.test_case "tab-hxld" `Quick serialization;
          Alcotest.test_case "tab-8la3 bw4j" `Quick focus_emulation;
          Alcotest.test_case "tab-0ohq popup acknowledged" `Quick popup_acknowledged;
          Alcotest.test_case "tab-1lhx tab-0ohq slow reply" `Quick slow_reply_settles;
          Alcotest.test_case "tab-0ohq silent page unavailable" `Quick
            silent_page_unavailable;
          Alcotest.test_case "tab-0ohq own-teh1 self-closing click" `Quick
            self_closing_click_reports_tab_gone;
          Alcotest.test_case "own-teh1 tab-0ohq self-closing probe" `Quick
            self_closing_click_probe;
        ] );
    ]
