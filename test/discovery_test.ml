module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let handle json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let code = function
  | P.Failure e -> P.Error_code.to_string e.code
  | _ -> Alcotest.fail "expected a failure"

let result = function
  | P.Success json -> json
  | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let request tabs _client command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let check_code label expected reply = Alcotest.(check string) label expected (code reply)
let text key json = match get key json with `String s -> s | _ -> ""

let listed tabs _client ~all:_ =
  match get "tabs" (result (request tabs "any" P.List_tabs)) with
  | `List xs -> xs
  | _ -> Alcotest.fail "tabs must be an array"

let all tabs = listed tabs "alice" ~all:true

let row_of_url tabs url =
  match List.find_opt (fun row -> text "url" row = url) (all tabs) with
  | Some row -> row
  | None -> Alcotest.failf "%s is not listed" url

let count_url tabs url =
  List.length (List.filter (fun row -> text "url" row = url) (all tabs))

let target_info ?(kind = "page") ?(url = "about:blank") ?(title = "") ?opener id =
  obj
    ([
       ("targetId", str id);
       ("type", str kind);
       ("title", str title);
       ("url", str url);
       ("attached", `Bool false);
       ("canAccessOpener", `Bool (opener <> None));
       ("browserContextId", str "browser-context-1");
     ]
    @ match opener with None -> [] | Some opener -> [ ("openerId", str opener) ])

let announce fake ?kind ?url ?title ?opener ~id () =
  Fake.emit fake ~method_:"Target.targetCreated"
    ~params:(obj [ ("targetInfo", target_info ?kind ?url ?title ?opener id) ])

let attach fake ~session ?kind ?url ?title ?opener ~id () =
  Fake.emit fake ~method_:"Target.attachedToTarget"
    ~params:
      (obj
         [
           ("sessionId", str session);
           ("targetInfo", target_info ?kind ?url ?title ?opener id);
           ("waitingForDebugger", `Bool false);
         ])

let destroy fake id =
  Fake.emit fake ~method_:"Target.targetDestroyed" ~params:(obj [ ("targetId", str id) ])

let barrier fake tabs tag =
  let url = "https://barrier.example/" ^ tag in
  announce fake ~id:("barrier-" ^ tag) ~url ();
  let rec loop n =
    if n = 0 then Alcotest.failf "the barrier %s never arrived" tag
    else if count_url tabs url = 1 then ()
    else (
      Eio.Fiber.yield ();
      loop (n - 1))
  in
  loop 1000

let check_disposition label expected reply =
  match reply with
  | P.Failure e -> (
      Alcotest.(check string)
        (label ^ " is tab-gone") "tab-gone"
        (P.Error_code.to_string e.code);
      match e.detail with
      | Some json -> Alcotest.(check string) label expected (text "disposition" json)
      | None -> Alcotest.failf "%s: tab-gone with no disposition" label)
  | P.Success _ -> Alcotest.failf "%s: expected tab-gone" label

let rig f =
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
      let logs = Ox_observability.Logger.Memory.create () in
      let logger =
        Ox_observability.Logger.create ~service:"leash-discovery-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Memory.reporter logs)
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
        Leash.Tabs.create ~sw ~cap:128 ~tombstone_s:3600
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
      let fake = match !current with Some x -> x | None -> Alcotest.fail "no fake" in
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("value", str "") ]) ]);
      f ~env ~sw ~tabs ~fake ~logs)

let subscribed fake =
  let rec loop n =
    if n = 0 then Alcotest.fail "Leash never subscribed to target discovery"
    else
      match
        List.find_opt
          (fun json -> field "method" json = Some (str "Target.setDiscoverTargets"))
          (Fake.received fake)
      with
      | Some request ->
          Alcotest.(check bool)
            "own-c0cl discovery is subscribed with discover:true" true
            (field "params" request = Some (obj [ ("discover", `Bool true) ]))
      | None ->
          Eio.Fiber.yield ();
          loop (n - 1)
  in
  loop 1000

let page_says fake what =
  Fake.on_method fake "Runtime.evaluate" (fun _ ->
      obj [ ("result", obj [ ("type", str "string"); ("value", str what) ]) ])

let received fake meth =
  Fake.received fake |> List.filter (fun json -> field "method" json = Some (str meth))

let received_for fake meth key value =
  received fake meth
  |> List.exists (fun json ->
      match field "params" json with
      | Some params -> field key params = Some value
      | None -> false)

let received_in fake meth session =
  received fake meth
  |> List.filter (fun json -> field "sessionId" json = Some (str session))

let human_and_popup () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      subscribed fake;
      let parent =
        result (request tabs "a" (P.New { url = None; label = None })) |> handle
      in
      announce fake ~id:"ui-target" ~url:"https://personal.example/" ~title:"Human" ();
      announce fake ~id:"popup-target" ~opener:"target-1" ~url:"https://popup.example/"
        ~title:"Popup" ();
      attach fake ~session:"popup-session" ~id:"popup-target" ~opener:"target-1"
        ~url:"https://popup.example/" ~title:"Popup" ();
      announce fake ~kind:"service_worker" ~id:"worker" ~url:"https://worker.example/" ();
      barrier fake tabs "first";
      (* field-drpx: an attached popup is resumed, or Chrome leaves it blank and paused
         ("Debugger paused in another tab", the Google sign-in popup of 2026-10-01). *)
      let rec resumed n =
        if received_in fake "Runtime.runIfWaitingForDebugger" "popup-session" <> [] then
          true
        else if n = 0 then false
        else (
          Eio.Fiber.yield ();
          resumed (n - 1))
      in
      Alcotest.(check bool) "field-drpx the attached popup is resumed" true (resumed 1000);
      List.iter
        (fun url ->
          let row = row_of_url tabs url in
          Alcotest.(check string)
            "ADR-0010 unsolicited tabs are human" "human" (text "origin" row);
          Alcotest.(check bool)
            "no capability minted for human" true
            (field "tab" row = None);
          Alcotest.(check bool)
            "human never expires" true
            (field "closes_in_s" row = Some `Null))
        [ "https://personal.example/"; "https://popup.example/" ];
      Alcotest.(check int)
        "announce and attach adopt once" 1
        (count_url tabs "https://popup.example/");
      Alcotest.(check int) "non-page ignored" 0 (count_url tabs "https://worker.example/");
      destroy fake "target-1";
      barrier fake tabs "second";
      check_disposition "external close tombstone" "closed_externally"
        (request tabs "b" (P.Text { tab = parent; index = None; max_chars = None })))

let creation_race () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      Fake.on_method fake "Target.createTarget" (fun _ ->
          announce fake ~id:"created-target" ~url:"about:blank" ();
          obj [ ("targetId", str "created-target") ]);
      let h =
        result (request tabs "a" (P.New { url = None; label = Some "Mine" })) |> handle
      in
      barrier fake tabs "race";
      Alcotest.(check int)
        "own create announcement does not duplicate" 1
        (count_url tabs "about:blank");
      ignore
        (result (request tabs "b" (P.Text { tab = h; index = None; max_chars = None }))))

let () =
  Alcotest.run "L49 discovery"
    [
      ( "discovery",
        [
          Alcotest.test_case "hand-x3hi ADR-0010 human UI and popup" `Quick
            human_and_popup;
          Alcotest.test_case "hand-ehqa own create discovery race" `Quick creation_race;
        ] );
    ]
