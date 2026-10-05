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

let text key json =
  match get key json with
  | `String s -> s
  | other -> Alcotest.failf "%s: %s" key (Yojson.Safe.to_string other)

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

let request tabs _client command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let advance env seconds = Ox_test.advance env#clock (Ox.Duration.seconds seconds)

let rows tabs =
  match get "tabs" (result (request tabs "any" P.List_tabs)) with
  | `List xs -> xs
  | _ -> assert false

let fresh tabs =
  handle_of (result (request tabs "a" (P.New { url = None; label = None })))

let use tabs h = request tabs "b" (P.Text { tab = h; index = None; max_chars = None })

let held tabs =
  List.exists (fun row -> field "with_human" row = Some (`Bool true)) (rows tabs)

let settle () =
  for _ = 1 to 100 do
    Eio.Fiber.yield ()
  done

let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) ?(idle = 30) ?(interval = Expiry.interval) f =
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
      let logs = Ox_observability.Logger.Memory.create () in
      let logger =
        Ox_observability.Logger.create ~service:"leash-expiry-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Memory.reporter logs)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch:(launch ~caps)
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
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
      let expiry = Expiry.create ~sw ~interval ~idle ~clock:env#mono_clock ~logger tabs in
      f ~env ~tabs ~expiry ~fake)

(* ---------- The policy, pure ---------- *)

(* L49 hand-0ibq hand-ihcg: the pure policy has exactly one closing stage. *)
let policy () =
  let h = match P.Handle.of_string "t_test" with Ok h -> h | Error e -> failwith e in
  List.iter
    (fun (origin, with_human, age, expected) ->
      let origin =
        match P.Origin.of_string origin with Ok o -> o | Error e -> failwith e
      in
      Alcotest.(check bool)
        "human safety and boundary" expected
        (Expiry.decide ~idle:(Ox.Duration.seconds 30)
           { Tabs.handle = h; origin; with_human; idle_for_s = age }
        = Tabs.Close_idle))
    [
      ("human", false, 1e9, false);
      ("human", true, 1e9, false);
      ("agent", true, 1e9, false);
      ("agent", false, 29.9, false);
      ("agent", false, 30., true);
    ]

let boundary
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env ~tabs ~expiry ~fake:_ ->
      let h = fresh tabs in
      advance env 29;
      ignore (Expiry.sweep expiry);
      ignore (result (use tabs h));
      advance env 29;
      ignore (Expiry.sweep expiry);
      Alcotest.(check int) "action resets idle" 1 (List.length (rows tabs));
      advance env 1;
      ignore (Expiry.sweep expiry);
      let reply = use tabs h in
      Alcotest.(check string) "hand-0ibq no intermediate stage" "tab-gone" (code reply);
      match reply with
      | P.Failure { detail = Some (`Assoc f); hint; _ } ->
          Alcotest.(check string)
            "idle disposition" "closed_by_idle"
            (match List.assoc "disposition" f with `String s -> s | _ -> "");
          Alcotest.(check string)
            "hand-s4cq late use recovery" "open a new tab with `leash new`" hint
      | _ -> Alcotest.fail "idle detail")

let human_safety
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env ~tabs ~expiry ~fake ->
      Fake.emit fake ~method_:"Target.targetCreated"
        ~params:
          (obj
             [
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "human-page");
                     ("type", str "page");
                     ("url", str "https://personal.example/");
                     ("title", str "Personal");
                   ] );
             ]);
      settle ();
      advance env 86400;
      ignore (Expiry.sweep expiry);
      Alcotest.(check int)
        "hand-ihcg hand-amp5 human page is permanent" 1
        (List.length (rows tabs));
      let info =
        result
          (request tabs "a"
             (P.Take { url = Some "https://personal"; title = None; label = None }))
      in
      let h = handle_of info in
      advance env 30;
      ignore (Expiry.sweep expiry);
      Alcotest.(check string)
        "hand-ihcg taken page is now agent and closes" "tab-gone"
        (code (use tabs h)))

let idle_pause
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env ~tabs ~expiry ~fake:_ ->
      let h = fresh tabs in
      (* The held-state assertion below checks the fixture transition. *)
      let _human_handoff =
        Tabs.hand_over tabs ~reason:"captcha" h
          [@@ox.allow "ox-discarded-result: best effort: human handoff"]
      in
      advance env 3600;
      ignore (Expiry.sweep expiry);
      Alcotest.(check bool) "hand-len8 idle is paused" true (held tabs);
      ignore (result (request tabs "b" (P.Resume { tab = h })));
      advance env 29;
      ignore (Expiry.sweep expiry);
      Alcotest.(check int) "resume resets idle" 1 (List.length (rows tabs));
      advance env 1;
      ignore (Expiry.sweep expiry);
      Alcotest.(check string) "close after resumed idle" "tab-gone" (code (use tabs h)))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L49 idle close"
    [
      ( "idle",
        List.map
          (fun (n, f) -> Alcotest.test_case n `Quick f)
          [
            ("hand-0ibq ihcg pure policy", policy);
            ("hand-0ibq exact boundary and late-use hint", boundary ~caps);
            ("hand-ihcg human and permanently taken", human_safety ~caps);
            ("handoff pause", idle_pause ~caps);
          ] );
    ]
