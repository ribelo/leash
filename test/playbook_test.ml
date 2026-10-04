module B = Leash.Playbook

let base =
  {|{
 "site":"allegro.pl", "entry":"https://allegro.pl/", "description":"Allegro",
 "pages":[{"name":"offer","url_pattern":"https://allegro.pl/oferta/*"}],
 "procedures":[{"slug":"open","description":"Open an offer","steps":[{"goal":"Open product","hint":"Offer"}],"expect":["the page is offer"]}]
}|}

(* extr-plaz: a playbook is a directory. [rm_rf] removes one without following a symlink
   out of it. *)
let rec rm_rf ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
  match (Unix.lstat path).Unix.st_kind with
  | Unix.S_DIR ->
      Array.iter
        (fun entry -> (rm_rf ~caps) (Filename.concat path entry))
        ((Ox_caps.Cap_sys.readdir ~caps) path);
      (Ox_caps.Cap_unix.rmdir ~caps) path
  | _ -> (Ox_caps.Cap_sys.remove ~caps) path
  | exception Unix.Unix_error _ -> ()

let temp_dir ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let dir = (Ox_caps.Cap_stdlib.Filename.temp_file ~caps) "leash-playbook-" "" in
  (Ox_caps.Cap_sys.remove ~caps) dir;
  (Ox_caps.Cap_unix.mkdir ~caps) dir 0o700;
  dir

let write ~(caps : < Ox_caps.Cap.fs_write ; .. >) path content =
  let rec parents ~(caps : < Ox_caps.Cap.fs_write ; .. >) p =
    if not (Sys.file_exists p) then (
      (parents ~caps) (Filename.dirname p);
      (Ox_caps.Cap_unix.mkdir ~caps) p 0o700)
  in
  (parents ~caps) (Filename.dirname path);
  let output = (Ox_caps.Cap_stdlib.open_out_bin ~caps) path in
  output_string output content;
  close_out output

let with_playbook
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >)
    ?(name = "playbook.json") ?(files = []) content f =
  let root = (temp_dir ~caps) () in
  Fun.protect
    ~finally:(fun () -> (rm_rf ~caps) root)
    (fun () ->
      let dir = Filename.concat root "shop" in
      (Ox_caps.Cap_unix.mkdir ~caps) dir 0o700;
      (write ~caps) (Filename.concat dir name) content;
      List.iter (fun (path, body) -> (write ~caps) (Filename.concat dir path) body) files;
      f dir (Filename.concat dir name))

let with_file
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >)
    _suffix content f =
  (with_playbook ~caps) content (fun _ file -> f file)

let expect_error
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) needle
    data =
  (with_playbook ~caps) data (fun dir path ->
      match B.load ~caps dir with
      | Ok _ -> Alcotest.fail ("run-dbji accepted " ^ needle)
      | Error message ->
          Alcotest.(check bool)
            ("run-dbji " ^ needle ^ " includes file")
            true
            (String.starts_with ~prefix:path message);
          Alcotest.(check bool)
            ("run-dbji reason: " ^ needle)
            true
            (try
               ignore (Str.search_forward (Str.regexp_string needle) message 0);
               true
             with Not_found -> false))

let mutate member value =
  let json = Yojson.Safe.from_string base in
  let fields = match json with `Assoc fields -> fields | _ -> assert false in
  Yojson.Safe.to_string
    (`Assoc
       (List.map
          (fun (key, old) -> if key = member then (key, value) else (key, old))
          fields))

let procedure ?(slug = "open") ?(expect = `List [ `String "the page is offer" ]) steps =
  `Assoc
    [
      ("slug", `String slug);
      ("description", `String "Open");
      ("steps", `List steps);
      ("expect", expect);
    ]

let refusal
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  (* run-tcuz extr-plaz: JSON-only, including explicit YAML refusal, and a directory. *)
  (with_playbook ~caps) ~name:"playbook.yaml" base (fun dir _ ->
      match B.load ~caps dir with
      | Error e ->
          Alcotest.(check bool) "JSON format suggested" true (String.contains e 'J')
      | Ok _ -> Alcotest.fail "accepted YAML");
  (with_playbook ~caps) base (fun _ file ->
      match B.load ~caps file with
      | Error e ->
          Alcotest.(check bool)
            "extr-plaz a single file is not a playbook" true
            (String.starts_with ~prefix:file e)
      | Ok _ -> Alcotest.fail "accepted a bare playbook.json file");
  (expect_error ~caps) "non-empty list"
    (mutate "procedures"
       (`List [ procedure ~expect:(`List []) [ `Assoc [ ("goal", `String "Open") ] ] ]));
  (expect_error ~caps) "unknown slug"
    (mutate "procedures" (`List [ procedure [ `Assoc [ ("use", `String "absent") ] ] ]));
  (expect_error ~caps) "cycle"
    (mutate "procedures" (`List [ procedure [ `Assoc [ ("use", `String "open") ] ] ]));
  (expect_error ~caps) "unknown page kind"
    (mutate "procedures"
       (`List
          [
            procedure
              ~expect:(`List [ `String "the page is missing" ])
              [ `Assoc [ ("goal", `String "Open") ] ];
          ]));
  (expect_error ~caps) "more than 200"
    (mutate "procedures"
       (`List
          (List.init 201 (fun i ->
               procedure
                 ~slug:("p" ^ string_of_int i)
                 [ `Assoc [ ("goal", `String "Open") ] ]))))

let grammar () =
  (* run-r1e9 run-2lei run-84ds run-zmz8 run-tny5 run-vbys run-xfxx *)
  let resolve s =
    B.resolve
      [
        B.
          {
            name = "offer";
            url_pattern = Some "https://allegro.pl/oferta/*";
            text_marker = None;
            repeatable = true;
          };
      ]
      s
  in
  let kind = function
    | B.Page_kind _ -> "page"
    | B.Not_page_kind _ -> "not_page"
    | B.Text _ -> "text"
    | B.Download _ -> "download"
    | B.No_dialog -> "dialog"
    | B.Row _ -> "role"
    | B.Judgment _ -> "jev"
  in
  List.iter
    (fun (sentence, expected) ->
      Alcotest.(check string)
        sentence expected
        (kind
           (match resolve sentence with
           | Ok checker -> checker
           | Error e -> Alcotest.fail e)))
    [
      ("the page is offer", "page");
      ("the page is not offer", "not_page");
      ("the page shows cart", "text");
      ("a file was downloaded", "download");
      ("a PDF was downloaded", "download");
      ("no dialog is open", "dialog");
      ("a button named Buy is present", "role");
      ("the picture looks right", "jev");
    ];
  let page =
    B.
      {
        name = "offer";
        url_pattern = Some "https://allegro.pl/oferta/*";
        text_marker = None;
        repeatable = true;
      }
  in
  Alcotest.(check (option string))
    "run-r1e9 wildcard URL" (Some "offer")
    (B.page_kind [ page ] ~url:"https://allegro.pl/oferta/123" ~text:"");
  Alcotest.(check (option string))
    "run-r1e9 not another route" None
    (B.page_kind [ page ] ~url:"https://allegro.pl/koszyk" ~text:"")

(* ncaps-mygj L34: the live example.com page has a browser title but no
   "Example Domain" body heading. A body-text checker must not silently treat
   the browser title or a URL-only page-kind match as body text. *)
let example_title_is_not_body () =
  let title = "Example Domain" in
  let page =
    B.
      {
        name = "example";
        url_pattern = Some "https://example.com/";
        text_marker = Some title;
        repeatable = true;
      }
  in
  let body = "This domain is for use in documentation examples." in
  let observation =
    B.
      {
        kind = B.page_kind [ page ] ~url:"https://example.com/" ~text:body;
        text = body;
        dialog = false;
        rows = [];
        downloads = [];
      }
  in
  Alcotest.(check (option string))
    "URL identifies site despite missing heading" (Some "example") observation.kind;
  let checker =
    match B.resolve [ page ] "the page shows Example Domain" with
    | Ok checker -> checker
    | Error reason -> Alcotest.fail reason
  in
  Alcotest.(check bool)
    "title alone does not satisfy a body-text checker" false
    (B.await
       ~now:(fun () -> 0.)
       ~sleep:(fun _ -> ())
       ~observe:(fun () -> observation)
       ~score:(fun _ _ -> 0.)
       ~timeout_s:0 [ checker ])

(* run-xqh8 run-k8bx, L34: dismissal is verified by leaving consent, whether
   the underlying page was products, search, or an offer. Unknown is not enough. *)
let consent_cleared () =
  let pages =
    [
      B.
        {
          name = "consent";
          url_pattern = None;
          text_marker = Some "privacy overlay";
          repeatable = true;
        };
    ]
  in
  let checker =
    match B.resolve pages "the page is not consent" with
    | Ok checker -> checker
    | Error message -> Alcotest.fail message
  in
  let check kind =
    B.await
      ~now:(fun () -> 0.)
      ~sleep:(fun _ -> ())
      ~observe:(fun () ->
        B.{ kind; text = ""; dialog = false; rows = []; downloads = [] })
      ~score:(fun _ _ -> 0.)
      ~timeout_s:0 [ checker ]
  in
  Alcotest.(check bool) "run-xqh8 covered" false (check (Some "consent"));
  Alcotest.(check bool) "run-k8bx unknown is not dismissed" false (check None);
  Alcotest.(check bool) "run-xqh8 returned to search" true (check (Some "search"));
  Alcotest.(check bool) "run-xqh8 returned to products" true (check (Some "products"))

let await () =
  (* run-l06s run-k8bx: bounded retry of checkers and one rerun, never unbounded. *)
  let elapsed = ref 0. in
  let calls = ref 0 in
  let observation () =
    incr calls;
    B.
      {
        kind = Some "offer";
        text = (if !calls > 2 then "ready" else "loading");
        dialog = false;
        rows = [];
        downloads = [];
      }
  in
  let result =
    B.await
      ~now:(fun () -> !elapsed)
      ~sleep:(fun seconds -> elapsed := !elapsed +. seconds)
      ~observe:observation
      ~score:(fun _ _ -> 0.)
      ~threshold:0.75 ~timeout_s:5 [ B.Text "ready" ]
  in
  Alcotest.(check bool) "run-l06s waits for settlement" true result;
  Alcotest.(check int) "run-l06s three observations" 3 !calls;
  let elapsed = ref 0. in
  let failed =
    B.await
      ~now:(fun () -> !elapsed)
      ~sleep:(fun seconds -> elapsed := !elapsed +. seconds)
      ~observe:observation
      ~score:(fun _ _ -> 0.)
      ~threshold:0.75 ~timeout_s:1 [ B.Text "never" ]
  in
  Alcotest.(check bool) "run-l06s bounded failure" false failed;
  Alcotest.(check bool) "run-l06s deadline" true (!elapsed <= 1.);
  let download state =
    B.
      {
        kind = None;
        text = "";
        dialog = false;
        rows = [];
        downloads = [ ("sample.pdf", "application/pdf", state) ];
      }
  in
  let check state =
    B.await
      ~now:(fun () -> 0.)
      ~sleep:(fun _ -> ())
      ~observe:(fun () -> download state)
      ~score:(fun _ _ -> 0.)
      ~timeout_s:0
      [ B.Download (Some "application/pdf") ]
  in
  Alcotest.(check bool) "run-l06s active is not downloaded" false (check "in_progress");
  Alcotest.(check bool) "run-l06s completed PDF" true (check "completed")

let retry () =
  (* run-k8bx: replay the first step after failure exactly once. *)
  let executions = ref 0 and checks = ref 0 in
  let passed =
    B.retry_once
      ~execute:(fun () -> incr executions)
      ~verify:(fun () ->
        incr checks;
        !checks = 2)
  in
  Alcotest.(check bool) "second verification passes" true passed;
  Alcotest.(check int) "first step replayed" 2 !executions;
  let executions = ref 0 in
  let failed =
    B.retry_once ~execute:(fun () -> incr executions) ~verify:(fun () -> false)
  in
  Alcotest.(check bool) "second failure returned" false failed;
  Alcotest.(check int) "never a third run" 2 !executions

let examples ~(caps : < Ox_caps.Cap.fs_read ; .. >) () =
  (* run-seqo run-fk99 *)
  List.iter
    (fun path ->
      match B.load ~caps path with
      | Ok book -> Alcotest.(check bool) "resolved checkers" true (book.checks <> [])
      | Error error -> Alcotest.fail error)
    [
      "../examples/playbooks/allegro.pl";
      "../examples/playbooks/www.w3.org";
      "../examples/playbooks/automationexercise.com";
    ]

let offscreen_offer ~(caps : < Ox_caps.Cap.fs_read ; .. >) () =
  (* run-xqh8, L34: a tiny viewport hides the product detail link; a desktop
     viewport exposes it, so scroll only when View Product is not observed. *)
  match B.load ~caps "../examples/playbooks/automationexercise.com" with
  | Error error -> Alcotest.fail error
  | Ok book -> (
      match
        List.find_opt
          (fun (p : B.procedure) -> p.slug = "open-offer")
          book.playbook.procedures
      with
      | Some { steps = [ B.Goal click ]; _ } ->
          Alcotest.(check (option string))
            "target View Product" (Some "View Product") click.hint;
          Alcotest.(check bool)
            "conditionally reveal offscreen link" true
            (let words = String.split_on_char ' ' click.goal in
             List.mem "absent" words && List.mem "scroll" words)
      | _ -> Alcotest.fail "open-offer must target the observed detail link")

let cart_after_add ~(caps : < Ox_caps.Cap.fs_read ; .. >) () =
  (* run-xqh8, L34: after View Cart, the prior Added! marker can linger in
     rendered text. The confirmed /view_cart URL must outrank post-add. *)
  match B.load ~caps "../examples/playbooks/automationexercise.com" with
  | Error error -> Alcotest.fail error
  | Ok book ->
      Alcotest.(check (option string))
        "cart outranks lingering success marker" (Some "cart")
        (B.page_kind book.playbook.pages ~url:"https://automationexercise.com/view_cart"
           ~text:"Added! Blue Top")

(* ---------- L37: playbook directories, scripts and shapes ---------- *)

let books
    ?(scripts =
      {|{"list":{"file":"scripts/list.js","description":"List the page.","returns":"list"}}|})
    ?(steps = {|{"goal":"Open the list."},{"script":"list","args":{"page":"{page}"}}|}) ()
    =
  Printf.sprintf
    {|{
 "site":"books.example","entry":"https://books.example/","description":"Books",
 "pages":[{"name":"list","url_pattern":"https://books.example/*"}],
 "shapes":{"list":[{"title":"string","price":"number"}],"count":{"n":"number"},"item":[{"title":"string"}]},
 "scripts": %s,
 "procedures":[{"slug":"collect","description":"Collect","args":{"page":{"from":"mission"}},"steps":[%s],"expect":["the page is list"]}]
}|}
    scripts steps

let list_js = ("scripts/list.js", "return [{title: 'A', price: 1}];")

let contains needle haystack =
  Str.string_match (Str.regexp (".*" ^ Str.quote needle)) haystack 0

let expect_load_error
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >)
    ?(files = [ list_js ]) ~story needle json =
  (with_playbook ~caps) ~files json (fun dir file ->
      match B.load ~caps dir with
      | Ok _ -> Alcotest.fail (story ^ " accepted: " ^ needle)
      | Error message ->
          Alcotest.(check bool)
            (story ^ " names the playbook file: " ^ message)
            true
            (String.starts_with ~prefix:file message);
          Alcotest.(check bool)
            (story ^ " says why (" ^ needle ^ "): " ^ message)
            true (contains needle message))

let directory_and_scripts
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  (* extr-plaz: a script is a file relative to the playbook directory, or short inline
     source; both are read at load. *)
  let json =
    books
      ~scripts:
        {|{"list":{"file":"scripts/list.js","description":"List the page.","returns":"list"},
           "count":{"source":"return {n: 1}","description":"Count the page.","returns":"count"}}|}
      ()
  in
  (with_playbook ~caps) ~files:[ list_js ] json (fun dir file ->
      match B.load ~caps dir with
      | Error why -> Alcotest.fail ("extr-plaz " ^ why)
      | Ok book -> (
          Alcotest.(check string) "extr-plaz playbook.json is the file" file book.file;
          Alcotest.(check (option string)) "extr-plaz the directory" (Some dir) book.dir;
          (match B.script_named book "list" with
          | Some script ->
              Alcotest.(check string)
                "extr-plaz a file script's text is read at load"
                "return [{title: 'A', price: 1}];" script.code;
              Alcotest.(check int)
                "map-fmt01 the one script bound is 8 MiB" 8_388_608 B.script_max_bytes
          | None -> Alcotest.fail "extr-plaz file script missing");
          match B.script_named book "count" with
          | Some script ->
              Alcotest.(check string)
                "extr-plaz inline source" "return {n: 1}" script.code;
              Alcotest.(check bool)
                "map-fmt01 inline script has no per-script bound" true (script.code <> "")
          | None -> Alcotest.fail "extr-plaz inline script missing"))

let script_refusals
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let story = "extr-plaz" in
  let json file =
    books
      ~scripts:
        (Printf.sprintf {|{"list":{"file":%S,"returns":[{"title":"string"}]}}|} file)
      ()
  in
  (expect_load_error ~caps) ~story "must not contain .." (json "../outside.js");
  (expect_load_error ~caps) ~story "must not contain .." (json "scripts/../../outside.js");
  (expect_load_error ~caps) ~story "must be relative" (json "/etc/hostname");
  (expect_load_error ~caps) ~story "must be a .js file" (json "scripts/list.txt");
  (expect_load_error ~caps) ~story "No such file" (json "scripts/absent.js");
  (expect_load_error ~caps) ~story "not a regular file"
    ~files:[ list_js; ("scripts/sub.js/x", "") ]
    (json "scripts/sub.js");
  (expect_load_error ~caps) ~story "exactly one of file or source"
    (books ~scripts:{|{"list":{"returns":[{"title":"string"}]}}|} ());
  (expect_load_error ~caps) ~story "exactly one of file or source"
    (books
       ~scripts:
         {|{"list":{"file":"scripts/list.js","source":"return []","returns":[{"title":"string"}]}}|}
       ());
  (expect_load_error ~caps) ~story "inline source is over"
    (books
       ~scripts:
         (Printf.sprintf {|{"list":{"source":%S,"returns":[{"title":"string"}]}}|}
            (String.make 5000 'x'))
       ());
  (expect_load_error ~caps) ~story "the script is empty"
    (books ~scripts:{|{"list":{"source":"  ","returns":[{"title":"string"}]}}|} ());
  (expect_load_error ~caps) ~story "name must be a lowercase slug"
    (books ~steps:{|{"goal":"x"}|}
       ~scripts:{|{"List":{"source":"return []","returns":[{"title":"string"}]}}|} ());
  (expect_load_error ~caps) ~story "removed field max_bytes"
    (books
       ~scripts:
         {|{"list":{"source":"return []","returns":[{"title":"string"}],"max_bytes":0}}|}
       ());
  (* extr-zdst: a malformed shape refuses the playbook. *)
  (expect_load_error ~caps) ~story:"extr-zdst" "unknown type"
    (books
       ~scripts:
         {|{"list":{"source":"/** returns: [{\"title\":\"text\"}] */\nreturn []","description":"List the page."}}|}
       ());
  (expect_load_error ~caps) ~story:"extr-zdst" "record or a list of records"
    (books
       ~scripts:
         {|{"list":{"source":"/** returns: [\"string\"] */\nreturn []","description":"List the page."}}|}
       ());
  (expect_load_error ~caps) ~story:"extr-zdst" "record or a list of records"
    (books
       ~scripts:
         {|{"list":{"source":"/** returns: [\"string\"] */\nreturn []","description":"List the page."}}|}
       ());
  (* A step naming a script the playbook does not have. *)
  (expect_load_error ~caps) ~story:"extr-8o1h" "unknown script"
    (books ~steps:{|{"script":"absent"}|} ());
  (expect_load_error ~caps) ~story:"extr-8o1h" "args must be an object of strings"
    (books ~steps:{|{"script":"list","args":{"page":1}}|} ());
  (* hdoc-vqj7: the exclusivity refusal must name the navigate variant too. *)
  (expect_load_error ~caps) ~story:"extr-8o1h" "exactly one of goal, use or script"
    (books ~steps:{|{"script":"list","goal":"x"}|} ())

let symlinks
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  (* extr-plaz: a symlink is resolved, and refused when it leaves the playbook directory;
     one that stays inside it is fine. *)
  let root = (temp_dir ~caps) () in
  Fun.protect
    ~finally:(fun () -> (rm_rf ~caps) root)
    (fun () ->
      let dir = Filename.concat root "shop" in
      (write ~caps) (Filename.concat root "outside.js") "return [];";
      (write ~caps)
        (Filename.concat dir "playbook.json")
        (books
           ~scripts:
             {|{"list":{"file":"scripts/link.js","description":"List the page.","returns":"item"}}|}
           ());
      (write ~caps) (Filename.concat dir "scripts/list.js") "return [];";
      (Ox_caps.Cap_unix.symlink ~caps) "list.js" (Filename.concat dir "scripts/link.js");
      (match B.load ~caps dir with
      | Ok _ -> ()
      | Error why -> Alcotest.fail ("extr-plaz a link inside the directory: " ^ why));
      (Ox_caps.Cap_sys.remove ~caps) (Filename.concat dir "scripts/link.js");
      (Ox_caps.Cap_unix.symlink ~caps)
        "../../outside.js"
        (Filename.concat dir "scripts/link.js");
      (match B.load ~caps dir with
      | Ok _ -> Alcotest.fail "extr-plaz a symlink out of the directory was loaded"
      | Error why ->
          Alcotest.(check bool)
            ("extr-plaz refused as outside: " ^ why)
            true
            (contains "outside the playbook directory" why));
      (* A directory link too: scripts -> an outside directory. *)
      (Ox_caps.Cap_sys.remove ~caps) (Filename.concat dir "scripts/link.js");
      (rm_rf ~caps) (Filename.concat dir "scripts");
      (write ~caps) (Filename.concat root "elsewhere/link.js") "return [];";
      (Ox_caps.Cap_unix.symlink ~caps) "../elsewhere" (Filename.concat dir "scripts");
      match B.load ~caps dir with
      | Ok _ ->
          Alcotest.fail "extr-plaz a linked directory out of the directory was loaded"
      | Error why ->
          Alcotest.(check bool)
            ("extr-plaz a linked directory is refused: " ^ why)
            true
            (contains "outside the playbook directory" why))

let no_directory_no_file_script () =
  (* extr-plaz extr-k40c: JSON that did not come from a playbook directory (a planner's
     book) can carry inline scripts at most, never a file. *)
  let json = Yojson.Safe.from_string (books ()) in
  match B.of_json ~file:"planner.json" json with
  | Ok _ -> Alcotest.fail "extr-plaz a file script without a directory was accepted"
  | Error why ->
      Alcotest.(check bool)
        ("extr-plaz refused: " ^ why) true
        (contains "needs a playbook directory" why)

let layout
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (* extr-plaz: <XDG>/leash/playbooks/<name>/playbook.json; the old flat file is refused
     rather than silently ignored. *)
  let root = (temp_dir ~caps) () in
  let previous = (Ox_caps.Cap_sys.getenv_opt ~caps) "XDG_CONFIG_HOME" in
  (Ox_caps.Cap_unix.putenv ~caps) "XDG_CONFIG_HOME" root;
  Fun.protect
    ~finally:(fun () ->
      (Ox_caps.Cap_unix.putenv ~caps)
        "XDG_CONFIG_HOME"
        (Option.value ~default:"" previous);
      (rm_rf ~caps) root)
    (fun () ->
      let playbooks = Filename.concat root "leash/playbooks" in
      (write ~caps) (Filename.concat playbooks "shop/playbook.json") (books ());
      (write ~caps) (Filename.concat playbooks "shop/scripts/list.js") "return [];";
      (write ~caps) (Filename.concat playbooks "shop/notes.txt") "not a playbook";
      (match B.list ~caps () with
      | Ok [ book ] ->
          Alcotest.(check string)
            "extr-plaz listed by directory" "books.example" book.playbook.site
      | Ok _ -> Alcotest.fail "extr-plaz the directory listed a wrong count"
      | Error why -> Alcotest.fail why);
      (match B.show ~caps "shop" with
      | Ok book ->
          Alcotest.(check int)
            "extr-lslp show carries the scripts" 1 (List.length book.scripts);
          let shown = Yojson.Safe.to_string (B.inspect ~code:true book) in
          Alcotest.(check bool)
            "extr-lslp show prints the script's text" true (contains "return [];" shown);
          Alcotest.(check bool)
            "extr-lslp check does not print it" false
            (contains "return [];" (Yojson.Safe.to_string (B.inspect book)));
          Alcotest.(check bool)
            "extr-lslp both name the declared shape" true
            (contains "price" (Yojson.Safe.to_string (B.inspect book)))
      | Error why -> Alcotest.fail why);
      (match B.show ~caps "../shop" with
      | Ok _ -> Alcotest.fail "extr-plaz show accepted a path"
      | Error _ -> ());
      (write ~caps) (Filename.concat playbooks "old.json") (books ());
      match B.list ~caps () with
      | Ok _ -> Alcotest.fail "extr-plaz a flat playbook file was ignored"
      | Error why ->
          Alcotest.(check bool)
            ("extr-plaz names the layout: " ^ why)
            true
            (contains "playbooks are directories" why))

let proposals_carry_no_scripts
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (* map-op08 amends extr-k40c: compiler scripts cannot bypass successful replay. *)
  let root = (temp_dir ~caps) () in
  Fun.protect
    ~finally:(fun () -> (rm_rf ~caps) root)
    (fun () ->
      let path = Filename.concat root "proposal.json" in
      (write ~caps) path
        (books
           ~scripts:
             {|{"list":{"source":"return []","description":"List the page.","returns":"item"}}|}
           ());
      match B.accept ~caps path with
      | Ok _ -> Alcotest.fail "extr-k40c a proposal with scripts was merged"
      | Error why ->
          Alcotest.(check bool)
            ("extr-k40c refused: " ^ why) true (contains "replay gate" why))

(* extr-zdst extr-8o1h: the shape language and its validation, as a table. *)
let shape_of text =
  match Leash.Shape.t_of_yojson (Yojson.Safe.from_string text) with
  | Ok shape -> shape
  | Error why -> Alcotest.fail ("extr-zdst shape " ^ text ^ ": " ^ why)

let shapes () =
  let listing =
    shape_of
      {|[{"title":"string","price":"number","in_stock":"boolean","url":"url",
          "rating?":"number","tags":["string"],"offers":[{"seller":"string","price":"number"}]}]|}
  in
  let record =
    {|{"title":"A","price":9.5,"in_stock":true,"url":"https://x.example/a","tags":["a","b"],
       "offers":[{"seller":"s","price":1}]}|}
  in
  let accept ?(shape = listing) text =
    match Leash.Shape.validate shape (Yojson.Safe.from_string text) with
    | Ok () -> ()
    | Error why -> Alcotest.fail ("extr-zdst rejected " ^ text ^ ": " ^ why)
  in
  let reject ?(shape = listing) ~path text =
    match Leash.Shape.validate shape (Yojson.Safe.from_string text) with
    | Ok () -> Alcotest.fail ("extr-8o1h accepted " ^ text)
    | Error why ->
        Alcotest.(check bool)
          (Printf.sprintf "extr-8o1h the first mismatch is at %s: %s" path why)
          true
          (String.starts_with ~prefix:path why)
  in
  accept ("[" ^ record ^ "]");
  accept "[]";
  (* optional: absent or null *)
  accept
    ("[" ^ record ^ ","
   ^ {|{"title":"B","price":1,"in_stock":false,"url":"http://x.example/b","rating":null,"tags":[],"offers":[]}|}
   ^ "]");
  accept ~shape:(shape_of {|{"n":"number"}|}) {|{"n":3}|};
  Alcotest.(check int)
    "extr-8o1h records of a list" 2
    (Leash.Shape.records (Yojson.Safe.from_string "[1,2]"));
  Alcotest.(check int)
    "extr-8o1h records of a record" 1
    (Leash.Shape.records (Yojson.Safe.from_string {|{"n":1}|}));
  reject ~path:"$: expected an array, got object" record;
  reject ~path:"$[0]: expected an object, got string" {|["x"]|};
  reject ~path:{|$[0]: missing field "price"|}
    {|[{"title":"A","in_stock":true,"url":"https://x.example/","tags":[],"offers":[]}]|};
  reject ~path:"$[1].price: expected number, got string"
    ("[" ^ record ^ ","
   ^ {|{"title":"B","price":"9","in_stock":true,"url":"https://x.example/","tags":[],"offers":[]}|}
   ^ "]");
  reject ~path:"$[0].url: expected an http(s) url"
    {|[{"title":"A","price":1,"in_stock":true,"url":"/relative","tags":[],"offers":[]}]|};
  reject ~path:"$[0].url: expected an http(s) url"
    {|[{"title":"A","price":1,"in_stock":true,"url":"javascript:alert(1)","tags":[],"offers":[]}]|};
  reject ~path:"$[0].tags[1]: expected string, got number"
    {|[{"title":"A","price":1,"in_stock":true,"url":"https://x.example/","tags":["a",2],"offers":[]}]|};
  reject ~path:{|$[0].offers[0]: missing field "seller" (it is null)|}
    {|[{"title":"A","price":1,"in_stock":true,"url":"https://x.example/","tags":[],"offers":[{"seller":null,"price":1}]}]|};
  reject ~path:"$[0].sku: unexpected field"
    {|[{"title":"A","price":1,"in_stock":true,"url":"https://x.example/","tags":[],"offers":[],"sku":"z"}]|};
  reject ~path:"$[0]: missing field \"title\" (it is null)"
    {|[{"title":null,"price":1,"in_stock":true,"url":"https://x.example/","tags":[],"offers":[]}]|};
  reject ~shape:(shape_of {|{"n":"number"}|}) ~path:"$: expected an object, got null"
    "null";
  (* the shape language itself *)
  let bad text needle =
    match Leash.Shape.t_of_yojson (Yojson.Safe.from_string text) with
    | Ok _ -> Alcotest.fail ("extr-zdst accepted shape " ^ text)
    | Error why ->
        Alcotest.(check bool)
          ("extr-zdst " ^ needle ^ ": " ^ why)
          true (contains needle why)
  in
  bad {|{"a":"number?"}|} "optional by a ? on its name";
  bad {|{"a":"int"}|} "unknown type";
  bad {|{}|} "at least one field";
  bad {|["string","number"]|} "exactly one element";
  bad {|{"a":"string","a?":"string"}|} "declared twice";
  bad {|{"a":{"b":{"c":{"d":{"e":{"f":{"g":{"h":{"i":"string"}}}}}}}}}|}
    "nested more than";
  (* a shape round-trips as written *)
  Alcotest.(check string)
    "extr-zdst the shape is kept as written"
    {|[{"title":"string","rating?":"number","tags":["string"]}]|}
    (Yojson.Safe.to_string
       (Leash.Shape.yojson_of_t
          (shape_of {|[{"title":"string","rating?":"number","tags":["string"]}]|})))

let script_examples () =
  (* extr-8o1h: a large number of records validates in one linear pass. *)
  let shape = shape_of {|[{"n":"number","s":"string"}]|} in
  let items =
    Yojson.Safe.to_string
      (`List (List.init 20_000 (fun i -> `Assoc [ ("n", `Int i); ("s", `String "x") ])))
  in
  match Leash.Shape.validate shape (Yojson.Safe.from_string items) with
  | Ok () -> ()
  | Error why -> Alcotest.fail ("extr-8o1h " ^ why)

(* pbk-abr3 extr-uhnc: the shipped example is a goal, a pinned collector and a next-page
   goal, not a fetch crawl. The pager check still terminates the repeat. *)
let books_toscrape_example ~(caps : < Ox_caps.Cap.fs_read ; .. >) () =
  let dir = "../examples/playbooks/books.toscrape.com" in
  Alcotest.(check bool)
    "pbk-8n2l repeat.json is gone" false
    (Sys.file_exists (Filename.concat dir "repeat.json"));
  Alcotest.(check bool)
    "pbk-abr3 the fetch crawl is gone" false
    (Sys.file_exists (Filename.concat dir "scripts/crawl-category.js"));
  match B.load ~caps "../examples/playbooks/books.toscrape.com" with
  | Error why -> Alcotest.fail ("extr-tkco " ^ why)
  | Ok book ->
      let procedure slug =
        match
          List.find_opt (fun (p : B.procedure) -> p.slug = slug) book.playbook.procedures
        with
        | Some p -> p
        | None -> Alcotest.fail ("extr-tkco procedure " ^ slug)
      in
      let script name =
        match B.script_named book name with
        | Some s -> s
        | None -> Alcotest.fail ("extr-tkco script " ^ name)
      in
      Alcotest.(check bool)
        "pbk-abr3 the list script is a file of the directory" true
        (String.length (script "list-page").B.code > 80);
      Alcotest.(check (option (list string)))
        "pbk-46fr list-page applies to category pages" (Some [ "category" ])
        (script "list-page").B.pages;
      Alcotest.(check bool)
        "pbk-abr3 list-page does not fetch" false
        (try
           ignore
             (Str.search_forward (Str.regexp_string "fetch(") (script "list-page").B.code
                0);
           true
         with Not_found -> false);
      Alcotest.(check bool)
        "pbk-abr3 open-category is a goal with the pager check" true
        (match
           ((procedure "open-category").steps, (procedure "open-category").repeat)
         with
        | ( B.Goal _ :: _,
            Some { until = B.Script_check "last-page"; next = "next-page"; _ } ) ->
            true
        | _ -> false);
      Alcotest.(check bool)
        "pbk-abr3 next-page is a goal" true
        (match (procedure "next-page").steps with B.Goal _ :: _ -> true | _ -> false);
      let kind url text = B.page_kind book.playbook.pages ~url ~text in
      let category = "https://books.toscrape.com/catalogue/category/books/mystery_3" in
      Alcotest.(check (option string))
        "extr-uhnc next in book text does not classify pagination" (Some "category")
        (kind (category ^ "/index.html") "Page 1 of 2\nnext");
      Alcotest.(check (option string))
        "extr-ve3k the last page ends it" (Some "category")
        (kind (category ^ "/page-2.html") "Page 2 of 2\nprevious");
      (* extr-zdst: the declared shape accepts a well-formed book and refuses a price that is text. *)
      let record price =
        Yojson.Safe.from_string
          (Printf.sprintf
             {|[{"title":"Sharp Objects","price":%s,"url":"https://books.toscrape.com/catalogue/sharp-objects_997/index.html","category":"Mystery","rating":4,"availability":"In stock"}]|}
             price)
      in
      Alcotest.(check bool)
        "extr-zdst a book passes the declared shape" true
        (Leash.Shape.validate (script "list-page").B.returns (record "47.82") = Ok ());
      Alcotest.(check bool)
        "extr-zdst a price that is text is refused" true
        (Result.is_error
           (Leash.Shape.validate (script "list-page").B.returns (record {|"47.82"|})))

(* extr-k40c: a procedure from outside a file — a planner's answer — can name a script the
   playbook already has, and cannot bring one: no step carries source or a file, and a
   script that is not in the playbook is refused before anything runs. *)
let planner_procedures
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  (with_playbook ~caps) ~files:[ list_js ] (books ()) (fun dir _ ->
      let book =
        match B.load ~caps dir with Ok b -> b | Error why -> Alcotest.fail why
      in
      let procedure json =
        match B.procedure_of_yojson (Yojson.Safe.from_string json) with
        | Ok proc -> Ok proc
        | Error why -> Error why
      in
      let of_steps steps =
        Printf.sprintf
          {|{"slug":"plan","description":"d","steps":[%s],"expect":["the page is list"]}|}
          steps
      in
      (match procedure (of_steps {|{"script":"list"}|}) with
      | Ok proc -> (
          match B.check_procedure book.playbook proc with
          | Ok () -> ()
          | Error why -> Alcotest.fail ("extr-k40c a named script is allowed: " ^ why))
      | Error why -> Alcotest.fail why);
      (match procedure (of_steps {|{"script":"evil"}|}) with
      | Ok proc -> (
          match B.check_procedure book.playbook proc with
          | Ok () -> Alcotest.fail "extr-k40c a script the playbook lacks was accepted"
          | Error why ->
              Alcotest.(check bool)
                ("extr-k40c " ^ why) true
                (contains "unknown script" why))
      | Error why -> Alcotest.fail why);
      List.iter
        (fun step ->
          match procedure (of_steps step) with
          | Ok _ -> Alcotest.fail ("extr-k40c a step carrying code was decoded: " ^ step)
          | Error _ -> ())
        [
          {|{"script":"list","source":"fetch('/x')"}|};
          {|{"script":"list","file":"scripts/list.js"}|};
          {|{"source":"fetch('/x')"}|};
        ])

(* hdoc-vqj7: pinned script/navigate steps do not fill declaration sources. *)
let pinned_script_arguments
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let ok = function Ok loaded -> loaded | Error why -> Alcotest.fail why in
  let data declaration step =
    Printf.sprintf
      {|{
    "site":"example.com","entry":"https://example.com/","description":"Navigate",
    "pages":[],"shapes":{"destination":{"url":"url"}},
    "scripts":{"product_url":{"source":"return {url: args.product};","description":"Resolve the product.",
      "returns":"destination","args":{"product":%s}}},
    "procedures":[{"slug":"view_cart","description":"View cart.","steps":[{"goal":"Confirm the cart."},%s],
      "expect":["no dialog is open"]}]}|}
      declaration step
  in
  List.iter
    (fun step ->
      (expect_error ~caps) "must pass declared argument product in step args"
        (data {|{"from":"mission"}|} step);
      (expect_error ~caps) "must pass declared argument product in step args"
        (data {|{"const":"https://example.com/cart"}|} step);
      ignore
        (ok
           (B.of_json ~file:"hdoc-vqj7.json"
              (Yojson.Safe.from_string (data {|{"from":"mission","optional":true}|} step)))))
    [ {|{"script":"product_url"}|} ];
  (expect_error ~caps) "removed field navigate"
    (data {|{"from":"mission"}|} {|{"navigate":{"script":"product_url"}}|})

(* extr-uhnc: control scripts are typed steps/checks, not collected records. *)
let control_scripts
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let data =
    {|{"site":"example.com","entry":"https://example.com/","description":"Catalogue",
    "pages":[],"scripts":{"next":{"source":"/** returns: {\"url\":\"url\"} */\nreturn {url: location.href};","description":"The next page URL."},
    "last":{"source":"/** returns: {\"done\":\"boolean\"} */\nreturn {done: true};","description":"Whether the listing is finished."}},
    "procedures":[{"slug":"collect","description":"Collect pages","steps":[{"script":"next"}],
    "expect":["no dialog is open"],"repeat":{"next":"next-page","max":8,"until":{"script":"last"},"key":"url"}},
    {"slug":"next-page","description":"Next page","steps":[{"script":"next"}],"expect":["no dialog is open"]},
    {"slug":"open","description":"Open the catalogue.","steps":[{"goal":"Open the catalogue."},{"use":"collect"}],"expect":["no dialog is open"]}]}|}
  in
  (with_playbook ~caps) data (fun dir _ ->
      match B.load ~caps dir with
      | Error reason -> Alcotest.fail reason
      | Ok book ->
          let proc = List.hd book.playbook.procedures in
          Alcotest.(check bool)
            "extr-uhnc typed navigation" true
            (match proc.steps with
            | [ B.Script { script = "next"; _ } ] -> true
            | _ -> false);
          Alcotest.(check bool)
            "extr-uhnc typed termination" true
            (match proc.repeat with
            | Some { until = B.Script_check "last"; _ } -> true
            | _ -> false));
  let replace old next = Str.global_replace (Str.regexp_string old) next data in
  (expect_error ~caps) "repeat until script must be declared"
    (replace {|"script":"last"|} {|"script":"missing"|});
  (expect_error ~caps) "removed field navigate"
    (replace {|{"script":"next"}|} {|{"navigate":{"script":"next"}}|})

let format_refusals
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let goal = {|{"goal":"Open the list."}|} in
  let described =
    {|{"list":{"source":"return []","description":"List the page.","returns":"item"}}|}
  in
  (expect_load_error ~caps) ~story:"pbk-85m1" B.script_only_message
    (books ~steps:{|{"script":"list"}|} ());
  (expect_load_error ~caps) ~story:"pbk-i0zl" "not an inline shape on the declaration"
    (books ~steps:goal
       ~scripts:
         {|{"list":{"source":"return []","description":"List the page.","returns":[{"title":"string"}]}}|}
       ());
  (expect_load_error ~caps) ~story:"pbk-lww9" "args.secret is read but not declared"
    (books ~steps:goal
       ~scripts:
         {|{"list":{"source":"return args.secret","description":"List the page.","returns":"item"}}|}
       ());
  (with_playbook ~caps)
    {|{"site":"books.example","entry":"https://books.example/","description":"Books",
 "pages":[{"name":"list","url_pattern":"https://books.example/*"}],
 "procedures":[{"slug":"collect","description":"Collect","args":["page"],"steps":[{"goal":"Open."}],"expect":["the page is list"]}]}|}
    (fun _ file ->
      match B.load ~caps (Filename.dirname file) with
      | Ok _ -> Alcotest.fail "pbk-i0zl accepted a list of argument names"
      | Error message ->
          Alcotest.(check bool)
            "pbk-i0zl names the new arg form" true
            (contains "not a list of names" message));
  (with_playbook ~caps)
    ~files:[ ("repeat.json", "{}"); list_js ]
    (books ~steps:goal ~scripts:described ())
    (fun dir _ ->
      match B.load ~caps dir with
      | Ok _ -> Alcotest.fail "pbk-8n2l accepted stray JSON"
      | Error message ->
          Alcotest.(check bool)
            "pbk-8n2l names the stray file" true
            (contains "repeat.json" message && contains "stray JSON" message));
  (with_playbook ~caps)
    {|{"site":"books.example","entry":"https://books.example/","description":"Books","returns":{"n":"number"},
 "pages":[{"name":"list","url_pattern":"https://books.example/*"}],
 "procedures":[{"slug":"collect","description":"Collect","steps":[{"goal":"Open."}],"expect":["the page is list"]}]}|}
    (fun _ file ->
      match B.load ~caps (Filename.dirname file) with
      | Ok _ -> Alcotest.fail "pbk-i0zl accepted top-level returns"
      | Error message ->
          Alcotest.(check bool)
            "pbk-i0zl names the new returns form" true
            (contains "not at the playbook top level" message))

(* map-fmt01: old files are refused by the field they still carry. *)
let removed_fields
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  let base = books () in
  let swap old next = Str.global_replace (Str.regexp_string old) next base in
  let cases =
    [
      ( "until",
        "removed field until",
        swap "{\"goal\":\"Open the list.\"}"
          "{\"goal\":\"Open the list.\",\"until\":[\"the page is list\"]}" );
      ( "expect_timeout_s",
        "removed field expect_timeout_s",
        swap "\"expect\":[\"the page is list\"]"
          "\"expect\":[\"the page is list\"],\"expect_timeout_s\":5" );
      ( "max_steps",
        "removed field max_steps",
        swap "\"expect\":[\"the page is list\"]"
          "\"expect\":[\"the page is list\"],\"max_steps\":10" );
      ( "deadline_s",
        "removed field deadline_s",
        swap "\"expect\":[\"the page is list\"]"
          "\"expect\":[\"the page is list\"],\"deadline_s\":30" );
      ( "description",
        "removed field description",
        swap "{\"name\":\"list\"" "{\"name\":\"list\",\"description\":\"List\"" );
      ( "max_bytes",
        "removed field max_bytes",
        swap "\"returns\":\"list\"" "\"returns\":\"list\",\"max_bytes\":1000" );
      ( "origin",
        "removed field origin",
        swap "\"returns\":\"list\"" "\"returns\":\"list\",\"origin\":\"inline\"" );
      ( "navigate",
        "removed field navigate",
        swap "{\"goal\":\"Open the list.\"}" "{\"navigate\":{\"script\":\"list\"}}" );
      ( "provenance",
        "removed field provenance",
        swap "{\n \"site\"" "{\"provenance\":{},\n \"site\"" );
    ]
  in
  List.iter
    (fun (field, needle, json) ->
      (expect_load_error ~caps) ~story:("map-fmt01 " ^ field) needle json)
    cases

let page text =
  B.{ kind = Some "travel-slug"; text; dialog = false; rows = []; downloads = [] }

(* map-bjon: a judgment that passes on a loading frame is not the verdict if the
   page moves before the deadline, and a failing judgment is not final early. *)
let judgment_loading () =
  let elapsed = ref 0. in
  let phase = ref `loading in
  let scores = ref [] in
  let results =
    B.await_results
      ~now:(fun () -> !elapsed)
      ~sleep:(fun seconds -> elapsed := !elapsed +. seconds)
      ~observe:(fun () ->
        page (if !phase = `loading then "Loading results" else "Paris PLN 184"))
      ~score:(fun _ obs ->
        scores := obs.text :: !scores;
        phase := `ready;
        if obs.text = "Loading results" then 0.95 else 0.91)
      ~timeout_s:5
      [
        ("the page is travel-slug", B.Page_kind "travel-slug");
        ("destination prices are shown", B.Judgment "destination prices are shown");
      ]
  in
  Alcotest.(check bool)
    "map-bjon loaded page passes" true
    (List.for_all (fun (result : B.checked) -> result.passed) results);
  Alcotest.(check bool)
    "map-bjon judgment was scored on the loaded page" true
    (List.mem "Paris PLN 184" !scores);
  Alcotest.(check string)
    "map-bjon a loading-frame score is not enough" "Loading results"
    (List.hd (List.rev !scores));
  let elapsed = ref 0. in
  let calls = ref 0 in
  let failed =
    B.await_results
      ~now:(fun () -> !elapsed)
      ~sleep:(fun seconds -> elapsed := !elapsed +. seconds)
      ~observe:(fun () ->
        incr calls;
        page "Loading results")
      ~score:(fun _ _ -> 0.1)
      ~timeout_s:1
      [ ("destination prices are shown", B.Judgment "destination prices are shown") ]
  in
  Alcotest.(check bool)
    "map-bjon loading judgment does not pass" false
    (List.for_all (fun (result : B.checked) -> result.passed) failed);
  Alcotest.(check bool)
    "map-bjon failure waits out the timeout" true
    (!calls > 1 && !elapsed <= 1. && !elapsed > 0.5)

let learned_timeout () =
  Alcotest.(check int) "map-fmt01 one expect wait" 5 B.expect_timeout_s

let provenance_sidecar
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  (with_playbook ~caps) ~files:[ list_js ] (books ()) (fun dir file ->
      let prov =
        B.
          {
            traces = [ "trace-1" ];
            model = "test";
            time = "t";
            tries = 0;
            last_failure = None;
            path = [ "list" ];
            entry_kind = "list";
            exit_kind = "list";
            signature = [];
            kind_mapping = [];
            repeatable = true;
            reason = "test";
            gate = "replay";
            repair = false;
            model_calls = 1;
            model_cost = None;
          }
      in
      (match B.write_provenance ~caps ~dir ~slug:"collect" prov with
      | Ok () -> ()
      | Error why -> Alcotest.fail why);
      (match B.load ~caps dir with
      | Error why -> Alcotest.fail why
      | Ok book ->
          Alcotest.(check string)
            "map-fmt02 runner loads the book" "collect"
            (List.hd book.playbook.procedures).slug);
      let body =
        (Ox_caps.Cap_stdlib.In_channel.with_open_text ~caps) file In_channel.input_all
      in
      Alcotest.(check bool)
        "map-fmt02 provenance is not a playbook field" false
        (try
           ignore (Str.search_forward (Str.regexp_string "\"provenance\"") body 0);
           true
         with Not_found -> false);
      match
        B.read_provenance ~caps (Filename.concat dir (B.provenance_filename "collect"))
      with
      | Ok (Some read) ->
          Alcotest.(check string) "map-fmt02 sidecar gate" "replay" read.gate
      | Ok None -> Alcotest.fail "map-fmt02 sidecar missing"
      | Error why -> Alcotest.fail why)

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "playbooks"
    [
      ( "L29",
        [
          Alcotest.test_case "run-tcuz run-dbji refusals" `Quick (refusal ~caps);
          Alcotest.test_case "run-r1e9 run-tny5 grammar" `Quick grammar;
          Alcotest.test_case "run-xqh8 consent cleared" `Quick consent_cleared;
          Alcotest.test_case "run-l06s wait" `Quick await;
          Alcotest.test_case "map-bjon judgment waits out loading" `Quick judgment_loading;
          Alcotest.test_case "map-bjon learned expect timeout" `Quick learned_timeout;
          Alcotest.test_case "run-k8bx retry once" `Quick retry;
          Alcotest.test_case "run-seqo examples" `Quick (examples ~caps);
          Alcotest.test_case "run-xqh8 offscreen offer" `Quick (offscreen_offer ~caps);
          Alcotest.test_case "run-xqh8 cart outranks add" `Quick (cart_after_add ~caps);
          Alcotest.test_case "ncaps-mygj Example title is not body text" `Quick
            example_title_is_not_body;
        ] );
      ( "L37",
        [
          Alcotest.test_case "extr-plaz extr-8o1h directory and scripts" `Quick
            (directory_and_scripts ~caps);
          Alcotest.test_case "extr-plaz extr-zdst extr-8o1h refusals" `Quick
            (script_refusals ~caps);
          Alcotest.test_case "extr-plaz symlinks" `Quick (symlinks ~caps);
          Alcotest.test_case "extr-plaz extr-k40c no file without a directory" `Quick
            no_directory_no_file_script;
          Alcotest.test_case "extr-plaz extr-lslp layout, show and check" `Quick
            (layout ~caps);
          Alcotest.test_case "extr-k40c proposals carry no scripts" `Quick
            (proposals_carry_no_scripts ~caps);
          Alcotest.test_case "extr-k40c planner procedures" `Quick
            (planner_procedures ~caps);
          Alcotest.test_case "extr-zdst extr-8o1h shapes" `Quick shapes;
          Alcotest.test_case "extr-8o1h many records" `Quick script_examples;
          Alcotest.test_case "hdoc-vqj7 explicit pinned arguments" `Quick
            (pinned_script_arguments ~caps);
          Alcotest.test_case "extr-uhnc typed control scripts" `Quick
            (control_scripts ~caps);
          Alcotest.test_case "extr-tkco books.toscrape.com example" `Quick
            (books_toscrape_example ~caps);
          Alcotest.test_case "pbk-85m1 pbk-lww9 pbk-8n2l pbk-i0zl format refusals" `Quick
            (format_refusals ~caps);
          Alcotest.test_case "map-fmt01 removed fields" `Quick (removed_fields ~caps);
          Alcotest.test_case "map-fmt02 provenance sidecar" `Quick
            (provenance_sidecar ~caps);
        ] );
    ]
