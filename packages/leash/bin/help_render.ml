(* hdoc-8c12: a small markdown subset. Topics are written to it. *)

let drop_final_empty lines =
  match List.rev lines with "" :: rest -> List.rev rest | _ -> lines

let lines text = drop_final_empty (String.split_on_char '\n' text)

let is_fence line =
  let trimmed = String.trim line in
  String.starts_with ~prefix:"```" trimmed

let heading line =
  let rec count i =
    if i < String.length line && line.[i] = '#' then count (i + 1) else i
  in
  let level = count 0 in
  if level = 0 || level > 6 || level >= String.length line || line.[level] <> ' ' then
    None
  else
    Some
      (level, String.trim (String.sub line (level + 1) (String.length line - level - 1)))

let underline char text = text ^ "\n" ^ String.make (max 3 (String.length text)) char

let is_table_row line =
  let trimmed = String.trim line in
  String.length trimmed >= 2
  && trimmed.[0] = '|'
  && trimmed.[String.length trimmed - 1] = '|'

let is_separator line =
  let trimmed = String.trim line in
  String.length trimmed > 0
  && String.for_all (function '|' | '-' | ':' | ' ' | '\t' -> true | _ -> false) trimmed
  && String.contains trimmed '-'

let cells line =
  let trimmed = String.trim line in
  let inner = String.sub trimmed 1 (String.length trimmed - 2) in
  List.map String.trim (String.split_on_char '|' inner)

let pad cell width =
  let extra = width - String.length cell in
  if extra <= 0 then cell else cell ^ String.make extra ' '

let take width row =
  let rec go i acc =
    if i >= width then List.rev acc
    else
      let cell = match List.nth_opt row i with Some cell -> cell | None -> "" in
      go (i + 1) (cell :: acc)
  in
  go 0 []

let render_table rows =
  match rows with
  | [] -> ""
  | first :: _ ->
      let width = List.length first in
      let rows = List.map (take width) rows in
      let widths =
        List.init width (fun column ->
            List.fold_left
              (fun acc row -> max acc (String.length (List.nth row column)))
              0 rows)
      in
      rows
      |> List.map (fun row ->
          String.concat "  " (List.mapi (fun i cell -> pad cell (List.nth widths i)) row))
      |> String.concat "\n"

let strip_markup text =
  let len = String.length text in
  let buf = Buffer.create len in
  let rec go i =
    if i >= len then Buffer.contents buf
    else if i + 1 < len && text.[i] = '*' && text.[i + 1] = '*' then (
      let rec close j =
        if j + 1 >= len then None
        else if text.[j] = '*' && text.[j + 1] = '*' then Some j
        else close (j + 1)
      in
      match close (i + 2) with
      | Some j ->
          Buffer.add_substring buf text (i + 2) (j - i - 2);
          go (j + 2)
      | None ->
          Buffer.add_char buf text.[i];
          go (i + 1))
    else if text.[i] = '[' then (
      let rec bracket j =
        if j >= len then None else if text.[j] = ']' then Some j else bracket (j + 1)
      in
      match bracket (i + 1) with
      | Some j when j + 1 < len && text.[j + 1] = '(' -> (
          let rec paren k =
            if k >= len then None else if text.[k] = ')' then Some k else paren (k + 1)
          in
          match paren (j + 2) with
          | Some k ->
              Buffer.add_substring buf text (i + 1) (j - i - 1);
              go (k + 1)
          | None ->
              Buffer.add_char buf text.[i];
              go (i + 1))
      | _ ->
          Buffer.add_char buf text.[i];
          go (i + 1))
    else (
      Buffer.add_char buf text.[i];
      go (i + 1))
  in
  go 0

let render markdown =
  let input = lines markdown in
  let out = Buffer.create (String.length markdown) in
  let ends_with suffix =
    let n = Buffer.length out in
    let m = String.length suffix in
    n >= m && Buffer.sub out (n - m) m = suffix
  in
  let emit s =
    if Buffer.length out > 0 && not (ends_with "\n") then Buffer.add_char out '\n';
    Buffer.add_string out s;
    Buffer.add_char out '\n'
  in
  let emit_blank () =
    if Buffer.length out = 0 then ()
    else if not (ends_with "\n\n") then Buffer.add_char out '\n'
  in
  let rec loop = function
    | [] -> ()
    | line :: rest when is_fence line ->
        let rec take acc = function
          | [] -> (List.rev acc, [])
          | next :: tail when is_fence next -> (List.rev acc, tail)
          | next :: tail -> take (next :: acc) tail
        in
        let body, tail = take [] rest in
        emit_blank ();
        emit (String.concat "\n" body);
        emit_blank ();
        loop tail
    | line :: rest when is_table_row line ->
        let rec take acc = function
          | next :: tail when is_table_row next || is_separator next ->
              take (next :: acc) tail
          | other -> (List.rev acc, other)
        in
        let block, tail = take [ line ] rest in
        let rows =
          block |> List.filter (fun row -> not (is_separator row)) |> List.map cells
        in
        emit_blank ();
        emit (render_table rows);
        emit_blank ();
        loop tail
    | line :: rest -> (
        match heading line with
        | Some (1, text) ->
            emit_blank ();
            emit (underline '=' (strip_markup text));
            emit_blank ();
            loop rest
        | Some (_, text) ->
            emit_blank ();
            emit (underline '-' (strip_markup text));
            emit_blank ();
            loop rest
        | None when String.trim line = "" ->
            emit_blank ();
            loop rest
        | None ->
            emit (strip_markup line);
            loop rest)
  in
  loop input;
  let text = Buffer.contents out in
  if text = "" || ends_with "\n" then text else text ^ "\n"
