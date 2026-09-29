(* L32 — the planner (docs/issues/run/01-run.md, milestone 7; run-w7ke run-rq6i run-2tt3
   run-obtt run-m0r8 run-d99l).

   Two seams at once. The run loop is driven with scripted levels — as test/run_test.ml
   does — and its planner is the production one: {!Leash.Models.levels}.plan over a local
   plaintext chat server (leash_test_support.Fake_systemone, the way
   test/text_helper_test.ml serves the text helper). So every trigger, every answer kind,
   the fail-closed decode with its one retry, the turn cap and cost, the expectations the
   planner attaches and the proposal files are the real code, with no network, no browser
   and no model. *)

module R = Leash.Run
module B = Leash.Playbook
module P = Leash.Protocol
module Fake = Leash_test_support.Fake_systemone
module Config = Leash.Config
module Models = Leash.Models
module Logger = Ox_observability.Logger

let ok = function Ok x -> x | Error why -> Alcotest.fail why

let ran = function
  | Ok x -> x
  | Error (error : P.error) ->
      Alcotest.failf "%s: %s" (P.Error_code.to_string error.P.code) error.P.message

let failed = function
  | Ok _ -> Alcotest.fail "the run succeeded where a refusal was expected"
  | Error error -> error

let code name = ok (P.Error_code.of_string name)
let text_value value = ok (Config.Text.of_string value)
let handle = ok (P.Handle.of_string "t_test")
let snapshot_id = ok (P.Snapshot_id.of_string "s_test")

let detail_code (error : P.error) =
  match error.P.detail with
  | Some (`Assoc fields) -> (
      match List.assoc_opt "code" fields with Some (`String code) -> code | _ -> "")
  | _ -> ""

(* ---------- The page, the playbook and the scripted levels ---------- *)

let site = "site-a.example"
let home_url = "https://site-a.example/"
let cart_url = "https://site-a.example/cart"
let home_text = "Site A home page"

let snapshot ?(url = home_url) ?(title = "Site A") ?dialog () =
  P.
    {
      snapshot = snapshot_id;
      tab = handle;
      url;
      title;
      rows = [];
      total = 0;
      offset = 0;
      truncated = false;
      settled = true;
      dialog;
    }

let observation ?(url = home_url) ?(title = "Site A") ?(text = home_text) ?dialog () =
  R.
    {
      url;
      title;
      text;
      dialog;
      rows = [];
      downloads = [];
      snapshot = snapshot ~url ~title ?dialog ();
    }

let page name url_pattern =
  B.
    {
      name;
      description = name ^ " page";
      url_pattern = Some url_pattern;
      text_marker = None;
    }

let goal text = B.Goal B.{ goal = text; hint = None }

let procedure ?(args = []) ?(expect = [ "the page is home" ]) ~slug ~description steps =
  B.
    {
      slug;
      description;
      args = Some args;
      steps;
      expect;
      expect_timeout_s = None;
      repeat = None;
      max_steps = None;
      deadline_s = None;
    }

(* run-rq6i's playbook: two page kinds, so a planner procedure can name the cart, and one
   procedure the run's own level can be asked for. *)
let playbook
    ?(procedures =
      [ procedure ~slug:"step" ~description:"Do the step." [ goal "Do it." ] ]) () =
  B.
    {
      file = site ^ ".json";
      playbook =
        B.
          {
            site;
            entry = home_url;
            description = "Site A";
            pages = [ page "cart" (cart_url ^ "*"); page "home" (home_url ^ "*") ];
            procedures;
            scripts = None;
          };
      checks = [];
      dir = None;
      scripts = [];
    }

let drive ?(status = "done") ?reason () =
  P.
    {
      status = ok (P.Drive_status.of_string status);
      steps = [];
      final = snapshot ();
      reason;
    }

let expectation ?score ?(passed = true) sentence checker =
  P.{ sentence; checker; passed; score }

let tab_info () =
  P.
    {
      tab = handle;
      url = home_url;
      title = "Site A";
      origin = ok (P.Origin.of_string "agent");
      state = ok (P.State.of_string "owned");
      owner = Some (ok (P.Owner.of_string "alice"));
      generation = 1;
      dialog = None;
      expires = None;
      reason = None;
    }

type harness = {
  mutable books : string list;
  mutable procs : string list;
  mutable verifies : P.run_expectation list list;
  mutable drives : P.drive_result list;
  mutable observations : R.observation list;
  mutable values : (string * string) list;
  mutable clock : float;
  mutable asked : string list;
  mutable steps : R.step_request list;
  mutable handoffs : string list;
  mutable proposed : string list;
  mutable plans : R.plan_request list;
  mutable last : R.observation;
}

let harness ?(books = [ site ]) ?(procs = [ "step" ])
    ?(verifies = [ [ expectation "the page is home" "page_kind" ] ])
    ?(drives = [ drive () ]) ?(observations = [ observation () ])
    ?(values = [ ("product", "Blue Top") ]) () =
  let last = match observations with [] -> observation () | first :: _ -> first in
  {
    books;
    procs;
    verifies;
    drives;
    observations;
    values;
    clock = 0.;
    asked = [];
    steps = [];
    handoffs = [];
    proposed = [];
    plans = [];
    last;
  }

(* A script that repeats its last entry: the loop asks the same levels more than once, and
   a test that wants a different answer later lists it explicitly. *)
let spread label get set =
  match get () with
  | [] -> Alcotest.failf "the scripted run asked for more %s than it was given" label
  | [ one ] -> one
  | one :: rest ->
      set rest;
      one

let next_observation (h : harness) =
  match h.observations with
  | [] -> h.last
  | [ one ] ->
      h.last <- one;
      one
  | one :: rest ->
      h.last <- one;
      h.observations <- rest;
      one

let choice key =
  R.
    {
      key;
      probabilities = `Assoc [ (key, `Float 1.) ];
      confidence = 1.;
      usage = None;
      judgments = [];
    }

let args ?(mission = "buy a Blue Top on site-a.example") ?(max_plans = 3) ?(expect = [])
    () =
  R.{ mission; max_procedures = 40; deadline_s = 900; dry_run = false; max_plans; expect }

(* run-vj48: the loop reaches its one planner through the handler, and here that handler's
   planner is the production plan call over the fake chat server. Every other level is
   scripted, so a test says exactly where the run stops. *)
let handler ~(models : Models.t) (h : harness) : R.handler =
  R.
    {
      observe =
        (fun () ->
          h.asked <- h.asked @ [ "observe" ];
          Ok (next_observation h));
      navigate = (fun _ -> Ok ());
      choose =
        (fun (question : R.question) ->
          h.asked <- h.asked @ [ question.R.name ];
          match question.R.name with
          | "select_playbook" ->
              Ok
                (choice
                   (spread "playbook answers" (fun () -> h.books) (fun x -> h.books <- x)))
          | "select_procedure" ->
              Ok
                (choice
                   (spread "procedure answers"
                      (fun () -> h.procs)
                      (fun x -> h.procs <- x)))
          | other -> Alcotest.failf "unexpected question %s" other);
      text_value =
        (fun (context : Leash.Text_helper.context) ->
          Ok
            (List.assoc_opt context.Leash.Text_helper.field.Leash.Text_helper.label
               h.values));
      step =
        (fun request ->
          h.steps <- h.steps @ [ request ];
          Ok (spread "drives" (fun () -> h.drives) (fun x -> h.drives <- x)));
      verify =
        (fun ~pages:_ ~checks:_ ~timeout_s:_ ->
          Ok
            ( spread "verifications" (fun () -> h.verifies) (fun x -> h.verifies <- x),
              h.last ));
      plan =
        (fun request ->
          h.plans <- h.plans @ [ request ];
          let levels = Models.levels models in
          levels.R.plan ~deadline:(Ox.Duration.seconds 30) request);
      propose =
        (fun ~site proc ->
          match B.propose ~site proc with
          | Ok path ->
              h.proposed <- h.proposed @ [ path ];
              Ok path
          | Error why -> Error P.{ code = code "internal"; message = why; detail = None });
      hand_off =
        (fun ~reason ->
          h.handoffs <- h.handoffs @ [ reason ];
          Ok (tab_info ()));
      script = (fun _ ~args:_ -> Alcotest.fail "planner tests run no script");
    }

let run ?(installed = [ playbook () ]) h models run_args =
  R.loop ~handler:(handler ~models h) ~now:(fun () -> h.clock) ~installed run_args

let status_of (result : P.run_result) = P.Run_status.to_string result.P.status

let check_status label expected (result : P.run_result) =
  Alcotest.(check string) label expected (status_of result)

(* ---------- The fake chat server ---------- *)

let planner_model = "openai/gpt-6-luna"
let key = "test-key"

let models_config ?(api_key = Some (Ox_observability.Redact.make key))
    ?(planner_model = planner_model) ?(planner_reasoning = "high") ?planner_endpoint
    ~chat_base_url () : Config.models =
  {
    Config.api_key;
    systemone_endpoint = text_value "http://127.0.0.1:1/api/v1/systemone";
    jev_model = text_value "typesafe/jev-1.13-20260917";
    chat_base_url = text_value chat_base_url;
    text_model = text_value "inception/mercury-2.5";
    planner_model = text_value planner_model;
    planner_reasoning = text_value planner_reasoning;
    planner_endpoint = Option.map text_value planner_endpoint;
    choice_confidence = Config.default.models.choice_confidence;
  }

let chat_content ?(model = planner_model) content =
  Fake.ok
    (Yojson.Safe.to_string
       (`Assoc
          [
            ("id", `String "gen-1");
            ("model", `String model);
            ( "choices",
              `List
                [
                  `Assoc
                    [
                      ("index", `Int 0);
                      ( "message",
                        `Assoc
                          [ ("role", `String "assistant"); ("content", `String content) ]
                      );
                      ("finish_reason", `String "stop");
                    ];
                ] );
            ( "usage",
              `Assoc
                [
                  ("prompt_tokens", `Int 10);
                  ("completion_tokens", `Int 2);
                  ("total_tokens", `Int 12);
                  ("cost", `Float 0.00042);
                ] );
          ]))

let chat_server ~sw ~net contents =
  let remaining = ref (List.map chat_content contents) in
  Fake.serve ~net ~sw (fun (_ : Fake.request) ->
      match !remaining with
      | reply :: rest ->
          remaining := rest;
          reply
      | [] -> Fake.failure 500 "the chat script is exhausted")

let rig ?(contents = []) ?(api_key = Some (Ox_observability.Redact.make key))
    ?(planner_model = planner_model) ?(planner_reasoning = "high") f =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Info ~service:"leash-planner-tests"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let server = chat_server ~sw ~net:env#net contents in
          let config =
            models_config ~api_key ~chat_base_url:(Fake.url server "") ~planner_model
              ~planner_reasoning ()
          in
          let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
          f env sw models server memory))

(* run-d99l: two routes in one rig, so a configured planner endpoint is distinguishable
   from the route the text helper would use. *)
let rig_two ?(contents = []) ?(planner_model = planner_model)
    ?(planner_reasoning = "high") f =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Info ~service:"leash-planner-tests"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let planner = chat_server ~sw ~net:env#net contents in
          let helper = chat_server ~sw ~net:env#net [] in
          let config =
            models_config ~chat_base_url:(Fake.url helper "")
              ~planner_endpoint:(Fake.url planner "/chat/completions")
              ~planner_model ~planner_reasoning ()
          in
          let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
          f env sw models planner helper memory))

(* ---------- The answers, as the model writes them ---------- *)

let obj fields = `Assoc fields
let str value = `String value

let procedure_json ?(slug = "go-to-cart")
    ?(description = "Open the cart and check it is there.")
    ?(expect = [ "the page is cart" ])
    ?(steps = [ `Assoc [ ("goal", str "Open the cart.") ] ]) () =
  `Assoc
    [
      ("slug", str slug);
      ("description", str description);
      ("steps", `List steps);
      ("expect", `List (List.map (fun sentence -> str sentence) expect));
    ]

let sentences values = `List (List.map (fun value -> str value) values)

let procedure_answer ?expect ?procedure () =
  let procedure = match procedure with Some json -> json | None -> procedure_json () in
  Yojson.Safe.to_string
    (obj
       ([ ("answer", str "procedure"); ("procedure", procedure) ]
       @ match expect with None -> [] | Some values -> [ ("expect", sentences values) ]))

let handoff_answer ?(reason = "the captcha needs you") () =
  Yojson.Safe.to_string (obj [ ("answer", str "handoff"); ("reason", str reason) ])

let fail_answer ?(reason = "the site cannot serve this mission") () =
  Yojson.Safe.to_string (obj [ ("answer", str "fail"); ("reason", str reason) ])

let message i json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt "messages" fields with
      | Some (`List messages) -> (
          match List.nth_opt messages i with
          | Some (`Assoc message) -> (
              match List.assoc_opt "content" message with
              | Some (`String content) -> content
              | _ -> "")
          | _ -> "")
      | _ -> "")
  | _ -> ""

let field name json =
  match json with `Assoc fields -> List.assoc_opt name fields | _ -> None

let string_field name json =
  match field name json with Some (`String value) -> value | _ -> ""

(* run-rq6i: what a planner turn is asked from, for the tests that call the plan seam
   without a loop. *)
let plan_request ?(trigger = R.Blocked) ?(reason = "the procedure level answered BLOCKED")
    () =
  R.
    {
      trigger;
      reason;
      mission = "buy a Blue Top on site-a.example";
      site = Some site;
      playbook = Some (playbook ()).B.playbook;
      recent = [ ("add-to-cart", "verified") ];
      arguments = [ ("product", "Blue Top") ];
      page_kind = Some "home";
      title = "Site A";
      url = home_url;
      text = home_text;
    }

(* ---------- Proposals on disk ---------- *)

let temp_dir prefix =
  let path = Filename.temp_file prefix "" in
  Sys.remove path;
  Unix.mkdir path 0o700;
  path

let rec remove_dir path =
  if Sys.is_directory path then begin
    Sys.readdir path |> Array.iter (fun entry -> remove_dir (Filename.concat path entry));
    Unix.rmdir path
  end
  else Sys.remove path

let read_file path =
  let channel = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let write_file path content =
  ignore (ok (Config.ensure_dir (Filename.dirname path)));
  let channel =
    open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 path
  in
  Fun.protect
    ~finally:(fun () -> close_out channel)
    (fun () -> output_string channel content)

(* The XDG directories are process environment, so these tests set them; the suite is
   single-domain by construction, which is what the multidomain-safety alert on [putenv]
   wants a caller to say. *)
let setenv name value = (Unix.putenv [@alert "-unsafe_multidomain"]) name value

let with_env name value f =
  let previous = Sys.getenv_opt name in
  setenv name value;
  Fun.protect ~finally:(fun () -> setenv name (Option.value ~default:"" previous)) f

(* The run's proposals live under XDG state and the playbooks it must not touch under XDG
   config; one temporary root holds both, and it is removed with the test. *)
let with_xdg f =
  let root = temp_dir "leash-planner-" in
  Fun.protect
    ~finally:(fun () -> remove_dir root)
    (fun () ->
      with_env "XDG_STATE_HOME" root (fun () ->
          with_env "XDG_CONFIG_HOME" root (fun () -> f root)))

let playbook_file root =
  Filename.concat
    (Filename.concat (Filename.concat (Filename.concat root "leash") "playbooks") site)
    "playbook.json"

let proposal_file root slug =
  Filename.concat
    (Filename.concat (Filename.concat root "leash") "proposed")
    (site ^ "-" ^ slug ^ ".json")

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec scan at = at + n <= h && (String.sub haystack at n = needle || scan (at + 1)) in
  n = 0 || scan 0

let trigger_of (request : R.plan_request) = R.trigger_name request.R.trigger

(* ---------- run-w7ke: the three triggers ---------- *)

let triggers () =
  (* run-w7ke: a BLOCKED procedure answer. *)
  rig
    ~contents:[ fail_answer () ]
    (fun _env _sw models server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let result = ran (run h models (args ())) in
      check_status "run-w7ke a BLOCKED answer asks the planner" "blocked" result;
      Alcotest.(check int) "run-w7ke one turn" 1 (List.length result.P.planner_turns);
      Alcotest.(check string)
        "run-w7ke the trigger in the trace" "blocked"
        (List.hd result.P.planner_turns).P.trigger;
      Alcotest.(check (list string))
        "run-w7ke the trigger in the request" [ "blocked" ] (List.map trigger_of h.plans);
      Alcotest.(check int) "run-w7ke one chat call" 1 (List.length (Fake.requests server));
      let request = List.hd h.plans in
      Alcotest.(check string)
        "run-rq6i the request carries the mission" "buy a Blue Top on site-a.example"
        request.R.mission;
      Alcotest.(check bool)
        "run-rq6i the request carries the playbook" true (request.R.playbook <> None);
      Alcotest.(check (option string))
        "run-rq6i the request carries the page kind" (Some "home") request.R.page_kind;
      Alcotest.(check string)
        "run-rq6i the request carries the page text" home_text request.R.text;
      Alcotest.(check (list string))
        "run-rq6i the request carries the trace" []
        (List.map fst request.R.recent));
  (* run-w7ke: a procedure that failed its expectations twice. *)
  rig
    ~contents:[ fail_answer () ]
    (fun _env _sw models _server _memory ->
      let failed_check = expectation "the page is home" "page_kind" ~passed:false in
      let h =
        harness ~procs:[ "step" ]
          ~drives:[ drive () ]
          ~verifies:[ [ failed_check ]; [ failed_check ] ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-w7ke a twice-failed procedure asks the planner" "failed" result;
      Alcotest.(check string)
        "run-w7ke the trigger" "failed"
        (trigger_of (List.hd h.plans));
      Alcotest.(check string)
        "run-w7ke the trigger in the trace" "failed"
        (List.hd result.P.planner_turns).P.trigger);
  (* run-w7ke: an argument the text helper could not fill. *)
  rig
    ~contents:[ fail_answer () ]
    (fun _env _sw models _server _memory ->
      let with_arg =
        playbook
          ~procedures:
            [
              procedure ~args:[ "product" ] ~slug:"find" ~description:"Find the product."
                [ goal "Search for {product}." ];
            ]
          ()
      in
      let h = harness ~procs:[ "find" ] ~values:[] () in
      let result = ran (run ~installed:[ with_arg ] h models (args ())) in
      check_status "run-w7ke an unfillable argument asks the planner" "blocked" result;
      Alcotest.(check string)
        "run-w7ke the trigger" "arguments"
        (trigger_of (List.hd h.plans));
      Alcotest.(check bool)
        "run-w7ke the reason names the argument" true
        (contains (List.hd h.plans).R.reason "product"))

(* ---------- run-rq6i: the three answers ---------- *)

let answers () =
  (* run-rq6i run-m0r8: a procedure is run now, verified like any other, and proposed. *)
  rig
    ~contents:[ procedure_answer () ]
    (fun _env _sw models _server _memory ->
      let h =
        harness ~procs:[ "BLOCKED"; "DONE" ]
          ~drives:[ drive () ]
          ~verifies:
            [
              [ expectation "the page is cart" "page_kind" ];
              [ expectation "the page is cart" "page_kind" ];
            ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-rq6i a procedure answer is run and verified" "done" result;
      Alcotest.(check int) "run-rq6i one procedure" 1 (List.length result.P.procedures);
      let entry = List.hd result.P.procedures in
      Alcotest.(check string) "run-rq6i the planner's slug" "go-to-cart" entry.P.slug;
      Alcotest.(check bool) "run-m0r8 it is marked planned" true entry.P.planned;
      Alcotest.(check string)
        "run-rq6i its step ran" "Open the cart." (List.hd h.steps).R.goal;
      Alcotest.(check string)
        "run-rq6i the answer in the trace" "procedure"
        (List.hd result.P.planner_turns).P.answer;
      Alcotest.(check int)
        "run-m0r8 the verified procedure was proposed" 1 (List.length h.proposed));
  (* run-klp9: a handoff leaves the tab with the human. *)
  rig
    ~contents:[ handoff_answer () ]
    (fun _env _sw models _server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let result = ran (run h models (args ())) in
      check_status "run-klp9 a handoff ends the run" "handoff" result;
      Alcotest.(check (list string))
        "run-klp9 the reason reached the registry" [ "the captcha needs you" ] h.handoffs;
      Alcotest.(check string)
        "run-klp9 the answer in the trace" "handoff"
        (List.hd result.P.planner_turns).P.answer;
      Alcotest.(check (option string))
        "run-klp9 the reason in the trace" (Some "the captcha needs you")
        (List.hd result.P.planner_turns).P.reason);
  (* run-rq6i: a failure names why. *)
  rig
    ~contents:[ fail_answer ~reason:"the offer is gone" () ]
    (fun _env _sw models _server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let result = ran (run h models (args ())) in
      check_status "run-rq6i a fail ends the run" "blocked" result;
      Alcotest.(check bool)
        "run-rq6i the reason is reported" true
        (match result.P.reason with
        | Some reason -> contains reason "the offer is gone"
        | None -> false))

(* ---------- run-rq6i: the fail-closed decode and its one retry ---------- *)

let malformed () =
  (* run-rq6i: a reply that is not the asked shape is shown back with its refusal, once,
     and the second answer is the turn's. *)
  rig
    ~contents:[ "I cannot do that."; fail_answer () ]
    (fun _env _sw models server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let result = ran (run h models (args ())) in
      check_status "run-rq6i the retried turn ends the run" "blocked" result;
      Alcotest.(check int)
        "run-rq6i one turn, two calls" 2
        (List.length (Fake.requests server));
      let second =
        Yojson.Safe.from_string (List.nth (Fake.requests server) 1).Fake.body
      in
      Alcotest.(check string)
        "run-rq6i the refused reply is shown back" "I cannot do that." (message 2 second);
      Alcotest.(check bool)
        "run-rq6i the refusal is shown back" true
        (contains (message 3 second) "refused");
      match (List.hd result.P.planner_turns).P.usage with
      | Some usage ->
          Alcotest.(check int)
            "run-obtt the turn's tokens are both calls" 20 usage.P.input_tokens
      | None -> Alcotest.fail "run-obtt the turn carries no usage");
  (* run-rq6i: a second refusal ends the turn as a model failure. *)
  rig ~contents:[ "not json"; "still not json" ] (fun _env _sw models _server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let error = failed (run h models (args ())) in
      Alcotest.(check string)
        "run-rq6i a twice-refused reply is a model failure" "model-unavailable"
        (P.Error_code.to_string error.P.code);
      Alcotest.(check string)
        "run-rq6i with invalid-response" "invalid-response" (detail_code error));
  (* run-rq6i: every answer that is not exactly one of the three, or names something the
     playbook cannot run, is refused the same way. *)
  let bad =
    [
      ( "an answer that is not one of the three",
        Yojson.Safe.to_string (obj [ ("answer", str "maybe") ]) );
      ( "a handoff with no reason",
        Yojson.Safe.to_string (obj [ ("answer", str "handoff") ]) );
      ("a blank reason", fail_answer ~reason:"   " ());
      ( "a procedure with no procedure",
        Yojson.Safe.to_string (obj [ ("answer", str "procedure") ]) );
      ( "a procedure that also carries a reason",
        Yojson.Safe.to_string
          (obj
             [
               ("answer", str "procedure");
               ("procedure", procedure_json ());
               ("reason", str "because");
             ]) );
      ( "a procedure naming a page kind the playbook does not have",
        procedure_answer
          ~procedure:(procedure_json ~expect:[ "the page is nowhere" ] ())
          () );
      ( "a procedure calling an unknown slug",
        procedure_answer
          ~procedure:(procedure_json ~steps:[ `Assoc [ ("use", str "absent") ] ] ())
          () );
      ( "an attached expectation naming an unknown page kind",
        procedure_answer ~expect:[ "the page is nowhere" ] () );
      ( "a member the answer does not name",
        Yojson.Safe.to_string
          (obj
             [ ("answer", str "fail"); ("reason", str "why"); ("comment", str "extra") ])
      );
    ]
  in
  List.iter
    (fun (label, content) ->
      rig ~contents:[ content; content ] (fun _env _sw models _server _memory ->
          let h = harness ~procs:[ "BLOCKED" ] () in
          let error = failed (run h models (args ())) in
          Alcotest.(check string)
            ("run-rq6i refused: " ^ label)
            "invalid-response" (detail_code error);
          Alcotest.(check string)
            ("run-rq6i a model failure: " ^ label)
            "model-unavailable"
            (P.Error_code.to_string error.P.code)))
    bad

(* ---------- run-rq6i run-d99l: the prompt the planner is asked with ---------- *)

let prompt () =
  rig
    ~contents:[ fail_answer () ]
    (fun _env _sw models server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      ignore (ran (run h models (args ())));
      let request = List.hd (Fake.requests server) in
      Alcotest.(check string)
        "run-rq6i the chat route" "/chat/completions" request.Fake.target;
      let body = Yojson.Safe.from_string request.Fake.body in
      Alcotest.(check string)
        "run-d99l the configured planner model" planner_model (string_field "model" body);
      Alcotest.(check bool)
        "run-rq6i the reply is required to be a JSON object" true
        (match field "response_format" body with
        | Some (`Assoc [ ("type", `String "json_object") ]) -> true
        | _ -> false);
      Alcotest.(check bool)
        "run-d99l the configured reasoning effort" true
        (match field "reasoning" body with
        | Some (`Assoc [ ("effort", `String "high") ]) -> true
        | _ -> false);
      Alcotest.(check bool)
        "run-rq6i the system message is the planner's instruction" true
        (contains (message 0 body) "exactly one JSON object");
      let user = message 1 body in
      Alcotest.(check bool)
        "run-rq6i the mission is asked" true
        (contains user "buy a Blue Top on site-a.example");
      Alcotest.(check bool)
        "run-rq6i the playbook is asked in its schema" true
        (contains user "\"slug\":\"step\"");
      Alcotest.(check bool)
        "run-rq6i the page is asked" true
        (contains user "\"page_kind\":\"home\"");
      Alcotest.(check bool)
        "run-rq6i no page is asked without its text" true (contains user home_text))

(* ---------- run-obtt: the turn cap and the cost ---------- *)

let cap () =
  (* run-obtt: three turns by default, and the trigger that arrives fourth ends the run
     instead of asking again. *)
  rig
    ~contents:
      [
        procedure_answer (); procedure_answer (); procedure_answer (); procedure_answer ();
      ]
    (fun _env _sw models server _memory ->
      let h =
        harness ~procs:[ "BLOCKED" ]
          ~drives:[ drive () ]
          ~verifies:[ [ expectation "the page is cart" "page_kind" ] ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-obtt the cap ends the run" "blocked" result;
      Alcotest.(check int)
        "run-obtt three turns by default" 3
        (List.length result.P.planner_turns);
      Alcotest.(check int)
        "run-obtt three calls, never a fourth" 3
        (List.length (Fake.requests server));
      Alcotest.(check int)
        "run-obtt three procedures ran" 3
        (List.length result.P.procedures);
      Alcotest.(check bool)
        "run-obtt the reason names the cap" true
        (match result.P.reason with
        | Some reason -> contains reason "cap"
        | None -> false));
  (* run-obtt: the cap is the run's, so a test (or a later discovery handler) can set it. *)
  rig
    ~contents:[ procedure_answer (); procedure_answer () ]
    (fun _env _sw models server _memory ->
      let h =
        harness ~procs:[ "BLOCKED" ]
          ~drives:[ drive () ]
          ~verifies:[ [ expectation "the page is cart" "page_kind" ] ]
          ()
      in
      let result = ran (run h models (args ~max_plans:1 ())) in
      check_status "run-obtt a cap of one ends the run" "blocked" result;
      Alcotest.(check int) "run-obtt one turn" 1 (List.length result.P.planner_turns);
      Alcotest.(check int) "run-obtt one call" 1 (List.length (Fake.requests server)))

let usage () =
  (* run-obtt: a turn's tokens ride in the trace, and every call is logged once. *)
  rig
    ~contents:[ fail_answer () ]
    (fun _env _sw models _server memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      let result = ran (run h models (args ())) in
      (match (List.hd result.P.planner_turns).P.usage with
      | Some usage ->
          Alcotest.(check int) "run-obtt the trace's input tokens" 10 usage.P.input_tokens;
          Alcotest.(check int)
            "run-obtt the trace's output tokens" 2 usage.P.output_tokens;
          Alcotest.(check (float 0.000001))
            "run-obtt provider cost reaches trace" 0.00042 usage.P.cost
      | None -> Alcotest.fail "run-obtt the turn carries no usage");
      let logged =
        List.filter
          (fun (record : Logger.record) ->
            record.Logger.level = Logger.Info && record.Logger.msg = "planner usage")
          (Logger.Memory.records memory)
      in
      Alcotest.(check int) "run-obtt one usage line per call" 1 (List.length logged);
      let fields = (List.hd logged).Logger.fields in
      Alcotest.(check string)
        "run-obtt the model is logged" planner_model
        (match List.assoc_opt "model" fields with
        | Some (Logger.String model) -> model
        | _ -> Alcotest.fail "no model field");
      Alcotest.(check int)
        "run-obtt the tokens are logged" 10
        (match List.assoc_opt "prompt_tokens" fields with
        | Some (Logger.Int tokens) -> tokens
        | _ -> Alcotest.fail "no prompt_tokens field");
      Alcotest.(check (float 0.000001))
        "run-obtt provider cost logged" 0.00042
        (match List.assoc_opt "cost" fields with
        | Some (Logger.Float cost) -> cost
        | _ -> Alcotest.fail "no cost field"))

(* ---------- run-2tt3: mission-level expectations ---------- *)

let expectations () =
  (* run-2tt3: attached on the first turn, verified by the DONE guard when the caller
     stated none — the L30 guard with something to verify. *)
  rig
    ~contents:[ procedure_answer ~expect:[ "the page is cart" ] () ]
    (fun _env _sw models _server _memory ->
      let h =
        harness ~procs:[ "BLOCKED"; "DONE" ]
          ~drives:[ drive () ]
          ~verifies:
            [
              [ expectation "the page is cart" "page_kind" ];
              [ expectation "the page is cart" "page_kind" ];
            ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-2tt3 the attached expectation verifies DONE" "done" result;
      Alcotest.(check int)
        "run-2tt3 the mission expectations are the planner's" 1
        (List.length result.P.mission_expectations);
      let checked = List.hd result.P.mission_expectations in
      Alcotest.(check string)
        "run-2tt3 the sentence" "the page is cart" checked.P.sentence;
      Alcotest.(check bool) "run-2tt3 and it held" true checked.P.passed);
  (* run-2tt3 run-4j1v: and a DONE the attached expectation does not verify is refused to
     the planner again. *)
  rig
    ~contents:
      [
        procedure_answer ~expect:[ "the page is cart" ] ();
        fail_answer ~reason:"the cart was never reached" ();
      ]
    (fun _env _sw models _server _memory ->
      let h =
        harness ~procs:[ "BLOCKED"; "DONE" ]
          ~drives:[ drive () ]
          ~verifies:
            [
              [ expectation "the page is cart" "page_kind" ];
              [ expectation "the page is cart" "page_kind" ~passed:false ];
            ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-2tt3 a failing attached expectation refuses DONE" "blocked" result;
      Alcotest.(check int) "run-2tt3 two turns" 2 (List.length result.P.planner_turns);
      Alcotest.(check int)
        "run-2tt3 the failing expectation is reported" 1
        (List.length result.P.mission_expectations);
      Alcotest.(check bool)
        "run-2tt3 and it did not hold" false
        (List.hd result.P.mission_expectations).P.passed);
  (* run-2tt3: only the first turn may attach them: the second turn's attachment is
     ignored, and DONE falls back to the last verified procedure's expectations. *)
  rig
    ~contents:[ procedure_answer (); procedure_answer ~expect:[ "the page is cart" ] () ]
    (fun _env _sw models _server _memory ->
      let h =
        harness
          ~procs:[ "BLOCKED"; "BLOCKED"; "BLOCKED"; "BLOCKED"; "DONE" ]
          ~drives:[ drive () ]
          ~verifies:[ [ expectation "the page is cart" "page_kind" ] ]
          ()
      in
      let result = ran (run h models (args ())) in
      check_status "run-2tt3 a later turn's attachment is ignored" "done" result;
      Alcotest.(check int)
        "run-2tt3 two turns were taken" 2
        (List.length result.P.planner_turns);
      Alcotest.(check int)
        "run-2tt3 no mission expectations" 0
        (List.length result.P.mission_expectations))

(* ---------- run-m0r8: proposals and the operator's accept ---------- *)

let proposals () =
  (* run-m0r8: a planner-written procedure that ran and passed its expectations is written
     under XDG state, reported in the run result, and the playbook is left exactly as it
     was: nothing merges it but the operator. *)
  with_xdg (fun root ->
      let installed = playbook () in
      let file = playbook_file root in
      write_file file (Yojson.Safe.pretty_to_string (B.yojson_of_t installed.B.playbook));
      let before = read_file file in
      let run_result = ref None in
      rig
        ~contents:[ procedure_answer () ]
        (fun _env _sw models _server _memory ->
          let h =
            harness ~procs:[ "BLOCKED"; "DONE" ]
              ~drives:[ drive () ]
              ~verifies:
                [
                  [ expectation "the page is cart" "page_kind" ];
                  [ expectation "the page is cart" "page_kind" ];
                ]
              ()
          in
          let outcome = ran (run ~installed:[ installed ] h models (args ())) in
          run_result := Some outcome;
          let result = outcome in
          check_status "run-m0r8 the planned procedure is done" "done" result;
          let path = proposal_file root "go-to-cart" in
          Alcotest.(check bool)
            "run-m0r8 the proposal file exists" true (Sys.file_exists path);
          Alcotest.(check (list string))
            "run-m0r8 the run reports the proposal" [ path ] result.P.proposals;
          Alcotest.(check string)
            "run-m0r8 the playbook was not touched" before (read_file file);
          let proposal = ok (B.proposal_of_yojson (Yojson.Safe.from_file path)) in
          Alcotest.(check string)
            "run-m0r8 the proposal names the site" site proposal.B.site;
          Alcotest.(check string)
            "run-m0r8 the proposal carries the procedure" "go-to-cart"
            proposal.B.procedure.B.slug);
      ignore (Option.get !run_result);
      (* the operator accepts it *)
      let accepted = ok (B.accept (proposal_file root "go-to-cart")) in
      Alcotest.(check string) "run-m0r8 the accepted site" site accepted.B.site;
      Alcotest.(check string) "run-m0r8 the accepted slug" "go-to-cart" accepted.B.slug;
      Alcotest.(check bool) "run-m0r8 it was appended" false accepted.B.replaced;
      let merged = ok (B.load (Filename.dirname file)) in
      Alcotest.(check (list string))
        "run-m0r8 the playbook grew by one procedure" [ "step"; "go-to-cart" ]
        (List.map
           (fun (proc : B.procedure) -> proc.B.slug)
           merged.B.playbook.B.procedures);
      Alcotest.(check bool)
        "run-m0r8 the merged procedure's expectations resolve" true
        (match List.assoc_opt "go-to-cart" merged.B.checks with
        | Some _ -> true
        | None -> false))

let accept_rules () =
  (* run-m0r8: accept replaces the same slug, refuses a site it cannot find, refuses a
     procedure the playbook cannot run, and refuses a file that is not a proposal. *)
  with_xdg (fun root ->
      let installed = playbook () in
      let file = playbook_file root in
      write_file file (Yojson.Safe.pretty_to_string (B.yojson_of_t installed.B.playbook));
      let first = ok (B.propose ~site (ok (B.procedure_of_yojson (procedure_json ())))) in
      let appended = ok (B.accept first) in
      Alcotest.(check bool) "run-m0r8 the first accept appends" false appended.B.replaced;
      let revised =
        ok
          (B.procedure_of_yojson
             (procedure_json ~description:"Open the cart, revised." ()))
      in
      let second = ok (B.propose ~site revised) in
      let replaced = ok (B.accept second) in
      Alcotest.(check bool)
        "run-m0r8 a second proposal for the same slug replaces it" true
        replaced.B.replaced;
      let merged = ok (B.load (Filename.dirname file)) in
      Alcotest.(check int)
        "run-m0r8 still one procedure plus the playbook's own" 2
        (List.length merged.B.playbook.B.procedures);
      let procedure =
        List.find
          (fun (proc : B.procedure) -> proc.B.slug = "go-to-cart")
          merged.B.playbook.B.procedures
      in
      Alcotest.(check string)
        "run-m0r8 the revised description is the one kept" "Open the cart, revised."
        procedure.B.description;
      (* a site no installed playbook serves *)
      let orphan = ok (B.propose ~site:"other.example" revised) in
      Alcotest.(check bool)
        "run-m0r8 an unserved site is refused" true
        (match B.accept orphan with
        | Error why -> contains why "no installed playbook"
        | Ok _ -> false);
      (* a procedure the playbook could not run *)
      let bad =
        ok
          (B.procedure_of_yojson
             (procedure_json ~slug:"bad" ~steps:[ `Assoc [ ("use", str "absent") ] ] ()))
      in
      let bad_path = ok (B.propose ~site bad) in
      let before = read_file file in
      Alcotest.(check bool)
        "run-m0r8 an unrunnable procedure is refused" true
        (match B.accept bad_path with
        | Error why -> contains why "unknown slug"
        | Ok _ -> false);
      Alcotest.(check string)
        "run-m0r8 and the playbook is untouched" before (read_file file);
      (* not a proposal at all *)
      write_file second "{ not json";
      Alcotest.(check bool)
        "run-m0r8 a file that is not JSON is refused" true
        (match B.accept second with
        | Error why -> contains why "invalid JSON"
        | Ok _ -> false))

(* ---------- run-d99l: the configurable model, effort and endpoint ---------- *)

let config_test () =
  Alcotest.(check string)
    "run-d99l the default planner model" "openai/gpt-6-luna"
    (Config.Text.to_string Config.default.models.Config.planner_model);
  Alcotest.(check string)
    "run-d99l the default reasoning effort" "high"
    (Config.Text.to_string Config.default.models.Config.planner_reasoning);
  Alcotest.(check bool)
    "run-d99l the planner shares the chat route by default" true
    (Config.default.models.Config.planner_endpoint = None);
  Alcotest.(check bool)
    "run-d99l config init names the key" true
    (contains Config.default_toml "planner_model");
  (* a configured model and effort are what the request names *)
  rig_two
    ~contents:[ fail_answer () ]
    ~planner_model:"openai/gpt-6-luna-preview" ~planner_reasoning:"low"
    (fun _env _sw models planner helper _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      ignore (ran (run h models (args ())));
      Alcotest.(check int)
        "run-d99l the planner went to its configured endpoint" 1
        (List.length (Fake.requests planner));
      Alcotest.(check int)
        "run-d99l and not to the chat route" 0
        (List.length (Fake.requests helper));
      let body = Yojson.Safe.from_string (List.hd (Fake.requests planner)).Fake.body in
      Alcotest.(check string)
        "run-d99l the configured planner model" "openai/gpt-6-luna-preview"
        (string_field "model" body);
      Alcotest.(check bool)
        "run-d99l the configured effort" true
        (match field "reasoning" body with
        | Some (`Assoc [ ("effort", `String "low") ]) -> true
        | _ -> false));
  (* "none" turns reasoning off *)
  rig
    ~contents:[ fail_answer () ]
    ~planner_reasoning:"none"
    (fun _env _sw models server _memory ->
      let h = harness ~procs:[ "BLOCKED" ] () in
      ignore (ran (run h models (args ())));
      let body = Yojson.Safe.from_string (List.hd (Fake.requests server)).Fake.body in
      Alcotest.(check bool)
        "run-d99l none turns reasoning off" true
        (match field "reasoning" body with
        | Some (`Assoc [ ("enabled", `Bool false) ]) -> true
        | _ -> false))

let missing_key () =
  (* run-d99l: without a key the planner refuses before anything is sent. *)
  rig ~api_key:None (fun _env _sw models server _memory ->
      let levels = Models.levels models in
      let error =
        failed (levels.R.plan ~deadline:(Ox.Duration.seconds 30) (plan_request ()))
      in
      Alcotest.(check string)
        "run-d99l a keyless planner is missing-key" "missing-key" (detail_code error);
      Alcotest.(check string)
        "run-d99l and a model failure" "model-unavailable"
        (P.Error_code.to_string error.P.code);
      Alcotest.(check int)
        "run-d99l nothing was sent" 0
        (List.length (Fake.requests server)))

(* L33 run-xda7: accepting an isolated complete proposal installs a new site only
   after explicit operator acceptance. *)
let discover_accept () =
  with_xdg (fun root ->
      let draft =
        B.
          {
            site = "new.example";
            entry = "https://new.example/";
            description = "Discovered site";
            pages =
              [
                {
                  name = "home";
                  description = "Home page";
                  url_pattern = Some "https://new.example/*";
                  text_marker = None;
                };
              ];
            procedures =
              [
                {
                  slug = "browse";
                  description = "Browse home";
                  args = None;
                  steps = [ Goal { goal = "Inspect home"; hint = None } ];
                  expect = [ "the page is home" ];
                  expect_timeout_s = None;
                  repeat = None;
                  max_steps = None;
                  deadline_s = None;
                };
              ];
            scripts = None;
          }
      in
      let path = ok (B.propose_book draft) in
      let target =
        Filename.concat (Filename.concat (B.directory ()) "new.example") "playbook.json"
      in
      Alcotest.(check bool) "proposal exists" true (Sys.file_exists path);
      Alcotest.(check bool) "not installed without accept" false (Sys.file_exists target);
      let accepted = ok (B.accept path) in
      Alcotest.(check string) "accepted new site" target accepted.B.playbook;
      let loaded = ok (B.load (Filename.dirname target)) in
      Alcotest.(check int) "page installed" 1 (List.length loaded.playbook.pages);
      Alcotest.(check int)
        "procedure installed" 1
        (List.length loaded.playbook.procedures);
      ignore root)

let () =
  Alcotest.run "L32 planner"
    [
      ( "L32",
        [
          Alcotest.test_case "run-w7ke triggers" `Quick triggers;
          Alcotest.test_case "run-rq6i answers" `Quick answers;
          Alcotest.test_case "run-rq6i malformed replies" `Quick malformed;
          Alcotest.test_case "run-rq6i prompt" `Quick prompt;
          Alcotest.test_case "run-obtt turn cap" `Quick cap;
          Alcotest.test_case "run-obtt usage" `Quick usage;
          Alcotest.test_case "run-2tt3 mission expectations" `Quick expectations;
          Alcotest.test_case "run-m0r8 proposals" `Quick proposals;
          Alcotest.test_case "run-m0r8 accept" `Quick accept_rules;
          Alcotest.test_case "run-xda7 discover acceptance" `Quick discover_accept;
          Alcotest.test_case "run-d99l configurable planner" `Quick config_test;
          Alcotest.test_case "run-d99l missing key" `Quick missing_key;
        ] );
    ]
