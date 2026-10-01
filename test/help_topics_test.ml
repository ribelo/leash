(* hdoc-8c12 hdoc-ztwo hdoc-2264 hdoc-65jx: topics render, stay portable, and the
   embedded errors topic matches Protocol.Error_code. *)

let failf fmt = Printf.ksprintf failwith fmt

let contains hay needle =
  let n = String.length needle in
  let h = String.length hay in
  let rec loop i = i + n <= h && (String.sub hay i n = needle || loop (i + 1)) in
  loop 0

let render () =
  let sample =
    "# Title\n\n\
     Intro.\n\n\
     ## Section\n\n\
     - one\n\
     - two\n\n\
     | code | exit |\n\
     | --- | --- |\n\
     | alpha | 64 |\n\
     | beta | 65 |\n\n\
     ```json\n\
     {\"k\": 1}\n\
     ```\n"
  in
  let text = Leash_cli_support.Help_render.render sample in
  if contains text "\x1b" then failf "renderer emitted ANSI";
  if not (contains text "Title\n=====") then failf "h1 not underlined: %S" text;
  if not (contains text "Section\n-------") then failf "h2 not underlined: %S" text;
  if not (contains text "- one") then failf "list dropped";
  if (not (contains text "alpha  64")) && not (contains text "alpha   64") then
    if (not (contains text "alpha")) || not (contains text "64") then
      failf "table cells missing: %S" text;
  let alpha = String.index text 'a' in
  let _ = alpha in
  if not (contains text "{\"k\": 1}") then failf "fence not verbatim: %S" text;
  if contains text "```" then failf "fence markers leaked";
  let lines = String.split_on_char '\n' text |> List.filter (fun s -> s <> "") in
  let row =
    List.find_opt (fun line -> contains line "alpha" && contains line "64") lines
  in
  (match row with
  | None -> failf "no aligned table row: %S" text
  | Some line ->
      let beta = List.find (fun l -> contains l "beta") lines in
      let col a = String.index a '6' in
      if col line <> String.index beta '6' then
        failf "table columns not aligned:\n%s\n%s" line beta);
  print_endline "renderer: headings, lists, aligned table, verbatim fence, no ANSI"

let forbidden =
  [ "DSH_SESSION_ID"; "DSH"; "niri"; "/home/ribelo"; "~/.dotfiles"; "nixos-config" ]

let portable () =
  List.iter
    (fun (path, contents) ->
      List.iter
        (fun needle ->
          if contains contents needle then
            failf "embedded topic %s contains %S" path needle)
        forbidden;
      let rendered = Leash_cli_support.Help_render.render contents in
      if contains rendered "\x1b" then failf "%s rendered with ANSI" path)
    Leash_cli_support.Leash_help_data.topics;
  let names =
    Leash_cli_support.Leash_help_data.topics
    |> List.map (fun (path, _) -> Filename.chop_suffix path ".md")
    |> List.sort String.compare
  in
  List.iter
    (fun name -> if not (List.mem name names) then failf "missing embedded topic %s" name)
    [
      "handles";
      "playbooks";
      "authoring";
      "expectations";
      "drive";
      "scripts";
      "errors";
      "traces";
    ];
  let errors = List.assoc "errors.md" Leash_cli_support.Leash_help_data.topics in
  if errors <> Leash.Protocol.Error_code.topic_markdown then
    failf "embedded errors.md drifted from Protocol.Error_code";
  let skill = In_channel.with_open_bin "../skill/SKILL.md" In_channel.input_all in
  let lines = String.split_on_char '\n' skill in
  let n = List.length lines - if List.hd (List.rev lines) = "" then 1 else 0 in
  if n >= 60 then failf "SKILL.md is %d lines" n;
  if not (contains skill "leash help TOPIC") then
    failf "SKILL.md does not point at leash help";
  if
    not
      (contains skill
         "agent tabs close after 30 idle minutes; human tabs are never closed unless an \
          agent takes one")
  then failf "SKILL.md lacks the tab rule";
  print_endline "topics portable, errors live, skill under 60 lines"

(* hdoc-vqj7: the fresh-agent recovery/authoring answers must survive embedding. *)
let fresh_agent_guidance () =
  let topic name = List.assoc (name ^ ".md") Leash_cli_support.Leash_help_data.topics in
  List.iter
    (fun (name, needles) ->
      let contents = topic name in
      List.iter
        (fun needle ->
          if not (contains contents needle) then
            failf "hdoc-vqj7 %s missing %S" name needle)
        needles)
    [
      ( "handles",
        [
          "XDG_RUNTIME_DIR";
          "HOME";
          "service keeps its startup environment";
          "omits that id";
          "--url-prefix";
          "cross-origin";
          "Decline optional tracking";
          "persist in the managed Chrome profile";
          "refused click can scroll";
        ] );
      ("playbooks", [ "no source checkout is needed"; "navigate"; "step args" ]);
      ( "scripts",
        [
          "three argument locations";
          "text-helper model";
          "returned promise is awaited";
          "Top-level";
          "script-failed";
          "`_`";
        ] );
      ( "authoring",
        [
          "exactly once";
          "not an exactly-once guarantee";
          "model that scores available actions";
          "sampled field values";
          "must contain at least one goal";
        ] );
      ("drive", [ "child entries precede the parent"; "proposals" ]);
      ("errors", [ "leash help playbooks"; "engine error" ]);
    ];
  (* hdoc-vqj7: the first authoring JSON fence is a loadable navigation book. *)
  let rec fence = function
    | [] -> failf "hdoc-vqj7 no minimal JSON example"
    | "```json" :: rest -> rest
    | _ :: rest -> fence rest
  in
  let rec body = function
    | [] -> failf "hdoc-vqj7 unterminated JSON example"
    | "```" :: _ -> []
    | line :: rest -> line :: body rest
  in
  let json =
    topic "authoring" |> String.split_on_char '\n' |> fence |> body |> String.concat "\n"
    |> Yojson.Safe.from_string
  in
  (match Leash.Playbook.of_json ~file:"hdoc-vqj7.json" json with
  | Ok _ -> ()
  | Error why -> failf "hdoc-vqj7 minimal example does not load: %s" why);
  List.iter
    (fun (_, contents) ->
      if contains contents "examples/playbooks/" then
        failf "hdoc-vqj7 repository-only example reference")
    Leash_cli_support.Leash_help_data.topics

let () =
  Alcotest.run "help topics"
    [
      ( "hdoc",
        [
          Alcotest.test_case "render" `Quick render;
          Alcotest.test_case "portable" `Quick portable;
          Alcotest.test_case "hdoc-vqj7 fresh agent answers" `Quick fresh_agent_guidance;
        ] );
    ]
