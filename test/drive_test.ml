(* drive-y7v8 drive-xjh6 drive-4zlp drive-ix5t drive-l7yk drive-4bhg
   drive-8n2z: scripted handler and mock clock, no browser or model server. *)
module P = Leash.Protocol
module J = Leash__Jev_request
module D = Leash__Drive

let check label expected actual = Alcotest.(check string) label expected actual
let handle = match P.Handle.of_string "t_test" with Ok x -> x | Error _ -> assert false
let id = match P.Snapshot_id.of_string "s_test" with Ok x -> x | Error _ -> assert false
let op s = match P.Operation.of_string s with Ok x -> x | Error _ -> assert false
let status (r : P.drive_result) = P.Drive_status.to_string r.status

let contains haystack needle =
  let n = String.length needle in
  let rec scan at =
    at + n <= String.length haystack
    && (String.sub haystack at n = needle || scan (at + 1))
  in
  n > 0 && scan 0

let snapshot ?(title = "Initial") () =
  P.
    {
      snapshot = id;
      tab = handle;
      url = "https://example.org";
      title;
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

let row ?(value = "") index name =
  P.{ index; role = "textbox"; name; value = Some value; state = None; options = None }

let observation ?(rows = []) title =
  D.
    {
      snapshot = { (snapshot ~title ()) with P.rows; total = List.length rows };
      text = title;
      can_scroll_down = false;
      can_scroll_up = false;
      fingerprint = title;
    }

let decision ?index name : J.decision =
  {
    operation = op name;
    script = None;
    index;
    option = None;
    confidence = 1.;
    target_confidence = None;
    operation_probabilities = [ (name, 1.) ];
    target_probabilities = [];
    targets = [];
  }

let args ?(max_steps = 30) ?(deadline_s = 120) () =
  P.
    {
      tab = handle;
      goal = "check page";
      max_steps = Some max_steps;
      deadline_s = Some deadline_s;
      dry_run = None;
    }

let run ?(clock_step = 0.) ?(max_steps = 30) ?(deadline_s = 120) ?(dry_run = false)
    ?(change = false) ?reached choices =
  let time = ref 0. and calls = ref 0 and actions = ref 0 and state = ref "Initial" in
  let queue = ref choices in
  let decide _ =
    incr calls;
    match !queue with
    | next :: rest ->
        queue := rest;
        Ok (decision next)
    | [] -> Alcotest.fail "decision script exhausted"
  in
  let observe () = Ok (observation !state) in
  let text_value _ = Ok None in
  let act _ _ ~text:_ =
    incr actions;
    time := !time +. clock_step;
    if change then state := "Changed" ^ string_of_int !actions;
    Ok
      P.
        {
          tab = handle;
          url = "https://example.org";
          title = !state;
          snapshot = None;
          dialog = None;
          popups = [];
          via = None;
        }
  in
  let reply =
    D.run ?reached
      ~handler:D.{ observe; decide; text_value; act }
      ~now:(fun () -> !time)
      ~model:"test-model"
      ~args:(args ~max_steps ~deadline_s ())
      ~dry_run ()
  in
  match reply with
  | Ok r -> (r, !actions, !calls)
  | Error e -> Alcotest.failf "%s: %s" (P.Error_code.to_string e.code) e.message

let done_path () =
  let r, acts, _ = run ~change:true [ "wait"; "done" ] in
  check "drive-y7v8 done" "done" (status r);
  Alcotest.(check int) "drive-xjh6 steps" 2 (List.length r.steps);
  Alcotest.(check int) "drive-4zlp action" 1 acts;
  check "final" "Changed1" r.final.title

(* pbk-eyya: a goal step's until ends the drive done after the action that reached it,
   without asking JEV to judge the page it landed on; it is never asked before an action. *)
let until_reached () =
  let asked = ref [] in
  let reached ~(start : D.observation) (page : D.observation) =
    asked := (start.snapshot.title, page.snapshot.title) :: !asked;
    page.snapshot.title = "Changed1"
  in
  let r, acts, calls = run ~change:true ~reached [ "click"; "blocked" ] in
  check "pbk-eyya until ends the step done" "done" (status r);
  Alcotest.(check int) "pbk-eyya one action" 1 acts;
  Alcotest.(check int) "pbk-eyya no prediction after the action" 1 calls;
  Alcotest.(check (list (pair string string)))
    "pbk-eyya until sees the step's start and the page the action produced"
    [ ("Initial", "Changed1") ]
    !asked;
  check "pbk-eyya reason" "the step's until checks hold"
    (Option.value ~default:"" r.reason);
  let r, acts, _ =
    run ~change:true ~reached:(fun ~start:_ _ -> false) [ "click"; "done" ]
  in
  check "pbk-eyya until unmet leaves JEV to decide" "done" (status r);
  Alcotest.(check int) "pbk-eyya unmet until" 1 acts

let blocked_reasons () =
  List.iter
    (fun (choices, dry_run, fragment) ->
      let result, _, _ = run ~dry_run choices in
      check "daily-9ggi blocked status" "blocked" (status result);
      Alcotest.(check bool)
        "daily-9ggi blocked reason identifies cause" true
        (contains (Option.value ~default:"" result.P.reason) fragment))
    [
      ([ "blocked" ], false, "no available action");
      ([ "click"; "click"; "click" ], false, "without changing");
      ([ "click" ], true, "dry run");
    ]

let stall () =
  let r, acts, _ = run [ "click"; "click"; "click"; "done" ] in
  check "drive-4bhg stall" "blocked" (status r);
  Alcotest.(check int) "three actions" 3 acts

let cap () =
  let r, acts, _ = run ~max_steps:2 [ "click"; "click"; "done" ] in
  check "fly-vzzw DONE after last action" "done" (status r);
  Alcotest.(check int) "two actions" 2 acts

let deadline () =
  let r, acts, _ = run ~clock_step:2. ~deadline_s:1 [ "click"; "done" ] in
  check "drive-ix5t deadline" "deadline" (status r);
  Alcotest.(check int) "one action" 1 acts

let dry_run () =
  let r, acts, calls = run ~dry_run:true [ "click"; "done" ] in
  check "drive-l7yk dry status" "blocked" (status r);
  Alcotest.(check int) "one decision" 1 calls;
  Alcotest.(check int) "zero actions" 0 acts;
  Alcotest.(check int) "one trace" 1 (List.length r.steps)

(* drive-ls3c: one scripted drive over the text helper. [operations] are the decisions
   JEV answers in order, [answers] what the helper answers; every text an act writes and
   every context the helper is asked from are kept, and [refuse] fails the nth act with
   the action layer's [stale-snapshot]. *)
let with_text ?(rows = []) ?(refuse = fun _ -> false) operations answers =
  let actions = ref 0 and typed = ref [] and contexts = ref [] in
  let queue = ref operations and answers = ref answers in
  let observe () = Ok (observation ~rows "Search page") in
  let decide _ =
    match !queue with
    | next :: rest ->
        queue := rest;
        Ok (decision ?index:(snd next) (fst next))
    | [] -> Alcotest.fail "decision script exhausted"
  in
  let text_value (context : Leash.Text_helper.context) =
    contexts := context :: !contexts;
    match !answers with
    | answer :: rest ->
        answers := rest;
        answer
    | [] -> Alcotest.fail "text helper script exhausted"
  in
  let act _ _ ~text =
    incr actions;
    if refuse !actions then
      Error
        (P.make_error
           (match P.Error_code.of_string "stale-snapshot" with
           | Ok code -> code
           | Error _ -> assert false)
           ~message:"the row changed since the snapshot; snap again")
    else begin
      typed := text :: !typed;
      Ok
        P.
          {
            tab = handle;
            url = "https://example.org";
            title = "Search page";
            snapshot = None;
            dialog = None;
            popups = [];
            via = None;
          }
    end
  in
  let reply =
    D.run
      ~handler:D.{ observe; decide; text_value; act }
      ~now:(fun () -> 0.)
      ~model:"test-model" ~args:(args ()) ~dry_run:false ()
  in
  (reply, List.rev !typed, List.rev !contexts, !actions)

(* drive-ls3c drive-fh1h: the helper's value is what the act writes, the trace records it,
   and the context is jev's field_context: the goal, the chosen element's field, the page
   and the drive's history. *)
let type_text_fills () =
  let reply, typed, contexts, _ =
    with_text
      ~rows:[ row 1 "Search" ]
      [ ("type_text", Some 1); ("done", None) ]
      [ Ok (Some "Gödel, Escher, Bach") ]
  in
  match reply with
  | Error error -> Alcotest.failf "drive-ls3c %s" error.message
  | Ok r -> (
      check "drive-ls3c done" "done" (status r);
      Alcotest.(check (list (option string)))
        "drive-ls3c the value is typed"
        [ Some "Gödel, Escher, Bach" ]
        typed;
      Alcotest.(check int) "drive-ls3c two trace steps" 2 (List.length r.steps);
      let step = List.hd r.steps in
      check "drive-ls3c the step operation" "type_text"
        (P.Operation.to_string step.operation);
      Alcotest.(check (option int)) "drive-ls3c the step row" (Some 1) step.index;
      Alcotest.(check (option string))
        "drive-xjh6 the step text" (Some "Gödel, Escher, Bach") step.text;
      match contexts with
      | [ context ] ->
          let open Leash.Text_helper in
          check "drive-fh1h the goal verbatim" "check page" context.goal;
          check "drive-fh1h the field label" "Search" context.field.label;
          check "drive-fh1h the field role" "textbox" context.field.role;
          check "drive-fh1h the field value" "" context.field.value;
          check "drive-fh1h the page title" "Search page" context.page_title;
          check "drive-fh1h the page text" "Search page" context.page_text;
          Alcotest.(check int) "drive-fh1h no history yet" 0 (List.length context.recent)
      | contexts ->
          Alcotest.(check int) "drive-ls3c one helper call" 1 (List.length contexts))

(* drive-ls3c: the model's null — the value is missing — ends the drive blocked with the
   field named, and nothing is typed. *)
let type_text_missing () =
  let reply, typed, _, actions =
    with_text ~rows:[ row 1 "Search" ] [ ("type_text", Some 1) ] [ Ok None ]
  in
  match reply with
  | Error error -> Alcotest.failf "drive-ls3c %s" error.message
  | Ok r ->
      check "drive-ls3c blocked" "blocked" (status r);
      Alcotest.(check (option string))
        "drive-ls3c the field is named"
        (Some (Printf.sprintf "no value for field %S" "Search"))
        r.reason;
      Alcotest.(check int) "drive-ls3c nothing is typed" 0 actions;
      Alcotest.(check (list (option string))) "drive-ls3c no fill" [] typed;
      Alcotest.(check int)
        "drive-ls3c the decision is in the trace" 1 (List.length r.steps);
      check "drive-ls3c the blocked step" "type_text"
        (P.Operation.to_string (List.hd r.steps).operation)

(* drive-kh2u drive-ls3c: a helper failure is a model failure: the protocol error carries
   the completed steps, like a System One failure does. *)
let text_error () =
  let failure =
    P.make_error
      ~detail:(`Assoc [ ("code", `String "unavailable") ])
      (match P.Error_code.of_string "model-unavailable" with
      | Ok code -> code
      | Error _ -> assert false)
      ~message:"chat offline"
  in
  let reply, _, _, _ =
    with_text
      ~rows:[ row 1 "Search" ]
      [ ("scroll_down", None); ("type_text", Some 1) ]
      [ Error failure ]
  in
  match reply with
  | Error error -> Alcotest.failf "fly-8fgl expected partial result: %s" error.message
  | Ok result ->
      check "fly-8fgl helper provider error" "error" (status result);
      Alcotest.(check int) "fly-4mio completed step retained" 1 (List.length result.steps);
      Alcotest.(check bool)
        "fly-9e0f partial state retained" true
        (Option.is_some result.operator_state)

(* drive-ls3c: a refused (stale) act asks the helper again, and the loop hands it the same
   context — the helper is what reuses the answer, not the loop. *)
let type_text_stale () =
  let reply, typed, contexts, actions =
    with_text
      ~rows:[ row 1 "Search" ]
      [ ("type_text", Some 1); ("type_text", Some 1); ("done", None) ]
      [ Ok (Some "alice"); Ok (Some "alice") ]
      ~refuse:(fun actions -> actions = 1)
  in
  match reply with
  | Error error -> Alcotest.failf "drive-ls3c %s" error.message
  | Ok r ->
      check "drive-ls3c done after the retry" "done" (status r);
      Alcotest.(check int) "drive-ls3c two acts attempted" 2 actions;
      Alcotest.(check (list (option string)))
        "drive-ls3c the value is typed once" [ Some "alice" ] typed;
      Alcotest.(check int)
        "fly-gysl unchanged stale context is memoized" 1 (List.length contexts);
      (match contexts with
      | [ context ] ->
          check "fly-gysl memo uses original mission" (args ()).goal context.goal
      | _ -> Alcotest.fail "fly-gysl expected exactly one helper context");
      Alcotest.(check int)
        "drive-9y2s the stale decision is not a trace step" 2 (List.length r.steps)

let model_error ?(code = "model-unavailable") () =
  let count = ref 0 and actions = ref 0 in
  let error =
    P.make_error
      ~detail:(`Assoc [ ("code", `String "offline"); ("model_kind", `String "jev") ])
      (match P.Error_code.of_string code with Ok x -> x | Error _ -> assert false)
      ~message:"model offline"
  in
  let handler =
    D.
      {
        observe = (fun () -> Ok (observation "Initial"));
        decide =
          (fun _ ->
            incr count;
            if !count = 1 then Ok (decision "wait") else Error error);
        text_value = (fun _ -> Alcotest.fail "no text step in this script");
        act =
          (fun _ _ ~text:_ ->
            incr actions;
            Ok
              P.
                {
                  tab = handle;
                  url = "https://example.org";
                  title = "Initial";
                  snapshot = None;
                  dialog = None;
                  popups = [];
                  via = None;
                });
      }
  in
  match
    D.run ~handler
      ~now:(fun () -> 0.)
      ~model:"test-model" ~args:(args ()) ~dry_run:false ()
  with
  | Error error -> Alcotest.failf "fly-8fgl expected terminal evidence: %s" error.message
  | Ok result ->
      check "fly-8fgl provider failure is distinct" "error" (status result);
      Alcotest.(check int)
        "fly-4mio one completed step retained" 1 (List.length result.steps);
      Alcotest.(check bool)
        "fly-9e0f terminal state" true
        (Option.is_some result.operator_state);
      Alcotest.(check int) "fly-4mio one action" 1 !actions

let step_failure () =
  let internal =
    P.make_error
      (match P.Error_code.of_string "internal" with Ok x -> x | Error _ -> assert false)
      ~message:"browser unavailable"
  in
  List.iter
    (fun (label, act_fails) ->
      let observations = ref 0 in
      let handler =
        D.
          {
            observe =
              (fun () ->
                incr observations;
                if !observations > 1 && not act_fails then Error internal
                else Ok (observation "Initial"));
            decide = (fun _ -> Ok (decision "click"));
            text_value = (fun _ -> Alcotest.fail "no text step in this script");
            act =
              (fun _ _ ~text:_ ->
                if act_fails then Error internal
                else
                  Ok
                    P.
                      {
                        tab = handle;
                        url = "https://example.org";
                        title = "Initial";
                        snapshot = None;
                        dialog = None;
                        popups = [];
                        via = None;
                      });
          }
      in
      match
        D.run ~handler
          ~now:(fun () -> 0.)
          ~model:"test-model" ~args:(args ()) ~dry_run:false ()
      with
      | Error _ -> Alcotest.fail (label ^ " must return a drive status")
      | Ok r ->
          check (label ^ " status") "error" (status r);
          Alcotest.(check int) (label ^ " trace") 1 (List.length r.steps);
          let reason =
            match r.reason with
            | Some reason -> reason
            | None -> Alcotest.fail (label ^ " names no cause")
          in
          Alcotest.(check bool)
            (label ^ " reason names the phase")
            true
            (contains reason
               (if act_fails then
                  "the click action (outcome uncertain; not replayed) failed"
                else "observe after executed action; not replayed failed"));
          Alcotest.(check bool)
            (label ^ " reason names the code")
            true (contains reason "internal"))
    [ ("act", true); ("post-action observe", false) ]

(* drive-n3ld drive-y7v8: a dialog or popup mid-loop ends the drive with error and
   names the cause — the dialog kind, the popup count. *)
let dialog_popup_error () =
  let alert =
    P.
      {
        kind =
          (match Dialog_kind.of_string "alert" with Ok x -> x | Error _ -> assert false);
        message = "are you sure";
        default_prompt = None;
      }
  in
  let popup =
    P.
      {
        tab = Some handle;
        url = "https://example.org/popup";
        title = "Popup";
        page_kind = None;
        origin =
          (match Origin.of_string "agent" with Ok x -> x | Error _ -> assert false);
        label = None;
        age_s = 0;
        idle_s = 0;
        closes_in_s = Some 1800;
        with_human = false;
        state =
          (match Popup_state.of_string "ready" with Ok x -> x | Error _ -> assert false);
        generation = 1;
        dialog = None;
        reason = None;
        opener_url = "https://example.org/";
      }
  in
  List.iter
    (fun (label, dialog, popups, expected) ->
      let handler =
        D.
          {
            observe = (fun () -> Ok (observation "Initial"));
            decide = (fun _ -> Ok (decision "click"));
            text_value = (fun _ -> Alcotest.fail "no text step in this script");
            act =
              (fun _ _ ~text:_ ->
                Ok
                  P.
                    {
                      tab = handle;
                      url = "https://example.org";
                      title = "Initial";
                      snapshot = None;
                      dialog;
                      popups;
                      via = None;
                    });
          }
      in
      match
        D.run ~handler
          ~now:(fun () -> 0.)
          ~model:"test-model" ~args:(args ()) ~dry_run:false ()
      with
      | Error e -> Alcotest.failf "%s: %s" label (P.Error_code.to_string e.code)
      | Ok r ->
          check (label ^ " status") "error" (status r);
          Alcotest.(check (option string)) (label ^ " reason") (Some expected) r.reason)
    [
      ("dialog", Some alert, [], "dialog open: alert");
      ("popup", None, [ popup ], "1 popup opened");
    ]

(* L45 deterministic operator regressions. These use no model or browser service. *)
let json_member key = function
  | `Assoc fields -> List.assoc key fields
  | _ -> Alcotest.fail key

let state (result : P.drive_result) =
  match result.operator_state with
  | Some state -> state
  | None -> Alcotest.fail "fly-9e0f missing state"

let metric result key =
  match json_member key (json_member "metrics" (state result)) with
  | `Int value -> value
  | _ -> Alcotest.fail key

let fly_run ?label ?(validate = fun _ -> Ok ()) ?(coverage = fun _ -> `Assoc [])
    ?(usage = fun _ -> None) ?(dry_run = false) ?(max_steps = None)
    ?(observe = fun () -> Ok (observation "Initial"))
    ?(text_value = fun _ -> Alcotest.fail "unexpected helper") ~decide ~act () =
  let handler = D.{ observe; decide; text_value; act } in
  match
    D.run ?label ~validate ~coverage ~usage ~handler
      ~now:(fun () -> 0.)
      ~model:"test"
      ~args:{ (args ()) with P.max_steps }
      ~dry_run ()
  with
  | Ok result -> result
  | Error error -> Alcotest.fail error.message

let performed () =
  P.
    {
      tab = handle;
      url = "https://example.org";
      title = "Initial";
      snapshot = None;
      dialog = None;
      popups = [];
      via = None;
    }

let stale_error =
  P.make_error
    (match P.Error_code.of_string "stale-snapshot" with
    | Ok code -> code
    | Error _ -> assert false)
    ~message:"changed"

let fly_budgets () =
  let calls = ref 0 in
  let result =
    fly_run
      ~decide:(fun _ ->
        incr calls;
        Ok (decision (if !calls <= 60 then "wait" else "done")))
      ~act:(fun _ _ ~text:_ -> Ok (performed ()))
      ()
  in
  check "fly-hc3l default actions" "done" (status result);
  Alcotest.(check int) "fly-hc3l sixty actual actions" 60 (metric result "actions");
  Alcotest.(check int) "fly-vzzw one terminal after cap" 61 (metric result "predictions");
  let result =
    fly_run
      ~decide:(fun _ -> Ok (decision "click"))
      ~act:(fun _ _ ~text:_ -> Error stale_error)
      ()
  in
  check "fly-fl7u stale predictions terminate" "step-cap" (status result);
  Alcotest.(check int) "fly-fl7u default predictions" 120 (metric result "predictions");
  Alcotest.(check int) "fly-hc3l stale is never executed" 0 (metric result "actions")

let fly_helper_guard () =
  let checks = ref 0 and helpers = ref 0 and calls = ref 0 in
  let result =
    fly_run
      ~observe:(fun () -> Ok (observation ~rows:[ row 1 "Search" ] "Initial"))
      ~validate:(fun _ ->
        incr checks;
        if !checks = 1 then Error stale_error else Ok ())
      ~text_value:(fun _ ->
        incr helpers;
        Ok (Some "alice"))
      ~decide:(fun _ ->
        incr calls;
        Ok
          (decision
             ?index:(if !calls <= 2 then Some 1 else None)
             (if !calls <= 2 then "type_text" else "done")))
      ~act:(fun _ _ ~text:_ -> Ok (performed ()))
      ()
  in
  check "fly-gysl fresh helper" "done" (status result);
  Alcotest.(check int) "fly-gysl no helper for stale decision" 1 !helpers;
  Alcotest.(check int)
    "fly-qr70 only TYPE_TEXT calls helper" 1 (metric result "text_calls");
  let result =
    fly_run ~dry_run:true
      ~observe:(fun () -> Ok (observation ~rows:[ row 1 "Search" ] "Initial"))
      ~decide:(fun _ -> Ok (decision ~index:1 "type_text"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "fly-9363 dry run dispatched")
      ()
  in
  Alcotest.(check int)
    "fly-9363 dry run never calls helper" 0 (metric result "text_calls")

let fly_terminal_refresh () =
  let observations = ref 0 and calls = ref 0 in
  let result =
    fly_run
      ~observe:(fun () ->
        incr observations;
        Ok (observation (if !observations = 1 then "Initial" else "Changed")))
      ~decide:(fun _ ->
        incr calls;
        Ok (decision "done"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "terminal input")
      ()
  in
  Alcotest.(check int) "fly-vzzw stale terminal opinion re-decided" 2 !calls;
  check "fly-vzzw final fresh evidence" "Changed" result.final.title;
  Alcotest.(check int)
    "fly-8fgl stale terminal is not an action" 0 (metric result "actions")

let fly_observation_bound () =
  let calls = ref 0 in
  let result =
    fly_run
      ~observe:(fun () ->
        incr calls;
        if !calls > 1 then Error stale_error else Ok (observation "Initial"))
      ~decide:(fun _ -> Ok (decision "click"))
      ~act:(fun _ _ ~text:_ -> Ok (performed ()))
      ()
  in
  Alcotest.(check int) "fly-4lmg ten attempts per acquisition" 11 !calls;
  Alcotest.(check int)
    "fly-4mio executed action survives observation failure" 1 (metric result "actions");
  Alcotest.(check int) "fly-2pn7 action not duplicated" 1 (List.length result.steps);
  check "fly-9e0f last valid page retained" "Initial" result.final.title

let fly_structured_state () =
  let result =
    fly_run
      ~coverage:(fun _ ->
        `Assoc
          [
            ("coverage", `String "viewport+below");
            ("omitted_elements", `Int 9);
            ("text_truncated", `Bool true);
          ])
      ~usage:(fun kind ->
        if kind = "operator" then
          Some
            (`Assoc
               [
                 ("input_tokens", `Int 4);
                 ("output_tokens", `Int 2);
                 ("cost", `Null);
                 ("retries", `Int 1);
               ])
        else None)
      ~decide:(fun _ -> Ok (decision "blocked"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "terminal input")
      ()
  in
  let state = state result in
  Alcotest.(check string)
    "fly-g0uh explicit coverage" "viewport+below"
    (match json_member "coverage" (json_member "page" state) with
    | `String s -> s
    | _ -> "");
  let prediction =
    match json_member "predictions" state with
    | `List [ prediction ] -> prediction
    | _ -> Alcotest.fail "prediction"
  in
  Alcotest.(check bool)
    "fly-9e0f unknown cost is null" true
    (json_member "cost" (json_member "usage" prediction) = `Null);
  Alcotest.(check int)
    "fly-u9eg prediction count retained" 1 (metric result "predictions");
  Alcotest.(check int)
    "fly-gn5z terminal state has no fake input" 0 (metric result "actions")

let fly_blocked_frontier () =
  let blocked =
    {
      (decision "blocked") with
      J.operation_probabilities =
        [ ("BLOCKED", 0.7); ("SCROLL_DOWN", 0.2); ("SCROLL_UP", 0.1) ];
    }
  in
  let exercise ~start ~bottom ~max_steps ~dry_run =
    let actions = ref 0 in
    let result =
      fly_run ~max_steps ~dry_run
        ~observe:(fun () ->
          Ok
            {
              (observation (string_of_int !actions)) with
              D.can_scroll_down = (not bottom) || !actions = 0 || (start && !actions >= 2);
              can_scroll_up =
                (start && !actions = 0) || !actions = 1 || ((not bottom) && !actions > 0);
            })
        ~decide:(fun _ -> Ok blocked)
        ~act:(fun _ choice ~text:_ ->
          let expected = if bottom && !actions > 0 then "scroll_up" else "scroll_down" in
          Alcotest.(check string)
            "rescues only offered scroll" expected
            (P.Operation.to_string choice.J.operation);
          incr actions;
          Ok (performed ()))
        ()
    in
    (result, !actions)
  in
  let result, actions =
    exercise ~start:false ~bottom:true ~max_steps:(Some 60) ~dry_run:false
  in
  check "seen page BLOCKED stands" "blocked" (P.Drive_status.to_string result.status);
  Alcotest.(check int) "one unseen bottom rescue" 1 actions;
  let first = List.hd result.steps in
  Alcotest.(check (float 0.0001))
    "original BLOCKED probability retained" 0.7
    (match json_member "BLOCKED" first.P.probabilities.op with `Float p -> p | _ -> 0.);
  let predictions =
    match json_member "predictions" (state result) with `List xs -> xs | _ -> []
  in
  Alcotest.(check bool)
    "raw BLOCKED prediction and rescue logged" true
    (json_member "operation" (List.hd predictions) = `String "blocked"
    && json_member "rescued_operation" (List.hd predictions) = `String "scroll_down");
  let history =
    match json_member "history" (state result) with `List xs -> xs | _ -> []
  in
  let rescue_entry = match history with entry :: _ -> entry | [] -> `Null in
  Alcotest.(check bool)
    "history keeps the rescue and the original BLOCKED probability" true
    (json_member "model_operation" rescue_entry = `String "blocked"
    && json_member "rescue" rescue_entry = `Bool true
    && json_member "BLOCKED"
         (json_member "op"
            (json_member "probabilities" (json_member "step" rescue_entry)))
       = `Float 0.7);
  let _, actions =
    exercise ~start:true ~bottom:true ~max_steps:(Some 60) ~dry_run:false
  in
  Alcotest.(check int) "unseen top follows unseen bottom" 2 actions;
  let result, actions =
    exercise ~start:false ~bottom:false ~max_steps:(Some 60) ~dry_run:false
  in
  Alcotest.(check int) "per-URL rescue budget (pbk-eyya: eight)" 8 actions;
  check "bounded rescue terminates BLOCKED" "blocked"
    (P.Drive_status.to_string result.status);
  let _, actions =
    exercise ~start:false ~bottom:false ~max_steps:(Some 1) ~dry_run:false
  in
  Alcotest.(check int) "rescues respect mission action cap" 1 actions;
  let _, actions =
    exercise ~start:false ~bottom:true ~max_steps:(Some 60) ~dry_run:true
  in
  Alcotest.(check int) "dry-run never rescues input" 0 actions

let fly_unsupported () =
  let unsupported = `List [ `String "iframe"; `String "canvas" ] in
  let result =
    fly_run
      ~coverage:(fun _ -> `Assoc [ ("unsupported_states", unsupported) ])
      ~decide:(fun request ->
        Alcotest.(check bool)
          "unsupported coverage reaches JEV" true
          (json_member "unsupported_states"
             (json_member "coverage" (json_member "state" (J.body request)))
          = unsupported);
        Ok (decision "blocked"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "terminal unsupported input")
      ()
  in
  Alcotest.(check bool)
    "terminal page reports unsupported states" true
    (json_member "unsupported_states" (json_member "page" (state result)) = unsupported);
  Alcotest.(check (option string))
    "unsupported reason is explicit"
    (Some "the operator found no available action; unsupported visible UI: iframe, canvas")
    result.reason;
  (* daily-9ggi fly-eoqg: a password field is never the operator's; BLOCKED says who
     types it (the L44 run-3 login mission typed the password into Username). *)
  let password = `List [ `String "password-field" ] in
  let result =
    fly_run
      ~coverage:(fun _ -> `Assoc [ ("unsupported_states", password) ])
      ~decide:(fun _ -> Ok (decision "blocked"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "terminal password input")
      ()
  in
  Alcotest.(check bool)
    "daily-9ggi a password page names leash fill" true
    (match result.reason with
    | Some reason -> contains reason "leash fill" && contains reason "never types"
    | None -> false)

let semantic_request_real_reply () =
  let result =
    fly_run
      ~label:(fun ~url:_ ~title:_ ~text:_ ->
        D.{ kind = "home"; source = "inferred"; url = "home" })
      ~decide:(fun request ->
        let page = J.body request |> json_member "state" |> json_member "page" in
        Alcotest.(check bool)
          "kind-ir9l request alone uses shown URL" true
          (json_member "url" page = `String "home");
        Ok (decision "done"))
      ~act:(fun _ _ ~text:_ -> Alcotest.fail "unexpected action")
      ()
  in
  let page = state result |> json_member "page" in
  Alcotest.(check bool)
    "trace-qe8c reply preserves real URL" true
    (json_member "url" page = `String "https://example.org");
  Alcotest.(check bool)
    "kind-ir9l reply keeps kind separately" true
    (json_member "page_kind" page = `String "home")

let bounded_pre_action_risk () =
  let actions = ref 0 in
  let target =
    P.
      {
        index = 1;
        role = "button";
        name = "OK";
        value = None;
        state = None;
        options = None;
      }
  in
  let initial =
    {
      (observation ~rows:[ target ] "Settings") with
      D.text = "Delete account PRIVATE-BODY";
    }
  in
  let current = ref initial in
  let handler =
    D.
      {
        observe = (fun () -> Ok !current);
        decide =
          (fun _ ->
            Ok (if !actions = 0 then decision ~index:1 "click" else decision "done"));
        text_value = (fun _ -> Ok None);
        act =
          (fun _ _ ~text:_ ->
            incr actions;
            current := observation ~rows:[ target ] "Settings";
            Ok
              P.
                {
                  tab = handle;
                  url = "https://example.org";
                  title = "Settings";
                  snapshot = None;
                  dialog = None;
                  popups = [];
                  via = None;
                });
      }
  in
  let result =
    match
      D.run ~handler ~now:(fun () -> 0.) ~model:"fake" ~args:(args ()) ~dry_run:false ()
    with
    | Ok result -> result
    | Error e -> Alcotest.fail e.P.message
  in
  Alcotest.(check bool)
    "map-yzqp neutral OK retains destructive pre-action context" true
    (List.hd result.steps).P.non_repeatable;
  Alcotest.(check bool)
    "map-yzqp durable step never includes raw page body" false
    (contains (Yojson.Safe.to_string (P.yojson_of_drive_result result)) "PRIVATE-BODY")

(* map-yzqp map-ngyr: risk belongs to the chosen action, not unrelated controls. *)
let scoped_action_risk () =
  let check_case ?(title = "Google Maps") ?(url = "https://www.google.com/maps")
      ?(kind = None) ?(target = "Search") ?(role = "button") ?(index = Some 1)
      ?(operation = "click") ?(truncated = false) ~body ~ambient expected =
    let selected = { (row 1 target) with P.role } in
    let other = { (row 2 ambient) with P.role = "button" } in
    let page = observation ~rows:[ selected; other ] title in
    let page =
      {
        page with
        D.text = body;
        snapshot = { page.snapshot with P.url; page_kind = kind; truncated };
      }
    in
    let calls = ref 0 in
    let result =
      fly_run
        ~observe:(fun () -> Ok page)
        ~decide:(fun _ ->
          incr calls;
          Ok (if !calls = 1 then decision ?index operation else decision "done"))
        ~text_value:(fun _ -> Ok (Some "Eiffel Tower"))
        ~act:(fun _ _ ~text:_ -> Ok (performed ()))
        ()
    in
    Alcotest.(check bool)
      ("map-yzqp " ^ target ^ " / " ^ body)
      expected (List.hd result.steps).P.non_repeatable
  in
  check_case ~body:"Search\nSend Product Feedback" ~ambient:"Send Product Feedback" false;
  check_case ~target:"Search Google Maps" ~role:"combobox" ~operation:"type_text"
    ~body:"Send to phone\nSearch Google Maps" ~ambient:"Send to phone" false;
  check_case ~truncated:true ~body:"Search\nSend Product Feedback"
    ~ambient:"Send Product Feedback" true;
  check_case ~body:"Search\nDelete account permanently"
    ~ambient:"Delete account permanently" false;
  check_case ~body:"Delete account permanently\nSearch\nDelete account permanently"
    ~ambient:"Delete account permanently" true;
  check_case ~target:"Send to phone" ~body:"Send to phone" ~ambient:"Search" true;
  check_case ~target:"OK" ~body:"Delete this account permanently?\nOK" ~ambient:"Cancel"
    true;
  check_case ~target:"Continue" ~body:"Payment details\nContinue" ~ambient:"Cancel" true;
  check_case ~target:"Submit" ~body:"Post this message\nSubmit" ~ambient:"Cancel" true;
  check_case ~title:"Checkout payment" ~body:"Search\nSend Product Feedback"
    ~ambient:"Send Product Feedback" true;
  check_case
    ~kind:(Some P.{ name = "deletion"; source = Inferred })
    ~body:"Search" ~ambient:"Cancel" true;
  check_case ~body:"Search\nThis action will delete your account" ~ambient:"Cancel" true;
  check_case ~index:None ~body:"Send Product Feedback" ~ambient:"Send Product Feedback"
    true;
  check_case ~target:"Search" ~body:"Send Product Feedback and delete account"
    ~ambient:"Send Product Feedback" true

let () =
  Alcotest.run "drive"
    [
      ( "scripted",
        List.map
          (fun (n, f) -> Alcotest.test_case n `Quick f)
          [
            ("map-yzqp action scoped search safety", scoped_action_risk);
            ("map-yzqp bounded pre-action safety evidence", bounded_pre_action_risk);
            ("fly-hc3l fly-fl7u fly-vzzw budgets", fly_budgets);
            ("fly-vnf1 bounded BLOCKED frontier rescue", fly_blocked_frontier);
            ("fly-g0uh unsupported partial evidence", fly_unsupported);
            ("fly-gysl fly-qr70 fly-9363 helper guard", fly_helper_guard);
            ("fly-vzzw fresh terminal", fly_terminal_refresh);
            ("fly-4lmg fly-4mio fly-2pn7 observation bound", fly_observation_bound);
            ("fly-g0uh fly-9e0f fly-u9eg fly-gn5z state", fly_structured_state);
            ("kind-ir9l trace-qe8c shown request real reply", semantic_request_real_reply);
            ("done", done_path);
            ("pbk-eyya goal until", until_reached);
            ("daily-9ggi blocked reasons", blocked_reasons);
            ("stall", stall);
            ("cap", cap);
            ("deadline", deadline);
            ("dry-run", dry_run);
            ("drive-ls3c type-text fills", type_text_fills);
            ("drive-ls3c type-text missing", type_text_missing);
            ("drive-kh2u type-text error", text_error);
            ("drive-ls3c type-text stale", type_text_stale);
            ("drive-kh2u model-error", fun () -> model_error ());
            ( "daily-9ggi timeout retains trace",
              fun () -> model_error ~code:"model-timeout" () );
            ("drive-y7v8 step-error", step_failure);
            ("drive-n3ld dialog and popup name the cause", dialog_popup_error);
          ] );
    ]
