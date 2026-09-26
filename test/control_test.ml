(* L3: chrome-qnul chrome-1yn9 chrome-akz4 chrome-2n8n chrome-hjw9
   chrome-fuao chrome-38a4 chrome-d4mz chrome-2z2z chrome-6lfk. *)
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

let rig f =
  Eta_test.run (fun env sw ->
      let mgr = Eta_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Eta_process.Child.spawn ~sw ~clock ~mgr:(Eta_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Eta.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Eta_observability.Logger.create ~service:"leash-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
          { Leash.Tabs.chrome; clock = env#clock; logger }
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

let lifecycle () =
  rig (fun _ _ _ tabs fake ->
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
      check_code "owner" "not-owner" (request tabs "bob" (P.Close { tab = h }));
      ignore (result (request tabs "alice" (P.Close { tab = h })));
      ignore (result (request tabs "alice" (P.Close { tab = h })));
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
      let reply =
        result
          (request tabs "alice" (P.Nav { tab = h; url = "https://example.com/next" }))
      in
      Alcotest.(check bool)
        "chrome-1yn9 complete" true
        (get "url" reply = str "https://example.com/next"))

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

let socket () =
  with_runtime (fun runtime ->
      rig (fun env sw _ tabs _ ->
          let make () =
            Leash.Control.create ~sw ~runtime_dir:runtime
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Eta_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
                    ();
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
            Leash.Control.create ~sw ~runtime_dir:runtime
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Eta_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
                    ();
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
            Leash.Control.create ~sw ~runtime_dir:runtime
              {
                Leash.Control.tabs;
                status_query = (fun () -> []);
                fs = env#fs;
                net = env#net;
                clock = env#clock;
                logger =
                  Eta_observability.Logger.create ~service:"socket-test" ~clock:env#clock
                    ~mono_clock:env#mono_clock
                    ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
                    ();
              }
          in
          let verdict =
            match result with
            | Ok _ -> Alcotest.fail "chrome-fwnu accepted unsafe socket directory"
            | Error _ -> ()
          in
          Unix.chmod dir 0o700;
          verdict))

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
      let before = Fake.received (fake ()) |> List.length in
      Leash.Tabs.stop tabs;
      let closed =
        Fake.received (fake ())
        |> List.filteri (fun i _ -> i >= before)
        |> List.filter (fun x -> field "method" x = Some (str "Target.closeTarget"))
      in
      Alcotest.(check int) "agent only closed, human retained" 1 (List.length closed);
      ignore agent)

let () =
  Alcotest.run "L3 control protocol"
    [
      ( "lifecycle",
        [
          Alcotest.test_case "chrome-qnul hjw9 fuao 2n8n" `Quick lifecycle;
          Alcotest.test_case "chrome-akz4 d4mz" `Quick safety;
          Alcotest.test_case "chrome-1yn9" `Quick nav;
          Alcotest.test_case "chrome-38a4" `Quick malformed;
          Alcotest.test_case "chrome-2z2z 6lfk" `Quick lost;
          Alcotest.test_case "chrome-fwnu socket" `Quick socket;
          Alcotest.test_case "human-origin shutdown" `Quick human;
        ] );
    ]
