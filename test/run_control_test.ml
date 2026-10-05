(* L40 extr-uhnc: prepared controls navigate real pages, never collect control records. *)
module R = Leash.Run
module B = Leash.Playbook
module P = Leash.Protocol

let ok = function Ok x -> x | Error e -> Alcotest.fail e

let book =
  ok
    (B.of_json ~file:"control.json"
       (Yojson.Safe.from_string
          {|{
 "site":"example.com","entry":"https://example.com/","description":"Catalogue","pages":[],
 "shapes":{"row":[{"id":"string"}],"url":{"url":"url"},"done":{"done":"boolean"}},
 "scripts":{"list":{"source":"return []","description":"List the page.","returns":"row"},
 "next":{"source":"return {url:location.href}","description":"The next page URL.","returns":"url"},
 "last":{"source":"return {done:true}","description":"Whether the listing is finished.","returns":"done"}},
 "procedures":[{"slug":"collect","description":"Collect","steps":[{"script":"list"}],
 "expect":["no dialog is open"],"repeat":{"next":"next-page","max":2,"key":"id","until":{"script":"last"}}},
 {"slug":"next-page","description":"Next","steps":[{"goal":"Open the next page."},{"script":"list"}],"expect":["no dialog is open"]},
 {"slug":"open","description":"Open the catalogue.","steps":[{"goal":"Open the catalogue."},{"use":"collect"}],"expect":["no dialog is open"]}]}|}))

let run ?(duplicate = false) ?(book = book) ?(empty = false)
    ?(next_url = "https://example.com/page-2") ?(malformed_done = false)
    ?(rejected = false) () =
  (* fly-xger: a blank tab with no URL is missing-start, not a playbook question.
     These controls start on an open page so the playbook switch is what navigates. *)
  let url = ref "https://start.example/" and page = ref 0 and asked = ref 0 in
  let navigations = ref [] and streamed = ref [] and questions = ref [] in
  let observe () =
    let snapshot =
      P.
        {
          snapshot = ok (Snapshot_id.of_string "s_control");
          tab = ok (Handle.of_string "t_control");
          url = !url;
          title = "Catalogue";
          page_kind = None;
          rows = [];
          total = 0;
          offset = 0;
          truncated = false;
          settled = true;
          source = P.Ax;
          image = None;
          reason = None;
          dialog = None;
        }
    in
    R.
      {
        url = !url;
        title = "Catalogue";
        text = "";
        rows = [];
        downloads = [];
        dialog = None;
        snapshot;
        image_input = None;
      }
  in
  let handler =
    R.
      {
        observe = (fun ~image:_ () -> Ok (observe ()));
        navigate =
          (fun target ->
            navigations := target :: !navigations;
            url := target;
            incr page;
            Ok ());
        choose = (fun _ -> Alcotest.fail "pilot must not choose playbooks through JEV");
        text_value = (fun _ -> assert false);
        step =
          (fun _ ->
            navigations := next_url :: !navigations;
            url := next_url;
            incr page;
            Ok
              {
                status = ok (P.Drive_status.of_string "done");
                steps = [];
                final = (observe ()).snapshot;
                operator_state = None;
                reason = None;
              });
        verify =
          (fun ~pages:_ ~checks ~timeout_s:_ ->
            Ok
              ( List.map
                  (fun (sentence, _) ->
                    P.{ sentence; checker = "no_dialog"; passed = true; score = None })
                  checks,
                observe () ));
        plan =
          (fun request ->
            questions := request :: !questions;
            incr asked;
            Ok
              {
                answer =
                  (if !asked = 1 then Leg "collect"
                   else if malformed_done || rejected then Fail "collection failed"
                   else
                     Done { result = "Collected catalogue"; evidence = []; records = [] });
                expect = [];
                usage = None;
                reasoning_summary = None;
                secrets_for_operator = [];
              });
        propose = (fun ~site:_ _ -> assert false);
        hand_off = (fun ~reason:_ -> assert false);
        script =
          (fun script ~args:_ ->
            if rejected && script.B.name = "last" then
              Ok (Rejected { reason = "$.done: expected boolean"; elapsed_ms = 1 })
            else
              let value, records =
                match script.B.name with
                | "list" ->
                    if empty then (`List [], 0)
                    else
                      ( `List
                          [
                            `Assoc
                              [
                                ( "id",
                                  `String
                                    (if duplicate then "same-id" else string_of_int !page)
                                );
                              ];
                          ],
                        1 )
                | "next" -> (`Assoc [ ("url", `String next_url) ], 1)
                | "last" ->
                    ( `Assoc
                        [
                          ( "done",
                            if malformed_done then `String "yes" else `Bool (!page = 2) );
                        ],
                      1 )
                | _ -> assert false
              in
              Ok (Collected { value; records; bytes = 20; elapsed_ms = 1 }));
      }
  in
  let result =
    match
      R.loop ~handler
        ~now:(fun () -> 0.)
        ~installed:[ book ]
        ~on_record:(fun record ->
          streamed := record :: !streamed;
          Ok ())
        ~pause_ms:ignore
        R.
          {
            mission = "collect every book";
            max_steps = 60;
            start_url = Some book.playbook.entry;
            max_procedures = 10;
            deadline_s = 60;
            dry_run = false;
            max_plans = 2;
            expect = [];
          }
    with
    | Ok result -> result
    | Error e -> Alcotest.fail e.P.message
  in
  (result, List.rev !navigations, !streamed, List.rev !questions)

let native_repeat () =
  let result, navigations, streamed, questions = run () in
  Alcotest.(check string)
    "terminal check wins at exact cap" "done"
    (P.Run_status.to_string result.status);
  Alcotest.(check (list string))
    "native navigation called"
    [ "https://example.com/"; "https://example.com/page-2" ]
    navigations;
  Alcotest.(check int) "only list records streamed" 2 (List.length streamed);
  Alcotest.(check int) "only list records counted" 2 result.collected;
  Alcotest.(check int)
    "candidate expectations are audited" 2
    (List.length (List.hd result.procedures).expectations);
  Alcotest.(check int) "no JEV playbook decision" 0 (List.length result.playbook_choices);
  let first = List.hd questions in
  Alcotest.(check bool)
    "an open tab is not reported as a blank start" false (first.legs <> [])

let duplicate_records () =
  let result, _, streamed, _ = run ~duplicate:true () in
  Alcotest.(check int) "repeat key deduplicates records" 1 result.collected;
  Alcotest.(check int) "repeat key deduplicates streamed JSONL" 1 (List.length streamed)

let rejected_trace () =
  let result, _, _, _ = run ~rejected:true () in
  Alcotest.(check bool)
    "control rejection is audited" true
    (List.exists
       (fun (script : P.run_script) ->
         script.script = "last" && script.error = Some "$.done: expected boolean")
       (List.hd result.procedures).scripts)

let refuses_control () =
  List.iter
    (fun (name, result, navigations) ->
      Alcotest.(check bool)
        (name ^ " refuses completion")
        false
        (P.Run_status.to_string result.P.status = "done");
      Alcotest.(check (list string))
        (name ^ " does not navigate bad URL")
        [ "https://example.com/" ] navigations)
    (List.map
       (fun (name, (r, n, _, _)) -> (name, r, n))
       [
         (* map-fmt01: a navigate script no longer returns the URL, so scheme checks are not a step kind. *)
         ("wrong done type", run ~malformed_done:true ());
         ("shape rejection", run ~rejected:true ());
       ])

let one_shot () =
  let proc = { (List.hd book.playbook.procedures) with B.repeat = None } in
  let anchor =
    List.find (fun (p : B.procedure) -> p.slug = "open") book.playbook.procedures
  in
  let book =
    ok
      (B.of_json ~file:"one-shot.json"
         (B.yojson_of_t { book.playbook with B.procedures = [ proc; anchor ] }))
  in
  List.iter
    (fun empty ->
      let result, _, _, questions = run ~book ~empty () in
      Alcotest.(check string)
        "one-shot finishes" "done"
        (P.Run_status.to_string result.status);
      Alcotest.(check int)
        "one candidate leg" 1
        (List.length (List.hd (List.rev questions)).legs);
      let last = List.hd (List.rev questions) in
      Alcotest.(check bool)
        "completion visible even for zero records" true
        (match last.legs with [ leg ] -> leg.outcome = "done" | _ -> false))
    [ false; true ]

let () =
  Alcotest.run "L40 controls"
    [
      ( "extr-uhnc",
        [
          Alcotest.test_case "native repeat and terminal cap" `Quick native_repeat;
          Alcotest.test_case "keyed repeat deduplication" `Quick duplicate_records;
          Alcotest.test_case "rejected control audit" `Quick rejected_trace;
          Alcotest.test_case "one-shot and empty completion" `Quick one_shot;
          Alcotest.test_case "fail closed controls" `Quick refuses_control;
        ] );
    ]
