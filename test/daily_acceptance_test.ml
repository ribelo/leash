(* daily-c4cl, daily-9ggi: acceptance repairs at their source. *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let owner text =
  match P.Owner.of_string text with Ok x -> x | Error e -> Alcotest.fail e

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

let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
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

let rig ?reporter ?download_dir f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let current_child = ref None in
      let memory = Ox_observability.Logger.Memory.create () in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~caps:(Ox_test.powerbox ()) ~sw ~clock
            ~mgr:(Ox_test.Process.mgr mgr) ~argv:(Chrome.argv config)
            ~grace:(Ox.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child ->
            current_child := Some child;
            Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Ox_observability.Logger.create ~service:"leash-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:
            (Option.value reporter
               ~default:(Ox_observability.Logger.Memory.reporter memory))
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true
             ~backoff:{ Chrome.default_backoff with attempts = 0 }
             ())
          {
            Chrome.clock = env#clock;
            mgr = env#process_mgr;
            logger;
            caps = (Ox_test.powerbox () :> Leash.Chrome.caps);
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600 ?download_dir
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
            caps = (Ox_test.powerbox () :> Leash.Tabs.caps);
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
      f env sw chrome tabs fake (fun () -> Option.get !current_child) memory)

let spin label f =
  let rec loop n =
    if f () then ()
    else if n = 0 then Alcotest.fail label
    else (
      Eio.Fiber.yield ();
      loop (n - 1))
  in
  loop 1000

let timed env sw f =
  let cell = ref None in
  Eio.Fiber.fork ~sw (fun () -> cell := Some (f ()));
  let rec loop n =
    match !cell with
    | Some value -> value
    | None when n = 0 -> Alcotest.fail "daily-c4cl bounded action exceeded budget"
    | None ->
        Ox_test.advance env#clock (Ox.Duration.ms 20);
        Eio.Fiber.yield ();
        loop (n - 1)
  in
  loop 200

let script_row fake role =
  let node =
    obj
      [
        ("nodeId", str "12");
        ("role", obj [ ("value", str role) ]);
        ("name", obj [ ("value", str "When") ]);
        ("backendDOMNodeId", `Int 12);
        ("ignored", `Bool false);
        ("childIds", `List []);
      ]
  in
  let ax = obj [ ("nodes", `List [ node ]) ] in
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
                      ("loaderId", str "loader-1");
                      ("url", str "https://example.com/");
                    ] );
              ] );
        ]);
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> ax);
  Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ -> ax);
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ ->
      obj
        [
          ( "documents",
            `List
              [
                obj
                  [
                    ("nodes", obj [ ("backendNodeId", `List [ `Int 12 ]) ]);
                    ( "layout",
                      obj
                        [
                          ("nodeIndex", `List [ `Int 0 ]);
                          ( "bounds",
                            `List [ `List [ `Int 10; `Int 10; `Int 100; `Int 30 ] ] );
                          ("styles", `List [ `List [ `Int 0 ] ]);
                        ] );
                  ];
              ] );
          ("strings", `List [ str "block" ]);
        ]);
  Fake.on_method fake "DOM.describeNode" (fun _ ->
      obj
        [
          ( "node",
            obj
              [
                ("nodeId", `Int 102);
                ("backendNodeId", `Int 12);
                ("nodeName", str "INPUT");
                ("attributes", `List [ str "type"; str "time" ]);
              ] );
        ]);
  Fake.on_method fake "Runtime.evaluate" (fun req ->
      let expression = get "expression" (get "params" req) in
      let value =
        match expression with
        | `String s when s = Leash__Snapshot_source.interactive_count_expression ->
            obj [ ("type", str "number"); ("value", `Int 0) ]
        | `String s when contains s "leashSnapshotGuard" ->
            obj
              [
                ("type", str "object");
                ( "value",
                  obj
                    [
                      ("epoch", str "doc-1");
                      ("count", `Int 1);
                      ("width", `Int 800);
                      ("height", `Int 600);
                    ] );
              ]
        | _ -> obj [ ("type", str "boolean"); ("value", `Bool true) ]
      in
      obj [ ("result", value) ])

let snapshot tabs h =
  let json =
    result
      (request tabs "alice"
         (P.Snap { tab = h; offset = None; limit = None; match_ = None }))
  in
  let id =
    match P.Snapshot_id.t_of_yojson (get "snapshot" json) with
    | Ok id -> id
    | Error e -> Alcotest.fail e
  in
  (id, json)

let press_keys () =
  rig (fun _ _ _ tabs fake _ _ ->
      let h = tab (result (request tabs "alice" (P.New { url = None }))) in
      script_row (fake ()) "InputTime";
      let id, _ = snapshot tabs h in
      List.iter
        (fun key ->
          ignore
            (result
               (request tabs "alice"
                  (P.Press
                     {
                       tab = h;
                       snapshot = id;
                       index = None;
                       key;
                       snap = None;
                       match_ = None;
                       limit = None;
                     }))))
        [ "Enter"; "Esc"; "Escape"; "ArrowRight"; "a"; "1"; "-"; "'" ];
      match
        request tabs "alice"
          (P.Press
             {
               tab = h;
               snapshot = id;
               index = None;
               key = "Return";
               snap = None;
               match_ = None;
               limit = None;
             })
      with
      | P.Success _ -> Alcotest.fail "unsupported Return accepted"
      | P.Failure error ->
          Alcotest.(check string)
            "daily-c4cl unsupported key" "invalid-request"
            (P.Error_code.to_string error.code);
          Alcotest.(check bool)
            "accepted names in hint" true (contains error.hint "Enter");
          Alcotest.(check bool)
            "machine-readable accepted set" true
            (Option.is_some (Option.bind error.detail (field "accepted_keys"))))

let native_identity () =
  rig (fun _ _ _ tabs fake _ _ ->
      let h = tab (result (request tabs "alice" (P.New { url = None }))) in
      script_row (fake ()) "InputTime";
      let id, json = snapshot tabs h in
      let row =
        match get "rows" json with
        | `List [ row ] -> row
        | _ -> Alcotest.fail "daily-c4cl native time row absent"
      in
      Alcotest.(check string)
        "native AX role normalized" "textbox"
        (Yojson.Safe.Util.to_string (get "role" row));
      let index = Yojson.Safe.Util.to_int (get "index" row) in
      ignore
        (result
           (request tabs "alice"
              (P.Press
                 {
                   tab = h;
                   snapshot = id;
                   index = Some index;
                   key = "Tab";
                   snap = None;
                   match_ = None;
                   limit = None;
                 })));
      Fake.on_method (fake ()) "Accessibility.getPartialAXTree" (fun _ ->
          obj
            [
              ( "nodes",
                `List
                  [
                    obj
                      [
                        ("role", obj [ ("value", str "button") ]);
                        ("name", obj [ ("value", str "Changed") ]);
                      ];
                  ] );
            ]);
      check_code "daily-c4cl row identity changed, not only id" "stale-snapshot"
        (request tabs "alice"
           (P.Press
              {
                tab = h;
                snapshot = id;
                index = Some index;
                key = "Tab";
                snap = None;
                match_ = None;
                limit = None;
              })))

(* daily-9ggi: stale branches share one recovery object; ownership refusal tells
   whether to claim an unowned tab or leave another owner's tab alone. *)
let recovery_details () =
  rig (fun _ _ _ tabs fake _ _ ->
      let h = tab (result (request tabs "alice" (P.New { url = None }))) in
      script_row (fake ()) "InputTime";
      let old =
        match P.Snapshot_id.of_string "old" with Ok x -> x | _ -> assert false
      in
      let stale current command =
        match request tabs "alice" command with
        | P.Success _ -> Alcotest.fail "daily-9ggi expected stale-snapshot"
        | P.Failure error ->
            let expected = P.stale_snapshot current in
            Alcotest.(check string)
              "daily-9ggi one stale message" expected.message error.message;
            Alcotest.(check string)
              "daily-9ggi stale code" "stale-snapshot"
              (P.Error_code.to_string error.code);
            Alcotest.(check bool)
              "daily-9ggi current snapshot always in detail" true
              (error.detail = expected.detail);
            Alcotest.(check string)
              "daily-9ggi canonical recovery" expected.hint error.hint
      in
      let press snapshot index =
        P.Press
          {
            tab = h;
            snapshot;
            index;
            key = "Tab";
            snap = None;
            match_ = None;
            limit = None;
          }
      in
      stale None (press old None);
      let first, _ = snapshot tabs h in
      ignore (result (request tabs "alice" (press first None)));
      let current, json = snapshot tabs h in
      stale (Some current) (press first None);
      stale (Some current)
        (P.Eval
           {
             tab = h;
             expression = "return element.textContent";
             argument = None;
             index = Some 1;
             snapshot = Some first;
           });
      let index =
        match get "rows" json with
        | `List [ row ] -> Yojson.Safe.Util.to_int (get "index" row)
        | _ -> Alcotest.fail "daily-9ggi missing fixture row"
      in
      Fake.on_method (fake ()) "Accessibility.getPartialAXTree" (fun _ ->
          obj
            [
              ( "nodes",
                `List
                  [
                    obj
                      [
                        ("role", obj [ ("value", str "button") ]);
                        ("name", obj [ ("value", str "Changed") ]);
                      ];
                  ] );
            ]);
      stale (Some current) (press current (Some index));
      Fake.emit ~session:"session-1" (fake ()) ~method_:"Page.frameNavigated"
        ~params:
          (obj
             [
               ( "frame",
                 obj
                   [
                     ("id", str "frame-1");
                     ("loaderId", str "new-doc");
                     ("url", str "https://example.com/new");
                   ] );
             ]);
      spin "daily-9ggi navigation not observed" (fun () ->
          (* This older id is refused without dispatch, even before the event arrives. *)
          match request tabs "alice" (press first None) with
          | P.Failure error -> Option.bind error.detail (field "snapshot") = Some `Null
          | P.Success _ -> false);
      stale None (press current None);
      let not_owner who state expected_owner =
        match request tabs who (P.Text { tab = h; index = None; max_chars = None }) with
        | P.Success _ -> Alcotest.fail "daily-9ggi expected not-owner"
        | P.Failure error ->
            Alcotest.(check string)
              "daily-9ggi not-owner code" "not-owner"
              (P.Error_code.to_string error.code);
            Alcotest.(check string)
              "daily-9ggi canonical owner hint"
              (P.Error_code.hint error.code)
              error.hint;
            let detail = Option.get error.detail in
            Alcotest.(check bool)
              "daily-9ggi ownership state detail" true
              (get "state" detail = str state && get "owner" detail = expected_owner)
      in
      not_owner "bob" "owned" (str "alice");
      ignore (result (request tabs "alice" (P.Release { tab = h; force = None })));
      not_owner "alice" "unowned" `Null)

let popup_url () =
  rig (fun env sw _ tabs fake _ _ ->
      let h = tab (result (request tabs "alice" (P.New { url = None }))) in
      let fake = fake () in
      script_row fake "InputTime";
      let id, _ = snapshot tabs h in
      let refreshes = ref 0 in
      let popup_info url =
        obj
          [
            ("targetId", str "popup");
            ("type", str "page");
            ("url", str url);
            ("title", str "Popup");
            ("openerId", str "target-1");
          ]
      in
      Fake.on_method fake "Target.getTargetInfo" (fun req ->
          if field "targetId" (get "params" req) = Some (str "popup") then (
            incr refreshes;
            obj
              [
                ( "targetInfo",
                  popup_info (if !refreshes = 1 then "" else "https://example.com/popup")
                );
              ])
          else
            obj
              [
                ( "targetInfo",
                  obj
                    [
                      ("targetId", str "target-1");
                      ("type", str "page");
                      ("title", str "Page");
                      ("url", str "https://example.com/");
                    ] );
              ]);
      Fake.on_method fake "Input.dispatchKeyEvent" (fun req ->
          if get "type" (get "params" req) = str "keyUp" then
            Fake.emit fake ~method_:"Target.attachedToTarget"
              ~params:
                (obj
                   [
                     ("sessionId", str "popup-session");
                     ("targetInfo", popup_info "");
                     ("waitingForDebugger", `Bool false);
                   ]);
          obj []);
      let reply =
        timed env sw (fun () ->
            request tabs "alice"
              (P.Press
                 {
                   tab = h;
                   snapshot = id;
                   index = None;
                   key = "Enter";
                   snap = None;
                   match_ = None;
                   limit = None;
                 }))
        |> result
      in
      let popup =
        match get "popups" reply with
        | `List [ popup ] -> popup
        | _ -> Alcotest.fail "daily-c4cl popup absent"
      in
      Alcotest.(check string)
        "action returns eventual popup URL" "https://example.com/popup"
        (Yojson.Safe.Util.to_string (get "url" popup));
      Alcotest.(check int) "bounded refresh observed delayed target metadata" 2 !refreshes)

let download_bytes () =
  rig ~download_dir:"/tmp/leash-c-acceptance-downloads" (fun _ _ _ tabs fake _ _ ->
      let h = tab (result (request tabs "alice" (P.New { url = None }))) in
      let fake = fake () in
      Fake.emit ~session:"session-1" fake ~method_:"Page.frameNavigated"
        ~params:
          (obj
             [
               ( "frame",
                 obj [ ("id", str "frame-1"); ("url", str "https://example.com/") ] );
             ]);
      Fake.emit fake ~method_:"Browser.downloadWillBegin"
        ~params:
          (obj
             [
               ("frameId", str "frame-1");
               ("guid", str "download");
               ("url", str "https://example.com/file");
               ("suggestedFilename", str "file.pdf");
             ]);
      let read () =
        match
          get "downloads" (result (request tabs "alice" (P.Downloads { tab = h })))
        with
        | `List [ entry ] -> Some entry
        | _ -> None
      in
      spin "download begin absent" (fun () -> Option.is_some (read ()));
      let entry = Option.get (read ()) in
      Alcotest.(check int)
        "received starts at zero" 0
        (Yojson.Safe.Util.to_int (get "received_bytes" entry));
      Fake.emit fake ~method_:"Browser.downloadProgress"
        ~params:
          (obj
             [
               ("guid", str "download");
               ("state", str "inProgress");
               ("receivedBytes", `Float 47.);
               ("totalBytes", `Float 105.);
             ]);
      spin "byte progress absent" (fun () ->
          get "received_bytes" (Option.get (read ())) = `Int 47);
      let entry = Option.get (read ()) in
      Alcotest.(check int)
        "total exposed" 105
        (Yojson.Safe.Util.to_int (get "total_bytes" entry));
      Fake.emit fake ~method_:"Browser.downloadProgress"
        ~params:
          (obj
             [
               ("guid", str "download");
               ("state", str "completed");
               ("receivedBytes", `Float 105.);
               ("totalBytes", `Float 105.);
               ("filePath", str "/tmp/file.pdf");
             ]);
      spin "completion absent" (fun () ->
          get "state" (Option.get (read ())) = str "completed");
      Alcotest.(check int)
        "completed bytes retained" 105
        (Yojson.Safe.Util.to_int (get "received_bytes" (Option.get (read ())))))

let chrome_identity () =
  rig (fun env sw chrome _ _ child memory ->
      Alcotest.(check (option int))
        "daily-c4cl actual managed child pid"
        (Some (Ox_process.Child.pid (child ())))
        (Chrome.status chrome).pid;
      Ox_process.Child.signal (child ()) Sys.sigkill;
      timed env sw (fun () ->
          while (Chrome.status chrome).failure = None do
            Eio.Fiber.yield ()
          done);
      Alcotest.(check (option int)) "no stale PID" None (Chrome.status chrome).pid;
      Alcotest.(check bool)
        "failure uses OS-facing signal" true
        (contains (Option.get (Chrome.status chrome).failure) "SIGKILL / 9");
      let records = Ox_observability.Logger.Memory.records memory in
      let lost =
        List.find
          (fun record -> record.Ox_observability.Logger.msg = "chrome generation lost")
          records
      in
      match List.assoc_opt "origin" lost.fields with
      | Some (Ox_observability.Logger.String s) ->
          Alcotest.(check string) "journal uses OS-facing signal" "SIGKILL / 9" s
      | _ -> Alcotest.fail "lost generation origin absent")

let config_roots () =
  let config =
    match
      Leash.Config.decode_all
        (obj
           [
             ( "skill",
               obj
                 [
                   ( "roots",
                     `List
                       [
                         str "~/.dotfiles/skills/engineering/debugging"; str "$LIB/skills";
                       ] );
                 ] );
           ])
    with
    | Ok config -> config
    | Error _ -> Alcotest.fail "daily-c4cl roots decode refused"
  in
  let expanded =
    Leash.Config.env
      ~getenv:(function
        | "HOME" -> Some "/home/test" | "LIB" -> Some "/opt/library" | _ -> None)
      config
  in
  Alcotest.(check (list string))
    "nested roots and expansion"
    [ "/home/test/.dotfiles/skills/engineering/debugging"; "/opt/library/skills" ]
    (List.map Leash.Config.Text.to_string expanded.skill.roots);
  let refused ?getenv pointer roots =
    match
      Leash.Config.decode_all ?getenv (obj [ ("skill", obj [ ("roots", `List roots) ]) ])
    with
    | Ok _ -> Alcotest.fail ("invalid root accepted: " ^ pointer)
    | Error issues ->
        Alcotest.(check bool)
          "index-specific error" true
          (List.exists (fun issue -> issue.Ox_app.Config.pointer = pointer) issues)
  in
  refused "/skill/roots/1" [ str "/good"; `Int 3 ];
  refused "/skill/roots/0" [ str "relative/skills" ];
  refused ~getenv:(fun _ -> None) "/skill/roots/0" [ str "$UNSET/skills" ];
  refused ~getenv:(fun _ -> None) "/skill/roots/0" [ str "~/skills" ];
  match
    Leash.Config.decode_all
      (obj [ ("skill", obj [ ("roots", `List [ str "relative/skills"; `Int 3 ]) ]) ])
  with
  | Ok _ -> Alcotest.fail "invalid roots accepted"
  | Error issues ->
      Alcotest.(check (list string))
        "root issues aggregate"
        [ "/skill/roots/1"; "/skill/roots/0" ]
        (List.map (fun issue -> issue.Ox_app.Config.pointer) issues)

let skill_catalog () =
  let text =
    In_channel.with_open_bin "../skill/references/errors.md" In_channel.input_all
  in
  List.iter
    (fun code ->
      let expected =
        Printf.sprintf "| `%s` | %d | %s | %s |" (P.Error_code.to_string code)
          (P.Error_code.exit_code code) (P.Error_code.meaning code)
          (P.Error_code.hint code)
      in
      Alcotest.(check bool)
        ("daily-c4cl skill catalog: " ^ P.Error_code.to_string code)
        true (contains text expected))
    P.Error_code.all

let () =
  Alcotest.run "daily-c4cl acceptance"
    [
      ( "daily-9ggi",
        [
          Alcotest.test_case "press vocabulary" `Quick press_keys;
          Alcotest.test_case "native time identity and stale row" `Quick native_identity;
          Alcotest.test_case "daily-9ggi recovery detail" `Quick recovery_details;
          Alcotest.test_case "delayed popup URL" `Quick popup_url;
          Alcotest.test_case "download progress bytes" `Quick download_bytes;
          Alcotest.test_case "managed PID and signal numbers" `Quick chrome_identity;
          Alcotest.test_case "configured nested roots" `Quick config_roots;
          Alcotest.test_case "skill catalog is canonical" `Quick skill_catalog;
        ] );
    ]
