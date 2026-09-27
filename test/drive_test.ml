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
      rows = [];
      total = 0;
      offset = 0;
      truncated = false;
      settled = true;
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
    ?(change = false) choices =
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
        }
  in
  let reply =
    D.run
      ~handler:D.{ observe; decide; text_value; act }
      ~now:(fun () -> !time)
      ~model:"test-model"
      ~args:(args ~max_steps ~deadline_s ())
      ~dry_run
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

let stall () =
  let r, acts, _ = run [ "click"; "click"; "click"; "done" ] in
  check "drive-4bhg stall" "blocked" (status r);
  Alcotest.(check int) "three actions" 3 acts

let cap () =
  let r, acts, _ = run ~max_steps:2 [ "click"; "click"; "done" ] in
  check "drive-ix5t cap" "step-cap" (status r);
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
        P.
          {
            code =
              (match Error_code.of_string "stale-snapshot" with
              | Ok code -> code
              | Error _ -> assert false);
            message = "the row changed since the snapshot; snap again";
            detail = None;
          }
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
          }
    end
  in
  let reply =
    D.run
      ~handler:D.{ observe; decide; text_value; act }
      ~now:(fun () -> 0.)
      ~model:"test-model" ~args:(args ()) ~dry_run:false
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
    P.
      {
        code =
          (match Error_code.of_string "model-unavailable" with
          | Ok code -> code
          | Error _ -> assert false);
        message = "chat offline";
        detail = Some (`Assoc [ ("code", `String "unavailable") ]);
      }
  in
  let reply, _, _, _ =
    with_text
      ~rows:[ row 1 "Search" ]
      [ ("scroll_down", None); ("type_text", Some 1) ]
      [ Error failure ]
  in
  match reply with
  | Ok _ -> Alcotest.fail "drive-ls3c a helper failure must be a protocol error"
  | Error error ->
      Alcotest.(check string)
        "drive-ls3c the code" "model-unavailable"
        (P.Error_code.to_string error.code);
      let field key =
        match error.detail with Some (`Assoc xs) -> List.assoc_opt key xs | _ -> None
      in
      Alcotest.(check int)
        "drive-kh2u the completed step travels" 1
        (match field "steps" with Some (`List xs) -> List.length xs | _ -> 0)

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
      Alcotest.(check int) "drive-ls3c the helper is asked again" 2 (List.length contexts);
      (match contexts with
      | [ first; second ] ->
          Alcotest.(check bool)
            "drive-ls3c the retry's context is unchanged" true (first = second)
      | _ -> ());
      Alcotest.(check int)
        "drive-9y2s the stale decision is not a trace step" 2 (List.length r.steps)

let model_error () =
  let count = ref 0 and actions = ref 0 in
  let error =
    P.
      {
        code =
          (match Error_code.of_string "model-unavailable" with
          | Ok x -> x
          | Error _ -> assert false);
        message = "model offline";
        detail = Some (`Assoc [ ("code", `String "offline") ]);
      }
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
                });
      }
  in
  match
    D.run ~handler ~now:(fun () -> 0.) ~model:"test-model" ~args:(args ()) ~dry_run:false
  with
  | Ok _ -> Alcotest.fail "drive-kh2u must return protocol error"
  | Error got ->
      check "model error code" "model-unavailable" (P.Error_code.to_string got.code);
      let field k =
        match got.detail with Some (`Assoc xs) -> List.assoc_opt k xs | _ -> None
      in
      Alcotest.(check (option string))
        "error subtype" (Some "offline")
        (match field "code" with Some (`String s) -> Some s | _ -> None);
      Alcotest.(check int)
        "one completed step in detail" 1
        (match field "steps" with Some (`List xs) -> List.length xs | _ -> 0);
      Alcotest.(check int) "one action" 1 !actions

let step_failure () =
  let internal =
    P.
      {
        code =
          (match Error_code.of_string "internal" with
          | Ok x -> x
          | Error _ -> assert false);
        message = "browser unavailable";
        detail = None;
      }
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
                      });
          }
      in
      match
        D.run ~handler
          ~now:(fun () -> 0.)
          ~model:"test-model" ~args:(args ()) ~dry_run:false
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
               (if act_fails then "the click action failed"
                else "observe after the action failed"));
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
      }
  in
  let popup =
    P.
      {
        tab = handle;
        url = "https://example.org/popup";
        title = "Popup";
        origin =
          (match Origin.of_string "agent" with Ok x -> x | Error _ -> assert false);
        state = (match State.of_string "owned" with Ok x -> x | Error _ -> assert false);
        owner = None;
        generation = 1;
        expires = None;
        reason = None;
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
                    });
          }
      in
      match
        D.run ~handler
          ~now:(fun () -> 0.)
          ~model:"test-model" ~args:(args ()) ~dry_run:false
      with
      | Error e -> Alcotest.failf "%s: %s" label (P.Error_code.to_string e.code)
      | Ok r ->
          check (label ^ " status") "error" (status r);
          Alcotest.(check (option string)) (label ^ " reason") (Some expected) r.reason)
    [
      ("dialog", Some alert, [], "dialog open: alert");
      ("popup", None, [ popup ], "1 popup opened");
    ]

let () =
  Alcotest.run "drive"
    [
      ( "scripted",
        List.map
          (fun (n, f) -> Alcotest.test_case n `Quick f)
          [
            ("done", done_path);
            ("stall", stall);
            ("cap", cap);
            ("deadline", deadline);
            ("dry-run", dry_run);
            ("drive-ls3c type-text fills", type_text_fills);
            ("drive-ls3c type-text missing", type_text_missing);
            ("drive-kh2u type-text error", text_error);
            ("drive-ls3c type-text stale", type_text_stale);
            ("drive-kh2u model-error", model_error);
            ("drive-y7v8 step-error", step_failure);
            ("drive-n3ld dialog and popup name the cause", dialog_popup_error);
          ] );
    ]
