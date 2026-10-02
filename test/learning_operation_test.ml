(* map-op01–map-op06: pure durable Google2/Google3 regressions; no browser or model. *)
module O = Leash__Learning_operation
module N = Leash__Learning_pages
module B = Leash.Playbook
module Trace = Leash.Protocol.Trace

let ok = function Ok x -> x | Error why -> Alcotest.fail why
let check name value = Alcotest.(check bool) name true value

let fixture name =
  Yojson.Safe.from_file ("fixtures/learning-operations/" ^ name ^ ".json")
  |> Trace.t_of_yojson |> ok

let one trace =
  match O.segment trace with
  | [ op ] -> op
  | ops -> Alcotest.failf "expected one operation, got %d" (List.length ops)

let google_maps () =
  List.iter
    (fun revision ->
      let a = fixture (revision ^ "-maps-1") and b = fixture (revision ^ "-maps-2") in
      let x = one a and y = one b in
      check "map-op01 consent is not an operation"
        (x.entry_kind = "maps" && List.length x.steps = 2);
      check "map-op03 different paths and typed values agree"
        (a.page_kind_path <> b.page_kind_path && O.agrees x y);
      check "map-op01 delayed DONE observation is the result"
        (x.exit = Option.get a.final
        && (y.exit = Option.get b.final || y.exit_kind = "search-<slug>"));
      check "map-op01 DONE is not an action"
        (List.for_all (fun (s : Trace.trace_step) -> s.operation <> "done") x.steps);
      check "map-op05 first entry is post-consent"
        (Option.get (O.first_entry a) <> Option.get a.start_url);
      let projected = O.project a x in
      check "map-op04 projection retains raw keys"
        (x.entry_kind = "maps"
        && List.exists
             (fun (p : Trace.inferred_page) -> p.name = "place-<slug>")
             projected.inferred_pages);
      let evidence = N.observations [ projected ] |> Yojson.Safe.Util.to_list in
      let titles =
        List.concat_map
          (fun row ->
            Yojson.Safe.Util.(row |> member "titles" |> to_list |> List.map to_string))
          evidence
      in
      check "map-op04 delayed final title reaches naming"
        (List.mem (Option.get a.final).title titles))
    [ "google2"; "google3" ]

let page name = Trace.{ url = "https://example.com/" ^ name; title = name }

let synthetic () =
  let base = fixture "google3-maps-1" in
  let original =
    List.find (fun (s : Trace.trace_step) -> s.operation = "type_text") base.steps
  in
  let step n operation after target text source =
    { original with n; operation; after = page after; target; text; source }
  in
  let field = Some Trace.{ role = "combobox"; label = "Search" }
  and button = Some Trace.{ role = "button"; label = "Open" } in
  {
    base with
    site = "example.com";
    start_url = Some (page "a").url;
    page_kind_path = [ "a"; "b"; "c" ];
    inferred_pages =
      List.map
        (fun name -> Trace.{ name; url_pattern = (page name).url })
        [ "a"; "b"; "c" ];
    arguments = [ ("query", "needle"); ("unrelated", "not typed") ];
    steps =
      [
        step 1 "type_text" "a" field (Some "needle") "operator";
        step 2 "click" "b" button None "operator";
        step 3 "press_enter" "c" field None "planner";
        step 4 "done" "c" None None "operator";
      ];
    final = Some (page "c");
    procedures = [];
  }

let boundaries () =
  let trace = synthetic () in
  let ops = O.segment trace in
  check "map-op01 maximal per-entry operations"
    (List.map (fun (o : O.t) -> (o.entry_kind, o.exit_kind)) ops
    = [ ("a", "b"); ("b", "c") ]);
  let a = List.hd ops and b = List.nth ops 1 in
  check "map-op01 transition belongs to departing operation"
    (List.map (fun (s : Trace.trace_step) -> s.n) a.steps = [ 1; 2 ]
    && List.map (fun (s : Trace.trace_step) -> s.n) b.steps = [ 3 ]);
  check "map-op01 typed values and argument names retained"
    (a.arguments = [ (1, [ "query" ]) ] && (List.hd a.steps).text = Some "needle");
  check "map-op01 planner source retained" ((List.hd b.steps).source = "planner");
  let changed =
    {
      a with
      exit_kind = "other";
      steps =
        List.map
          (fun (s : Trace.trace_step) -> { s with text = Some "different" })
          a.steps;
    }
  in
  check "map-op03 exit and typed values are not agreement identity" (O.agrees a changed);
  let changed =
    {
      a with
      steps =
        List.map
          (fun (s : Trace.trace_step) ->
            { s with target = Some Trace.{ role = "link"; label = "Different" } })
          a.steps;
    }
  in
  check "map-op03 roles and labels remain exact" (not (O.agrees a changed));
  check "map-op01 unsuccessful traces do not segment"
    (O.segment { trace with outcome = "blocked" } = []);
  let legacy =
    {
      trace with
      steps = [];
      procedures =
        [
          Trace.
            {
              n = 1;
              procedure = "old";
              planned = true;
              steps = trace.steps;
              outcome = "done";
            };
        ];
    }
  in
  check "map-op01 legacy procedure steps still segment" (O.segment legacy = ops)

let interstitials () =
  let trace = synthetic () in
  let first = List.hd trace.steps in
  let before = { first with n = 0; operation = "click"; text = None } in
  let trace =
    {
      trace with
      start_url = Some (page "gate").url;
      steps = before :: trace.steps;
      inferred_pages =
        Trace.{ name = "gate"; url_pattern = (page "gate").url } :: trace.inferred_pages;
    }
  in
  check "map-op05 named same-host consent is excluded"
    (List.length (O.segment ~mapping:[ ("gate", "consent") ] trace) = 2);
  check "map-op05 named same-host consent entry is cleared"
    (O.first_entry ~mapping:[ ("gate", "consent") ] trace = Some (page "a").url);
  let foreign = { trace with start_url = Some "https://login.example.net/gate" } in
  check "map-op05 off-final-host operations are excluded"
    (List.length (O.segment foreign) = 2)

let book pages procedures =
  B.
    {
      site = "example.com";
      entry = (page "a").url;
      description = "example";
      pages;
      procedures;
      scripts = None;
      shapes = None;
    }

let declared name pattern =
  B.
    {
      name;
      description = name;
      url_pattern = Some pattern;
      text_marker = None;
      repeatable = true;
    }

let naming () =
  let seed = book [ declared "travel-<slug>" "https://example.com/travel/*" ] [] in
  let response name = `Assoc [ ("kinds", `Assoc [ ("travel-<slug>", `String name) ]) ] in
  check "map-op04 missing names rejected"
    (Result.is_error (N.name ~known:[] seed (`Assoc [])));
  List.iter
    (fun name ->
      check "map-op04 URL/placeholder names rejected"
        (Result.is_error (N.name ~known:[] seed (response name))))
    [ "m"; "unknown"; "travel-slug" ];
  let named, mapping = ok (N.name ~known:[] seed (response "flights-explore")) in
  check "map-op04 pattern is service-owned"
    ((List.hd named.pages).url_pattern = (List.hd seed.pages).url_pattern);
  check "map-op04 raw keys map durably to observed names"
    (List.assoc "travel-<slug>" mapping = "flights-explore");
  let renamed, _ = ok (N.name ~known:mapping seed (response "url-shaped")) in
  check "map-op04 existing names cannot be renamed"
    ((List.hd renamed.pages).name = "flights-explore")

let goals () =
  let goal = B.Goal { goal = "Inspect the page"; hint = None; until = None } in
  let proc =
    B.
      {
        slug = "child";
        description = "inspect";
        steps = [ goal ];
        expect = [ "the page is a" ];
        args = None;
        provenance = None;
        expect_timeout_s = None;
        repeat = None;
        max_steps = None;
        deadline_s = None;
      }
  in
  let seed = book [ declared "a" (page "a").url ] [ proc ] in
  check "map-op06 authored one-goal procedure remains valid"
    (Result.is_ok (B.of_json ~file:"authored" (B.yojson_of_t seed)));
  check "map-op06 learned top-level needs two goals"
    (Result.is_error (B.check_goal_count ~minimum:2 seed proc));
  let parent =
    {
      proc with
      slug = "parent";
      steps = [ B.Use { use = "child"; args = None; optional = None } ];
    }
  in
  check "map-op06 direct use exempts the child"
    (Result.is_ok
       (B.check_goal_count ~minimum:2 { seed with procedures = [ parent; proc ] } proc));
  let parent = { parent with steps = [ B.Navigate { script = "child"; args = None } ] } in
  check "map-op06 navigation is not a use exemption"
    (Result.is_error
       (B.check_goal_count ~minimum:2 { seed with procedures = [ parent; proc ] } proc));
  let provenance =
    B.
      {
        traces = [];
        model = "scripted";
        time = "now";
        tries = 0;
        last_failure = None;
        path = [ "a" ];
        entry_kind = "a";
        exit_kind = "a";
        signature = [];
        kind_mapping = [ ("a", "a") ];
        repeatable = true;
        reason = "inspect";
        gate = "draft";
        repair = false;
        model_calls = 0;
        model_cost = None;
      }
  in
  check "map-op06 shared loader rejects learned one-goal top level"
    (Result.is_error
       (B.of_json ~file:"learned"
          (B.yojson_of_t
             { seed with procedures = [ { proc with provenance = Some provenance } ] })));
  List.iter
    (fun n ->
      let trace = fixture ("google3-flights-" ^ n) in
      check "map-op06 real Explore is only one action, not useful proof"
        (List.length (one trace).steps <= 2))
    [ "1"; "2" ]

let () =
  Alcotest.run "learning operations"
    [
      ( "map-op01–map-op06",
        List.map
          (fun (name, run) -> Alcotest.test_case name `Quick run)
          [
            ("real Google Maps", google_maps);
            ("operation boundaries", boundaries);
            ("interstitials", interstitials);
            ("observed kind names", naming);
            ("goal minimum and Explore", goals);
          ] );
    ]
