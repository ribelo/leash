module B = Leash.Playbook

let base =
  {|{
 "site":"allegro.pl", "entry":"https://allegro.pl/", "description":"Allegro",
 "pages":[{"name":"offer","description":"An offer","url_pattern":"https://allegro.pl/oferta/*"}],
 "procedures":[{"slug":"open","description":"Open an offer","steps":[{"goal":"Open product","hint":"Offer"}],"expect":["the page is offer"]}]
}|}

let with_file suffix content f =
  let path = Filename.temp_file "leash-playbook-" suffix in
  Fun.protect
    ~finally:(fun () -> Sys.remove path)
    (fun () ->
      let output = open_out path in
      output_string output content;
      close_out output;
      f path)

let expect_error needle data =
  with_file ".json" data (fun path ->
      match B.load path with
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

let refusal () =
  (* run-tcuz: JSON-only, including explicit YAML refusal. *)
  with_file ".yaml" base (fun path ->
      match B.load path with
      | Error e ->
          Alcotest.(check bool) "JSON format suggested" true (String.contains e 'J')
      | Ok _ -> Alcotest.fail "accepted YAML");
  expect_error "non-empty list"
    (mutate "procedures"
       (`List [ procedure ~expect:(`List []) [ `Assoc [ ("goal", `String "Open") ] ] ]));
  expect_error "unknown slug"
    (mutate "procedures" (`List [ procedure [ `Assoc [ ("use", `String "absent") ] ] ]));
  expect_error "cycle"
    (mutate "procedures" (`List [ procedure [ `Assoc [ ("use", `String "open") ] ] ]));
  expect_error "unknown page kind"
    (mutate "procedures"
       (`List
          [
            procedure
              ~expect:(`List [ `String "the page is missing" ])
              [ `Assoc [ ("goal", `String "Open") ] ];
          ]));
  expect_error "more than 200"
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
            description = "";
            url_pattern = Some "https://allegro.pl/oferta/*";
            text_marker = None;
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
        description = "";
        url_pattern = Some "https://allegro.pl/oferta/*";
        text_marker = None;
      }
  in
  Alcotest.(check (option string))
    "run-r1e9 wildcard URL" (Some "offer")
    (B.page_kind [ page ] ~url:"https://allegro.pl/oferta/123" ~text:"");
  Alcotest.(check (option string))
    "run-r1e9 not another route" None
    (B.page_kind [ page ] ~url:"https://allegro.pl/koszyk" ~text:"")

(* run-xqh8 run-k8bx, L34: dismissal is verified by leaving consent, whether
   the underlying page was products, search, or an offer. Unknown is not enough. *)
let consent_cleared () =
  let pages =
    [
      B.
        {
          name = "consent";
          description = "privacy overlay";
          url_pattern = None;
          text_marker = Some "privacy overlay";
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

let examples () =
  (* run-seqo run-fk99 *)
  List.iter
    (fun path ->
      match B.load path with
      | Ok book -> Alcotest.(check bool) "resolved checkers" true (book.checks <> [])
      | Error error -> Alcotest.fail error)
    [
      "../examples/playbooks/allegro.pl.json";
      "../examples/playbooks/www.w3.org.json";
      "../examples/playbooks/automationexercise.com.json";
    ]

let offscreen_offer () =
  (* run-xqh8, L34: a tiny viewport hides the product detail link; a desktop
     viewport exposes it, so scroll only when View Product is not observed. *)
  match B.load "../examples/playbooks/automationexercise.com.json" with
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

let cart_after_add () =
  (* run-xqh8, L34: after View Cart, the prior Added! marker can linger in
     rendered text. The confirmed /view_cart URL must outrank post-add. *)
  match B.load "../examples/playbooks/automationexercise.com.json" with
  | Error error -> Alcotest.fail error
  | Ok book ->
      Alcotest.(check (option string))
        "cart outranks lingering success marker" (Some "cart")
        (B.page_kind book.playbook.pages ~url:"https://automationexercise.com/view_cart"
           ~text:"Added! Blue Top")

let () =
  Alcotest.run "playbooks"
    [
      ( "L29",
        [
          Alcotest.test_case "run-tcuz run-dbji refusals" `Quick refusal;
          Alcotest.test_case "run-r1e9 run-tny5 grammar" `Quick grammar;
          Alcotest.test_case "run-xqh8 consent cleared" `Quick consent_cleared;
          Alcotest.test_case "run-l06s wait" `Quick await;
          Alcotest.test_case "run-k8bx retry once" `Quick retry;
          Alcotest.test_case "run-seqo examples" `Quick examples;
          Alcotest.test_case "run-xqh8 offscreen offer" `Quick offscreen_offer;
          Alcotest.test_case "run-xqh8 cart outranks add" `Quick cart_after_add;
        ] );
    ]
