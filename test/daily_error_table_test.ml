(* daily-u1k2 daily-3bwr daily-6pde daily-pb5a daily-azxe: every error code has an
   exit code, a hint, a docs/protocol.md row, and a line in error_help. Adding a code
   without them fails this test. *)

module P = Leash.Protocol

let failf fmt = Printf.ksprintf failwith fmt

let find_sub hay needle =
  let n = String.length needle in
  let h = String.length hay in
  let rec loop i =
    if i + n > h then None
    else if String.sub hay i n = needle then Some i
    else loop (i + 1)
  in
  loop 0

let contains hay needle = match find_sub hay needle with Some _ -> true | None -> false
let lines text = String.split_on_char '\n' text |> List.filter (fun line -> line <> "")

let error_section doc =
  let marker = "## Error codes\n" in
  match find_sub doc marker with
  | None -> failf "docs/protocol.md has no Error codes section"
  | Some at -> (
      let start = at + String.length marker in
      let rest = String.sub doc start (String.length doc - start) in
      match find_sub rest "\n## " with
      | None -> rest
      | Some stop -> String.sub rest 0 stop)

let row_code line =
  let prefix = "| `" in
  if not (String.starts_with ~prefix line) then None
  else
    let rest = String.sub line 3 (String.length line - 3) in
    match String.index_opt rest '`' with
    | None -> None
    | Some i ->
        let code = String.sub rest 0 i in
        let after = String.sub rest (i + 1) (String.length rest - i - 1) in
        if String.starts_with ~prefix:" |" after then Some code else None

let protocol_doc () =
  let path = "../docs/protocol.md" in
  try In_channel.with_open_bin path In_channel.input_all
  with Sys_error message ->
    failf
      "daily-u1k2 cannot read %s (%s); the dune stanza needs (deps ../docs/protocol.md)"
      path message

(* The metadata enumerator is not its own completeness oracle: a new variant can
   otherwise be forgotten in [all], docs and help together. Read the independent
   declared wire constructors, whose explicit names are part of the protocol. *)
let constructor_names () =
  let source =
    In_channel.with_open_bin "../packages/leash/protocol.ml" In_channel.input_all
  in
  let start = Option.get (find_sub source "type error_code =") in
  let rest = String.sub source start (String.length source - start) in
  let stop = Option.get (find_sub rest "[@@deriving yojson]") in
  String.sub rest 0 stop |> lines
  |> List.filter_map (fun line ->
      let line = String.trim line in
      if not (String.starts_with ~prefix:"| " line) then None
      else
        match String.split_on_char '"' line with
        | [ prefix; name; suffix ]
          when contains prefix "[@json.name" && contains suffix "]" ->
            Some name
        | _ -> failf "error-code constructor has no explicit wire name: %s" line)

let classes = [ 64; 65; 66; 69; 70; 75; 77; 124 ]

let wire code =
  match P.Error_code.of_string code with
  | Ok code -> code
  | Error message -> failf "%s" message

let four_way () =
  let declared = List.sort String.compare (constructor_names ()) in
  let enumerated =
    List.map P.Error_code.to_string P.Error_code.all |> List.sort String.compare
  in
  Alcotest.(check (list string)) "every declared code is enumerated" declared enumerated;
  let doc = error_section (protocol_doc ()) in
  let doc_lines = lines doc in
  let doc_codes = List.filter_map row_code doc_lines |> List.sort_uniq String.compare in
  let help_lines =
    lines P.error_help
    |> List.filter (fun line -> not (String.starts_with ~prefix:"#" line))
  in
  if P.error_help <> P.Error_code.error_help then
    failf "Protocol.error_help and Error_code.error_help differ";
  if not (String.starts_with ~prefix:"# code\t" P.error_help) then
    failf "error_help has no column header";
  let seen = Hashtbl.create 32 in
  List.iter
    (fun code ->
      let name = P.Error_code.to_string code in
      if Hashtbl.mem seen name then failf "duplicate code %s" name;
      Hashtbl.add seen name ();
      let exit = P.Error_code.exit_code code in
      let hint = P.Error_code.hint code in
      let meaning = P.Error_code.meaning code in
      if not (List.mem exit classes) then
        failf "%s exit %d is outside the documented classes" name exit;
      if hint = "" || meaning = "" then failf "%s has an empty hint or meaning" name;
      if String.contains hint '\n' || String.contains hint '\t' then
        failf "%s hint is not one line" name;
      if String.contains meaning '\n' || String.contains meaning '\t' then
        failf "%s meaning is not one line" name;
      let row = List.find_opt (fun line -> row_code line = Some name) doc_lines in
      (match row with
      | None -> failf "%s has no docs/protocol.md row" name
      | Some line ->
          if not (contains line ("| " ^ string_of_int exit ^ " |")) then
            failf "%s docs row lacks exit %d" name exit;
          if not (contains line hint) then failf "%s docs row lacks its hint" name;
          if not (contains line meaning) then failf "%s docs row lacks its meaning" name);
      let help =
        List.find_opt
          (fun line -> String.starts_with ~prefix:(name ^ "\t") line)
          help_lines
      in
      match help with
      | None -> failf "%s has no error_help line" name
      | Some line -> (
          if not (contains line ("\t" ^ string_of_int exit ^ "\t")) then
            failf "%s error_help line lacks exit %d" name exit;
          if not (contains line hint) then failf "%s error_help line lacks its hint" name;
          if not (contains line meaning) then
            failf "%s error_help line lacks its meaning" name;
          match P.Error_code.of_string name with
          | Ok back when back = code -> ()
          | Ok _ -> failf "%s of_string did not round-trip" name
          | Error message -> failf "%s of_string: %s" name message))
    P.Error_code.all;
  List.iter
    (fun name ->
      if not (Hashtbl.mem seen name) then
        failf "docs/protocol.md row %s is not an error code" name)
    doc_codes;
  List.iter
    (fun line ->
      match String.split_on_char '\t' line with
      | name :: _ when not (Hashtbl.mem seen name) ->
          failf "error_help line %s is not an error code" name
      | _ -> ())
    help_lines;
  if List.length doc_codes <> List.length P.Error_code.all then
    failf "docs rows %d <> codes %d" (List.length doc_codes)
      (List.length P.Error_code.all);
  if List.length help_lines <> List.length P.Error_code.all then
    failf "error_help lines %d <> codes %d" (List.length help_lines)
      (List.length P.Error_code.all)

let examples () =
  let check name expected =
    Alcotest.(check string) name expected (P.Error_code.hint (wire name))
  in
  check "stale-snapshot" "run `leash snap TAB` again and use its snapshot id";
  check "service-unreachable" "`systemctl --user start leash`, or pass --socket";
  Alcotest.(check int)
    "cli-parse exits 124" 124
    (P.Error_code.exit_code (wire "cli-parse"));
  Alcotest.(check int)
    "config-invalid is the configuration class" 65
    (P.Error_code.exit_code (wire "config-invalid"));
  Alcotest.(check int)
    "socket-permission is the permission class" 77
    (P.Error_code.exit_code (wire "socket-permission"))

let make_error_fills_hint () =
  List.iter
    (fun code ->
      let built = P.make_error code ~message:"daily-azxe" in
      if built.hint <> P.Error_code.hint code then
        failf "%s make_error hint drifted" (P.Error_code.to_string code);
      if built.detail <> None then failf "make_error invented a detail";
      let json = P.yojson_of_error built in
      (match json with
      | `Assoc fields ->
          if List.assoc_opt "hint" fields <> Some (`String built.hint) then
            failf "%s wire object omitted hint" (P.Error_code.to_string code);
          if List.assoc_opt "detail" fields <> None then
            failf "%s wire object kept an empty detail" (P.Error_code.to_string code)
      | _ -> failf "error did not encode as an object");
      match P.error_of_yojson json with
      | Ok back when back = built -> ()
      | Ok _ -> failf "%s error did not round-trip" (P.Error_code.to_string code)
      | Error message -> failf "%s decode: %s" (P.Error_code.to_string code) message)
    P.Error_code.all;
  let code = wire "tab-gone" in
  let detail = `Assoc [ ("disposition", `String "closed_by_owner") ] in
  let built = P.make_error ~detail code ~message:"gone" in
  match P.yojson_of_error built with
  | `Assoc fields ->
      if List.assoc_opt "detail" fields <> Some detail then
        failf "make_error dropped detail";
      if List.assoc_opt "hint" fields <> Some (`String (P.Error_code.hint code)) then
        failf "detailled error omitted hint"
  | _ -> failf "error did not encode as an object"

let () =
  Alcotest.run "daily-error-table"
    [
      ( "table",
        [
          Alcotest.test_case "daily-u1k2 four-way" `Quick four_way;
          Alcotest.test_case "daily-6pde spec hints" `Quick examples;
          Alcotest.test_case "daily-azxe make_error" `Quick make_error_fills_hint;
        ] );
    ]
