module P = Protocol

let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None
let get key json = Option.value ~default:`Null (field key json)
let list = function `List xs -> xs | _ -> []
let integer = function `Int n -> n | _ -> -1
let number = function `Int n -> float n | `Float x -> x | _ -> 0.
let text = function `String s -> s | _ -> ""
let value json = get "value" json

(* Run in the main world before page scripts on each new document. A new epoch catches
   reloads even if a loader id is unavailable; same-document history retains the observer. *)
let counter_script =
  {|(() => {
  if (window.__leashSnapshotGuard) return;
  const epoch = Array.from(crypto.getRandomValues(new Uint32Array(4))).join('-');
  let count = 0;
  new MutationObserver(() => { count++; }).observe(document,
    {subtree:true, childList:true, attributes:true, characterData:true});
  Object.defineProperty(window, '__leashSnapshotGuard', {
    value: () => ({epoch, count, width: innerWidth, height: innerHeight,
                   scrollX, scrollY}),
    configurable:false, writable:false
  });
})()|}

let guard_expression = "window.__leashSnapshotGuard?.()"

let guard json =
  match (get "epoch" json, get "count" json) with
  | `String epoch, `Int count when epoch <> "" ->
      Some
        ( epoch,
          count,
          number (get "width" json),
          number (get "height" json),
          number (get "scrollX" json),
          number (get "scrollY" json) )
  | _ -> None

(* DOMSnapshot bounds are in document CSS coordinates, not viewport coordinates.
   Clip against the viewport translated by the guard's scroll position (tab-tmoc). *)
let visible dom ~width ~height ~scroll_x ~scroll_y =
  let result = Hashtbl.create 128 in
  (match list (get "documents" dom) with
  | doc :: _ ->
      let nodes = get "nodes" doc in
      let backends = Array.of_list (list (get "backendNodeId" nodes)) in
      let layout = get "layout" doc in
      let indices = list (get "nodeIndex" layout) in
      let bounds = list (get "bounds" layout) in
      let styles = list (get "styles" layout) in
      let strings = Array.of_list (list (get "strings" dom)) in
      let style idx =
        if idx >= 0 && idx < Array.length strings then text strings.(idx) else ""
      in
      let rec loop indices bounds styles =
        match (indices, bounds, styles) with
        | index :: is, rect :: rs, style_indices :: ss ->
            let i = integer index in
            (match rect with
            | `List [ x; y; w; h ]
              when i >= 0
                   && i < Array.length backends
                   && number w > 0.
                   && number h > 0.
                   && number x +. number w > scroll_x
                   && number y +. number h > scroll_y
                   && number x < scroll_x +. width
                   && number y < scroll_y +. height ->
                let css = List.map (fun x -> style (integer x)) (list style_indices) in
                if not (List.mem "none" css || List.mem "hidden" css) then
                  Hashtbl.replace result (integer backends.(i)) ()
            | _ -> ());
            loop is rs ss
        | _ -> ()
      in
      loop indices bounds styles
  | [] -> ());
  result

(* tab-zc36: the placeholder is a DOM attribute, not an accessibility member. Chrome uses
   it as the accessible name when nothing else names the control, so this map matters for
   the case where an author's aria-label or title left the name empty, and the row still
   has to say what the control is for. The DOMSnapshot carries the attributes inline:
   [nodes.attributes[i]] is a flat [name, value, name, value, ...] array of indexes into
   [strings], aligned with [nodes.backendNodeId[i]] (docs/cdp-shapes.md, Chrome 152). *)
let placeholders dom =
  let table = Hashtbl.create 16 in
  (match list (get "documents" dom) with
  | doc :: _ ->
      let strings = Array.of_list (list (get "strings" dom)) in
      let string index =
        if index >= 0 && index < Array.length strings then text strings.(index) else ""
      in
      let nodes = get "nodes" doc in
      let rec loop backends attributes =
        match (backends, attributes) with
        | backend :: backends, `List attributes :: rest ->
            let rec field = function
              | name :: value :: rest ->
                  (if string (integer name) = "placeholder" then
                     let placeholder = string (integer value) in
                     if placeholder <> "" then
                       Hashtbl.replace table (integer backend) placeholder);
                  field rest
              | _ -> ()
            in
            field attributes;
            loop backends rest
        | _ -> ()
      in
      loop (list (get "backendNodeId" nodes)) (list (get "attributes" nodes))
  | [] -> ());
  table

(* A row whose role is only informative still needs a name, or the table fills with
   unnamed decoration; a control is worth a row either way (tab-zc36). *)
let informative = [ "heading"; "paragraph"; "img"; "status"; "alert" ]
let role n = text (value (get "role" n))
let name n = text (value (get "name" n))

let prop key n =
  list (get "properties" n)
  |> List.find_opt (fun p -> get "name" p = `String key)
  |> Option.map (fun p -> value (get "value" p))

let state name n =
  let state =
    match P.Row_state.of_string name with Ok x -> x | Error _ -> assert false
  in
  match prop name n with
  | Some (`Bool true) -> Some state
  | Some (`String s) when s = "true" -> Some state
  | _ -> None

let states n =
  let checked =
    match prop "checked" n with
    | Some (`String "mixed") -> (
        match P.Row_state.of_string "mixed" with Ok x -> [ x ] | Error _ -> [])
    | Some (`Bool false | `String "false") -> (
        match P.Row_state.of_string "unchecked" with Ok x -> [ x ] | Error _ -> [])
    | _ -> Option.to_list (state "checked" n)
  in
  let expanded =
    match prop "expanded" n with
    | Some (`Bool false | `String "false") -> (
        match P.Row_state.of_string "collapsed" with Ok x -> [ x ] | Error _ -> [])
    | _ -> Option.to_list (state "expanded" n)
  in
  let other =
    List.filter_map
      (fun key -> state key n)
      [ "selected"; "disabled"; "required"; "readonly" ]
  in
  match checked @ expanded @ other with [] -> None | xs -> Some xs

let rows ~ax ~dom ~width ~height ~scroll_x ~scroll_y =
  let visible = visible dom ~width ~height ~scroll_x ~scroll_y in
  let placeholders = placeholders dom in
  let nodes = list (get "nodes" ax) in
  let by_id = Hashtbl.create 128 in
  List.iter (fun n -> Hashtbl.replace by_id (text (get "nodeId" n)) n) nodes;
  let parent n = Hashtbl.find_opt by_id (text (get "parentId" n)) in
  let included =
    [
      "heading";
      "paragraph";
      "link";
      "button";
      "textbox";
      "checkbox";
      "radio";
      "combobox";
      "listbox";
      "option";
      "switch";
      "menuitem";
      "searchbox";
      "slider";
      "spinbutton";
      "img";
      "status";
      "alert";
      "tab";
      "treeitem";
    ]
  in
  let seen = Hashtbl.create 128 in
  let rec walk n =
    let id = text (get "nodeId" n) in
    if Hashtbl.mem seen id then []
    else (
      Hashtbl.add seen id ();
      let r = role n in
      let effective_role, effective_node =
        if r = "StaticText" then
          match parent n with
          | Some p when role p = "paragraph" -> ("paragraph", p)
          | _ -> ("", n)
        else if r = "DisclosureTriangle" then ("button", n)
        else (r, n)
      in
      let backend = integer (get "backendDOMNodeId" effective_node) in
      let label = name n in
      (* tab-zc36: an empty-name control keeps its row, with the value it holds now or,
         when it holds none, the placeholder that is the only other thing telling an agent
         what it is. *)
      let here =
        if
          List.mem effective_role included
          && (label <> "" || not (List.mem effective_role informative))
          && get "ignored" n <> `Bool true
          && backend >= 0 && Hashtbl.mem visible backend
        then
          let value =
            match get "value" n with
            | `Assoc _ as v -> (
                match value v with `String s when s <> "" -> Some s | _ -> None)
            | `String s when s <> "" -> Some s
            | _ -> None
          in
          let value =
            match value with
            | Some value -> Some value
            | None -> if label = "" then Hashtbl.find_opt placeholders backend else None
          in
          [
            ( { P.index = 0; role = effective_role; name = label; value; state = states n },
              backend );
          ]
        else []
      in
      let children =
        list (get "childIds" n)
        |> List.filter_map (fun id -> Hashtbl.find_opt by_id (text id))
      in
      here @ List.concat_map walk children)
  in
  let roots = List.filter (fun n -> field "parentId" n = None) nodes in
  let raw = List.concat_map walk roots in
  List.mapi
    (fun index ((row : P.row), backend) -> ({ row with index = index + 1 }, backend))
    raw
