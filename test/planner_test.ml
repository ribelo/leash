(* revert-apgf revert-bqrq: the planner's strict consultation shapes. *)
module M = Leash.Planner
module R = Leash.Run
module P = Leash.Protocol

let ok = function Ok x -> x | Error why -> Alcotest.fail why

let snapshot =
  P.
    {
      snapshot = ok (Snapshot_id.of_string "s_test");
      tab = ok (Handle.of_string "t_test");
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

let request trigger =
  R.
    {
      trigger;
      reason = "no control";
      mission = "Find the report";
      secret_names = [ "portal_password" ];
      headless = false;
      site = Some "site.example";
      notes = Some "Reports are under Archive.";
      history = [ ("Find the report", "blocked: no control") ];
      url = snapshot.url;
      title = snapshot.title;
      text = "Archive";
      snapshot;
    }

let answer trigger json =
  match M.decode (request trigger) json with
  | Ok r -> Some r.R.answer
  | Error _ ->
      None [@ox.allow "ox-discarded-result: a refused reply is the expected outcome"]

(* revert-apgf: on a stop the planner may only hint, hand off, notify or fail. *)
let stop_shapes () =
  (match answer R.Blocked {|{"answer":"hint","goal":"Click the link named Archive"}|} with
  | Some (R.Hint g) ->
      Alcotest.(check string) "revert-apgf hint" "Click the link named Archive" g
  | _ -> Alcotest.fail "hint refused");
  Alcotest.(check bool)
    "handoff" true
    (match answer R.Blocked {|{"answer":"handoff","reason":"captcha"}|} with
    | Some (R.Handoff _) -> true
    | _ -> false);
  Alcotest.(check bool)
    "notify" true
    (match answer R.Expectation {|{"answer":"notify","message":"look"}|} with
    | Some (R.Notify _) -> true
    | _ -> false);
  Alcotest.(check bool)
    "fail" true
    (match answer R.Blocked {|{"answer":"fail","reason":"gone"}|} with
    | Some (R.Fail _) -> true
    | _ -> false);
  List.iter
    (fun json ->
      Alcotest.(check bool)
        ("revert-apgf refused: " ^ json)
        true
        (answer R.Blocked json = None))
    [
      {|{"answer":"act","action":{"cmd":"click","args":{"index":1}}}|};
      {|{"answer":"leg","goal":"x"}|};
      {|{"answer":"done","result":"x","evidence":[],"done":true}|};
      {|{"answer":"hint","goal":""}|};
      {|not json|};
    ]

(* revert-bqrq: at the end the planner gives result, evidence and done, or fail. *)
let final_shapes () =
  (match
     answer R.Final
       {|{"answer":"done","result":"19","evidence":["19 results"],"done":true}|}
   with
  | Some (R.Answer { result; evidence; done_ }) ->
      Alcotest.(check string) "result" "19" result;
      Alcotest.(check (list string)) "evidence" [ "19 results" ] evidence;
      Alcotest.(check bool) "done" true done_
  | _ -> Alcotest.fail "answer refused");
  Alcotest.(check bool)
    "done must be a boolean" true
    (answer R.Final {|{"answer":"done","result":"19","evidence":[]}|} = None);
  Alcotest.(check bool)
    "no hint at the end" true
    (answer R.Final {|{"answer":"hint","goal":"x"}|} = None)

(* What the planner is shown: why, the mission, JEV's history, notes, secret names. *)
let shown () =
  let json = M.request_json (request R.Blocked) in
  let field key = Yojson.Safe.Util.member key json in
  Alcotest.(check string)
    "mission" "Find the report"
    (Yojson.Safe.Util.to_string (field "mission"));
  Alcotest.(check string)
    "notes" "Reports are under Archive."
    (Yojson.Safe.Util.to_string (field "site_notes"));
  Alcotest.(check int)
    "history" 1
    (List.length (Yojson.Safe.Util.to_list (field "jev_history")));
  Alcotest.(check string)
    "secret names only" "[\"portal_password\"]"
    (Yojson.Safe.to_string (field "secret_names"))

(* revert-r9ka: on a headless browser handoff is neither offered nor accepted. *)
let headless () =
  let request = { (request R.Blocked) with R.headless = true } in
  Alcotest.(check bool)
    "revert-r9ka handoff refused" true
    (Result.is_error (M.decode request {|{"answer":"handoff","reason":"captcha"}|}));
  Alcotest.(check bool)
    "revert-r9ka hint accepted" true
    (Result.is_ok (M.decode request {|{"answer":"hint","goal":"Click Search"}|}));
  Alcotest.(check bool)
    "revert-r9ka the headless prompt offers no handoff" false
    (let p = Leash__Questions.planner_hint_headless in
     let rec has i =
       i + 9 <= String.length p && (String.sub p i 9 = {|"handoff"|} || has (i + 1))
     in
     has 0)

let () =
  Alcotest.run "planner consultations"
    [
      ( "shapes",
        [
          Alcotest.test_case "revert-apgf stop answers" `Quick stop_shapes;
          Alcotest.test_case "revert-bqrq final answer" `Quick final_shapes;
          Alcotest.test_case "what the planner is shown" `Quick shown;
          Alcotest.test_case "revert-r9ka headless" `Quick headless;
        ] );
    ]
