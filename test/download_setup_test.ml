(* daily-c4cl: persisted download history must load before CDP replaces its delegate. *)
module Fake = Leash_test_support.Fake_browser
module Cdp = Leash.Cdp

let obj fields = `Assoc fields
let str value = `String value

let get key = function
  | `Assoc fields -> Option.value (List.assoc_opt key fields) ~default:`Null
  | _ -> `Null

let rig f =
  Ox_test.run (fun env sw ->
      let fake, client = Fake.create ~sw () in
      let cdp =
        Cdp.create ~sw ~clock:env#clock { read = client.read; write = client.write }
      in
      let prepare ~on_target =
        let result = ref None in
        Eio.Fiber.fork ~sw (fun () ->
            result := Some (Leash.Download_setup.prepare ~clock:env#clock ~cdp ~on_target));
        let rec await rounds =
          match !result with
          | Some result -> result
          | None when rounds = 0 -> Alcotest.fail "daily-c4cl bootstrap exceeded budget"
          | None ->
              for _ = 1 to 100 do
                Eio.Fiber.yield ()
              done;
              Ox_test.advance env#clock (Ox.Duration.ms 20);
              await (rounds - 1)
        in
        await 300
      in
      f env#clock fake prepare)

let closed fake =
  List.exists
    (fun req ->
      get "method" req = str "Target.closeTarget"
      && get "targetId" (get "params" req) = str "download-setup-target")
    (Fake.received fake)

let waits_for_history () =
  rig (fun _clock fake prepare ->
      let announced = ref false and evaluations = ref 0 in
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          Alcotest.(check bool) "daily-c4cl hide target before attachment" true !announced;
          Alcotest.(check bool)
            "dedicated session" true
            (get "sessionId" request = str "download-setup-session");
          incr evaluations;
          obj [ ("result", obj [ ("value", `Bool (!evaluations = 3)) ]) ]);
      let result = prepare ~on_target:(fun _ -> announced := true) in
      Alcotest.(check bool) "history acknowledged" true (result = Ok ());
      Alcotest.(check int) "not merely first page evaluation" 3 !evaluations;
      Alcotest.(check bool) "closed internal target" true (closed fake);
      let created = List.hd (Fake.received fake) in
      Alcotest.(check bool)
        "background target" true
        (get "background" (get "params" created) = `Bool true))

let failure_closes () =
  rig (fun _clock fake prepare ->
      Fake.on_failure fake "Target.attachToTarget" (fun _ -> Some (-1, "attach failed"));
      let result = prepare ~on_target:ignore in
      Alcotest.(check bool)
        "daily-c4cl failure is explicit" true
        (result = Error (`Bootstrap "Target.attachToTarget"));
      Alcotest.(check bool) "failed setup closes target" true (closed fake))

let bounded_wait () =
  rig (fun clock fake prepare ->
      Fake.withhold fake "Runtime.evaluate" (fun _ -> true);
      let start = Eio.Time.now clock in
      let result = prepare ~on_target:ignore in
      Alcotest.(check bool) "daily-c4cl never hangs startup" true (Result.is_error result);
      Alcotest.(check bool) "five-second budget" true (Eio.Time.now clock -. start < 6.);
      Alcotest.(check bool) "timeout closes target" true (closed fake))

let () =
  Alcotest.run "daily-c4cl download startup"
    [
      ( "history",
        [
          Alcotest.test_case "wait for acknowledgement and close" `Quick waits_for_history;
          Alcotest.test_case "close after failure" `Quick failure_closes;
          Alcotest.test_case "bounded unresponsive page" `Quick bounded_wait;
        ] );
    ]
