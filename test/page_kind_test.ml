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

let () =
  Alcotest.run "page kinds"
    [
      ( "inference",
        [
          Alcotest.test_case "kind-jdcs twenty real pairs" `Quick table;
          Alcotest.test_case "kind-dnye kind-s1k2 kind-4qke session" `Quick session;
        ] );
    ]
