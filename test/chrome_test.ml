(* Managed Chrome over the fake process manager and the fake browser. Stories:
   chrome-qo4q (restart under backoff), chrome-2z2z (generation lost), chrome-6lfk
   (browser-unavailable), chrome-b288 (orderly stop). chrome-p2n4, chrome-9ex7 and
   chrome-2y3t are live-only: scripts/live-acceptance launches real Chrome. *)

module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module Cdp = Leash.Cdp

type rig = { mgr : Eta_test.Process.t; mutable browsers : (Fake.t * Fake.client) list }

let launch rig ~sw ~clock ~mgr:_ config =
  let fake, client = Fake.create ~sw () in
  rig.browsers <- (fake, client) :: rig.browsers;
  match
    Eta_process.Child.spawn ~sw ~clock
      ~mgr:(Eta_test.Process.mgr rig.mgr)
      ~argv:(Chrome.argv config) ~grace:(Eta.Duration.ms 50) ~stderr:Pipe ~fds:[] ()
  with
  | Error error -> Error error
  | Ok child ->
      assert (Option.is_some (Eta_process.Child.stderr child));
      let transport : Cdp.transport = { read = client.read; write = client.write } in
      Ok (child, transport)

let config ?(headless = false) () =
  Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-profile" ~workspace:"dev"
    ~headless ()

let deps env : _ Chrome.deps =
  {
    clock = env#clock;
    mgr = env#process_mgr;
    logger =
      Eta_observability.Logger.create ~service:"leash-test" ~clock:env#clock
        ~mono_clock:env#mono_clock
        ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
        ();
  }

(* The mock clock only moves when the test moves it, so every wait steps it until the
   lifecycle event it expects arrives; nothing here waits on real time. *)
let next_event ?(step = Eta.Duration.ms 100) ?(budget = 500) env chrome =
  let rec loop remaining =
    match Eio.Stream.take_nonblocking (Chrome.events chrome) with
    | Some event -> event
    | None when remaining <= 0 ->
        Alcotest.fail "no lifecycle event within the test's virtual budget"
    | None ->
        Eta_test.advance env#clock step;
        Eio.Fiber.yield ();
        loop (remaining - 1)
  in
  loop budget

let show_phase = function
  | `Running -> "running"
  | `Restarting -> "restarting"
  | `Gave_up -> "gave-up"
  | `Stopped -> "stopped"

let show_event = function
  | Chrome.Started generation -> Printf.sprintf "Started %d" generation
  | Chrome.Lost generation -> Printf.sprintf "Lost %d" generation
  | Chrome.Gave_up _ -> "Gave_up"
  | Chrome.Stopped -> "Stopped"

let expect_event label env chrome expected =
  match next_event env chrome with
  | event when event = expected -> ()
  | event ->
      let status = Chrome.status chrome in
      Alcotest.failf "expected %s, got %s (phase %s, failure %s)" label (show_event event)
        (show_phase status.phase)
        (Option.value ~default:"none" status.failure)

let argv_flags () =
  let argv = Chrome.argv (config ()) in
  let has flag = List.exists (fun value -> value = flag) argv in
  let prefixed prefix =
    List.exists
      (fun value ->
        String.length value >= String.length prefix
        && String.sub value 0 (String.length prefix) = prefix)
      argv
  in
  Alcotest.(check bool) "remote-debugging-pipe" true (has "--remote-debugging-pipe");
  Alcotest.(check bool) "dedicated profile" true (prefixed "--user-data-dir=");
  Alcotest.(check bool) "no-first-run" true (has "--no-first-run");
  Alcotest.(check bool) "no-default-browser-check" true (has "--no-default-browser-check");
  Alcotest.(check bool)
    "hide-crash-restore-bubble" true
    (has "--hide-crash-restore-bubble");
  Alcotest.(check bool) "class=leash" true (has "--class=leash");
  Alcotest.(check bool) "headed by default" false (has "--headless=new");
  Alcotest.(check bool) "no debugging port" false (prefixed "--remote-debugging-port");
  (* headless is an operator and gate choice: [--headless=new] and nothing else moves *)
  let headless = Chrome.argv (config ~headless:true ()) in
  let has_headless flag = List.exists (fun value -> value = flag) headless in
  Alcotest.(check bool) "headless=new when asked" true (has_headless "--headless=new");
  Alcotest.(check bool)
    "headless adds one flag" true
    (List.length headless = List.length argv + 1);
  Alcotest.(check bool)
    "debugging pipe stays" true
    (has_headless "--remote-debugging-pipe")

let pipe_launch () =
  (* launch_pipe maps the pipe pair onto the child's descriptors 3 and 4 *)
  Eta_test.run (fun env sw ->
      let fake = Eta_test.Process.make [ Block_until_signal ] in
      match
        Chrome.launch_pipe ~sw ~clock:env#clock ~mgr:(Eta_test.Process.mgr fake)
          (config ())
      with
      | Error _ -> Alcotest.fail "the pipe launch failed"
      | Ok (_child, transport) ->
          let targets =
            List.map
              (fun (target, _, _) -> target)
              (List.hd (Eta_test.Process.spawns fake)).fds
          in
          ignore transport;
          Alcotest.(check (list int)) "child descriptors" [ 0; 1; 2; 3; 4 ] targets)

let restart () =
  (* chrome-qo4q *)
  Eta_test.run (fun env sw ->
      let rig =
        {
          mgr =
            Eta_test.Process.make
              [ Eta_test.Process.Exit (`Exited 1); Block_until_signal ];
          browsers = [];
        }
      in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      (match Chrome.connection chrome with
      | Ok _ -> ()
      | Error `Browser_unavailable -> Alcotest.fail "generation 1 must be reachable");
      expect_event "Lost 1" env chrome (Chrome.Lost 1);
      Alcotest.(check int) "generation after the exit" 1 (Chrome.generation chrome);
      expect_event "Started 2" env chrome (Chrome.Started 2);
      Alcotest.(check int) "generation after the restart" 2 (Chrome.generation chrome);
      (match Chrome.connection chrome with
      | Ok _ -> ()
      | Error `Browser_unavailable -> Alcotest.fail "generation 2 must be reachable");
      let spawns = Eta_test.Process.spawns rig.mgr in
      Alcotest.(check int) "one spawn per generation" 2 (List.length spawns);
      Alcotest.(check (list string))
        "argv"
        (Chrome.argv (config ()))
        (List.hd spawns).argv)

let transport_loss () =
  (* chrome-2z2z *)
  Eta_test.run (fun env sw ->
      let rig =
        {
          mgr = Eta_test.Process.make [ Block_until_signal; Block_until_signal ];
          browsers = [];
        }
      in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      let cdp =
        match Chrome.connection chrome with
        | Ok cdp -> cdp
        | Error `Browser_unavailable -> Alcotest.fail "generation 1 must be reachable"
      in
      Fake.drop (fst (List.hd rig.browsers));
      expect_event "Lost 1" env chrome (Chrome.Lost 1);
      Alcotest.(check int)
        "the lost generation is the one recorded" 1 (Chrome.generation chrome);
      (match Chrome.connection chrome with
      | Error `Browser_unavailable -> ()
      | Ok _ -> Alcotest.fail "a lost generation must not be reachable");
      (* the handle from before the loss answers with the transport's death *)
      match Cdp.call cdp "Target.getTargets" (`Assoc []) with
      | Error (`Transport_closed _) -> ()
      | Error _ -> Alcotest.fail "expected a transport-closed error"
      | Ok _ -> Alcotest.fail "the lost transport must not answer")

let unavailable_during_restart () =
  (* chrome-6lfk *)
  Eta_test.run (fun env sw ->
      let rig =
        {
          mgr = Eta_test.Process.make [ Block_until_signal; Block_until_signal ];
          browsers = [];
        }
      in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      (match Chrome.connection chrome with
      | Ok _ -> ()
      | Error `Browser_unavailable -> Alcotest.fail "generation 1 must be reachable");
      Fake.drop (fst (List.hd rig.browsers));
      expect_event "Lost 1" env chrome (Chrome.Lost 1);
      (* while restarting, requests fail fast so the caller can retry shortly *)
      (match Chrome.connection chrome with
      | Error `Browser_unavailable -> ()
      | Ok _ -> Alcotest.fail "requests during a relaunch must fail fast");
      expect_event "Started 2" env chrome (Chrome.Started 2);
      match Chrome.connection chrome with
      | Ok _ -> ()
      | Error `Browser_unavailable -> Alcotest.fail "the retry must succeed")

let gave_up () =
  Eta_test.run (fun env sw ->
      let scripts = List.init 12 (fun _ -> Eta_test.Process.Exit (`Exited 1)) in
      let rig = { mgr = Eta_test.Process.make scripts; browsers = [] } in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      let rec drain remaining gave_up =
        if remaining = 0 then Alcotest.fail "the supervisor never gave up"
        else
          match next_event ~step:(Eta.Duration.seconds 30) ~budget:4 env chrome with
          | Chrome.Stopped -> gave_up
          | Chrome.Gave_up _ -> drain (remaining - 1) true
          | _ -> drain (remaining - 1) gave_up
      in
      Alcotest.(check bool) "gave up before the terminal event" true (drain 40 false);
      let status = Chrome.status chrome in
      Alcotest.(check int) "attempts" 11 status.generation;
      Alcotest.(check bool) "terminal phase" true (status.phase = `Stopped);
      Alcotest.(check bool)
        ("failure recorded: " ^ Option.value ~default:"none" status.failure)
        true
        (Option.is_some status.failure))

let orderly_stop () =
  (* chrome-b288 *)
  Eta_test.run (fun env sw ->
      let rig = { mgr = Eta_test.Process.make [ Block_until_signal ]; browsers = [] } in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      Chrome.stop chrome;
      expect_event "Stopped" env chrome Chrome.Stopped;
      Alcotest.(check (list int))
        "SIGTERM, no SIGKILL" [ Sys.sigterm ]
        (Eta_test.Process.signals rig.mgr);
      Alcotest.(check int) "no restart after stop" 1 (Chrome.generation chrome);
      Alcotest.(check bool) "stopped" true ((Chrome.status chrome).phase = `Stopped);
      match Chrome.connection chrome with
      | Error `Browser_unavailable -> ()
      | Ok _ -> Alcotest.fail "a stopped service has no browser to reach")

let stderr_tail () =
  (* svc-qrmc: an actual Child stderr pipe, not a synthetic ring insertion. *)
  Eta_test.run (fun env sw ->
      let memory = Eta_observability.Logger.Memory.create () in
      let logger =
        Eta_observability.Logger.create ~service:"leash-test" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Eta_observability.Logger.Memory.reporter memory)
          ()
      in
      let lines = List.init 25 (fun i -> Printf.sprintf "chrome diagnostic %02d" i) in
      let text = String.concat "\n" lines ^ "\n" ^ String.make 1300 'x' in
      let mgr =
        Eta_test.Process.make
          [
            Eta_test.Process.Output
              ( [
                  {
                    Eta_test.Process.stream = Stderr;
                    data = text;
                    after = Eta.Duration.zero;
                  };
                ],
                Eta_test.Process.Exit (`Exited 1) );
            Block_until_signal;
          ]
      in
      let rig = { mgr; browsers = [] } in
      let chrome =
        Chrome.create ~sw ~launch:(launch rig) (config ()) { (deps env) with logger }
      in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      expect_event "Lost 1" env chrome (Chrome.Lost 1);
      let records = Eta_observability.Logger.Memory.records memory in
      let lost =
        match
          List.find_opt
            (fun record -> record.Eta_observability.Logger.msg = "chrome generation lost")
            records
        with
        | Some record -> record
        | None -> Alcotest.fail "missing generation lost record"
      in
      let stderr =
        match List.assoc_opt "stderr" lost.fields with
        | Some (Eta_observability.Logger.Json (`List xs)) ->
            List.map
              (function `String s -> s | _ -> Alcotest.fail "stderr must be strings")
              xs
        | _ -> Alcotest.fail "missing stderr tail"
      in
      Alcotest.(check (list string))
        "last 19 complete and capped partial line"
        (List.filteri (fun i _ -> i >= 6) lines @ [ String.make 1024 'x' ])
        stderr)

let () =
  Alcotest.run "L2 managed Chrome"
    [
      ( "launch",
        [
          Alcotest.test_case "flags" `Quick argv_flags;
          Alcotest.test_case "pipe descriptors 3 and 4" `Quick pipe_launch;
        ] );
      ( "lifecycle",
        [
          Alcotest.test_case "stderr tail per generation" `Quick stderr_tail;
          Alcotest.test_case "restart under backoff" `Quick restart;
          Alcotest.test_case "transport loss loses the generation" `Quick transport_loss;
          Alcotest.test_case "unavailable while restarting" `Quick
            unavailable_during_restart;
          Alcotest.test_case "give up after the schedule" `Quick gave_up;
          Alcotest.test_case "orderly stop" `Quick orderly_stop;
        ] );
    ]
