(* L13 - expiry and disposition (docs/issues/tab-ownership/01-tab-ownership.md, milestone
   3; ADR-0005). Stories: own-uo77 own-hslp own-2zpi own-ay3s own-nbwk own-vhqo own-5qoh.
   Everything runs at the control-protocol seam over the fake browser with the mock clock:
   the sweep is one fiber on that clock, so a test moves time and nothing else. *)
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

let owner name =
  match P.Owner.of_string name with Ok x -> x | Error e -> Alcotest.fail e

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

(* One request, exactly as the CLI sends it: encoded to the wire, dispatched by the
   service, decoded back. *)
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

let origin tabs handle = text "origin" (row tabs handle)

(* [expires] is the next stage a tab faces and the seconds left before it (own-82jd): the
   one way a human sees what is about to happen. *)
let expires tabs handle =
  match get "expires" (row tabs handle) with
  | `Assoc [ ("stage", `String stage); ("in_s", `Int seconds) ] -> (stage, seconds)
  | other -> Alcotest.failf "expires: %s" (Yojson.Safe.to_string other)

let no_stage tabs handle =
  match get "expires" (row tabs handle) with
  | `Null -> ()
  | other ->
      Alcotest.failf "a tab no timer may take carries no expiry, got %s"
        (Yojson.Safe.to_string other)

let probe tabs who handle =
  request tabs who (P.Debug { tab = handle; limit = None; clear = None })

let disposition = function
  | P.Failure { detail = Some (`Assoc fields); _ } -> (
      match List.assoc_opt "disposition" fields with
      | Some (`String disposition) -> disposition
      | _ -> Alcotest.fail "the tab-gone detail carries no disposition")
  | P.Failure _ -> Alcotest.fail "tab-gone without a disposition"
  | P.Success _ -> Alcotest.fail "expected a failure"

let closes fake =
  Fake.received fake
  |> List.filter (fun json -> field "method" json = Some (str "Target.closeTarget"))
  |> List.length

(* The sweep is one fiber on the mock clock: moving the clock is the only way time passes,
   and the fiber is a daemon of the test switch. *)
let advance env seconds = Eta_test.advance env#clock (Eta.Duration.seconds seconds)

let rec until n what check =
  if check () then ()
  else if n = 0 then Alcotest.failf "the sweep never did %s" what
  else (
    Eio.Fiber.yield ();
    until (n - 1) what check)

let rig ?(idle = 30) ?(unclaimed = 60) ?(interval = Expiry.interval) f =
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
        Eta_observability.Logger.create ~service:"leash-expiry-tests" ~clock:env#clock
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
      let idle = Eta.Duration.seconds idle in
      let unclaimed = Eta.Duration.seconds unclaimed in
      let tabs =
        Tabs.create ~sw ~cap:128 ~tombstone_s:3600 ~idle ~unclaimed
          { Tabs.chrome; clock = env#clock; logger }
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
        Expiry.create ~sw ~interval ~idle ~unclaimed ~clock:env#clock ~logger tabs
      in
      f ~env ~tabs ~expiry ~fake)

(* ---------- The policy, pure ---------- *)

(* own-uo77 own-hslp own-2zpi own-ay3s: the two stages, the human exemption, and the
   handoff exemption, with no clock, no browser, and no registry. *)
let policy () =
  let idle = Eta.Duration.seconds 30 in
  let unclaimed = Eta.Duration.seconds 60 in
  let handle =
    match P.Handle.of_string "t_policy" with Ok h -> h | Error e -> Alcotest.fail e
  in
  let origin name =
    match P.Origin.of_string name with Ok o -> o | Error e -> Alcotest.fail e
  in
  let agent = origin "agent" in
  let human = origin "human" in
  let alice = owner "alice" in
  let decide = Expiry.decide ~idle ~unclaimed in
  let subject ~origin ~owner_state ~idle_for_s ?unowned_for_s () =
    Tabs.{ handle; origin; owner_state; idle_for_s; unowned_for_s }
  in
  let check label expected tab =
    Alcotest.(check bool) label true (decide tab = expected)
  in
  check "own-uo77 an owned tab one second short of idle is left alone" Tabs.Keep_idle
    (subject ~origin:agent ~owner_state:(Tabs.Owned alice) ~idle_for_s:29. ());
  check "own-uo77 an owned tab idle for the idle duration is released" Tabs.Release_idle
    (subject ~origin:agent ~owner_state:(Tabs.Owned alice) ~idle_for_s:30. ());
  check "own-uo77 a human tab an agent claimed is released, not closed, exactly the same"
    Tabs.Release_idle
    (subject ~origin:human ~owner_state:(Tabs.Owned alice) ~idle_for_s:1000. ());
  check "own-hslp an unowned agent tab short of the unclaimed duration is left alone"
    Tabs.Keep_idle
    (subject ~origin:agent ~owner_state:Tabs.Unowned ~idle_for_s:1000. ~unowned_for_s:59.
       ());
  check "own-hslp an unowned agent tab unclaimed for the unclaimed duration is closed"
    Tabs.Close_idle
    (subject ~origin:agent ~owner_state:Tabs.Unowned ~idle_for_s:1000. ~unowned_for_s:60.
       ());
  check "own-2zpi a human tab unowned forever is never closed" Tabs.Keep_idle
    (subject ~origin:human ~owner_state:Tabs.Unowned ~idle_for_s:1_000_000.
       ~unowned_for_s:1_000_000. ());
  check "own-hslp an unowned tab with no unowned instant is not closed" Tabs.Keep_idle
    (subject ~origin:agent ~owner_state:Tabs.Unowned ~idle_for_s:1_000_000. ());
  check "hand-len8 a handed-off tab is exempt from both stages" Tabs.Keep_idle
    (subject ~origin:agent ~owner_state:(Tabs.With_human alice) ~idle_for_s:1_000_000. ())

(* ---------- The sweep on the clock ---------- *)

(* own-uo77 own-hslp own-nbwk: the whole life of one tab under the default thirty-second
   period. Owned until the idle duration, released by stage 1, then closed by stage 2 once
   the unclaimed duration passes with nobody claiming it. *)
let two_stages () =
  rig (fun ~env ~tabs ~expiry:_ ~fake ->
      let h = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      Alcotest.(check string) "own-uo77 a fresh tab is owned" "owned" (state tabs h);
      Alcotest.(check (pair string int))
        "own-82jd an owned tab counts down to release" ("release", 30) (expires tabs h);
      advance env 29;
      Alcotest.(check string)
        "own-uo77 one second short of the idle duration it is still owned" "owned"
        (state tabs h);
      Alcotest.(check (pair string int))
        "own-82jd the seconds remaining move" ("release", 1) (expires tabs h);
      advance env 1;
      until 1000 "release the idle tab" (fun () -> state tabs h = "unowned");
      Alcotest.(check int)
        "own-uo77 stage 1 released it, stage 2 did not close it" 0 (closes fake);
      Alcotest.(check (option string))
        "own-uo77 and nobody owns it now" None (owner_of tabs h);
      Alcotest.(check (pair string int))
        "own-hslp it now counts down to close" ("close", 60) (expires tabs h);
      advance env 30;
      Alcotest.(check string)
        "own-hslp half the unclaimed duration is not enough" "unowned" (state tabs h);
      advance env 30;
      until 1000 "close the unclaimed tab" (fun () -> state tabs h = "gone");
      Alcotest.(check int) "own-hslp stage 2 closed it" 1 (closes fake);
      Alcotest.(check string)
        "own-nbwk a released tab the sweep closed reports closed_by_ttl" "closed_by_ttl"
        (disposition (probe tabs "alice" h)))

(* The threshold is exact. The sweep fiber is parked for an hour here, so the passes below
   happen at instants of the test choosing rather than at a tick. *)
let boundary () =
  rig ~interval:(Eta.Duration.hours 1) ~idle:60 ~unclaimed:120
    (fun ~env ~tabs ~expiry ~fake:_ ->
      let h = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      advance env 59;
      Alcotest.(check int)
        "own-uo77 a second short of the idle duration nothing is due" 0
        (List.length (Expiry.sweep expiry));
      advance env 1;
      Alcotest.(check int)
        "own-uo77 at the idle duration the tab is released" 1
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "own-uo77 released" "unowned" (state tabs h);
      advance env 119;
      Alcotest.(check int)
        "own-hslp a second short of the unclaimed duration nothing is due" 0
        (List.length (Expiry.sweep expiry));
      advance env 1;
      Alcotest.(check int)
        "own-hslp at the unclaimed duration the tab is closed" 1
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "own-hslp gone" "gone" (state tabs h);
      Alcotest.(check string)
        "own-nbwk the pass that closed it left closed_by_ttl" "closed_by_ttl"
        (disposition (probe tabs "alice" h)))

(* own-ay3s: any action its owner is allowed to take resets the clock, and a refused
   command is not an action. *)
let owner_action_resets_idle () =
  rig ~idle:300 ~unclaimed:600 (fun ~env ~tabs ~expiry:_ ~fake:_ ->
      let h = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      advance env 240;
      Alcotest.(check string)
        "own-ay3s four minutes in, still owned" "owned" (state tabs h);
      ignore (result (probe tabs "alice" h));
      advance env 240;
      Alcotest.(check string)
        "own-ay3s the action at 240 s moved the clock: 240 s later still owned" "owned"
        (state tabs h);
      advance env 60;
      until 1000 "release the tab 300 s after the last action" (fun () ->
          state tabs h = "unowned");
      let other = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      advance env 280;
      Alcotest.(check string)
        "own-ay3s a stranger is refused" "not-owner"
        (code (probe tabs "bob" other));
      advance env 260;
      until 1000 "release the tab although a stranger tried" (fun () ->
          state tabs other = "unowned"))

(* ---------- Dispositions ---------- *)

(* own-nbwk own-teh1: the tombstone says who ended the tab, so a close Leash issued for
   the owner and a close its timer issued are told apart. *)
let dispositions () =
  rig (fun ~env ~tabs ~expiry:_ ~fake:_ ->
      let owned = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      ignore (result (request tabs "alice" (P.Close { tab = owned; force = None })));
      Alcotest.(check string)
        "own-teh1 the owner closed it" "closed_by_owner"
        (disposition (probe tabs "alice" owned));
      let released = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      ignore (result (request tabs "alice" (P.Release { tab = released; force = None })));
      advance env 400;
      until 1000 "close the released tab by ttl" (fun () -> state tabs released = "gone");
      Alcotest.(check string)
        "own-nbwk the timer closed it, not the owner" "closed_by_ttl"
        (disposition (probe tabs "alice" released)))

(* own-5qoh: nothing about ownership or expiry survives a browser generation. *)
let restart_wipes_state () =
  rig (fun ~env:_ ~tabs ~expiry:_ ~fake ->
      let owned = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      let released = handle_of (result (request tabs "bob" (P.New { url = None }))) in
      ignore (result (request tabs "bob" (P.Release { tab = released; force = None })));
      Fake.drop fake;
      until 1000 "tombstone the tabs of the lost generation" (fun () -> listed tabs = []);
      Alcotest.(check string)
        "own-5qoh an owned handle is gone with browser_lost" "browser_lost"
        (disposition (probe tabs "alice" owned));
      Alcotest.(check string)
        "own-5qoh a released one too" "browser_lost"
        (disposition (probe tabs "bob" released));
      Alcotest.(check int)
        "own-5qoh and the new generation starts empty" 0
        (List.length (listed tabs)))

(* ---------- A human tab ---------- *)

(* own-2zpi, the required case: a tab the human opened, which an agent claimed and then
   released, is never auto-closed - not at the idle duration, not at the unclaimed
   duration, and not a thousand seconds later. *)
let human_origin_never_closed () =
  rig (fun ~env ~tabs ~expiry:_ ~fake ->
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
      until 1000 "adopt the human tab" (fun () -> List.length (listed tabs) = 1);
      let h = handle_of (List.hd (listed tabs)) in
      Alcotest.(check string)
        "own-c0cl discovered as the human tab" "human" (origin tabs h);
      no_stage tabs h;
      Alcotest.(check string)
        "own-jua9 an agent claims it" "owned"
        (text "state" (result (request tabs "alice" (P.Claim { tab = h }))));
      Alcotest.(check (pair string int))
        "own-2zpi while an agent owns it, stage 1 is what it faces" ("release", 30)
        (expires tabs h);
      ignore (result (request tabs "alice" (P.Release { tab = h; force = None })));
      Alcotest.(check string) "own-2zpi released again" "unowned" (state tabs h);
      no_stage tabs h;
      advance env 30;
      advance env 60;
      advance env 600;
      Alcotest.(check string)
        "own-2zpi claimed, released, idle past both stages: never closed" "unowned"
        (state tabs h);
      Alcotest.(check int) "own-2zpi and no close ever reached Chrome" 0 (closes fake);
      Alcotest.(check string) "own-2zpi still the human tab" "human" (origin tabs h);
      ignore (result (request tabs "bob" (P.Claim { tab = h })));
      Alcotest.(check (option string))
        "own-2zpi still claimable, so it is alive" (Some "bob") (owner_of tabs h);
      advance env 30;
      until 1000 "release the claimed human tab" (fun () -> state tabs h = "unowned");
      advance env 600;
      Alcotest.(check string)
        "own-2zpi after a claim and stage 1 the page is still there" "unowned"
        (state tabs h);
      Alcotest.(check int) "own-2zpi still no close" 0 (closes fake))

(* ---------- Config ---------- *)

(* own-vhqo: the two durations are config keys. Decoding a config file and building the
   registry from the decoded values is what the Door does; the boundaries below are the
   configured ones, not the defaults. *)
let configured_durations () =
  let text =
    {|
[chrome]
binary = "/bin/sh"
profile_dir = "/tmp/leash-test-profile"
workspace = "leash"
headless = true
[tabs]
cap = 8
[expiry]
idle_s = 200
unclaimed_s = 400
tombstone_s = 3600
[models]
jev_model = "jev"
text_model = "helper"
|}
  in
  let config =
    match Eta_app.Config.decode ~spec:Leash.Config.spec ~getenv:(fun _ -> None) text with
    | Ok config -> config
    | Error (`Config why) -> Alcotest.fail why
  in
  let idle = Leash.Config.Seconds.to_int config.expiry.idle_s in
  let unclaimed = Leash.Config.Seconds.to_int config.expiry.unclaimed_s in
  Alcotest.(check (pair int int))
    "own-vhqo the file names both durations" (200, 400) (idle, unclaimed);
  (* the fiber is parked, so each pass below happens at an instant of the test choosing *)
  rig ~idle ~unclaimed ~interval:(Eta.Duration.hours 1) (fun ~env ~tabs ~expiry ~fake:_ ->
      let h = handle_of (result (request tabs "alice" (P.New { url = None }))) in
      Alcotest.(check (pair string int))
        "own-vhqo the configured idle is the countdown" ("release", 200) (expires tabs h);
      advance env 199;
      Alcotest.(check int)
        "own-vhqo a second short of the configured idle" 0
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "own-vhqo still owned" "owned" (state tabs h);
      advance env 1;
      Alcotest.(check int)
        "own-vhqo at the configured idle it is released" 1
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "own-vhqo released" "unowned" (state tabs h);
      Alcotest.(check (pair string int))
        "own-vhqo the configured unclaimed is the next countdown" ("close", 400)
        (expires tabs h);
      advance env 399;
      Alcotest.(check int)
        "own-vhqo a second short of the configured unclaimed" 0
        (List.length (Expiry.sweep expiry));
      advance env 1;
      Alcotest.(check int)
        "own-vhqo at the configured unclaimed it is closed" 1
        (List.length (Expiry.sweep expiry));
      Alcotest.(check string) "own-vhqo gone" "gone" (state tabs h);
      Alcotest.(check string)
        "own-vhqo closed by ttl" "closed_by_ttl"
        (disposition (probe tabs "alice" h)))

let () =
  Alcotest.run "L13 expiry and disposition"
    [
      ( "policy",
        [
          Alcotest.test_case "own-uo77 own-hslp own-2zpi own-ay3s hand-len8" `Quick policy;
        ] );
      ( "sweep",
        [
          Alcotest.test_case "own-uo77 own-hslp own-nbwk" `Quick two_stages;
          Alcotest.test_case "own-uo77 own-hslp own-nbwk" `Quick boundary;
          Alcotest.test_case "own-ay3s" `Quick owner_action_resets_idle;
        ] );
      ( "disposition",
        [
          Alcotest.test_case "own-nbwk own-teh1" `Quick dispositions;
          Alcotest.test_case "own-5qoh" `Quick restart_wipes_state;
        ] );
      ( "human",
        [
          Alcotest.test_case "own-2zpi own-c0cl own-jua9" `Quick human_origin_never_closed;
        ] );
      ("config", [ Alcotest.test_case "own-vhqo own-82jd" `Quick configured_durations ]);
    ]
