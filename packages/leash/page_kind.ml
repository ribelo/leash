type t = { name : string; url_pattern : string; title : string }

let seps = [ " - "; " | "; " \u{2014} " ]
let is_hex_char = function '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true | _ -> false
let is_digit = function '0' .. '9' -> true | _ -> false

let percent_decode s =
  let buf = Buffer.create (String.length s) in
  let i = ref 0 in
  let ok = ref true in
  while !i < String.length s && !ok do
    match s.[!i] with
    | '%'
      when !i + 2 < String.length s && is_hex_char s.[!i + 1] && is_hex_char s.[!i + 2] ->
        let value c =
          match c with
          | '0' .. '9' -> Char.code c - Char.code '0'
          | 'a' .. 'f' -> Char.code c - Char.code 'a' + 10
          | 'A' .. 'F' -> Char.code c - Char.code 'A' + 10
          | _ -> 0
        in
        Buffer.add_char buf (Char.chr ((value s.[!i + 1] * 16) + value s.[!i + 2]));
        i := !i + 3
    | c ->
        Buffer.add_char buf c;
        incr i
  done;
  if !ok then Buffer.contents buf else s

let is_uuid s =
  let s = String.lowercase_ascii s in
  let hex_span a b =
    let rec go i = i > b || (is_hex_char s.[i] && go (i + 1)) in
    String.length s > b && go a
  in
  String.length s = 36
  && s.[8] = '-'
  && s.[13] = '-'
  && s.[18] = '-'
  && s.[23] = '-'
  && hex_span 0 7 && hex_span 9 12 && hex_span 14 17 && hex_span 19 22 && hex_span 24 35

let is_numeric s = s <> "" && String.for_all is_digit s
let is_hex s = String.length s >= 8 && String.for_all is_hex_char s
let has_digit s = String.exists is_digit s

let has_letter s =
  String.exists (function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false) s

let has_upper s = String.exists (function 'A' .. 'Z' -> true | _ -> false) s

let is_alnum s =
  s <> ""
  && String.for_all
       (function '0' .. '9' | 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false)
       s

(* Amazon ASINs are mixed alphanumeric with no separator. *)
let is_token_id s = String.length s >= 8 && is_alnum s && has_letter s && has_digit s

let count_char s c =
  let n = ref 0 in
  String.iter (fun ch -> if ch = c then incr n) s;
  !n

(* page-2 is a short word plus a counter. travel_2 is a content slug, not this. *)
let word_id stem =
  match String.rindex_opt stem '-' with
  | None -> None
  | Some i when i > 0 && i < String.length stem - 1 ->
      let word = String.sub stem 0 i in
      let digits = String.sub stem (i + 1) (String.length stem - i - 1) in
      if
        String.length word <= 12
        && String.for_all (function 'A' .. 'Z' | 'a' .. 'z' -> true | _ -> false) word
        && is_numeric digits
      then Some (String.lowercase_ascii word ^ "-<id>")
      else None
  | Some _ -> None

let ends_underscore_digits stem =
  match String.rindex_opt stem '_' with
  | None -> false
  | Some i ->
      let tail = String.sub stem (i + 1) (String.length stem - i - 1) in
      tail <> "" && is_numeric tail

(* =ref, @coordinates and !data are not page identity. *)
let is_noise s =
  String.contains s '=' || String.contains s '@' || String.contains s '!'
  || (String.contains s ',' && has_digit s)

let is_index s =
  match String.lowercase_ascii s with
  | "index" | "index.html" | "index.htm" | "index.php" -> true
  | _ -> false

let split_ext decoded =
  let lower = String.lowercase_ascii decoded in
  let cut suffix =
    if String.ends_with ~suffix lower then
      Some
        ( String.sub decoded 0 (String.length decoded - String.length suffix),
          String.lowercase_ascii suffix )
    else None
  in
  match cut ".html" with
  | Some pair -> pair
  | None -> (
      match cut ".htm" with
      | Some pair -> pair
      | None -> ( match cut ".php" with Some pair -> pair | None -> (decoded, "")))

(* kind-jdcs: ids and content slugs collapse; a short word-counter stays word-<id>. *)
let generalize_stem stem =
  if is_uuid stem then "<id>"
  else if is_numeric stem then "<id>"
  else if is_hex stem then "<id>"
  else if is_token_id stem then "<id>"
  else
    match word_id stem with
    | Some token -> token
    | None when ends_underscore_digits stem -> "<slug>"
    | None when String.length stem > 40 -> "<slug>"
    | None when count_char stem '-' >= 2 -> "<slug>"
    | None when String.contains stem '+' -> "<slug>"
    | None when has_upper stem -> "<slug>"
    | None -> String.lowercase_ascii stem

type piece = { pattern : string option; token : string option }

let piece_of raw =
  let decoded = percent_decode raw in
  if is_noise decoded then { pattern = None; token = None }
  else if is_index decoded then
    { pattern = Some (String.lowercase_ascii decoded); token = None }
  else
    let stem, ext = split_ext decoded in
    let token = generalize_stem stem in
    { pattern = Some (token ^ ext); token = Some token }

let is_placeholder s = s = "<id>" || s = "<slug>"

(* The last static segment, plus the placeholders that follow it. A word-<id>
   segment is itself the name when nothing follows. *)
let name_of tokens =
  let rev = List.rev tokens in
  let rec take_placeholders acc = function
    | s :: rest when is_placeholder s -> take_placeholders (s :: acc) rest
    | rest -> (acc, rest)
  in
  let placeholders, before = take_placeholders [] rev in
  match before with
  | stem :: _ ->
      if placeholders = [] then stem else stem ^ "-" ^ String.concat "-" placeholders
  | [] -> if placeholders = [] then "home" else "home-" ^ String.concat "-" placeholders

let take_until s stops =
  let stop =
    List.fold_left
      (fun best c ->
        match String.index_opt s c with Some i -> min best i | None -> best)
      (String.length s) stops
  in
  String.sub s 0 stop

let parse_url url =
  if url = "" || String.starts_with ~prefix:"about:" url then None
  else
    match String.index_opt url ':' with
    | None -> None
    | Some i when i + 3 <= String.length url && String.sub url i 3 = "://" ->
        let scheme = String.lowercase_ascii (String.sub url 0 i) in
        let rest = String.sub url (i + 3) (String.length url - i - 3) in
        let host_port = take_until rest [ '/'; '?'; '#' ] in
        (* kind-jdcs map-bjon: patterns keep origin ports, never userinfo. *)
        let authority =
          match String.rindex_opt host_port '@' with
          | None -> String.lowercase_ascii host_port
          | Some at ->
              String.lowercase_ascii
                (String.sub host_port (at + 1) (String.length host_port - at - 1))
        in
        let host =
          if String.starts_with ~prefix:"[" authority then
            match String.index_opt authority ']' with
            | Some last -> String.sub authority 0 (last + 1)
            | None -> authority
          else take_until authority [ ':' ]
        in
        let path_and_more =
          if String.length host_port = String.length rest then ""
          else
            String.sub rest (String.length host_port)
              (String.length rest - String.length host_port)
        in
        let path = take_until path_and_more [ '?'; '#' ] in
        if scheme = "http" || scheme = "https" then Some (scheme, host, authority, path)
        else None
    | _ -> None

let shape_of path =
  let pieces =
    String.split_on_char '/' path |> List.filter (fun s -> s <> "") |> List.map piece_of
  in
  let dropped = List.exists (fun piece -> piece.pattern = None) pieces in
  let kept = List.filter_map (fun piece -> piece.pattern) pieces in
  let tokens = List.filter_map (fun piece -> piece.token) pieces in
  (kept, tokens, dropped)

let pattern scheme host kept ~dropped =
  let path = match kept with [] -> "/" | segs -> "/" ^ String.concat "/" segs in
  scheme ^ "://" ^ host ^ path ^ if dropped then "*" else ""

let find_sep s =
  let found sep =
    let n = String.length sep in
    let rec scan i =
      if i + n > String.length s then None
      else if String.sub s i n = sep then Some (i, sep)
      else scan (i + 1)
    in
    scan 0
  in
  List.filter_map found seps
  |> List.fold_left
       (fun best hit ->
         match (best, hit) with
         | None, hit -> Some hit
         | Some (bi, _), (i, _) when i < bi -> Some hit
         | Some _, _ -> best)
       None

let rec split_title s =
  match find_sep s with
  | None -> [ s ]
  | Some (i, sep) ->
      let left = String.sub s 0 i in
      let right =
        String.sub s (i + String.length sep) (String.length s - i - String.length sep)
      in
      left :: split_title right

let strip_counter s =
  let rec loop s =
    let s = String.trim s in
    let n = String.length s in
    if n < 3 || s.[n - 1] <> ')' then s
    else
      let rec back i =
        if i < 0 then None
        else
          match s.[i] with
          | '(' -> Some i
          | '0' .. '9' | ',' | ' ' -> back (i - 1)
          | _ -> None
      in
      match back (n - 2) with
      | None -> s
      | Some i ->
          let inner = String.trim (String.sub s (i + 1) (n - i - 2)) in
          if
            inner <> ""
            && String.for_all (function '0' .. '9' | ',' -> true | _ -> false) inner
          then loop (String.sub s 0 i)
          else s
  in
  loop s

let site_names host =
  let bare =
    if String.starts_with ~prefix:"www." host then
      String.sub host 4 (String.length host - 4)
    else host
  in
  let first =
    match String.index_opt bare '.' with None -> bare | Some i -> String.sub bare 0 i
  in
  List.sort_uniq String.compare [ host; bare; first ]

let is_site_name names part =
  let part = String.lowercase_ascii (String.trim part) in
  part = ""
  || List.exists
       (fun name ->
         part = name
         || part = name ^ ".com"
         || part = name ^ ".pl"
         || part = name ^ ".co.uk")
       names

let clean_title ~host title =
  let names = site_names host in
  split_title title |> List.map strip_counter |> List.map String.trim
  |> List.filter (fun part -> part <> "" && not (is_site_name names part))
  |> String.concat " - "

(* kind-a7uy: browser-internal and non-web pages have no site identity. *)
let is_page ~url = Option.is_some (parse_url url)

let infer ~url ~title =
  match parse_url url with
  | None -> { name = ""; url_pattern = ""; title = String.trim title }
  | Some (scheme, host, authority, path) ->
      let kept, tokens, dropped = shape_of path in
      {
        name = name_of tokens;
        url_pattern = pattern scheme authority kept ~dropped;
        title = clean_title ~host title;
      }

type session = {
  mutable order : string list;
  by_pattern : (string, string) Hashtbl.t;
  aliases : (string, string) Hashtbl.t;
  name_uses : (string, int) Hashtbl.t;
}

let session () =
  {
    order = [];
    by_pattern = Hashtbl.create 16;
    aliases = Hashtbl.create 16;
    name_uses = Hashtbl.create 16;
  }

(* A name that already contains a placeholder is one kind for every page of that
   shape. Suffixes are only for two static names that happen to collide. *)
let assign t base =
  if String.contains base '<' then base
  else
    let used = match Hashtbl.find_opt t.name_uses base with None -> 0 | Some n -> n in
    Hashtbl.replace t.name_uses base (used + 1);
    if used = 0 then base else Printf.sprintf "%s-%d" base (used + 1)

let segments path = String.split_on_char '/' path |> List.filter (( <> ) "")

let segment_matches pattern value =
  if pattern = value then true
  else
    match (String.index_opt pattern '<', String.index_opt pattern '>') with
    | Some first, Some last
      when first < last
           && String.sub pattern first (last - first + 1) = "<slug>"
           && not (String.contains value '<') ->
        let prefix = String.sub pattern 0 first in
        let suffix = String.sub pattern (last + 1) (String.length pattern - last - 1) in
        String.starts_with ~prefix value && String.ends_with ~suffix value
    | _ -> false

let covers pattern value =
  match (parse_url pattern, parse_url value) with
  | Some (scheme, _, authority, path), Some (other_scheme, _, other_authority, other_path)
    when scheme = other_scheme && authority = other_authority ->
      let a = segments path and b = segments other_path in
      List.length a = List.length b && List.for_all2 segment_matches a b
  | _ -> false

(* kind-dnye kind-jdcs: observed sibling slugs, not a vocabulary of route names.
   A static prefix is required: unrelated root routes remain separate kinds. *)
let without_annotation pattern =
  if String.ends_with ~suffix:"*" pattern then
    String.sub pattern 0 (String.length pattern - 1)
  else pattern

let merge_pattern previous current =
  match (parse_url previous, parse_url current) with
  | Some (scheme, _, authority, path), Some (other_scheme, _, other_authority, other_path)
    when scheme = other_scheme && authority = other_authority ->
      let rec merge prefix difference a b =
        match (a, b) with
        | [], [] -> if difference then Some (List.rev prefix) else None
        | x :: xs, y :: ys when x = y -> merge (x :: prefix) difference xs ys
        | x :: xs, y :: ys
          when (not difference) && prefix <> []
               && (not (String.contains x '<' || String.contains y '<'))
               && List.for_all (fun s -> not (String.contains s '<')) prefix
               (* map-ngyr: a route before a dynamic argument is not a sibling
                  value (search/<slug> and place/<slug> are distinct routes). *)
               && match xs with s :: _ -> not (String.contains s '<') | [] -> true ->
            let _, ext = split_ext x and _, other_ext = split_ext y in
            if ext = other_ext then merge (("<slug>" ^ ext) :: prefix) true xs ys
            else None
        | _ -> None
      in
      Option.map
        (fun pieces -> pattern scheme authority pieces ~dropped:false)
        (merge [] false (segments path) (segments other_path))
  | _ -> None

let observe t ~url ~title =
  let inferred = infer ~url ~title in
  if not (is_page ~url) then inferred
  else
    let canonical =
      match Hashtbl.find_opt t.aliases inferred.url_pattern with
      | Some pattern -> Some pattern
      | None ->
          List.find_opt
            (fun pattern ->
              covers pattern inferred.url_pattern
              || String.ends_with ~suffix:"*" pattern
                 && without_annotation pattern = inferred.url_pattern)
            t.order
    in
    match canonical with
    | Some url_pattern ->
        Hashtbl.replace t.aliases inferred.url_pattern url_pattern;
        { inferred with name = Hashtbl.find t.by_pattern url_pattern; url_pattern }
    | None -> (
        match
          List.find_map
            (fun previous ->
              Option.map
                (fun merged -> (previous, merged))
                (if without_annotation previous = without_annotation inferred.url_pattern
                 then Some (without_annotation previous ^ "*")
                 else merge_pattern previous inferred.url_pattern))
            (List.rev t.order)
        with
        | Some (previous, url_pattern) ->
            let annotation_only =
              without_annotation previous = without_annotation url_pattern
            in
            let name =
              if annotation_only then Hashtbl.find t.by_pattern previous
              else
                match parse_url url_pattern with
                | None -> inferred.name
                | Some (_, _, _, path) ->
                    let rec prefix = function
                      | [] -> []
                      | piece :: rest ->
                          piece
                          ::
                          (if String.starts_with ~prefix:"<slug>" piece then []
                           else prefix rest)
                    in
                    let _, tokens, _ =
                      shape_of ("/" ^ String.concat "/" (prefix (segments path)))
                    in
                    name_of tokens
            in
            let name = if annotation_only then name else assign t name in
            let aliases =
              Hashtbl.fold
                (fun alias canonical acc ->
                  if canonical = previous then alias :: acc else acc)
                t.aliases []
            in
            List.iter (fun alias -> Hashtbl.replace t.aliases alias url_pattern) aliases;
            Hashtbl.replace t.aliases previous url_pattern;
            Hashtbl.replace t.aliases inferred.url_pattern url_pattern;
            Hashtbl.remove t.by_pattern previous;
            Hashtbl.replace t.by_pattern url_pattern name;
            t.order <- List.map (fun p -> if p = previous then url_pattern else p) t.order;
            { inferred with name; url_pattern }
        | None ->
            let name = assign t inferred.name in
            Hashtbl.add t.by_pattern inferred.url_pattern name;
            Hashtbl.add t.aliases inferred.url_pattern inferred.url_pattern;
            t.order <- inferred.url_pattern :: t.order;
            { inferred with name })

type source = Declared | Inferred

let classify t ~declared ~url ~title =
  match declared with
  | _ when not (is_page ~url) -> (infer ~url ~title, Inferred)
  | Some name ->
      let inferred = infer ~url ~title in
      ({ inferred with name }, Declared)
  | None -> (observe t ~url ~title, Inferred)

type draft_page = { name : string; url_pattern : string }

let playbook_placeholders ~id ~slug pattern =
  let replace piece =
    match
      List.find_opt
        (fun (token, _) -> String.starts_with ~prefix:token piece)
        [ ("id>", id); ("slug>", slug) ]
    with
    | Some (token, replacement) ->
        replacement
        ^ String.sub piece (String.length token)
            (String.length piece - String.length token)
    | None -> "<" ^ piece
  in
  match String.split_on_char '<' pattern with
  | first :: rest -> first ^ String.concat "" (List.map replace rest)
  | [] -> pattern

let playbook_pattern = playbook_placeholders ~id:"*" ~slug:"*"
let playbook_name = playbook_placeholders ~id:"id" ~slug:"slug"

let inferred_pages t =
  List.rev t.order
  |> List.map (fun url_pattern ->
      { name = Hashtbl.find t.by_pattern url_pattern; url_pattern })

let draft_pages t =
  let specificity (page : draft_page) =
    if String.contains page.url_pattern '*' then
      String.split_on_char '*' page.url_pattern |> String.concat "" |> String.length
    else max_int
  in
  inferred_pages t
  |> List.map (fun (page : draft_page) ->
      { name = playbook_name page.name; url_pattern = playbook_pattern page.url_pattern })
  (* map-ngyr: generated broad annotation patterns must not shadow their more
     specific routes when the draft becomes a first-match declared vocabulary. *)
  |> List.stable_sort (fun a b -> Int.compare (specificity b) (specificity a))
