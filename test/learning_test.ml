[@@@warning "-26"]

(* map-0by0 map-w62c map-cnee map-bjon map-6xcy map-6m3c map-2l5q
   map-tval map-rz4w map-yzqp map-wm4v map-nh2e map-itbt map-pd0q
   map-b3kk map-igfx map-2ga3 map-ptnk map-lnwr map-h5ym:
   fake compiler, durable evidence, temp XDG; no model or Chrome. *)
module L = Leash.Learning
module B = Leash.Playbook
module C = Leash.Config
module T = Leash.Traces
module P = Leash.Protocol
module Trace = P.Trace

let caps = Ox_test.powerbox ()
let ok = function Ok x -> x | Error why -> Alcotest.fail why
let bool name value = Alcotest.(check bool) name true value

let rec remove path =
  match Unix.lstat path with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  | st when st.Unix.st_kind = Unix.S_DIR ->
      Array.iter (fun name -> remove (Filename.concat path name)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path

let temp f =
  let dir = Filename.temp_file "leash-map-" "" in
  Unix.unlink dir;
  Unix.mkdir dir 0o700;
  let keys = [ "XDG_CONFIG_HOME"; "XDG_STATE_HOME" ] in
  let old = List.map (fun k -> (k, Sys.getenv_opt k)) keys in
  List.iter (fun key -> (Unix.putenv [@alert "-unsafe_multidomain"]) key dir) keys;
  Fun.protect
    ~finally:(fun () ->
      List.iter
        (fun (k, v) ->
          (Unix.putenv [@alert "-unsafe_multidomain"]) k (Option.value ~default:"" v))
        old;
      remove dir)
    (fun () -> f dir)

let snap () =
  P.
    {
      snapshot = ok (Snapshot_id.of_string "s_test");
      tab = ok (Handle.of_string "t_test");
      url = "https://example.com/catalog";
      title = "Catalog";
      page_kind = None;
      rows = [];
      total = 0;
      offset = 0;
      truncated = false;
      settled = true;
      source = Ax;
      reason = None;
      dialog = None;
    }

let result ?(status = "done") ?(procedures = []) () =
  P.
    {
      status = ok (Run_status.of_string status);
      site = Some "example.com";
      procedures;
      mission_expectations = [];
      playbook_choices = [];
      planner_turns = [];
      proposals = [];
      installed = [];
      collected = 0;
      data = `Null;
      answer = None;
      model_calls = 0;
      model_cost = Some 0.;
      operator_steps = [];
      operator_state = None;
      output_kinds = [];
      final = snap ();
      reason = None;
      trace_path = None;
      unattended = [];
      detail = None;
    }

let entry ?revision ?(attempts = 1) ?(outcome = "verified") slug =
  P.
    {
      revision;
      slug;
      site = "example.com";
      planned = false;
      attempts;
      choice = { key = slug; probabilities = `Assoc []; confidence = 1.; usage = None };
      drives = [];
      scripts = [];
      expectations =
        [
          {
            sentence = "the page is catalog";
            checker = "page_kind";
            passed = outcome = "verified";
            score = None;
          };
        ];
      outcome;
      elapsed_ms = 1;
      reason = None;
    }

let step ?text ?(operation = "click") ?(label = "View") () =
  Trace.
    {
      n = 1;
      non_repeatable = false;
      operation;
      source = "operator";
      error = None;
      target = Some { role = "button"; label };
      text;
      operations = [];
      targets = [];
      after = { url = "https://example.com/catalog"; title = "Catalog" };
      elapsed_ms = 1;
    }

let trace ?(kinds = [ "catalog" ]) ?(steps = [ step () ]) ?(outcome = "done") time =
  Trace.
    {
      unattended = [];
      version = 1;
      time = T.timestamp time;
      site = "example.com";
      mission = "inspect catalog";
      arguments = [];
      outcome;
      cost = Some 0.;
      duration_ms = 1;
      model_calls = 0;
      start_url = Some "https://example.com/catalog";
      page_kind_path = kinds;
      inferred_pages =
        [ { name = "catalog"; url_pattern = "https://example.com/catalog" } ];
      compiled = false;
      structural_outline = None;
      procedures = [];
      steps;
      final = Some { url = "https://example.com/catalog"; title = "Catalog" };
      error_code = None;
    }

let page ?(repeatable = true) () =
  B.
    {
      name = "catalog";
      description = "catalog";
      url_pattern = Some "https://example.com/catalog*";
      text_marker = None;
      repeatable;
    }

let procedure ?(slug = "inspect") ?(goal = "Click the button named View") ?(args = [])
    ?(until = [ "the page is catalog" ]) () =
  B.
    {
      slug;
      description = "inspect catalog";
      steps =
        [
          Goal { goal; hint = None; until = Some until };
          Goal { goal = "Observe the catalog page"; hint = None; until = None };
        ];
      expect = [ "the page is catalog"; "catalog entries are shown" ];
      args = Some args;
      provenance = None;
      expect_timeout_s = None;
      repeat = None;
      max_steps = None;
      deadline_s = None;
    }

let book ?(repeatable = true) proc =
  B.
    {
      site = "example.com";
      entry = "https://example.com/catalog";
      description = "catalog";
      pages = [ page ~repeatable () ];
      procedures = [ proc ];
      scripts = None;
      shapes = None;
    }

let answer ?(confirm = true) ?(kinds = [ ("catalog", "catalog") ]) proc =
  `Assoc
    [
      ("kinds", `Assoc (List.map (fun (key, name) -> (key, `String name)) kinds));
      ("procedure", B.yojson_of_procedure proc);
      ("confirm", `Bool confirm);
    ]

let install_authored ?(repeatable = true) proc =
  ignore
    (ok
       (B.accept ~caps
          (ok (B.propose ~book:(book ~repeatable proc) ~caps ~site:"example.com" proc))))

let save store trace = ok (T.write store trace)
let learning_switch = ref None

let learning_sw () =
  match !learning_switch with
  | Some sw -> sw
  | None -> Alcotest.fail "learning switch is not running"

let after learning store trace result =
  let file = save store trace in
  let replied = L.after_trace learning ~store ~file trace result in
  L.await_pending learning;
  (* map-w62c: once the work has finished, status says nothing is pending. *)
  (match L.status learning with
  | `Assoc fields ->
      Alcotest.(check bool)
        "map-w62c status pending is 0 after the work" true
        (List.assoc_opt "pending" fields = Some (`Int 0))
  | _ -> Alcotest.fail "status is an object");
  replied

let proposal_files () =
  let root = B.proposed_directory ~caps () in
  match Sys.readdir root with
  | exception Sys_error _ -> []
  | names ->
      Array.to_list names
      |> List.filter (fun name -> Filename.check_suffix name ".json")
      |> List.map (Filename.concat root)
      |> List.sort String.compare

let installed_slugs () =
  List.concat_map
    (fun (book : B.loaded) ->
      List.map (fun (proc : B.procedure) -> proc.slug) book.playbook.procedures)
    (ok (B.list ~caps ()))

let store root = T.create ~caps ~root:(Filename.concat root "evidence") ()
let configure mode = { C.default_learning with mode }
let drafts learning = L.drafts learning ~site:"example.com" ~kind:(Some "catalog")

let trial learning ?attempts ?outcome slug =
  entry ~revision:(List.hd (drafts learning)).revision ?attempts ?outcome slug

(* map-op08/map-op09: compiler source is observed, resolved and replay-gated. *)
let collection_compile_replay () =
  temp (fun root ->
      let calls = ref 0 in
      let proc =
        {
          (procedure ()) with
          steps = (procedure ()).steps @ [ B.Script { script = "collect"; args = None } ];
        }
      in
      let source =
        "/** returns: [{\"title\":\"string\",\"price\":\"string\"}] */\n\
         return Array.from(document.querySelectorAll('article.product_pod')).map(e => \
         ({title: e.querySelector('h3 a').textContent, price: \
         e.querySelector('.price_color').textContent}));"
      in
      let reply =
        match answer proc with
        | `Assoc fields ->
            `Assoc
              (( "scripts",
                 `Assoc
                   [
                     ( "collect",
                       `Assoc
                         [
                           ("source", `String source);
                           ( "description",
                             `String "Collect every title and price on the catalog page."
                           );
                           ("pages", `List [ `String "catalog" ]);
                         ] );
                   ] )
              :: fields)
        | _ -> assert false
      in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun input ->
            incr calls;
            let evidence = Yojson.Safe.Util.(input |> member "traces" |> to_list) in
            bool "map-op09 compiler receives final-page skeleton"
              (List.for_all
                 (fun t ->
                   Yojson.Safe.Util.(t |> member "structural_outline")
                   = `String "article.product_pod\n  h3\n    a\n  p.price_color\n")
                 evidence);
            Ok reply)
          ()
      in
      let store = store root in
      let trace n =
        {
          (trace n) with
          mission = "Collect every book title and price";
          structural_outline = Some "article.product_pod\n  h3\n    a\n  p.price_color\n";
        }
      in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      Alcotest.(check int) "map-op08 one compilation" 1 !calls;
      let draft = List.hd (drafts learning) in
      Alcotest.(check int)
        "map-op08 compiled script survives draft decoding" 1 (List.length draft.scripts);
      let file = List.hd (proposal_files ()) in
      bool "map-op08 manual acceptance cannot bypass script replay"
        (Result.is_error (B.accept ~caps file));
      ignore
        (after learning store (trace 3.)
           (result ~procedures:[ trial learning "draft:inspect" ] ()));
      bool "map-op08 unexecuted script blocks automatic installation"
        (installed_slugs () = []);
      let ran =
        P.
          {
            script = "collect";
            url = (snap ()).url;
            records = 1;
            bytes = 30;
            elapsed_ms = 1;
            error = None;
          }
      in
      let failed = { ran with error = Some "script-failed" } in
      let attempted = { (trial learning "draft:inspect") with scripts = [ failed ] } in
      ignore (after learning store (trace 4.) (result ~procedures:[ attempted ] ()));
      bool "map-op08 failed script blocks automatic installation" (installed_slugs () = []);
      let attempted =
        { (trial learning "draft:inspect") with scripts = [ ran ]; expectations = [] }
      in
      ignore (after learning store (trace 5.) (result ~procedures:[ attempted ] ()));
      bool "map-op08 empty expectation proof cannot install" (installed_slugs () = []);
      let attempted =
        {
          (trial learning "draft:inspect") with
          scripts = [ ran ];
          expectations = [ { (List.hd (entry "x").expectations) with passed = false } ];
        }
      in
      ignore (after learning store (trace 6.) (result ~procedures:[ attempted ] ()));
      bool "map-op08 failed check cannot install" (installed_slugs () = []);
      let attempted =
        {
          (trial learning "draft:inspect") with
          scripts = [ ran ];
          revision = Some "stale";
        }
      in
      ignore (after learning store (trace 7.) (result ~procedures:[ attempted ] ()));
      bool "map-op08 stale draft revision cannot install" (installed_slugs () = []);
      let attempted = { (trial learning "draft:other") with scripts = [ ran ] } in
      ignore (after learning store (trace 8.) (result ~procedures:[ attempted ] ()));
      bool "map-op08 another selected draft cannot install" (installed_slugs () = []);
      ignore (after learning store (trace 9.) (result ()));
      bool "map-op08 JEV declining the draft cannot install" (installed_slugs () = []);
      let attempted = { (trial learning "draft:inspect") with scripts = [ ran ] } in
      let installed =
        after learning store (trace 10.) (result ~procedures:[ attempted ] ())
      in
      bool "map-op08 selected draft, script and checks install"
        (installed_slugs () = [ "inspect" ]);
      let book = List.hd (ok (B.list ~caps ())) in
      bool "map-op08 installed script resolves and retains returns"
        (B.script_named book "collect" <> None))

let collection_compiler_refusals () =
  let valid = "/** returns: [{\"title\":\"string\"}] */ return [];" in
  List.iter
    (fun (name, source, collection, outline, non_repeatable, referenced) ->
      temp (fun root ->
          let proc =
            {
              (procedure ()) with
              steps =
                ((procedure ()).steps
                @
                if referenced then [ B.Script { script = "collect"; args = None } ]
                else []);
            }
          in
          let reply =
            match answer proc with
            | `Assoc fields ->
                `Assoc
                  (( "scripts",
                     `Assoc
                       [
                         ( "collect",
                           `Assoc
                             [
                               ("source", `String source);
                               ("description", `String "Collect catalog records.");
                             ] );
                       ] )
                  :: fields)
            | _ -> assert false
          in
          let learning =
            L.create ~sw:(learning_sw ()) ~caps
              ~config:{ (configure C.Learning_mode.Draft) with successes = 1 }
              ~planner:(fun _ -> Ok reply)
              ()
          in
          let trace =
            {
              (trace 1.) with
              mission = (if collection then "Collect every title" else "Open the catalog");
              structural_outline =
                (if outline then Some "article.product_pod\n" else None);
              steps = [ { (step ()) with non_repeatable } ];
            }
          in
          ignore (after learning (store root) trace (result ()));
          bool ("map-op08 rejects " ^ name) (drafts learning = [])))
    [
      ("missing returns", "return [];", true, true, false, true);
      ("network source", valid ^ " fetch('/api');", true, true, false, true);
      ("non-repeatable script", valid, true, true, true, true);
      ("unobserved outline", valid, true, false, false, true);
      ("non-collection script", valid, false, true, false, true);
      ("unexecuted declaration", valid, true, true, false, false);
    ]

let collection_keeps_authored_scripts () =
  temp (fun root ->
      let existing_source =
        "/** returns: [{\"title\":\"string\"}] */ return await fetch('/author-api');"
      in
      let authored =
        B.t_of_yojson
          (match B.yojson_of_t (book (procedure ~slug:"keep" ())) with
          | `Assoc fields ->
              `Assoc
                (( "scripts",
                   `Assoc
                     [
                       ( "authored",
                         `Assoc
                           [
                             ("source", `String existing_source);
                             ("description", `String "Authored endpoint reader.");
                           ] );
                     ] )
                :: List.remove_assoc "scripts" fields)
          | _ -> assert false)
        |> ok
      in
      let dir = Filename.concat (B.directory ~caps ()) "example.com" in
      ok (Leash.Config.ensure_dir ~caps dir);
      let out = open_out (Filename.concat dir "playbook.json") in
      Fun.protect
        ~finally:(fun () -> close_out out)
        (fun () -> Yojson.Safe.to_channel out (B.yojson_of_t authored));
      let proc =
        {
          (procedure ()) with
          steps = (procedure ()).steps @ [ B.Script { script = "collect"; args = None } ];
        }
      in
      let reply =
        match answer proc with
        | `Assoc fields ->
            `Assoc
              (( "scripts",
                 `Assoc
                   [
                     ( "collect",
                       `Assoc
                         [
                           ( "source",
                             `String "/** returns: [{\"title\":\"string\"}] */ return [];"
                           );
                           ("description", `String "Collect catalog records.");
                         ] );
                   ] )
              :: fields)
        | _ -> assert false
      in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:{ (configure C.Learning_mode.Auto) with successes = 1 }
          ~planner:(fun _ -> Ok reply)
          ()
      in
      let trace n =
        {
          (trace n) with
          mission = "Collect every title";
          structural_outline = Some "article.product_pod\n";
        }
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      let draft = List.hd (drafts learning) in
      bool "map-op08 unrelated authored source does not block collection compile"
        (List.map (fun (s : B.script) -> s.name) draft.scripts = [ "collect" ]);
      let attempted =
        {
          (trial learning "draft:inspect") with
          scripts =
            [
              P.
                {
                  script = "collect";
                  url = (snap ()).url;
                  records = 0;
                  bytes = 2;
                  elapsed_ms = 1;
                  error = None;
                };
            ];
        }
      in
      ignore (after learning store (trace 2.) (result ~procedures:[ attempted ] ()));
      let installed = List.hd (ok (B.list ~caps ())) in
      bool "map-op08 authored declaration retained on merge"
        (Option.map (fun (s : B.script) -> s.code) (B.script_named installed "authored")
        = Some existing_source);
      bool "map-op08 new script installs beside authored one"
        (B.script_named installed "collect" <> None))

let defaults () =
  Alcotest.(check int) "map-w62c successes" 2 C.default.learning.successes;
  Alcotest.(check int) "learning timeout default" 900 C.default.learning.timeout_s;
  Alcotest.(check string)
    "map-0by0 draft default" "draft"
    (C.Learning_mode.to_string C.default.learning.mode);
  List.iter
    (fun field ->
      bool "map-0by0 rejected invalid config"
        (Result.is_error (C.t_of_yojson (`Assoc [ ("learning", `Assoc [ field ]) ]))))
    [
      ("mode", `String "unsafe");
      ("successes", `Int 0);
      ("max_tries", `Int 0);
      ("retire_after", `Int (-1));
      ("planner_actions", `Int 21);
      ("timeout_s", `Int 59);
      ("timeout_s", `Int 3601);
    ]

let pure () =
  Alcotest.(check (list string))
    "map-cnee normalize kinds" [ "catalog"; "detail" ]
    (L.path [ "unknown"; "catalog"; "catalog"; ""; "detail" ]);
  Alcotest.(check (list string))
    "map-cnee revisits collapse to first visit" [ "catalog"; "detail" ]
    (L.path [ "catalog"; "detail"; "catalog"; "detail" ]);
  bool "map-nh2e typed values may differ"
    (L.agreement
       [
         trace ~steps:[ step ~text:"one" () ] 1.; trace ~steps:[ step ~text:"two" () ] 2.;
       ]);
  bool "map-nh2e labels must agree"
    (not (L.agreement [ trace 1.; trace ~steps:[ step ~label:"Delete" () ] 2. ]));
  bool "map-nh2e configured one-trace threshold can agree" (L.agreement [ trace 1. ]);
  bool "map-yzqp normal catalog repeatable" (fst (L.classify [ page () ] [ trace 1. ]));
  bool "map-wm4v authored false wins"
    (not (fst (L.classify [ page ~repeatable:false () ] [ trace 1. ])));
  bool "map-yzqp target delete prevents replay"
    (not (fst (L.classify [] [ trace ~steps:[ step ~label:"Delete" () ] 1. ])))

let draft_compile () =
  temp (fun root ->
      let calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ ->
            incr calls;
            Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      Alcotest.(check int) "map-w62c wait for threshold" 0 !calls;
      let r =
        after learning store (trace ~kinds:[ "catalog"; "catalog" ] 2.) (result ())
      in
      Alcotest.(check int) "map-bjon compile once" 1 !calls;
      Alcotest.(check int) "map-6m3c proposal written" 1 (List.length (proposal_files ()));
      bool "map-tval draft does not install"
        (installed_slugs () = [] && ok (B.list ~caps ()) = []);
      bool "map-6m3c private proposal"
        ((Unix.stat (List.hd (proposal_files ()))).st_perm = 0o600);
      bool "map-tval draft does not offer" (drafts learning = []);
      let proposed =
        ok
          (B.of_json
             ~file:(List.hd (proposal_files ()))
             (Yojson.Safe.from_file (List.hd (proposal_files ()))))
      in
      let p = Option.get (List.hd proposed.playbook.procedures).provenance in
      bool "map-2l5q durable provenance"
        (List.length p.traces = 2 && p.gate = "replay" && p.repeatable && p.tries = 0);
      bool "map-6m3c inferred pages persisted"
        (List.map (fun (p : B.page) -> p.name) proposed.playbook.pages = [ "catalog" ]);
      bool "map-bjon evidence marked compiled"
        (List.for_all (fun file -> (ok (T.read ~caps file)).compiled) p.traces))

let validation () =
  temp (fun root ->
      let calls = ref 0 and retry = ref false in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun request ->
            incr calls;
            if !calls = 1 then Ok (answer (procedure ~goal:"type {missing}" ()))
            else (
              retry := Yojson.Safe.Util.member "validation_errors" request <> `String "";
              Ok (answer (procedure ()))))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      let _ = after learning store (trace 2.) (result ()) in
      bool "map-rz4w exactly one validation retry"
        (!calls = 2 && !retry && List.length (proposal_files ()) = 1))

let parameters () =
  temp (fun root ->
      let warnings = ref [] and calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~warn:(fun s -> warnings := s :: !warnings)
          ~planner:(fun _ ->
            incr calls;
            Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace ~steps:[ step ~text:"one" () ] 1.) (result ()));
      let r =
        after learning store (trace ~steps:[ step ~text:"two" () ] 2.) (result ())
      in
      bool "map-6xcy refuse unparameterized values after bounded retry"
        (!calls = 2 && proposal_files () = [] && !warnings <> []))

let replay () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      bool "map-b3kk same first kind offers" (List.length (drafts learning) = 1);
      bool "map-b3kk other kind never offers"
        (L.drafts learning ~site:"example.com" ~kind:(Some "detail") = []);
      bool "map-b3kk temporary new book"
        (List.length (L.books learning []) = 1
        && (List.hd (L.books learning [])).playbook.procedures = []);
      let r =
        after learning store (trace ~outcome:"blocked" 3.)
          (result ~status:"blocked" ~procedures:[ trial learning "draft:inspect" ] ())
      in
      bool "map-igfx verified but unfinished cannot install" (installed_slugs () = []);
      let r =
        after learning store (trace 4.)
          (result ~procedures:[ trial learning "draft:inspect" ] ())
      in
      bool "map-igfx done replay installs without third submission"
        (installed_slugs () = [ "inspect" ] && drafts learning = []);
      let installed = List.hd (ok (B.list ~caps ())) in
      bool "map-2ga3 install remembers gate"
        ((Option.get (List.hd installed.playbook.procedures).provenance).gate = "replay"))

let tries () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      for i = 1 to 3 do
        ignore
          (after learning store
             (trace ~outcome:"blocked" (float (i + 2)))
             (result ~status:"blocked"
                ~procedures:[ trial learning ~outcome:"failed" "draft:inspect" ]
                ()))
      done;
      bool "map-pd0q max three failed tries" (drafts learning = []);
      bool "map-pd0q drop does not install" (ok (B.list ~caps ()) = []);
      let retired = Filename.concat (B.proposed_directory ~caps ()) "retired" in
      bool "map-pd0q failed evidence retained"
        (Sys.file_exists retired && Array.length (Sys.readdir retired) = 1))

let agreement_gate () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            Ok (answer (procedure ~goal:"Click the button named Delete" ())))
          ()
      in
      let store = store root and steps = [ step ~label:"Delete" () ] in
      ignore (after learning store (trace ~steps 1.) (result ()));
      let _ = after learning store (trace ~steps 2.) (result ()) in
      bool "map-itbt agreement installs with no trial"
        (installed_slugs () = [ "inspect" ] && drafts learning = []);
      let b = List.hd (ok (B.list ~caps ())) in
      let p = Option.get (List.hd b.playbook.procedures).provenance in
      bool "map-2ga3 agreement provenance" (p.gate = "agreement" && not p.repeatable))

let repair () =
  temp (fun root ->
      install_authored (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            Ok
              (answer
                 (procedure ~slug:"wrong-name" ~goal:"Click the button named Updated" ())))
          ()
      in
      let store = store root in
      ignore
        (after learning store (trace ~outcome:"blocked" 1.)
           (result ~status:"blocked"
              ~procedures:[ entry ~attempts:2 ~outcome:"failed" "inspect" ]
              ()));
      let p = (List.hd (drafts learning)).procedure in
      bool "map-ptnk repair keeps slug and waits"
        (p.slug = "inspect" && (Option.get p.provenance).repair);
      let unchanged =
        after learning store (trace 1.5) (result ~procedures:[ entry "inspect" ] ())
      in
      bool "map-pd0q original success cannot bypass repair trial"
        (drafts learning <> []
        && (List.hd (List.hd (ok (B.list ~caps ()))).playbook.procedures).provenance
           = None);
      let r =
        after learning store (trace 2.)
          (result ~procedures:[ trial learning "draft:inspect" ] ())
      in
      bool "map-lnwr verified repair replaces"
        (installed_slugs () = [ "inspect" ] && drafts learning = []);
      let b = List.hd (ok (B.list ~caps ())) in
      bool "map-lnwr old procedure archived"
        (Array.length
           (Sys.readdir (Filename.concat (B.proposed_directory ~caps ()) "retired"))
        = 1);
      bool "map-lnwr replacement readable"
        (match (List.hd b.playbook.procedures).steps with
        | B.Goal g :: _ -> g.goal = "Click the button named Updated"
        | _ -> false))

let retire () =
  temp (fun root ->
      install_authored (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Error "no repair")
          ()
      in
      let store = store root in
      for i = 1 to 5 do
        ignore
          (after learning store
             (trace ~outcome:"blocked" (float i))
             (result ~status:"blocked"
                ~procedures:[ entry ~outcome:"failed" "inspect" ]
                ()))
      done;
      bool "map-h5ym retired procedure excluded"
        ((List.hd (ok (B.list ~caps ()))).playbook.procedures = []);
      bool "map-h5ym retirement archived"
        (Array.length
           (Sys.readdir (Filename.concat (B.proposed_directory ~caps ()) "retired"))
        = 1))

let off () =
  temp (fun root ->
      let called = ref false in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Off)
          ~planner:(fun _ ->
            called := true;
            Error "must not call")
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      bool "map-0by0 off neither compiles nor persists proposals"
        ((not !called) && not (Sys.file_exists (B.proposed_directory ~caps ()))))

let permanent_invalid () =
  temp (fun root ->
      let count = ref 0 and warnings = ref [] in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ ->
            incr count;
            Ok (answer (procedure ~goal:"Click the button {missing}" ())))
          ~warn:(fun why -> warnings := why :: !warnings)
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      let _ = after learning store (trace 2.) (result ()) in
      bool "map-6xcy two invalid drafts dropped with reason"
        (!count = 2 && proposal_files () = [] && !warnings <> []))

let confirmation () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            Ok
              (answer ~confirm:false
                 (procedure ~goal:"Click the button named Checkout" ())))
          ()
      in
      let store = store root in
      let risky n = trace ~steps:[ step ~label:"Checkout" () ] n in
      ignore (after learning store (risky 1.) (result ()));
      let _ = after learning store (risky 2.) (result ()) in
      bool "map-nh2e no confirmation means no installation"
        (installed_slugs () = [] && proposal_files () = [] && ok (B.list ~caps ()) = []))

let nonrepeatable_repair () =
  temp (fun root ->
      install_authored ~repeatable:false (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            Ok (answer (procedure ~goal:"Click the button named View" ())))
          ()
      in
      let snap =
        P.
          {
            (snap ()) with
            rows =
              [
                {
                  index = 1;
                  role = "button";
                  name = "View";
                  value = None;
                  state = None;
                  options = None;
                };
              ];
            total = 1;
          }
      in
      let r =
        after learning (store root) (trace ~outcome:"blocked" 1.)
          {
            (result ~status:"blocked"
               ~procedures:[ entry ~attempts:2 ~outcome:"failed" "inspect" ]
               ())
            with
            P.final = snap;
          }
      in
      let proc = List.hd (List.hd (ok (B.list ~caps ()))).playbook.procedures in
      bool "map-itbt observed non-repeatable repair installs without replay"
        (installed_slugs () = [ "inspect" ]
        && (Option.get proc.provenance).gate = "agreement-repair"))

let unsafe_repair () =
  temp (fun root ->
      install_authored ~repeatable:false (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            Ok (answer (procedure ~goal:"Click the button named Absent" ())))
          ()
      in
      let r =
        after learning (store root) (trace ~outcome:"blocked" 1.)
          (result ~status:"blocked"
             ~procedures:[ entry ~attempts:2 ~outcome:"failed" "inspect" ]
             ())
      in
      let repaired =
        List.exists
          (fun file ->
            match
              (List.hd
                 (ok (B.of_json ~file (Yojson.Safe.from_file file))).playbook.procedures)
                .provenance
            with
            | Some p -> p.repair
            | None -> false)
          (proposal_files ())
      in
      let kept = List.hd (List.hd (ok (B.list ~caps ()))).playbook.procedures in
      bool "map-itbt unknown target cannot pass by naming the kind"
        ((not repaired) && kept.provenance = None))

let resets () =
  temp (fun root ->
      install_authored (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Error "no repair")
          ()
      in
      let store = store root in
      let fail n =
        ignore
          (after learning store (trace ~outcome:"blocked" n)
             (result ~status:"blocked"
                ~procedures:[ entry ~outcome:"failed" "inspect" ]
                ()))
      in
      fail 1.;
      fail 2.;
      fail 3.;
      fail 4.;
      ignore (after learning store (trace 5.) (result ~procedures:[ entry "inspect" ] ()));
      fail 6.;
      fail 7.;
      fail 8.;
      fail 9.;
      bool "map-b3kk verified installed mission resets consecutive retirement counter"
        ((List.hd (ok (B.list ~caps ()))).playbook.procedures <> []))

let status_gates () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      ignore
        (after learning store (trace 3.)
           (result ~procedures:[ trial learning "draft:inspect" ] ()));
      let member = Yojson.Safe.Util.member in
      let site =
        match member "sites" (L.status learning) with
        | `List [ site ] -> site
        | _ -> Alcotest.fail "missing site status"
      in
      bool "map-b3kk installed replay counted"
        (member "installed_by_replay" site = `Int 1
        && member "installed_by_agreement" site = `Int 0
        && member "last_compile" site <> `Null))

let legacy_trace () =
  let json =
    match Trace.yojson_of_t (trace 1.) with
    | `Assoc fields -> `Assoc (List.filter (fun (k, _) -> k <> "start_url") fields)
    | _ -> assert false
  in
  bool "map-cnee legacy durable trace lacks optional entry URL"
    ((ok (Trace.t_of_yojson json)).start_url = None)

let navigation_until () =
  temp (fun root ->
      let proc = { (procedure ()) with B.expect = [ "the page is detail" ] } in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ -> Ok (answer proc))
          ()
      in
      let navigated n =
        let t = trace ~kinds:[ "catalog"; "detail" ] n in
        {
          t with
          Trace.steps =
            [
              {
                (step ~operation:"nav" ()) with
                after = { url = "https://example.com/detail"; title = "Detail" };
              };
            ];
          inferred_pages =
            t.inferred_pages
            @ [ { name = "detail"; url_pattern = "https://example.com/detail" } ];
        }
      in
      let store = store root in
      ignore (after learning store (navigated 1.) (result ()));
      let _ = after learning store (navigated 2.) (result ()) in
      bool "map-bjon navigation requires per-step until, not global expect"
        (proposal_files () = []))

let constant_argument () =
  temp (fun root ->
      let proc =
        procedure ~goal:"Type {query} in the button named View"
          ~args:[ B.{ name = "query"; source = Const (`String "one") } ]
          ()
      in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ -> Ok (answer proc))
          ()
      in
      let store = store root in
      ignore (after learning store (trace ~steps:[ step ~text:"one" () ] 1.) (result ()));
      let r =
        after learning store (trace ~steps:[ step ~text:"two" () ] 2.) (result ())
      in
      bool "map-bjon differing evidence needs mission argument, not a constant"
        (proposal_files () = []))

let authored_mode () =
  temp (fun root ->
      install_authored (procedure ());
      let loaded = List.hd (ok (B.list ~caps ())) in
      Unix.chmod loaded.file 0o640;
      let file =
        ok
          (B.propose ~caps ~site:"example.com"
             (procedure ~goal:"Click the button named Updated" ()))
      in
      ignore (ok (B.accept ~caps file));
      bool "map-lnwr atomic replacement preserves authored permissions"
        ((Unix.stat loaded.file).st_perm = 0o640);
      ignore root)

let mission_counter () =
  temp (fun root ->
      install_authored (procedure ());
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ -> Error "no repair")
          ()
      in
      let store = store root in
      for i = 1 to 3 do
        ignore
          (after learning store
             (trace ~outcome:"blocked" (float i))
             (result ~status:"blocked"
                ~procedures:
                  [ entry ~outcome:"failed" "inspect"; entry ~outcome:"failed" "inspect" ]
                ()))
      done;
      bool "map-h5ym two attempts in one mission count only one retirement failure"
        ((List.hd (ok (B.list ~caps ()))).playbook.procedures <> []))

let stale_trial_revision () =
  temp (fun root ->
      let calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            incr calls;
            Ok
              (answer
                 (procedure
                    ~goal:
                      (if !calls = 1 then "Click the button named View"
                       else "Click the button named New")
                    ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      let old = trial learning "draft:inspect" in
      let newer =
        after learning store (trace ~outcome:"blocked" 3.)
          (result ~status:"blocked" ~procedures:[ { old with P.outcome = "failed" } ] ())
      in
      let current = List.hd (drafts learning) in
      bool "map-w62c failed trial recompiled a distinct revision"
        (Some current.revision <> old.revision);
      ignore (after learning store (trace 4.) (result ~procedures:[ old ] ()));
      bool "map-w62c stale successful trial cannot install" (ok (B.list ~caps ()) = []);
      bool "map-w62c stale trial cannot alter a new revision"
        ((List.hd (drafts learning)).revision = current.revision);
      ignore
        (after learning store
           (trace ~outcome:"blocked" 4.5)
           (result ~status:"blocked" ~procedures:[ { old with P.outcome = "failed" } ] ()));
      bool "map-w62c stale failure cannot consume new tries"
        ((List.hd (drafts learning)).revision = current.revision);
      (match
         B.accept ~revision:(Option.get old.revision) ~caps (List.hd (proposal_files ()))
       with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "map-w62c locked installer accepted stale revision");
      let installed =
        after learning store (trace 5.)
          (result ~procedures:[ trial learning "draft:inspect" ] ())
      in
      bool "map-w62c exact current revision installs" (installed_slugs () = [ "inspect" ]))

let agreement_all_targets () =
  List.iter
    (fun (compound, duplicate) ->
      temp (fun root ->
          let authored = book ~repeatable:false (procedure ()) in
          let file = root ^ "/authored.json" in
          ok (B.atomic_write_json ~caps ~mode:0o600 file (B.yojson_of_t authored));
          ignore (ok (B.accept ~caps file));
          let valid = procedure ~goal:"Click the button named View" () in
          let candidate =
            if compound then
              procedure
                ~goal:"Click the button named View and then click the button named Absent"
                ()
            else
              {
                valid with
                B.steps =
                  valid.steps
                  @ [
                      B.Goal
                        {
                          goal = "Click the button named Absent";
                          hint = None;
                          until = Some [ "the page is catalog" ];
                        };
                    ];
              }
          in
          let learning =
            L.create ~sw:(learning_sw ()) ~caps
              ~config:(configure C.Learning_mode.Auto)
              ~planner:(fun _ -> Ok (answer candidate))
              ()
          in
          let row =
            P.
              {
                index = 1;
                role = "button";
                name = "View";
                value = None;
                state = None;
                options = None;
              }
          in
          let final =
            {
              (snap ()) with
              P.rows = (if duplicate then [ row; { row with index = 2 } ] else [ row ]);
            }
          in
          let r =
            after learning (store root) (trace ~outcome:"blocked" 1.)
              {
                (result ~status:"blocked"
                   ~procedures:[ entry ~outcome:"failed" "inspect" ]
                   ())
                with
                P.final;
              }
          in
          let kept = List.hd (List.hd (ok (B.list ~caps ()))).playbook.procedures in
          bool "map-itbt every required exact target must agree" (kept.provenance = None);
          bool "map-itbt uncertain compound goals fail closed" (drafts learning = [])))
    [ (false, false); (true, false); (true, true) ]

let bounded_risk_agreement () =
  List.iter
    (fun (pinned, previously_repeatable) ->
      temp (fun root ->
          let old =
            {
              (procedure ()) with
              B.provenance =
                Some
                  B.
                    {
                      traces = [];
                      entry_kind = "";
                      exit_kind = "";
                      signature = [];
                      kind_mapping = [];
                      path = [ "catalog" ];
                      model = "test";
                      time = "earlier";
                      repeatable = previously_repeatable;
                      reason = "earlier classified trial";
                      tries = 0;
                      last_failure = None;
                      gate = "replay";
                      repair = false;
                      model_calls = 0;
                      model_cost = None;
                    };
            }
          in
          ignore
            (ok
               (B.accept ~consume:true ~caps
                  (ok
                     (B.propose
                        ~book:(book ~repeatable:(not pinned) old)
                        ~caps ~site:"example.com" old))));
          let learning =
            L.create ~sw:(learning_sw ()) ~caps
              ~config:(configure C.Learning_mode.Auto)
              ~planner:(fun _ ->
                Ok (answer (procedure ~goal:"Click the button named View" ())))
              ()
          in
          let trace =
            trace ~outcome:"blocked"
              ~steps:
                [
                  {
                    (step ()) with
                    Trace.non_repeatable = (not pinned) && previously_repeatable;
                  };
                ]
              1.
          in
          let row =
            P.
              {
                index = 1;
                role = "button";
                name = "View";
                value = None;
                state = None;
                options = None;
              }
          in
          let final = { (snap ()) with P.rows = [ row ]; title = "Settings" } in
          let r =
            after learning (store root) trace
              {
                (result ~status:"blocked"
                   ~procedures:
                     [
                       entry
                         ~attempts:(if previously_repeatable then 1 else 2)
                         ~outcome:"failed" "inspect";
                     ]
                   ())
                with
                P.final;
              }
          in
          bool "map-yzqp pre-action risk does not become a replay draft"
            (drafts learning = []);
          bool "map-itbt one unsafe failure may repair by snapshot agreement"
            (installed_slugs () = [ "inspect" ]);
          let proc = List.hd (List.hd (ok (B.list ~caps ()))).playbook.procedures in
          match proc.provenance with
          | Some p ->
              bool "map-yzqp bounded bit remains authoritative"
                ((not p.repeatable) && p.gate = "agreement-repair")
          | None -> Alcotest.fail "map-yzqp repaired provenance missing"))
    [ (true, true); (false, true); (false, false) ]

let inferred_navigation_patterns () =
  temp (fun root ->
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun request ->
            let parsed =
              ok
                (B.t_of_yojson
                   (match request with
                   | `Assoc fields -> List.assoc "playbook" fields
                   | _ -> assert false))
            in
            bool "map-bjon inferred declared patterns are executable"
              (List.for_all
                 (fun (p : B.page) ->
                   not (String.contains (Option.get p.url_pattern) '<'))
                 parsed.pages);
            Ok
              (answer
                 ~kinds:[ ("home", "home"); ("books-<slug>", "books-category") ]
                 {
                   (procedure ~goal:"Click the link named Mystery"
                      ~until:[ "the page is books-category" ]
                      ())
                   with
                   B.expect = [ "the page is books-category"; "book prices are shown" ];
                 }))
          ()
      in
      let make time =
        let t = trace ~kinds:[ "home"; "books-<slug>" ] time in
        {
          t with
          Trace.start_url = Some "https://example.com/";
          inferred_pages =
            [
              { name = "home"; url_pattern = "https://example.com/" };
              {
                name = "books-<slug>";
                url_pattern =
                  "https://example.com/catalogue/category/books/<slug>/index.html";
              };
            ];
          steps =
            [
              {
                (step ()) with
                Trace.after =
                  {
                    url =
                      "https://example.com/catalogue/category/books/mystery_3/index.html?sort=title#books";
                    title = "Mystery";
                  };
              };
            ];
        }
      in
      let store = store root in
      ignore (after learning store (make 1.) (result ()));
      let _ = after learning store (make 2.) (result ()) in
      bool "map-bjon real books navigation validates without weakening until"
        (proposal_files () <> []);
      bool "map-bjon compiler produces a replay draft"
        (L.drafts learning ~site:"example.com" ~kind:(Some "home") <> []))

(* map-2l5q map-b3kk: isolated processes share complete JSON and one install transaction. *)
let atomic_and_cross_process_install () =
  temp (fun dir ->
      let p = procedure () in
      let first = book p in
      let file = ok (B.propose ~caps ~book:first ~site:first.site p) in
      let old_revision = B.draft_revision first in
      let newer = { p with B.description = "replacement revision" } in
      let replacement = book newer in
      ignore (ok (B.propose ~caps ~book:replacement ~site:first.site newer));
      (match B.propose ~revision:old_revision ~caps ~book:first ~site:first.site p with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "stale failure rewrote replacement");
      (match B.archive_proposal ~revision:old_revision ~caps file with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "stale retirement archived replacement");
      Alcotest.(check bool) "replacement remains" true (Sys.file_exists file);
      Alcotest.(check bool)
        "proposals never create an authored map directory" false
        (Sys.file_exists (B.directory ~caps ()));
      ignore (ok (C.ensure_dir ~caps (B.directory ~caps ())));
      let lock =
        Unix.openfile
          (Filename.concat (B.directory ~caps ()) ".install.lock")
          [ Unix.O_CREAT; Unix.O_WRONLY ]
          0o600
      in
      let child fn =
        match Unix.fork () with 0 -> Unix._exit (try fn () with _ -> 3) | pid -> pid
      in
      let rec wait pid =
        try snd (Unix.waitpid [] pid)
        with Unix.Unix_error (Unix.EINTR, _, _) -> wait pid
      in
      let finished label pid =
        match wait pid with Unix.WEXITED 0 -> () | _ -> Alcotest.fail label
      in
      Unix.lockf lock Unix.F_TLOCK 0;
      Fun.protect
        ~finally:(fun () ->
          Unix.lockf lock Unix.F_ULOCK 0;
          Unix.close lock)
        (fun () ->
          let pid =
            child (fun () ->
                match B.accept ~caps file with
                | Error why
                  when String.starts_with ~prefix:"playbook installation is busy" why ->
                    0
                | _ -> 2)
          in
          finished "another process bypassed the install lock" pid);
      ignore
        (ok (B.accept ~revision:(B.draft_revision replacement) ~consume:true ~caps file));
      Alcotest.(check bool)
        "accepted revision consumed under lock" false (Sys.file_exists file);
      let other = procedure ~slug:"other" () in
      let other_file = ok (B.propose ~caps ~book:(book other) ~site:first.site other) in
      ignore (ok (B.accept ~caps other_file));
      let installed = List.hd (ok (B.list ~caps ())) in
      Alcotest.(check int)
        "serialized merges retain both procedures" 2
        (List.length installed.playbook.procedures);
      let other_revision = B.draft_revision (book other) in
      let changed = { other with B.description = "new repair candidate" } in
      ignore (ok (B.propose ~caps ~book:(book changed) ~site:first.site changed));
      (match
         B.retire_draft ~file:other_file ~revision:other_revision ~caps ~site:first.site
           ~slug:other.slug
       with
      | Error _ -> ()
      | Ok () -> Alcotest.fail "stale failure retired an installed procedure");
      let installed = List.hd (ok (B.list ~caps ())) in
      Alcotest.(check int)
        "stale retirement leaves installed map unchanged" 2
        (List.length installed.playbook.procedures);
      let target = Filename.concat dir "atomic.json" in
      let payload worker =
        `Assoc [ ("worker", `Int worker); ("body", `String (String.make 32768 'x')) ]
      in
      ignore (ok (B.atomic_write_json ~caps ~mode:0o600 target (payload 0)));
      let spawn worker =
        child (fun () ->
            for _ = 1 to 20 do
              match B.atomic_write_json ~caps ~mode:0o600 target (payload worker) with
              | Ok () -> ()
              | Error _ -> raise Exit
            done;
            0)
      in
      let left = spawn 1 and right = spawn 2 in
      let statuses = ref [] in
      Fun.protect
        ~finally:(fun () -> statuses := List.map wait [ left; right ])
        (fun () ->
          for _ = 1 to 40 do
            let json = Yojson.Safe.from_file target in
            Alcotest.(check int)
              "atomic readers see a complete document" 32768
              Yojson.Safe.Util.(json |> member "body" |> to_string |> String.length)
          done);
      List.iter
        (function Unix.WEXITED 0 -> () | _ -> Alcotest.fail "atomic writer failed")
        !statuses;
      Alcotest.(check int)
        "private atomic file" 0o600
        ((Unix.stat target).st_perm land 0o777);
      Alcotest.(check bool)
        "unique temporary files cleaned up" false
        (Array.exists (String.ends_with ~suffix:".tmp") (Sys.readdir dir)))

let bounded_provider_metadata () =
  let raw =
    `Assoc
      [
        ( "choices",
          `List
            [
              `Assoc
                [
                  ("finish_reason", `String "length");
                  ( "message",
                    `Assoc [ ("content", `Null); ("reasoning", `String "SECRET-PRIVATE") ]
                  );
                ];
            ] );
        ( "usage",
          `Assoc
            [
              ("prompt_tokens", `Int 17);
              ("completion_tokens", `Int 4096);
              ("total_tokens", `Int 4113);
              ("cost", `Float 0.2);
              ("completion_tokens_details", `Assoc [ ("reasoning_tokens", `Int 4096) ]);
            ] );
        ("private", `String (String.make 10000 'S'));
      ]
  in
  let metadata = Leash__Planner.learning_response_metadata raw in
  let fields = match metadata with `Assoc fields -> fields | _ -> assert false in
  bool "map-ptnk null diagnostics retain finish reason"
    (List.assoc "finish_reason" fields = `String "length");
  bool "map-ptnk null diagnostics retain billed cost"
    (List.assoc "cost" fields = `Float 0.2);
  let encoded = Yojson.Safe.to_string metadata in
  bool "map-ptnk diagnostics never preserve raw response or reasoning"
    ((not (String.contains encoded 'S')) && String.length encoded < 400)

let learning_cost_accounting () =
  List.iter
    (fun reported ->
      temp (fun root ->
          let calls = ref 0 in
          let learning =
            L.create ~sw:(learning_sw ()) ~caps
              ~config:(configure C.Learning_mode.Auto)
              ~planner:(fun _ ->
                incr calls;
                Leash__Model_usage.start "planner";
                Leash__Model_usage.report "planner" reported;
                Ok
                  (answer
                     (procedure
                        ~until:
                          (if !calls = 1 then [ "unsupported" ]
                           else [ "the page is catalog" ])
                        ())))
              ()
          in
          let store = store root in
          ignore (after learning store (trace 1.) (result ()));
          let current = trace 2. in
          let file = save store current in
          let r =
            L.after_trace learning ~store ~file current
              { (result ()) with P.model_calls = 3; model_cost = Some 0.5 }
          in
          L.await_pending learning;
          let durable = ok (Trace.t_of_yojson (Yojson.Safe.from_file file)) in
          let learning_cost = Option.map (fun cost -> 2. *. cost) reported in
          Alcotest.(check int) "reply does not wait for learning calls" 3 r.model_calls;
          Alcotest.(check (option (float 0.000001)))
            "reply does not fold learning cost" (Some 0.5) r.model_cost;
          Alcotest.(check int) "durable trace keeps its own calls" 0 durable.model_calls;
          Alcotest.(check (option (float 0.000001)))
            "durable trace keeps its own cost" (Some 0.) durable.cost;
          Alcotest.(check bool)
            "map-ptnk compiled marker is preserved" true durable.compiled;
          let proposed =
            ok
              (B.of_json
                 ~file:(List.hd (proposal_files ()))
                 (Yojson.Safe.from_file (List.hd (proposal_files ()))))
          in
          let provenance = Option.get (List.hd proposed.playbook.procedures).provenance in
          Alcotest.(check int)
            "provenance counts compiler and validation retry" 2 provenance.model_calls;
          Alcotest.(check (option (float 0.000001)))
            "unknown learning cost stays unknown" learning_cost provenance.model_cost;
          let site =
            match Yojson.Safe.Util.member "sites" (L.status learning) with
            | `List (site :: _) -> site
            | _ -> Alcotest.fail "status omitted the site"
          in
          Alcotest.(check int)
            "status counts learning calls" 2
            (Yojson.Safe.Util.to_int (Yojson.Safe.Util.member "learning_calls" site));
          Alcotest.(check (option (float 0.000001)))
            "status records learning cost" learning_cost
            (match Yojson.Safe.Util.member "learning_cost" site with
            | `Null -> None
            | `Float value -> Some value
            | `Int value -> Some (float_of_int value)
            | other -> Alcotest.fail (Yojson.Safe.to_string other))))
    [ Some 0.2; None ]

(* map-cnee map-ngyr: the two Google Maps done traces from the 2026-10-02 live
   gate. The stored paths stay as recorded; the matching path drops the consent
   host and collapses the search/place revisits. *)
(* map-cnee: Flights live (google3) — a learned procedure verified from another entry
   page must not trigger a second compile. *)
let covered_by_use () =
  temp (fun root ->
      let calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun _ ->
            incr calls;
            Ok (answer (procedure ())))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      ignore (after learning store (trace 2.) (result ()));
      ignore
        (after learning store (trace 3.)
           (result ~procedures:[ trial learning "draft:inspect" ] ()));
      bool "map-cnee the draft installed" (installed_slugs () = [ "inspect" ]);
      let compiled = !calls in
      let used time =
        {
          (trace ~kinds:[ "home"; "catalog" ] time) with
          Trace.procedures =
            [
              {
                n = 1;
                procedure = "inspect";
                outcome = "verified";
                planned = false;
                steps = [];
              };
            ];
        }
      in
      ignore (after learning store (used 4.) (result ~procedures:[ entry "inspect" ] ()));
      ignore (after learning store (used 5.) (result ~procedures:[ entry "inspect" ] ()));
      Alcotest.(check int)
        "map-cnee runs that verified the installed procedure do not compile again"
        compiled !calls)

let maps_final =
  "https://www.google.com/maps/place/Eiffel+Tower/@48.8583736,2.2919064,17z/data=!3m1!4b1"

let maps_page name pattern : Trace.inferred_page = { name; url_pattern = pattern }

let maps_pages =
  [
    maps_page "m" "https://consent.google.com/m";
    maps_page "maps" "https://www.google.com/maps";
    maps_page "search-<slug>" "https://www.google.com/maps/search/<slug>*";
    maps_page "place-<slug>" "https://www.google.com/maps/place/<slug>*";
  ]

let mission1_kinds =
  "m" :: "maps"
  :: List.concat (List.init 6 (fun _ -> [ "search-<slug>"; "place-<slug>" ]))

let mission2_kinds = [ "maps"; "search-<slug>"; "place-<slug>" ]

let maps_trace ?(kinds = mission2_kinds) ?(pages = maps_pages) ?(label = "View") time =
  let stay = "https://www.google.com/maps" in
  let t = trace ~kinds ~steps:[ step ~label () ] time in
  {
    t with
    Trace.site = "google.com";
    start_url = Some stay;
    inferred_pages = pages;
    steps = [ { (step ~label ()) with after = { url = stay; title = "Google Maps" } } ];
    final = Some { url = maps_final; title = "Eiffel Tower - Google Maps" };
  }

let google_paths () =
  let expected = [ "maps"; "search-slug"; "place-slug" ] in
  let first = maps_trace ~kinds:mission1_kinds 1. in
  let second = maps_trace ~kinds:mission2_kinds 2. in
  Alcotest.(check int)
    "map-cnee raw consent path is kept" 14
    (List.length first.page_kind_path);
  Alcotest.(check bool)
    "map-cnee raw path still records the interstitial" true
    (List.hd first.page_kind_path = "m");
  Alcotest.(check (list string))
    "map-cnee mission 1 matching path" expected (L.matching_path first);
  Alcotest.(check (list string))
    "map-cnee mission 2 matching path" expected (L.matching_path second);
  bool "map-nh2e the two live paths agree when the actions do"
    (L.agreement [ first; second ]);
  bool "map-nh2e a different target still does not agree"
    (not (L.agreement [ first; maps_trace ~kinds:mission2_kinds ~label:"Delete" 3. ]));
  let swapped = maps_trace ~kinds:[ "maps"; "place-<slug>"; "search-<slug>" ] 4. in
  bool "map-cnee a different distinct order does not match"
    (L.matching_path swapped <> expected);
  let extra =
    maps_trace
      ~kinds:[ "maps"; "search-<slug>"; "place-<slug>"; "reviews" ]
      ~pages:(maps_pages @ [ maps_page "reviews" "https://www.google.com/maps/reviews" ])
      5.
  in
  bool "map-cnee an extra same-host kind does not match"
    (L.matching_path extra <> expected);
  let same_host_gate =
    maps_trace
      ~kinds:[ "m"; "maps"; "search-<slug>"; "place-<slug>" ]
      ~pages:(maps_page "m" "https://www.google.com/m" :: List.tl maps_pages)
      6.
  in
  bool "map-cnee a kind on the final host is not dropped"
    (List.mem "m" (L.matching_path same_host_gate));
  let both_hosts =
    maps_trace ~kinds:mission1_kinds
      ~pages:(maps_pages @ [ maps_page "m" "https://www.google.com/m" ])
      7.
  in
  bool "map-cnee a kind also seen on the final host stays"
    (List.mem "m" (L.matching_path both_hosts));
  temp (fun root ->
      let calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ ->
            incr calls;
            let proc = procedure ~until:[ "the page is maps" ] () in
            Ok
              (answer
                 ~kinds:[ ("maps", "maps"); ("place-<slug>", "maps-place") ]
                 {
                   proc with
                   B.expect = [ "the page is maps-place"; "the place is shown" ];
                 }))
          ()
      in
      let store = store root in
      ignore (after learning store first (result ()));
      Alcotest.(check int) "map-cnee one live path does not compile" 0 !calls;
      let _ = after learning store second (result ()) in
      Alcotest.(check int) "map-cnee the two live paths compile" 1 !calls;
      Alcotest.(check int)
        "map-cnee a proposal is written" 1
        (List.length (proposal_files ()));
      ignore
        (after learning store
           (maps_trace ~kinds:[ "maps"; "place-<slug>"; "search-<slug>" ] 8.)
           (result ()));
      Alcotest.(check int) "map-cnee a reordered path does not compile with them" 1 !calls)

let contains needle haystack =
  let n = String.length needle in
  let rec loop i =
    i + n <= String.length haystack && (String.sub haystack i n = needle || loop (i + 1))
  in
  n = 0 || loop 0

(* map-bjon: Flights verified on "the page is travel-slug" while the page still
   said Loading results. The compiler must be shown the mission and the final
   title, and must reject an expect list that only checks the page kind. *)
let result_expectation () =
  temp (fun root ->
      let calls = ref 0 in
      let first = ref None in
      let retry_reason = ref "" in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun request ->
            incr calls;
            if !calls = 1 then (
              first := Some request;
              Ok (answer { (procedure ()) with B.expect = [ "the page is catalog" ] }))
            else (
              (retry_reason :=
                 match Yojson.Safe.Util.member "validation_errors" request with
                 | `String reason -> reason
                 | _ -> "");
              Ok (answer (procedure ()))))
          ()
      in
      let store = store root in
      ignore (after learning store (trace 1.) (result ()));
      let _ = after learning store (trace 2.) (result ()) in
      Alcotest.(check int) "map-bjon page-kind-only expect is retried once" 2 !calls;
      bool "map-bjon retry names the mission result"
        (contains "mission result" !retry_reason
        && contains "destination prices are shown" !retry_reason);
      let request = Option.get !first in
      Alcotest.(check string)
        "map-bjon compiler prompt" "map-5"
        (match Yojson.Safe.Util.member "prompt_version" request with
        | `String version -> version
        | _ -> "");
      let trace_json =
        match Yojson.Safe.Util.member "traces" request with
        | `List (head :: _) -> head
        | _ -> Alcotest.fail "map-bjon compiler request has no traces"
      in
      let fields = match trace_json with `Assoc fields -> fields | _ -> [] in
      Alcotest.(check string)
        "map-bjon mission reaches the compiler" "inspect catalog"
        (match List.assoc_opt "mission" fields with
        | Some (`String mission) -> mission
        | _ -> "");
      Alcotest.(check string)
        "map-bjon final title reaches the compiler" "Catalog"
        (match List.assoc_opt "final_title" fields with
        | Some (`String title) -> title
        | _ -> "");
      bool "map-bjon traces still carry no page body"
        ((not (List.mem_assoc "page_text" fields)) && not (List.mem_assoc "text" fields));
      let proposed =
        ok
          (B.of_json
             ~file:(List.hd (proposal_files ()))
             (Yojson.Safe.from_file (List.hd (proposal_files ()))))
      in
      let proc = List.hd proposed.playbook.procedures in
      Alcotest.(check (option int))
        "map-bjon learned wait is 15 s" (Some 15) proc.expect_timeout_s;
      bool "map-bjon expect keeps the page kind and adds a result check"
        (List.mem "the page is catalog" proc.expect
        && List.exists (( <> ) "the page is catalog") proc.expect);
      ignore root)

(* map-op01–map-op06: scripted compiler protocol over minimized stored live evidence. *)
let google_fixture name =
  let path = "fixtures/learning-operations/" ^ name ^ ".json" in
  Yojson.Safe.from_file (if Sys.file_exists path then path else "test/" ^ path)
  |> Trace.t_of_yojson |> ok

let google_procedure () =
  {
    (procedure ~slug:"search-place"
       ~goal:
         "Type {query} in the combobox named Search Google Maps, then click the button \
          named Search"
       ~args:[ B.{ name = "query"; source = From_mission { optional = false } } ]
       ~until:[ "the page is maps-place" ] ())
    with
    B.steps =
      [
        B.Goal
          {
            goal = "Type {query} in the combobox named Search Google Maps";
            hint = None;
            until = Some [ "the page is maps-search" ];
          };
        B.Goal
          {
            goal = "Click the button named Search and read the place details";
            hint = None;
            until = Some [ "the page is maps-place" ];
          };
      ];
    expect = [ "the page is maps-place"; "place details are shown" ];
  }

let google_operation_protocol () =
  temp (fun root ->
      let calls = ref 0 and attributed = ref false and errors = ref `Null in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Auto)
          ~planner:(fun request ->
            incr calls;
            let input = Yojson.Safe.to_string request in
            attributed := contains "names" input && contains "query" input;
            errors := Yojson.Safe.Util.member "validation_errors" request;
            Ok
              (answer
                 ~kinds:
                   [
                     ("maps", "maps-search");
                     ("place-<slug>", "maps-place");
                     ("search-<slug>", "maps-results");
                   ]
                 (google_procedure ())))
          ()
      in
      let store = store root in
      let trace n =
        let trace = google_fixture ("google3-maps-" ^ n) in
        let text =
          List.find_map (fun (step : Trace.trace_step) -> step.text) trace.steps
          |> Option.get
        in
        { trace with arguments = [ ("query", text) ] }
      in
      ignore (after learning store (trace "1") (result ()));
      ignore (after learning store (trace "2") (result ()));
      if !calls <> 1 || List.length (proposal_files ()) <> 1 then
        Alcotest.failf "map-op03 calls=%d proposals=%d errors=%s status=%s" !calls
          (List.length (proposal_files ()))
          (Yojson.Safe.to_string !errors)
          (Yojson.Safe.to_string (L.status learning));
      bool "map-op01 feeding argument names reach compiler" !attributed;
      bool "map-op04 raw runtime kind offers its named draft"
        (List.length (L.drafts learning ~site:"google.com" ~kind:(Some "maps")) = 1);
      let loaded = (List.hd (L.books learning [])).B.playbook in
      bool "map-op05 new-site entry excludes consent"
        (loaded.entry <> Option.get (trace "1").start_url);
      let proc =
        (List.hd (L.drafts learning ~site:"google.com" ~kind:(Some "maps"))).B.procedure
      in
      let p = Option.get proc.provenance in
      bool "map-op04 meaningful name and raw mapping survive codec"
        (List.assoc "maps" p.kind_mapping = "maps-search"
        && p.entry_kind = "maps"
        && List.length p.signature = 2))

let repeated_operation_votes () =
  temp (fun root ->
      let calls = ref 0 in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun _ ->
            incr calls;
            Ok
              (answer
                 ~kinds:[ ("maps", "maps-search"); ("place-<slug>", "maps-place") ]
                 (google_procedure ())))
          ()
      in
      let a = google_fixture "google3-maps-1" in
      let steps =
        List.filter
          (fun (s : Trace.trace_step) ->
            s.operation <> "done"
            && s.target <> Some Trace.{ role = "button"; label = "Reject all" })
          a.steps
      in
      let steps =
        List.filter (fun (s : Trace.trace_step) -> s.operation <> "scroll_down") steps
      in
      let typed =
        List.find (fun (s : Trace.trace_step) -> s.operation = "type_text") steps
      in
      let click = List.find (fun (s : Trace.trace_step) -> s.operation = "click") steps in
      let final = Option.get a.final and entry = typed.after in
      let repeated =
        {
          a with
          start_url = Some entry.url;
          inferred_pages =
            List.filter (fun (p : Trace.inferred_page) -> p.name <> "m") a.inferred_pages;
          steps =
            [
              { typed with n = 1 };
              { click with n = 2; after = final };
              { click with n = 3; operation = "navigate"; target = None; after = entry };
              { typed with n = 4 };
              { click with n = 5; after = final };
            ];
          compiled = true;
        }
      in
      let store = store root in
      ignore (after learning store repeated (result ()));
      bool "map-op03 two repeated segments in one stored trace do not meet successes"
        (!calls = 0);
      ignore (after learning store (google_fixture "google3-maps-2") (result ()));
      bool "map-op03 previously compiled trace is still independent evidence"
        (!calls = 1 && List.length (proposal_files ()) = 1))

let named_consent_protocol () =
  temp (fun root ->
      let compiles = ref 0 in
      let base = google_procedure () in
      let proc =
        {
          base with
          B.steps =
            List.mapi
              (fun n -> function
                | B.Goal goal when n = 0 ->
                    B.Goal { goal with until = Some [ "the page is consent" ] }
                | step -> step)
              base.steps;
        }
      in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:(configure C.Learning_mode.Draft)
          ~planner:(fun request ->
            if Yojson.Safe.Util.member "task" request = `String "compile" then
              incr compiles;
            Ok
              (answer ~kinds:[ ("maps", "consent"); ("place-<slug>", "maps-place") ] proc))
          ()
      in
      let store = store root in
      List.iter
        (fun n ->
          ignore (after learning store (google_fixture ("google3-maps-" ^ n)) (result ())))
        [ "1"; "2" ];
      bool "map-op05 a compiler-named consent entry is retried once and excluded"
        (!compiles = 2 && proposal_files () = []))

let pending_vocabulary_protocol () =
  temp (fun root ->
      ignore (install_authored ~repeatable:false (procedure ~slug:"authored" ()));
      let named_page name repeatable =
        {
          (page ~repeatable ()) with
          B.name;
          description = name;
          url_pattern = Some ("https://example.com/" ^ name);
        }
      in
      List.iter
        (fun (name, repeatable) ->
          let proc =
            {
              (procedure ~slug:("pending-" ^ name) ~until:[ "the page is " ^ name ] ()) with
              B.expect = [ "the page is " ^ name; name ^ " details are shown" ];
              provenance =
                Some
                  B.
                    {
                      traces = [];
                      model = "test";
                      time = "earlier";
                      tries = 0;
                      last_failure = None;
                      path = [ name ];
                      entry_kind = name;
                      exit_kind = name;
                      signature = [];
                      kind_mapping = [ (name, name) ];
                      repeatable;
                      reason = "fixture";
                      gate = "replay";
                      repair = false;
                      model_calls = 0;
                      model_cost = None;
                    };
            }
          in
          let pending =
            { (book proc) with B.pages = [ page (); named_page name repeatable ] }
          in
          ignore (ok (B.propose ~caps ~book:pending ~site:"example.com" proc)))
        [ ("account", true); ("checkout", false) ];
      let original_files = proposal_files () in
      let seen = ref None and calls = ref 0 in
      let proc =
        {
          (procedure ~slug:"profile-operation"
             ~until:[ "the page is profile-details" ]
             ())
          with
          B.steps =
            [
              B.Goal
                {
                  goal = "Click the button named View";
                  hint = None;
                  until = Some [ "the page is profile-details" ];
                };
              B.Goal { goal = "Read the profile details"; hint = None; until = None };
            ];
          expect = [ "the page is profile-details"; "profile details are shown" ];
        }
      in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps
          ~config:{ (configure C.Learning_mode.Draft) with successes = 1 }
          ~planner:(fun request ->
            incr calls;
            seen :=
              Some
                (ok
                   (B.of_json ~file:"<map-op04 compiler seed>"
                      (Yojson.Safe.Util.member "playbook" request)))
                  .B.playbook;
            Ok
              (answer
                 ~kinds:[ ("profile", "profile-details"); ("account", "renamed-account") ]
                 proc))
          ()
      in
      let observation =
        Trace.{ url = "https://example.com/profile"; title = "Profile details" }
      in
      let trace =
        {
          (trace 1.) with
          Trace.start_url = Some observation.url;
          page_kind_path = [ "profile" ];
          inferred_pages = [ Trace.{ name = "profile"; url_pattern = observation.url } ];
          steps = [ { (step ()) with Trace.after = observation } ];
          final = Some observation;
        }
      in
      ignore (after learning (store root) trace (result ()));
      bool "map-op04 all pending books contribute to one compiler seed" (!calls = 1);
      let seed = Option.get !seen in
      let names pages =
        List.map (fun (p : B.page) -> p.name) pages |> List.sort String.compare
      in
      Alcotest.(check (list string))
        "map-op04 installed and both pending vocabularies reach the compiler"
        [ "account"; "catalog"; "checkout"; "profile" ]
        (names seed.pages);
      let file =
        Filename.concat
          (B.proposed_directory ~caps ())
          "example.com-profile-operation.json"
      in
      let learned = ok (B.of_json ~file (Yojson.Safe.from_file file)) in
      bool "map-op04 known names stay stable despite a compiler rename"
        (names learned.playbook.pages
        = [ "account"; "catalog"; "checkout"; "profile-details" ]);
      List.iter
        (fun name ->
          let p = List.find (fun (p : B.page) -> p.name = name) learned.playbook.pages in
          bool "map-op04 authored and pending non-repeatable pins are preserved"
            (not p.repeatable))
        [ "catalog"; "checkout" ];
      Alcotest.(check (list string))
        "map-op04 the complete compiler seed retains unrelated procedures"
        [ "authored"; "pending-account"; "pending-checkout" ]
        (List.map (fun (p : B.procedure) -> p.slug) seed.procedures
        |> List.sort String.compare);
      bool "map-op04 separate pending drafts survive compilation"
        (List.length (proposal_files ()) = List.length original_files + 1))

let flights_one_goal_protocol () =
  temp (fun root ->
      let calls = ref 0 and retry = ref false in
      let proc =
        {
          (procedure ~slug:"explore" ~goal:"Click the button named Explore destinations"
             ~until:[ "the page is flights-explore" ]
             ())
          with
          B.steps =
            [
              B.Goal
                {
                  goal = "Click the button named Explore destinations";
                  hint = None;
                  until = Some [ "the page is flights-explore" ];
                };
            ];
          expect = [ "the page is flights-explore"; "destination prices are shown" ];
        }
      in
      let config = { (configure C.Learning_mode.Auto) with successes = 1 } in
      let learning =
        L.create ~sw:(learning_sw ()) ~caps ~config
          ~planner:(fun request ->
            incr calls;
            retry :=
              !retry || Yojson.Safe.Util.member "validation_errors" request <> `String "";
            Ok (answer ~kinds:[ ("travel-<slug>", "flights-explore") ] proc))
          ()
      in
      ignore
        (after learning (store root) (google_fixture "google3-flights-2") (result ()));
      bool "map-op06 real one-click Explore output is retried once then dropped"
        (!calls = 2 && !retry && proposal_files () = [] && installed_slugs () = []))

let () =
  Eio_main.run (fun _ ->
      Eio.Switch.run (fun sw ->
          learning_switch := Some sw;
          Alcotest.run "learning"
            [
              ( "map",
                List.map
                  (fun (name, f) -> Alcotest.test_case name `Quick f)
                  [
                    ( "atomic and cross-process installation",
                      atomic_and_cross_process_install );
                    ("bounded provider metadata", bounded_provider_metadata);
                    ("stale trial revision", stale_trial_revision);
                    ("all repair targets", agreement_all_targets);
                    ("bounded risk agreement", bounded_risk_agreement);
                    ("inferred navigation patterns", inferred_navigation_patterns);
                    ("total learning cost", learning_cost_accounting);
                    ("config", defaults);
                    ("map-op05 compiler-named consent is excluded", named_consent_protocol);
                    ( "map-op04 pending vocabulary and authored pins",
                      pending_vocabulary_protocol );
                    ("path and classification", pure);
                    ("google live paths", google_paths);
                    ( "map-op01–05 real Google compiler protocol",
                      google_operation_protocol );
                    ("map-op03 independent operation votes", repeated_operation_votes);
                    ("map-op06 real Explore one-goal rejection", flights_one_goal_protocol);
                    ("map-cnee covered by verified use", covered_by_use);
                    ("draft compile", draft_compile);
                    ( "map-op08 map-op09 collection compile replay",
                      collection_compile_replay );
                    ("map-op08 compiler refusal cases", collection_compiler_refusals);
                    ( "map-op08 preserve authored scripts",
                      collection_keeps_authored_scripts );
                    ("validation retry", validation);
                    ("map-bjon result expectation", result_expectation);
                    ("parameterization", parameters);
                    ("replay", replay);
                    ("try budget", tries);
                    ("agreement", agreement_gate);
                    ("repair", repair);
                    ("retire", retire);
                    ("off", off);
                    ("invalid twice", permanent_invalid);
                    ("confirmation", confirmation);
                    ("nonrepeatable repair", nonrepeatable_repair);
                    ("unsafe repair", unsafe_repair);
                    ("counter resets", resets);
                    ("status gates", status_gates);
                    ("legacy trace", legacy_trace);
                    ("navigation until", navigation_until);
                    ("constant argument", constant_argument);
                    ("authored mode", authored_mode);
                    ("mission counter", mission_counter);
                  ] );
            ]))
