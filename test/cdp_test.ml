(* cdp framing, correlation, sessions and events. Stories: chrome-2z2z (transport
   close), chrome-6lfk (fail fast), and the CDP seam the registry reads. *)

module Fake = Leash_test_support.Fake_browser
module Cdp = Leash.Cdp

let transport (client : Fake.client) : Cdp.transport =
  { read = client.read; write = client.write }

let obj fields = `Assoc fields
let str value = `String value
let json value = Yojson.Safe.to_string value
let member name = function `Assoc fields -> List.assoc_opt name fields | _ -> None

let assert_member label expected message name =
  Alcotest.(check (option string))
    label
    (Some (json expected))
    (Option.map json (member name message))

let frame_round_trip () =
  Eta_test.run (fun _env sw ->
      let a_read, a_write = Eio_unix.pipe sw in
      let b_read, b_write = Eio_unix.pipe sw in
      let a = Cdp.Frame.of_flows ~read:b_read ~write:a_write () in
      let b = Cdp.Frame.of_flows ~read:a_read ~write:b_write () in
      let first = obj [ ("id", `Int 1); ("method", str "A.one") ] in
      let second = obj [ ("id", `Int 2); ("method", str "A.two"); ("params", obj []) ] in
      Cdp.Frame.write a first;
      Cdp.Frame.write a second;
      Alcotest.(check (option string))
        "first frame"
        (Some (json first))
        (Option.map json (Cdp.Frame.read b));
      Alcotest.(check (option string))
        "second frame"
        (Some (json second))
        (Option.map json (Cdp.Frame.read b));
      let reply = obj [ ("id", `Int 1); ("result", obj []) ] in
      Cdp.Frame.write b reply;
      Alcotest.(check (option string))
        "reply frame"
        (Some (json reply))
        (Option.map json (Cdp.Frame.read a));
      Eio.Resource.close a_write;
      Alcotest.(check (option string))
        "end of input" None
        (Option.map json (Cdp.Frame.read b)))

let frame_errors () =
  Eta_test.run (fun _env sw ->
      let a_read, a_write = Eio_unix.pipe sw in
      let _b_read, b_write = Eio_unix.pipe sw in
      let b = Cdp.Frame.of_flows ~read:a_read ~write:b_write () in
      Eio.Flow.copy_string "{\"id\":1" a_write;
      Eio.Resource.close a_write;
      Alcotest.check_raises "truncated final frame" End_of_file (fun () ->
          ignore (Cdp.Frame.read b));
      let c_read, c_write = Eio_unix.pipe sw in
      let _d_read, d_write = Eio_unix.pipe sw in
      let d = Cdp.Frame.of_flows ~read:c_read ~write:d_write () in
      Eio.Flow.copy_string "not json\000" c_write;
      match Cdp.Frame.read d with
      | _ -> Alcotest.fail "expected a JSON error"
      | exception Yojson.Json_error _ -> ())

let call_round_trip () =
  Eta_test.run (fun env sw ->
      let fake, client = Fake.create ~sw () in
      let cdp = Cdp.create ~sw ~clock:env#clock (transport client) in
      (match Cdp.call cdp "Target.getTargets" (obj []) with
      | Error _ -> Alcotest.fail "Target.getTargets did not round-trip"
      | Ok reply ->
          assert_member "result" (obj [ ("targetInfos", `List []) ]) reply "result");
      match Fake.received fake with
      | [ request ] ->
          assert_member "method" (str "Target.getTargets") request "method";
          assert_member "id" (`Int 1) request "id"
      | requests -> Alcotest.failf "expected one request, got %d" (List.length requests))

let session_call () =
  Eta_test.run (fun env sw ->
      let fake, client = Fake.create ~sw () in
      let cdp = Cdp.create ~sw ~clock:env#clock (transport client) in
      (match Cdp.call cdp ~session:"session-1" "Page.enable" (obj []) with
      | Error _ -> Alcotest.fail "session-scoped Page.enable did not round-trip"
      | Ok reply -> assert_member "result" (obj []) reply "result");
      let request = List.hd (Fake.received fake) in
      assert_member "request session" (str "session-1") request "sessionId";
      (* a deadline the reply beats is still a reply *)
      match
        Cdp.call cdp ~deadline:(Eta.Duration.seconds 5) "Target.getTargets" (obj [])
      with
      | Ok _ -> ()
      | Error _ -> Alcotest.fail "call with a deadline did not round-trip")

let method_error () =
  Eta_test.run (fun env sw ->
      let _fake, client = Fake.create ~sw () in
      let cdp = Cdp.create ~sw ~clock:env#clock (transport client) in
      match Cdp.call cdp "No.suchMethod" (obj []) with
      | Error _ -> Alcotest.fail "an error reply is still a reply"
      | Ok reply ->
          Alcotest.(check (option (pair int string)))
            "CDP error"
            (Some (-32601, "Method not found"))
            (Cdp.error_of_reply reply))

let events_beside_calls () =
  Eta_test.run (fun env sw ->
      let fake, client = Fake.create ~sw () in
      let cdp = Cdp.create ~sw ~clock:env#clock (transport client) in
      Fake.emit fake ~method_:"Target.targetCreated"
        ~params:(Fake.event "Target.targetCreated");
      (match Cdp.call cdp "Target.getTargets" (obj []) with
      | Error _ -> Alcotest.fail "a pending event must not break a call"
      | Ok _ -> ());
      match Eio.Stream.take (Cdp.events cdp) with
      | Eta_rpc.Correlator.Message message ->
          assert_member "event method" (str "Target.targetCreated") message "method"
      | Eta_rpc.Correlator.Closed _ -> Alcotest.fail "the transport closed early")

let transport_close () =
  Eta_test.run (fun env sw ->
      let fake, client = Fake.create ~sw () in
      let cdp = Cdp.create ~sw ~clock:env#clock (transport client) in
      (match Cdp.call cdp "Target.getTargets" (obj []) with
      | Error _ -> Alcotest.fail "the first call did not round-trip"
      | Ok _ -> ());
      Fake.drop fake;
      (match Eio.Promise.await (Cdp.closed cdp) with
      | `Eof -> ()
      | `Read_failed _ -> Alcotest.fail "expected end of input, not a read failure"
      | `Closed -> Alcotest.fail "expected end of input, not an explicit close");
      (match Cdp.call cdp "Target.getTargets" (obj []) with
      | Error (`Transport_closed _) -> ()
      | Error _ -> Alcotest.fail "expected a transport-closed error"
      | Ok _ -> Alcotest.fail "a closed transport must not answer");
      match Eio.Stream.take (Cdp.events cdp) with
      | Eta_rpc.Correlator.Closed _ -> ()
      | Eta_rpc.Correlator.Message _ -> Alcotest.fail "expected the closing notification")

let () =
  Alcotest.run "L2 CDP"
    [
      ( "framing",
        [
          Alcotest.test_case "NUL-delimited round trip" `Quick frame_round_trip;
          Alcotest.test_case "truncation and bad JSON" `Quick frame_errors;
        ] );
      ( "correlation",
        [
          Alcotest.test_case "call round trip" `Quick call_round_trip;
          Alcotest.test_case "session and deadline" `Quick session_call;
          Alcotest.test_case "method-not-found reply" `Quick method_error;
          Alcotest.test_case "events beside calls" `Quick events_beside_calls;
        ] );
      ( "transport",
        [ Alcotest.test_case "close reaches the caller" `Quick transport_close ] );
    ]
