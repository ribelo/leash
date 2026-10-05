module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

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
let rows json = match get "tabs" json with `List xs -> xs | _ -> Alcotest.fail "tabs"

let find_tab listed handle =
  let handle = P.Handle.to_string handle in
  match List.find_opt (fun row -> get "tab" row = str handle) listed with
  | Some row -> row
  | None -> Alcotest.failf "tab %s is not listed" handle

let text key json = match get key json with `String s -> s | _ -> ""

let enum of_string value =
  match of_string value with Ok v -> v | Error e -> Alcotest.fail e

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
      let logs = Ox_observability.Logger.Memory.create () in
      let logger =
        Ox_observability.Logger.create ~service:"leash-handles-tests" ~clock:env#clock
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
            mgr = env#process_mgr;
            logger;
            caps :> Leash.Chrome.caps;
          }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:128 ~tombstone_s:3600
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
      let fake = match !current with Some x -> x | None -> Alcotest.fail "no fake" in
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("value", str "") ]) ]);
      f ~env ~sw ~tabs ~fake ~logs)

let loads fake =
  Fake.on_method fake "Page.navigate" (fun request ->
      let session =
        match get "sessionId" request with `String s -> s | _ -> assert false
      in
      Fake.emit ~session fake ~method_:"Page.loadEventFired"
        ~params:(Fake.event "Page.loadEventFired");
      obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-1") ])

let page_commands handle : (string * P.command) list =
  let snapshot =
    match P.Snapshot_id.of_string "s_matrix" with Ok s -> s | Error e -> Alcotest.fail e
  in
  [
    ("nav", P.Nav { tab = handle; url = "about:blank" });
    ( "snap",
      P.Snap
        { tab = handle; match_ = None; limit = Some 1; offset = None; with_image = None }
    );
    ("text", P.Text { tab = handle; index = None; max_chars = None });
    ( "eval",
      P.Eval
        { tab = handle; expression = "1"; argument = None; index = None; snapshot = None }
    );
    ("shot", P.Shot { tab = handle; path = "/tmp/leash-capability.png"; full_page = None });
    ("debug", P.Debug { tab = handle; limit = None; clear = None });
    ( "wait",
      P.Wait
        {
          tab = handle;
          until =
            {
              url_prefix = None;
              text = None;
              index_gone = None;
              dialog = None;
              changed_since = None;
            };
          timeout_ms = Some 1;
        } );
    ( "click",
      P.Click
        { tab = handle; snapshot; index = 1; snap = None; match_ = None; limit = None } );
    ( "fill",
      P.Fill
        {
          tab = handle;
          snapshot;
          index = 1;
          text = "x";
          snap = None;
          match_ = None;
          limit = None;
        } );
    ( "press",
      P.Press
        {
          tab = handle;
          snapshot;
          index = Some 1;
          key = "Enter";
          snap = None;
          match_ = None;
          limit = None;
        } );
    ( "select",
      P.Select
        {
          tab = handle;
          snapshot;
          index = 1;
          option = 0;
          snap = None;
          match_ = None;
          limit = None;
        } );
    ( "scroll",
      P.Scroll
        { tab = handle; direction = enum P.Direction.of_string "down"; index = None } );
    (* hard-xg6y hard-ovbx hard-vq5s hard-o3za hard-v1gs hard-ufb7: the seven additions of
       milestone 8 are Act commands like the rest, and this table is what keeps a net ring,
       a body, a cookie or an upload from being reachable without the handle. *)
    ("net", P.Net { tab = handle; match_ = None; limit = None; type_ = None });
    ("net_body", P.Net_body { tab = handle; id = "1000.1" });
    ("net_request", P.Net_request { tab = handle; id = "1000.1" });
    ( "upload",
      P.Upload { tab = handle; snapshot; index = 1; paths = [ "/tmp/leash-upload" ] } );
    ( "hover",
      P.Hover
        { tab = handle; snapshot; index = 1; snap = None; match_ = None; limit = None } );
    ("cookies", P.Cookies { tab = handle });
    ("storage", P.Storage { tab = handle; area = enum P.Storage_area.of_string "local" });
    ( "dialog",
      P.Dialog { tab = handle; answer = enum P.Answer.of_string "accept"; text = None } );
  ]

(* L49: hand-scaz hand-qos2 hand-mb9s hand-x3hi hand-ryxz hand-okk8 hand-gjqy hand-k1ag. *)
let create tabs ?label () = result (request tabs "client" (P.New { url = None; label }))
let listed tabs = rows (result (request tabs "any connection" P.List_tabs))

let settle () =
  for _ = 1 to 100 do
    Eio.Fiber.yield ()
  done

let announce fake ?opener ~id ~url ~title () =
  let fields =
    [ ("targetId", str id); ("type", str "page"); ("url", str url); ("title", str title) ]
  in
  let fields =
    match opener with None -> fields | Some p -> ("openerId", str p) :: fields
  in
  Fake.emit fake ~method_:"Target.targetCreated"
    ~params:(obj [ ("targetInfo", obj fields) ]);
  settle ()

let take tabs ?url ?title ?label () =
  request tabs "separate connection" (P.Take { url; title; label })

let capabilities
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let first = create tabs ~label:"Research" () in
      let h = tab first in
      let raw = P.Handle.to_string h in
      Alcotest.(check int)
        "hand-mb9s 128 random bits as 32 hex digits" 34 (String.length raw);
      Alcotest.(check bool)
        "hand-mb9s prefix and hex" true
        (String.starts_with ~prefix:"t_" raw
        && String.for_all
             (fun c -> String.contains "0123456789abcdef" c)
             (String.sub raw 2 32));
      let second = tab (create tabs ()) in
      Alcotest.(check bool) "fresh capabilities differ" true (h <> second);
      ignore
        (result
           (request tabs "another connection"
              (P.Text { tab = h; index = None; max_chars = None })));
      let all = listed tabs in
      Alcotest.(check int) "hand-x3hi all tabs" 2 (List.length all);
      List.iter
        (fun row ->
          Alcotest.(check bool)
            "hand-x3hi no handle or target id" true
            (match row with
            | `Assoc fields ->
                List.map fst fields |> List.sort String.compare
                = List.sort String.compare
                    [
                      "label";
                      "url";
                      "title";
                      "origin";
                      "age_s";
                      "idle_s";
                      "closes_in_s";
                      "with_human";
                    ]
            | _ -> false))
        all;
      Alcotest.(check bool)
        "hand-ryxz label retained" true
        (List.exists (fun row -> field "label" row = Some (str "Research")) all);
      check_code "hand-okk8 exact label is case-insensitive" "taken"
        (take tabs ~label:"rEsEaRcH" ());
      check_code "hand-okk8 label is not a substring" "no-match"
        (take tabs ~label:"sea" ());
      ignore (create tabs ~label:"research" ());
      check_code "hand-okk8 duplicate labels are ambiguous" "ambiguous"
        (take tabs ~label:"research" ());
      let encoded = P.encode_request { command = P.List_tabs } in
      Alcotest.(check bool)
        "hand-scaz anonymous envelope" true
        (match encoded with `Assoc f -> List.length f = 3 | _ -> false))

let selectors
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw:_ ~tabs ~fake ~logs ->
      announce fake ~id:"human-1" ~url:"https://Example.com/Inbox" ~title:"Personal Inbox"
        ();
      announce fake ~id:"human-2" ~url:"https://example.com/Other" ~title:"Other Inbox" ();
      check_code "hand-okk8 exactly one selector" "invalid-request" (take tabs ());
      check_code "hand-okk8 selector conflict" "invalid-request"
        (take tabs ~url:"https://" ~title:"Inbox" ());
      check_code "hand-okk8 no-match" "no-match" (take tabs ~url:"https://missing/" ());
      let ambiguous = take tabs ~title:"INBOX" () in
      check_code "hand-okk8 ambiguous" "ambiguous" ambiguous;
      (match ambiguous with
      | P.Failure { detail = Some (`Assoc f); _ } -> (
          match List.assoc_opt "matches" f with
          | Some (`List xs) ->
              List.iter
                (fun x ->
                  Alcotest.(check bool)
                    "ambiguous reveals no capability" true
                    (field "tab" x = None))
                xs
          | _ -> Alcotest.fail "matches")
      | _ -> Alcotest.fail "ambiguous detail");
      let acquired = result (take tabs ~url:"HTTPS://EXAMPLE.COM/IN" ()) in
      let h = tab acquired in
      Alcotest.(check string)
        "hand-okk8 permanently agent" "agent" (text "origin" acquired);
      let taken = take tabs ~title:"personal" () in
      check_code "hand-gjqy already taken" "taken" taken;
      (match taken with
      | P.Failure e -> Alcotest.(check bool) "holder can share" true (e.hint <> "")
      | _ -> assert false);
      (* Ownership assertions below check this fixture transition. *)
      let _human_handoff = Leash.Tabs.hand_over tabs ~reason:"captcha" h in
      check_code "hand-0o28 hand-gjqy human-held refusal" "with-human"
        (take tabs ~url:"https://example.com/in" ());
      Alcotest.(check bool)
        "hand-0o28 list shows the hold and no handle" true
        (List.exists
           (fun row ->
             field "with_human" row = Some (`Bool true) && field "tab" row = None)
           (listed tabs));
      let audits =
        Ox_observability.Logger.Memory.records logs
        |> List.filter (fun e -> e.Ox_observability.Logger.msg = "tab taken")
      in
      Alcotest.(check bool)
        "hand-k1ag take audit has URL and time, never a handle" true
        (List.exists
           (fun (e : Ox_observability.Logger.record) ->
             List.assoc_opt "url" e.fields
             = Some (Ox_observability.Logger.String "https://Example.com/Inbox")
             && List.assoc_opt "at" e.fields = Some (Ox_observability.Logger.Float e.ts)
             && List.assoc_opt "tab" e.fields = None)
           audits))

(* Every handle command, against the five capability conditions, including separate
   decoded raw-wire requests for each cell. Live actions may fail for page-specific reasons,
   but never at authorization. *)
let matrix
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      loads fake;
      let bad = enum P.Handle.of_string "t_unknown" in
      let commands h =
        page_commands h
        @ [ ("close", P.Close { tab = h }); ("resume", P.Resume { tab = h }) ]
      in
      List.iter
        (fun condition ->
          List.iter
            (fun (name, _) ->
              let info = create tabs () in
              let h = tab info in
              let chosen = if condition = `Bad then bad else h in
              (match condition with
              | `Human ->
                  (* The refusal assertion below checks the resulting ownership. *)
                  let _human_handoff = Leash.Tabs.hand_over tabs ~reason:"captcha" h in
                  ()
              | `Closed -> ignore (result (request tabs "a" (P.Close { tab = h })))
              | _ -> ());
              let command = List.assoc name (commands chosen) in
              let reply =
                if condition = `Missing then
                  let args =
                    match P.args_to_json command with
                    | `Assoc f -> obj (List.remove_assoc "tab" f)
                    | _ -> assert false
                  in
                  let line =
                    Yojson.Safe.to_string
                      (obj
                         [
                           ("v", `Int P.version);
                           ("cmd", str (P.command_name command));
                           ("args", args);
                         ])
                  in
                  match
                    P.decode_reply
                      (Yojson.Safe.from_string (Leash.Control.handle tabs line))
                  with
                  | Ok r -> r
                  | Error e -> Alcotest.fail e
                else request tabs "independent connection" command
              in
              let label = "hand-oyzl " ^ name in
              match condition with
              | `Missing -> check_code label "invalid-request" reply
              | `Bad -> check_code label "unknown-tab" reply
              | `Closed when name = "close" -> ignore (result reply)
              | `Closed -> check_code label "tab-gone" reply
              | `Human when name = "resume" -> ignore (result reply)
              | `Human -> check_code label "with-human" reply
              | `Live -> (
                  match reply with
                  | P.Failure e ->
                      Alcotest.(check bool)
                        label false
                        (List.mem
                           (P.Error_code.to_string e.code)
                           [ "unknown-tab"; "tab-gone"; "with-human" ])
                  | P.Success _ -> ()))
            (commands bad))
        [ `Missing; `Bad; `Live; `Human; `Closed ])

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L49 capabilities"
    [
      ( "handles",
        [
          Alcotest.test_case "hand-scaz mb9s x3hi ryxz" `Quick (capabilities ~caps);
          Alcotest.test_case "hand-okk8 gjqy k1ag" `Quick (selectors ~caps);
          Alcotest.test_case "hand-oyzl command x capability matrix" `Quick (matrix ~caps);
        ] );
    ]
