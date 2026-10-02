(* trace-qe8c trace-iqqz trace-dqr2 trace-zbb9 trace-uovo trace-o6ld
   trace-lg58 trace-szpg: offline evidence only; temporary state, fake clock/model. *)
module T = Leash.Traces
module P = Leash.Protocol
module D = Leash__Drive
module J = Leash__Jev_request

let caps = Ox_test.powerbox ()
let ok = function Ok x -> x | Error why -> Alcotest.fail why
let bool name value = Alcotest.(check bool) name true value

let rec remove path =
  match Unix.lstat path with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  | s when s.Unix.st_kind = Unix.S_DIR ->
      Array.iter (fun name -> remove (Filename.concat path name)) (Sys.readdir path);
      Unix.rmdir path
  | _ -> Unix.unlink path

let temp f =
  let path = Filename.temp_file "leash-l51-" "" in
  Unix.unlink path;
  Unix.mkdir path 0o700;
  Fun.protect ~finally:(fun () -> remove path) (fun () -> f path)

let trace ?(site = "toscrape.com") ?(outcome = "done") ?(compiled = false) time :
    P.drive_trace =
  P.Trace.
    {
      unattended = [];
      version = 1;
      time = T.timestamp time;
      site;
      mission = "check catalog";
      outcome;
      cost = Some 0.125;
      duration_ms = 200;
      model_calls = 2;
      page_kind_path = [ "catalog" ];
      start_url = None;
      inferred_pages = [];
      compiled;
      procedures = [];
      steps = [];
      final = Some { url = "https://books.toscrape.com/"; title = "Catalog" };
      error_code = None;
    }

let filesystem () =
  temp (fun root ->
      let store = T.create ~caps ~root () in
      let saved = trace 1000. in
      let path = ok (T.write store saved) in
      Alcotest.(check int) "trace-qe8c file private" 0o600 (Unix.stat path).st_perm;
      Alcotest.(check int)
        "trace-qe8c site private" 0o700 (Unix.stat (Filename.dirname path)).st_perm;
      let duplicate = ok (T.write store saved) in
      bool "trace-qe8c same-time traces never overwrite"
        (duplicate <> path && Sys.file_exists path && Sys.file_exists duplicate);
      bool "trace-lg58 derived roundtrip" (ok (T.read ~caps path) = saved);
      bool "trace-o6ld site filter" (ok (T.list store ~site:"missing.example" ()) = []);
      bool "trace-o6ld outcome filter" (ok (T.list store ~outcome:"blocked" ()) = []);
      bool "trace-qe8c unsafe path refused"
        (Result.is_error (T.write store { saved with site = "../escape" }));
      let link = Filename.concat root "symlink.json" in
      Unix.symlink path link;
      bool "trace-uovo symlink read refused" (Result.is_error (T.read ~caps link));
      bool "trace-uovo oversized writer refuses unreadable evidence"
        (Result.is_error (T.write store { saved with mission = String.make 8388608 'x' }));
      let forged = Filename.concat (Filename.dirname path) "forged.json" in
      Out_channel.with_open_bin forged (fun ch ->
          output_string ch
            (P.yojson_of_drive_trace { saved with site = "other.example" }
            |> Yojson.Safe.to_string));
      bool "trace-o6ld header-directory mismatch refuses list and prune"
        (Result.is_error (T.list store ())
        && Result.is_error (T.prune store ~dry_run:false ~now:1000. ()));
      bool "trace-dqr2 refused prune leaves evidence intact" (Sys.file_exists path);
      Unix.unlink forged;
      Unix.symlink (Filename.dirname path) (Filename.concat root "linked-site");
      bool "trace-uovo symlink site directory refused" (Result.is_error (T.list store ())))

let domains () =
  List.iter
    (fun (url, want) ->
      Alcotest.(check (option string))
        "trace-qe8c first registrable site" want (T.site url))
    [
      ("about:blank", None);
      ("https://books.toscrape.com/a", Some "toscrape.com");
      ("https://a.b.co.uk/", Some "b.co.uk");
      ("https://a.b.github.io/", Some "b.github.io");
      ("https://www.xn--85x722f.xn--55qx5d.cn/", Some "xn--85x722f.xn--55qx5d.cn");
      ("https://a.www.ck/", Some "www.ck");
      ("https://a.b.ck/", Some "a.b.ck");
      ("https://WWW.EXAMPLE.COM.:443/a", Some "example.com");
      ("http://localhost:8000/", Some "localhost");
      ("http://127.0.0.1:80/", Some "127.0.0.1");
      ("http://[::1]:80/", Some "::1");
    ]

let retention () =
  temp (fun root ->
      let retention = ok (T.Retention.of_values ~count:2 ~days:1) in
      let store = T.create ~caps ~root ~retention () in
      let write ?site ?outcome ?compiled time =
        ok (T.write store (trace ?site ?outcome ?compiled time))
      in
      let protected = write 1. in
      let old = write ~outcome:"error" 2. in
      let compiled = write ~compiled:true 3. in
      let boundary = write ~outcome:"blocked" (100000. -. 86400.) in
      let recent = write ~outcome:"error" 99999. in
      let other = write ~site:"other.example" ~outcome:"error" 1. in
      let doomed =
        ok (T.prune store ~site:"toscrape.com" ~dry_run:true ~now:100000. ())
      in
      bool "trace-dqr2 dry-run protected"
        (Sys.file_exists protected && Sys.file_exists old);
      bool "trace-dqr2 age and compiled marker"
        (List.mem old doomed && List.mem compiled doomed);
      bool "trace-dqr2 newest count and inclusive boundary"
        ((not (List.mem boundary doomed)) && not (List.mem recent doomed));
      bool "trace-dqr2 uncompiled success forever" (not (List.mem protected doomed));
      ignore (ok (T.prune store ~site:"toscrape.com" ~dry_run:false ~now:100000. ()));
      bool "trace-dqr2 prunes only selected site"
        (Sys.file_exists other && not (Sys.file_exists old));
      let json = P.yojson_of_drive_trace (trace 1.) in
      let legacy =
        match json with
        | `Assoc fields -> `Assoc (List.remove_assoc "compiled" fields)
        | _ -> assert false
      in
      bool "trace-dqr2 legacy defaults uncompiled"
        (not (ok (P.drive_trace_of_yojson legacy)).compiled))

let config () =
  let defaults = ok (Leash.Config.t_of_yojson (`Assoc [])) in
  bool "trace-szpg enabled by default" defaults.traces.enabled;
  Alcotest.(check int) "trace-dqr2 default count" 20 defaults.traces.retention.count;
  Alcotest.(check int) "trace-dqr2 default days" 30 defaults.traces.retention.days;
  let disabled =
    ok
      (Leash.Config.t_of_yojson
         (`Assoc [ ("traces", `Assoc [ ("enabled", `Bool false) ]) ]))
  in
  bool "trace-szpg switch" (not disabled.traces.enabled);
  List.iter
    (fun (count, days) ->
      bool "trace-dqr2 bounds" (Result.is_error (T.Retention.of_values ~count ~days)))
    [ (0, 30); (10001, 30); (20, 0); (20, 3651) ];
  bool "trace-szpg unknown config refused"
    (Result.is_error
       (Leash.Config.t_of_yojson
          (`Assoc [ ("traces", `Assoc [ ("enable", `Bool true) ]) ])))

let capture () =
  let c = T.capture ~mission:"mission" ~now:10. in
  T.page c ~url:"about:blank" ~kind:None ~pattern:None;
  T.page c ~url:"https://books.toscrape.com/" ~kind:(Some "catalog") ~pattern:None;
  T.page c ~url:"https://books.toscrape.com/" ~kind:(Some "catalog") ~pattern:None;
  T.page c ~url:"https://books.toscrape.com/" ~kind:(Some "detail") ~pattern:None;
  T.page c ~url:"https://other.example/" ~kind:(Some "checkout") ~pattern:None;
  let error =
    P.make_error
      ~detail:
        (`Assoc
           [
             ("model_calls", `Int 3);
             ("model_cost", `Float 0.2);
             ("cookies", `String "SECRET COOKIE");
             ("state", `String "SECRET PAGE");
           ])
      (ok (P.Error_code.of_string "model-unavailable"))
      ~message:"SECRET ERROR"
  in
  let saved = T.finish c ~now:10.250 (Error error) in
  Alcotest.(check string)
    "trace-qe8c first site across navigation" "toscrape.com" saved.site;
  Alcotest.(check (list string))
    "trace-iqqz declared transitions, unchanged omitted"
    [ "catalog"; "detail"; "checkout" ]
    saved.page_kind_path;
  Alcotest.(check int) "trace-qe8c failed call counters" 3 saved.model_calls;
  Alcotest.(check int) "trace-qe8c duration" 250 saved.duration_ms;
  let json = Yojson.Safe.to_string (P.yojson_of_drive_trace saved) in
  bool "trace-uovo errors and raw state absent" (not (String.contains json 'S'));
  let fly = T.finish (T.capture ~mission:"fly" ~now:0.) ~now:1. (Error error) in
  Alcotest.(check (list string))
    "trace-iqqz no invented on-the-fly kinds" [] fly.page_kind_path

let scripted_steps () =
  let c = T.capture ~mission:"fill search" ~now:0. in
  let handle = ok (P.Handle.of_string "t_trace") in
  let sid = ok (P.Snapshot_id.of_string "s_trace") in
  let state = ref false in
  let page () : D.observation =
    D.
      {
        snapshot =
          P.
            {
              snapshot = sid;
              tab = handle;
              url = "https://books.toscrape.com/";
              title = "Catalog";
              page_kind = None;
              rows =
                [
                  {
                    index = 1;
                    role = "textbox";
                    name = (if !state then "New row" else "Search");
                    value = None;
                    state = None;
                    options = None;
                  };
                ];
              total = 1;
              offset = 0;
              truncated = false;
              settled = true;
              source = Ax;
              reason = None;
              dialog = None;
            };
        text = "SECRET PAGE";
        can_scroll_down = false;
        can_scroll_up = false;
        fingerprint = "page";
      }
  in
  let choices = ref [ "type_text"; "done" ] in
  let decide _ =
    match !choices with
    | [] -> assert false
    | op :: rest ->
        choices := rest;
        Ok
          J.
            {
              operation = ok (P.Operation.of_string op);
              script = None;
              index = (if op = "type_text" then Some 1 else None);
              option = None;
              confidence = 1.;
              target_confidence = None;
              operation_probabilities =
                [ (String.uppercase_ascii op, 1.); ("NOT_AN_OPERATION", 0.) ];
              target_probabilities = [ ("1", 1.) ];
              targets = [];
            }
  in
  let acted = ref None in
  let act _ _ ~text =
    acted := text;
    state := true;
    Ok
      P.
        {
          tab = handle;
          url = "https://books.toscrape.com/";
          title = "Catalog";
          snapshot = None;
          dialog = None;
          popups = [];
          via = None;
        }
  in
  T.page c ~url:"https://books.toscrape.com/" ~kind:(Some "catalog") ~pattern:None;
  let result =
    match
      D.run ~on_step:(T.step c)
        ~handler:
          D.
            {
              observe = (fun () -> Ok (page ()));
              decide;
              text_value = (fun _ -> Ok (Some "alice"));
              act;
            }
        ~now:(fun () -> 0.)
        ~model:"scripted"
        ~args:
          P.
            {
              tab = handle;
              goal = "fill";
              max_steps = Some 2;
              deadline_s = Some 30;
              dry_run = None;
            }
        ~dry_run:false ()
    with
    | Ok r -> r
    | Error e -> Alcotest.fail e.message
  in
  Alcotest.(check (option string))
    "trace-uovo action receives actual value" (Some "alice") !acted;
  let saved =
    T.finish c ~now:1.
      (Error (P.make_error (ok (P.Error_code.of_string "internal")) ~message:"failure"))
  in
  Alcotest.(check int)
    "trace-qe8c partial capture after failure" (List.length result.steps)
    (List.length saved.steps);
  let first = List.hd saved.steps in
  Alcotest.(check (list (pair string (float 0.))))
    "trace-zbb9 upper-case JEV operation probabilities survive canonically"
    [ ("type_text", 1.) ]
    (List.map
       (fun (p : P.Trace.trace_probability) -> (p.key, p.probability))
       first.operations);
  Alcotest.(check (option string))
    "trace-zbb9 ordinary helper text retained" (Some "alice") first.text;
  Alcotest.(check (option string))
    "trace-zbb9 target from before action" (Some "Search")
    (Option.map (fun (t : P.Trace.trace_target) -> t.label) first.target);
  let redacted = T.capture ~mission:"password backstop" ~now:0. in
  T.step redacted { (List.hd result.steps) with P.text = Some "[password]" };
  let password =
    T.finish redacted ~now:1.
      (Error (P.make_error (ok (P.Error_code.of_string "internal")) ~message:"failure"))
  in
  Alcotest.(check (option string))
    "trace-uovo literal password marker retained" (Some "[password]")
    (List.hd password.steps).text;
  temp (fun root ->
      let store = T.create ~caps ~root () in
      let path = ok (T.write store saved) in
      bool "trace-lg58 safe captured roundtrip" (ok (T.read ~caps path) = saved))

let inferred_capture () =
  let c = T.capture ~mission:"tags" ~now:0. in
  List.iter
    (fun url -> T.page c ~url ~kind:(Some "home") ~pattern:(Some url))
    [ "about:blank"; "chrome://newtab/"; "data:text/html,Hello"; "file:///tmp/page" ];
  T.page c ~url:"https://quotes.toscrape.com/tag/love/" ~kind:(Some "love")
    ~pattern:(Some "https://quotes.toscrape.com/tag/love");
  T.page c ~url:"https://quotes.toscrape.com/tag/humor/" ~kind:(Some "tag-<slug>")
    ~pattern:(Some "https://quotes.toscrape.com/tag/<slug>");
  let trace =
    T.finish c ~now:1.
      (Error (P.make_error (ok (P.Error_code.of_string "internal")) ~message:"fixture"))
  in
  Alcotest.(check (list string))
    "trace-iqqz merged header excludes non-web kinds" [ "tag-<slug>" ]
    trace.page_kind_path;
  Alcotest.(check (list (pair string string)))
    "kind-s1k2 earlier draft entry merged"
    [ ("tag-<slug>", "https://quotes.toscrape.com/tag/<slug>") ]
    (List.map
       (fun (p : P.Trace.inferred_page) -> (p.name, p.url_pattern))
       trace.inferred_pages)

(* L53 map-3qag: a failed planner detour shares the durable chronological trace. *)
let planner_steps () =
  let c = T.capture ~mission:"inspect catalogue" ~now:0. in
  let after = P.{ url = "https://books.toscrape.com/"; title = "Catalogue" } in
  let operator : P.step =
    P.
      {
        non_repeatable = false;
        n = 1;
        snapshot = ok (Snapshot_id.of_string "s_test");
        operation = ok (Operation.of_string "done");
        index = None;
        probabilities = P.{ op = `Assoc []; target = `Assoc [] };
        target = None;
        text = None;
        after;
        elapsed_ms = 3;
      }
  in
  T.step c operator;
  T.planner_step c
    P.
      {
        non_repeatable = false;
        n = 1;
        command = "click";
        target = Some { target_role = "button"; target_label = "Browse" };
        text = None;
        after;
        elapsed_ms = 8;
        error = None;
      };
  T.planner_step c
    P.
      {
        non_repeatable = false;
        n = 2;
        command = "fill";
        target = Some { target_role = "textbox"; target_label = "Search" };
        text = Some "alice@example.com";
        after;
        elapsed_ms = 9;
        error = Some "stale-snapshot";
      };
  let trace =
    T.finish c ~now:1.
      (Error
         (P.make_error (ok (P.Error_code.of_string "stale-snapshot")) ~message:"changed"))
  in
  Alcotest.(check (list int))
    "mixed steps numbered once" [ 1; 2; 3 ]
    (List.map (fun (s : P.Trace.trace_step) -> s.n) trace.steps);
  Alcotest.(check (list string))
    "operator and detour chronology"
    [ "operator"; "planner"; "planner" ]
    (List.map (fun (s : P.Trace.trace_step) -> s.source) trace.steps);
  Alcotest.(check (list (option string)))
    "failed attempt remains evidence"
    [ None; None; Some "stale-snapshot" ]
    (List.map (fun (s : P.Trace.trace_step) -> s.error) trace.steps);
  Alcotest.(check (option string))
    "ordinary planner input retained" (Some "alice@example.com")
    (List.nth trace.steps 2).text;
  let roundtrip = ok (P.drive_trace_of_yojson (P.yojson_of_drive_trace trace)) in
  Alcotest.(check int)
    "durable wire retains planner steps" 3 (List.length roundtrip.steps)

let unattended_capture () =
  let notify =
    `Assoc
      [
        ("kind", `String "notify");
        ("message", `String "Order 123 placed");
        ("elapsed_ms", `Int 4);
        ("outcome", `String "failed");
        ("error", `String "exited 1");
      ]
  in
  let challenge =
    `Assoc
      [
        ("kind", `String "challenge");
        ("origin", `String "https://example.com");
        ("attempt", `Bool true);
        ("turns", `Int 2);
        ("outcome", `String "expired");
      ]
  in
  let polluted =
    match challenge with
    | `Assoc fields -> `Assoc (("cookies", `String "SECRET") :: fields)
    | _ -> assert false
  in
  let error =
    P.make_error
      ~detail:
        (`Assoc
           [
             ( "unattended",
               `List
                 [
                   notify;
                   polluted;
                   `Assoc [ ("kind", `String "unknown"); ("raw", `String "SECRET") ];
                 ] );
           ])
      (ok (P.Error_code.of_string "invalid-request"))
      ~message:"blocked"
  in
  let saved = T.finish (T.capture ~mission:"unattended" ~now:0.) ~now:1. (Error error) in
  bool "notif-udh3 audit kinds survive safe projection"
    (saved.unattended = [ notify; challenge ]);
  temp (fun root ->
      let path = ok (T.write (T.create ~caps ~root ()) saved) in
      bool "notif-udh3 audit survives durable store"
        ((ok (T.read ~caps path)).unattended = saved.unattended));
  let legacy =
    match P.yojson_of_drive_trace saved with
    | `Assoc fields -> `Assoc (List.remove_assoc "unattended" fields)
    | _ -> assert false
  in
  bool "notif-udh3 old trace default is empty"
    ((ok (P.drive_trace_of_yojson legacy)).unattended = [])

let () =
  Alcotest.run "L51 traces"
    [
      ( "offline",
        List.map
          (fun (n, f) -> Alcotest.test_case n `Quick f)
          [
            ("trace-qe8c trace-lg58 private store", filesystem);
            ("trace-qe8c public suffix", domains);
            ("trace-dqr2 retention", retention);
            ("trace-szpg config", config);
            ("trace-iqqz failure projection", capture);
            ("trace-iqqz kind-s1k2 inferred header canonicalization", inferred_capture);
            ("trace-zbb9 trace-uovo acknowledged target", scripted_steps);
            ("map-3qag mixed planner trace and partial failure", planner_steps);
            ("notif-udh3 safe durable unattended audit and old codecs", unattended_capture);
          ] );
    ]
