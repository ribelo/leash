(* L16 — handoff and resume (docs/issues/human-handoff/01-human-handoff.md, milestone 4).
   Stories: hand-lz3p hand-0sja hand-nisr hand-lmd5 hand-len8 hand-r4t1 hand-beip
   hand-yytf hand-szz7. Everything runs at the control-protocol seam over the fake
   browser with the mock clock: a handoff is a request that blocks, so a test forks it
   exactly as the CLI holds its connection open and then does what the human would —
   resume, wait out the deadline, close the terminal, or lose the browser — while the
   service runs in the same process. *)
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

let owner name =
  match P.Owner.of_string name with Ok x -> x | Error e -> Alcotest.fail e

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

(* One request, exactly as the CLI sends it: encoded to the wire, dispatched by the
   service, decoded back. The handoff and the resume both arrive this way; the only
   difference is that the handoff is sent from a fiber of its own, because it does not
   answer until the human does. *)
let request tabs who command =
  let wire = P.encode_request { owner = owner who; command } |> Yojson.Safe.to_string in
  match P.decode_reply (Yojson.Safe.from_string (Leash.Control.handle tabs wire)) with
  | Ok x -> x
  | Error e -> Alcotest.fail e

let listed tabs =
  match get "tabs" (result (request tabs "alice" (P.List_tabs { all = true }))) with
  | `List rows -> rows
  | other -> Alcotest.failf "tabs: %s" (Yojson.Safe.to_string other)

let find handle rows =
  let wanted = P.Handle.to_string handle in
  List.find_opt (fun row -> get "tab" row = str wanted) rows

let row tabs handle =
  match find handle (listed tabs) with
  | Some row -> row
  | None -> Alcotest.failf "tab %s is gone" (P.Handle.to_string handle)

let state tabs handle =
  match find handle (listed tabs) with Some row -> text "state" row | None -> "gone"

let owner_of tabs handle =
  match get "owner" (row tabs handle) with `String s -> Some s | _ -> None

(* hand-r4t1: the reason the human was given, absent from every tab nobody waits on. *)
let reason tabs handle =
  match find handle (listed tabs) with
  | Some row -> (
      match opt "reason" row with Some (`String reason) -> Some reason | _ -> None)
  | None -> None

let expires tabs handle =
  match get "expires" (row tabs handle) with
  | `Assoc [ ("stage", `String stage); ("in_s", `Int seconds) ] -> (stage, seconds)
  | other -> Alcotest.failf "expires: %s" (Yojson.Safe.to_string other)

let no_stage tabs handle =
  match get "expires" (row tabs handle) with `Null -> true | _ -> false

let handle_new tabs = handle_of (result (request tabs "alice" (P.New { url = None })))
let reply = function None -> Alcotest.fail "no reply" | Some reply -> reply
let answered cell = match !cell with Some _ -> true | None -> false

(* The sweep is one fiber on the mock clock, parked for an hour here, and time passes
   only when a test moves the clock. *)
let advance env seconds = Ox_test.advance env#clock (Ox.Duration.seconds seconds)

let rec until n what check =
  if check () then ()
  else if n = 0 then Alcotest.failf "the test never saw %s" what
  else (
    Eio.Fiber.yield ();
    until (n - 1) what check)

let rig ?(idle = 30) ?(unclaimed = 60) f =
  Ox_test.run (fun env sw ->
      let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
      let current = ref None in
      let launch ~sw ~clock ~mgr:_ config =
        let fake, client = Fake.create ~sw () in
        current := Some fake;
        match
          Ox_process.Child.spawn ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
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
        Chrome.create ~sw ~launch
          (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-test-profile"
             ~workspace:"test" ~headless:true ())
          { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
      in
      let idle = Ox.Duration.seconds idle in
      let unclaimed = Ox.Duration.seconds unclaimed in
      let tabs =
        Tabs.create ~sw ~cap:128 ~tombstone_s:3600 ~idle ~unclaimed
          { Tabs.chrome; clock = env#clock; logger; desktop = Leash.Desktop.disabled }
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
      let expiry =
        Expiry.create ~sw ~interval:(Ox.Duration.hours 1) ~idle ~unclaimed
          ~clock:env#clock ~logger tabs
      in
      f ~env ~sw ~tabs ~expiry ~fake)

(* hand-lz3p hand-0sja hand-nisr hand-r4t1: the handoff blocks until the human resumes
   it, the tab is the human's while it waits — its owner's commands included — and
   [list --all] says so, with the reason. The reply carries the page as the human left
   it, which is what the agent re-observes from. *)
let blocks_until_resume () =
  rig (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake ->
      let h = handle_new tabs in
      Fake.emit fake ~method_:"Target.targetInfoChanged"
        ~params:
          (obj
             [
               ( "targetInfo",
                 obj
                   [
                     ("targetId", str "target-1");
                     ("type", str "page");
                     ("url", str "https://example.com/login");
                     ("title", str "Sign in");
                   ] );
             ]);
      until 1000 "the tab report the page it is on" (fun () ->
          text "url" (row tabs h) = "https://example.com/login");
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      Alcotest.(check bool)
        "hand-lz3p the request waits instead of answering" false (answered cell);
      Alcotest.(check string)
        "hand-r4t1 list --all shows with_human" "with_human" (state tabs h);
      Alcotest.(check (option string))
        "hand-r4t1 with the reason the human was given" (Some "captcha") (reason tabs h);
      Alcotest.(check (option string))
        "hand-r4t1 still the owner's tab" (Some "alice") (owner_of tabs h);
      Alcotest.(check bool)
        "hand-len8 a handed-off tab faces no timer" true (no_stage tabs h);
      check_code "hand-nisr its owner cannot observe it" "with-human"
        (request tabs "alice" (P.Debug { tab = h; limit = None; clear = None }));
      check_code "hand-nisr its owner cannot close it" "with-human"
        (request tabs "alice" (P.Close { tab = h; force = None }));
      check_code "hand-nisr a stranger cannot act on it either" "with-human"
        (request tabs "bob"
           (P.Snap { tab = h; match_ = None; limit = None; offset = None }));
      Alcotest.(check bool)
        "hand-0sja the human resumes from a terminal that is not the owner's" true
        (get "resumed" (result (request tabs "human" (P.Resume { tab = h }))) = `Bool true);
      until 1000 "the blocked request answer" (fun () -> answered cell);
      let answer = result (reply !cell) in
      Alcotest.(check bool) "hand-lz3p resumed" true (get "resumed" answer = `Bool true);
      Alcotest.(check string)
        "hand-lz3p with the page's url" "https://example.com/login" (text "url" answer);
      Alcotest.(check string) "hand-lz3p and its title" "Sign in" (text "title" answer);
      Alcotest.(check string)
        "hand-0sja the tab is the agent's again" "owned" (state tabs h);
      Alcotest.(check (option string))
        "hand-0sja and still alice's" (Some "alice") (owner_of tabs h);
      Alcotest.(check (option string))
        "hand-r4t1 the reason went with the handoff" None (reason tabs h);
      Alcotest.(check int)
        "hand-lz3p the handoff reached Chrome for nothing" 0
        (Fake.received fake
        |> List.filter (fun json -> field "method" json = Some (str "Target.closeTarget"))
        |> List.length))

(* hand-lmd5 hand-szz7: the deadline ends an ignored handoff with [timeout] and gives the
   tab back to the agent, and a resume that arrives afterwards finds nothing to resume. *)
let timeout_restores_the_owner () =
  rig (fun ~env ~sw ~tabs ~expiry:_ ~fake:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "2fa code"; timeout_s = Some 60 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      advance env 59;
      Alcotest.(check bool)
        "hand-lmd5 a second short of the deadline it is still waiting" false
        (answered cell);
      Alcotest.(check string)
        "hand-lmd5 and still the human's" "with_human" (state tabs h);
      advance env 1;
      until 1000 "the deadline end the handoff" (fun () -> answered cell);
      check_code "hand-lmd5 the ignored handoff answers timeout" "timeout" (reply !cell);
      Alcotest.(check string)
        "hand-lmd5 the tab is the agent's again" "owned" (state tabs h);
      Alcotest.(check (option string))
        "hand-lmd5 owned by the agent that handed it over" (Some "alice")
        (owner_of tabs h);
      Alcotest.(check (option string))
        "hand-lmd5 with nothing left to resume" None (reason tabs h);
      check_code "hand-szz7 a late resume is no-handoff" "no-handoff"
        (request tabs "human" (P.Resume { tab = h })))

(* hand-lmd5: the deadline is the contract's fifteen minutes unless the caller names one,
   and the handler's budget outlasts it — a budget equal to the deadline would cancel the
   handler exactly when it is due to answer [timeout]. *)
let defaults_and_budget () =
  Alcotest.(check int)
    "hand-lmd5 fifteen minutes when the caller names no deadline" 900_000
    (Ox.Duration.to_ms (Tabs.handoff_timeout None));
  Alcotest.(check int)
    "hand-lmd5 the caller's deadline otherwise" 60_000
    (Ox.Duration.to_ms (Tabs.handoff_timeout (Some 60)));
  let budget timeout_s =
    match
      Leash.Control.budget
        (Ok
           {
             P.owner = owner "alice";
             command =
               P.Handoff { tab = handle "t_budget"; reason = "captcha"; timeout_s };
           })
    with
    | Some budget -> Ox.Duration.to_ms budget
    | None -> Alcotest.fail "a handoff has no handler budget"
  in
  Alcotest.(check bool)
    "hand-lmd5 the handler outlives the default deadline" true
    (budget None > Ox.Duration.to_ms (Tabs.handoff_timeout None));
  Alcotest.(check bool)
    "hand-lmd5 and the caller's" true
    (budget (Some 60) > Ox.Duration.to_ms (Tabs.handoff_timeout (Some 60)))

(* hand-len8 hand-0sja: the sweep leaves the tab the human holds alone however long the
   human takes, and the resume restarts the idle clock, so the work the human just did
   does not expire the agent's tab a moment later. *)
let idle_clock () =
  rig ~idle:30 ~unclaimed:60 (fun ~env ~sw ~tabs ~expiry ~fake:_ ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      advance env 600;
      Alcotest.(check int)
        "hand-len8 a sweep ten minutes into the handoff acts on nothing" 0
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string)
        "hand-len8 the tab is still the human's" "with_human" (state tabs h);
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell);
      Alcotest.(check (pair string int))
        "hand-0sja the resume restarts the idle countdown" ("release", 30)
        (expires tabs h);
      advance env 29;
      Alcotest.(check int)
        "hand-0sja a second short of idle nothing is due" 0
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string)
        "hand-0sja and the tab is still owned" "owned" (state tabs h);
      advance env 1;
      Alcotest.(check int)
        "hand-0sja at the idle duration, measured from the resume, it is released" 1
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "hand-0sja released" "unowned" (state tabs h))

(* hand-lz3p hand-szz7: the agent's terminal dies mid-handoff. The listener runs one
   handler per peer as the first branch of a [Fiber.first] whose second branch is the peer
   monitor, so a client that goes away cancels the blocked handler — this is that shape,
   and the loser is cancelled and awaited before [Fiber.first] returns — and the tab comes
   back to its owner with nothing left to resume. *)
let disconnect_restores_the_owner () =
  rig (fun ~env:_ ~sw:_ ~tabs ~expiry:_ ~fake:_ ->
      let h = handle_new tabs in
      let answered = ref false in
      Eio.Fiber.first
        (fun () ->
          ignore
            (request tabs "alice"
               (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 }));
          answered := true)
        (fun () ->
          (* the client: it waits for the handoff to reach the human, then its
             connection closes *)
          until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human"));
      Alcotest.(check bool)
        "hand-lz3p the abandoned request never answered" false !answered;
      Alcotest.(check string)
        "hand-lz3p the tab is the agent's again" "owned" (state tabs h);
      Alcotest.(check (option string))
        "hand-lz3p alice has it back" (Some "alice") (owner_of tabs h);
      Alcotest.(check (option string))
        "hand-lz3p with no handoff left on it" None (reason tabs h);
      check_code "hand-szz7 and nothing to resume" "no-handoff"
        (request tabs "human" (P.Resume { tab = h })))

(* hand-yytf: the browser dies while the request waits, and the wait ends with the
   disposition that closed the tab rather than blocking on a page that is gone. *)
let browser_loss_ends_it () =
  rig (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake ->
      let h = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      Fake.drop fake;
      until 1000 "the lost browser end the handoff" (fun () -> answered cell);
      check_code "hand-yytf a browser loss ends the handoff" "tab-gone" (reply !cell);
      Alcotest.(check string)
        "hand-yytf with browser_lost" "browser_lost"
        (disposition (reply !cell));
      Alcotest.(check string) "hand-yytf and the tab is gone" "gone" (state tabs h))

(* own-0pnk hand-lz3p: a forced release or close of the tab the human holds ends the
   handoff at once — the agent must not wait out a deadline for a tab it no longer owns.
   The release answers the waiting request [not-owner] and leaves the tab unowned with no
   reason; the close answers [tab-gone] with the disposition that closed it. *)
let forced_endings () =
  rig (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake:_ ->
      (* --force release of a tab the human holds *)
      let released = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = released; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the handoff reach the human" (fun () ->
          state tabs released = "with_human");
      ignore
        (result (request tabs "bob" (P.Release { tab = released; force = Some true })));
      until 1000 "the forced release end the handoff" (fun () -> answered cell);
      check_code "own-0pnk hand-lz3p a forced release answers not-owner" "not-owner"
        (reply !cell);
      Alcotest.(check string)
        "own-0pnk hand-lz3p and the tab is unowned" "unowned" (state tabs released);
      Alcotest.(check (option string))
        "hand-r4t1 with no reason left on it" None (reason tabs released);
      check_code "hand-szz7 and nothing left to resume" "no-handoff"
        (request tabs "human" (P.Resume { tab = released }));
      (* --force close of a tab the human holds *)
      let closed = handle_new tabs in
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "alice"
                 (P.Handoff { tab = closed; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the handoff reach the human" (fun () ->
          state tabs closed = "with_human");
      ignore (result (request tabs "bob" (P.Close { tab = closed; force = Some true })));
      until 1000 "the forced close end the handoff" (fun () -> answered cell);
      check_code "own-0pnk hand-lz3p a forced close answers tab-gone" "tab-gone"
        (reply !cell);
      Alcotest.(check string)
        "own-0pnk with the disposition that closed it" "closed_by_owner"
        (disposition (reply !cell));
      Alcotest.(check string) "hand-lz3p and the tab is gone" "gone" (state tabs closed))

(* hand-beip: only the tab's owner can pull the human onto it, and a tab the human
   already holds is not handed over twice. *)
let handoff_is_the_owners () =
  rig (fun ~env:_ ~sw ~tabs ~expiry:_ ~fake:_ ->
      let h = handle_new tabs in
      check_code "hand-beip bob cannot hand alice's tab over" "not-owner"
        (request tabs "bob"
           (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 }));
      Alcotest.(check string) "hand-beip and the tab is untouched" "owned" (state tabs h);
      ignore (result (request tabs "alice" (P.Release { tab = h; force = None })));
      check_code "hand-beip nor a tab nobody owns" "not-owner"
        (request tabs "bob"
           (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 60 }));
      ignore (result (request tabs "bob" (P.Claim { tab = h })));
      let cell = ref None in
      Eio.Fiber.fork ~sw (fun () ->
          cell :=
            Some
              (request tabs "bob"
                 (P.Handoff { tab = h; reason = "captcha"; timeout_s = Some 3600 })));
      until 1000 "the handoff reach the human" (fun () -> state tabs h = "with_human");
      check_code "hand-beip a second handoff of the tab the human holds is with-human"
        "with-human"
        (request tabs "bob"
           (P.Handoff { tab = h; reason = "again"; timeout_s = Some 60 }));
      ignore (result (request tabs "human" (P.Resume { tab = h })));
      until 1000 "the blocked request answer" (fun () -> answered cell))

(* hand-szz7: a resume on a tab nobody is waiting on is [no-handoff] — never a quiet
   success, so a stale notification cannot do something surprising — while a handle whose
   tab is gone still answers like every other command. *)
let resume_without_a_handoff () =
  rig (fun ~env:_ ~sw:_ ~tabs ~expiry:_ ~fake:_ ->
      let owned = handle_new tabs in
      check_code "hand-szz7 an owned tab nobody handed over" "no-handoff"
        (request tabs "alice" (P.Resume { tab = owned }));
      Alcotest.(check string)
        "hand-szz7 and the refusal left it owned" "owned" (state tabs owned);
      let unowned = handle_new tabs in
      ignore (result (request tabs "alice" (P.Release { tab = unowned; force = None })));
      check_code "hand-szz7 an unowned tab" "no-handoff"
        (request tabs "human" (P.Resume { tab = unowned }));
      Alcotest.(check string)
        "hand-szz7 and the refusal left it unowned" "unowned" (state tabs unowned);
      let closed = handle_new tabs in
      ignore (result (request tabs "alice" (P.Close { tab = closed; force = None })));
      check_code "hand-szz7 a handle whose tab was closed" "tab-gone"
        (request tabs "alice" (P.Resume { tab = closed }));
      check_code "hand-szz7 an unknown handle" "unknown-tab"
        (request tabs "human" (P.Resume { tab = handle "t_nobody" })))

let () =
  Alcotest.run "L16 handoff and resume"
    [
      ( "handoff",
        [
          Alcotest.test_case "hand-lz3p hand-0sja hand-nisr hand-r4t1" `Quick
            blocks_until_resume;
          Alcotest.test_case "hand-beip" `Quick handoff_is_the_owners;
        ] );
      ( "ending",
        [
          Alcotest.test_case "hand-lmd5 hand-szz7" `Quick timeout_restores_the_owner;
          Alcotest.test_case "hand-lz3p hand-szz7" `Quick disconnect_restores_the_owner;
          Alcotest.test_case "hand-yytf" `Quick browser_loss_ends_it;
          Alcotest.test_case "own-0pnk hand-lz3p" `Quick forced_endings;
        ] );
      ("idle", [ Alcotest.test_case "hand-len8 hand-0sja" `Quick idle_clock ]);
      ("budget", [ Alcotest.test_case "hand-lmd5" `Quick defaults_and_budget ]);
      ("resume", [ Alcotest.test_case "hand-szz7" `Quick resume_without_a_handoff ]);
    ]
