(* map-op08 map-op09: no browser, model or sensitive page text is needed. *)
module O = Leash__Structural_outline
module B = Leash.Playbook

let check name value = Alcotest.(check bool) name true value

let contains s needle =
  try
    ignore (Str.search_forward (Str.regexp_string needle) s 0);
    true
  with Not_found -> false

let node tag classes children =
  `Assoc
    [
      ("tag", `String tag);
      ("classes", `List (List.map (fun s -> `String s) classes));
      ("children", `List children);
    ]

let projection () =
  let secrets =
    [ "PRIVATE PAGE BODY"; "s3cret-password"; "alice@example.com"; "4111 1111 1111 1111" ]
  in
  let json =
    node "article"
      [ "product_pod"; "bad token"; "alice@example.com" ]
      [ node "h3" [] [ node "a" [] [] ]; node "p" [ "price_color" ] [] ]
  in
  let fields = match json with `Assoc f -> f | _ -> assert false in
  let json =
    `Assoc
      (("textContent", `String (List.hd secrets))
      :: ("value", `String (List.nth secrets 1))
      :: ( "attributes",
           `Assoc
             [
               ("email", `String (List.nth secrets 2));
               ("card", `String (List.nth secrets 3));
             ] )
      :: fields)
  in
  let outline = Option.get (O.decode (`List [ json ])) in
  Alcotest.(check string)
    "map-op09 only tags/classes survive"
    "article.product_pod\n  h3\n    a\n  p.price_color\n" outline;
  List.iter
    (fun secret ->
      check "map-op09 page text/password/email/card absent"
        (not (contains outline secret)))
    secrets;
  check "map-op09 collection detection"
    (O.collection "Collect every title and price"
    && not (O.collection "Search for Barcelona"));
  check "map-op09 bound browser traversal"
    (contains O.expression "slice(0, 5000)" && contains O.expression "budget = 256");
  check "map-op09 no page text read by projection"
    (not
       (List.exists (contains O.expression)
          [ "textContent"; "innerText"; "innerHTML"; "getAttribute"; ".value" ]))

let bounds () =
  let wide = List.init 12 (fun _ -> node "article" [ String.make 64 'x' ] []) in
  let tree = node "section" [ "catalog" ] (List.init 12 (fun _ -> node "div" [] wide)) in
  let outline = Option.get (O.decode (`List (List.init 8 (fun _ -> tree)))) in
  check "map-op09 host skeleton <= 4KB" (String.length outline <= 4096);
  check "map-op09 invalid input is absent"
    (O.decode (`String "arbitrary page body") = None);
  check "map-op09 text is not a tag"
    (O.decode (`List [ node "PRIVATE PAGE BODY" [] [] ]) = None)

let source_refusal () =
  check "map-op08 ordinary read-only extractor allowed"
    (Result.is_ok
       (B.check_compiled_script
          "return Array.from(document.querySelectorAll('article')).map(e => ({title: \
           e.textContent}));"));
  check "map-op08 ordinary function declaration is not Function constructor"
    (Result.is_ok
       (B.check_compiled_script "function read(e) { return e.textContent; } return [];"));
  List.iter
    (fun source ->
      check
        ("map-op08 refuses " ^ source)
        (Result.is_error (B.check_compiled_script source)))
    [
      "location.href = '/next'";
      "history.back()";
      "window.open('/next')";
      "form.submit()";
      "form.requestSubmit()";
      "node.click()";
      "node.dispatchEvent(event)";
      "node.focus()";
      "node.value = 'x'";
      "node['value'] = 'x'";
      "fetch('/api')";
      "new XMLHttpRequest()";
      "new WebSocket('wss://a')";
      "navigator.sendBeacon('/api')";
      "import('remote')";
      "localStorage.getItem('x')";
      "sessionStorage.clear()";
      "document.cookie";
      "indexedDB.open('x')";
      "eval('x')";
      "Function('x')";
      "[].constructor.constructor('x')";
      "window['open']('/next')";
    ]

let () =
  Alcotest.run "collection structure"
    [
      ( "map-op08 map-op09",
        [
          Alcotest.test_case "redaction projection" `Quick projection;
          Alcotest.test_case "bounded skeleton" `Quick bounds;
          Alcotest.test_case "compiled source refusal" `Quick source_refusal;
        ] );
    ]
