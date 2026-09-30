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
 "scripts":{"list":{"source":"return []","returns":[{"id":"string"}]},
 "next":{"source":"return {url:location.href}","returns":{"url":"url"}},
 "last":{"source":"return {done:true}","returns":{"done":"boolean"}}},
 "procedures":[{"slug":"collect","description":"Collect","steps":[{"script":"list"}],
 "expect":["no dialog is open"],"repeat":{"next":"next-page","max":2,"key":"id","until":{"script":"last"}}},
 {"slug":"next-page","description":"Next","steps":[{"navigate":{"script":"next"}},{"script":"list"}],"expect":["no dialog is open"]}]}|}))

let run ?(book = book) ?(empty = false) ?(next_url = "https://example.com/page-2")
    ?(malformed_done = false) ?(rejected = false) () =
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
          rows = [];
          total = 0;
          offset = 0;
          truncated = false;
          settled = true;
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
      }
  in
  let handler =
    R.
      {
        observe = (fun () -> Ok (observe ()));
        navigate =
          (fun target ->
            navigations := target :: !navigations;
            url := target;
            incr page;
            Ok ());
        choose =
          (fun q ->
            questions := q :: !questions;
            let key =
              if q.name = "select_playbook" then
                match
                  List.find_opt
                    (fun (key, _) -> String.starts_with ~prefix:"book:" key)
                    q.criteria
                with
                | Some (key, _) -> key
                | None -> "example.com"
              else (
                incr asked;
                if !asked = 1 then "collect" else "DONE")
            in
            Ok
              {
                key;
                confidence = 1.;
                probabilities = `Assoc [ (key, `Float 1.) ];
                usage = None;
                judgments = [];
              });
        text_value = (fun _ -> assert false);
        step = (fun _ -> assert false);
        verify =
          (fun ~pages:_ ~checks ~timeout_s:_ ->
            Ok
              ( List.map
                  (fun (sentence, _) ->
                    P.{ sentence; checker = "no_dialog"; passed = true; score = None })
                  checks,
                observe () ));
        plan =
          (fun _ ->
            Ok
              { answer = Fail "collection failed"; expect = []; usage = None; pages = [] });
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
                    else (`List [ `Assoc [ ("id", `String (string_of_int !page)) ] ], 1)
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
            start_url = None;
            max_procedures = 10;
            deadline_s = 60;
            dry_run = false;
            max_plans = 1;
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
    "playbook decision recorded" 1
    (List.length result.playbook_choices);
  let first = List.hd questions in
  Alcotest.(check bool)
    "an open tab is not reported as a blank start" false
    (match first.state with
    | `Assoc fields -> List.mem_assoc "current_page" fields
    | _ -> true)

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
         ("unsafe scheme", run ~next_url:"javascript:alert(1)" ());
         ("wrong done type", run ~malformed_done:true ());
         ("shape rejection", run ~rejected:true ());
       ])

let one_shot () =
  let proc = { (List.hd book.playbook.procedures) with B.repeat = None } in
  let book =
    ok
      (B.of_json ~file:"one-shot.json"
         (B.yojson_of_t { book.playbook with B.procedures = [ proc ] }))
  in
  List.iter
    (fun empty ->
      let result, _, _, questions = run ~book ~empty () in
      Alcotest.(check string)
        "one-shot finishes" "done"
        (P.Run_status.to_string result.status);
      Alcotest.(check int) "collector runs once" 1 (List.length result.procedures);
      let last = List.hd (List.rev questions) in
      Alcotest.(check bool)
        "completion visible even for zero records" true
        (match last.state with
        | `Assoc fields -> List.assoc_opt "collection_complete" fields = Some (`Bool true)
        | _ -> false))
    [ false; true ]

let () =
  Alcotest.run "L40 controls"
    [
      ( "extr-uhnc",
        [
          Alcotest.test_case "native repeat and terminal cap" `Quick native_repeat;
          Alcotest.test_case "one-shot and empty completion" `Quick one_shot;
          Alcotest.test_case "fail closed controls" `Quick refuses_control;
        ] );
    ]
