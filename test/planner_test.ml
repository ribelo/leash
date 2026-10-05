(* takeover: the planner's strict answer shapes while it holds the page. *)
module M = Leash.Planner
module R = Leash.Run
module P = Leash.Protocol

let ok = function Ok x -> x | Error why -> Alcotest.fail why
let sid = ok (P.Snapshot_id.of_string "s_test")
let tab = ok (P.Handle.of_string "t_test")

let snapshot =
  P.
    {
      snapshot = sid;
      tab;
      url = "https://site.example/";
      title = "Page";
      page_kind = None;
      rows =
        [
          {
            index = 1;
            role = "textbox";
            name = "Password";
            value = None;
            state = None;
            options = None;
            box = None;
          };
        ];
      total = 1;
      offset = 0;
      truncated = false;
      settled = true;
      source = Ax;
      image = None;
      reason = None;
      dialog = None;
    }

let request ?(headless = false) trigger =
  R.
    {
      trigger;
      reason = "no control";
      mission = "Find the report";
      secret_names = [ "portal_password" ];
      headless;
      site = Some "site.example";
      notes = Some "Reports are under Archive.";
      history = [ ("Find the report", "blocked: no control") ];
      url = snapshot.url;
      title = snapshot.title;
      text = "Archive";
      snapshot;
      image_input = None;
      downloads = [];
      offered = [ ("open-reports", "Open the reports page") ];
    }

let answer ?headless trigger json =
  match M.decode (request ?headless trigger) json with
  | Ok r -> Some r.R.answer
  | Error _ ->
      None [@ox.allow "ox-discarded-result: a refused reply is the expected outcome"]

let shapes () =
  let is f json =
    Alcotest.(check bool)
      json true
      (match answer R.Blocked json with Some a -> f a | None -> false)
  in
  is
    (function R.Jev "Click Archive" -> true | _ -> false)
    {|{"answer":"jev","goal":"Click Archive"}|};
  is
    (function R.Act (P.Fill a) -> a.text = "portal_password" | _ -> false)
    {|{"answer":"act","action":{"cmd":"fill","args":{"tab":"t_test","snapshot":"s_test","index":1,"text":"portal_password"}}}|};
  is
    (function R.Read _ -> true | _ -> false)
    {|{"answer":"read","quote":"Archive","note":"the menu"}|};
  is
    (function R.Observe_image -> true | _ -> false)
    {|{"answer":"observe","image":true}|};
  is
    (function R.Run "open-reports" -> true | _ -> false)
    {|{"answer":"run","name":"open-reports"}|};
  is
    (function R.Handoff _ -> true | _ -> false)
    {|{"answer":"handoff","reason":"captcha"}|};
  is
    (function R.Done { records = [ [ ("title", "A") ] ]; _ } -> true | _ -> false)
    {|{"answer":"done","result":"one","evidence":[],"records":[{"title":"A"}]}|};
  is (function R.Fail _ -> true | _ -> false) {|{"answer":"fail","reason":"gone"}|};
  List.iter
    (fun json ->
      Alcotest.(check bool) ("refused: " ^ json) true (answer R.Blocked json = None))
    [
      {|{"answer":"act","action":{"cmd":"click","args":{"tab":"t_test","snapshot":"s_test","index":9}}}|};
      {|{"answer":"jev","goal":""}|};
      {|{"answer":"leg","goal":"x"}|};
      {|not json|};
    ]

(* revert-r9ka: on a headless browser handoff is neither offered nor accepted. *)
let headless () =
  Alcotest.(check bool)
    "handoff refused" true
    (answer ~headless:true R.Blocked {|{"answer":"handoff","reason":"captcha"}|} = None);
  let has needle p =
    let n = String.length needle in
    let rec go i =
      i + n <= String.length p && (String.sub p i n = needle || go (i + 1))
    in
    go 0
  in
  Alcotest.(check bool)
    "headless prompt offers no handoff" false
    (has {|"handoff"|} (Leash__Questions.takeover ~headless:true));
  Alcotest.(check bool)
    "headed prompt offers it" true
    (has {|"handoff"|} (Leash__Questions.takeover ~headless:false))

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
    (List.length (Yojson.Safe.Util.to_list (field "history")));
  Alcotest.(check int)
    "offered" 1
    (List.length (Yojson.Safe.Util.to_list (field "offered")))

let () =
  Alcotest.run "planner takeover"
    [
      ( "shapes",
        [
          Alcotest.test_case "answer shapes" `Quick shapes;
          Alcotest.test_case "revert-r9ka headless" `Quick headless;
          Alcotest.test_case "what the planner is shown" `Quick shown;
        ] );
    ]
