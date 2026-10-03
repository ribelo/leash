(* L45 fly-iodm fly-crcc fly-4lmg fly-2pn7 fly-4mio fly-9363: one guarded viewport
   observation and the reference's action checks, against the scripted CDP fake. *)

module P = Leash.Protocol
module S = Leash__Snapshot_source
module J = Leash__Jev_request
module Fake = Leash_test_support.Fake_browser

let operation name =
  match P.Operation.of_string name with Ok value -> value | Error e -> Alcotest.fail e

let decision ?(index = None) name =
  J.
    {
      operation = operation name;
      script = None;
      index;
      option = None;
      confidence = 1.;
      target_confidence = None;
      operation_probabilities = [ (name, 1.) ];
      target_probabilities = [];
      targets = [];
    }

let assoc key = function `Assoc fields -> List.assoc_opt key fields | _ -> None

let string_field key json =
  match assoc key json with Some (`String s) -> s | _ -> Alcotest.fail ("missing " ^ key)

let bool_field key json =
  match assoc key json with Some (`Bool b) -> b | _ -> Alcotest.fail ("missing " ^ key)

let int_field key json =
  match assoc key json with
  | Some (`Int n) -> n
  | Some (`Float n) -> int_of_float n
  | _ -> Alcotest.fail ("missing " ^ key)

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec scan at = at + n <= h && (String.sub haystack at n = needle || scan (at + 1)) in
  n = 0 || scan 0

let expression request =
  match assoc "params" request with
  | Some params -> (
      match assoc "expression" params with Some (`String s) -> s | _ -> "")
  | None -> ""

let guard_value =
  `Assoc
    [
      ("epoch", `String "document-1");
      ("count", `Int 1);
      ("width", `Int 800);
      ("height", `Int 600);
      ("scrollX", `Int 0);
      ("scrollY", `Int 0);
      ("devicePixelRatio", `Int 1);
    ]

let evaluated value =
  `Assoc [ ("result", `Assoc [ ("type", `String "object"); ("value", value) ]) ]

let payload ~text ~truncated ~omitted ~y ~height ~viewport =
  `Assoc
    [
      ("kind", `String "leash-operator");
      ("url", `String "https://example.com/");
      ("title", `String "Example");
      ("timeOrigin", `Int 1);
      ("text", `String text);
      ("truncated", `Bool truncated);
      ("omitted", `Int omitted);
      ( "scroll",
        `Assoc
          [
            ("x", `Int 0);
            ("y", `Int y);
            ("height", `Int height);
            ("viewport", `Int viewport);
            ("width", `Int 800);
          ] );
      ("semantics", `List []);
    ]

let stable =
  payload ~text:"Visible title 12" ~truncated:false ~omitted:0 ~y:0 ~height:400
    ~viewport:400

let scrolled =
  payload ~text:"Visible title 12" ~truncated:true ~omitted:3 ~y:0 ~height:2000
    ~viewport:400

let rig f =
  Eio_main.run (fun env ->
      Eio.Time.with_timeout_exn env#clock 5. (fun () ->
          Eio.Switch.run (fun sw ->
              let mgr =
                Ox_test.Process.make
                  [ Block_until_signal; Block_until_signal; Block_until_signal ]
              in
              let current = ref None in
              let launch ~sw ~clock ~mgr:_ config =
                let fake, client = Fake.create ~sw ~sleep:(Eio.Time.sleep clock) () in
                current := Some fake;
                match
                  Ox_process.Child.spawn ~caps:(Ox_test.powerbox ()) ~sw ~clock
                    ~mgr:(Ox_test.Process.mgr mgr) ~argv:(Leash.Chrome.argv config)
                    ~grace:(Ox.Duration.ms 50) ~fds:[] ()
                with
                | Error e -> Error e
                | Ok child ->
                    Ok (child, { Leash.Cdp.read = client.read; write = client.write })
              in
              let logger =
                Ox_observability.Logger.create ~service:"leash-observation-tests"
                  ~clock:env#clock ~mono_clock:env#mono_clock
                  ~reporter:(Ox_observability.Logger.Reporter.writer ignore)
                  ()
              in
              let chrome =
                Leash.Chrome.create ~sw ~launch
                  (Leash.Chrome.make ~binary:"/bin/sh"
                     ~profile_dir:"/tmp/leash-observation-profile" ~workspace:"test"
                     ~headless:true ())
                  {
                    Leash.Chrome.clock = env#clock;
                    mgr = env#process_mgr;
                    logger;
                    caps = (Ox_test.powerbox () :> Leash.Chrome.caps);
                  }
              in
              let tabs =
                Leash.Tabs.create ~sw ~cap:3 ~tombstone_s:3600
                  {
                    Leash.Tabs.chrome;
                    clock = env#clock;
                    logger;
                    desktop = Leash.Desktop.disabled;
                    caps = (Ox_test.powerbox () :> Leash.Tabs.caps);
                  }
              in
              let rec ready n =
                if n = 0 then Alcotest.fail "no Chrome"
                else
                  match Leash.Chrome.connection chrome with
                  | Ok _ -> ()
                  | Error _ ->
                      Eio.Fiber.yield ();
                      ready (n - 1)
              in
              ready 1000;
              let fake () =
                match !current with Some fake -> fake | None -> Alcotest.fail "no fake"
              in
              f env sw tabs fake)))

let new_tab tabs =
  match Leash.Tabs.new_tab tabs ~url:None with
  | Ok info -> info.P.tab
  | Error e -> Alcotest.fail e.P.message

let script fake reply =
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      let expression = expression request in
      if expression = S.interactive_count_expression then evaluated (`Int 0)
      else if contains expression S.operator_mark then (
        let params = Option.get (assoc "params" request) in
        Alcotest.(check int)
          "fly-spgh isolated-world read" 7
          (int_field "contextId" params);
        reply ())
      else if contains expression S.settle_mark then
        `Assoc
          [ ("result", `Assoc [ ("type", `String "boolean"); ("value", `Bool true) ]) ]
      else evaluated guard_value)

let operator_reads fake =
  Fake.received fake
  |> List.filter (fun json ->
      match assoc "method" json with
      | Some (`String "Runtime.evaluate") -> contains (expression json) S.operator_mark
      | _ -> false)

let drive ?text_helper tabs decisions =
  let queue = ref decisions in
  let decide ~deadline:_ _request =
    match !queue with
    | next :: rest ->
        queue := rest;
        Ok next
    | [] -> Alcotest.fail "the drive asked for another decision"
  in
  Leash.Tabs.drive ~decide ?text_helper tabs ~model:"fixture"
    P.
      {
        tab = new_tab tabs;
        goal = "Read the visible page";
        max_steps = Some 4;
        deadline_s = Some 30;
        dry_run = Some false;
      }

let page_of (result : P.drive_result) =
  match result.P.operator_state with
  | Some state -> (
      match assoc "page" state with
      | Some page -> page
      | None -> Alcotest.fail "operator_state has no page")
  | None -> Alcotest.fail "drive returned no operator_state"

let vocabulary () =
  Alcotest.(check string)
    "fly-9363 a fitted viewport" "viewport"
    (S.coverage_string ~text_truncated:false ~omitted_elements:0 ~can_scroll_up:false
       ~can_scroll_down:false);
  Alcotest.(check string)
    "fly-9363 flags stay in order" "viewport+truncated+omitted+above+below"
    (S.coverage_string ~text_truncated:true ~omitted_elements:3 ~can_scroll_up:true
       ~can_scroll_down:true);
  Alcotest.(check string) "fly-2pn7 wait is 100 ms" "0.1" (string_of_float S.wait_s);
  Alcotest.(check int) "fly-2pn7 scroll is 560" 560 S.scroll_delta;
  Alcotest.(check int) "fly-4mio ten observation attempts" 10 S.observe_attempts;
  Alcotest.(check string)
    "fly-4mio twenty milliseconds between attempts" "0.02"
    (string_of_float S.observe_retry_s);
  (match S.parse_operator `Null with
  | S.Navigating -> ()
  | _ -> Alcotest.fail "fly-4mio null is a navigating document");
  (match S.parse_operator guard_value with
  | S.Foreign -> ()
  | _ -> Alcotest.fail "fly-crcc a guard object is not an operator payload");
  match (S.parse_operator stable, S.parse_operator scrolled) with
  | S.Payload a, S.Payload b ->
      Alcotest.(check bool)
        "fly-4lmg a scroll change moves the marker" true (a.marker <> b.marker)
  | _ -> Alcotest.fail "payloads did not parse"

let bounded_page () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      script fake (fun () -> evaluated scrolled);
      match drive tabs [ decision "done" ] with
      | Error e -> Alcotest.fail e.P.message
      | Ok result ->
          Alcotest.(check string)
            "fly-iodm status" "done"
            (P.Drive_status.to_string result.status);
          let page = page_of result in
          Alcotest.(check string)
            "fly-iodm viewport text, not the whole document" "Visible title 12"
            (string_field "text" page);
          Alcotest.(check bool)
            "fly-crcc truncation is reported" true
            (bool_field "text_truncated" page);
          Alcotest.(check int)
            "fly-crcc omitted candidates" 3
            (int_field "omitted_elements" page);
          Alcotest.(check bool)
            "fly-iodm can scroll down" true
            (bool_field "can_scroll_down" page);
          Alcotest.(check bool)
            "fly-iodm cannot scroll up from the top" false
            (bool_field "can_scroll_up" page);
          let bounds =
            match assoc "bounds" page with
            | Some bounds -> bounds
            | None -> Alcotest.fail "fly-9363 coverage bounds missing"
          in
          Alcotest.(check string)
            "fly-9363 coverage vocabulary" "viewport+truncated+omitted+below"
            (string_field "coverage" bounds))

let inconsistent_read_retries () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let reads = ref 0 in
      script fake (fun () ->
          incr reads;
          evaluated (if !reads = 2 then stable else scrolled));
      match drive tabs [ decision "done"; decision "done"; decision "done" ] with
      | Error e -> Alcotest.fail e.P.message
      | Ok result ->
          Alcotest.(check string)
            "fly-crcc a mismatched pair is retried, not sent" "done"
            (P.Drive_status.to_string result.status);
          Alcotest.(check bool)
            "fly-4mio the second read differed, so another attempt ran" true (!reads > 2);
          Alcotest.(check bool)
            "fly-4mio not more than ten acquisitions" true
            (List.length (operator_reads fake) <= 20))

let stale_click_is_not_dispatched () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let reads = ref 0 in
      script fake (fun () ->
          incr reads;
          evaluated (if !reads = 3 then scrolled else stable));
      match drive tabs [ decision ~index:(Some 1) "click"; decision "done" ] with
      | Error e -> Alcotest.fail e.P.message
      | Ok result ->
          Alcotest.(check string)
            "fly-4lmg a changed marker is re-decided" "done"
            (P.Drive_status.to_string result.status);
          Alcotest.(check int)
            "fly-4lmg no click was dispatched" 0
            (List.length
               (Fake.received fake
               |> List.filter (fun json ->
                   match assoc "method" json with
                   | Some (`String "Input.dispatchMouseEvent") -> true
                   | _ -> false))))

(* Ox_test.run supplies a manual clock: without advancing it, WAIT and the
   observation retry sleep never finish. This CDP rig uses the backend clock and
   a five-second enclosing deadline, so a missing reply fails rather than hangs. *)
let scroll_and_wait () =
  rig (fun env _ tabs fake ->
      let fake = fake () in
      let y = ref 0 in
      script fake (fun () ->
          evaluated
            (payload ~text:"Visible page" ~truncated:false ~omitted:0 ~y:!y ~height:2000
               ~viewport:400));
      Fake.on_method fake "Input.dispatchMouseEvent" (fun request ->
          let params = Option.get (assoc "params" request) in
          Alcotest.(check string)
            "fly-2pn7 wheel input" "mouseWheel" (string_field "type" params);
          Alcotest.(check bool)
            "fly-2pn7 wheel point inside viewport" true
            (int_field "x" params < 800 && int_field "y" params < 600);
          y := !y + int_field "deltaY" params;
          `Assoc []);
      let started = Eio.Time.now env#clock in
      match
        drive tabs
          [
            decision "scroll_down"; decision "wait"; decision "scroll_up"; decision "done";
          ]
      with
      | Error e -> Alcotest.fail e.P.message
      | Ok result ->
          Alcotest.(check string)
            "fly-2pn7 complete scroll/wait loop" "done"
            (P.Drive_status.to_string result.status);
          Alcotest.(check bool)
            "fly-2pn7 WAIT sleeps at least 100ms" true
            (Eio.Time.now env#clock -. started >= 0.1);
          let wheels =
            Fake.received fake
            |> List.filter_map (fun request ->
                if assoc "method" request = Some (`String "Input.dispatchMouseEvent") then
                  Option.map (int_field "deltaY") (assoc "params" request)
                else None)
          in
          Alcotest.(check (list int)) "fly-2pn7 exact wheel deltas" [ 560; -560 ] wheels;
          let settles =
            Fake.received fake
            |> List.filter (fun request -> contains (expression request) S.settle_mark)
          in
          Alcotest.(check int) "fly-2pn7 settle inputs, not WAIT" 2 (List.length settles);
          Alcotest.(check bool)
            "fly-2pn7 fresh observations after actions" true
            (List.length (operator_reads fake) >= 8))

let retry_exhaustion () =
  rig (fun env _ tabs fake ->
      let fake = fake () in
      script fake (fun () -> evaluated `Null);
      let started = Eio.Time.now env#clock in
      ignore (drive tabs []);
      Alcotest.(check int)
        "fly-4mio exactly ten attempts" 10
        (List.length (operator_reads fake));
      Alcotest.(check bool)
        "fly-4mio nine bounded retry sleeps" true
        (Eio.Time.now env#clock -. started >= 0.18))

let replace_field key value = function
  | `Assoc fields -> `Assoc ((key, value) :: List.remove_assoc key fields)
  | _ -> Alcotest.fail "expected object"

let unicode_bounds () =
  let text = String.concat "" (List.init 6001 (fun _ -> "ż")) in
  match S.parse_operator (replace_field "text" (`String text) stable) with
  | S.Payload page ->
      Alcotest.(check int)
        "fly-iodm 6000 Unicode characters, not bytes" 12000 (String.length page.text);
      Alcotest.(check bool) "fly-crcc cut is explicit" true page.coverage.text_truncated
  | _ -> Alcotest.fail "invalid Unicode observation"

let invalid_observation () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      script fake (fun () -> evaluated guard_value);
      (match drive tabs [] with
      | Error error ->
          Alcotest.(check string)
            "fly-crcc no legacy fallback" "internal"
            (P.Error_code.to_string error.code)
      | Ok _ -> Alcotest.fail "invalid observation accepted");
      Alcotest.(check int)
        "fly-crcc invalid observation read once" 1
        (List.length (operator_reads fake)))

let unsettled_snapshot () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let count = ref 0 in
      Fake.on_method fake "Runtime.evaluate" (fun request ->
          if expression request = S.interactive_count_expression then evaluated (`Int 0)
          else if contains (expression request) S.operator_mark then evaluated stable
          else (
            incr count;
            evaluated (replace_field "count" (`Int !count) guard_value)));
      (match drive tabs [] with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "unsettled snapshot accepted");
      Alcotest.(check int)
        "fly-crcc ten unsettled acquisitions" 20
        (List.length (operator_reads fake));
      Alcotest.(check int)
        "fly-4mio no nested AX retries" 10
        (List.length
           (Fake.received fake
           |> List.filter (fun request ->
               assoc "method" request = Some (`String "Accessibility.getFullAXTree")))))

let form_guard_changed () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let reads = ref 0 in
      script fake (fun () ->
          incr reads;
          evaluated
            (replace_field "guard"
               (`Assoc
                  [
                    ( "forms",
                      `String
                        (if !reads >= 3 then "changed offscreen value"
                         else "original value") );
                  ])
               stable));
      match drive tabs [ decision ~index:(Some 1) "click"; decision "done" ] with
      | Error error -> Alcotest.fail error.message
      | Ok result ->
          Alcotest.(check string)
            "fly-4lmg redecide changed form" "done"
            (P.Drive_status.to_string result.status);
          Alcotest.(check int)
            "fly-4lmg refused click is not executed" 1 (List.length result.steps))

let settle_timeout_retains_input () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      let mutated = ref false in
      script fake (fun () -> evaluated (if !mutated then `Null else scrolled));
      Fake.on_method fake "Input.dispatchMouseEvent" (fun _ ->
          mutated := true;
          `Assoc []);
      Fake.withhold fake "Runtime.evaluate" (fun request ->
          contains (expression request) S.settle_mark);
      match drive tabs [ decision "scroll_down" ] with
      | Error error -> Alcotest.fail error.message
      | Ok result ->
          Alcotest.(check string)
            "fly-4mio exhausted post-input observation" "error"
            (P.Drive_status.to_string result.status);
          Alcotest.(check int)
            "fly-4mio acknowledged input survives failed observation" 1
            (List.length result.steps))

let covered_edit () =
  rig (fun _ _ tabs fake ->
      let fake = fake () in
      script fake (fun () -> evaluated stable);
      let ax =
        Yojson.Safe.from_string
          {|{"nodes":[{"nodeId":"1","backendDOMNodeId":10,"role":{"value":"textbox"},"name":{"value":"Search"},"value":{"value":"current"}}]}|}
      in
      let dom =
        Yojson.Safe.from_string
          {|{"strings":["INPUT","block","visible"],"documents":[{"nodes":{"backendNodeId":[10],"nodeName":[0],"attributes":[[]]},"layout":{"nodeIndex":[0],"bounds":[[10,10,100,30]],"styles":[[1,2]]}}]}|}
      in
      Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> ax);
      Fake.on_method fake "Accessibility.getPartialAXTree" (fun _ -> ax);
      Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> dom);
      Fake.on_method fake "DOM.describeNode" (fun _ ->
          Yojson.Safe.from_string
            {|{"node":{"nodeId":1,"backendNodeId":10,"nodeName":"INPUT","children":[],"attributes":[]}}|});
      Fake.on_method fake "DOM.getContentQuads" (fun _ ->
          Yojson.Safe.from_string {|{"quads":[[10,10,110,10,110,40,10,40]]}|});
      Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
          `Assoc [ ("backendNodeId", `Int 99) ]);
      let text_helper () =
        Leash__Text_helper.{ complete = (fun ?deadline:_ _ -> Ok (Some "query")) }
      in
      match
        drive ~text_helper tabs [ decision ~index:(Some 1) "type_text"; decision "done" ]
      with
      | Error error -> Alcotest.fail error.message
      | Ok result ->
          Alcotest.(check string)
            "map-op07 covered field refusal re-decides" "done"
            (P.Drive_status.to_string result.status);
          Alcotest.(check bool)
            "fly-iodm current value retained" true
            (List.exists
               (fun (row : P.row) -> row.index = 1 && row.value = Some "current")
               result.final.rows);
          let methods =
            Fake.received fake
            |> List.filter_map (fun request ->
                match assoc "method" request with Some (`String s) -> Some s | _ -> None)
          in
          Alcotest.(check bool)
            "fly-4lmg target was hit-tested" true
            (List.mem "DOM.getNodeForLocation" methods);
          Alcotest.(check bool)
            "fly-4lmg no input into covered control" false
            (List.exists
               (fun method_ ->
                 List.mem method_
                   [ "Input.insertText"; "Input.dispatchKeyEvent"; "DOM.focus" ])
               methods))

let unsupported_flags () =
  let flags =
    `List
      (List.map
         (fun s -> `String s)
         [ "iframe"; "shadow-root"; "canvas"; "nested-scroll-container" ])
  in
  match S.parse_operator (replace_field "unsupported_states" flags stable) with
  | S.Payload page ->
      Alcotest.(check int)
        "fly-8fgl typed unsupported-state flags" 4
        (List.length page.coverage.unsupported_states);
      Alcotest.(check string)
        "fly-9363 unsupported flags retain coverage vocabulary" "viewport"
        page.coverage.coverage;
      Alcotest.(check bool)
        "fly-8fgl coverage hook carries flags" true
        (assoc "unsupported_states" (S.coverage_json page.coverage) = Some flags)
  | _ -> Alcotest.fail "invalid unsupported-state observation"

let () =
  Alcotest.run "observation"
    [
      ( "vocabulary",
        [ Alcotest.test_case "fly-9363 fly-2pn7 coverage words" `Quick vocabulary ] );
      ( "cdp",
        [
          Alcotest.test_case "fly-iodm fly-crcc fly-9363 bounded page" `Quick bounded_page;
          Alcotest.test_case "fly-crcc fly-4mio inconsistent read" `Quick
            inconsistent_read_retries;
          Alcotest.test_case "fly-4lmg stale click" `Quick stale_click_is_not_dispatched;
          Alcotest.test_case "fly-2pn7 scroll and wait" `Quick scroll_and_wait;
          Alcotest.test_case "fly-4mio bounded retry exhaustion" `Quick retry_exhaustion;
          Alcotest.test_case "fly-iodm Unicode bounds" `Quick unicode_bounds;
          Alcotest.test_case "fly-8fgl unsupported flags" `Quick unsupported_flags;
          Alcotest.test_case "fly-4lmg covered edit" `Quick covered_edit;
          Alcotest.test_case "fly-crcc invalid observation" `Quick invalid_observation;
          Alcotest.test_case "fly-crcc unsettled snapshot" `Quick unsettled_snapshot;
          Alcotest.test_case "fly-4lmg offscreen form guard" `Quick form_guard_changed;
          Alcotest.test_case "fly-4mio settle timeout retains input" `Quick
            settle_timeout_retains_input;
        ] );
    ]
