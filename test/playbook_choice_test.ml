(* L40 extr-uhnc extr-andy run-kli0 run-pvmc: the real run builder and Models transport must
   preserve authored playbook descriptions, even before any site has loaded.
   Only the HTTP peer and browser observations are scripted; no live model is used. *)
module R = Leash.Run
module B = Leash.Playbook
module P = Leash.Protocol
module Server = Leash_test_support.Fake_systemone
module Logger = Ox_observability.Logger

let ok = function Ok value -> value | Error why -> Alcotest.fail why

let get name = function
  | `Assoc fields -> List.assoc name fields
  | _ -> Alcotest.fail ("expected object for " ^ name)

let check_json label expected actual =
  Alcotest.(check string)
    label
    (Yojson.Safe.to_string expected)
    (Yojson.Safe.to_string actual)

let blank =
  let snapshot =
    P.
      {
        snapshot = ok (Snapshot_id.of_string "s_test");
        tab = ok (Handle.of_string "t_test");
        url = "about:blank";
        title = "";
        page_kind = None;
        rows = [];
        total = 0;
        offset = 0;
        truncated = false;
        settled = true;
        source = P.Ax;
        reason = None;
        dialog = None;
      }
  in
  R.
    {
      url = snapshot.url;
      title = snapshot.title;
      text = "";
      dialog = None;
      rows = [];
      downloads = [];
      snapshot;
    }

let installed site description =
  B.
    {
      file = site ^ ".json";
      playbook =
        {
          site;
          description;
          entry = "https://" ^ site ^ "/";
          pages = [];
          procedures = [];
          shapes = None;
          scripts = None;
        };
      checks = [];
      dir = None;
      scripts = [];
    }

let refusal (request : Server.request) =
  let body = Yojson.Safe.from_string request.body in
  let criteria = get "criteria" (get "select_playbook" (get "questions" body)) in
  let probabilities =
    match criteria with
    | `Assoc criteria ->
        `Assoc
          (List.map
             (fun (key, _) -> (key, `Float (if key = "none" then 1. else 0.)))
             criteria)
    | _ -> Alcotest.fail "missing criteria"
  in
  Server.ok
    (Yojson.Safe.to_string
       (`Assoc
          [
            ("model", get "model" body);
            ( "answers",
              `Assoc
                [
                  ( "select_playbook",
                    `Assoc
                      [
                        ("type", `String "choice");
                        ("choice", `String "none");
                        ("probabilities", probabilities);
                        ("confidence", `Float 1.);
                      ] );
                ] );
            ( "usage",
              `Assoc
                [
                  ("input_tokens", `Int 10); ("output_tokens", `Int 2); ("cost", `Float 0.);
                ] );
          ]))

let question_on_wire ~url () =
  let observed = R.{ blank with url; snapshot = { blank.snapshot with url } } in
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let server = Server.serve ~net:env#net ~sw refusal in
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Debug ~service:"playbook-choice-test"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let config =
            {
              Leash.Config.default.models with
              api_key = Some (Ox_observability.Redact.make "test-key");
              systemone_endpoint =
                ok (Leash.Config.Text.of_string (Server.url server "/systemone"));
            }
          in
          let models =
            Leash.Models.create ~sw ~net:env#net ~clock:env#clock ~logger config
          in
          let asked = ref None in
          let unexpected () = Alcotest.fail "unexpected browser/planner operation" in
          let handler =
            R.
              {
                observe = (fun () -> Ok observed);
                navigate = (fun _ -> unexpected ());
                choose =
                  (fun question ->
                    asked := Some question;
                    Leash.Models.choose models question);
                text_value = (fun _ -> unexpected ());
                step =
                  (fun _ ->
                    Ok
                      P.
                        {
                          status = ok (Drive_status.of_string "blocked");
                          steps = [];
                          final = observed.snapshot;
                          operator_state = None;
                          reason = None;
                        });
                verify = (fun ~pages:_ ~checks:_ ~timeout_s:_ -> unexpected ());
                plan = (fun _ -> unexpected ());
                propose = (fun ~site:_ _ -> unexpected ());
                hand_off = (fun ~reason:_ -> unexpected ());
                script = (fun _ ~args:_ -> unexpected ());
              }
          in
          let books = "Book catalogue with travel categories, titles and prices." in
          let trains = "Passenger train timetables and rail tickets." in
          let result =
            R.loop ~handler
              ~now:(fun () -> 0.)
              ~installed:
                [ installed "books.example" books; installed "rail.example" trains ]
              R.
                {
                  mission = "collect every book in the Travel category";
                  max_steps = 60;
                  start_url = None;
                  max_procedures = 1;
                  deadline_s = 30;
                  dry_run = false;
                  max_plans = 0;
                  expect = [];
                }
          in
          (match result with
          | Error error -> Alcotest.fail error.P.message
          | Ok result -> (
              let choices = get "playbook_choices" (P.yojson_of_run_result result) in
              match choices with
              | `List (choice :: _) ->
                  check_json "none choice is recorded" (`String "none") (get "key" choice);
                  let probabilities = get "probabilities" choice in
                  check_json "none probability survives in reply" (`Float 1.)
                    (get "none" probabilities);
                  check_json "book probability survives in reply" (`Float 0.)
                    (get "book:books.example.json" probabilities);
                  check_json "other candidate probability survives in reply" (`Float 0.)
                    (get "book:rail.example.json" probabilities)
              | _ -> Alcotest.fail "expected one recorded playbook choice"));
          Alcotest.(check int)
            "one model request" 1
            (List.length (Server.requests server));
          let sent = Yojson.Safe.from_string (Server.body server) in
          let question = get "select_playbook" (get "questions" sent) in
          let criteria = get "criteria" question in
          List.iter
            (fun (identity, description) ->
              let offered =
                match get identity criteria with
                | `String text -> text
                | _ -> Alcotest.fail "description"
              in
              Alcotest.(check bool)
                "authored description and stable identity survive" true
                (String.ends_with ~suffix:description offered
                && String.starts_with ~prefix:("identity=" ^ identity) offered))
            [ ("book:books.example.json", books); ("book:rail.example.json", trains) ];
          check_json "none describes continuing on the current page"
            (`String "Continue on the current page without a playbook.")
            (get "none" criteria);
          let state = get "state" sent in
          (if url = "about:blank" then
             check_json "blank page has no current site"
               (`String "Blank page; no site is loaded.") (get "current_page" state)
           else
             match state with
             | `Assoc fields ->
                 Alcotest.(check bool)
                   "loaded page is not described as blank" false
                   (List.mem_assoc "current_page" fields)
             | _ -> Alcotest.fail "expected state object");
          check_json "no site selected" `Null (get "site" state);
          let kind = if url = "about:blank" then "blank" else "home" in
          check_json "kind-ir9l inferred kind before a book is chosen" (`String kind)
            (get "page_kind" state);
          Alcotest.(check bool)
            "kind-ir9l upper state omits raw and substituted URL" true
            (match state with
            | `Assoc fields -> not (List.mem_assoc "url" fields)
            | _ -> false);
          check_json "plain mission without host"
            (`String "collect every book in the Travel category") (get "mission" state);
          match !asked with
          | None -> Alcotest.fail "run did not ask playbook question"
          | Some built ->
              check_json "transport preserves run state" built.R.state state;
              check_json "transport preserves instructions" (`String built.R.instructions)
                (get "instructions" question);
              check_json "transport preserves all option descriptions"
                (`Assoc
                   (List.map (fun (key, value) -> (key, `String value)) built.R.criteria))
                criteria))

let () =
  Alcotest.run "playbook-choice"
    [
      ( "extr-uhnc run-kli0 run-pvmc",
        [
          Alcotest.test_case "current-page choice preserves authored options on wire"
            `Quick
            (question_on_wire ~url:"https://books.example/");
          Alcotest.test_case "loaded page preserves authored options without blank fact"
            `Quick
            (question_on_wire ~url:"https://other.example/");
        ] );
    ]
