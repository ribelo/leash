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

(* The DOMSnapshot's document half: the string table, the nodes, and the flat parallel
   arrays aligned with [nodes.backendNodeId[i]] — attributes as
   [name, value, name, value, ...] indexes into [strings], and node names
   (docs/cdp-shapes.md, Chrome 152). *)
let dom_strings dom =
  let strings = Array.of_list (list (get "strings" dom)) in
  fun index ->
    if index >= 0 && index < Array.length strings then text strings.(index) else ""

let dom_nodes dom =
  match list (get "documents" dom) with doc :: _ -> get "nodes" doc | [] -> `Null

let dom_attribute dom name =
  let table = Hashtbl.create 16 in
  let string = dom_strings dom in
  let nodes = dom_nodes dom in
  let rec loop backends attributes =
    match (backends, attributes) with
    | backend :: backends, `List attributes :: rest ->
        let rec field = function
          | name_index :: value_index :: rest ->
              if string (integer name_index) = name then
                Hashtbl.replace table (integer backend) (string (integer value_index));
              field rest
          | _ -> ()
        in
        field attributes;
        loop backends rest
    | _ -> ()
  in
  loop (list (get "backendNodeId" nodes)) (list (get "attributes" nodes));
  table

(* tab-zc36: the placeholder is a DOM attribute, not an accessibility member. Chrome uses
   it as the accessible name when nothing else names the control, so this map matters for
   the case where an author's aria-label or title left the name empty, and the row still
   has to say what the control is for. *)
let placeholders dom =
  let table = Hashtbl.create 16 in
  Hashtbl.iter
    (fun backend placeholder ->
      if placeholder <> "" then Hashtbl.replace table backend placeholder)
    (dom_attribute dom "placeholder");
  table

(* The DOM's own node names, by backend id: a native [<option>] and an ARIA
   [role=option] node are both role [option] in the accessibility tree, and only the DOM
   half tells them apart. *)
let dom_node_names dom =
  let table = Hashtbl.create 128 in
  let string = dom_strings dom in
  let nodes = dom_nodes dom in
  let rec loop backends names =
    match (backends, names) with
    | backend :: backends, name_index :: rest ->
        Hashtbl.replace table (integer backend) (string (integer name_index));
        loop backends rest
    | _ -> ()
  in
  loop (list (get "backendNodeId" nodes)) (list (get "nodeName" nodes));
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

let true_prop key n =
  match prop key n with
  | Some (`Bool true) -> true
  | Some (`String "true") -> true
  | _ -> false

(* snapshot.js:68-71, the select branch: one action per option that is not selected, not
   disabled and not inside a disabled optgroup, its value the option's own value attribute
   and its index the one the select action takes. Chrome exposes a closed select's options
   under a [MenuListPopup] node (docs/cdp-shapes.md, L10) where they have no layout box, so
   the accessibility half is where they are read, and the DOM half says which of them are
   real [<option>] elements rather than ARIA options of a listbox. *)
let options ~by_id ~values ~names n =
  let rec descendants n =
    list (get "childIds" n)
    |> List.filter_map (fun id -> Hashtbl.find_opt by_id (text id))
    |> List.concat_map (fun child -> child :: descendants child)
  in
  let native node =
    match Hashtbl.find_opt names (integer (get "backendDOMNodeId" node)) with
    | Some "OPTION" -> true
    | _ -> false
  in
  let rec disabled node =
    true_prop "disabled" node
    ||
    match Hashtbl.find_opt by_id (text (get "parentId" node)) with
    | Some parent -> disabled parent
    | None -> false
  in
  descendants n
  |> List.filter (fun node -> role node = "option" && native node)
  |> List.mapi (fun index node ->
      let label = name node in
      let value =
        match Hashtbl.find_opt values (integer (get "backendDOMNodeId" node)) with
        | Some value when value <> "" -> value
        | _ -> label
      in
      P.
        {
          index;
          label;
          value;
          selected = true_prop "selected" node;
          disabled = disabled node;
        })

let rows ~ax ~dom ~width ~height ~scroll_x ~scroll_y =
  let visible = visible dom ~width ~height ~scroll_x ~scroll_y in
  let placeholders = placeholders dom in
  let values = dom_attribute dom "value" in
  let input_types = dom_attribute dom "type" in
  let names = dom_node_names dom in
  let nodes = list (get "nodes" ax) in
  let by_id = Hashtbl.create 128 in
  List.iter (fun n -> Hashtbl.replace by_id (text (get "nodeId" n)) n) nodes;
  let parent n = Hashtbl.find_opt by_id (text (get "parentId" n)) in
  (* snapshot.js:68 branches on the DOM tag, so a row carries options exactly when it is a
     native [<select>]: every other combobox — an input with a datalist, an ARIA combobox —
     carries none, and the request reads it as the text control it is. *)
  let options_of role n =
    let backend = integer (get "backendDOMNodeId" n) in
    if
      List.mem role [ "combobox"; "listbox" ]
      && Hashtbl.find_opt names backend = Some "SELECT"
    then Some (options ~by_id ~values ~names n)
    else None
  in
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
          && not
               (Hashtbl.find_opt names backend = Some "INPUT"
               && List.mem
                    (String.lowercase_ascii
                       (Option.value ~default:"text"
                          (Hashtbl.find_opt input_types backend)))
                    [ "password"; "file"; "hidden" ])
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
            ( {
                P.index = 0;
                role = effective_role;
                name = label;
                value;
                state = states n;
                options = options_of effective_role n;
              },
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
