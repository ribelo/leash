(* map-op09: page text never enters this projection. Both browser traversal and
   host formatting are bounded; only element tags and class tokens survive. *)
let collection mission =
  let mission = String.lowercase_ascii mission in
  let has pattern =
    try
      ignore (Str.search_forward (Str.regexp pattern) mission 0);
      true
    with Not_found -> false
  in
  has "\\bcollect\\b" || has "\\blist\\b" || has "\\bevery\\b" || has "\\ball\\b"

let expression =
  {|(() => {
  const classes = e => Array.from(e.classList).slice(0, 8).filter(c => /^[A-Za-z_][A-Za-z0-9_-]{0,63}$/.test(c));
  const key = e => e.tagName.toLowerCase() + '.' + classes(e).join('.');
  let budget = 256;
  const skeleton = (e, depth) => {
    if (budget-- <= 0 || depth > 5) return null;
    return {tag: e.tagName.toLowerCase(), classes: classes(e),
      children: depth === 5 ? [] : Array.from(e.children).slice(0, 12).map(c => skeleton(c, depth + 1)).filter(Boolean)};
  };
  const groups = [], seen = new Set();
  for (const parent of Array.from(document.querySelectorAll('body *')).slice(0, 5000)) {
    const children = Array.from(parent.children).slice(0, 100);
    const counts = new Map();
    for (const child of children) { const k = key(child); counts.set(k, (counts.get(k) || 0) + 1); }
    for (const child of children) {
      const k = key(child);
      if (counts.get(k) < 2 || seen.has(k) || child.children.length < 2) continue;
      seen.add(k); groups.push(child);
    }
    if (groups.length >= 16) break;
  }
  groups.sort((a, b) => b.querySelectorAll('*').length - a.querySelectorAll('*').length);
  return groups.slice(0, 8).map(e => skeleton(e, 0)).filter(Boolean);
})()|}

let decode json =
  let out = Buffer.create 4096 and nodes = ref 0 in
  let identifier ~tag value =
    String.length value > 0
    && String.length value <= 64
    && String.for_all
         (function
           | 'a' .. 'z' | '0' .. '9' | '-' -> true
           | ('A' .. 'Z' | '_') when not tag -> true
           | _ -> false)
         value
    &&
    match value.[0] with
    | 'a' .. 'z' -> true
    | ('A' .. 'Z' | '_') when not tag -> true
    | _ -> false
  in
  let rec node depth = function
    | `Assoc fields when depth <= 5 && !nodes < 256 -> (
        match
          ( List.assoc_opt "tag" fields,
            List.assoc_opt "classes" fields,
            List.assoc_opt "children" fields )
        with
        | Some (`String tag), Some (`List classes), Some (`List children)
          when identifier ~tag:true tag ->
            incr nodes;
            let classes =
              List.filter_map
                (function `String c when identifier ~tag:false c -> Some c | _ -> None)
                classes
              |> List.filteri (fun i _ -> i < 8)
            in
            let line =
              String.make (depth * 2) ' '
              ^ tag
              ^ String.concat "" (List.map (fun c -> "." ^ c) classes)
              ^ "\n"
            in
            if Buffer.length out + String.length line <= 4096 then (
              Buffer.add_string out line;
              List.iteri (fun i child -> if i < 12 then node (depth + 1) child) children)
        | _ -> ())
    | _ -> ()
  in
  (match json with
  | `List nodes -> List.iteri (fun i n -> if i < 8 then node 0 n) nodes
  | _ -> ());
  if Buffer.length out = 0 then None else Some (Buffer.contents out)
