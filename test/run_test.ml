(* L31 (docs/issues/run/01-run.md, milestone 7): the run loop with scripted handlers.

   Every test here crosses the loop's own seam: {!Leash.Run.loop} is called with a handler
   made of closures, so no browser, model, clock or file is touched, and the recorded JEV
   answers of the L30 measurement (run-snk4) drive the levels exactly as the model did. The
   production wiring is covered at the control seam in test/control_test.ml. *)

module R = Leash.Run
module B = Leash.Playbook
module P = Leash.Protocol

let ok = function Ok x -> x | Error why -> Alcotest.fail why

let ran = function
  | Ok x -> x
  | Error (error : P.error) ->
      Alcotest.failf "%s: %s" (P.Error_code.to_string error.P.code) error.P.message

let handle = ok (P.Handle.of_string "t_test")
let snapshot_id = ok (P.Snapshot_id.of_string "s_test")

let snapshot ?(url = "https://site-a.example/") ?(title = "A page") ?dialog () =
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

let observation ?(url = "https://site-a.example/") ?(title = "A page") ?(text = "")
    ?dialog () =
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

let page ?url_pattern ?text_marker name =
  B.{ name; description = name ^ " page"; url_pattern; text_marker }

let goal ?hint text = B.Goal B.{ goal = text; hint }
let use ?args ?optional slug = B.Use B.{ use = slug; args; optional }

let procedure ?(args = []) ?(expect = []) ?max_steps ?deadline_s ~slug ~description steps
    =
  B.
    {
      slug;
      description;
      args = Some args;
      steps;
      expect;
      expect_timeout_s = None;
      max_steps;
      deadline_s;
    }

let book ~site ~entry ?(pages = []) procedures =
  B.
    {
      file = site ^ ".json";
      playbook = B.{ site; entry; description = site ^ " playbook"; pages; procedures };
      checks = [];
    }

let choice key =
  R.
    {
      key;
      probabilities = `Assoc [ (key, `Float 1.) ];
      confidence = 1.;
      usage = Some P.{ input_tokens = 10; output_tokens = 2; cost = 0.0001 };
    }

let field_string key = function
  | `Assoc fields -> (
      match List.assoc_opt key fields with
      | Some (`String value) -> value
      | _ -> "missing")
  | _ -> "missing"

let expectation ?score ?(passed = true) sentence checker =
  P.{ sentence; checker; passed; score }

let drive ?(status = "done") ?reason ?(url = "https://site-a.example/") () =
  P.
    {
      status = ok (P.Drive_status.of_string status);
      steps = [];
      final = snapshot ~url ();
      reason;
    }

let tab_info () =
  P.
    {
      tab = handle;
      url = "https://site-a.example/";
      title = "A page";
      origin = ok (P.Origin.of_string "agent");
      state = ok (P.State.of_string "owned");
      owner = Some (ok (P.Owner.of_string "alice"));
      generation = 1;
      expires = None;
      reason = None;
    }

(* ---------- The scripted handler ---------- *)

type harness = {
  mutable books : string list;  (** level 1 answers, in order; the last repeats *)
  mutable procs : string list;  (** level 2 answers, in order; the last repeats *)
  mutable verifies : P.run_expectation list list;
  mutable verification_observations : R.observation list;
  mutable drives : P.drive_result list;
  mutable observations : R.observation list;
  mutable plans : R.plan_reply list;
  mutable proposed : (string * string) list;
      (** site and slug of each proposal asked for *)
  mutable values : (string * string) list;  (** what the text helper answers per label *)
  mutable clock : float;
  mutable tick : float;  (** seconds the clock moves on every answered question *)
  mutable asked : string list;
  mutable questions : R.question list;
  mutable steps : R.step_request list;
  mutable fills : Leash.Text_helper.context list;
  mutable navigations : string list;
  mutable handoffs : string list;
  mutable plan_requests : R.plan_request list;
  mutable ops : string list;
      (** every operation performed through the token (run-vj48) *)
  mutable last : R.observation;
}

let harness ?(books = [ "site-a.example" ]) ?(procs = [ "step" ])
    ?(verifies = [ [ expectation "the page is a" "page_kind" ] ]) ?(drives = [ drive () ])
    ?(observations = [ observation () ]) ?(verification_observations = [])
    ?(plans = [ R.{ answer = Fail "no plan"; expect = []; usage = None; pages = [] } ])
    ?(values = [ ("product", "Blue Top") ]) ?(tick = 0.) () =
  let last = match observations with [] -> observation () | first :: _ -> first in
  {
    books;
    procs;
    verifies;
    verification_observations;
    drives;
    observations;
    plans;
    values;
    clock = 0.;
    tick;
    asked = [];
    questions = [];
    steps = [];
    fills = [];
    navigations = [];
    handoffs = [];
    proposed = [];
    plan_requests = [];
    ops = [];
    last;
  }

let pop label get set =
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

let handler (h : harness) : R.handler =
  let tick () = h.clock <- h.clock +. h.tick in
  R.
    {
      observe =
        (fun () ->
          h.ops <- "observe" :: h.ops;
          Ok (next_observation h));
      navigate =
        (fun url ->
          h.ops <- "navigate" :: h.ops;
          h.navigations <- h.navigations @ [ url ];
          Ok ());
      choose =
        (fun (question : R.question) ->
          h.ops <- "choose" :: h.ops;
          h.asked <- h.asked @ [ question.R.name ];
          h.questions <- h.questions @ [ question ];
          tick ();
          match question.R.name with
          | "select_playbook" ->
              Ok
                (choice
                   (pop "playbook answers" (fun () -> h.books) (fun x -> h.books <- x)))
          | "select_procedure" ->
              Ok
                (choice
                   (pop "procedure answers" (fun () -> h.procs) (fun x -> h.procs <- x)))
          | other -> Alcotest.failf "unexpected question %s" other);
      text_value =
        (fun (context : Leash.Text_helper.context) ->
          h.ops <- "fill_args" :: h.ops;
          h.fills <- h.fills @ [ context ];
          Ok
            (List.assoc_opt context.Leash.Text_helper.field.Leash.Text_helper.label
               h.values));
      step =
        (fun request ->
          h.ops <- "execute_step" :: h.ops;
          h.steps <- h.steps @ [ request ];
          tick ();
          Ok (pop "drives" (fun () -> h.drives) (fun x -> h.drives <- x)));
      verify =
        (fun ~pages:_ ~checks ~timeout_s:_ ->
          h.ops <- "verify" :: h.ops;
          ignore checks;
          let observed =
            match h.verification_observations with
            | [] -> h.last
            | next :: rest ->
                h.verification_observations <- rest;
                h.last <- next;
                next
          in
          Ok
            ( pop "verifications" (fun () -> h.verifies) (fun x -> h.verifies <- x),
              observed ));
      plan =
        (fun request ->
          h.ops <- "plan" :: h.ops;
          h.plan_requests <- h.plan_requests @ [ request ];
          Ok (pop "plans" (fun () -> h.plans) (fun x -> h.plans <- x)));
      (* L32 run-m0r8: the scripted run records what it would propose and writes nothing;
         test/planner_test.ml is where the production writer and the operator's merge are
         exercised. *)
      propose =
        (fun ~site proc ->
          h.ops <- "propose" :: h.ops;
          h.proposed <- h.proposed @ [ (site, proc.B.slug) ];
          Ok (Printf.sprintf "/state/proposed/%s-%s.json" site proc.B.slug));
      hand_off =
        (fun ~reason ->
          h.ops <- "hand_off" :: h.ops;
          h.handoffs <- h.handoffs @ [ reason ];
          Ok (tab_info ()));
    }

let args ?(mission = "buy the thing") ?(max_procedures = 40) ?(deadline_s = 900)
    ?(dry_run = false) ?(max_plans = 3) ?(expect = []) () =
  R.{ mission; max_procedures; deadline_s; dry_run; max_plans; expect }

let run ?(installed = []) ?discovery h run_args =
  R.loop ~handler:(handler h) ~now:(fun () -> h.clock) ~installed ?discovery run_args

let status_of (result : P.run_result) = P.Run_status.to_string result.P.status

let check_status label expected (result : P.run_result) =
  Alcotest.(check string) label expected (status_of result)

let site_a =
  book ~site:"site-a.example" ~entry:"https://site-a.example/"
    ~pages:[ page ~url_pattern:"https://site-a.example/*" "a" ]
    [
      procedure ~slug:"step" ~description:"Do the step." ~expect:[ "the page is a" ]
        [ goal "Do it." ];
    ]

let site_b =
  book ~site:"site-b.example" ~entry:"https://site-b.example/"
    ~pages:[ page ~url_pattern:"https://site-b.example/*" "b" ]
    [
      procedure ~slug:"other" ~description:"Do the other step."
        ~expect:[ "the page is b" ]
        [ goal "Do it elsewhere." ];
    ]

(* run-9ypy run-xqh8: one mission, one procedure, verified DONE, and a trace that says
   what was chosen, what it cost and how each expectation was decided. *)
let trace () =
  let h =
    harness ~procs:[ "step"; "DONE" ]
      ~verifies:
        [
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is a" "page_kind" ];
        ]
      ()
  in
  let result = ran (run ~installed:[ site_a ] h (args ())) in
  check_status "run-9ypy done" "done" result;
  Alcotest.(check (option string)) "run-9ypy site" (Some "site-a.example") result.P.site;
  Alcotest.(check int) "run-9ypy one procedure" 1 (List.length result.P.procedures);
  let entry = List.hd result.P.procedures in
  Alcotest.(check string) "run-9ypy slug" "step" entry.P.slug;
  Alcotest.(check string) "run-9ypy outcome" "verified" entry.P.outcome;
  Alcotest.(check int) "run-k8bx one attempt" 1 entry.P.attempts;
  Alcotest.(check bool) "run-xqh8 usage recorded" true (entry.P.choice.P.usage <> None);
  Alcotest.(check string)
    "run-xqh8 checker" "page_kind" (List.hd entry.P.expectations).P.checker;
  Alcotest.(check int) "run-xqh8 one drive" 1 (List.length entry.P.drives);
  Alcotest.(check string) "run-xqh8 drive goal" "Do it." (List.hd entry.P.drives).P.goal;
  Alcotest.(check string)
    "run-9ypy final snapshot" "https://site-a.example/" result.P.final.P.url;
  Alcotest.(check int)
    "run-4j1v mission expectations empty" 0
    (List.length result.P.mission_expectations)

(* run-kli0 run-xh5d run-qq3o run-pvmc: the levels and the state they are asked over. *)
let levels () =
  let h = harness ~procs:[ "step"; "DONE" ] () in
  ignore (ran (run ~installed:[ site_a; site_b ] h (args ())));
  Alcotest.(check (list string))
    "run-kli0 the playbook level is asked once for a single-site mission"
    [ "select_playbook" ]
    (List.filter (fun name -> name = "select_playbook") h.asked);
  let playbook_question = List.hd h.questions in
  Alcotest.(check (list string))
    "run-kli0 the playbooks and none are the criteria"
    [ "site-a.example"; "site-b.example"; "none" ]
    (List.map fst playbook_question.R.criteria);
  let procedure_question = List.nth h.questions 1 in
  Alcotest.(check (list string))
    "run-qq3o the procedures plus DONE and BLOCKED are the criteria"
    [ "step"; "DONE"; "BLOCKED" ]
    (List.map fst procedure_question.R.criteria);
  let state = procedure_question.R.state in
  Alcotest.(check (list string))
    "run-pvmc the state's keys are the small semantic ones"
    [ "mission"; "site"; "page_kind"; "title"; "url"; "recent_procedures"; "arguments" ]
    (match state with `Assoc fields -> List.map fst fields | _ -> []);
  Alcotest.(check bool)
    "run-pvmc no page text reaches the upper level" true
    (not (List.mem_assoc "text" (match state with `Assoc fields -> fields | _ -> [])));
  Alcotest.(check string)
    "run-pvmc the page kind is the playbook's" "a"
    (field_string "page_kind" state)

(* run-kli0 run-xh5d: a mission that says the next part is elsewhere switches playbooks and
   navigates the same tab to the new playbook's entry. *)
let switch () =
  let h =
    harness
      ~books:[ "site-a.example"; "site-b.example" ]
      ~procs:[ "step"; "other"; "DONE" ]
      ~verifies:
        [
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is b" "page_kind" ];
          [ expectation "the page is b" "page_kind" ];
        ]
      ~observations:
        [
          observation ();
          observation ~url:"https://site-b.example/" ~title:"B" ();
          observation ~url:"https://site-b.example/" ~title:"B" ();
        ]
      ()
  in
  let result =
    ran
      (run ~installed:[ site_a; site_b ] h
         (args
            ~mission:
              "do the first thing on site-a.example then the rest on site-b.example"
            ()))
  in
  check_status "run-xh5d done" "done" result;
  Alcotest.(check (list string))
    "run-xh5d the entry navigation of the switch"
    [ "https://site-a.example/"; "https://site-b.example/" ]
    h.navigations;
  Alcotest.(check int)
    "run-kli0 the playbook level was asked at the start and after the cross-site \
     procedure"
    2
    (List.length (List.filter (fun name -> name = "select_playbook") h.asked));
  Alcotest.(check int)
    "run-kli0 the procedure level was asked every turn" 3
    (List.length (List.filter (fun name -> name = "select_procedure") h.asked));
  Alcotest.(check int) "run-kli0 two procedures" 2 (List.length result.P.procedures)

(* run-5rll run-d82w: the arguments come from the mission through the text helper, are
   reused for the run, and every step is one drive call with its own bounds. *)
let arguments () =
  let with_arg =
    book ~site:"site-a.example" ~entry:"https://site-a.example/"
      ~pages:[ page ~url_pattern:"https://site-a.example/*" "a" ]
      [
        procedure ~slug:"find" ~description:"Find the product." ~args:[ "product" ]
          ~max_steps:7 ~deadline_s:60 ~expect:[ "the page is a" ]
          [ goal ~hint:"search" "Search for {product}." ];
        procedure ~slug:"open" ~description:"Open the product." ~args:[ "product" ]
          ~expect:[ "the page is a" ]
          [ goal "Open the offer for {product}." ];
      ]
  in
  let h =
    harness ~procs:[ "find"; "open"; "DONE" ]
      ~verifies:
        [
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is a" "page_kind" ];
        ]
      ()
  in
  let result = ran (run ~installed:[ with_arg ] h (args ~mission:"find Blue Top" ())) in
  check_status "run-5rll done" "done" result;
  Alcotest.(check int)
    "run-5rll one helper call for a reused value" 1 (List.length h.fills);
  let context = List.hd h.fills in
  Alcotest.(check string)
    "run-5rll the field is the argument" "product"
    context.Leash.Text_helper.field.Leash.Text_helper.label;
  Alcotest.(check string)
    "run-5rll the goal is the mission" "find Blue Top" context.Leash.Text_helper.goal;
  let first = List.hd h.steps and second = List.nth h.steps 1 in
  Alcotest.(check string)
    "run-5rll the value is substituted into the goal" "Search for Blue Top. Hint: search"
    first.R.goal;
  Alcotest.(check string)
    "run-5rll and into the next procedure's goal" "Open the offer for Blue Top."
    second.R.goal;
  Alcotest.(check int) "run-d82w the procedure's step cap" 7 first.R.max_steps;
  Alcotest.(check int) "run-d82w the procedure's step deadline" 60 first.R.deadline_s;
  Alcotest.(check int)
    "run-d82w the operator's own default otherwise" 30 second.R.max_steps

(* run-prrv: a use runs the named procedure inline with its own expectations, and an
   optional one is skipped when its first step ends blocked within two operator steps. *)
let composition () =
  let composed =
    book ~site:"site-a.example" ~entry:"https://site-a.example/"
      ~pages:[ page ~url_pattern:"https://site-a.example/*" "a" ]
      [
        procedure ~slug:"main" ~description:"Do the main thing."
          [ goal "Add it."; use ~optional:true "dismiss-upsell" ]
          ~expect:[ "the page is a" ];
        procedure ~slug:"dismiss-upsell" ~description:"Dismiss the upsell if shown."
          [ goal "Dismiss the upsell." ]
          ~expect:[ "no dialog is open" ];
      ]
  in
  let h =
    harness ~procs:[ "main"; "DONE" ]
      ~drives:[ drive (); drive ~status:"blocked" ~reason:"nothing to dismiss" () ]
      ~verifies:
        [
          [ expectation "no dialog is open" "no_dialog" ];
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is a" "page_kind" ];
        ]
      ()
  in
  let result = ran (run ~installed:[ composed ] h (args ())) in
  check_status "run-prrv done" "done" result;
  Alcotest.(check int)
    "run-prrv the called procedure has its own trace entry" 2
    (List.length result.P.procedures);
  let called = List.nth result.P.procedures 0 in
  Alcotest.(check string)
    "run-prrv the optional procedure was skipped" "skipped" called.P.outcome;
  Alcotest.(check string)
    "run-prrv the optional procedure runs its first step under two operator steps" "2"
    (string_of_int (List.nth h.steps 1).R.max_steps);
  let main = List.nth result.P.procedures 1 in
  Alcotest.(check string) "run-prrv the parent verified" "verified" main.P.outcome

(* run-k8bx: a failed verification replays the whole procedure once. *)
let retry () =
  let h =
    harness ~procs:[ "step"; "DONE" ]
      ~drives:[ drive ~status:"blocked" (); drive () ]
      ~verifies:
        [
          [ expectation "the page is a" "page_kind" ~passed:false ];
          [ expectation "the page is a" "page_kind" ];
          [ expectation "the page is a" "page_kind" ];
        ]
      ()
  in
  let result = ran (run ~installed:[ site_a ] h (args ())) in
  check_status "run-k8bx done after the replay" "done" result;
  let entry = List.hd result.P.procedures in
  Alcotest.(check int) "run-k8bx two attempts" 2 entry.P.attempts;
  Alcotest.(check int) "run-k8bx the step ran twice" 2 (List.length h.steps);
  Alcotest.(check int) "run-k8bx both drives in trace" 2 (List.length entry.P.drives)

(* run-xqh8 run-k8bx: the observed L34 live failure retried a failed procedure,
   but the result omitted both attempts and their failed expectation entirely. *)
let failed_retry_trace () =
  let h =
    harness ~procs:[ "step" ]
      ~drives:[ drive (); drive () ]
      ~verifies:
        [
          [ expectation "the page is a" "page_kind" ~passed:false ];
          [ expectation "the page is a" "page_kind" ~passed:false ];
        ]
      ~plans:[ R.{ answer = Fail "nothing left"; expect = []; usage = None; pages = [] } ]
      ()
  in
  let result = ran (run ~installed:[ site_a ] h (args ())) in
  check_status "run-xqh8 failed procedure ends failed" "failed" result;
  Alcotest.(check int)
    "run-xqh8 failed procedure included" 1
    (List.length result.P.procedures);
  let entry = List.hd result.P.procedures in
  Alcotest.(check string) "run-xqh8 failed outcome" "failed" entry.P.outcome;
  Alcotest.(check int) "run-k8bx two failed attempts" 2 entry.P.attempts;
  Alcotest.(check int) "run-xqh8 both failed drives" 2 (List.length entry.P.drives);
  Alcotest.(check bool)
    "run-xqh8 failed expectation" false (List.hd entry.P.expectations).P.passed

(* run-xqh8 run-k8bx, L34: a consent overlay appears after the initial
   Products page observation, covers both attempts, and changes its page kind.
   The loop offers the playbook's dismiss-consent procedure, then the interrupted
   find-product again, without inventing a planner procedure or clicking through. *)
let delayed_consent_recovery () =
  let installed = ok (B.load "../examples/playbooks/automationexercise.com.json") in
  let products =
    observation ~url:"https://automationexercise.com/products" ~text:"ALL PRODUCTS" ()
  in
  let overlay =
    observation ~url:"https://automationexercise.com/products"
      ~text:"ALL PRODUCTS This site asks for consent to use your data" ()
  in
  let search =
    observation ~url:"https://automationexercise.com/products?search=Blue%20Top"
      ~text:"SEARCHED PRODUCTS Blue Top" ()
  in
  let h =
    harness ~books:[ "automationexercise.com" ]
      ~procs:[ "find-product"; "dismiss-consent"; "find-product"; "DONE" ]
      ~observations:[ products; products; products; overlay; products; search ]
      ~verification_observations:[ overlay; overlay; products; search; search ]
      ~drives:
        [
          drive ~status:"error" ~reason:"the row is covered" ();
          drive ~status:"error" ~reason:"the row is covered" ();
          drive ();
          drive ();
        ]
      ~verifies:
        [
          [ expectation "the page is search" "page_kind" ~passed:false ];
          [ expectation "the page is search" "page_kind" ~passed:false ];
          [ expectation "the page is products" "page_kind" ];
          [ expectation "the page is search" "page_kind" ];
          [ expectation "the page is search" "page_kind" ];
        ]
      ()
  in
  let result =
    ran (run ~installed:[ installed ] h (args ~expect:[ "the page is search" ] ()))
  in
  if status_of result <> "done" then
    Alcotest.failf "run-xqh8 status=%s reason=%s asked=%s plans=%d procedures=%s"
      (status_of result)
      (Option.value ~default:"" result.P.reason)
      (String.concat "," h.procs) (List.length h.plan_requests)
      (String.concat ","
         (List.map
            (fun (entry : P.run_procedure) -> entry.P.slug ^ ":" ^ entry.P.outcome)
            result.P.procedures));
  check_status "run-xqh8 recovered consent then resumed" "done" result;
  Alcotest.(check (list string))
    "run-k8bx reselected installed recovery and search"
    [ "find-product"; "dismiss-consent"; "find-product" ]
    (List.map (fun (entry : P.run_procedure) -> entry.P.slug) result.P.procedures);
  Alcotest.(check (list string))
    "run-xqh8 first failure and two verified successors"
    [ "failed"; "verified"; "verified" ]
    (List.map (fun (entry : P.run_procedure) -> entry.P.outcome) result.P.procedures);
  Alcotest.(check int)
    "run-xqh8 page transition needs no planner" 0 (List.length h.plan_requests)

(* run-4j1v, the L30 guard: DONE is not accepted without an independent verification of
   the mission's expectations. The state is the successful Added! modal of L30's
   measurement (run-snk4): the offer URL with the modal's text, whose page kind is the
   playbook's [post-add] because its text marker takes priority over the offer matcher. *)
let added_modal () =
  let playbook = ok (B.load "../examples/playbooks/automationexercise.com.json") in
  let modal =
    observation ~url:"https://automationexercise.com/product_details/1" ~title:"Blue Top"
      ~text:"Added! Your product has been added to cart. View Cart" ()
  in
  let open_h =
    harness ~books:[ "automationexercise.com" ] ~procs:[ "add-to-cart"; "DONE" ]
      ~observations:[ modal ]
      ~verifies:
        [
          [
            expectation "the page is post-add" "page_kind";
            expectation "the page shows Added!" "text";
          ];
          (* The DONE guard asks about the mission's own expectation, and the modal does
             not satisfy it: this is the L30 finding, in the loop. *)
          [ expectation "the page is cart" "page_kind" ~passed:false ];
        ]
      ~plans:
        [
          R.
            {
              answer = Fail "nothing left to plan";
              expect = [];
              usage = None;
              pages = [];
            };
        ]
      ()
  in
  let result =
    ran
      (run ~installed:[ playbook ] open_h
         (args ~mission:"add Blue Top to the cart" ~expect:[ "the page is cart" ] ()))
  in
  let question = List.nth open_h.questions 1 in
  Alcotest.(check string)
    "run-snk4 the modal is the playbook's post-add kind, not the offer URL" "post-add"
    (field_string "page_kind" question.R.state);
  check_status "run-4j1v the Added! modal is not DONE" "blocked" result;
  Alcotest.(check int)
    "run-4j1v the mission expectation was verified" 1
    (List.length result.P.mission_expectations);
  Alcotest.(check bool)
    "run-4j1v and it did not hold" false (List.hd result.P.mission_expectations).P.passed;
  Alcotest.(check bool)
    "run-4j1v the refusal names DONE" true
    (match result.P.reason with Some reason -> String.length reason > 0 | None -> false);
  Alcotest.(check int)
    "run-9ypy a planner turn was taken" 1
    (List.length result.P.planner_turns);
  Alcotest.(check string)
    "run-w7ke the trigger is blocked" "blocked" (List.hd result.P.planner_turns).P.trigger;
  Alcotest.(check string)
    "run-w7ke the planner answered fail" "fail" (List.hd result.P.planner_turns).P.answer;
  (* The same run with the expectation the page satisfies ends done. *)
  let cart =
    observation ~url:"https://automationexercise.com/view_cart" ~title:"Cart"
      ~text:"Blue Top Shopping Cart" ()
  in
  let satisfied =
    harness ~books:[ "automationexercise.com" ] ~procs:[ "add-to-cart"; "DONE" ]
      ~observations:[ modal; cart ]
      ~verifies:
        [
          [
            expectation "the page is post-add" "page_kind";
            expectation "the page shows Added!" "text";
          ];
          [
            expectation "the page is cart" "page_kind";
            expectation "the page shows Blue Top" "text";
          ];
        ]
      ()
  in
  let accepted =
    ran
      (run ~installed:[ playbook ] satisfied
         (args ~mission:"add Blue Top to the cart"
            ~expect:[ "the page is cart"; "the page shows Blue Top" ]
            ()))
  in
  check_status "run-4j1v a verified DONE is done" "done" accepted;
  Alcotest.(check int)
    "run-4j1v the mission expectations are in the result" 2
    (List.length accepted.P.mission_expectations)

(* run-4mzm: the recorded JEV answers of the L30 measurement, replayed as a script. *)
let recorded () =
  let playbook = ok (B.load "../examples/playbooks/automationexercise.com.json") in
  let home =
    observation ~url:"https://automationexercise.com/" ~title:"Home" ~text:"Products" ()
  in
  let search =
    observation ~url:"https://automationexercise.com/products?search=Blue%20Top"
      ~title:"Products" ~text:"SEARCHED PRODUCTS Blue Top" ()
  in
  let offer =
    observation ~url:"https://automationexercise.com/product_details/1" ~title:"Blue Top"
      ~text:"Blue Top Add to cart" ()
  in
  let modal =
    observation ~url:"https://automationexercise.com/product_details/1" ~title:"Blue Top"
      ~text:"Added! Your product has been added to cart. View Cart" ()
  in
  let h =
    harness ~books:[ "automationexercise.com" ]
      ~procs:[ "find-product"; "open-offer"; "add-to-cart"; "DONE" ]
      ~observations:[ home; search; offer; modal ]
      ~verifies:
        [
          [
            expectation "the page is search" "page_kind";
            expectation "the page shows Blue Top" "text";
          ];
          [ expectation "the page is offer" "page_kind" ];
          [
            expectation "the page is post-add" "page_kind";
            expectation "the page shows Added!" "text";
          ];
          (* L30's own label for this state: the correct next procedure is go-to-cart, and
             DONE here is refused by the mission's expectation. *)
          [ expectation "the page is cart" "page_kind" ~passed:false ];
        ]
      ~plans:
        [
          R.
            {
              answer = Fail "nothing left to plan";
              expect = [];
              usage = None;
              pages = [];
            };
        ]
      ()
  in
  let result =
    ran
      (run ~installed:[ playbook ] h
         (args ~mission:"add Blue Top to the cart" ~expect:[ "the page is cart" ] ()))
  in
  check_status "run-snk4 the recorded answers end blocked on the modal" "blocked" result;
  Alcotest.(check (list string))
    "run-snk4 the recorded procedure answers were followed"
    [ "find-product"; "open-offer"; "add-to-cart" ]
    (List.map (fun (entry : P.run_procedure) -> entry.P.slug) result.P.procedures)

(* run-vspj: the procedure cap and the run deadline bound a wandering run. *)
let limits () =
  let h =
    harness ~procs:[ "step"; "step" ]
      ~drives:[ drive () ]
      ~verifies:[ [ expectation "the page is a" "page_kind" ] ]
      ()
  in
  let capped = ran (run ~installed:[ site_a ] h (args ~max_procedures:2 ())) in
  check_status "run-vspj the procedure cap" "limit" capped;
  Alcotest.(check int)
    "run-vspj capped after two procedures" 2
    (List.length capped.P.procedures);
  let ticking =
    harness ~procs:[ "step" ]
      ~drives:[ drive () ]
      ~tick:400.
      ~verifies:[ [ expectation "the page is a" "page_kind" ] ]
      ()
  in
  let late = ran (run ~installed:[ site_a ] ticking (args ~deadline_s:900 ())) in
  check_status "run-vspj the deadline" "deadline" late

(* run-fp7i run-9ypy: a dry run asks the two levels, reports the chosen playbook and
   procedure with its resolved checkers, and never acts. *)
let dry () =
  let h =
    harness ~procs:[ "step" ] ~verifies:[ [ expectation "the page is a" "page_kind" ] ] ()
  in
  let result = ran (run ~installed:[ site_a ] h (args ~dry_run:true ())) in
  check_status "run-fp7i a dry run executes nothing" "blocked" result;
  Alcotest.(check (list string))
    "run-fp7i the two levels were asked"
    [ "select_playbook"; "select_procedure" ]
    h.asked;
  Alcotest.(check int) "run-fp7i no step ran" 0 (List.length h.steps);
  Alcotest.(check int) "run-fp7i no argument was filled" 0 (List.length h.fills);
  Alcotest.(check (option string))
    "run-fp7i the chosen playbook" (Some "site-a.example") result.P.site;
  let entry = List.hd result.P.procedures in
  Alcotest.(check string) "run-fp7i the chosen procedure" "step" entry.P.slug;
  Alcotest.(check string) "run-fp7i the outcome is planned" "planned" entry.P.outcome;
  Alcotest.(check int) "run-fp7i nothing was executed" 0 (List.length entry.P.drives);
  Alcotest.(check string)
    "run-fp7i the resolved checker is reported" "page_kind"
    (List.hd entry.P.expectations).P.checker

(* run-klp9: a dialog ends the run with the page state that has it, and a planner handoff
   leaves the ending to the human. *)
let endings () =
  let dialog =
    P.{ P.kind = ok (P.Dialog_kind.of_string "confirm"); message = "Leave?" }
  in
  let h = harness ~observations:[ observation ~dialog () ] () in
  let blocked = ran (run ~installed:[ site_a ] h (args ())) in
  check_status "run-klp9 a dialog ends the run" "error" blocked;
  Alcotest.(check bool)
    "run-klp9 the dialog is in the final snapshot" true
    (blocked.P.final.P.dialog <> None);
  let handoff =
    harness ~procs:[ "BLOCKED" ]
      ~plans:
        [
          R.
            {
              answer = Handoff "the captcha needs you";
              expect = [];
              usage = None;
              pages = [];
            };
        ]
      ()
  in
  let ended = ran (run ~installed:[ site_a ] handoff (args ())) in
  check_status "run-klp9 a planner handoff ends the run" "handoff" ended;
  Alcotest.(check (list string))
    "run-klp9 the handoff reason reached the registry" [ "the captcha needs you" ]
    handoff.handoffs

(* run-vj48 run-7blx: the six judgments of the loop go through one handler token — one
   handler, one place where a model or a level is swapped — and the run performs all six. *)
let operations () =
  let with_arg =
    book ~site:"site-a.example" ~entry:"https://site-a.example/"
      ~pages:[ page ~url_pattern:"https://site-a.example/*" "a" ]
      [
        procedure ~slug:"step" ~description:"Do the step." ~args:[ "product" ]
          ~expect:[ "the page is a" ]
          [ goal "Do it with {product}." ];
      ]
  in
  let failing =
    harness ~procs:[ "step" ]
      ~drives:[ drive ~status:"error" ~reason:"the action failed" () ]
      ~verifies:[ [ expectation "the page is a" "page_kind" ~passed:false ] ]
      ~plans:[ R.{ answer = Fail "nothing left"; expect = []; usage = None; pages = [] } ]
      ()
  in
  let result = ran (run ~installed:[ with_arg ] failing (args ())) in
  check_status "run-vj48 a twice-failed procedure ends failed" "failed" result;
  List.iter
    (fun name ->
      Alcotest.(check bool)
        ("run-vj48 the run performed " ^ name)
        true (List.mem name failing.ops))
    [ "observe"; "choose"; "verify"; "execute_step"; "fill_args"; "plan" ];
  Alcotest.(check (list string))
    "run-7blx one handler served every level"
    [ "select_playbook"; "select_procedure" ]
    failing.asked

(* run-klp9 run-9ypy: a missing playbook never reaches a model. *)
let no_playbook () =
  let h = harness () in
  let result = ran (run h (args ())) in
  check_status "run-9ypy no playbook installed" "blocked" result;
  Alcotest.(check (list string)) "run-9ypy nothing was asked" [] h.asked

(* L33 run-3vat run-xda7: the first discovery turn is planner-led and a verified
   draft is reported without installing it. The next turn sees learned page kinds. *)
let discovery_plans_first () =
  let draft =
    procedure ~slug:"browse" ~description:"Browse catalog" ~expect:[ "catalog visible" ]
      [ goal "Open catalog" ]
  in
  let h =
    harness ~procs:[ "browse" ]
      ~verifies:[ [ expectation "catalog visible" "page_kind" ] ]
      ~plans:
        [
          R.
            {
              answer = Procedure draft;
              expect = [];
              usage = None;
              pages = [ page ~url_pattern:"https://site-a.example/*" "catalog" ];
            };
          R.{ answer = Fail "explored"; expect = []; usage = None; pages = [] };
        ]
      ()
  in
  let seed = book ~site:"site-a.example" ~entry:"https://site-a.example/" [] in
  let discovery = R.{ book = seed; max_steps = 5; max_cost = 1. } in
  let result = ran (run ~discovery h (args ~max_plans:2 ())) in
  check_status "planner finished exploration" "blocked" result;
  Alcotest.(check (list string))
    "planner precedes procedure selection" [ "plan"; "choose" ]
    ( List.filter (fun op -> op = "choose" || op = "plan") (List.rev h.ops) |> fun ops ->
      List.filteri (fun i _ -> i < 2) ops );
  Alcotest.(check (list (pair string string)))
    "verified proposal"
    [ ("site-a.example", "browse") ]
    h.proposed;
  Alcotest.(check int) "two planner turns" 2 (List.length h.plan_requests);
  let next = List.nth h.plan_requests 1 in
  Alcotest.(check bool)
    "learned page kind is reused" true
    (match next.R.playbook with
    | Some book -> List.exists (fun (p : B.page) -> p.name = "catalog") book.pages
    | None -> false)

(* L33 run-tt9z run-tpnf: protected action intent stops before the fake browser
   receives a goal, even when the mission asks for exactly that action. *)
let discovery_hard_stops () =
  List.iter
    (fun (label, goal_text) ->
      let draft =
        procedure ~slug:"danger" ~description:goal_text ~expect:[ "page visible" ]
          [ goal goal_text ]
      in
      let h =
        harness ~procs:[ "danger" ]
          ~plans:[ R.{ answer = Procedure draft; expect = []; usage = None; pages = [] } ]
          ()
      in
      let seed = book ~site:"site-a.example" ~entry:"https://site-a.example/" [] in
      let result =
        ran
          (run
             ~discovery:R.{ book = seed; max_steps = 3; max_cost = 1. }
             h (args ~mission:goal_text ()))
      in
      check_status label "blocked" result;
      Alcotest.(check int) (label ^ " no browser action") 0 (List.length h.steps))
    [
      ("payment", "Pay now"); ("deletion", "Delete account"); ("messaging", "Send message");
    ]

let discovery_cost () =
  let draft =
    procedure ~slug:"browse" ~description:"Browse" ~expect:[ "page visible" ]
      [ goal "Browse" ]
  in
  let h =
    harness
      ~plans:
        [
          R.
            {
              answer = Procedure draft;
              expect = [];
              usage = Some P.{ input_tokens = 10; output_tokens = 10; cost = 2. };
              pages = [];
            };
        ]
      ()
  in
  let seed = book ~site:"site-a.example" ~entry:"https://site-a.example/" [] in
  let result =
    ran (run ~discovery:R.{ book = seed; max_steps = 3; max_cost = 1. } h (args ()))
  in
  check_status "reported cost cap" "limit" result;
  Alcotest.(check int) "no browser steps" 0 (List.length h.steps)

let () =
  Alcotest.run "L31 run"
    [
      ( "L31",
        [
          Alcotest.test_case "run-9ypy run-xqh8 trace" `Quick trace;
          Alcotest.test_case "run-kli0 run-qq3o run-pvmc levels" `Quick levels;
          Alcotest.test_case "run-xh5d run-kli0 switch" `Quick switch;
          Alcotest.test_case "run-5rll run-d82w arguments" `Quick arguments;
          Alcotest.test_case "run-prrv composition" `Quick composition;
          Alcotest.test_case "run-k8bx retry once" `Quick retry;
          Alcotest.test_case "run-xqh8 failed retry trace" `Quick failed_retry_trace;
          Alcotest.test_case "run-xqh8 late consent recovery" `Quick
            delayed_consent_recovery;
          Alcotest.test_case "run-4j1v run-snk4 Added! modal" `Quick added_modal;
          Alcotest.test_case "run-4mzm recorded answers" `Quick recorded;
          Alcotest.test_case "run-vspj caps and deadline" `Quick limits;
          Alcotest.test_case "run-fp7i dry run" `Quick dry;
          Alcotest.test_case "run-klp9 endings" `Quick endings;
          Alcotest.test_case "run-vj48 run-7blx operations" `Quick operations;
          Alcotest.test_case "run-9ypy no playbook" `Quick no_playbook;
          Alcotest.test_case "run-3vat run-xda7 discovery planner" `Quick
            discovery_plans_first;
          Alcotest.test_case "run-tt9z run-tpnf discovery stops" `Quick
            discovery_hard_stops;
          Alcotest.test_case "run-tpnf cost" `Quick discovery_cost;
        ] );
    ]
