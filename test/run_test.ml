(* pilot-ukoh pilot-eu1c pilot-x1f3 pilot-8csf pilot-gt2h pilot-s954
   pilot-rdjv pilot-02ij pilot-e4sh pilot-a4ua pilot-oijk pilot-3egp:
   the mission pilot over scripted handlers, with no browser or model. *)
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
      image_input = None;
      url = snapshot.url;
      title = snapshot.title;
      text;
      rows = [];
      downloads = [];
      dialog = None;
    }

let drive status =
  P.
    {
      status = ok (Drive_status.of_string status);
      steps = [];
      final = snapshot;
      operator_state = None;
      reason = None;
    }

let reply answer =
  R.
    {
      answer;
      expect = [];
      usage = None;
      reasoning_summary = Some "pilot decision";
      secrets_for_operator = [];
    }

let params ?(dry_run = false) ?(turns = 12) ?(mission = "Find a fact") () =
  R.
    {
      mission;
      max_steps = 15;
      start_url = None;
      max_procedures = 40;
      deadline_s = 600;
      dry_run;
      max_plans = turns;
      expect = [];
    }

let harness ?(text = "Fact 42") ?(statuses = [ "done" ]) answers =
  let answers = ref answers
  and requests = ref []
  and goals = ref []
  and statuses = ref statuses in
  let pop values =
    match !values with
    | [] -> Alcotest.fail "unexpected callback"
    | value :: rest ->
        values := rest;
        value
  in
  let handler =
    R.
      {
        observe = (fun ~image:_ () -> Ok (page text));
        navigate = (fun _ -> Ok ());
        choose = (fun _ -> Alcotest.fail "mission called JEV choice");
        text_value = (fun _ -> Ok None);
        step =
          (fun request ->
            goals := request :: !goals;
            Ok (drive (pop statuses)));
        verify = (fun ~pages:_ ~checks:_ ~timeout_s:_ -> Ok ([], page text));
        plan =
          (fun request ->
            requests := request :: !requests;
            Ok (pop answers));
        propose = (fun ~site:_ _ -> Alcotest.fail "pilot compiled a procedure");
        hand_off =
          (fun ~reason:_ ->
            Ok
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
                });
        script = (fun _ ~args:_ -> Alcotest.fail "unexpected script");
      }
  in
  (handler, requests, goals)

let finish = reply (R.Done { result = "42"; evidence = [ "Fact 42" ] })

let legs_return () =
  List.iter
    (fun status ->
      let h, requests, goals =
        harness ~statuses:[ status ] [ reply (R.Leg "Open account"); finish ]
      in
      let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
      Alcotest.(check string)
        "mission done only by pilot" "done"
        (P.Run_status.to_string r.status);
      Alcotest.(check int) "two pilot turns" 2 r.pilot_turns;
      Alcotest.(check int) "one local goal" 1 (List.length !goals);
      Alcotest.(check int) "local cap" 15 (List.hd !goals).max_steps;
      let previous = (List.hd !requests).R.legs in
      Alcotest.(check string) "previous outcome" status (List.hd previous).outcome)
    [ "done"; "blocked" ]

let bounded_context () =
  let h, requests, _ = harness ~text:(String.make 9000 'x') [ finish ] in
  let row =
    P.
      {
        index = 1;
        role = "button";
        name = "Open";
        value = None;
        state = None;
        options = None;
        box = None;
      }
  in
  let rows = List.init 300 (fun i -> { row with P.index = i + 1 }) in
  let h =
    {
      h with
      R.observe =
        (fun ~image:_ () ->
          Ok
            {
              (page (String.make 9000 'x')) with
              R.snapshot = { snapshot with rows; total = 300 };
            });
    }
  in
  ignore (ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())));
  Alcotest.(check int) "rows bound" 250 (List.length (List.hd !requests).snapshot.rows);
  Alcotest.(check int) "page text bound" 6000 (String.length (List.hd !requests).text)

let dry_run () =
  let h, _, goals = harness [ reply (R.Leg "Open account") ] in
  let h =
    { h with R.navigate = (fun _ -> Alcotest.fail "dry run navigated initial URL") }
  in
  let args =
    { (params ~dry_run:true ()) with R.start_url = Some "https://site.example/" }
  in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] args) in
  Alcotest.(check string)
    "first choice is visible" "Open account"
    (Yojson.Safe.Util.to_string
       (Yojson.Safe.Util.member "goal" (Yojson.Safe.Util.member "pilot_choice" r.data)));
  Alcotest.(check int) "no leg dispatched" 0 (List.length !goals);
  Alcotest.(check string) "decision" "leg" (Option.get r.reason);
  Alcotest.(check string)
    "reasoning summary" "pilot decision"
    (Option.get r.reasoning_summary)

let turn_limit () =
  let h, _, _ = harness [ reply (R.Notify "Still reading") ] in
  let r =
    ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ~turns:1 ()))
  in
  Alcotest.(check string) "pilot cap" "limit" (P.Run_status.to_string r.status)

let secrets () =
  let generated = "generated-password" and supplied = "supplied-password" in
  let first =
    {
      finish with
      R.secrets_for_operator = [ ("NEW", generated) ];
      answer = R.Notify generated;
    }
  in
  let last = reply (R.Done { result = supplied ^ generated; evidence = [ supplied ] }) in
  let h, requests, _ = harness ~text:supplied [ first; last ] in
  let r =
    ran
      (R.loop ~handler:h
         ~now:(fun () -> 0.)
         ~installed:[]
         ~secrets:[ ("PASS", supplied) ]
         (params ()))
  in
  let contains needle text =
    try
      ignore (Str.search_forward (Str.regexp_string needle) text 0);
      true
    with Not_found -> false
  in
  List.iter
    (fun request ->
      Alcotest.(check bool)
        "secret excluded from request" false
        (contains supplied request.R.text))
    !requests;
  let public =
    { r with P.secrets_for_operator = [] }
    |> P.yojson_of_run_result |> Yojson.Safe.to_string
  in
  Alcotest.(check bool)
    "supplied secret excluded from reply" false (contains supplied public);
  Alcotest.(check bool)
    "generated secret excluded from public reply" false (contains generated public);
  Alcotest.(check string)
    "generated only in operator field" generated
    (List.assoc "NEW" r.secrets_for_operator)

let handoff_returns () =
  let h, _, _ = harness [ reply (R.Handoff "Login"); finish ] in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  Alcotest.(check int) "pilot resumes" 2 r.pilot_turns

(* pilot-a4ua: row actions stay bounded and dangerous intents need a positive mission. *)
let action_refusal () =
  List.iter
    (fun (name, mission, allowed) ->
      let row =
        P.
          {
            index = 1;
            role = "button";
            name;
            value = None;
            state = None;
            options = None;
            box = None;
          }
      in
      let observation = page "Ready" in
      let observation =
        {
          observation with
          R.snapshot = { snapshot with rows = [ row ]; total = 1 };
          rows = [ ("button", name) ];
        }
      in
      let h, _, _ =
        harness
          [
            reply
              (R.Act
                 (P.Click
                    P.
                      {
                        tab;
                        snapshot = sid;
                        index = 1;
                        snap = None;
                        match_ = None;
                        limit = None;
                      }));
            finish;
          ]
      in
      let h = { h with R.observe = (fun ~image:_ () -> Ok observation) } in
      let dispatched = ref 0 in
      let result =
        ran
          (R.loop ~handler:h
             ~now:(fun () -> 0.)
             ~installed:[]
             ~planner_action:(fun _ ->
               incr dispatched;
               Ok
                 P.
                   {
                     tab;
                     url = snapshot.url;
                     title = snapshot.title;
                     snapshot = None;
                     dialog = None;
                     popups = [];
                     hits = None;
                     shots = None;
                     via = None;
                   })
             (params ~mission ()))
      in
      Alcotest.(check int)
        "only named positive intent dispatches"
        (if allowed then 1 else 0)
        !dispatched;
      let turn = List.hd result.planner_turns in
      Alcotest.(check bool)
        "refusal is visible" (not allowed)
        (turn.reason <> Some "pilot decision"))
    [
      ("Pay", "Inspect account", false);
      ("Delete account", "Inspect account", false);
      ("Send", "Do not send the message", false);
      ("Pay", "Pay and send a message", true);
      ("Send", "Pay and send a message", true);
    ]

let empty_result () =
  let h, _, _ = harness [ reply (R.Done { result = ""; evidence = [] }) ] in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  Alcotest.(check string) "empty done refused" "failed" (P.Run_status.to_string r.status)

(* pilot-3egp: a mission finished by the pilot's own acts is remembered — the acts as
   goal steps in JEV's language, the final page as the expectation when the pilot gave
   none (U2 on Tauron finished done twice and wrote nothing). *)
let act_memory
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let dir = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-run-memory-" "" in
  Ox_caps.Cap_sys.remove ~caps dir;
  Ox_caps.Cap_unix.mkdir ~caps dir 0o700;
  Ox_caps.Cap_unix.putenv ~caps "XDG_STATE_HOME" dir;
  Ox_caps.Cap_unix.putenv ~caps "XDG_CONFIG_HOME" dir;
  let row =
    P.
      {
        index = 1;
        role = "link";
        name = "Invoices";
        value = None;
        state = None;
        options = None;
        box = None;
      }
  in
  let h, _, _ =
    harness
      [
        reply
          (R.Act
             (P.Click
                P.
                  {
                    tab;
                    snapshot = sid;
                    index = 1;
                    snap = None;
                    match_ = None;
                    limit = None;
                  }));
        finish;
      ]
  in
  let h =
    {
      h with
      R.observe =
        (fun ~image:_ () ->
          Ok
            {
              (page "Invoices") with
              R.snapshot = { snapshot with rows = [ row ]; total = 1 };
            });
    }
  in
  let clicked =
    P.
      {
        tab;
        url = snapshot.url;
        title = snapshot.title;
        snapshot = None;
        dialog = None;
        popups = [];
        hits = None;
        shots = None;
        via = None;
      }
  in
  Eio_main.run (fun _ ->
      Eio.Switch.run (fun sw ->
          let memory =
            Leash.Learning.create ~sw ~caps ~config:Leash.Config.default.learning
              ~warn:ignore ()
          in
          ignore
            (ran
               (R.loop ~handler:h
                  ~now:(fun () -> 0.)
                  ~installed:[] ~learning:memory
                  ~planner_action:(fun _ -> Ok clicked)
                  (params ())));
          Leash.Learning.await_pending memory;
          match Leash.Learning.candidates memory ~site:"site.example" ~kind:None with
          | [ (proc, _) ] ->
              Alcotest.(check bool)
                "act remembered as a leg" true
                (proc.steps
                = [
                    Leash.Playbook.Goal
                      { goal = "Click the link named Invoices"; hint = None };
                  ]);
              Alcotest.(check int) "an expectation" 1 (List.length proc.expect)
          | found ->
              Alcotest.failf "expected one remembered procedure, got %d"
                (List.length found)))

let secret_dispatch () =
  let h, requests, _ =
    harness
      [
        reply
          (R.Act
             (P.Fill
                P.
                  {
                    tab;
                    snapshot = sid;
                    index = 1;
                    text = "PASS";
                    snap = None;
                    match_ = None;
                    limit = None;
                  }));
        finish;
      ]
  in
  let row =
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
  in
  let h =
    {
      h with
      R.observe =
        (fun ~image:_ () ->
          Ok
            {
              (page "Ready") with
              R.snapshot = { snapshot with rows = [ row ]; total = 1 };
            });
    }
  in
  let sent = ref None in
  ignore
    (ran
       (R.loop ~handler:h
          ~now:(fun () -> 0.)
          ~installed:[]
          ~secrets:[ ("PASS", "actual-password") ]
          ~planner_action:(fun command ->
            (match command with
            | P.Fill a -> sent := Some a.text
            | _ -> Alcotest.fail "not Fill");
            Ok
              P.
                {
                  tab;
                  url = snapshot.url;
                  title = snapshot.title;
                  snapshot = None;
                  dialog = None;
                  popups = [];
                  hits = None;
                  shots = None;
                  via = None;
                })
          (params ())));
  Alcotest.(check (option string))
    "dispatch resolves secret name" (Some "actual-password") !sent;
  (* pilot-x1f3: the pilot sees its own act in the next turn's history, by secret name. *)
  let history = (List.hd !requests).R.legs in
  Alcotest.(check (list string))
    "act is in the history"
    [ "Type PASS into the textbox named Password" ]
    (List.map (fun (leg : R.leg) -> leg.goal) history);
  Alcotest.(check string) "act outcome" "done" (List.hd history).outcome

(* pic-7ozf pic-k4ij pic-cqcf: explicit observation is bounded; focused secrets
   dispatch once and native evidence is redacted before the trace boundary. *)
let picture_turns () =
  let h, requests, _ =
    harness
      [
        reply R.Observe_image;
        reply (R.Act (P.Type { tab; text = "PASS"; shot = None }));
        finish;
      ]
  in
  let observed = ref [] and acts = ref 0 and evidence = ref [] in
  let h =
    {
      h with
      R.observe =
        (fun ~image () ->
          observed := image :: !observed;
          Ok
            {
              (page "Ready") with
              image_input = (if image then Some (Bytes.of_string "owned PNG") else None);
            });
    }
  in
  ignore
    (ran
       (R.loop ~handler:h
          ~now:(fun () -> 0.)
          ~installed:[]
          ~secrets:[ ("PASS", "actual-password") ]
          ~on_planner_step:(fun step ->
            evidence := P.yojson_of_planner_step step :: !evidence)
          ~planner_action:(fun command ->
            incr acts;
            (match command with
            | P.Type a ->
                Alcotest.(check string)
                  "protected reference resolves only at dispatch" "actual-password" a.text
            | _ -> Alcotest.fail "not focused type");
            Ok
              P.
                {
                  tab;
                  url = snapshot.url;
                  title = snapshot.title;
                  snapshot = None;
                  dialog = None;
                  popups = [];
                  via = None;
                  shots = None;
                  hits =
                    Some
                      [
                        {
                          at = { x = 1.; y = 2. };
                          sampled_at = { x = 1.; y = 2. };
                          element = "actual-password";
                          hit_role = Some "textbox";
                          hit_label = Some "actual-password";
                        };
                      ];
                })
          (params ())));
  Alcotest.(check (list bool))
    "explicit image observation flag" [ false; true; false ] (List.rev !observed);
  Alcotest.(check int) "focused type executes once" 1 !acts;
  Alcotest.(check bool)
    "actual owned image reaches the next pilot turn" true
    (List.exists
       (fun (r : R.plan_request) -> r.image_input = Some (Bytes.of_string "owned PNG"))
       !requests);
  let wire = Yojson.Safe.to_string (`List !evidence) in
  Alcotest.(check bool)
    "native hit evidence has no protected value" false
    (try
       ignore (Str.search_forward (Str.regexp_string "actual-password") wire 0);
       true
     with Not_found -> false);
  let h, _, _ = harness [ reply R.Observe_image ] in
  let observed = ref [] in
  let h =
    {
      h with
      R.observe =
        (fun ~image () ->
          observed := image :: !observed;
          Ok (page "Ready"));
    }
  in
  ignore (ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ~turns:1 ())));
  Alcotest.(check (list bool))
    "no useless image after the final allowed turn" [ false ] !observed

let leg_failure_visible () =
  let h, requests, _ = harness [ reply (R.Leg "Open account"); finish ] in
  let h =
    {
      h with
      R.step =
        (fun _ ->
          Error
            (P.make_error
               (ok (P.Error_code.of_string "internal"))
               ~message:"navigator failed"));
    }
  in
  let result = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  Alcotest.(check (option string))
    "navigator failure is durable" (Some "navigator failed")
    (List.hd result.procedures).reason;
  Alcotest.(check string)
    "failed navigator returns to pilot" "failed"
    (List.hd (List.hd !requests).R.legs).outcome

let dangerous_leg () =
  let h, requests, goals = harness [ reply (R.Leg "Confirm payment"); finish ] in
  let result = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  Alcotest.(check (option string))
    "refusal is durable" (Some "refused payment: mission does not name that action")
    (List.hd result.procedures).reason;
  Alcotest.(check int) "unsafe leg never dispatches" 0 (List.length !goals);
  Alcotest.(check string)
    "unsafe leg is audited" "refused" (List.hd (List.hd !requests).R.legs).outcome

(* pilot-x1f3: a twice-refused pilot reply costs one turn, not the mission. *)
let refused_reply_costs_a_turn () =
  let h, requests, _ = harness [ finish ] in
  let first = ref true in
  let h =
    {
      h with
      R.plan =
        (fun request ->
          if !first then (
            first := false;
            Error
              (P.make_error
                 ~detail:(`Assoc [ ("code", `String "invalid-response") ])
                 (ok (P.Error_code.of_string "model-unavailable"))
                 ~message:"act refused"))
          else h.R.plan request);
    }
  in
  let r = ran (R.loop ~handler:h ~now:(fun () -> 0.) ~installed:[] (params ())) in
  Alcotest.(check string) "mission still done" "done" (P.Run_status.to_string r.status);
  Alcotest.(check string)
    "refusal is in the next history" "refused: act refused"
    (List.hd (List.hd !requests).R.legs).outcome

(* pilot-gt2h: whole words; navigation that names a section is not an action (U1, Tauron). *)
let unsafe_words () =
  List.iter
    (fun (text, expected) ->
      Alcotest.(check (option string)) text expected (R.unsafe_action text))
    [
      ("Open the section showing invoices, payments, or outstanding balances", None);
      ("Open Messages", None);
      ("Show deleted items", None);
      ("Confirm payment", Some "payment");
      ("Click the button named Pay now", Some "payment");
      ("Kupuję i płacę", Some "payment");
      ("Place order", Some "payment");
      ("Delete this address", Some "deletion");
      ("Usuń konto", Some "deletion");
      ("Send message", Some "messaging");
      ("Wyślij", Some "messaging");
    ]

let schema_redaction () =
  let h, _, _ = harness [ finish ] in
  Alcotest.(check bool)
    "redaction that changes typed keys fails closed" true
    (Result.is_error
       (R.loop ~handler:h
          ~now:(fun () -> 0.)
          ~installed:[]
          ~secrets:[ ("PASS", "title") ]
          (params ())))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "mission pilot"
    [
      ( "pilot",
        List.map
          (fun (name, test) -> Alcotest.test_case name `Quick test)
          [
            ("leg DONE/BLOCKED return", legs_return);
            ("bounded context", bounded_context);
            ("dry run", dry_run);
            ("turn cap", turn_limit);
            ("secrets", secrets);
            ("handoff resumes", handoff_returns);
            ("dangerous action refusal", action_refusal);
            ("done result required", empty_result);
            ("secret dispatch", secret_dispatch);
            ("pic-cqcf bounded image turns and protected focused type", picture_turns);
            ("failed leg context", leg_failure_visible);
            ("redaction fails closed", schema_redaction);
            ("dangerous leg refusal", dangerous_leg);
            ("refusal words are whole words", unsafe_words);
            ("refused reply costs a turn", refused_reply_costs_a_turn);
            ("acts are remembered", act_memory ~caps);
          ] );
    ]
