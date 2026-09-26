module Fake = Leash_test_support.Fake_browser

let obj fields = `Assoc fields
let member name = function `Assoc fields -> List.assoc_opt name fields | _ -> None

let assert_json label expected actual =
  Alcotest.(check string)
    label
    (Yojson.Safe.to_string expected)
    (Yojson.Safe.to_string actual)

let reader flow = Eio.Buf_read.of_flow ~max_size:1_048_576 flow

let request client json =
  Eio.Flow.copy_string (Yojson.Safe.to_string json ^ "\000") client.Fake.write

let reply input =
  let body = Eio.Buf_read.take_while (fun c -> c <> '\000') input in
  Eio.Buf_read.char '\000' input;
  Yojson.Safe.from_string body

let request_reply () =
  Eta_test.run (fun _env sw ->
      let _fake, client = Fake.create ~sw () in
      let input = reader client.read in
      List.iteri
        (fun n (method_, expected) ->
          request client (obj [ ("id", `Int (n + 1)); ("method", `String method_) ]);
          assert_json method_
            (obj [ ("id", `Int (n + 1)); ("result", expected) ])
            (reply input))
        [
          ("Target.createTarget", obj [ ("targetId", `String "target-1") ]);
          ("Target.attachToTarget", obj [ ("sessionId", `String "session-1") ]);
          ("Target.setDiscoverTargets", obj []);
          ("Target.setAutoAttach", obj []);
          ("Target.getTargets", obj [ ("targetInfos", `List []) ]);
          ("Target.closeTarget", obj [ ("success", `Bool true) ]);
          ("Page.enable", obj []);
          ( "Page.navigate",
            obj [ ("frameId", `String "frame-1"); ("loaderId", `String "loader-1") ] );
          ("Runtime.evaluate", obj [ ("result", obj [ ("type", `String "undefined") ]) ]);
        ];
      request client (obj [ ("id", `Int 10); ("method", `String "Unknown.method") ]);
      assert_json "unknown CDP method"
        (obj
           [
             ("id", `Int 10);
             ( "error",
               obj [ ("code", `Int (-32601)); ("message", `String "Method not found") ] );
           ])
        (reply input))

let session_echo () =
  Eta_test.run (fun _env sw ->
      let _fake, client = Fake.create ~sw () in
      let input = reader client.read in
      request client
        (obj
           [
             ("id", `Int 42);
             ("sessionId", `String "session-a");
             ("method", `String "Page.enable");
           ]);
      assert_json "id and sessionId preserved"
        (obj [ ("id", `Int 42); ("sessionId", `String "session-a"); ("result", obj []) ])
        (reply input))

let event_on_cue () =
  Eta_test.run (fun _env sw ->
      let fake, client = Fake.create ~sw () in
      let input = reader client.read in
      List.iter
        (fun method_ ->
          let params = Fake.event method_ in
          Fake.emit fake ~method_ ~params;
          assert_json method_
            (obj [ ("method", `String method_); ("params", params) ])
            (reply input))
        [
          "Target.targetCreated";
          "Target.targetInfoChanged";
          "Target.targetDestroyed";
          "Target.attachedToTarget";
          "Target.detachedFromTarget";
          "Page.loadEventFired";
          "Page.frameNavigated";
          "Page.domContentEventFired";
        ];
      Fake.emit fake ~session:"session-a" ~method_:"Page.domContentEventFired"
        ~params:(Fake.event "Page.domContentEventFired");
      Alcotest.(check (option string))
        "event session" (Some "session-a")
        (match member "sessionId" (reply input) with
        | Some (`String s) -> Some s
        | _ -> None))

let records_and_override () =
  Eta_test.run (fun _env sw ->
      let fake, client = Fake.create ~sw () in
      Fake.on_method fake "Target.getTargets" (fun request ->
          obj
            [
              ( "targetInfos",
                `List [ obj [ ("targetId", Option.get (member "id" request)) ] ] );
            ]);
      let sent =
        obj
          [ ("id", `Int 7); ("method", `String "Target.getTargets"); ("params", obj []) ]
      in
      request client sent;
      assert_json "override sees request"
        (obj
           [
             ("id", `Int 7);
             ("result", obj [ ("targetInfos", `List [ obj [ ("targetId", `Int 7) ] ]) ]);
           ])
        (reply (reader client.read));
      Alcotest.(check int) "record count" 1 (List.length (Fake.received fake));
      assert_json "record exact frame" sent (List.hd (Fake.received fake)))

let drop_pipe () =
  Eta_test.run (fun _env sw ->
      let fake, client = Fake.create ~sw () in
      let input = reader client.read in
      Fake.drop fake;
      Fake.drop fake;
      Alcotest.check_raises "EOF after peer crash" End_of_file (fun () ->
          ignore (Eio.Buf_read.any_char input)))

let placeholder () =
  Eta_test.run (fun _env _sw -> Alcotest.(check bool) "L0 placeholder" true true)

let () =
  Alcotest.run "L0 fake browser"
    [
      ( "CDP pipe",
        [
          Alcotest.test_case "request/reply defaults" `Quick request_reply;
          Alcotest.test_case "id and session echo" `Quick session_echo;
          Alcotest.test_case "events on cue" `Quick event_on_cue;
          Alcotest.test_case "recording and override" `Quick records_and_override;
          Alcotest.test_case "drop reaches EOF" `Quick drop_pipe;
        ] );
      ("later rows", [ Alcotest.test_case "placeholder" `Quick placeholder ]);
    ]
