(* L11 — owner state and authorization (docs/issues/tab-ownership/01-tab-ownership.md,
   milestone 3). Stories: own-6ndc own-pmr7 own-jua9 own-0np9 own-2zs7 own-82jd own-7pzw
   own-0pnk; hand-nisr, the refusal a handed-off tab answers with, for the [With_human]
   state the milestone-3 owner model carries. Everything runs at the control-protocol
   seam: two clients, alice and bob, the fake browser, no real Chrome. *)
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

(* One request, exactly as the CLI sends it: encoded to the wire, dispatched by the
   service, decoded back. *)
let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
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
        Eta_observability.Logger.create ~service:"leash-ownership-tests" ~clock:env#clock
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

(* [nav] waits for the document (chrome-1yn9 chrome-qnul) and the mock clock never moves,
   so every cell that sends one answers its load event here. *)
let loads fake =
  Fake.on_method fake "Page.navigate" (fun request ->
      let session =
        match get "sessionId" request with `String s -> s | _ -> assert false
      in
      Fake.emit ~session fake ~method_:"Page.loadEventFired"
        ~params:(Fake.event "Page.loadEventFired");
      obj [ ("frameId", str "frame-1"); ("loaderId", str "loader-1") ])

(* The owner state a cell is about. Every tab here is alice's where it has an owner, so
   "same" is alice and "other" is bob. *)
let fresh tabs ~state =
  let handle = result (request tabs "alice" (P.New { url = None })) |> tab in
  (match state with
  | `Owned -> ()
  | `Unowned ->
      ignore (result (request tabs "alice" (P.Release { tab = handle; force = None })))
  | `With_human -> (
      (* The handoff command itself is milestone 4 (hand-lz3p); this suite drives the
         transition it drives — the registry call without its wait, so the with-human
         cells exist without a request blocked on the mock clock. *)
      match Leash.Tabs.hand_over tabs ~owner:(owner "alice") ~reason:"captcha" handle with
      | Ok _ -> ()
      | Error e -> Alcotest.failf "hand_over: %s" (P.Error_code.to_string e.code)));
  handle

(* Every command that touches a page — the [Act] class — plus [dialog], whose class is its
   own. One representative per wire command, so no command can slip past the single
   authorization function. *)
let page_commands handle : (string * P.command) list =
  let snapshot =
    match P.Snapshot_id.of_string "s_matrix" with Ok s -> s | Error e -> Alcotest.fail e
  in
  [
    ("nav", P.Nav { tab = handle; url = "about:blank" });
    ("snap", P.Snap { tab = handle; match_ = None; limit = Some 1; offset = None });
    ("text", P.Text { tab = handle; index = None; max_chars = None });
    ("eval", P.Eval { tab = handle; expression = "1"; argument = None });
    ("shot", P.Shot { tab = handle; path = "/tmp/leash-ownership.png"; full_page = None });
    ("debug", P.Debug { tab = handle; limit = None; clear = None });
    ( "wait",
      P.Wait
        {
          tab = handle;
          until = { url_prefix = None; text = None; index_gone = None; dialog = None };
          timeout_ms = Some 1;
        } );
    ("click", P.Click { tab = handle; snapshot; index = 1 });
    ("fill", P.Fill { tab = handle; snapshot; index = 1; text = "x" });
    ("press", P.Press { tab = handle; snapshot; index = Some 1; key = "Enter" });
    ("select", P.Select { tab = handle; snapshot; index = 1; option = 0 });
    ( "scroll",
      P.Scroll
        { tab = handle; direction = enum P.Direction.of_string "down"; index = None } );
    ( "dialog",
      P.Dialog { tab = handle; answer = enum P.Answer.of_string "accept"; text = None } );
  ]

let access_of = function "dialog" -> `Dialog | _ -> `Act

type expectation = Allow | Refuse of string

(* The authorization table of ADR-0005, written out here rather than derived from the code
   under test: for every command class, every owner state, and the caller being the tab's
   owner or not, with and without the force flag.

   - acting, answering a dialog, releasing, and closing require ownership; a tab nobody
     owns answers not-owner and a handed-off tab answers with-human, its owner included;
   - claiming requires a tab nobody owns, so anything else is already-owned;
   - force is honoured for close and release alone, and then allows the command whatever
     the state. *)
let expectation ~access ~state ~caller ~force =
  match access with
  | `Claim -> (
      match state with
      | `Unowned -> Allow
      | `Owned | `With_human -> Refuse "already-owned")
  | `Act | `Dialog | `Close | `Release -> (
      if force && (access = `Close || access = `Release) then Allow
      else
        match state with
        | `Owned -> if caller = "alice" then Allow else Refuse "not-owner"
        | `Unowned -> Refuse "not-owner"
        | `With_human -> Refuse "with-human")

(* A refused command must answer with the refusal the table names; an allowed one must get
   past the gate. What an allowed command then does to the page — a stale snapshot, an
   absent dialog, a CDP call the fake browser does not answer — is the command's own
   business, so only the three refusal codes are wrong. *)
let check_cell ~label ~tabs ~who ~command ~expectation =
  match expectation with
  | Allow -> (
      match request tabs who command with
      | P.Success _ -> ()
      | P.Failure e ->
          let code = P.Error_code.to_string e.code in
          if List.mem code [ "not-owner"; "already-owned"; "with-human" ] then
            Alcotest.failf "%s: the table allows it, the service refused with %s" label
              code)
  | Refuse expected -> check_code label expected (request tabs who command)

(* own-pmr7 own-0np9 own-2zs7 own-7pzw own-0pnk hand-nisr: every cell — each command ×
   each state × caller same/other × forced or not — with bob as the second client. *)
let authorization () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      loads fake;
      let states =
        [ ("unowned", `Unowned); ("owned", `Owned); ("with_human", `With_human) ]
      in
      let callers = [ ("same", "alice"); ("other", "bob") ] in
      List.iter
        (fun (state_name, state) ->
          List.iter
            (fun (caller_name, caller) ->
              let label name = name ^ "/" ^ state_name ^ "/" ^ caller_name in
              (* the page commands, none of which changes the state *)
              let handle = fresh tabs ~state in
              List.iter
                (fun (name, command) ->
                  check_cell ~label:(label name) ~tabs ~who:caller ~command
                    ~expectation:
                      (expectation ~access:(access_of name) ~state ~caller ~force:false))
                (page_commands handle);
              check_cell ~label:(label "claim") ~tabs ~who:caller
                ~command:(P.Claim { tab = fresh tabs ~state })
                ~expectation:(expectation ~access:`Claim ~state ~caller ~force:false);
              (* release and close: each on its own tab, because a permitted one changes
                 the state the next cell would see *)
              List.iter
                (fun (how, force) ->
                  check_cell
                    ~label:(label ("release " ^ how))
                    ~tabs ~who:caller
                    ~command:(P.Release { tab = fresh tabs ~state; force })
                    ~expectation:
                      (expectation ~access:`Release ~state ~caller ~force:(force <> None)))
                [ ("plain", None); ("forced", Some true) ];
              List.iter
                (fun (how, force) ->
                  check_cell
                    ~label:(label ("close " ^ how))
                    ~tabs ~who:caller
                    ~command:(P.Close { tab = fresh tabs ~state; force })
                    ~expectation:
                      (expectation ~access:`Close ~state ~caller ~force:(force <> None)))
                [ ("plain", None); ("forced", Some true) ])
            callers)
        states)

(* own-6ndc: the tab an agent creates is owned by that agent and nobody else may use it. *)
let created_owned () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let info = result (request tabs "alice" (P.New { url = None })) in
      let h = tab info in
      Alcotest.(check bool)
        "own-6ndc owned by its creator, agent origin" true
        (get "state" info = str "owned"
        && get "owner" info = str "alice"
        && get "origin" info = str "agent");
      ignore
        (result (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None })));
      check_code "own-6ndc bob is refused" "not-owner"
        (request tabs "bob" (P.Debug { tab = h; limit = None; clear = None })))

(* own-jua9 own-0np9: claim takes a tab nobody owns — which is how an agent picks up a
   page the human prepared — and never one somebody owns. *)
let claiming () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      ignore (result (request tabs "alice" (P.Release { tab = h; force = None })));
      let listed = rows (result (request tabs "bob" (P.List_tabs { all = true }))) in
      let row = find_tab listed h in
      Alcotest.(check bool)
        "own-82jd a released tab is listed unowned with no owner" true
        (get "state" row = str "unowned" && get "owner" row = `Null);
      let claimed = result (request tabs "bob" (P.Claim { tab = h })) in
      Alcotest.(check bool)
        "own-jua9 the claimer owns it now" true
        (get "state" claimed = str "owned" && get "owner" claimed = str "bob");
      check_code "own-0np9 alice cannot take it back" "already-owned"
        (request tabs "alice" (P.Claim { tab = h }));
      check_code "own-0np9 the owner cannot claim it again" "already-owned"
        (request tabs "bob" (P.Claim { tab = h }));
      ignore
        (result (request tabs "bob" (P.Debug { tab = h; limit = None; clear = None })));
      check_code "own-jua9 alice is out of it" "not-owner"
        (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None })))

(* own-2zs7: release makes the caller's tab unowned without closing it, so the page stays
   up for the next claimer. *)
let releasing () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      let released =
        result (request tabs "alice" (P.Release { tab = h; force = None }))
      in
      Alcotest.(check bool) "own-2zs7 released" true (get "released" released = `Bool true);
      let row =
        find_tab (rows (result (request tabs "alice" (P.List_tabs { all = true })))) h
      in
      Alcotest.(check bool)
        "own-2zs7 unowned and ownerless" true
        (get "state" row = str "unowned" && get "owner" row = `Null);
      let closed =
        Fake.received fake
        |> List.filter (fun json -> field "method" json = Some (str "Target.closeTarget"))
      in
      Alcotest.(check int) "own-2zs7 the page was not closed" 0 (List.length closed);
      check_code "own-2zs7 releasing nobody's tab is not-owner" "not-owner"
        (request tabs "bob" (P.Release { tab = h; force = None })))

(* own-82jd: [list] shows the caller's tabs only, and [--all] every tab with origin,
   state, and owner. *)
let listing () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let alice = result (request tabs "alice" (P.New { url = None })) |> tab in
      let bob = result (request tabs "bob" (P.New { url = None })) |> tab in
      let count who all =
        List.length (rows (result (request tabs who (P.List_tabs { all }))))
      in
      Alcotest.(check int) "own-82jd alice sees her one tab" 1 (count "alice" false);
      Alcotest.(check int) "own-82jd bob sees his own" 1 (count "bob" false);
      Alcotest.(check int) "own-82jd --all sees both" 2 (count "alice" true);
      let all = rows (result (request tabs "alice" (P.List_tabs { all = true }))) in
      let row = find_tab all alice in
      Alcotest.(check bool)
        "own-82jd origin, state and owner are there" true
        (get "origin" row = str "agent"
        && get "state" row = str "owned"
        && get "owner" row = str "alice");
      ignore (find_tab all bob))

(* own-7pzw: closing my tab is idempotent and closing another's is not-owner, so cleanup
   is safe and bounded to what is mine. *)
let closing () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      check_code "own-7pzw bob cannot close it" "not-owner"
        (request tabs "bob" (P.Close { tab = h; force = None }));
      Alcotest.(check bool)
        "own-7pzw alice closes it" true
        (get "closed" (result (request tabs "alice" (P.Close { tab = h; force = None })))
        = `Bool true);
      Alcotest.(check bool)
        "own-7pzw closing it again is a no-op, not an error" true
        (get "closed" (result (request tabs "alice" (P.Close { tab = h; force = None })))
        = `Bool true);
      check_code "own-7pzw and bob still cannot close it" "not-owner"
        (request tabs "bob" (P.Close { tab = h; force = None })))

(* own-0pnk: --force releases and closes any tab — the one another agent owns and the one
   the human holds — and every use is logged for the human to audit. *)
let force () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs ->
      let h = result (request tabs "alice" (P.New { url = None })) |> tab in
      check_code "own-0pnk not bob's without force" "not-owner"
        (request tabs "bob" (P.Release { tab = h; force = None }));
      Alcotest.(check bool)
        "own-0pnk bob releases it with force" true
        (get "released"
           (result (request tabs "bob" (P.Release { tab = h; force = Some true })))
        = `Bool true);
      Alcotest.(check string)
        "own-0pnk the forced release left it unowned" "unowned"
        (text "state"
           (find_tab (rows (result (request tabs "bob" (P.List_tabs { all = true })))) h));
      (* the tab the human holds, which even its owner cannot close *)
      let held = fresh tabs ~state:`With_human in
      check_code "own-0pnk the hold refuses its owner" "with-human"
        (request tabs "alice" (P.Close { tab = held; force = None }));
      Alcotest.(check bool)
        "own-0pnk bob closes the held tab with force" true
        (get "closed"
           (result (request tabs "bob" (P.Close { tab = held; force = Some true })))
        = `Bool true);
      let other = result (request tabs "alice" (P.New { url = None })) |> tab in
      let before = List.length (Fake.received fake) in
      Alcotest.(check bool)
        "own-0pnk bob closes another agent's tab with force" true
        (get "closed"
           (result (request tabs "bob" (P.Close { tab = other; force = Some true })))
        = `Bool true);
      Alcotest.(check bool)
        "own-0pnk the forced close reached Chrome" true
        (Fake.received fake
        |> List.filteri (fun i _ -> i >= before)
        |> List.exists (fun json -> field "method" json = Some (str "Target.closeTarget"))
        );
      Alcotest.(check bool)
        "own-0pnk a forced close is idempotent for whoever forced it" true
        (get "closed"
           (result (request tabs "bob" (P.Close { tab = other; force = Some true })))
        = `Bool true);
      let module Log = Eta_observability.Logger in
      let forced cmd = Log.Memory.find ~level:Log.Warn ~field:("cmd", cmd) logs in
      Alcotest.(check bool)
        "own-0pnk a forced release is logged" true
        (forced "release" <> []);
      Alcotest.(check bool)
        "own-0pnk every forced command is logged" true
        (List.length (forced "release" @ forced "close") >= 4);
      let named (record : Log.record) name expected =
        match List.assoc_opt name record.fields with
        | Some value -> Format.asprintf "%a" Log.pp_value value = expected
        | None -> false
      in
      Alcotest.(check bool)
        "own-0pnk the record names the caller, the tab and the state it overrode" true
        (List.exists
           (fun (record : Log.record) ->
             record.msg = "ownership forced"
             && named record "cmd" "close" && named record "owner" "bob"
             && named record "state" "with_human"
             && List.mem_assoc "tab" record.fields)
           (forced "close"));
      (* force is release/close only: a record type that does not carry the key refuses it *)
      let raw =
        Yojson.Safe.from_string
          (Leash.Control.handle tabs
             {|{"v":1,"owner":"bob","cmd":"claim","args":{"tab":"t_x","force":true}}|})
      in
      Alcotest.(check bool)
        "own-0pnk a forced claim is not a request at all" true
        (get "code" (get "error" raw) = str "invalid-request"))

(* hand-nisr, own-0np9 own-2zs7: a tab the human holds is out of every agent's reach —
   its owner's included — until resume, and only --force overrides the hold. *)
let with_human () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake:_ ~logs:_ ->
      let h = fresh tabs ~state:`With_human in
      let row =
        find_tab (rows (result (request tabs "alice" (P.List_tabs { all = true })))) h
      in
      Alcotest.(check bool)
        "hand-nisr still listed as alice's, with_human" true
        (get "state" row = str "with_human" && get "owner" row = str "alice");
      let refused label who command =
        check_code label "with-human" (request tabs who command)
      in
      refused "hand-nisr its owner cannot observe" "alice"
        (P.Snap { tab = h; match_ = None; limit = None; offset = None });
      refused "hand-nisr its owner cannot close" "alice"
        (P.Close { tab = h; force = None });
      refused "hand-nisr its owner cannot release" "alice"
        (P.Release { tab = h; force = None });
      refused "hand-nisr a stranger cannot act" "bob"
        (P.Debug { tab = h; limit = None; clear = None });
      check_code "own-0np9 a held tab is nobody's to claim" "already-owned"
        (request tabs "bob" (P.Claim { tab = h }));
      Alcotest.(check int)
        "hand-nisr its owner still lists it" 1
        (List.length (rows (result (request tabs "alice" (P.List_tabs { all = false })))));
      Alcotest.(check int)
        "hand-nisr a stranger does not" 0
        (List.length (rows (result (request tabs "bob" (P.List_tabs { all = false })))));
      ignore (result (request tabs "bob" (P.Release { tab = h; force = Some true })));
      Alcotest.(check string)
        "own-2zs7 the forced release made it unowned" "unowned"
        (text "state"
           (find_tab (rows (result (request tabs "bob" (P.List_tabs { all = true })))) h));
      ignore (result (request tabs "bob" (P.Claim { tab = h })));
      ignore
        (result (request tabs "bob" (P.Debug { tab = h; limit = None; clear = None }))))

(* own-c0cl own-jua9: a tab Leash discovers from outside the protocol — the human's — is
   human-origin and unowned, and an agent claims it to work on the page the human
   prepared. *)
let discovered_human () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      Fake.emit fake ~method_:"Target.attachedToTarget"
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
        if n = 0 then Alcotest.fail "the human tab was not adopted"
        else
          match rows (result (request tabs "alice" (P.List_tabs { all = true }))) with
          | [ _ ] -> ()
          | _ ->
              Eio.Fiber.yield ();
              await (n - 1)
      in
      await 1000;
      let row =
        match rows (result (request tabs "alice" (P.List_tabs { all = true }))) with
        | [ row ] -> row
        | _ -> Alcotest.fail "exactly one tab is expected"
      in
      Alcotest.(check bool)
        "own-c0cl human origin, unowned, ownerless" true
        (get "origin" row = str "human"
        && get "state" row = str "unowned"
        && get "owner" row = `Null);
      let h = tab row in
      check_code "own-jua9 nobody acts on it unclaimed" "not-owner"
        (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None }));
      let claimed = result (request tabs "alice" (P.Claim { tab = h })) in
      Alcotest.(check bool)
        "own-jua9 claimed, origin kept" true
        (get "state" claimed = str "owned"
        && get "owner" claimed = str "alice"
        && get "origin" claimed = str "human");
      ignore
        (result (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None }))))

(* own-ehqa (the L10 opener-based adoption, now carrying an owner state): a popup a page
   opens from an agent's tab is that agent's tab, while a target whose opener Leash does
   not know is a human's and unowned. The target info is the recorded headless Chrome 152
   shape with [openerId] (test/fixtures/unlabelled-controls-chrome.json). *)
let adopted_popup () =
  rig (fun ~env:_ ~sw:_ ~tabs ~fake ~logs:_ ->
      let fixture () =
        let load path = Yojson.Safe.from_file path in
        try load "fixtures/unlabelled-controls-chrome.json"
        with Sys_error _ -> load "test/fixtures/unlabelled-controls-chrome.json"
      in
      let attached =
        get "popup" (fixture ()) |> fun popup -> get "attached_to_target" popup
      in
      let base =
        match get "targetInfo" attached with `Assoc fields -> fields | _ -> []
      in
      let set key value fields = (key, value) :: List.remove_assoc key fields in
      let popup ~session ~target ~opener ~url =
        Fake.emit fake ~method_:"Target.attachedToTarget"
          ~params:
            (obj
               [
                 ("sessionId", str session);
                 ("waitingForDebugger", `Bool false);
                 ( "targetInfo",
                   obj
                     (set "url" (str url)
                     @@ set "title" (str "Popup")
                     @@ set "targetId" (str target)
                     @@ set "openerId" (str opener) base) );
               ])
      in
      let parent = result (request tabs "alice" (P.New { url = None })) |> tab in
      ignore parent;
      (* the fake browser creates every target as "target-1", which is what the parent got *)
      popup ~session:"popup-session" ~target:"popup-target" ~opener:"target-1"
        ~url:"https://example.com/popup";
      popup ~session:"stranger-session" ~target:"stranger-target" ~opener:"gone-target"
        ~url:"https://example.com/stranger";
      let listed () = rows (result (request tabs "alice" (P.List_tabs { all = true }))) in
      let rec await n =
        if n = 0 then Alcotest.fail "the popups were not adopted"
        else
          match listed () with
          | [ _; _; _ ] -> ()
          | _ ->
              Eio.Fiber.yield ();
              await (n - 1)
      in
      await 1000;
      let find url =
        match List.find_opt (fun row -> text "url" row = url) (listed ()) with
        | Some row -> row
        | None -> Alcotest.failf "%s is not listed" url
      in
      let mine = find "https://example.com/popup" in
      Alcotest.(check bool)
        "own-ehqa the popup is the opener agent's tab" true
        (get "origin" mine = str "agent"
        && get "state" mine = str "owned"
        && get "owner" mine = str "alice");
      let stranger = find "https://example.com/stranger" in
      Alcotest.(check bool)
        "own-ehqa an unknown opener leaves a human's unowned tab" true
        (get "origin" stranger = str "human"
        && get "state" stranger = str "unowned"
        && get "owner" stranger = `Null);
      Alcotest.(check int)
        "own-ehqa the adopted popup is alice's tab too" 2
        (List.length (rows (result (request tabs "alice" (P.List_tabs { all = false })))));
      Alcotest.(check int)
        "own-ehqa a stranger sees neither of them" 0
        (List.length (rows (result (request tabs "bob" (P.List_tabs { all = false }))))))

let () =
  Alcotest.run "L11 owner state and authorization"
    [
      ( "authorization",
        [
          Alcotest.test_case "own-pmr7 own-0np9 own-2zs7 own-7pzw own-0pnk hand-nisr"
            `Quick authorization;
          Alcotest.test_case "own-0pnk force" `Quick force;
          Alcotest.test_case "hand-nisr own-0np9 own-2zs7 with-human" `Quick with_human;
        ] );
      ( "ownership",
        [
          Alcotest.test_case "own-6ndc" `Quick created_owned;
          Alcotest.test_case "own-jua9 own-0np9 own-82jd" `Quick claiming;
          Alcotest.test_case "own-2zs7" `Quick releasing;
          Alcotest.test_case "own-82jd" `Quick listing;
          Alcotest.test_case "own-7pzw" `Quick closing;
          Alcotest.test_case "own-c0cl own-jua9" `Quick discovered_human;
          Alcotest.test_case "own-ehqa" `Quick adopted_popup;
        ] );
    ]
