(* pilot-ukoh pilot-r94o pilot-02ij pilot-e4sh: pure pilot wire tests. *)
module P = Leash.Protocol
module R = Leash.Run
module M = Leash.Planner

let ok = function Ok x -> x | Error why -> Alcotest.fail why
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
      reason = None;
      dialog = None;
    }

let request =
  R.
    {
      legs = [];
      candidates = [];
      secret_names = [ "PASS" ];
      trigger = Blocked;
      reason = "pilot turn";
      mission = "Find the answer";
      site = None;
      playbook = None;
      recent = [];
      arguments = [];
      snapshot;
      planner_actions = 5;
      page_kind = None;
      title = "Page";
      url = snapshot.url;
      text = "Fact 42";
    }

let shapes () =
  List.iter
    (fun json -> ignore (ok (M.decode_pilot request json)))
    [
      {|{"answer":"leg","goal":"Open account"}|};
      {|{"answer":"read","quote":"Fact 42","note":"the answer"}|};
      {|{"answer":"done","result":"42","evidence":["Fact 42"]}|};
      {|{"answer":"handoff","reason":"Login"}|};
      {|{"answer":"notify","message":"Working"}|};
      {|{"answer":"fail","reason":"Unavailable"}|};
    ]

let refuses () =
  List.iter
    (fun json ->
      Alcotest.(check bool)
        "invalid shape" true
        (Result.is_error (M.decode_pilot request json)))
    [
      {|{"answer":"done","evidence":[]}|};
      {|{"answer":"done","result":"42"}|};
      {|{"answer":"done","result":"","evidence":[]}|};
      {|{"answer":"leg","goal":"Open","message":"mixed"}|};
      {|{"answer":"procedure","procedure":{}}|};
      {|{"answer":"continue","actions":[]}|};
      {|{"answer":"act","action":[{"cmd":"wait","args":{"tab":"t_test"}},{"cmd":"wait","args":{"tab":"t_test"}}]}|};
      {|{"answer":"act","action":{"cmd":"wait","args":{"tab":"t_test"}},"actions":[]}|};
      {|{"answer":"act","action":{"cmd":"nav","args":{"tab":"t_test","url":"https://evil.example/"}}}|};
    ]

(* pilot-x1f3: the pilot writes {cmd, args} without the wire version (U1 live run,
   2026-10-04: "missing field v" before the first turn). *)
let act_without_version () =
  match
    P.planner_action_of_yojson
      (Yojson.Safe.from_string
         {|{"cmd":"press","args":{"tab":"t_test","snapshot":"s_test","key":"Enter"}}|})
  with
  | Ok _ -> ()
  | Error why -> Alcotest.fail why

(* pilot-x1f3: a select option given by label resolves to its index (U2, Tauron). *)
let select_label () =
  let row =
    P.
      {
        index = 3;
        role = "combobox";
        name = "Typ dokumentu";
        value = None;
        state = None;
        options =
          Some
            [
              {
                index = 0;
                label = "Wszystkie";
                value = "all";
                selected = true;
                disabled = false;
              };
              {
                index = 1;
                label = "Faktury";
                value = "inv";
                selected = false;
                disabled = false;
              };
            ];
      }
  in
  let request =
    { request with R.snapshot = { snapshot with rows = [ row ]; total = 1 } }
  in
  match
    M.decode_pilot request
      {|{"answer":"act","action":{"cmd":"select","args":{"tab":"t_test","snapshot":"s_test","index":3,"option":"Faktury"}}}|}
  with
  | Ok { answer = R.Act (P.Select a); _ } ->
      Alcotest.(check int) "option index" 1 a.option
  | Ok _ -> Alcotest.fail "not a select"
  | Error why -> Alcotest.fail why

(* pilot-x1f3: the prompt offers act scroll; the decoder and the check accept it. *)
let act_scroll () =
  match
    M.decode_pilot request
      {|{"answer":"act","action":{"cmd":"scroll","args":{"tab":"t_test","direction":"down"}}}|}
  with
  | Ok { answer = R.Act (P.Scroll _); _ } -> ()
  | Ok _ -> Alcotest.fail "not a scroll"
  | Error why -> Alcotest.fail why

(* pilot-02ij: the pilot prompt stays under 300 words. *)
let prompt_size () =
  let words =
    String.split_on_char ' '
      (String.map (function '\n' | '\t' -> ' ' | c -> c) M.pilot_prompt)
    |> List.filter (( <> ) "")
  in
  Alcotest.(check bool)
    (Printf.sprintf "%d words" (List.length words))
    true
    (List.length words < 300)

let generated () =
  let reply =
    ok
      (M.decode_pilot request
         {|{"answer":"done","result":"Account made","evidence":[],"secrets_for_operator":{"PASSWORD":"new-value"}}|})
  in
  Alcotest.(check string)
    "generated operator secret" "new-value"
    (List.assoc "PASSWORD" reply.secrets_for_operator)

let bounded () =
  let wire = M.pilot_request_json { request with text = String.make 9000 'x' } in
  let field key = Yojson.Safe.Util.member key wire in
  Alcotest.(check int)
    "text bound" 6000
    (String.length (Yojson.Safe.Util.to_string (field "text")));
  Alcotest.(check bool)
    "secret names included" true
    (field "secret_names" = `List [ `String "PASS" ])

let redact () =
  let wire = `Assoc [ ("secret-value", `String "secret-value longer secret-value") ] in
  let cleaned =
    P.redact_json [ ("A", "secret-value"); ("B", "secret-value longer") ] wire
  in
  Alcotest.(check string)
    "longest first, keys too" {|{"<redacted>":"<redacted> <redacted>"}|}
    (Yojson.Safe.to_string cleaned)

let () =
  Alcotest.run "pilot wire"
    [
      ( "codec",
        List.map
          (fun (name, test) -> Alcotest.test_case name `Quick test)
          [
            ("shapes", shapes);
            ("refusals", refuses);
            ("act without wire version", act_without_version);
            ("prompt under 300 words", prompt_size);
            ("select option by label", select_label);
            ("act scroll", act_scroll);
            ("generated secret", generated);
            ("bounded request", bounded);
            ("redaction", redact);
          ] );
    ]
