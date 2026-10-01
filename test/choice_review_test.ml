(* L45 fly-2akp: JEV owns playbook routing, including a low-confidence NONE.
   A configured planner response cannot veto it. All traffic uses scripted peers. *)
module R = Leash.Run
module P = Leash.Protocol
module C = Leash.Config
module B = Leash.Playbook
module Server = Leash_test_support.Fake_systemone
module Logger = Ox_observability.Logger

let ok = function Ok x -> x | Error why -> Alcotest.fail why

let get name = function
  | `Assoc fields -> List.assoc name fields
  | _ -> Alcotest.fail name

let json_equal label a b =
  Alcotest.(check string) label (Yojson.Safe.to_string a) (Yojson.Safe.to_string b)

let scripted ~probability ~content (request : Server.request) =
  let body = Yojson.Safe.from_string request.body in
  if request.target = "/systemone" then
    let probabilities =
      `Assoc
        [
          ("none", `Float probability);
          ("book:books.example.json", `Float (1. -. probability));
        ]
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
                          ( "choice",
                            `String
                              (if probability >= 0.5 then "none"
                               else "book:books.example.json") );
                          ("probabilities", probabilities);
                          ("confidence", `Float 0.01);
                        ] );
                  ] );
              ( "usage",
                `Assoc
                  [
                    ("input_tokens", `Int 10);
                    ("output_tokens", `Int 2);
                    ("cost", `Float 0.001);
                  ] );
            ]))
  else
    Server.ok
      (Yojson.Safe.to_string
         (`Assoc
            [
              ("id", `String "gen-test");
              ("model", get "model" body);
              ( "choices",
                `List
                  [
                    `Assoc
                      [
                        ("index", `Int 0);
                        ( "message",
                          `Assoc
                            [
                              ("role", `String "assistant"); ("content", `String content);
                            ] );
                        ("finish_reason", `String "stop");
                      ];
                  ] );
              ( "usage",
                `Assoc
                  [
                    ("prompt_tokens", `Int 20);
                    ("completion_tokens", `Int 3);
                    ("total_tokens", `Int 23);
                    ("cost", `Float 0.002);
                  ] );
            ]))

let review ~probability ~threshold ~content ~consulted:_ ~valid:_ () =
  let consulted = false and valid = false in
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let server = Server.serve ~net:env#net ~sw (scripted ~probability ~content) in
          let logger =
            Logger.create ~level:Logger.Debug ~service:"choice-review-test"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter (Logger.Memory.create ()))
              ()
          in
          let config =
            {
              C.default.models with
              api_key = Some (Ox_observability.Redact.make "test-key");
              choice_confidence = ok (C.Probability.of_float threshold);
              systemone_endpoint = ok (C.Text.of_string (Server.url server "/systemone"));
              planner_endpoint = Some (ok (C.Text.of_string (Server.url server "/chat")));
            }
          in
          let models =
            Leash.Models.create ~sw ~net:env#net ~clock:env#clock ~logger config
          in
          let snapshot =
            P.
              {
                snapshot = ok (Snapshot_id.of_string "s_test");
                tab = ok (Handle.of_string "t_test");
                url = "https://books.example/";
                title = "";
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
          let observation =
            R.
              {
                url = snapshot.url;
                title = "";
                text = "";
                dialog = None;
                rows = [];
                downloads = [];
                snapshot;
              }
          in
          let book =
            B.
              {
                file = "books.example.json";
                playbook =
                  {
                    site = "books.example";
                    description = "A book catalogue with Travel categories";
                    entry = "https://books.example/";
                    pages = [];
                    procedures = [];
                    shapes = None;
                    scripts = None;
                  };
                checks = [];
                dir = None;
                scripts = [];
              }
          in
          let unexpected () =
            Alcotest.fail "unexpected browser or procedure planner operation"
          in
          let question = ref None in
          let handler =
            R.
              {
                observe = (fun () -> Ok observation);
                navigate = (fun _ -> unexpected ());
                choose =
                  (fun q ->
                    question := Some q;
                    Leash.Models.choose models q);
                text_value = (fun _ -> unexpected ());
                step =
                  (fun _ ->
                    Ok
                      P.
                        {
                          status = ok (Drive_status.of_string "blocked");
                          steps = [];
                          final = snapshot;
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
          let result =
            match
              R.loop ~handler
                ~now:(fun () -> 0.)
                ~installed:[ book ]
                R.
                  {
                    mission = "collect every book in the Travel category";
                    max_steps = 60;
                    start_url = None;
                    max_procedures = 1;
                    deadline_s = 30;
                    max_plans = 0;
                    dry_run = false;
                    expect = [];
                  }
            with
            | Ok result -> result
            | Error error -> Alcotest.fail error.P.message
          in
          Alcotest.(check int)
            "actual calls include review"
            (if consulted then 2 else 1)
            result.model_calls;
          Alcotest.(check (float 0.0000001))
            "actual cost includes review"
            (if consulted then 0.003 else 0.001)
            (Option.get result.model_cost);
          Alcotest.(check int)
            "one answer per model"
            (if consulted then 2 else 1)
            (List.length
               (List.filter
                  (fun (item : P.playbook_choice) -> item.source = "jev")
                  result.playbook_choices));
          let first = List.hd result.playbook_choices in
          Alcotest.(check string) "original judge" "jev" first.P.source;
          Alcotest.(check (option string))
            "JEV answer remains visible"
            (Some (if probability >= 0.5 then "none" else "book:books.example.json"))
            first.key;
          if consulted then begin
            let last = List.nth result.playbook_choices 1 in
            Alcotest.(check string) "review source" "planner" last.source;
            Alcotest.(check (option string))
              "strict review key"
              (if valid then Some "none" else None)
              last.key;
            Alcotest.(check bool)
              "fallback has trace note" (not valid) (Option.is_some last.note);
            json_equal "planner has no invented distribution" `Null last.probabilities;
            let request =
              List.find
                (fun (r : Server.request) -> r.target = "/chat")
                (Server.requests server)
            in
            let messages = get "messages" (Yojson.Safe.from_string request.body) in
            let user =
              match messages with
              | `List [ _; user ] ->
                  Yojson.Safe.from_string
                    (match get "content" user with `String s -> s | _ -> assert false)
              | _ -> assert false
            in
            let q = Option.get !question in
            json_equal "same instructions" (`String q.instructions)
              (get "instructions" user);
            json_equal "same factual state" q.state (get "state" user);
            json_equal "same options and authored descriptions"
              (`Assoc (List.map (fun (k, v) -> (k, `String v)) q.criteria))
              (get "options" user)
          end;
          Alcotest.(check int)
            "no correction request"
            (if consulted then 2 else 1)
            (List.length (Server.requests server))))

let config () =
  let parse value =
    C.t_of_yojson (`Assoc [ ("models", `Assoc [ ("choice_confidence", value) ]) ])
  in
  Alcotest.(check (float 0.))
    "default threshold" 0.7
    (C.Probability.to_float C.default.models.choice_confidence);
  List.iter
    (fun value ->
      match parse value with
      | Ok _ -> Alcotest.fail "invalid threshold accepted"
      | Error _ -> ())
    [ `Float (-0.1); `Float 1.1; `Float Float.nan; `Float Float.infinity; `String "0.7" ];
  List.iter
    (fun value -> match parse value with Ok _ -> () | Error why -> Alcotest.fail why)
    [ `Int 0; `Int 1; `Float 0.83 ]

let () =
  Alcotest.run "choice-review"
    [
      ( "extr-uhnc run-kli0",
        [
          Alcotest.test_case "fly-2akp low-confidence NONE bypasses planner veto" `Quick
            (review ~probability:0.55 ~threshold:0.7 ~content:{|{"choice":"none"}|}
               ~consulted:true ~valid:true);
          Alcotest.test_case "high top probability ignores margin-like confidence" `Quick
            (review ~probability:0.8 ~threshold:0.7 ~content:"unused" ~consulted:false
               ~valid:false);
          Alcotest.test_case "exact configured boundary does not consult" `Quick
            (review ~probability:0.6 ~threshold:0.6 ~content:"unused" ~consulted:false
               ~valid:false);
          Alcotest.test_case "malformed response retains JEV argmax" `Quick
            (review ~probability:0.6 ~threshold:0.7 ~content:"none" ~consulted:true
               ~valid:false);
          Alcotest.test_case "unknown option fails closed" `Quick
            (review ~probability:0.6 ~threshold:0.7
               ~content:{|{"choice":"other.example"}|} ~consulted:true ~valid:false);
          Alcotest.test_case "extra field fails closed" `Quick
            (review ~probability:0.6 ~threshold:0.7
               ~content:{|{"choice":"none","reason":"extra"}|} ~consulted:true
               ~valid:false);
          Alcotest.test_case "duplicate key fails closed" `Quick
            (review ~probability:0.6 ~threshold:0.7
               ~content:{|{"choice":"none","choice":"none"}|} ~consulted:true ~valid:false);
          Alcotest.test_case "configuration validates threshold" `Quick config;
        ] );
    ]
