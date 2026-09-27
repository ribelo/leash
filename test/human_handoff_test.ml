(* L17 — the human-facing side of a handoff (docs/issues/human-handoff/01-human-handoff.md,
   milestone 4). Stories: hand-04rb hand-phof hand-rg9h. Everything runs at the
   control-protocol seam over the fake browser, the mock clock and eta_test's fake process
   manager, and the desktop commands go through the real {!Leash.Desktop.create} and the
   real {!Eta_process.Child}: argv, exit statuses, retirement and the notification's stdout
   are the production path, with no child started. What a child prints is a script of
   {!Eta_test.Process.Output} chunks delayed on the mock clock — a notification's Done
   action and a notifier stopped before it prints are both made of one. No test runs a
   focus command, a notification or niri for real, and nothing here touches the desktop. *)

module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module Desktop = Leash.Desktop
module Logger = Eta_observability.Logger
module Tabs = Leash.Tabs

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let opt key json = field key json

let text key json =
  match get key json with
  | `String s -> s
  | other -> Alcotest.failf "%s: %s" key (Yojson.Safe.to_string other)

let fields = function
  | `Assoc fields -> fields
  | other -> Alcotest.failf "expected an object, got %s" (Yojson.Safe.to_string other)

let contains haystack needle =
  let hay = String.length haystack and width = String.length needle in
  let rec at start index =
    index = width || (haystack.[start + index] = needle.[index] && at start (index + 1))
  in
  let rec scan start = start + width <= hay && (at start 0 || scan (start + 1)) in
  width = 0 || scan 0

let owner name =
  match P.Owner.of_string name with Ok x -> x | Error e -> Alcotest.fail e

let handle text =
  match P.Handle.of_string text with Ok h -> h | Error e -> Alcotest.fail e

let handle_of json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let result = function
  | P.Success json -> json
  | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let code = function
  | P.Failure e -> P.Error_code.to_string e.code
  | P.Success _ -> Alcotest.fail "expected a failure"

let check_code label expected reply = Alcotest.(check string) label expected (code reply)

(* One request, exactly as the CLI sends it. *)
let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let listed tabs =
  match get "tabs" (result (request tabs "alice" (P.List_tabs { all = true }))) with
  | `List rows -> rows
  | other -> Alcotest.failf "tabs: %s" (Yojson.Safe.to_string other)

let find handle rows =
  let wanted = P.Handle.to_string handle in
  List.find_opt (fun row -> get "tab" row = str wanted) rows

let row tabs handle =
  match find handle (listed tabs) with
  | Some row -> row
  | None -> Alcotest.failf "tab %s is gone" (P.Handle.to_string handle)

let state tabs handle =
  match find handle (listed tabs) with Some row -> text "state" row | None -> "gone"

let owner_of tabs handle =
  match get "owner" (row tabs handle) with `String s -> Some s | _ -> None

let handle_new tabs = handle_of (result (request tabs "alice" (P.New { url = None })))
let reply = function None -> Alcotest.fail "no reply" | Some reply -> reply
let answered cell = match !cell with Some _ -> true | None -> false
let advance env seconds = Eta_test.advance env#clock (Eta.Duration.seconds seconds)

let rec until n what check =
  if check () then ()
  else if n = 0 then Alcotest.failf "the test never saw %s" what
  else (
    Eio.Fiber.yield ();
    until (n - 1) what check)

(* hand-phof: a scripted child's stdout, one chunk written [after] the spawn on the mock
   clock. A real notification's Done action reaches the service exactly this way. *)
let out ?(after = Eta.Duration.zero) data : Eta_test.Process.chunk =
  { stream = Eta_test.Process.Stdout; data; after }

let output chunks rest = Eta_test.Process.Output (chunks, rest)
let exit_ok = Eta_test.Process.Exit (`Exited 0)
let blocked = Eta_test.Process.Block_until_signal

(* Give every other fiber the scheduler several turns: a chunk the mock clock released runs
   through the child's pipe, the runner's reader, the service and its reply in that many
   steps. *)
let settle () =
  for _ = 1 to 200 do
    Eio.Fiber.yield ()
  done

let last = function
  | [] -> Alcotest.fail "no command was run"
  | commands -> List.nth commands (List.length commands - 1)

(* hand-rg9h: the warnings a reply carries, and the same list on a timeout's [detail]. *)
let warnings json =
  match opt "warnings" json with
  | None -> []
  | Some (`List xs) ->
      List.map (function `String s -> s | other -> Yojson.Safe.to_string other) xs
  | Some other -> Alcotest.failf "warnings: %s" (Yojson.Safe.to_string other)

let failure_warnings = function
  | P.Failure { detail = Some detail; _ } -> warnings detail
  | P.Failure _ | P.Success _ -> []

(* The desktop commands the fake process manager ran, in call order: Chrome's own spawn
   is first, then whatever a handoff started. The manager never executes anything, but
   Eio's spawn front-end resolves the executable before the manager is reached, so a
   command under test has to name a program that exists — [sh] is the stand-in here, and
   nothing in this file runs a focus command or a notification. *)
let commands process =
  match Eta_test.Process.spawns process with
  | [] -> Alcotest.fail "no process was spawned at all"
  | _chrome :: commands ->
      List.map (fun (spawn : Eta_test.Process.spawn) -> spawn.argv) commands

let terminations process =
  List.length
    (List.filter (fun signal -> signal = Sys.sigterm) (Eta_test.Process.signals process))

let default_focus = [ "sh"; "{tab}"; "{reason}" ]
let default_notify = [ "sh"; "{reason}" ]

(* The rig of handoff_test.ml: the fake browser behind a real Chrome service with the mock
   clock and the fake process manager, plus the desktop side of the service. [scripts] are
   the fake process manager's scripts after Chrome's own — one per desktop command, in call
   order — and the chunks they delay run on the mock clock. [real] hands the commands to
   the real process manager instead, which no test does to run a command: the one that uses
   it points at a binary that is not installed, so Eio fails before a child exists. [log]
   keeps what the service logged, which is how a notification that answered after its
   handoff had already ended would be caught. *)
let rig ?(focus = default_focus) ?(notify = default_notify) ?(scripts = [])
    ?(real = false) f =
  Eta_test.run (fun env sw ->
      let process = Eta_test.Process.make ~clock:env#clock (blocked :: scripts) in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Eta_process.Child.spawn ~sw ~clock
            ~mgr:(Eta_test.Process.mgr process)
            ~argv:(Chrome.argv config) ~grace:(Eta.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let log = Logger.Memory.create () in
      let logger =
        Logger.create ~service:"leash-human-handoff-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock ~reporter:(Logger.Memory.reporter log) ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-human-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let desktop =
        Desktop.create ~clock:env#clock
          ~mgr:(if real then env#process_mgr else Eta_test.Process.mgr process)
          { Desktop.focus_command = focus; notify_command = notify }
      in
      let tabs =
        Tabs.create ~sw ~cap:128 ~tombstone_s:3600
          { Tabs.chrome; clock = env#clock; logger; desktop }
      in
      let rec ready n =
        if n = 0 then Alcotest.fail "no Chrome"
        else if (Chrome.status chrome).phase <> `Running then (
          Eio.Fiber.yield ();
          ready (n - 1))
      in
      ready 1000;
      let fake =
        match !current with Some fake -> fake | None -> Alcotest.fail "no fake browser"
      in
      f ~env ~sw ~tabs ~fake ~process ~log)

(* hand-04rb: the handoff raises the live view — [Target.activateTarget] for this tab,
   then the configured desktop command, with the reason and the tab substituted into one
   argv element each, never through a shell. hand-rg9h: a handoff whose steps all worked
   carries no warnings at all. *)
let focus_raises_the_view () =
  rig ~focus:[ "sh"; "{tab}"; "reason={reason}"; "literal" ]
    ~notify:[ "sh"; "{reason}" ] ~scripts:[ exit_ok; blocked ]
    (fun ~env:_ ~sw ~tabs ~fake ~process ~log:_ ->
      let h = handle_new tabs in
      let reason = "solve the 'captcha' now" in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice" (P.Handoff { tab = h; reason; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      until 1000 "both desktop commands run" (fun () ->
          List.length (commands process) = 2);
      let activated =
        Fake.received fake
        |> List.filter (fun json ->
            field "method" json = Some (str "Target.activateTarget"))
      in
      Alcotest.(check int)
        "hand-04rb the live view is raised exactly once" 1 (List.length activated);
      Alcotest.(check string)
        "hand-04rb on the target this tab is" "target-1"
        (text "targetId" (get "params" (List.hd activated)));
      Alcotest.(check (list string))
        "hand-04rb the focus command gets the tab and the reason, element by element"
        [ "sh"; P.Handle.to_string h; "reason=" ^ reason; "literal" ]
        (List.nth (commands process) 0);
      Alcotest.(check (list string))
        "hand-phof and the notification gets the reason as one argument" [ "sh"; reason ]
        (List.nth (commands process) 1);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      let answer = result (reply !cell) in
      Alcotest.(check bool) "hand-04rb resumed" true (get "resumed" answer = `Bool true);
      Alcotest.(check (list string))
        "hand-rg9h a handoff whose steps all worked carries no warnings" []
        (warnings answer))

(* hand-phof: the notification prints the Done action's name on stdout when the human
   clicks it, and that alone hands the tab back — no [leash resume] anywhere in this test.
   The line is a chunk due two seconds after the spawn, so it arrives while the handoff
   waits, and the notifier is the human's resume (hand-0sja): the tab is its owner's
   again. The test below this one is the same chunk with nobody clicking. *)
let notification_done_resumes () =
  rig
    ~scripts:[ exit_ok; output [ out ~after:(Eta.Duration.seconds 2) "done\n" ] blocked ]
    (fun ~env ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "2fa code"; timeout_s = Some 3600 })));
      until 1000 "the notification run" (fun () -> List.length (commands process) = 2);
      Alcotest.(check bool)
        "hand-phof the Done action has not arrived yet" false (answered cell);
      advance env 2;
      until 1000 "the notification's Done action hand the tab back" (fun () ->
          answered cell);
      let answer = result (reply !cell) in
      Alcotest.(check bool) "hand-phof resumed" true (get "resumed" answer = `Bool true);
      Alcotest.(check string)
        "hand-phof the tab is the agent's again" "owned" (state tabs h);
      Alcotest.(check (option string))
        "hand-phof and still alice's" (Some "alice") (owner_of tabs h);
      Alcotest.(check (list string))
        "hand-phof the notification carries the agent's reason" [ "sh"; "2fa code" ]
        (last (commands process));
      Alcotest.(check (list string))
        "hand-phof a notification that worked is not a warning" [] (warnings answer))

(* hand-phof hand-04rb: a notification stopped before it prints never prints. Its chunk is
   due thirty seconds after the spawn, the human resumes the tab long before that, and the
   handoff ending stops the child — one SIGTERM and no output. The clock then passes the
   delay: the same chunk resumed the tab in the test above, so nothing happening here is
   the stopping, not a missing line. The log is the evidence the line was never read, since
   a Done action arriving after its handoff ended is reported. *)
let notifier_stopped_before_printing () =
  rig
    ~scripts:[ exit_ok; output [ out ~after:(Eta.Duration.seconds 30) "done\n" ] blocked ]
    (fun ~env ~sw ~tabs ~fake:_ ~process ~log ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the notification run" (fun () -> List.length (commands process) = 2);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check bool)
        "hand-phof the human's resume answered" true
        (get "resumed" (result (reply !cell)) = `Bool true);
      until 1000 "the notifier stopped with the handoff" (fun () ->
          terminations process = 1);
      advance env 30;
      settle ();
      Alcotest.(check int)
        "hand-phof the stopped notifier printed nothing" 0
        (List.length
           (List.filter
              (fun (record : Logger.record) -> contains record.msg "already ended")
              (Logger.Memory.records log)));
      Alcotest.(check string)
        "hand-phof and the tab is still the agent's" "owned" (state tabs h))

(* hand-rg9h: a human-facing step that fails is a warning and a log line, never a handoff
   failure — the tab still goes to the human and still comes back. *)

let focus_failure_is_a_warning () =
  rig
    ~scripts:[ Eta_test.Process.Exit (`Exited 2); blocked ]
    (fun ~env:_ ~sw ~tabs ~fake:_ ~process:_ ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      let answer = result (reply !cell) in
      Alcotest.(check bool)
        "hand-rg9h the handoff still succeeded" true
        (get "resumed" answer = `Bool true);
      Alcotest.(check (list string))
        "hand-rg9h a focus command that failed is a warning, not a failure"
        [ "focus: exited 2" ] (warnings answer))

(* hand-rg9h: a notification that fails — here one that exits non-zero; the not-installed
   binary is {!missing_binary_is_a_warning} — is a warning and a log line, never a handoff
   failure. The warning is waited for on the log, because the notification is a daemon of
   the handoff and its failure lands after the tab is already the human's. *)
let notify_failure_is_a_warning () =
  rig
    ~scripts:[ exit_ok; Eta_test.Process.Exit (`Exited 1) ]
    (fun ~env:_ ~sw ~tabs ~fake:_ ~process:_ ~log ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      until 1000 "the notification fail" (fun () ->
          List.exists
            (fun (record : Logger.record) -> contains record.msg "notify: exited 1")
            (Logger.Memory.records log));
      Alcotest.(check bool)
        "hand-rg9h a broken notification does not fail the handoff" false (answered cell);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (list string))
        "hand-rg9h and the reply says the human was never told" [ "notify: exited 1" ]
        (warnings (result (reply !cell))))

let focus_timeout_is_a_warning () =
  rig ~scripts:[ blocked; blocked ] (fun ~env ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      (* the command has to be running before its five seconds are spent, or the deadline
         the test advances past was never registered *)
      until 1000 "the focus command run" (fun () -> List.length (commands process) = 1);
      advance env 5;
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (list string))
        "hand-rg9h a command that never answers is stopped and reported"
        [ "focus: the command did not finish within five seconds" ]
        (warnings (result (reply !cell))))

let activate_failure_is_a_warning () =
  rig ~scripts:[ exit_ok; blocked ] (fun ~env:_ ~sw ~tabs ~fake ~process:_ ~log:_ ->
      Fake.on_failure fake "Target.activateTarget" (fun _ ->
          Some (-32601, "Method not found"));
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (list string))
        "hand-rg9h a raise Chrome refuses is best effort too"
        [ "activate-target: browser refused Target.activateTarget" ]
        (warnings (result (reply !cell))))

(* The real process manager, one command that is not installed: Eio resolves the executable
   before anything is spawned, and the warning names the binary the config asked for. *)
let missing_binary_is_a_warning () =
  rig ~real:true ~focus:[ "leash-focus-command-that-is-not-installed"; "{tab}" ]
    ~notify:[] (fun ~env:_ ~sw ~tabs ~fake:_ ~process:_ ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      let answer = warnings (result (reply !cell)) in
      Alcotest.(check int) "hand-rg9h one step failed" 1 (List.length answer);
      Alcotest.(check bool)
        "hand-rg9h and the warning names the binary that is missing" true
        (contains (List.hd answer) "leash-focus-command-that-is-not-installed"))

(* hand-rg9h: an unanswered handoff is exactly when a broken notification matters, so the
   [timeout] error carries the same warnings in its detail. *)
let timeout_carries_the_warnings () =
  rig
    ~scripts:[ Eta_test.Process.Exit (`Exited 1); blocked ]
    (fun ~env ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 30 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      (* the human-facing steps have their own five seconds; let them finish — the
         notification running means the focus step is done — before the deadline takes the
         clock away from them *)
      until 1000 "the failed focus command and the notification be recorded" (fun () ->
          List.length (commands process) = 2);
      advance env 30;
      until 1000 "the deadline end the handoff" (fun () -> answered cell);
      check_code "hand-rg9h the handoff still ends as the deadline says" "timeout"
        (reply !cell);
      Alcotest.(check (list string))
        "hand-rg9h with what the human-facing side could not do" [ "focus: exited 1" ]
        (failure_warnings (reply !cell)))

(* hand-04rb hand-phof: the notification child is stopped when the handoff ends, however
   it ends — here a resume and then the deadline — so a handoff leaves no notifier behind
   for the rest of the service's life. *)
let the_notifier_is_stopped () =
  rig ~scripts:[ exit_ok; blocked; exit_ok; blocked ]
    (fun ~env ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      until 1000 "its notification run" (fun () -> List.length (commands process) = 2);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      until 1000 "the notifier stopped with the handoff" (fun () ->
          terminations process = 1);
      let second = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = second; reason = "captcha"; timeout_s = Some 30 })));
      until 1000 "the second handoff reach the human" (fun () ->
          state tabs second = "with_human");
      until 1000 "its notification run" (fun () ->
          terminations process = 1 && List.length (commands process) = 4);
      advance env 30;
      until 1000 "the deadline end the second handoff" (fun () -> answered cell);
      check_code "hand-lmd5 the second handoff timed out" "timeout" (reply !cell);
      until 1000 "and its notifier stopped too" (fun () -> terminations process = 2))

(* hand-04rb: the focus command's [{window_id}] is the managed Chrome's niri window, by
   app id; a listing without one skips the command rather than running it on nothing. *)
let focus_finds_the_chrome_window () =
  let listing =
    "[{\"id\":2,\"title\":\"Mail - Google Chrome\",\"app_id\":\"google-chrome\"},"
    ^ "{\"id\":7,\"title\":\"Sign in - Chrome\",\"app_id\":\"leash\"}]"
  in
  (* hand-04rb: the listing is niri's own `msg --json windows` output, a chunk the child
     prints before it exits zero; the focus command that follows gets the window id. *)
  rig
    ~scripts:[ output [ out (listing ^ "\n") ] exit_ok; exit_ok; blocked ]
    ~focus:[ "niri"; "msg"; "action"; "focus-window"; "--id"; "{window_id}" ]
    (fun ~env:_ ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      until 1000 "the focus command run" (fun () -> List.length (commands process) = 2);
      Alcotest.(check (list string))
        "hand-04rb the window is looked for with niri's own list"
        [ "niri"; "msg"; "--json"; "windows" ]
        (List.hd (commands process));
      Alcotest.(check (list string))
        "hand-04rb and the focus command gets the Chrome window's id"
        [ "niri"; "msg"; "action"; "focus-window"; "--id"; "7" ]
        (List.nth (commands process) 1);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (list string))
        "hand-rg9h finding the window is not a warning" []
        (warnings (result (reply !cell))));
  let without_chrome = "[{\"id\":2,\"app_id\":\"google-chrome\"}]" in
  rig
    ~scripts:[ output [ out (without_chrome ^ "\n") ] exit_ok; exit_ok; blocked ]
    ~focus:[ "niri"; "msg"; "action"; "focus-window"; "--id"; "{window_id}" ]
    (fun ~env:_ ~sw ~tabs ~fake:_ ~process ~log:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      (* the lookup ran and the notification that follows every focus step started: the
         focus command between them is the one that must not run *)
      until 1000 "the notification run" (fun () ->
          List.exists (fun argv -> List.mem "sh" argv) (commands process));
      Alcotest.(check int)
        "hand-04rb a window list without the managed Chrome skips the focus command" 0
        (List.length
           (List.filter (fun argv -> List.mem "focus-window" argv) (commands process)));
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (list string))
        "hand-rg9h and skipping it is not a warning either" []
        (warnings (result (reply !cell))))

(* hand-rg9h: [warnings] is [key?] on the wire. *)
let reply_shapes () =
  let clean =
    P.yojson_of_handoff_result
      P.
        {
          resumed = true;
          url = "https://example.com";
          title = "Sign in";
          warnings = None;
        }
  in
  Alcotest.(check bool)
    "hand-rg9h a handoff without warnings omits the key" false
    (List.mem_assoc "warnings" (fields clean));
  let warned =
    P.yojson_of_handoff_result
      P.
        {
          resumed = true;
          url = "https://example.com";
          title = "Sign in";
          warnings = Some [ "notify: exited 1" ];
        }
  in
  Alcotest.(check (list string))
    "hand-rg9h and carries them when there are any" [ "notify: exited 1" ]
    (warnings warned)

let test name case = Alcotest.test_case name `Quick case

let () =
  Alcotest.run "L17 human-facing handoff"
    [
      ( "focus",
        [
          test "hand-04rb hand-rg9h" focus_raises_the_view;
          test "hand-04rb hand-rg9h" focus_finds_the_chrome_window;
        ] );
      ( "notification",
        [
          test "hand-phof" notification_done_resumes;
          test "hand-phof hand-04rb" notifier_stopped_before_printing;
        ] );
      ( "warnings",
        [
          test "hand-rg9h" focus_failure_is_a_warning;
          test "hand-rg9h" notify_failure_is_a_warning;
          test "hand-rg9h" focus_timeout_is_a_warning;
          test "hand-rg9h" activate_failure_is_a_warning;
          test "hand-rg9h" missing_binary_is_a_warning;
          test "hand-rg9h hand-lmd5" timeout_carries_the_warnings;
          test "hand-rg9h" reply_shapes;
        ] );
      ("cleanup", [ test "hand-04rb hand-phof hand-lmd5" the_notifier_is_stopped ]);
    ]
