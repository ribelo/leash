(* revert-eft1 revert-24kr revert-apgf revert-bqrq revert-o3fh: drive is JEV's loop, the
   planner only consulted, over scripted handlers with no browser or model. *)
module R = Leash.Run
module P = Leash.Protocol

let ok = function Ok x -> x | Error why -> Alcotest.fail why
let ran = function Ok x -> x | Error (e : P.error) -> Alcotest.fail e.message
let tab = ok (P.Handle.of_string "t_test")
let sid = ok (P.Snapshot_id.of_string "s_test")

let snapshot =
  P.
    {
      snapshot = sid;
      tab;
      url = "https://site.example/";
      title = "Page";
      page_kind = None;
      rows = [];
      total = 0;
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

let params ?(mission = "Open the reports page") ?(expect = []) () =
  R.
    {
      mission;
      max_steps = 60;
      start_url = None;
      max_procedures = 40;
      deadline_s = 600;
      dry_run = false;
      max_plans = 3;
      expect;
    }

let tab_info =
  P.
    {
      tab;
      url = snapshot.url;
      title = snapshot.title;
      page_kind = None;
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

(* Each JEV run pops a drive result; each planner call pops an answer. *)
let harness ?(text = "Fact 42") ?(on_step = fun _ -> ()) drives answers =
  let drives = ref drives
  and answers = ref answers
  and goals = ref []
  and asked = ref [] in
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
        observe = (fun () -> Ok (page text));
        navigate = (fun _ -> Ok ());
        choose = (fun _ -> Alcotest.fail "no choice level");
        text_value = (fun _ -> Ok None);
        step =
          (fun request ->
            goals := request.R.goal :: !goals;
            on_step request;
            Ok (pop drives));
        verify = (fun ~pages:_ ~checks:_ ~timeout_s:_ -> Ok ([], page text));
        plan =
          (fun request ->
            asked := request :: !asked;
            Ok R.{ answer = pop answers; usage = None });
        hand_off = (fun ~reason:_ -> Ok tab_info);
        script = (fun _ ~args:_ -> Alcotest.fail "unexpected script");
      }
  in
  (handler, goals, asked)

let status expected (r : P.run_result) =
  Alcotest.(check string) "status" expected (P.Run_status.to_string r.status)

(* revert-eft1 revert-24kr: JEV's DONE ends a navigation mission; no planner is asked. *)
let jev_runs () =
  let h, goals, asked = harness [ drive "done" ] [] in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  status "done" r;
  Alcotest.(check (list string))
    "revert-eft1 JEV gets the mission as its goal" [ "Open the reports page" ] !goals;
  Alcotest.(check int) "revert-24kr no planner call" 0 (List.length !asked)

(* revert-24kr: without a planner, BLOCKED ends blocked and nothing is asked. *)
let no_planner () =
  let h, _, asked = harness [ drive ~reason:"no control" "blocked" ] [] in
  let r =
    ran (R.loop ~handler:h ~planner:false ~now:(fun () -> 0.) ~installed:[] (params ()))
  in
  status "blocked" r;
  Alcotest.(check int) "revert-24kr never called" 0 (List.length !asked)

(* revert-apgf: on BLOCKED the planner's hint becomes JEV's goal; it never acts. *)
let blocked_hint () =
  let h, goals, asked =
    harness
      [ drive ~reason:"no control" "blocked"; drive "done" ]
      [ R.Hint "Click the link named Reports" ]
  in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  status "done" r;
  Alcotest.(check int) "revert-apgf one consultation" 1 (List.length !asked);
  Alcotest.(check string)
    "revert-apgf asked because blocked" "blocked"
    R.(
      match (List.hd !asked).trigger with
      | Blocked -> "blocked"
      | Expectation -> "expectation"
      | Final -> "final");
  Alcotest.(check bool)
    "revert-apgf the hint is JEV's next goal" true
    (match !goals with
    | second :: _ -> String.ends_with ~suffix:"Next: Click the link named Reports" second
    | [] -> false);
  Alcotest.(check (list string))
    "revert-apgf the consultation is recorded" [ "hint" ]
    (List.map (fun (t : P.planner_turn) -> t.answer) r.planner_turns)

(* revert-apgf: fail ends the mission; the consultation cap ends a loop of hints. *)
let planner_endings () =
  let h, _, _ = harness [ drive "blocked" ] [ R.Fail "the site has no reports" ] in
  status "failed" (ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())));
  let h, _, asked =
    harness
      (List.init 4 (fun _ -> drive "blocked"))
      (List.init 3 (fun _ -> R.Hint "try again"))
  in
  status "limit" (ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())));
  Alcotest.(check int) "bounded by max_plans" 3 (List.length !asked)

(* revert-bqrq: a mission that asks for an answer gets one planner call at the end, over
   the final page, for result and evidence and the done judgment. *)
let end_answer () =
  let mission = "How many books are in the Poetry category?" in
  let h, _, asked =
    harness
      [ drive "done" ]
      [ R.Answer { result = "19"; evidence = [ "19 results" ]; done_ = true } ]
  in
  let r =
    ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ~mission ()))
  in
  status "done" r;
  Alcotest.(check (option string)) "revert-bqrq result" (Some "19") r.result;
  Alcotest.(check (list string)) "revert-bqrq evidence" [ "19 results" ] r.evidence;
  Alcotest.(check bool)
    "revert-bqrq asked once, at the end" true
    (match !asked with
    | [ q ] -> q.R.trigger = R.Final && q.text = "Fact 42"
    | _ -> false);
  let h, _, _ =
    harness
      [ drive "done" ]
      [ R.Answer { result = "unknown"; evidence = []; done_ = false } ]
  in
  status "failed"
    (ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ~mission ())));
  let h, _, asked = harness [ drive "done" ] [] in
  let r =
    ran
      (R.loop ~handler:h ~planner:false
         ~now:(fun () -> 0.)
         ~installed:[] (params ~mission ()))
  in
  status "done" r;
  Alcotest.(check (option string)) "revert-bqrq no planner, no result" None r.result;
  Alcotest.(check int) "not asked" 0 (List.length !asked)

(* revert-eft1: the site playbook's procedures are offered to JEV as operations; one that
   fails its expectation is a stop the planner sees (revert-24kr). *)
let procedures_as_operations () =
  let proc =
    Leash.Playbook.
      {
        slug = "open-reports";
        description = "Open the reports page";
        args = None;
        steps = [ Goal { goal = "Click the link named Reports"; hint = None } ];
        expect = [ "the page shows Quarterly" ];
        repeat = None;
      }
  in
  let book =
    Leash.Playbook.
      {
        file = "<test>";
        dir = None;
        playbook =
          {
            site = "site.example";
            entry = "https://site.example/";
            description = "Reports";
            pages = [];
            procedures = [ proc ];
            shapes = None;
            scripts = None;
            notes = None;
          };
        checks = [];
        scripts = [];
      }
  in
  let offered = ref [] and outer = ref true in
  let on_step (request : R.step_request) =
    if !outer then (
      outer := false;
      offered :=
        List.map
          (fun (s : Leash__Jev_request.offered_script) -> s.name)
          (request.script_offers ~url:"https://site.example/" ~text:"");
      ignore
        (request.on_script ~url:"https://site.example/" "procedure:open-reports"
          : (Leash__Jev_request.script_effect, P.error) result)
      [@ox.allow
        "ox-discarded-result: the procedure's failure is read from the run below"])
  in
  let h, _, asked =
    harness ~text:"Reports" ~on_step
      [ drive "done"; drive "done" ]
      [ R.Fail "reports are gone" ]
  in
  let h =
    {
      h with
      R.verify =
        (fun ~pages:_ ~checks:_ ~timeout_s:_ ->
          Ok
            ( [
                P.
                  {
                    sentence = "the page shows Quarterly";
                    checker = "page_shows";
                    passed = false;
                    score = None;
                  };
              ],
              page "Reports" ));
    }
  in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[ book ] (params ())) in
  Alcotest.(check (list string))
    "revert-eft1 procedure offered" [ "procedure:open-reports" ] !offered;
  Alcotest.(check bool)
    "revert-24kr failed expectation consulted" true
    (match !asked with q :: _ -> q.R.trigger = R.Expectation | [] -> false);
  status "failed" r

let () =
  Alcotest.run "drive: JEV runs the loop"
    [
      ( "loop",
        List.map
          (fun (name, f) -> Alcotest.test_case name `Quick f)
          [
            ("revert-eft1 revert-24kr JEV runs the mission", jev_runs);
            ("revert-24kr no planner, never called", no_planner);
            ("revert-apgf BLOCKED hint becomes JEV's goal", blocked_hint);
            ("revert-apgf fail and the consultation cap", planner_endings);
            ("revert-bqrq end answer and done judgment", end_answer);
            ("revert-eft1 procedures offered as operations", procedures_as_operations);
          ] );
    ]
