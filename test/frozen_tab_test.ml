module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj fields = `Assoc fields
let str s = `String s

let get name = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt name fields)
  | _ -> `Null

let ok = function Ok value -> value | Error why -> Alcotest.fail why

let result = function
  | P.Success value -> value
  | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let failure = function
  | P.Failure e -> e
  | P.Success _ -> Alcotest.fail "expected failure"

let request tabs command =
  let wire = Yojson.Safe.to_string (P.encode_request { command }) in
  ok (P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)))

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch
          ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >)
          ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~caps ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Ox_observability.Logger.create ~service:"leash-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch:(launch ~caps)
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          {
            Chrome.clock = env#clock;
            mgr = env#process_mgr;
            logger;
            caps :> Leash.Chrome.caps;
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
            caps :> Leash.Tabs.caps;
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
      f env sw chrome tabs fake)

let script_sessions fake =
  let created = ref 0 in
  Fake.on_method fake "Target.createTarget" (fun _ ->
      incr created;
      obj [ ("targetId", str ("field-target-" ^ string_of_int !created)) ]);
  Fake.on_method fake "Target.attachToTarget" (fun request ->
      let target = get "targetId" (get "params" request) in
      obj
        [
          ( "sessionId",
            str
              (if target = str "field-target-1" then "field-session-1"
               else "field-session-2") );
        ]);
  Fake.on_method fake "Runtime.evaluate" (fun _ ->
      obj [ ("result", obj [ ("objectId", str "global") ]) ]);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      obj [ ("result", obj [ ("value", `Int 42) ]) ])

let new_tab tabs =
  let reply = result (request tabs (P.New { url = None; label = None })) in
  let info = ok (P.tab_info_of_yojson reply) in
  Alcotest.(check bool) "field-m5jw blank new is loaded" true (info.loaded = Some true);
  info.tab

let eval tab =
  P.Eval { tab; expression = "1 + 1"; argument = None; index = None; snapshot = None }

let wait_until label pred =
  let rec loop n =
    if pred () then ()
    else if n = 0 then Alcotest.fail label
    else (
      Eio.Fiber.yield ();
      loop (n - 1))
  in
  loop 2000

let advance_until clock label cell =
  let rec loop n =
    match !cell with
    | Some value -> value
    | None ->
        if n = 0 then Alcotest.fail label;
        Ox_test.advance clock (Ox.Duration.seconds 1);
        for _ = 1 to 30 do
          Eio.Fiber.yield ()
        done;
        loop (n - 1)
  in
  loop 45

let seen fake session method_ =
  List.exists
    (fun request ->
      get "sessionId" request = str session && get "method" request = str method_)
    (Fake.received fake)

(* field-cde7 / field-zr9n: one renderer is frozen, not the CDP transport.
   The other tab answers before the failing tab's clock reaches its deadline;
   a screenshot still works after the diagnosis, and debug is not cleared. *)
let frozen_renderer
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (rig ~caps) (fun env sw _ tabs fake ->
      let fake = fake () in
      script_sessions fake;
      let frozen = new_tab tabs and other = new_tab tabs in
      Fake.emit ~session:"field-session-1" fake ~method_:"Runtime.consoleAPICalled"
        ~params:
          (obj
             [
               ("type", str "warning");
               ("timestamp", `Float 1.);
               ( "args",
                 `List
                   [
                     obj
                       [
                         ("type", str "string");
                         ("value", str "Turnstile challenge did not finish");
                       ];
                   ] );
             ]);
      wait_until "field-cde7 debug event not collected" (fun () ->
          get "entries"
            (result (request tabs (P.Debug { tab = frozen; limit = None; clear = None })))
          <> `List []);
      for n = 0 to 24 do
        Fake.emit ~session:"field-session-1" fake ~method_:"Runtime.consoleAPICalled"
          ~params:
            (obj
               [
                 ("type", str "warning");
                 ("timestamp", `Float 1.);
                 ( "args",
                   `List
                     [
                       obj
                         [
                           ("type", str "string");
                           ("value", str ("challenge-log-" ^ string_of_int n));
                         ];
                     ] );
               ])
      done;
      wait_until "field-cde7 ring tail not collected" (fun () ->
          match
            get "entries"
              (result
                 (request tabs (P.Debug { tab = frozen; limit = None; clear = None })))
          with
          | `List entries -> List.length entries = 26
          | _ -> false);
      Fake.stop_evaluating fake ~session:"field-session-1";
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () -> cell := Some (request tabs (eval frozen)));
      wait_until "field-zr9n evaluate not dispatched" (fun () ->
          seen fake "field-session-1" "Runtime.evaluate");
      Alcotest.(check bool)
        "field-zr9n other tab unaffected before deadline" true
        (get "value" (result (request tabs (eval other))) = `Int 42);
      let diagnosis =
        failure (advance_until env#clock "field-cde7 deadline did not settle" cell)
      in
      Alcotest.(check string)
        "field-cde7 diagnosis" "renderer-unresponsive"
        (P.Error_code.to_string diagnosis.code);
      Alcotest.(check string)
        "field-cde7 recovery hint"
        "the page's renderer is not answering; a bot-detection challenge or a hung \
         script is likely; shot may still work; close the tab or hand off"
        diagnosis.hint;
      let detail = Option.get diagnosis.detail in
      Alcotest.(check bool)
        "field-cde7 tab handle in diagnosis" true
        (get "tab" detail = P.Handle.yojson_of_t frozen);
      let debug =
        result (request tabs (P.Debug { tab = frozen; limit = None; clear = None }))
      in
      let entries =
        match get "entries" debug with `List entries -> entries | _ -> assert false
      in
      Alcotest.(check int) "field-cde7 ring not cleared" 26 (List.length entries);
      Alcotest.(check bool)
        "field-cde7 last 20 entries folded in" true
        (get "entries" detail = `List (List.filteri (fun i _ -> i < 20) entries));
      let path =
        (Ox_caps.Cap_stdlib.Filename.temp_file ~caps) "leash-field-zr9n-" ".png"
      in
      Fun.protect
        ~finally:(fun () -> (Ox_caps.Cap_sys.remove ~caps) path)
        (fun () ->
          let shot =
            result (request tabs (P.Shot { tab = frozen; path; full_page = None }))
          in
          Alcotest.(check bool)
            "field-zr9n working screenshot" true
            (get "bytes" shot = `Int 8);
          Alcotest.(check int)
            "field-zr9n screenshot file written" 8 (Unix.stat path).Unix.st_size);
      Fake.withhold fake "Page.navigate" (fun request ->
          get "sessionId" request = str "field-session-1");
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some (request tabs (P.Nav { tab = frozen; url = "https://example.com/" })));
      wait_until "field-cde7 navigate not dispatched" (fun () ->
          seen fake "field-session-1" "Page.navigate");
      let e = failure (advance_until env#clock "field-cde7 navigate deadline" cell) in
      Alcotest.(check string)
        "field-cde7 session navigate is not a load timeout" "renderer-unresponsive"
        (P.Error_code.to_string e.code))

(* field-cde7: a browser-level call has no page renderer to diagnose. *)
let browser_timeout
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  (rig ~caps) (fun env sw _ tabs fake ->
      let creates () =
        List.fold_left
          (fun n r -> if get "method" r = str "Target.createTarget" then n + 1 else n)
          0
          (Fake.received (fake ()))
      in
      let before = creates () in
      Fake.withhold (fake ()) "Target.createTarget" (fun _ -> true);
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell := Some (request tabs (P.New { url = None; label = None })));
      wait_until "field-cde7 create not dispatched" (fun () -> creates () > before);
      let e = failure (advance_until env#clock "field-cde7 browser deadline" cell) in
      Alcotest.(check string)
        "field-cde7 browser remains timeout" "timeout"
        (P.Error_code.to_string e.code))

(* field-m5jw: the in-flight new target is visible in the ledger before the
   load waiter finishes, and the successful timeout reply refreshes metadata. *)
let load_timeout_retains_handle
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  (rig ~caps) (fun env sw _ tabs fake ->
      let fake = fake () in
      script_sessions fake;
      Fake.on_method fake "Target.getTargetInfo" (fun _ ->
          obj
            [
              ( "targetInfo",
                obj
                  [
                    ("targetId", str "field-target-1");
                    ("type", str "page");
                    ("url", str "https://example.com/current");
                    ("title", str "Challenge");
                  ] );
            ]);
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs
                 (P.New { url = Some "https://example.com/requested"; label = None })));
      wait_until "field-m5jw navigate not dispatched" (fun () ->
          seen fake "field-session-1" "Page.navigate");
      let listed = result (request tabs P.List_tabs) in
      let registered =
        match get "tabs" listed with
        | `List [ tab ] -> tab
        | _ -> Alcotest.fail "field-m5jw target absent while loading"
      in
      Alcotest.(check bool)
        "hand-x3hi field-m5jw list omits handle and loaded" true
        (get "tab" registered = `Null && get "loaded" registered = `Null);
      let created = result (advance_until env#clock "field-m5jw load deadline" cell) in
      let handle = (ok (P.tab_info_of_yojson created)).tab in
      Alcotest.(check bool)
        "field-m5jw unfinished load is successful" true
        (get "loaded" created = `Bool false);
      Alcotest.(check bool)
        "field-m5jw pre-wait handle retained" true
        (get "tab" created = P.Handle.yojson_of_t handle);
      Alcotest.(check bool)
        "field-m5jw current committed URL" true
        (get "url" created = str "https://example.com/current");
      Alcotest.(check bool)
        "field-m5jw current title" true
        (get "title" created = str "Challenge");
      Alcotest.(check bool)
        "field-m5jw close still works" true
        (get "closed" (result (request tabs (P.Close { tab = handle }))) = `Bool true))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "frozen-tab"
    [
      ( "field hardening",
        [
          Alcotest.test_case "field-cde7 field-zr9n session freeze" `Quick
            (frozen_renderer ~caps);
          Alcotest.test_case "field-cde7 browser timeout" `Quick (browser_timeout ~caps);
          Alcotest.test_case "field-m5jw registered load timeout" `Quick
            (load_timeout_retains_handle ~caps);
        ] );
    ]
