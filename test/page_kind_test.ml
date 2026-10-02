(* kind-a7uy kind-dnye kind-jdcs kind-4qke kind-s1k2: inferred page kinds.

   The pairs are realistic URL and title shapes from Allegro, Amazon, Google
   Flights, Google Maps and books.toscrape.com. Nothing here opens a browser or
   a socket. *)

module K = Leash.Page_kind

let check_string name expected actual = Alcotest.(check string) name expected actual

let table () =
  let cases =
    [
      ( "https://allegro.pl/",
        "Allegro - atrakcyjne ceny na miliony produktów",
        "home",
        "https://allegro.pl/",
        "atrakcyjne ceny na miliony produktów" );
      ( "https://allegro.pl/listing?string=logitech+mx+master",
        "logitech mx master - Allegro",
        "listing",
        "https://allegro.pl/listing",
        "logitech mx master" );
      ( "https://allegro.pl/kategoria/elektronika",
        "Elektronika - Allegro.pl",
        "elektronika",
        "https://allegro.pl/kategoria/elektronika",
        "Elektronika" );
      ( "https://allegro.pl/oferta/12345678901",
        "Logitech MX Master 3S - Allegro",
        "oferta-<id>",
        "https://allegro.pl/oferta/<id>",
        "Logitech MX Master 3S" );
      ( "https://allegro.pl/oferta/logitech-mx-master-3s-grafitowy-bezprzewodowa",
        "Logitech MX Master 3S - Allegro",
        "oferta-<slug>",
        "https://allegro.pl/oferta/<slug>",
        "Logitech MX Master 3S" );
      ( "https://allegro.pl/koszyk",
        "Koszyk (2) - Allegro",
        "koszyk",
        "https://allegro.pl/koszyk",
        "Koszyk" );
      ( "https://allegro.pl/uzytkownik/a1b2c3d4e5f67890",
        "Sprzedający - Allegro",
        "uzytkownik-<id>",
        "https://allegro.pl/uzytkownik/<id>",
        "Sprzedający" );
      ( "https://allegro.pl/zamowienie/550e8400-e29b-41d4-a716-446655440000",
        "Zamówienie - Allegro",
        "zamowienie-<id>",
        "https://allegro.pl/zamowienie/<id>",
        "Zamówienie" );
      ( "https://www.amazon.com/",
        "Amazon.com. Spend less. Smile more.",
        "home",
        "https://www.amazon.com/",
        "Amazon.com. Spend less. Smile more." );
      ( "https://www.amazon.com/s?k=logitech+mx+master",
        "Amazon.com : logitech mx master",
        "s",
        "https://www.amazon.com/s",
        "Amazon.com : logitech mx master" );
      ( "https://www.amazon.com/Logitech-MX-Master-3S-Graphite/dp/B0B6C5J6B8",
        "Amazon.com: Logitech MX Master 3S Wireless Mouse : Electronics",
        "dp-<id>",
        "https://www.amazon.com/<slug>/dp/<id>",
        "Amazon.com: Logitech MX Master 3S Wireless Mouse : Electronics" );
      ( "https://www.amazon.com/gp/cart/view.html",
        "Amazon.com Shopping Cart",
        "view",
        "https://www.amazon.com/gp/cart/view.html",
        "Amazon.com Shopping Cart" );
      ( "https://www.amazon.com/dp/B07FZ8S74R/ref=sr_1_1?keywords=mouse",
        "Amazon.com: mouse",
        "dp-<id>",
        "https://www.amazon.com/dp/<id>*",
        "Amazon.com: mouse" );
      ( "https://www.google.com/travel/flights",
        "Google Flights",
        "flights",
        "https://www.google.com/travel/flights",
        "Google Flights" );
      ( "https://www.google.com/travel/flights/search?tfs=CBwQAhoeEgoyMDI2LTEwLTE1",
        "Warsaw to London | Google Flights",
        "search",
        "https://www.google.com/travel/flights/search",
        "Warsaw to London - Google Flights" );
      ( "https://www.google.com/maps",
        "Google Maps",
        "maps",
        "https://www.google.com/maps",
        "Google Maps" );
      ( "https://www.google.com/maps/place/Warsaw/@52.2297,21.0122,12z",
        "Warsaw - Google Maps",
        "place-<slug>",
        "https://www.google.com/maps/place/<slug>*",
        "Warsaw - Google Maps" );
      ( "https://www.google.com/maps/place/Palace+of+Culture/@52.2318,21.0060,17z/data=!3m1!4b1!4m6!3m5!1s0x471ecc8c92692e49:0xc2e97552d5c2c0e0",
        "Palace of Culture and Science - Google Maps",
        "place-<slug>",
        "https://www.google.com/maps/place/<slug>*",
        "Palace of Culture and Science - Google Maps" );
      ( "https://books.toscrape.com/",
        "All products | Books to Scrape - Sandbox",
        "home",
        "https://books.toscrape.com/",
        "All products - Books to Scrape - Sandbox" );
      ( "https://books.toscrape.com/catalogue/category/books/travel_2/index.html",
        "Travel | Books to Scrape - Sandbox",
        "books-<slug>",
        "https://books.toscrape.com/catalogue/category/books/<slug>/index.html",
        "Travel - Books to Scrape - Sandbox" );
      ( "https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html",
        "A Light in the Attic | Books to Scrape - Sandbox",
        "catalogue-<slug>",
        "https://books.toscrape.com/catalogue/<slug>/index.html",
        "A Light in the Attic - Books to Scrape - Sandbox" );
      ( "https://books.toscrape.com/catalogue/page-2.html",
        "All products | Books to Scrape - Sandbox",
        "page-<id>",
        "https://books.toscrape.com/catalogue/page-<id>.html",
        "All products - Books to Scrape - Sandbox" );
    ]
  in
  Alcotest.(check bool) "kind-jdcs at least twenty pairs" true (List.length cases >= 20);
  List.iter
    (fun (url, title, name, pattern, cleaned) ->
      let inferred = K.infer ~url ~title in
      check_string ("kind-jdcs name " ^ url) name inferred.name;
      check_string ("kind-jdcs pattern " ^ url) pattern inferred.url_pattern;
      check_string ("kind-a7uy title " ^ url) cleaned inferred.title)
    cases;
  let same label urls =
    let names =
      List.map (fun url -> (K.infer ~url ~title:"").name) urls
      |> List.sort_uniq String.compare
    in
    Alcotest.(check int) label 1 (List.length names)
  in
  same "kind-jdcs every Amazon product is one kind"
    [
      "https://www.amazon.com/Logitech-MX-Master-3S-Graphite/dp/B0B6C5J6B8";
      "https://www.amazon.com/dp/B07FZ8S74R/ref=sr_1_1?keywords=mouse";
      "https://www.amazon.com/dp/B000000000";
    ];
  same "kind-jdcs every map place is one kind"
    [
      "https://www.google.com/maps/place/Warsaw/@52.2297,21.0122,12z";
      "https://www.google.com/maps/place/Krakow/@50.06,19.94,12z";
    ];
  same "kind-jdcs every books category is one kind"
    [
      "https://books.toscrape.com/catalogue/category/books/travel_2/index.html";
      "https://books.toscrape.com/catalogue/category/books/mystery_3/index.html";
    ];
  same "kind-jdcs every book is one kind"
    [
      "https://books.toscrape.com/catalogue/a-light-in-the-attic_1000/index.html";
      "https://books.toscrape.com/catalogue/tipping-the-velvet_999/index.html";
    ]

let session () =
  let kinds = K.session () in
  let first =
    K.observe kinds ~url:"https://allegro.pl/listing?string=a" ~title:"a - Allegro"
  in
  let again =
    K.observe kinds ~url:"https://allegro.pl/listing?string=b" ~title:"b - Allegro"
  in
  check_string "kind-dnye same shape keeps its name" first.name again.name;
  let other = K.observe kinds ~url:"https://allegro.pl/shop/listing" ~title:"Listing" in
  check_string "kind-dnye collision gets a numeric suffix" "listing-2" other.name;
  let pages = K.draft_pages kinds in
  Alcotest.(check int) "kind-s1k2 two draft pages" 2 (List.length pages);
  check_string "kind-s1k2 first pattern" "https://allegro.pl/listing"
    (List.hd pages).url_pattern;
  check_string "kind-s1k2 first name" "listing" (List.hd pages).name;
  check_string "kind-s1k2 second name" "listing-2" (List.nth pages 1).name;
  let declared, source =
    K.classify kinds ~declared:(Some "cart") ~url:"https://allegro.pl/koszyk"
      ~title:"Koszyk"
  in
  check_string "kind-4qke declared name wins" "cart" declared.name;
  Alcotest.(check bool) "kind-4qke declared is not inferred" true (source = K.Declared);
  let pages = K.draft_pages kinds in
  Alcotest.(check bool)
    "kind-4qke declared kind is not proposed" true
    (not (List.exists (fun page -> page.K.name = "cart") pages));
  Alcotest.(check int) "kind-4qke mapping unchanged" 2 (List.length pages)

let non_web_pages () =
  let kinds = K.session () in
  List.iter
    (fun url ->
      Alcotest.(check bool) ("kind-a7uy non-web " ^ url) false (K.is_page ~url);
      let inferred, _ = K.classify kinds ~declared:(Some "home") ~url ~title:"New Tab" in
      check_string "kind-a7uy no inferred or declared kind" "" inferred.name)
    [
      "about:blank";
      "chrome://newtab/";
      "chrome://settings/";
      "data:text/html,Hello";
      "file:///tmp/page.html";
      "ftp://example.com/";
    ];
  Alcotest.(check int)
    "kind-s1k2 no non-web draft pages" 0
    (List.length (K.draft_pages kinds))

let sibling_patterns () =
  List.iter
    (fun (first, second, expected, pattern) ->
      let kinds = K.session () in
      ignore (K.observe kinds ~url:first ~title:"");
      let merged = K.observe kinds ~url:second ~title:"" in
      check_string "kind-dnye sibling kind" expected merged.name;
      check_string "kind-dnye sibling pattern" pattern merged.url_pattern;
      let earlier = K.observe kinds ~url:first ~title:"" in
      check_string "kind-dnye earlier mapping updated" expected earlier.name;
      check_string "kind-dnye earlier pattern updated" pattern earlier.url_pattern;
      let pages = K.draft_pages kinds in
      Alcotest.(check int) "kind-s1k2 siblings propose one page" 1 (List.length pages);
      check_string "kind-s1k2 merged draft pattern" (K.playbook_pattern pattern)
        (List.hd pages).url_pattern)
    [
      ( "https://quotes.toscrape.com/tag/love/",
        "https://quotes.toscrape.com/tag/humor/",
        "tag-<slug>",
        "https://quotes.toscrape.com/tag/<slug>" );
      ( "https://example.com/topics/ocaml",
        "https://example.com/topics/rust",
        "topics-<slug>",
        "https://example.com/topics/<slug>" );
      ( "https://example.com/tag/love/page/2",
        "https://example.com/tag/humor/page/3",
        "tag-<slug>",
        "https://example.com/tag/<slug>/page/<id>" );
      ( "https://example.com/category/red.html",
        "https://example.com/category/blue.html",
        "category-<slug>",
        "https://example.com/category/<slug>.html" );
    ];
  List.iter
    (fun (first, second) ->
      let kinds = K.session () in
      ignore (K.observe kinds ~url:first ~title:"");
      ignore (K.observe kinds ~url:second ~title:"");
      Alcotest.(check int)
        "kind-dnye unrelated routes do not merge" 2
        (List.length (K.draft_pages kinds)))
    [
      ("https://example.com/login", "https://example.com/about");
      ("https://one.example/tag/love", "https://two.example/tag/humor");
      ("https://example.com/tag/love", "https://example.com/author/einstein");
      ("https://example.com/user/1/red", "https://example.com/user/2/blue");
      ("https://example.com/tag/1", "https://example.com/tag/love");
    ];
  let kinds = K.session () in
  List.iter
    (fun slug ->
      ignore (K.observe kinds ~url:("https://quotes.toscrape.com/tag/" ^ slug) ~title:""))
    [ "love"; "humor"; "wisdom" ];
  Alcotest.(check int)
    "kind-dnye later sibling reuses merge" 1
    (List.length (K.draft_pages kinds))

let executable_patterns () =
  List.iter
    (fun url ->
      let kinds = K.session () in
      let abstract = K.observe kinds ~url ~title:"Page" in
      let inferred = List.hd (K.draft_pages kinds) in
      Alcotest.(check bool)
        "map-bjon executable pattern has no inference placeholders" false
        (String.contains inferred.url_pattern '<');
      check_string "map-bjon inferred name becomes a valid declared slug"
        (K.playbook_name abstract.name)
        inferred.name;
      let page =
        Leash.Playbook.
          {
            name = inferred.name;
            description = "inferred";
            url_pattern = Some inferred.url_pattern;
            text_marker = None;
            repeatable = true;
          }
      in
      Alcotest.(check (option string))
        "map-bjon query and trailing path annotations resolve" (Some inferred.name)
        (Leash.Playbook.page_kind [ page ] ~url ~text:""))
    [
      "http://localhost:36089/agreement/123?stage=review";
      "http://127.0.0.1:36089/agreement/123";
      "https://example.com:8443/products/123?view=full";
      "https://example.com/list/page-2?sort=ascending#results";
      "https://example.com/products/12345?view=full";
      "https://books.toscrape.com/catalogue/category/books/mystery_3/index.html?sort=title#books";
      "https://www.google.com/maps/place/Paris/@48.85,2.35,12z/data=!3m1!4b1?entry=ttu";
    ];
  let explicit =
    Leash.Playbook.
      {
        name = "safe";
        description = "safe";
        url_pattern = Some "https://example.com/list?mode=safe";
        text_marker = None;
        repeatable = true;
      }
  in
  Alcotest.(check (option string))
    "map-bjon authored query conditions stay exact" None
    (Leash.Playbook.page_kind [ explicit ] ~url:"https://example.com/list?mode=unsafe"
       ~text:"")

(* kind-jdcs kind-s1k2 map-bjon: executable patterns retain the full web origin. *)
let origin_ports () =
  List.iter
    (fun (url, title, name, pattern, cleaned) ->
      let kinds = K.session () in
      let inferred = K.observe kinds ~url ~title in
      check_string "kind-jdcs port does not change kind name" name inferred.name;
      check_string "kind-jdcs inferred pattern retains explicit port" pattern
        inferred.url_pattern;
      check_string "kind-a7uy title uses hostname without port" cleaned inferred.title;
      let draft = List.hd (K.draft_pages kinds) in
      check_string "kind-s1k2 executable draft retains explicit port"
        (K.playbook_pattern pattern) draft.url_pattern)
    [
      ( "http://localhost:36089/agreement/123?stage=review",
        "Agreement - localhost",
        "agreement-<id>",
        "http://localhost:36089/agreement/<id>",
        "Agreement" );
      ( "http://127.0.0.1:36089/agreement/123",
        "Agreement - 127.0.0.1",
        "agreement-<id>",
        "http://127.0.0.1:36089/agreement/<id>",
        "Agreement" );
      ( "https://EXAMPLE.COM:8443/products/123?view=full",
        "Product - Example.com",
        "products-<id>",
        "https://example.com:8443/products/<id>",
        "Product" );
      ( "http://localhost:36089/",
        "Agreement - localhost",
        "home",
        "http://localhost:36089/",
        "Agreement" );
      ( "http://user:secret@localhost:36089/agreement/123",
        "Agreement - localhost",
        "agreement-<id>",
        "http://localhost:36089/agreement/<id>",
        "Agreement" );
      ( "http://localhost:80/agreement/123",
        "Agreement - localhost",
        "agreement-<id>",
        "http://localhost:80/agreement/<id>",
        "Agreement" );
      ( "https://example.com:443/products/123",
        "Product - Example.com",
        "products-<id>",
        "https://example.com:443/products/<id>",
        "Product" );
    ];
  let kinds = K.session () in
  ignore (K.observe kinds ~url:"http://localhost:36089/tag/love" ~title:"");
  ignore (K.observe kinds ~url:"http://localhost:36089/tag/humor" ~title:"");
  Alcotest.(check (list string))
    "kind-s1k2 sibling draft keeps origin port"
    [ "http://localhost:36089/tag/*" ]
    (List.map (fun (p : K.draft_page) -> p.url_pattern) (K.draft_pages kinds));
  ignore (K.observe kinds ~url:"http://localhost:36090/tag/humor" ~title:"");
  Alcotest.(check (list string))
    "kind-dnye different ports are distinct origins"
    [ "http://localhost:36089/tag/*"; "http://localhost:36090/tag/humor" ]
    (List.map (fun (p : K.draft_page) -> p.url_pattern) (K.draft_pages kinds))

let () =
  Alcotest.run "page kinds"
    [
      ( "inference",
        [
          Alcotest.test_case "kind-jdcs kind-s1k2 map-bjon explicit origin ports" `Quick
            origin_ports;
          Alcotest.test_case "map-bjon executable inferred patterns" `Quick
            executable_patterns;
          Alcotest.test_case "kind-a7uy non-web pages" `Quick non_web_pages;
          Alcotest.test_case "kind-dnye kind-s1k2 observed sibling table" `Quick
            sibling_patterns;
          Alcotest.test_case "kind-jdcs twenty real pairs" `Quick table;
          Alcotest.test_case "kind-dnye kind-s1k2 kind-4qke session" `Quick session;
        ] );
    ]
