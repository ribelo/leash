module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome
module Tabs = Leash.Tabs
module Expiry = Leash.Expiry

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

let disposition = function
  | P.Failure { detail = Some (`Assoc fields); _ } -> (
      match List.assoc_opt "disposition" fields with
      | Some (`String disposition) -> disposition
      | _ -> Alcotest.fail "the tab-gone detail carries no disposition")
  | P.Failure _ -> Alcotest.fail "tab-gone without a disposition"
  | P.Success _ -> Alcotest.fail "expected a failure"

let request tabs _client command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let advance env seconds = Ox_test.advance env#clock (Ox.Duration.seconds seconds)

let rec until n what check =
  if n = 0 then Alcotest.fail what
  else if check () then ()
  else (
    Eio.Fiber.yield ();
    until (n - 1) what check)

let fresh tabs =
  handle_of (result (request tabs "a" (P.New { url = None; label = None })))

let held tabs =
  match get "tabs" (result (request tabs "b" P.List_tabs)) with
  | `List xs -> List.exists (fun x -> field "with_human" x = Some (`Bool true)) xs
  | _ -> assert false

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(idle = 30) f =
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
        Ox_observability.Logger.create ~service:"leash-handoff-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch:(launch ~caps)
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:false ())
          {
            Chrome.clock = env#clock;
            mono_clock = (env#mono_clock :> Eio.Time.Mono.ty Eio.Resource.t);
            mgr = env#process_mgr;
            logger;
            caps :> Leash.Chrome.caps;
          }
      in
      let idle = Ox.Duration.seconds idle in
      let tabs =
        Tabs.create ~sw ~cap:128 ~tombstone_s:3600 ~idle
          {
            Tabs.chrome;
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
      let fake =
        match !current with Some fake -> fake | None -> Alcotest.fail "no fake browser"
      in
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("value", str "") ]) ]);
      let expiry =
        Expiry.create ~sw ~interval:(Ox.Duration.hours 1) ~idle ~clock:env#mono_clock
          ~logger tabs
      in
      f ~env ~sw ~tabs ~expiry ~fake)

let resumed
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake:_ ->
      let h = fresh tabs in
      let answer = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          answer :=
            Some
              (request tabs "a"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "handoff entered" (fun () -> held tabs);
      Alcotest.(check bool) "handoff blocks" true (!answer = None);
      check_code "shared handle is still human-gated" "with-human"
        (request tabs "b" (P.Text { tab = h; index = None; max_chars = None }));
      ignore (result (request tabs "b" (P.Resume { tab = h })));
      until 1000 "handoff answered" (fun () -> !answer <> None);
      ignore (result (Option.get !answer));
      Alcotest.(check bool) "resume restores capability use" false (held tabs))

let timeout
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env ~sw ~tabs ~expiry:_ ~fake:_ ->
      let h = fresh tabs in
      let answer = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          answer :=
            Some
              (request tabs "a"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 5 })));
      until 1000 "handoff entered" (fun () -> held tabs);
      advance env 5;
      until 1000 "timeout answered" (fun () -> !answer <> None);
      check_code "deadline replies timeout" "timeout" (Option.get !answer);
      Alcotest.(check bool) "deadline restores capability" false (held tabs);
      ignore
        (result (request tabs "b" (P.Text { tab = h; index = None; max_chars = None }))))

let cancelled
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw:_ ~tabs ~expiry:_ ~fake:_ ->
      let h = fresh tabs in
      Eio.Fiber.first
        (fun () ->
          ignore
            (request tabs "a"
               (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })))
        (fun () -> until 1000 "handoff entered" (fun () -> held tabs));
      Alcotest.(check bool) "peer disconnect clears handoff" false (held tabs);
      check_code "nothing left to resume" "no-handoff"
        (request tabs "b" (P.Resume { tab = h })))

let browser_loss
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake ->
      let h = fresh tabs in
      let answer = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          answer :=
            Some
              (request tabs "a"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "handoff entered" (fun () -> held tabs);
      Fake.drop fake;
      until 1000 "browser loss answered" (fun () -> !answer <> None);
      check_code "browser loss ends wait" "tab-gone" (Option.get !answer))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L49 capability handoff"
    [
      ( "handoff",
        List.map
          (fun (n, f) -> Alcotest.test_case n `Quick f)
          [
            ("hand-lz3p resume by shared capability", resumed ~caps);
            ("hand-lmd5 timeout restores", timeout ~caps);
            ("hand-szz7 disconnect restores", cancelled ~caps);
            ("hand-yytf browser loss ends", browser_loss ~caps);
          ] );
    ]
