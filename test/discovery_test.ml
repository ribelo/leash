(* L12 — origin and discovery (docs/issues/tab-ownership/01-tab-ownership.md, milestone 3).
   Stories: own-c0cl own-ehqa own-teh1.

   Everything runs at the control-protocol seam: the fake browser pushes the Target.*
   notifications Chrome pushes — discovery, attachment, destruction — and what the
   registry makes of them is read back through the protocol, exactly as the CLI reads it.
   No real Chrome, no socket outside the test, no network. *)

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

(* One request, exactly as the CLI sends it: encoded to the wire, dispatched by the
   service, decoded back. *)
let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let check_code label expected reply = Alcotest.(check string) label expected (code reply)
let text key json = match get key json with `String s -> s | _ -> ""

let listed tabs who ~all =
  match get "tabs" (result (request tabs who (P.List_tabs { all }))) with
  | `List xs -> xs
  | _ -> Alcotest.fail "tabs must be an array"

let all tabs = listed tabs "alice" ~all:true

let row_of_url tabs url =
  match List.find_opt (fun row -> text "url" row = url) (all tabs) with
  | Some row -> row
  | None -> Alcotest.failf "%s is not listed" url

let count_url tabs url =
  List.length (List.filter (fun row -> text "url" row = url) (all tabs))

(* Chrome's page TargetInfo of docs/cdp-shapes.md. A target with no opener omits
   [openerId] entirely and reports [canAccessOpener:false], which is what real Chrome
   does. *)
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

(* Chrome pushes its notifications in order on one pipe, so a target announced after
   another is listed only once the earlier one has been handled: this is the barrier the
   cases below wait on instead of sleeping. *)
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

(* own-teh1: a handle that names a closed tab answers tab-gone, and its detail says why. *)
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
      let logs = Eta_observability.Logger.Memory.create () in
      let logger =
        Eta_observability.Logger.create ~service:"leash-discovery-tests" ~clock:env#clock
          ~mono_clock:env#mono_clock
          ~reporter:(Eta_observability.Logger.Memory.reporter logs)
          ()
      in
      let chrome =
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let tabs =
        Leash.Tabs.create ~sw ~cap:128 ~tombstone_s:3600
          { Leash.Tabs.chrome; clock = env#clock; logger }
      in
      let rec ready n =
        if n = 0 then Alcotest.fail "no Chrome"
        else if (Chrome.status chrome).phase <> `Running then (
          Eio.Fiber.yield ();
          ready (n - 1))
      in
      ready 1000;
      let fake = match !current with Some x -> x | None -> Alcotest.fail "no fake" in
      f ~env ~sw ~tabs ~fake ~logs)

(* own-c0cl: the subscription the row is about. Discovery only happens because Leash asks
   Chrome for it (Target.setDiscoverTargets), so a tab opened in the Chrome UI — which is
   no attach of Leash's and no createTarget of Leash's — arrives as an announcement. *)
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

(* A read that needs the page: one Runtime.evaluate returning a string. *)
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

(* The requests one page session saw: a session's own traffic, as opposed to the browser
   session's. *)
let received_in fake meth session =
  received fake meth
  |> List.filter (fun json -> field "sessionId" json = Some (str session))

(* own-c0cl: a tab the human opened in the Chrome UI appears in list --all as human-origin
   and unowned, an agent claims it, and claiming is what makes it usable: the first
   command that needs the page attaches to the target and runs in the session Chrome hands
   back. A target that is not a page is not a tab. *)
let discovered_human () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      subscribed fake;
      announce fake ~id:"human-target" ~url:"https://human.example/" ~title:"human" ();
      (* chrome-fuao: Leash tracks pages; an iframe's own target is not a tab *)
      announce fake ~id:"frame-target" ~kind:"iframe" ~url:"https://human.example/frame"
        ();
      barrier fake tabs "0";
      let rows = all tabs in
      Alcotest.(check int)
        "own-c0cl only page targets become tabs" 1
        (List.length
           (List.filter (fun row -> text "url" row <> "https://barrier.example/0") rows));
      let row = row_of_url tabs "https://human.example/" in
      Alcotest.(check bool)
        "own-c0cl human origin, unowned, ownerless" true
        (get "origin" row = str "human"
        && get "state" row = str "unowned"
        && get "owner" row = `Null
        && text "title" row = "human");
      let h = handle row in
      check_code "own-c0cl nobody acts on it before claiming" "not-owner"
        (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None }));
      Alcotest.(check int)
        "own-c0cl it is nobody's tab yet" 0
        (List.length (listed tabs "alice" ~all:false));
      let claimed = result (request tabs "alice" (P.Claim { tab = h })) in
      Alcotest.(check bool)
        "own-c0cl claimed, origin kept" true
        (get "state" claimed = str "owned"
        && get "owner" claimed = str "alice"
        && get "origin" claimed = str "human");
      page_says fake "the human's page";
      let read =
        result (request tabs "alice" (P.Text { tab = h; index = None; max_chars = None }))
      in
      Alcotest.(check string)
        "own-c0cl the claimer reads the page" "the human's page" (text "text" read);
      Alcotest.(check bool)
        "own-c0cl acting attached to the discovered target" true
        (received_for fake "Target.attachToTarget" "targetId" (str "human-target"));
      Alcotest.(check bool)
        "own-c0cl the read ran in the session Chrome handed back" true
        (received fake "Runtime.evaluate"
        |> List.exists (fun json -> field "sessionId" json = Some (str "session-1"))))

(* own-c0cl own-ehqa (own-6ndc): Chrome announces the target Leash itself created before
   createTarget's reply, and a human's tab can appear in that same window. The created tab
   is alice's, agent-origin, and the announcement adds no second tab; the human's is
   human-origin and unowned. *)
let created_not_discovered () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      Fake.on_method fake "Target.createTarget" (fun _ ->
          announce fake ~id:"target-1" ~url:"about:blank" ();
          announce fake ~id:"human-target" ~url:"https://human.example/" ~title:"human" ();
          obj [ ("targetId", str "target-1") ]);
      let created = result (request tabs "alice" (P.New { url = None })) in
      let h = handle created in
      Alcotest.(check bool)
        "own-c0cl the created tab stays alice's, agent-origin" true
        (get "state" created = str "owned"
        && get "owner" created = str "alice"
        && get "origin" created = str "agent");
      barrier fake tabs "1";
      let mine =
        match
          List.find_opt (fun row -> get "tab" row = str (P.Handle.to_string h)) (all tabs)
        with
        | Some row -> row
        | None -> Alcotest.fail "the created tab is not listed"
      in
      Alcotest.(check bool)
        "own-c0cl the announcement did not make it a human's" true
        (get "origin" mine = str "agent" && get "state" mine = str "owned");
      Alcotest.(check int)
        "own-c0cl the announcement added no second tab for it" 1
        (List.length
           (List.filter
              (fun row -> get "tab" row = str (P.Handle.to_string h))
              (all tabs)));
      let human = row_of_url tabs "https://human.example/" in
      Alcotest.(check bool)
        "own-ehqa the human's tab in the same window is unowned, human origin" true
        (get "origin" human = str "human"
        && get "state" human = str "unowned"
        && get "owner" human = `Null))

(* own-ehqa: popups and tabs opened by a page are human-origin and unowned unless their
   opener is a tab an agent owns, in which case they are that agent's, agent-origin. Origin
   is decided once: a later report about the same target moves the page and never what the
   tab is, and the attachment Chrome pushes afterwards is the session it is used in, not a
   second tab. *)
let adopted_popup () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      let parent = result (request tabs "alice" (P.New { url = None })) |> handle in
      ignore parent;
      (* the fake browser creates every target as "target-1", which is what the parent got *)
      announce fake ~id:"popup-target" ~opener:"target-1" ~url:"https://example.com/popup"
        ~title:"Popup" ();
      announce fake ~id:"stranger-target" ~opener:"gone-target"
        ~url:"https://example.com/stranger" ~title:"Stranger" ();
      barrier fake tabs "0";
      let popup = row_of_url tabs "https://example.com/popup" in
      Alcotest.(check bool)
        "own-ehqa the popup is the opener agent's tab, agent-origin" true
        (get "origin" popup = str "agent"
        && get "state" popup = str "owned"
        && get "owner" popup = str "alice");
      let stranger = row_of_url tabs "https://example.com/stranger" in
      Alcotest.(check bool)
        "own-ehqa an opener Leash never saw leaves a human's unowned tab" true
        (get "origin" stranger = str "human"
        && get "state" stranger = str "unowned"
        && get "owner" stranger = `Null);
      Alcotest.(check int)
        "own-ehqa the adopted popup is alice's tab too" 2
        (List.length (listed tabs "alice" ~all:false));
      Alcotest.(check int)
        "own-ehqa bob sees neither popup" 0
        (List.length (listed tabs "bob" ~all:false));
      (* origin never changes: the report moves the page, not the tab *)
      announce fake ~id:"popup-target" ~opener:"gone-target"
        ~url:"https://example.com/moved" ~title:"Moved" ();
      destroy fake "stranger-target";
      barrier fake tabs "1";
      let moved = row_of_url tabs "https://example.com/moved" in
      Alcotest.(check bool)
        "own-ehqa the later report moved the page and nothing else" true
        (get "origin" moved = str "agent"
        && get "state" moved = str "owned"
        && get "owner" moved = str "alice");
      Alcotest.(check bool)
        "own-ehqa the stranger's tab is gone, not re-homed" false
        (List.exists
           (fun row -> text "url" row = "https://example.com/stranger")
           (all tabs));
      (* Chrome attaches to the popup right after announcing it; that is its session *)
      let popup_handle = handle moved in
      attach fake ~session:"popup-session" ~id:"popup-target" ~opener:"target-1"
        ~url:"https://example.com/moved" ~title:"Moved" ();
      barrier fake tabs "2";
      Alcotest.(check int)
        "own-ehqa the attachment added no second tab" 1
        (count_url tabs "https://example.com/moved");
      page_says fake "from the popup";
      let read =
        result
          (request tabs "alice"
             (P.Text { tab = popup_handle; index = None; max_chars = None }))
      in
      Alcotest.(check string)
        "own-ehqa the popup is usable" "from the popup" (text "text" read);
      let read_in_attached_session =
        received fake "Runtime.evaluate"
        |> List.exists (fun json -> field "sessionId" json = Some (str "popup-session"))
      in
      let attached_again =
        received_for fake "Target.attachToTarget" "targetId" (str "popup-target")
      in
      Alcotest.(check bool)
        "own-ehqa the popup ran in the attached session, without attaching again" true
        (read_in_attached_session && not attached_again))

(* own-teh1: a tab that goes away while Leash did not close it is closed_externally — the
   human's own tab, and an agent's tab a page or the human closed — while a tab Leash
   closed keeps closed_by_owner through the destroy report Chrome sends afterwards. *)
let tombstones () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      announce fake ~id:"human-target" ~url:"https://human.example/" ~title:"human" ();
      barrier fake tabs "0";
      let human = handle (row_of_url tabs "https://human.example/") in
      destroy fake "human-target";
      barrier fake tabs "1";
      check_disposition "own-teh1 a page or the human closed it" "closed_externally"
        (request tabs "alice" (P.Debug { tab = human; limit = None; clear = None }));
      (* an agent's tab, closed from outside Leash: the tab was Leash's, the close was not *)
      let mine = result (request tabs "alice" (P.New { url = None })) |> handle in
      destroy fake "target-1";
      barrier fake tabs "2";
      check_disposition "own-teh1 the human closed my tab" "closed_externally"
        (request tabs "alice" (P.Debug { tab = mine; limit = None; clear = None }));
      (* Leash's own close: Chrome reports the destroy afterwards, and the tombstone still
         says who closed the tab *)
      let closed = result (request tabs "alice" (P.New { url = None })) |> handle in
      ignore (result (request tabs "alice" (P.Close { tab = closed; force = None })));
      destroy fake "target-1";
      barrier fake tabs "3";
      check_disposition "own-teh1 Leash's close is not a stranger's" "closed_by_owner"
        (request tabs "alice" (P.Debug { tab = closed; limit = None; clear = None })))

(* tab-a7l3: claiming a discovered tab is the moment it stops being lazy. Discovery only
   records the session Chrome reports and enables nothing (own-c0cl), while the claim
   enables the page's event domains in that session, so a [debug] from the claim on covers
   console, exception and failed-request entries for the tab the agent now holds. *)
let claimed_debug () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      Fake.emit fake ~method_:"Target.attachedToTarget"
        ~params:
          (obj
             [
               ("sessionId", str "human-session");
               ( "targetInfo",
                 target_info ~url:"https://human.example/" ~title:"human" "human-target"
               );
               ("waitingForDebugger", `Bool false);
             ]);
      barrier fake tabs "0";
      let h = handle (row_of_url tabs "https://human.example/") in
      Alcotest.(check int)
        "tab-a7l3 discovery enabled nothing for the tab" 0
        (List.length (received_in fake "Runtime.enable" "human-session"));
      ignore (result (request tabs "alice" (P.Claim { tab = h })));
      List.iter
        (fun method_ ->
          Alcotest.(check int)
            ("tab-a7l3 the claim enabled " ^ method_)
            1
            (List.length (received_in fake method_ "human-session")))
        [ "Page.enable"; "Runtime.enable"; "Network.enable" ];
      Fake.emit ~session:"human-session" fake ~method_:"Runtime.consoleAPICalled"
        ~params:
          (obj
             [
               ("type", str "log");
               ("args", `List [ obj [ ("value", str "held by alice") ] ]);
             ]);
      Fake.emit ~session:"human-session" fake ~method_:"Runtime.exceptionThrown"
        ~params:(obj [ ("exceptionDetails", obj [ ("text", str "boom") ]) ]);
      Fake.emit ~session:"human-session" fake ~method_:"Network.loadingFailed"
        ~params:(obj [ ("errorText", str "net::ERR_FAILED") ]);
      barrier fake tabs "1";
      let entries =
        match
          get "entries"
            (result
               (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None })))
        with
        | `List entries -> entries
        | _ -> Alcotest.fail "debug entries must be an array"
      in
      let texts =
        List.filter_map
          (fun entry -> match get "text" entry with `String s -> Some s | _ -> None)
          entries
      in
      let kinds =
        List.filter_map
          (fun entry -> match get "kind" entry with `String s -> Some s | _ -> None)
          entries
      in
      Alcotest.(check bool)
        "tab-a7l3 the console message from the claim on" true
        (List.mem "held by alice" texts);
      Alcotest.(check bool) "tab-a7l3 the uncaught exception" true (List.mem "boom" texts);
      Alcotest.(check bool)
        "tab-a7l3 the failed request" true
        (List.mem "net::ERR_FAILED" texts);
      Alcotest.(check (list string))
        "tab-a7l3 with their kinds"
        [ "console"; "exception"; "request-failed" ]
        (List.sort String.compare kinds))

let () =
  Alcotest.run "L12 origin and discovery"
    [
      ( "discovery",
        [
          Alcotest.test_case "own-c0cl" `Quick discovered_human;
          Alcotest.test_case "own-c0cl own-ehqa" `Quick created_not_discovered;
          Alcotest.test_case "own-ehqa" `Quick adopted_popup;
        ] );
      ("tombstones", [ Alcotest.test_case "own-teh1" `Quick tombstones ]);
      ("claim", [ Alcotest.test_case "tab-a7l3" `Quick claimed_debug ]);
    ]
