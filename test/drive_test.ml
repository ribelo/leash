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

let observation title =
  D.
    {
      snapshot = snapshot ~title ();
      text = title;
      can_scroll_down = false;
      can_scroll_up = false;
      fingerprint = title;
    }

let decision name : J.decision =
  {
    operation = op name;
    index = None;
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
  let act _ _ =
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
      ~handler:D.{ observe; decide; act }
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

let type_text () =
  let r, acts, _ = run [ "type_text" ] in
  check "drive-ls3c blocked" "blocked" (status r);
  Alcotest.(check (option string)) "unavailable" (Some "text helper unavailable") r.reason;
  Alcotest.(check int) "never fill" 0 acts

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
        act =
          (fun _ _ ->
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
            act =
              (fun _ _ ->
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
          Alcotest.(check int) (label ^ " trace") 1 (List.length r.steps))
    [ ("act", true); ("post-action observe", false) ]

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
            ("type-text", type_text);
            ("drive-kh2u model-error", model_error);
            ("drive-y7v8 step-error", step_failure);
          ] );
    ]
