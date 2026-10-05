(* takeover (operator 2026-10-05): JEV drives; on BLOCKED, a stall or its cap the page
   passes to Luna, which acts, runs procedures, finishes or hands back to JEV with a goal.
   Over scripted handlers, with no browser or model. *)
module R = Leash.Run
module P = Leash.Protocol

let ok = function Ok x -> x | Error why -> Alcotest.fail why
let ran = function Ok x -> x | Error (e : P.error) -> Alcotest.fail e.message
let tab = ok (P.Handle.of_string "t_test")
let sid = ok (P.Snapshot_id.of_string "s_test")

let password_row =
  P.
    {
      index = 1;
      role = "textbox";
      name = "Password";
      value = None;
      state = None;
      options = None;
      box = None;
    }

let snapshot =
  P.
    {
      snapshot = sid;
      tab;
      url = "https://site.example/";
      title = "Page";
      rows = [ password_row ];
      total = 1;
      offset = 0;
      truncated = false;
      settled = true;
      source = Ax;
      image = None;
      reason = None;
      dialog = None;
    }

let page text =
  R.
    {
      snapshot;
      url = snapshot.url;
      title = snapshot.title;
      text;
      rows = [];
      downloads = [];
      dialog = None;
      image_input = None;
    }

let drive ?reason status =
  P.
    {
      status = ok (Drive_status.of_string status);
      steps = [];
      final = snapshot;
      operator_state = None;
      reason;
    }

let params ?(mission = "Open the reports page") () =
  R.{ mission; max_steps = 256; start_url = None; deadline_s = 600; dry_run = false }

let tab_info =
  P.
    {
      tab;
      url = snapshot.url;
      title = snapshot.title;
      origin = ok (Origin.of_string "agent");
      label = None;
      age_s = 0;
      idle_s = 0;
      closes_in_s = Some 1800;
      with_human = false;
      generation = 1;
      dialog = None;
      loaded = None;
      reason = None;
    }

let acted =
  {
    P.tab;
    url = snapshot.url;
    title = snapshot.title;
    snapshot = None;
    dialog = None;
    popups = [];
    hits = None;
    shots = None;
    via = None;
  }

(* Each JEV stint pops a drive result; each Luna turn pops an answer. *)
let harness ?(text = "Fact 42") ?(on_step = fun _ -> ()) drives answers =
  let drives = ref drives
  and answers = ref answers
  and goals = ref []
  and asked = ref []
  and acts = ref [] in
  let pop values =
    match !values with
    | [] -> Alcotest.fail "unexpected callback"
    | v :: rest ->
        values := rest;
        v
  in
  let handler =
    R.
      {
        observe = (fun ~image:_ () -> Ok (page text));
        navigate = (fun _ -> Ok ());
        step =
          (fun request ->
            goals := request.R.goal :: !goals;
            on_step request;
            Ok (pop drives));
        plan =
          (fun request ->
            asked := request :: !asked;
            Ok R.{ answer = pop answers; usage = None });
        act =
          (fun command ->
            acts := command :: !acts;
            Ok acted);
        hand_off = (fun ~reason:_ -> Ok tab_info);
      }
  in
  (handler, goals, asked, acts)

let status expected (r : P.run_result) =
  Alcotest.(check string) "status" expected (P.Run_status.to_string r.status)

let loop ?(planner = true) ?(secrets = []) ?(now = fun () -> 0.) h p =
  ran (R.loop ~handler:h ~planner ~secrets ~now p)

(* JEV's DONE ends a navigation mission; Luna is not asked. *)
let jev_runs () =
  let h, goals, asked, _ = harness [ drive "done" ] [] in
  status "done" (loop h (params ()));
  Alcotest.(check (list string)) "JEV gets the mission" [ "Open the reports page" ] !goals;
  Alcotest.(check int) "Luna not asked" 0 (List.length !asked)

(* Without a planner a stop ends blocked. *)
let no_planner () =
  let h, _, asked, _ = harness [ drive ~reason:"no control" "blocked" ] [] in
  status "blocked" (loop ~planner:false h (params ()));
  Alcotest.(check int) "never called" 0 (List.length !asked)

(* takeover: JEV blocks; Luna types the password secret and hands back with a goal. *)
let takeover_and_back () =
  let fill =
    P.Fill
      P.
        {
          tab;
          snapshot = sid;
          index = 1;
          text = "password";
          snap = None;
          match_ = None;
          limit = None;
        }
  in
  let h, goals, asked, acts =
    harness
      [ drive ~reason:"login form" "blocked"; drive "done" ]
      [ R.Act fill; R.Jev "Click the link named Reports" ]
  in
  let r = loop ~secrets:[ ("password", "hunter2") ] h (params ()) in
  status "done" r;
  Alcotest.(check bool)
    "takeover asked because JEV blocked" true
    (match List.rev !asked with q :: _ -> q.R.trigger = R.Blocked | [] -> false);
  Alcotest.(check bool)
    "the secret's value is typed" true
    (match !acts with [ P.Fill a ] -> a.text = "hunter2" | _ -> false);
  Alcotest.(check (list string))
    "JEV's next goal is Luna's string"
    [ "Click the link named Reports"; "Open the reports page" ]
    !goals;
  Alcotest.(check (list string))
    "turns recorded" [ "act"; "jev" ]
    (List.rev_map (fun (t : P.planner_turn) -> t.answer) r.planner_turns |> List.rev)

(* At the end of an answer mission Luna gives the answer, or takes over first. *)
let final_answer () =
  let mission = "How many books are in the Poetry category?" in
  let h, _, asked, _ =
    harness
      [ drive "done" ]
      [ R.Done { result = "19"; evidence = [ "19 results" ]; records = [] } ]
  in
  let r = loop h (params ~mission ()) in
  status "done" r;
  Alcotest.(check (option string)) "result" (Some "19") r.result;
  Alcotest.(check bool)
    "asked once, at the end" true
    (match !asked with [ q ] -> q.R.trigger = R.Final | _ -> false);
  let h, goals, _, _ =
    harness
      [ drive "done"; drive "done" ]
      [
        R.Jev "Open the Poetry category";
        R.Done { result = "19"; evidence = []; records = [] };
      ]
  in
  status "done" (loop h (params ~mission ()));
  Alcotest.(check int) "Luna sent JEV on before answering" 2 (List.length !goals)

let fail_and_records () =
  let h, _, _, _ = harness [ drive "blocked" ] [ R.Fail "the site has no reports" ] in
  status "failed" (loop h (params ()));
  let written = ref [] in
  let h, _, _, _ =
    harness
      [ drive "blocked" ]
      [
        R.Done
          {
            result = "2 books";
            evidence = [];
            records = [ [ ("title", "A") ]; [ ("title", "B") ] ];
          };
      ]
  in
  let r =
    ran
      (R.loop ~handler:h
         ~now:(fun () -> 0.)
         ~on_record:(fun x ->
           written := x :: !written;
           Ok ())
         (params ()))
  in
  Alcotest.(check int) "Luna's records go to --out" 2 (List.length !written);
  Alcotest.(check int) "and are counted" 2 r.collected

(* Only the deadline bounds Luna. *)
let deadline_bounds () =
  let clock = ref 0. in
  let reads =
    List.init 50 (fun _ -> R.Read { quote = "Fact 42"; note = "still reading" })
  in
  let h, _, asked, _ = harness [ drive "blocked" ] reads in
  let h =
    {
      h with
      R.plan =
        (fun request ->
          clock := !clock +. 30.;
          h.R.plan request);
    }
  in
  status "deadline" (loop ~now:(fun () -> !clock) h (params ()));
  Alcotest.(check bool) "more turns than the old cap of 12" true (List.length !asked > 12)

let () =
  Alcotest.run "drive: JEV drives, Luna takes over"
    [
      ( "takeover",
        List.map
          (fun (name, f) -> Alcotest.test_case name `Quick f)
          [
            ("JEV runs the mission", jev_runs);
            ("no planner, never called", no_planner);
            ("takeover and hand back", takeover_and_back);
            ("the answer at the end", final_answer);
            ("fail and records", fail_and_records);
            ("only the deadline bounds Luna", deadline_bounds);
          ] );
    ]
