(* L55 notif-7o8j notif-m37y notif-oslv notif-7pha notif-himb notif-p4yk
   notif-udh3 notif-tdtz: real Control -> Tabs -> Run, scripted CDP and planner.
   No live Chrome, model, desktop command, or installed XDG state. *)
module P = Leash.Protocol
module R = Leash.Run
module Tabs = Leash.Tabs
module Chrome = Leash.Chrome
module Desktop = Leash.Desktop
module Fake = Leash_test_support.Fake_browser
module Logger = Ox_observability.Logger

let ok = function Ok x -> x | Error why -> Alcotest.fail why
let obj fields = `Assoc fields
let str x = `String x
let member key = Yojson.Safe.Util.member key

let contains haystack needle =
  try
    ignore (Str.search_forward (Str.regexp_string needle) haystack 0);
    true
  with Not_found -> false

let boolean name value = Alcotest.(check bool) name true value
let eq name a b = Alcotest.(check string) name a b
let succeeded = function Ok x -> x | Error e -> Alcotest.fail e.P.message

let decision name =
  Leash__Jev_request.
    {
      operation = ok (P.Operation.of_string name);
      index = None;
      option = None;
      confidence = 1.;
      target_confidence = None;
      point = None;
      operation_probabilities = [ (name, 1.) ];
      target_probabilities = [];
      targets = [];
    }

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(attempt = true) ?(turns = 2) ?(text = "Page") ?(guard_count = ref 0)
    ?(notify = fun _ -> Ok ()) ?notification ?(headless = false) f =
  Eio_main.run (fun env ->
      Eio.Time.with_timeout_exn env#clock 10. (fun () ->
          Eio.Switch.run (fun sw ->
              let process =
                Ox_test.Process.make
                  (Ox_test.Process.Block_until_signal :: Option.to_list notification)
              in
              let current = ref None in
              let launch
                  ~(caps :
                     < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >)
                  ~sw ~clock ~mgr:_ config =
                let fake, client = Fake.create ~sw () in
                current := Some fake;
                match
                  Ox_process.Child.spawn ~caps ~sw ~clock
                    ~mgr:(Ox_test.Process.mgr process) ~argv:(Chrome.argv config)
                    ~grace:(Ox.Duration.ms 50) ~fds:[] ()
                with
                | Error e -> Error e
                | Ok child ->
                    Ok (child, Leash.Cdp.{ read = client.read; write = client.write })
              in
              let logger =
                Logger.create ~service:"leash-unattended-test" ~clock:env#clock
                  ~mono_clock:env#mono_clock
                  ~reporter:(Logger.Reporter.writer ignore)
                  ()
              in
              let chrome =
                Chrome.create ~sw ~launch:(launch ~caps)
                  (Chrome.make ~binary:"/bin/sh"
                     ~profile_dir:"/tmp/leash-unattended-unused" ~workspace:"test"
                     ~headless ())
                  {
                    Chrome.clock = env#clock;
                    mono_clock = (env#mono_clock :> Eio.Time.Mono.ty Eio.Resource.t);
                    mgr = env#process_mgr;
                    logger;
                    caps :> Chrome.caps;
                  }
              in
              let tabs =
                Tabs.create ~sw ~cap:8 ~tombstone_s:3600 ~handoff_timeout_s:1
                  ~challenge_attempt:attempt ~challenge_turns:turns ~notify
                  {
                    Tabs.chrome;
                    clock = env#clock;
                    logger;
                    desktop =
                      (match notification with
                      | None -> Desktop.disabled
                      | Some _ ->
                          Desktop.create
                            ~caps:(caps :> Desktop.caps)
                            ~clock:env#clock ~mgr:(Ox_test.Process.mgr process)
                            { Desktop.focus_command = []; notify_command = [ "sh" ] });
                    caps :> Tabs.caps;
                  }
              in
              let rec ready n =
                if n = 0 then Alcotest.fail "fake Chrome did not start"
                else if (Chrome.status chrome).phase <> `Running then (
                  Eio.Fiber.yield ();
                  ready (n - 1))
              in
              ready 1000;
              let fake = Option.get !current in
              let current_url = ref "about:blank" in
              Fake.on_method fake "Target.getTargetInfo" (fun _ ->
                  obj
                    [
                      ( "targetInfo",
                        obj
                          [
                            ("targetId", str "target-1");
                            ("type", str "page");
                            ("title", str "Example");
                            ("url", str !current_url);
                            ("attached", `Bool true);
                          ] );
                    ]);
              Fake.on_method fake "Page.navigate" (fun request ->
                  let session = Yojson.Safe.Util.to_string (member "sessionId" request) in
                  let url = member "url" (member "params" request) in
                  current_url := Yojson.Safe.Util.to_string url;
                  Fake.emit ~session fake ~method_:"Page.frameNavigated"
                    ~params:
                      (obj
                         [
                           ( "frame",
                             obj
                               [
                                 ("id", str "frame-1");
                                 ("loaderId", str "loader-1");
                                 ("url", url);
                                 ("securityOrigin", str "https://example.com");
                                 ("mimeType", str "text/html");
                               ] );
                         ]);
                  Fake.emit ~session fake ~method_:"Page.loadEventFired"
                    ~params:(Fake.event "Page.loadEventFired");
                  obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-1") ]);
              let guard () =
                obj
                  [
                    ("epoch", str "test-document");
                    ("count", `Int !guard_count);
                    ("width", `Int 800);
                    ("height", `Int 600);
                    ("scrollX", `Int 0);
                    ("scrollY", `Int 0);
                    ("dpr", `Int 1);
                  ]
              in
              Fake.on_method fake "Runtime.evaluate" (fun request ->
                  let expression = member "expression" (member "params" request) in
                  let value =
                    if
                      expression = str Leash__Snapshot_source.interactive_count_expression
                    then `Int 0
                    else
                      match expression with
                      | `String s when contains s Leash__Snapshot_source.settle_mark ->
                          `Bool true
                      | `String s when contains s Leash__Snapshot_source.operator_mark ->
                          obj
                            [
                              ("kind", str "leash-operator");
                              ("url", str "https://example.com/");
                              ("title", str "Example");
                              ("timeOrigin", `Int 1);
                              ("text", str text);
                              ("truncated", `Bool false);
                              ("omitted", `Int 0);
                              ("semantics", `List []);
                              ( "scroll",
                                obj
                                  [
                                    ("x", `Int 0);
                                    ("y", `Int 0);
                                    ("height", `Int 600);
                                    ("viewport", `Int 600);
                                    ("width", `Int 800);
                                  ] );
                              ("guard", obj []);
                            ]
                      | `String s
                        when String.starts_with
                               ~prefix:"Array.from(document.body?.innerText" s ->
                          str text
                      | _ -> guard ()
                  in
                  obj [ ("result", obj [ ("type", str "object"); ("value", value) ]) ]);
              Fake.on_method fake "DOM.resolveNode" (fun _ ->
                  obj [ ("object", obj [ ("objectId", str "row-41") ]) ]);
              Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
                  obj
                    [
                      ( "result",
                        obj
                          [
                            ( "value",
                              obj
                                [
                                  ("x", `Int 10);
                                  ("y", `Int 10);
                                  ("width", `Int 100);
                                  ("height", `Int 30);
                                  ("attached", `Bool true);
                                  ("visible", `Bool true);
                                  ("hit", `Bool true);
                                  ("role", str "checkbox");
                                  ("label", str "CAPTCHA checkbox");
                                ] );
                          ] );
                    ]);
              f env sw tabs fake)))

let args ?tab () =
  P.
    {
      tab;
      mission = "Inspect this harmless page";
      max_steps = Some 8;
      start_url = Some "https://example.com/";
      deadline_s = Some 30;
      dry_run = Some false;
      out = None;
      secrets = [];
    }

let status expected result =
  eq "run ending" expected (P.Run_status.to_string result.P.status)

let events result kind =
  List.filter (fun e -> member "kind" e = str kind) result.P.unattended

let tab_open tabs result =
  let listing = P.yojson_of_list_result (Tabs.list tabs) in
  let text = Yojson.Safe.to_string listing in
  boolean "mission tab retained" (String.length text > 2);
  ignore
    (succeeded
       (Tabs.snap tabs
          P.
            {
              tab = result.P.final.tab;
              match_ = None;
              limit = None;
              offset = None;
              with_image = None;
            }))

let ax label =
  obj
    [
      ( "nodes",
        `List
          [
            obj
              [
                ("nodeId", str "1");
                ("backendDOMNodeId", `Int 41);
                ("role", obj [ ("value", str "checkbox") ]);
                ("name", obj [ ("value", str label) ]);
                ("ignored", `Bool false);
              ];
          ] );
    ]

let set_ax fake label =
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ ->
      obj
        [
          ("strings", `List []);
          ( "documents",
            `List
              [
                obj
                  [
                    ("nodes", obj [ ("backendNodeId", `List [ `Int 41 ]) ]);
                    ( "layout",
                      obj
                        [
                          ("nodeIndex", `List [ `Int 0 ]);
                          ( "bounds",
                            `List [ `List [ `Int 10; `Int 10; `Int 100; `Int 30 ] ] );
                          ("styles", `List [ `List [] ]);
                        ] );
                  ];
              ] );
        ]);
  Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ -> ax label);
  Fake.on_method fake "DOM.describeNode" (fun _ ->
      obj
        [
          ( "node",
            obj
              [
                ("nodeId", `Int 41); ("backendNodeId", `Int 41); ("nodeName", str "INPUT");
              ] );
        ]);
  Fake.on_method fake "DOM.getContentQuads" (fun _ ->
      obj
        [
          ( "quads",
            `List
              [ `List (List.map (fun n -> `Int n) [ 10; 10; 110; 10; 110; 40; 10; 40 ]) ]
          );
        ]);
  Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
      obj [ ("backendNodeId", `Int 41) ]);
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> ax label)

let config () =
  let c = Leash.Config.default in
  Alcotest.(check int) "five minute default" 300 c.handoff.timeout_s;
  boolean "challenge attempts default enabled" c.challenges.attempt;
  Alcotest.(check int) "two turns default" 2 c.challenges.turns;
  Alcotest.(check (list string))
    "normal urgency argv"
    [ "notify-send"; "--urgency=normal"; "Leash"; "{message}" ]
    c.notify.command

let command_failure
    ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >) () =
  Ox_test.run (fun env _ ->
      let process = Ox_test.Process.make [] in
      let notify =
        Desktop.notifier
          ~caps:(caps :> Desktop.caps)
          ~clock:env#clock ~mgr:(Ox_test.Process.mgr process)
          ~command:[ "/no/such/leash-notification-command"; "{message}" ]
      in
      boolean "missing executable returns failure" (Result.is_error (notify "test"));
      let disabled =
        Desktop.notifier
          ~caps:(caps :> Desktop.caps)
          ~clock:env#clock ~mgr:(Ox_test.Process.mgr process) ~command:[]
      in
      boolean "disabled notification succeeds" (disabled "test" = Ok ()))

let notifier_bound
    ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >) () =
  Ox_test.run (fun env sw ->
      let process = Ox_test.Process.make ~clock:env#clock [ Block_until_signal ] in
      let notify =
        Desktop.notifier
          ~caps:(caps :> Desktop.caps)
          ~clock:env#clock ~mgr:(Ox_test.Process.mgr process)
          ~command:[ "/bin/sh"; "{message}" ]
      in
      let answer = ref None in
      let message = "Order 123; $(not-a-shell)" in
      Eio.Fiber.fork ~sw (fun () -> answer := Some (notify message));
      let rec started n =
        if Ox_test.Process.spawns process <> [] then ()
        else if n = 0 then Alcotest.fail "notifier never spawned"
        else (
          Eio.Fiber.yield ();
          started (n - 1))
      in
      started 1000;
      Alcotest.(check (list string))
        "message is exactly one argv element" [ "/bin/sh"; message ]
        (List.hd (Ox_test.Process.spawns process)).argv;
      Ox_test.advance env#clock (Ox.Duration.seconds 5);
      let rec finished n =
        match !answer with
        | Some answer -> answer
        | None when n = 0 -> Alcotest.fail "notifier outlived five-second bound"
        | None ->
            Eio.Fiber.yield ();
            finished (n - 1)
      in
      boolean "timeout best-effort failure"
        (finished 1000 = Error "notification command timed out");
      boolean "timed-out child terminated"
        (List.mem Sys.sigterm (Ox_test.Process.signals process)))

let config_invalid () =
  List.iter
    (fun json ->
      boolean "unattended config bounds enforced"
        (Result.is_error (Leash.Config.decode_all ~getenv:(fun _ -> None) json)))
    [
      obj [ ("handoff", obj [ ("timeout_s", `Int 0) ]) ];
      obj [ ("challenges", obj [ ("turns", `Int 0) ]) ];
      obj [ ("challenges", obj [ ("turns", `Int 11) ]) ];
    ]

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L55 unattended"
    [
      ( "protocol seam",
        [
          Alcotest.test_case "notif-oslv notif-7pha notif-udh3 config defaults" `Quick
            config;
          Alcotest.test_case "notif-7pha command failure and disable" `Quick
            (command_failure ~caps);
          Alcotest.test_case "notif-m37y JEV cannot encode direct interruptions" `Quick
            (fun () ->
              List.iter
                (fun name ->
                  boolean "planner-only operation"
                    (Result.is_error (P.Operation.of_string name)))
                [ "handoff"; "notify" ]);
          Alcotest.test_case "notif-7pha argv and five-second timeout" `Quick
            (notifier_bound ~caps);
          Alcotest.test_case "notif-udh3 invalid unattended bounds" `Quick config_invalid;
        ] );
    ]
