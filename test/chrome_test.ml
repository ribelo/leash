(* Managed Chrome over the fake process manager and the fake browser. Stories:
   chrome-qo4q (restart under backoff), chrome-2z2z (generation lost), chrome-6lfk
   (browser-unavailable), chrome-b288 (orderly stop). chrome-p2n4, chrome-9ex7 and
   chrome-2y3t are live-only: scripts/live-acceptance launches real Chrome. *)

module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module Cdp = Leash.Cdp

type rig = { mgr : Ox_test.Process.t; mutable browsers : (Fake.t * Fake.client) list }

let launch rig ~sw ~clock ~mgr:_ config =
  let fake, client = Fake.create ~sw () in
  rig.browsers <- (fake, client) :: rig.browsers;
  match
    Ox_process.Child.spawn ~sw ~clock ~mgr:(Ox_test.Process.mgr rig.mgr)
      ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~stderr:Pipe ~fds:[] ()
  with
  | Error error -> Error error
  | Ok child ->
      assert (Option.is_some (Ox_process.Child.stderr child));
      let transport : Cdp.transport = { read = client.read; write = client.write } in
      Ok (child, transport)

let config ?(headless = false) ?window_size () =
  Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-profile" ~workspace:"dev"
    ~headless ?window_size ()

let deps env : _ Chrome.deps =
  {
    clock = env#clock;
    mgr = env#process_mgr;
    logger =
      Ox_observability.Logger.create ~service:"leash-test" ~clock:env#clock
        ~mono_clock:env#mono_clock
        ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
        ();
  }

(* The mock clock only moves when the test moves it, so every wait steps it until the
   lifecycle event it expects arrives; nothing here waits on real time. *)
let next_event ?(step = Ox.Duration.ms 100) ?(budget = 500) env chrome =
  let rec loop remaining =
    match Eio.Stream.take_nonblocking (Chrome.events chrome) with
    | Some event -> event
    | None when remaining <= 0 ->
        Alcotest.fail "no lifecycle event within the test's virtual budget"
    | None ->
        Ox_test.advance env#clock step;
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
  (* chrome-p2n4, L34: match a usable desktop viewport in headless mode without
     changing the flags of the headed browser or adding a debugging port. *)
  let headless = Chrome.argv (config ~headless:true ()) in
  let has_headless flag = List.exists (fun value -> value = flag) headless in
  Alcotest.(check bool) "headless=new when asked" true (has_headless "--headless=new");
  Alcotest.(check bool) "headed has no window-size flag" false (prefixed "--window-size=");
  Alcotest.(check bool)
    "headless desktop viewport" true
    (has_headless "--window-size=1366,900");
  Alcotest.(check bool)
    "headless adds only size and mode" true
    (List.length headless = List.length argv + 2);
  let custom = Chrome.argv (config ~headless:true ~window_size:"1440,960" ()) in
  Alcotest.(check bool)
    "headless respects configured viewport" true
    (List.mem "--window-size=1440,960" custom);
  let headed_custom = Chrome.argv (config ~window_size:"1440,960" ()) in
  Alcotest.(check bool)
    "headed ignores configured viewport" false
    (List.mem "--window-size=1440,960" headed_custom);
  Alcotest.(check bool)
    "debugging pipe stays" true
    (has_headless "--remote-debugging-pipe")

let pipe_launch () =
  (* launch_pipe maps the pipe pair onto the child's descriptors 3 and 4 *)
  Ox_test.run (fun env sw ->
      let fake = Ox_test.Process.make [ Block_until_signal ] in
      match
        Chrome.launch_pipe ~sw ~clock:env#clock ~mgr:(Ox_test.Process.mgr fake)
          (config ())
      with
      | Error _ -> Alcotest.fail "the pipe launch failed"
      | Ok (_child, transport) ->
          let targets =
            List.map
              (fun (target, _, _) -> target)
              (List.hd (Ox_test.Process.spawns fake)).fds
          in
          ignore transport;
          Alcotest.(check (list int)) "child descriptors" [ 0; 1; 2; 3; 4 ] targets)

let restart () =
  (* chrome-qo4q *)
  Ox_test.run (fun env sw ->
      let rig =
        {
          mgr =
            Ox_test.Process.make [ Ox_test.Process.Exit (`Exited 1); Block_until_signal ];
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
      let spawns = Ox_test.Process.spawns rig.mgr in
      Alcotest.(check int) "one spawn per generation" 2 (List.length spawns);
      Alcotest.(check (list string))
        "argv"
        (Chrome.argv (config ()))
        (List.hd spawns).argv)

let transport_loss () =
  (* chrome-2z2z *)
  Ox_test.run (fun env sw ->
      let rig =
        {
          mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ];
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
  Ox_test.run (fun env sw ->
      let rig =
        {
          mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ];
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
  Ox_test.run (fun env sw ->
      let scripts = List.init 12 (fun _ -> Ox_test.Process.Exit (`Exited 1)) in
      let rig = { mgr = Ox_test.Process.make scripts; browsers = [] } in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      let rec drain remaining gave_up =
        if remaining = 0 then Alcotest.fail "the supervisor never gave up"
        else
          (* nactor-d120: a generation now passes through a supervisor's scopes before the
             next one starts, so an event takes a few more scheduler turns than it did *)
          match next_event ~step:(Ox.Duration.seconds 30) ~budget:12 env chrome with
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

(* nactor-d120: a launch that fails — a typed spawn error or a defect — is not a generation
   that exited, so the relaunch loop does not retry it: the service gives up with that
   cause at once. *)
let launch_failure_is_not_retried () =
  let run_with launch check =
    Ox_test.run (fun env sw ->
        let calls = ref 0 in
        let launch ~sw ~clock ~mgr config =
          incr calls;
          launch ~sw ~clock ~mgr config
        in
        let chrome = Chrome.create ~sw ~launch (config ()) (deps env) in
        let rec until_stopped seen budget =
          if budget = 0 then Alcotest.fail "the service never stopped"
          else
            match next_event ~step:(Ox.Duration.seconds 30) ~budget:12 env chrome with
            | Chrome.Stopped -> List.rev seen
            | event -> until_stopped (event :: seen) (budget - 1)
        in
        let events = until_stopped [] 10 in
        Alcotest.(check int) "launched exactly once" 1 !calls;
        check events;
        Alcotest.(check bool) "terminal" true ((Chrome.status chrome).phase = `Stopped))
  in
  run_with
    (fun ~sw:_ ~clock:_ ~mgr:_ _ -> Error (`Invalid_fd 3))
    (function
      | [ Chrome.Gave_up (Ox.Cause.Fail (`Spawn (`Invalid_fd 3))) ] -> ()
      | _ -> Alcotest.fail "expected Gave_up with the spawn error, then Stopped");
  let boom = Failure "launch defect" in
  run_with
    (fun ~sw:_ ~clock:_ ~mgr:_ _ -> raise boom)
    (function
      | [ Chrome.Gave_up (Ox.Cause.Die (ex, _)) ] ->
          Alcotest.(check bool) "the original exception" true (ex == boom)
      | _ -> Alcotest.fail "expected Gave_up with the defect, then Stopped")

let orderly_stop () =
  (* chrome-b288 *)
  Ox_test.run (fun env sw ->
      let rig = { mgr = Ox_test.Process.make [ Block_until_signal ]; browsers = [] } in
      let chrome = Chrome.create ~sw ~launch:(launch rig) (config ()) (deps env) in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      Chrome.stop chrome;
      expect_event "Stopped" env chrome Chrome.Stopped;
      Alcotest.(check (list int))
        "SIGTERM, no SIGKILL" [ Sys.sigterm ]
        (Ox_test.Process.signals rig.mgr);
      Alcotest.(check int) "no restart after stop" 1 (Chrome.generation chrome);
      Alcotest.(check bool) "stopped" true ((Chrome.status chrome).phase = `Stopped);
      match Chrome.connection chrome with
      | Error `Browser_unavailable -> ()
      | Ok _ -> Alcotest.fail "a stopped service has no browser to reach")

let stderr_tail () =
  (* svc-qrmc: an actual Child stderr pipe, not a synthetic ring insertion. *)
  Ox_test.run (fun env sw ->
      let memory = Ox_observability.Logger.Memory.create () in
      let logger =
        Ox_observability.Logger.create ~service:"leash-test" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Memory.reporter memory)
          ()
      in
      let lines = List.init 25 (fun i -> Printf.sprintf "chrome diagnostic %02d" i) in
      let text = String.concat "\n" lines ^ "\n" ^ String.make 1300 'x' in
      let mgr =
        Ox_test.Process.make
          [
            Ox_test.Process.Output
              ( [
                  {
                    Ox_test.Process.stream = Stderr;
                    data = text;
                    after = Ox.Duration.zero;
                  };
                ],
                Ox_test.Process.Exit (`Exited 1) );
            Block_until_signal;
          ]
      in
      let rig = { mgr; browsers = [] } in
      let chrome =
        Chrome.create ~sw ~launch:(launch rig) (config ()) { (deps env) with logger }
      in
      expect_event "Started 1" env chrome (Chrome.Started 1);
      expect_event "Lost 1" env chrome (Chrome.Lost 1);
      let records = Ox_observability.Logger.Memory.records memory in
      let lost =
        match
          List.find_opt
            (fun record -> record.Ox_observability.Logger.msg = "chrome generation lost")
            records
        with
        | Some record -> record
        | None -> Alcotest.fail "missing generation lost record"
      in
      let stderr =
        match List.assoc_opt "stderr" lost.fields with
        | Some (Ox_observability.Logger.Json (`List xs)) ->
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
          Alcotest.test_case "nactor-d120 a failed launch is not retried" `Quick
            launch_failure_is_not_retried;
          Alcotest.test_case "orderly stop" `Quick orderly_stop;
        ] );
    ]
