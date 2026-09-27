(* tab-9x5e tab-x4v0 tab-a33o tab-qmei tab-5vnm tab-un75 tab-fepr tab-0lax *)
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
    row;
  }

let stub name _ =
  match name with
  | "Runtime.evaluate" ->
      obj [ ("result", obj [ ("type", str "object"); ("objectId", str "window") ]) ]
  | "Runtime.callFunctionOn" ->
      obj [ ("result", obj [ ("type", str "string"); ("value", str "ok") ]) ]
  | "Page.captureScreenshot" -> obj [ ("data", str "iVBORw0KGgo=") ]
  | _ -> obj []

let eval_bounds () =
  let b = browser ~reply:stub () in
  let arg expression argument = P.{ tab = handle; expression; argument } in
  Alcotest.(check string)
    "expression bound" "too-large"
    (code (R.eval b (arg (String.make 65_537 'x') None)));
  Alcotest.(check string)
    "argument bound" "too-large"
    (code (R.eval b (arg "return argument" (Some (str (String.make 65_537 'x'))))));
  let evaluated = ok (R.eval b (arg "return argument" (Some (str "hi")))) in
  Alcotest.(check bool) "evaluated" true (evaluated.P.value = str "ok");
  let large _ _ = obj [ ("result", obj [ ("value", str (String.make 65_537 'x')) ]) ] in
  Alcotest.(check string)
    "result bound" "too-large"
    (code
       (R.eval
          (browser
             ~reply:(fun n a -> if n = "Runtime.evaluate" then stub n a else large n a)
             ())
          (arg "return 1" None)))

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
    (code (R.wait b P.{ tab = handle; until; timeout_ms = Some 30_001 }))

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
  let gone = P.{ url_prefix = None; text = None; index_gone = Some 8; dialog = None } in
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

let protocol_smoke () =
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
        Eta_observability.Logger.create ~service:"reading-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Eta_observability.Logger.Reporter.writer ignore)
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
          { Leash.Tabs.chrome; clock = env#clock; logger }
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

let () =
  Alcotest.run "reading"
    [
      ( "operations",
        [
          Alcotest.test_case "eval limits" `Quick eval_bounds;
          Alcotest.test_case "text and AND wait" `Quick text_and_wait;
          Alcotest.test_case "indexed text and disappearance" `Quick
            indexed_text_and_disappearance;
          Alcotest.test_case "dialog and PNG" `Quick dialog_and_shot;
          Alcotest.test_case "debug ring" `Quick debug_ring;
          Alcotest.test_case "control seam" `Quick protocol_smoke;
        ] );
    ]
