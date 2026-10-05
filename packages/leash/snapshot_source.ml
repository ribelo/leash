module P = Protocol

let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None
let get key json = Option.value ~default:`Null (field key json)
let list = function `List xs -> xs | _ -> []
let integer = function `Int n -> n | _ -> -1
let number = function `Int n -> float n | `Float x -> x | _ -> 0.
let text = function `String s -> s | _ -> ""
let value json = get "value" json

(* Run in the isolated world before page scripts on each new document. A new epoch catches
   reloads even if a loader id is unavailable; same-document history retains the observer. *)
let world_name = "leash"

let counter_script =
  {|(() => {
  if (window.__leashSnapshotGuard) return;
  const epoch = Array.from(crypto.getRandomValues(new Uint32Array(4))).join('-');
  let count = 0;
  new MutationObserver(() => { count++; }).observe(document,
    {subtree:true, childList:true, attributes:true, characterData:true});
  Object.defineProperty(window, '__leashSnapshotGuard', {
    value: () => ({epoch, count, width: innerWidth, height: innerHeight,
                   scrollX, scrollY, devicePixelRatio}),
    configurable:false, writable:false
  });
})()|}

let guard_expression = "window.__leashSnapshotGuard?.()"

(* field-lp65: intentionally cheap; hidden controls count too, so a loading application
   cannot be declared ready just because its controls do not have layout yet. *)
let interactive_selector =
  "a[href],button,input:not([type=hidden]),select,textarea,[role=button],[role=link],[role=textbox],[role=searchbox],[role=checkbox],[role=radio],[role=combobox],[role=listbox],[role=option],[role=switch],[role=menuitem],[role=slider],[role=spinbutton],[role=tab],[role=treeitem],[contenteditable]:not([contenteditable=false]),[tabindex]:not([tabindex='-1'])"

let interactive_count_expression =
  Printf.sprintf "document.querySelectorAll(%s).length"
    (Yojson.Safe.to_string (`String interactive_selector))

let interactive (row : P.row) =
  not (List.mem row.role [ "heading"; "paragraph"; "img"; "status"; "alert"; "frame" ])

let guard json =
  match (get "epoch" json, get "count" json) with
  | `String epoch, `Int count when epoch <> "" ->
      let scale = number (get "devicePixelRatio" json) in
      let scale = if scale > 0. then scale else 1. in
      let scaled key = number (get key json) *. scale in
      Some
        (epoch, count, scaled "width", scaled "height", scaled "scrollX", scaled "scrollY")
  | _ -> None

(* Chrome DOMSnapshot bounds are device-scaled document coordinates (daily-9ggi),
   unlike getBoundingClientRect. The guard scales the CSS viewport and scroll together;
   clipping stays correct on HiDPI displays and after scrolling (tab-tmoc). *)
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
(* field-cct4: inputValue is the live DOM property, not the stale value attribute or AX cache. *)
let input_values dom =
  let table = Hashtbl.create 16 in
  let nodes = dom_nodes dom in
  let backends = Array.of_list (list (get "backendNodeId" nodes)) in
  let strings = Array.of_list (list (get "strings" dom)) in
  let sparse = get "inputValue" nodes in
  let rec collect indices values =
    match (indices, values) with
    | index :: indices, value :: values ->
        let i = integer index in
        let v = integer value in
        (if i >= 0 && i < Array.length backends && v >= 0 && v < Array.length strings then
           match strings.(v) with
           | `String value -> Hashtbl.replace table (integer backends.(i)) value
           | _ -> ());
        collect indices values
    | _ -> ()
  in
  collect (list (get "index" sparse)) (list (get "value" sparse));
  table

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

let row_role = function
  | "DisclosureTriangle" -> "button"
  | "InputTime" | "Date" | "DateTime" -> "textbox"
  | role -> role

let role n = text (value (get "role" n))
let name n = text (value (get "name" n))

(* field-lp65: readiness belongs to the raw tree, not viewport-clipped rows. A page
   scrolled beyond every control still has a populated AX tree. *)
let has_interactive ax =
  List.exists
    (fun n ->
      get "ignored" n <> `Bool true
      && integer (get "backendDOMNodeId" n) > 0
      && List.mem
           (row_role (role n))
           [
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
             "tab";
             "treeitem";
           ])
    (list (get "nodes" ax))

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
        match P.Row_state.of_string "mixed" with
        | Ok x -> [ x ]
        | Error _ ->
            [] [@ox.allow "ox-discarded-result: a constant state name always decodes"])
    | Some (`Bool false | `String "false") -> (
        match P.Row_state.of_string "unchecked" with
        | Ok x -> [ x ]
        | Error _ ->
            [] [@ox.allow "ox-discarded-result: a constant state name always decodes"])
    | _ -> Option.to_list (state "checked" n)
  in
  let expanded =
    match prop "expanded" n with
    | Some (`Bool false | `String "false") -> (
        match P.Row_state.of_string "collapsed" with
        | Ok x -> [ x ]
        | Error _ ->
            [] [@ox.allow "ox-discarded-result: a constant state name always decodes"])
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

(* hard-2gnf: a file input is the one control an upload needs and the one a snapshot used
   to lose — Chrome shows a button and a "no file chosen" label for it, and pages hide the
   input itself behind a styled button of their own, so it has no box and the visible-only
   rule would never list it. Each `<input type=file>` of the document is a row of the role
   [file-input], visible or not, placed in document order among the rows around it. Its
   name is what the accessibility tree calls it when that says something, otherwise the
   author's own words for it (aria-label, title, name, id). *)
let file_inputs ~dom ~ax_by_backend =
  (* pilot-h506: an attached file shows as the row's value, the name Chrome reports after
     its fakepath directory prefix, so the pilot sees the upload took (U9 re-attached the
     file every turn instead of submitting). *)
  let attached = input_values dom in
  let attached backend =
    match Hashtbl.find_opt attached backend with
    | None | Some "" -> None
    | Some value ->
        let cut =
          max
            (String.rindex_opt value '\\' |> Option.value ~default:(-1))
            (String.rindex_opt value '/' |> Option.value ~default:(-1))
        in
        Some (String.sub value (cut + 1) (String.length value - cut - 1))
  in
  let string = dom_strings dom in
  let nodes = dom_nodes dom in
  let backends = list (get "backendNodeId" nodes) in
  let names = list (get "nodeName" nodes) in
  let types = dom_attribute dom "type" in
  let attr name = dom_attribute dom name in
  let aria = attr "aria-label" and title = attr "title" in
  let name_attr = attr "name" and id = attr "id" in
  let disabled = attr "disabled" and required = attr "required" in
  let state wanted present backend =
    match P.Row_state.of_string wanted with
    | Ok s when Hashtbl.mem present backend -> [ s ]
    | Ok _ -> []
    | Error _ ->
        [] [@ox.allow "ox-discarded-result: a constant state name always decodes"]
  in
  let rec collect position backends names =
    match (backends, names) with
    | backend :: backends, node_name :: names ->
        let backend = integer backend in
        let rest = collect (position + 1) backends names in
        if
          string (integer node_name) = "INPUT"
          && String.lowercase_ascii
               (Option.value ~default:"" (Hashtbl.find_opt types backend))
             = "file"
        then
          let first table = Hashtbl.find_opt table backend |> Option.to_list in
          let label =
            let from_ax =
              match Hashtbl.find_opt ax_by_backend backend with
              | Some n -> name n
              | None -> ""
            in
            if from_ax <> "" then from_ax
            else
              match
                List.concat_map first [ aria; title; name_attr; id ]
                |> List.find_opt (fun s -> s <> "")
              with
              | Some s -> s
              | None -> ""
          in
          let states =
            state "disabled" disabled backend @ state "required" required backend
          in
          ( position,
            backend,
            label,
            (if states = [] then None else Some states),
            attached backend )
          :: rest
        else rest
    | _ -> []
  in
  collect 0 backends names

let rows ~ax ~dom ~width ~height ~scroll_x ~scroll_y =
  let input_values = input_values dom in
  let visible = visible dom ~width ~height ~scroll_x ~scroll_y in
  let placeholders = placeholders dom in
  let values = dom_attribute dom "value" in
  let input_types = dom_attribute dom "type" in
  let names = dom_node_names dom in
  let nodes = list (get "nodes" ax) in
  let by_id = Hashtbl.create 128 in
  List.iter (fun n -> Hashtbl.replace by_id (text (get "nodeId" n)) n) nodes;
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
  let children n =
    list (get "childIds" n)
    |> List.filter_map (fun id -> Hashtbl.find_opt by_id (text id))
  in
  (* daily-9ggi: a paragraph may contain a span per character. Aggregate its text once,
     without swallowing separately actionable descendants or duplicating nested rows. *)
  let rec paragraph_text n =
    if role n = "StaticText" then name n
    else if role n = "LineBreak" then "\n"
    else if List.mem (row_role (role n)) included then ""
    else String.concat "" (List.map paragraph_text (children n))
  in
  let seen = Hashtbl.create 128 in
  let rec walk n =
    let id = text (get "nodeId" n) in
    if Hashtbl.mem seen id then []
    else (
      Hashtbl.add seen id ();
      let r = role n in
      let effective_role = row_role r in
      let backend = integer (get "backendDOMNodeId" n) in
      let label =
        if r = "paragraph" && name n = "" then
          String.concat "" (List.map paragraph_text (children n))
        else name n
      in
      (* tab-zc36: an empty-name control keeps its row, with the value it holds now or,
         when it holds none, the placeholder that is the only other thing telling an agent
         what it is. *)
      (* field-8bzc field-sazr: the agent's table lists a password input — the agent is
         the party that types it, by index — as a textbox marked [password] that never
         carries a value. File inputs are added below as file-input rows; hidden inputs are
         never rows. The operator's table (what JEV is offered) drops password rows again
         in {!Jev_request.elements} (fly-eoqg): two readers, two rules. *)
      let input_type =
        if Hashtbl.find_opt names backend = Some "INPUT" then
          Some
            (String.lowercase_ascii
               (Option.value ~default:"text" (Hashtbl.find_opt input_types backend)))
        else None
      in
      let password = input_type = Some "password" in
      let here =
        if
          (List.mem effective_role included || password)
          && (label <> "" || password || not (List.mem effective_role informative))
          && get "ignored" n <> `Bool true
          && backend >= 0 && Hashtbl.mem visible backend
          && not (List.mem input_type [ Some "file"; Some "hidden" ])
        then
          if password then
            [
              ( {
                  P.index = 0;
                  role = "textbox";
                  name = label;
                  value = None;
                  state =
                    Some
                      (Option.value ~default:[] (states n)
                      @ [
                          (match P.Row_state.of_string "password" with
                          | Ok x -> x
                          | Error _ -> assert false);
                        ]);
                  options = None;
                  box = None;
                },
                backend );
            ]
          else
            let value =
              match Hashtbl.find_opt input_values backend with
              | Some "" -> None
              | Some s -> Some s
              | None -> (
                  let ax_value =
                    match get "value" n with
                    | `Assoc _ as v -> (
                        match value v with `String s when s <> "" -> Some s | _ -> None)
                    | `String s when s <> "" -> Some s
                    | _ -> None
                  in
                  match ax_value with
                  | Some _ -> ax_value
                  | None -> (
                      match Hashtbl.find_opt values backend with
                      | Some "" | None -> None
                      | Some value -> Some value))
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
                  box = None;
                },
                backend );
            ]
        else []
      in
      here @ List.concat_map walk (children n))
  in
  let roots = List.filter (fun n -> field "parentId" n = None) nodes in
  let raw = List.concat_map walk roots in
  let raw =
    let ax_by_backend = Hashtbl.create 64 in
    List.iter
      (fun n ->
        let backend = integer (get "backendDOMNodeId" n) in
        if backend >= 0 && get "ignored" n <> `Bool true then
          Hashtbl.replace ax_by_backend backend n)
      nodes;
    let order = Hashtbl.create 128 in
    List.iteri
      (fun position backend -> Hashtbl.replace order (integer backend) position)
      (list (get "backendNodeId" (dom_nodes dom)));
    let position (_, backend) =
      Option.value ~default:max_int (Hashtbl.find_opt order backend)
    in
    List.fold_left
      (fun rows (at, backend, label, state, value) ->
        let row =
          ( {
              P.index = 0;
              role = "file-input";
              name = label;
              value;
              state;
              options = None;
              box = None;
            },
            backend )
        in
        let rec place = function
          | [] -> [ row ]
          | next :: rest as all ->
              if position next > at then row :: all else next :: place rest
        in
        place rows)
      raw
      (file_inputs ~dom ~ax_by_backend)
  in
  List.mapi
    (fun index ((row : P.row), backend) -> ({ row with index = index + 1 }, backend))
    raw

(* field-vji1: only the src origin is exposed; frame documents are never inspected. *)
let url_origin url =
  let url = String.trim url |> String.lowercase_ascii in
  let scheme, start =
    if String.starts_with ~prefix:"https://" url then ("https", 8)
    else if String.starts_with ~prefix:"http://" url then ("http", 7)
    else ("", 0)
  in
  if scheme = "" then None
  else
    let rec scan i =
      if i = String.length url || List.mem url.[i] [ '/'; '?'; '#'; '\\' ] then i
      else scan (i + 1)
    in
    let stop = scan start in
    let authority = String.sub url start (stop - start) in
    let authority =
      match String.rindex_opt authority '@' with
      | None -> authority
      | Some at -> String.sub authority (at + 1) (String.length authority - at - 1)
    in
    let port = if scheme = "https" then ":443" else ":80" in
    let authority =
      if String.ends_with ~suffix:port authority then
        String.sub authority 0 (String.length authority - String.length port)
      else authority
    in
    if authority = "" then None else Some (scheme ^ "://" ^ authority)

let frame_rows ~url ~dom ~width ~height ~scroll_x ~scroll_y =
  let visible = visible dom ~width ~height ~scroll_x ~scroll_y in
  let names = dom_node_names dom in
  let srcs = dom_attribute dom "src" in
  let parent = url_origin url in
  list (get "backendNodeId" (dom_nodes dom))
  |> List.filter_map (fun backend ->
      let backend = integer backend in
      if
        Hashtbl.find_opt names backend <> Some "IFRAME"
        || not (Hashtbl.mem visible backend)
      then None
      else
        match Hashtbl.find_opt srcs backend with
        | None -> None
        | Some src -> (
            let src =
              if String.starts_with ~prefix:"//" src then
                (if String.starts_with ~prefix:"https:" url then "https:" else "http:")
                ^ src
              else src
            in
            match url_origin src with
            | Some origin when Some origin <> parent ->
                let state =
                  match P.Row_state.of_string "cross-origin" with
                  | Ok state -> state
                  | Error _ -> assert false
                in
                Some
                  ( P.
                      {
                        index = 0;
                        role = "frame";
                        name = origin;
                        value = None;
                        state = Some [ state ];
                        options = None;
                        box = None;
                      },
                    backend )
            | _ -> None))

let dom_rows_expression = Snapshot_dom.expression ~selector:interactive_selector

let dom_rows ~call ~context =
  Snapshot_dom.rows ~call ~context ~selector:interactive_selector

let text_limit = 6000
let element_limit = 250
let scroll_delta = 560
let wait_s = 0.1
let observe_attempts = 10
let observe_retry_s = 0.02
let operator_mark = "leash-operator-read"
let settle_mark = "leash-operator-settle"

type unsupported_state =
  | Iframe
  | Shadow_root
  | Canvas
  | Nested_scroll_container
  | Password_field

type coverage = {
  text_truncated : bool;
  omitted_elements : int;
  can_scroll_up : bool;
  can_scroll_down : bool;
  coverage : string;
  unsupported_states : unsupported_state list;
}

let coverage_string ~text_truncated ~omitted_elements ~can_scroll_up ~can_scroll_down =
  let add flag token acc = if flag then acc ^ "+" ^ token else acc in
  "viewport"
  |> add text_truncated "truncated"
  |> add (omitted_elements > 0) "omitted"
  |> add can_scroll_up "above" |> add can_scroll_down "below"

let coverage_of ~unsupported_states ~text_truncated ~omitted_elements ~can_scroll_up
    ~can_scroll_down =
  {
    unsupported_states;
    text_truncated;
    omitted_elements;
    can_scroll_up;
    can_scroll_down;
    coverage =
      coverage_string ~text_truncated ~omitted_elements ~can_scroll_up ~can_scroll_down;
  }

let unsupported_name = function
  | Iframe -> "iframe"
  | Shadow_root -> "shadow-root"
  | Canvas -> "canvas"
  | Nested_scroll_container -> "nested-scroll-container"
  | Password_field -> "password-field"

let coverage_json coverage =
  `Assoc
    [
      ("text_truncated", `Bool coverage.text_truncated);
      ("omitted_elements", `Int coverage.omitted_elements);
      ("can_scroll_up", `Bool coverage.can_scroll_up);
      ("can_scroll_down", `Bool coverage.can_scroll_down);
      ("coverage", `String coverage.coverage);
      ( "unsupported_states",
        `List
          (List.map
             (fun state -> `String (unsupported_name state))
             coverage.unsupported_states) );
    ]

(* jev-ultrafast snapshot.js at 1231850a, one evaluation. Geometry is omitted from the
   marker: it is resolved and hit-tested at execution, and animation is not staleness
   (fly-4lmg). Password, file and hidden inputs are not candidates (fly-eoqg). *)
let operator_script =
  {|(() => {
  if (!document.body) return null;
  const safe = e => !['password','file','hidden'].includes(e.type);
  const identities = window.__leashOperatorIds ||= {nodes: new WeakMap(), next: 1};
  const identity = e => {
    if (!identities.nodes.has(e)) identities.nodes.set(e, identities.next++);
    return identities.nodes.get(e);
  };
  const visible = e => {
    try {
      if (e.closest('[aria-hidden="true"],[inert]')) return false;
      return e.checkVisibility
        ? e.checkVisibility({checkOpacity:true,checkVisibilityCSS:true})
        : true;
    } catch (err) { return false; }
  };
  const name = (e, seen=new Set()) => {
    if (!e || seen.has(e)) return '';
    seen.add(e);
    const referenced = (e.getAttribute('aria-labelledby') || '').split(/\s+/)
      .map(id => name(document.getElementById(id), seen)).filter(Boolean).join(' ');
    return referenced || e.getAttribute('aria-label') ||
      [...(e.labels || [])].map(l => name(l, seen)).filter(Boolean).join(' ') ||
      (['button','submit','reset'].includes(e.type) ? e.value : '') || e.getAttribute('alt') ||
      (e.tagName === 'INPUT' ? '' : [...e.childNodes].map(n => n.nodeType === 3 ? n.textContent :
        n.nodeType === 1 && n.getAttribute('aria-hidden') !== 'true' ? name(n, seen) : '').join(' ').trim()) ||
      e.getAttribute('title') || e.getAttribute('placeholder') || '';
  };
  const roles = ['button','link','checkbox','radio','switch','tab','menuitem','menuitemradio',
    'option','gridcell','combobox','textbox','searchbox','spinbutton'];
  const selector = 'a[href],button,input,textarea,select,summary,[contenteditable="true"],' +
    roles.map(role => '[role="' + role + '"]').join(',');
  const role = e => {
    const explicit = e.getAttribute('role');
    if (roles.includes(explicit)) return explicit;
    if (e.tagName === 'BUTTON' || e.tagName === 'SUMMARY') return 'button';
    if (e.tagName === 'A') return 'link';
    if (e.tagName === 'SELECT') return 'combobox';
    if (e.tagName === 'TEXTAREA' || e.isContentEditable) return 'textbox';
    if (e.tagName === 'INPUT') {
      if (['checkbox','radio'].includes(e.type)) return e.type;
      if (['button','submit','reset','image'].includes(e.type)) return 'button';
      if (e.type === 'search') return 'searchbox';
      if (e.type === 'number') return 'spinbutton';
      if (['text','email','url','tel'].includes(e.type)) return 'textbox';
    }
    return null;
  };
  const actions = [];
  const forms = [...document.querySelectorAll('input,textarea,select')].filter(safe)
    .map(e => [identity(e),e.value,e.checked,e.selectedIndex,e.disabled,e.readOnly]);
  for (const e of document.querySelectorAll(selector)) {
    if (!safe(e) || !visible(e) || e.matches(':disabled') || e.closest('[aria-disabled="true"]')) continue;
    const r = e.getBoundingClientRect(), x = r.x + r.width / 2, y = r.y + r.height / 2, rname = role(e);
    if (!rname || r.width <= 0 || r.height <= 0 || x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) continue;
    if (rname === 'gridcell' && e.querySelector('button,[role="button"]')) continue;
    const scope = e.closest('form,dialog,[role="dialog"],article,li,tr,[role="row"]') || e.parentElement;
    const value = 'value' in e ? String(e.value) :
      e.isContentEditable || rname === 'combobox' ? e.innerText.trim() : '';
    actions.push({
      identity: identity(e),
      role: rname,
      label: name(e) || rname,
      value,
      checked: ['checkbox','radio'].includes(e.type) ? String(e.checked) : e.getAttribute('aria-checked'),
      readOnly: !!(e.readOnly || e.getAttribute('aria-readonly') === 'true'),
      href: e.getAttribute('href'),
      expanded: e.getAttribute('aria-expanded'),
      selected: e.getAttribute('aria-selected'),
      selectedIndex: e.selectedIndex ?? null,
      context: (scope && scope.innerText ? scope.innerText : '').slice(0, 6000)
    });
  }
  const words = [], walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  const range = document.createRange();
  let node, length = 0, truncated = false;
  while ((node = walker.nextNode())) {
    const value = node.textContent.trim(), parent = node.parentElement;
    if (!value || !parent || parent.closest('script,style,noscript,template') || !visible(parent)) continue;
    range.selectNodeContents(node);
    const box = range.getBoundingClientRect();
    if (!(box.width > 0 && box.height > 0 && box.bottom > 0 && box.top < innerHeight && box.right > 0 && box.left < innerWidth)) continue;
    if (length >= 6000) { truncated = true; break; }
    words.push(value);
    length += value.length;
  }
  const joined = words.join('\n');
  if (joined.length > 6000) truncated = true;
  const height = Math.max(document.documentElement?.scrollHeight || 0, document.body?.scrollHeight || 0);
  const unsupported = new Set();
  for (const e of document.querySelectorAll('*')) {
    if (!visible(e)) continue;
    const r = e.getBoundingClientRect();
    if (!(r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight && r.right > 0 && r.left < innerWidth)) continue;
    if (e.tagName === 'IFRAME' || e.tagName === 'FRAME') unsupported.add('iframe');
    if (e.shadowRoot) unsupported.add('shadow-root');
    if (e.tagName === 'CANVAS') unsupported.add('canvas');
    if (e.tagName === 'INPUT' && e.type === 'password') unsupported.add('password-field');
    if (e !== document.body && e !== document.documentElement) {
      const css = getComputedStyle(e);
      if ((/(auto|scroll)/.test(css.overflowY) && e.scrollHeight > e.clientHeight + 2) ||
          (/(auto|scroll)/.test(css.overflowX) && e.scrollWidth > e.clientWidth + 2))
        unsupported.add('nested-scroll-container');
    }
  }
  return {
    unsupported_states: [...unsupported].sort(),
    kind: 'leash-operator',
    url: location.href,
    title: document.title,
    timeOrigin: performance.timeOrigin,
    text: joined.slice(0, 6000),
    truncated,
    omitted: Math.max(0, actions.length - 250),
    scroll: { x: scrollX, y: scrollY, height, viewport: innerHeight, width: innerWidth },
    semantics: actions.slice(0, 250),
    guard: { forms, actions }
  };
})()|}

let operator_expression = "/* " ^ operator_mark ^ " */\n" ^ operator_script

let settle_expression ~autocomplete =
  Printf.sprintf
    "/* %s */ new Promise(resolve => { const autocomplete = %s; let frames = 0, stopped \
     = false;      const finish = () => { stopped = true; resolve(true); }; \
     setTimeout(finish, autocomplete ? 200 : 50);      const ready = () => { if \
     (stopped) return; const field = document.activeElement; const ids = \
     (field?.getAttribute('aria-controls') || field?.getAttribute('aria-owns') || '') \
     .split(/\\s+/).filter(Boolean); const roots = ids.length ? ids.map(id => \
     document.getElementById(id)).filter(Boolean) : [document]; const options = \
     roots.flatMap(root => [...root.querySelectorAll('[role=\"option\"]')]); const shown \
     = options.some(e => { const r = e.getBoundingClientRect(); return r.width && \
     r.height && r.bottom > 0 && r.top < innerHeight &&      (e.checkVisibility ? \
     e.checkVisibility({checkOpacity:true,checkVisibilityCSS:true}) : true); });      if \
     (++frames >= 2 && (!autocomplete || shown)) finish(); else \
     requestAnimationFrame(ready); };      requestAnimationFrame(ready); })"
    settle_mark
    (if autocomplete then "true" else "false")

type semantics = {
  role : string;
  label : string;
  value : string;
  checked : string option;
  read_only : bool;
  href : string option;
  context : string;
}

type operator_read = {
  url : string;
  title : string;
  text : string;
  time_origin : float;
  scroll_x : float;
  scroll_y : float;
  scroll_height : float;
  viewport_width : float;
  viewport_height : float;
  can_scroll_up : bool;
  can_scroll_down : bool;
  semantics : semantics list;
  marker : string;
  coverage : coverage;
}

type operator_reply = Payload of operator_read | Navigating | Foreign

let float_field key json =
  match get key json with `Int n -> float n | `Float x -> x | _ -> 0.

let opt_string json = match json with `String s when s <> "" -> Some s | _ -> None
let bool_field key json = match get key json with `Bool b -> b | _ -> false

let semantics_of json =
  list json
  |> List.filter_map (fun item ->
      match item with
      | `Assoc _ ->
          let checked =
            match get "checked" item with
            | `String s -> Some s
            | `Bool b -> Some (if b then "true" else "false")
            | _ -> None
          in
          Some
            {
              role = text (get "role" item);
              label = text (get "label" item);
              value = text (get "value" item);
              checked;
              read_only = bool_field "readOnly" item;
              href = opt_string (get "href" item);
              context = text (get "context" item);
            }
      | _ -> None)

let semantics_json (item : semantics) =
  `Assoc
    [
      ("role", `String item.role);
      ("label", `String item.label);
      ("value", `String item.value);
      ( "checked",
        match item.checked with None -> `Null | Some checked -> `String checked );
      ("readOnly", `Bool item.read_only);
      ("href", match item.href with None -> `Null | Some href -> `String href);
      ("context", `String item.context);
    ]

let marker_of ~url ~title ~time_origin ~text ~scroll_x ~scroll_y ~scroll_height
    ~viewport_width ~viewport_height ~semantics =
  Yojson.Safe.to_string
    (`List
       [
         `Float time_origin;
         `String url;
         `String title;
         `Float scroll_x;
         `Float scroll_y;
         `Float scroll_height;
         `Float viewport_width;
         `Float viewport_height;
         `String text;
         `List (List.map semantics_json semantics);
       ])

(* CDP strings are UTF-8; a character bound must never split a codepoint or
   truncate non-ASCII text at 6,000 bytes (fly-iodm). *)
let bounded_text raw =
  let rec end_at offset remaining =
    if offset >= String.length raw || remaining = 0 then offset
    else
      let decoded = String.get_utf_8_uchar raw offset in
      end_at (offset + Uchar.utf_decode_length decoded) (remaining - 1)
  in
  let stop = end_at 0 text_limit in
  (String.sub raw 0 stop, stop < String.length raw)

let parse_operator json =
  match json with
  | `Null -> Navigating
  | _ when text (get "kind" json) <> "leash-operator" -> Foreign
  | _ ->
      let scroll = get "scroll" json in
      let scroll_x = float_field "x" scroll in
      let scroll_y = float_field "y" scroll in
      let scroll_height = float_field "height" scroll in
      let viewport_height = float_field "viewport" scroll in
      let viewport_width = float_field "width" scroll in
      let raw = text (get "text" json) in
      let page_text, cut = bounded_text raw in
      let text_truncated = bool_field "truncated" json || cut in
      let omitted_elements = max 0 (integer (get "omitted" json)) in
      let can_scroll_down = scroll_y +. viewport_height < scroll_height -. 2. in
      let can_scroll_up = scroll_y > 0. in
      let semantics = semantics_of (get "semantics" json) in
      let url = text (get "url" json) in
      let title = text (get "title" json) in
      let time_origin = float_field "timeOrigin" json in
      let unsupported_states =
        list (get "unsupported_states" json)
        |> List.filter_map (function
          | `String "iframe" -> Some Iframe
          | `String "shadow-root" -> Some Shadow_root
          | `String "canvas" -> Some Canvas
          | `String "nested-scroll-container" -> Some Nested_scroll_container
          | `String "password-field" -> Some Password_field
          | _ -> None)
      in
      let coverage =
        coverage_of ~unsupported_states ~text_truncated ~omitted_elements ~can_scroll_up
          ~can_scroll_down
      in
      Payload
        {
          url;
          title;
          text = page_text;
          time_origin;
          scroll_x;
          scroll_y;
          scroll_height;
          viewport_width;
          viewport_height;
          can_scroll_up;
          can_scroll_down;
          semantics;
          marker =
            marker_of ~url ~title ~time_origin ~text:page_text ~scroll_x ~scroll_y
              ~scroll_height ~viewport_width ~viewport_height ~semantics
            ^ Yojson.Safe.to_string (get "guard" json)
            ^ Yojson.Safe.to_string (get "unsupported_states" json);
          coverage;
        }
