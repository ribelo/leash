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
      script = None;
      index = None;
      option = None;
      confidence = 1.;
      target_confidence = None;
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
    ?(notify = fun _ -> Ok ()) ?notification f =
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
                     ~headless:true ())
                  {
                    Chrome.clock = env#clock;
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
      max_procedures = Some 8;
      deadline_s = Some 30;
      dry_run = Some false;
      expect = None;
      out = None;
      secrets = [];
    }

let run_reply ?tab ?(planner_actions = 2) tabs ~plan ~decide =
  let levels =
    R.
      {
        choose =
          (fun ~deadline:_ _ ->
            Ok
              {
                key = "none";
                probabilities = `Assoc [];
                confidence = 1.;
                usage = None;
                judgments = [];
              });
        score = (fun ~deadline:_ ~sentence:_ ~state:_ -> Ok 1.);
        plan = (fun ~deadline:_ request -> plan request);
      }
  in
  let line =
    Yojson.Safe.to_string (P.encode_request P.{ command = Drive (args ?tab ()) })
  in
  let wire =
    Leash.Control.handle ~installed:[] ~levels ~planner_actions
      ~decide:(fun ~deadline:_ request -> decide request)
      tabs line
  in
  ok (P.decode_reply (Yojson.Safe.from_string wire))

let run ?tab ?(planner_actions = 2) tabs ~plan ~decide =
  match run_reply ?tab ~planner_actions tabs ~plan ~decide with
  | P.Success json ->
      succeeded
        (P.run_result_of_yojson json
        |> Result.map_error (fun message ->
            P.make_error (ok (P.Error_code.of_string "internal")) ~message))
  | P.Failure e -> Alcotest.fail e.message

let reply answer =
  Ok
    R.
      {
        answer;
        expect = [];
        reasoning_summary = None;
        secrets_for_operator = [];
        usage = None;
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
          P.{ tab = result.P.final.tab; match_ = None; limit = None; offset = None }))

let notify_then_done
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(signal = "blocked") () =
  let messages = ref [] and jev = ref 0 and plans = ref 0 in
  rig ~caps
    ~notify:(fun s ->
      messages := s :: !messages;
      Error "phone command failed")
    (fun _ _ tabs _ ->
      let result =
        run tabs
          ~plan:(fun request ->
            incr plans;
            ignore (signal, request);
            reply
              (if !plans = 1 then R.Notify "Order 12345 placed"
               else R.Done { result = "Notified"; evidence = [] }))
          ~decide:(fun _ ->
            incr jev;
            Ok (decision (if !jev = 1 then signal else "done")))
      in
      status "done" result;
      Alcotest.(check int) "notify returns to pilot" 2 !plans;
      Alcotest.(check int) "notify does not invoke JEV" 0 !jev;
      Alcotest.(check (list string))
        "one nonblocking message" [ "Order 12345 placed" ] !messages;
      let event = List.hd (events result "notify") in
      eq "failure recorded, not raised" "failed"
        (Yojson.Safe.Util.to_string (member "outcome" event));
      boolean "no handoff on notify" (events result "handoff" = []))

let expiry
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  let messages = ref [] in
  rig ~caps
    ~notify:(fun s ->
      messages := s :: !messages;
      Ok ())
    (fun env _ tabs _ ->
      let before = Eio.Time.now env#clock in
      let result =
        run tabs
          ~plan:(fun _ -> reply (R.Handoff "Login required"))
          ~decide:(fun _ -> Ok (decision "blocked"))
      in
      status "handoff-expired" result;
      boolean "bounded human wait" (Eio.Time.now env#clock -. before >= 1.);
      Alcotest.(check (list string))
        "expiry message"
        [ "the agent gave up waiting; the tab is still open" ]
        !messages;
      tab_open tabs result;
      let event = List.hd (events result "handoff") in
      boolean "wait recorded" (member "elapsed_ms" event <> `Null);
      eq "expiry traced" "expired" (Yojson.Safe.Util.to_string (member "outcome" event));
      boolean "with_human cleared"
        (List.for_all
           (fun (tab : P.tab_listing) -> not tab.with_human)
           (Tabs.list tabs).tabs))

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

let click request =
  R.Act
    (P.Click
       P.
         {
           tab = request.R.snapshot.tab;
           snapshot = request.R.snapshot.snapshot;
           index = 1;
           snap = None;
           match_ = None;
           limit = None;
         })

let challenge_case
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(broken = false) ~attempt ~clears ~actions () =
  let plans = ref [] and clicked = ref 0 and jev = ref 0 in
  rig ~caps ~attempt (fun _ _ tabs fake ->
      set_ax fake "CAPTCHA checkbox";
      if broken then
        Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ ->
            obj [ ("nodes", `List []) ]);
      Fake.on_method fake "Input.dispatchMouseEvent" (fun _ ->
          incr clicked;
          if clears then set_ax fake "Continue";
          obj []);
      let result =
        run tabs
          ~plan:(fun request ->
            plans := request :: !plans;
            if clears && List.length !plans > 1 then
              reply (R.Done { result = "Challenge cleared"; evidence = [] })
            else if attempt && actions && List.length !plans <= 2 then
              reply (click request)
            else reply (R.Handoff "captcha"))
          ~decide:(fun _ ->
            incr jev;
            Ok (decision "done"))
      in
      status (if clears then "done" else "handoff-expired") result;
      Alcotest.(check int)
        "bounded attempts"
        (if clears then 2 else if attempt && actions then 3 else 1)
        (List.length !plans);
      if actions then
        boolean "ordinary mouse action executed"
          (if broken then !clicked = 0 else !clicked > 0);
      if not clears then begin
        eq "pilot selected captcha handoff" "captcha"
          (Option.value ~default:"" result.reason);
        boolean "captcha handoff only after bound" (events result "handoff" <> []);
        tab_open tabs result
      end;
      boolean "pilot decisions recorded" (result.pilot_turns > 0);
      if not attempt then Alcotest.(check int) "disabled never reaches JEV" 0 !jev)

let forbidden_challenge_actions
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  List.iter
    (fun case ->
      rig ~caps (fun _ _ tabs fake ->
          set_ax fake "CAPTCHA checkbox";
          let planned = ref 0 in
          let wire =
            run_reply tabs
              ~plan:(fun request ->
                incr planned;
                if !planned > 1 then reply (R.Fail "unsafe action refused")
                else
                  let page = request.R.snapshot in
                  let ordinary =
                    P.Click
                      P.
                        {
                          tab = page.tab;
                          snapshot = page.snapshot;
                          index = (if case = "invented-row" then 999 else 1);
                          snap = None;
                          match_ = None;
                          limit = None;
                        }
                  in
                  let actions =
                    match case with
                    | "javascript" ->
                        [
                          P.Eval
                            P.
                              {
                                tab = page.tab;
                                expression = "globalThis.__l55Forbidden = true";
                                argument = None;
                                index = None;
                                snapshot = None;
                              };
                        ]
                    | "navigation" ->
                        [
                          P.Nav P.{ tab = page.tab; url = "https://example.com/guessed" };
                        ]
                    | _ -> [ ordinary ]
                  in
                  reply (R.Act (List.hd actions)))
              ~decide:(fun _ -> Alcotest.fail "challenge reached JEV before validation")
          in
          (match wire with
          | P.Failure error ->
              eq "unsafe challenge answer refused" "invalid-request"
                (P.Error_code.to_string error.code)
          | P.Success json ->
              let result = ok (P.run_result_of_yojson json) in
              status "failed" result;
              boolean "refusal is recorded"
                (match result.planner_turns with
                | turn :: _ -> Option.is_some turn.reason
                | _ -> false));
          Alcotest.(check int) "refusal returns to pilot" 2 !planned;
          boolean "no mouse or keyboard actions"
            (not
               (List.exists
                  (fun request ->
                    let meth = member "method" request in
                    meth = str "Input.dispatchMouseEvent"
                    || meth = str "Input.insertText"
                    || contains (Yojson.Safe.to_string request) "__l55Forbidden")
                  (Fake.received fake)))))
    [ "javascript"; "navigation"; "invented-row" ]

let disabled
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  challenge_case ~caps ~attempt:false ~clears:false ~actions:false ()

let bounded
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  challenge_case ~caps ~attempt:true ~clears:false ~actions:false ()

let cleared
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  challenge_case ~caps ~attempt:true ~clears:true ~actions:true ()

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

let resumed
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ sw tabs _ ->
      let owned = succeeded (Tabs.new_tab tabs ~url:None) in
      Eio.Fiber.fork ~sw (fun () ->
          let rec wait () =
            match
              List.find_opt
                (fun (tab : P.tab_listing) -> tab.with_human)
                (Tabs.list tabs).tabs
            with
            | None ->
                Eio.Fiber.yield ();
                wait ()
            | Some _ -> (
                let wire =
                  Yojson.Safe.to_string
                    (P.encode_request P.{ command = Resume { tab = owned.tab } })
                in
                match
                  ok
                    (P.decode_reply
                       (Yojson.Safe.from_string (Leash.Control.handle tabs wire)))
                with
                | P.Success _ -> ()
                | P.Failure e -> Alcotest.fail e.message)
          in
          wait ());
      let result =
        run ~tab:owned.tab tabs
          ~plan:
            (let n = ref 0 in
             fun _ ->
               incr n;
               reply
                 (if !n = 1 then R.Handoff "Login"
                  else R.Done { result = "Resumed"; evidence = [] }))
          ~decide:(fun _ -> Ok (decision "blocked"))
      in
      status "done" result;
      eq "resume audited" "resumed"
        (Yojson.Safe.Util.to_string
           (member "outcome" (List.hd (events result "handoff"))));
      tab_open tabs result)

let canceled_notification
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  let calls = ref 0 and messages = ref [] in
  rig ~caps
    ~notification:(Ox_test.Process.Exit (`Exited 0))
    ~notify:(fun message ->
      messages := message :: !messages;
      Ok ())
    (fun _ _ tabs _ ->
      let result =
        run tabs
          ~plan:(fun _ ->
            incr calls;
            reply (R.Handoff "operator decision"))
          ~decide:(fun _ -> Alcotest.fail "canceled mission must not navigate")
      in
      status "canceled-by-operator" result;
      Alcotest.(check int) "pilot-9u3q no pilot retry" 1 !calls;
      boolean "pilot-9u3q no gave-up notification" (!messages = []);
      eq "pilot-9u3q cancellation audited" "canceled-by-operator"
        (Yojson.Safe.Util.to_string
           (member "outcome" (List.hd (events result "handoff"))));
      let saved =
        Leash.Traces.finish
          (Leash.Traces.capture ~mission:"operator decision" ~now:0.)
          ~now:0.1 (Ok result)
      in
      let restored = ok (P.drive_trace_of_yojson (P.yojson_of_drive_trace saved)) in
      eq "pilot-9u3q durable outcome" "canceled-by-operator" restored.outcome;
      boolean "pilot-9u3q durable cancellation event"
        (restored.unattended = result.unattended);
      boolean "pilot-9u3q no outstanding human ownership"
        (List.for_all
           (fun (tab : P.tab_listing) -> not tab.with_human)
           (Tabs.list tabs).tabs);
      tab_open tabs result)

let debug_challenge
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps ~attempt:false (fun _ _ tabs fake ->
      let tab = succeeded (Tabs.new_tab tabs ~url:(Some "https://example.com/")) in
      Fake.emit ~session:"session-1" fake ~method_:"Network.requestWillBeSent"
        ~params:
          (obj
             [
               ("requestId", str "debug-challenge");
               ("type", str "Script");
               ( "request",
                 obj
                   [
                     ( "url",
                       str "https://www.google.com/recaptcha/api.js?secret=not-retained"
                     );
                     ("method", str "GET");
                   ] );
             ]);
      for _ = 1 to 20 do
        Eio.Fiber.yield ()
      done;
      let result =
        run ~tab:tab.tab tabs
          ~plan:(fun _ -> reply (R.Handoff "captcha"))
          ~decide:(fun _ -> Alcotest.fail "debug challenge reached JEV")
      in
      status "handoff-expired" result;
      boolean "pilot handoff recorded" (events result "handoff" <> []);
      tab_open tabs result)

let debug_signal_lifecycle
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  List.iter
    (fun navigates ->
      let count = ref 0 and plans = ref 0 and jev = ref 0 in
      rig ~caps ~guard_count:count (fun _ _ tabs fake ->
          let tab = succeeded (Tabs.new_tab tabs ~url:(Some "https://example.com/")) in
          set_ax fake "Continue";
          Fake.emit ~session:"session-1" fake ~method_:"Network.requestWillBeSent"
            ~params:
              (obj
                 [
                   ("requestId", str "lifecycle-challenge");
                   ("type", str "Script");
                   ( "request",
                     obj
                       [
                         ("url", str "https://www.google.com/recaptcha/api.js");
                         ("method", str "GET");
                       ] );
                 ]);
          for _ = 1 to 20 do
            Eio.Fiber.yield ()
          done;
          if navigates then (
            Fake.emit ~session:"session-1" fake ~method_:"Page.frameNavigated"
              ~params:
                (obj
                   [
                     ( "frame",
                       obj
                         [
                           ("id", str "frame-1");
                           ("loaderId", str "loader-1");
                           ("url", str "https://example.com/next");
                           ("name", str "");
                         ] );
                   ]);
            for _ = 1 to 20 do
              Eio.Fiber.yield ()
            done);
          Fake.on_method fake "Input.dispatchMouseEvent" (fun _ ->
              incr count;
              obj []);
          let result =
            run ~tab:tab.tab tabs
              ~plan:(fun request ->
                incr plans;
                if navigates then
                  reply (R.Done { result = "New document"; evidence = [] })
                else if !plans = 1 then reply (click request)
                else reply (R.Handoff "captcha"))
              ~decide:(fun _ ->
                incr jev;
                Ok (decision "done"))
          in
          status (if navigates then "done" else "handoff-expired") result;
          Alcotest.(check int)
            "current document only, mutations cannot prove clearance"
            (if navigates then 1 else 2)
            !plans;
          Alcotest.(check int) "unresolved challenge never reaches JEV" 0 !jev))
    [ false; true ]

let semantic_challenge
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps ~attempt:false ~text:"Verify you are human" (fun _ _ tabs _ ->
      let result =
        run tabs
          ~plan:(fun _ -> reply (R.Handoff "captcha"))
          ~decide:(fun _ -> Alcotest.fail "semantic challenge reached JEV")
      in
      status "handoff-expired" result;
      boolean "pilot sees semantic page and hands off" (events result "handoff" <> []))

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
          Alcotest.test_case "notif-7o8j notif-m37y notif-7pha notify survives failure"
            `Quick (fun () -> notify_then_done ~caps ());
          Alcotest.test_case "notif-oslv bounded handoff retains tab" `Quick
            (expiry ~caps);
          Alcotest.test_case "notif-himb notif-tdtz ordinary challenge action clears"
            `Quick (cleared ~caps);
          Alcotest.test_case "notif-p4yk two turns then captcha expiry" `Quick
            (bounded ~caps);
          Alcotest.test_case "notif-udh3 disabled attempts and audit" `Quick
            (disabled ~caps);
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
          Alcotest.test_case "notif-oslv normal resume cancels expiry" `Quick
            (resumed ~caps);
          Alcotest.test_case "pilot-9u3q canceled notification stops pilot and trace"
            `Quick (canceled_notification ~caps);
          Alcotest.test_case
            "notif-p4yk failed row actions reach bounded captcha fallback" `Quick
            (challenge_case ~caps ~broken:true ~attempt:true ~clears:false ~actions:true);
          Alcotest.test_case "notif-tdtz debug-only challenge is normalized" `Quick
            (debug_challenge ~caps);
          Alcotest.test_case
            "notif-tdtz debug challenge follows document, not DOM mutations or old log \
             entries"
            `Quick
            (debug_signal_lifecycle ~caps);
          Alcotest.test_case "notif-tdtz inferred semantic challenge" `Quick
            (semantic_challenge ~caps);
          Alcotest.test_case "notif-7pha argv and five-second timeout" `Quick
            (notifier_bound ~caps);
          Alcotest.test_case "notif-udh3 invalid unattended bounds" `Quick config_invalid;
          Alcotest.test_case "notif-himb notif-p4yk no JS, guessed rows or navigation"
            `Quick
            (forbidden_challenge_actions ~caps);
        ] );
    ]
