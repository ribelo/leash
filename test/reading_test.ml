(* tab-9x5e tab-x4v0 tab-a33o tab-qmei tab-5vnm tab-un75 tab-fepr tab-0lax tab-gjo0 *)
module P = Leash.Protocol
module R = Leash__Reading
module Fake = Leash_test_support.Fake_browser
module Chrome = Leash.Chrome

let obj xs = `Assoc xs
let str s = `String s
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None

let get key json =
  match field key json with Some x -> x | None -> Alcotest.fail ("missing " ^ key)

let handle =
  match P.Handle.of_string "t_00000000000000000000000000000000" with
  | Ok h -> h
  | Error e -> failwith e

let code = function
  | Ok _ -> Alcotest.fail "expected error"
  | Error e -> P.Error_code.to_string e.P.code

let ok = function
  | Ok x -> x
  | Error e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.P.code) e.message

let browser ?(reply = fun _ _ -> obj []) ?(row = fun _ -> None) ?(dialog = fun () -> None)
    ?(clock = ref 0.) () : R.browser =
  {
    call = (fun name args -> Ok (reply name args));
    now = (fun () -> !clock);
    sleep = (fun s -> clock := !clock +. s);
    current = (fun () -> ("about:blank", "Untitled"));
    dialog;
    dialog_race =
      { Leash__Dialog_race.current = dialog; subscribe = (fun _ -> fun () -> ()) };
    (* No registry here, so this acknowledgement is never resolved and no event can end a
       call; [eval] still races it (tab-gjo0), which is why its cases run under Ox. *)
    acknowledge = (fun () -> fst (Leash__Dispatch.make ()));
    row;
    snapshot_current = (fun _ -> false);
    baseline = (fun _ -> None);
    probe = (fun () -> Ok { R.loader = ""; guard = None });
  }

let stub name _ =
  match name with
  | "Runtime.evaluate" ->
      obj [ ("result", obj [ ("type", str "object"); ("objectId", str "window") ]) ]
  | "Runtime.callFunctionOn" ->
      obj [ ("result", obj [ ("type", str "string"); ("value", str "ok") ]) ]
  | "Page.captureScreenshot" -> obj [ ("data", str "iVBORw0KGgo=") ]
  | _ -> obj []

(* tab-a33o tab-gjo0: [eval] races its call against the tab's acknowledgement, so it
   runs where Eio does. *)
let eval_bounds () =
  Ox_test.run (fun _env _sw ->
      let b = browser ~reply:stub () in
      let arg expression argument =
        P.{ tab = handle; expression; argument; index = None; snapshot = None }
      in
      Alcotest.(check string)
        "expression bound" "too-large"
        (code (R.eval b (arg (String.make 65_537 'x') None)));
      Alcotest.(check string)
        "argument bound" "too-large"
        (code (R.eval b (arg "return argument" (Some (str (String.make 65_537 'x'))))));
      let evaluated = ok (R.eval b (arg "return argument" (Some (str "hi")))) in
      Alcotest.(check bool) "evaluated" true (evaluated.P.value = str "ok");
      let large _ _ =
        obj [ ("result", obj [ ("value", str (String.make 65_537 'x')) ]) ]
      in
      Alcotest.(check string)
        "result bound" "too-large"
        (code
           (R.eval
              (browser
                 ~reply:(fun n a ->
                   if n = "Runtime.evaluate" then stub n a else large n a)
                 ())
              (arg "return 1" None))))

let text_and_wait () =
  let clock = ref 0. in
  let calls = ref 0 in
  let answer name params =
    if name = "Runtime.evaluate" then (
      incr calls;
      let value =
        match get "expression" params with
        | `String s when String.starts_with ~prefix:"Boolean(" s -> `Bool (!calls >= 3)
        | _ -> str "pending"
      in
      obj [ ("result", obj [ ("value", value) ]) ])
    else obj []
  in
  let b = browser ~reply:answer ~clock () in
  let rendered = ok (R.text b P.{ tab = handle; index = None; max_chars = Some 4 }) in
  Alcotest.(check string) "rendered text" "pend" rendered.P.text;
  Alcotest.(check bool) "truncated" true rendered.P.truncated;
  let unicode =
    browser ~reply:(fun _ _ -> obj [ ("result", obj [ ("value", str "żółw") ]) ]) ()
  in
  let first_two =
    ok (R.text unicode P.{ tab = handle; index = None; max_chars = Some 2 })
  in
  Alcotest.(check string) "Unicode scalar boundary" "żó" first_two.P.text;
  let until =
    P.
      {
        url_prefix = Some "about:";
        text = Some "ready";
        index_gone = None;
        dialog = Some false;
        changed_since = None;
      }
  in
  ignore (ok (R.wait b P.{ tab = handle; until; timeout_ms = Some 200 }));
  Alcotest.(check bool) "AND waits" true (!calls >= 3);
  let never = P.{ until with url_prefix = Some "https://missing" } in
  Alcotest.(check string)
    "deadline" "timeout"
    (code (R.wait b P.{ tab = handle; until = never; timeout_ms = Some 100 }));
  Alcotest.(check string)
    "bounded" "invalid-request"
    (code (R.wait b P.{ tab = handle; until; timeout_ms = Some 3_600_001 }))

let indexed_text_and_disappearance () =
  let calls = ref [] in
  let answer name params =
    calls := (name, params) :: !calls;
    match name with
    | "DOM.resolveNode" -> obj [ ("object", obj [ ("objectId", str "node.1") ]) ]
    | "Runtime.callFunctionOn" -> obj [ ("result", obj [ ("value", str "label") ]) ]
    | "Runtime.evaluate" -> obj [ ("result", obj [ ("value", `Bool true) ]) ]
    | _ -> obj []
  in
  let b =
    browser ~reply:answer ~row:(fun index -> if index = 7 then Some 123 else None) ()
  in
  let found = ok (R.text b P.{ tab = handle; index = Some 7; max_chars = None }) in
  Alcotest.(check string) "indexed node text" "label" found.P.text;
  Alcotest.(check bool)
    "backend id used" true
    (List.exists
       (fun (name, params) ->
         name = "DOM.resolveNode" && get "backendNodeId" params = `Int 123)
       !calls);
  let gone =
    P.
      {
        url_prefix = None;
        text = None;
        index_gone = Some 8;
        dialog = None;
        changed_since = None;
      }
  in
  ignore (ok (R.wait b P.{ tab = handle; until = gone; timeout_ms = Some 0 }));
  let connected = ref false in
  let missing =
    browser
      ~row:(fun _ -> Some 123)
      ~reply:(fun name _ ->
        match name with
        | "DOM.resolveNode" -> obj [ ("object", obj [ ("objectId", str "node.1") ]) ]
        | "Runtime.callFunctionOn" ->
            obj [ ("result", obj [ ("value", `Bool !connected) ]) ]
        | _ -> obj [])
      ()
  in
  ignore
    (ok
       (R.wait missing
          P.
            {
              tab = handle;
              until = P.{ gone with index_gone = Some 7 };
              timeout_ms = Some 0;
            }));
  connected := true;
  Alcotest.(check string)
    "attached node remains" "timeout"
    (code
       (R.wait missing
          P.
            {
              tab = handle;
              until = P.{ gone with index_gone = Some 7 };
              timeout_ms = Some 0;
            }));
  let probe = ref None in
  let b =
    browser
      ~reply:(fun name params ->
        if name = "Runtime.evaluate" then (
          probe := field "expression" params;
          obj [ ("result", obj [ ("value", `Bool true) ]) ])
        else obj [])
      ()
  in
  let until = P.{ gone with index_gone = None; text = Some "needle" } in
  ignore (ok (R.wait b P.{ tab = handle; until; timeout_ms = Some 0 }));
  Alcotest.(check bool)
    "search is evaluated on the full page" true
    (match !probe with
    | Some (`String expression) ->
        String.starts_with ~prefix:"Boolean(document.body" expression
    | _ -> false)

let dialog_and_shot () =
  let sent = ref [] in
  let b =
    browser
      ~reply:(fun n p ->
        sent := (n, p) :: !sent;
        stub n p)
      ()
  in
  let args =
    P.
      {
        tab = handle;
        answer = (match P.Answer.of_string "dismiss" with Ok v -> v | _ -> assert false);
        text = None;
      }
  in
  Alcotest.(check string) "none" "no-dialog" (code (R.dialog b args));
  let dlg =
    P.
      {
        kind =
          (match P.Dialog_kind.of_string "alert" with Ok v -> v | _ -> assert false);
        message = "notice";
        default_prompt = None;
      }
  in
  let active =
    browser
      ~reply:(fun n p ->
        sent := (n, p) :: !sent;
        stub n p)
      ~dialog:(fun () -> Some dlg)
      ()
  in
  let result = ok (R.dialog active args) in
  Alcotest.(check bool) "closed" true (result.P.dialog = None);
  Alcotest.(check bool)
    "dismiss flag" true
    (List.exists
       (fun (n, p) -> n = "Page.handleJavaScriptDialog" && get "accept" p = `Bool false)
       !sent);
  Alcotest.(check string)
    "absolute path" "invalid-request"
    (code (R.shot b P.{ tab = handle; path = "relative.png"; full_page = None }));
  let path =
    Filename.concat
      (Filename.get_temp_dir_name ())
      ("leash-reading-" ^ string_of_int (Unix.getpid ()) ^ ".png")
  in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      let shot = ok (R.shot b P.{ tab = handle; path; full_page = Some true }) in
      Alcotest.(check int) "bytes" 8 shot.P.bytes;
      Alcotest.(check bool) "written" true (Sys.file_exists path))

let debug_ring () =
  let state = R.create () in
  let emit kind params =
    R.observe state ~at:1_700_000_000. (obj [ ("method", str kind); ("params", params) ])
  in
  for i = 0 to 201 do
    emit "Runtime.consoleAPICalled"
      (obj
         [
           ("type", str "log");
           ("args", `List [ obj [ ("value", str (string_of_int i)) ] ]);
         ])
  done;
  emit "Runtime.exceptionThrown"
    (obj [ ("exceptionDetails", obj [ ("text", str "boom") ]) ]);
  emit "Network.loadingFailed" (obj [ ("errorText", str "net::ERR_FAILED") ]);
  let entries =
    (ok (R.debug state P.{ tab = handle; limit = None; clear = Some true })).P.entries
  in
  Alcotest.(check int) "ring cap" 200 (List.length entries);
  Alcotest.(check string) "newest first" "net::ERR_FAILED" (List.hd entries).P.text;
  Alcotest.(check string) "old entries dropped" "4" (List.hd (List.rev entries)).P.text;
  Alcotest.(check bool)
    "exception recorded" true
    (List.exists (fun (e : P.debug_entry) -> e.P.text = "boom") entries);
  Alcotest.(check bool)
    "failed request recorded" true
    (List.exists (fun (e : P.debug_entry) -> e.P.text = "net::ERR_FAILED") entries);
  Alcotest.(check int)
    "cleared" 0
    (List.length
       (ok (R.debug state P.{ tab = handle; limit = None; clear = None })).P.entries)

(* The control seam: the service in-process, the fake browser under it, and the commands
   the CLI would send. [fake] is the scripted Chrome, driven directly by the tests below. *)
let rig f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw ~sleep:(Eio.Time.sleep clock) () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
            ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~fds:[] ()
        with
        | Error e -> Error e
        | Ok child -> Ok (child, { Leash.Cdp.read = client.read; write = client.write })
      in
      let logger =
        Ox_observability.Logger.create ~service:"reading-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-reading-test-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
          {
            Leash.Tabs.chrome;
            clock = env#clock;
            logger;
            desktop = Leash.Desktop.disabled;
          }
      in
      let rec ready n =
        if n = 0 then Alcotest.fail "Chrome unavailable"
        else if (Chrome.status chrome).phase <> `Running then (
          Eio.Fiber.yield ();
          ready (n - 1))
      in
      ready 1000;
      let fake =
        match !current with Some f -> f | None -> Alcotest.fail "fake missing"
      in
      f ~env ~sw ~tabs ~fake)

let protocol_smoke () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ->
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          let params = get "params" request in
          let value =
            match field "expression" params with
            | Some (`String s) when String.starts_with ~prefix:"Boolean(" s -> `Bool true
            | _ -> str "body content"
          in
          obj [ ("result", obj [ ("value", value) ]) ]);
      Fake.on_method fake "Page.captureScreenshot" (fun _ ->
          obj [ ("data", str "iVBORw0KGgo=") ]);
      let owner =
        match P.Owner.of_string "alice" with Ok x -> x | Error e -> failwith e
      in
      let send command =
        let wire = P.encode_request { owner; command } |> Yojson.Safe.to_string in
        let decoded =
          P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire))
        in
        match decoded with Ok x -> x | Error why -> Alcotest.fail why
      in
      let result = function
        | P.Success x -> x
        | P.Failure e -> Alcotest.fail e.P.message
      in
      let new_tab = result (send (P.New { url = None })) in
      let tab =
        match P.Handle.t_of_yojson (get "tab" new_tab) with
        | Ok x -> x
        | Error e -> Alcotest.fail e
      in
      let rendered = result (send (P.Text { tab; index = None; max_chars = Some 4 })) in
      Alcotest.(check string)
        "text over protocol" "body"
        (match get "text" rendered with `String s -> s | _ -> "");
      let until =
        P.
          {
            url_prefix = Some "about:";
            text = Some "body";
            index_gone = None;
            dialog = Some false;
            changed_since = None;
          }
      in
      ignore (result (send (P.Wait { tab; until; timeout_ms = Some 0 })));
      let path =
        Filename.concat
          (Filename.get_temp_dir_name ())
          ("leash-reading-protocol-" ^ string_of_int (Unix.getpid ()) ^ ".png")
      in
      Fun.protect
        ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
        (fun () ->
          let screenshot = result (send (P.Shot { tab; path; full_page = Some true })) in
          Alcotest.(check int)
            "shot bytes over protocol" 8
            (match get "bytes" screenshot with `Int n -> n | _ -> -1));
      let absent =
        send
          (P.Dialog
             {
               tab;
               answer =
                 (match P.Answer.of_string "accept" with Ok x -> x | _ -> assert false);
               text = None;
             })
      in
      Alcotest.(check string)
        "no-dialog over protocol" "no-dialog"
        (match absent with
        | P.Failure e -> P.Error_code.to_string e.P.code
        | _ -> "success");
      let methods =
        Fake.received fake
        |> List.filter_map (fun j ->
            match field "method" j with Some (`String s) -> Some s | _ -> None)
      in
      Alcotest.(check bool) "console subscribed" true (List.mem "Runtime.enable" methods);
      Alcotest.(check bool) "network subscribed" true (List.mem "Network.enable" methods))

(* The popup announcement headless Chrome sends: a TargetInfo with the opener's target id,
   [canAccessOpener] and [openerFrameId] (docs/cdp-shapes.md, L10; the shape is the one in
   test/fixtures/unlabelled-controls-chrome.json, tab-8k2g). *)
let announcement ~id ~opener ~url =
  obj
    [
      ( "targetInfo",
        obj
          [
            ("targetId", str id);
            ("type", str "page");
            ("title", str "Popup");
            ("url", str url);
            ("attached", `Bool false);
            ("canAccessOpener", `Bool true);
            ("openerId", str opener);
            ("openerFrameId", str opener);
            ("browserContextId", str "browser-context-1");
          ] );
    ]

let tab_of json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok handle -> handle
  | Error e -> Alcotest.fail e

(* tab-gjo0: an evaluated [window.open] is answered only once the popup is gone
   (docs/cdp-shapes.md, L10), so [eval] settles the way a trusted input does: a new target
   with this tab as its opener ends the wait with a null value and the popup adopted, and
   this tab's own death ends it with [tab-gone] (own-teh1). The fake withholds both
   [Runtime.callFunctionOn] replies, so nothing but those two events can settle the calls,
   and the test never moves its clock. *)
let eval_settlement () =
  rig (fun ~env:_ ~sw ~tabs ~fake ->
      Fake.on_method fake "Runtime.evaluate" (fun _ ->
          obj [ ("result", obj [ ("type", str "object"); ("objectId", str "window") ]) ]);
      Fake.withhold fake "Runtime.callFunctionOn" (fun _ -> true);
      let owner =
        match P.Owner.of_string "alice" with Ok x -> x | Error e -> failwith e
      in
      let send command =
        let wire = P.encode_request { owner; command } |> Yojson.Safe.to_string in
        match
          P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire))
        with
        | Ok reply -> reply
        | Error why -> Alcotest.fail why
      in
      let result = function
        | P.Success json -> json
        | P.Failure e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message
      in
      let sent = ref 0 in
      let wait_for_call () =
        let rec loop n =
          let seen =
            Fake.received fake
            |> List.filter (fun json ->
                field "method" json = Some (str "Runtime.callFunctionOn"))
            |> List.length
          in
          if seen > !sent then sent := seen
          else if n = 0 then Alcotest.fail "tab-gjo0 the eval call was never sent"
          else (
            Eio.Fiber.yield ();
            loop (n - 1))
        in
        loop 1000
      in
      let await what cell =
        let rec loop n =
          match !cell with
          | Some reply -> reply
          | None ->
              if n = 0 then Alcotest.fail (what ^ " never replied")
              else (
                Eio.Fiber.yield ();
                loop (n - 1))
        in
        loop 100_000
      in
      let tab = tab_of (result (send (P.New { url = None }))) in
      (* window.open: the popup's own announcement settles the call. *)
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (send
                 (P.Eval
                    {
                      tab;
                      expression = "window.open('https://example.com/popup','w')";
                      argument = None;
                      index = None;
                      snapshot = None;
                    })));
      wait_for_call ();
      Fake.emit fake ~method_:"Target.targetCreated"
        ~params:
          (announcement ~id:"popup-target" ~opener:"target-1"
             ~url:"https://example.com/popup");
      let opened = result (await "tab-gjo0 the window-opening eval" cell) in
      Alcotest.(check bool)
        "tab-gjo0 a window-opening eval ends with a null value" true
        (get "value" opened = `Null);
      let popup =
        match get "tabs" (result (send (P.List_tabs { all = true }))) with
        | `List rows ->
            List.find_opt
              (fun row -> get "url" row = str "https://example.com/popup")
              rows
        | _ -> None
      in
      (match popup with
      | Some row ->
          Alcotest.(check string)
            "tab-gjo0 the popup is the opener's tab" "agent"
            (match get "origin" row with `String s -> s | _ -> "");
          Alcotest.(check string)
            "tab-gjo0 owned by the caller" "alice"
            (match get "owner" row with `String s -> s | _ -> "")
      | None -> Alcotest.fail "tab-gjo0 the popup was not adopted");
      (* window.close: the tab's own death settles it with tab-gone. *)
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (send
                 (P.Eval
                    {
                      tab;
                      expression = "window.close()";
                      argument = None;
                      index = None;
                      snapshot = None;
                    })));
      wait_for_call ();
      Fake.emit fake ~method_:"Target.targetDestroyed"
        ~params:(obj [ ("targetId", str "target-1") ]);
      match await "tab-gjo0 the window-closing eval" cell with
      | P.Failure e ->
          Alcotest.(check string)
            "tab-gjo0 a window-closing eval ends tab-gone" "tab-gone"
            (P.Error_code.to_string e.code);
          Alcotest.(check (option string))
            "tab-gjo0 with its disposition" (Some "closed_externally")
            (match e.detail with
            | Some detail -> (
                match field "disposition" detail with
                | Some (`String d) -> Some d
                | _ -> None)
            | None -> None)
      | P.Success _ -> Alcotest.fail "tab-gjo0 the closing eval should report tab-gone")

let () =
  Alcotest.run "reading"
    [
      ( "operations",
        [
          Alcotest.test_case "eval limits" `Quick eval_bounds;
          Alcotest.test_case "text and AND wait" `Quick (fun () ->
              Ox_test.run (fun _ _ -> text_and_wait ()));
          Alcotest.test_case "indexed text and disappearance" `Quick (fun () ->
              Ox_test.run (fun _ _ -> indexed_text_and_disappearance ()));
          Alcotest.test_case "dialog and PNG" `Quick dialog_and_shot;
          Alcotest.test_case "debug ring" `Quick debug_ring;
          Alcotest.test_case "control seam" `Quick protocol_smoke;
          Alcotest.test_case "tab-gjo0 eval settlement" `Quick eval_settlement;
        ] );
    ]
