(* L20 — request shaping and decision (docs/issues/drive/01-drive.md, milestone 5).

   jev-ultrafast's shapes at commit Questions.commit, copied not adapted: the elements and
   the questions come from model.py's action_space and choose over the action space
   snapshot.js builds, and the decision is model.py's choose after the answers arrive. The
   reference lines each shape comes from are quoted where it is built, and the test in
   test/jev_request_test.ml quotes them again beside the expected documents. Pure: no I/O,
   no clock, no configuration beyond the model id the caller passes. *)

module P = Protocol
module E = Ox_json

(* model.py:44 — the one sentence the reference answers an invalid response with. *)
let invalid = "Invalid TypeSafe response; no action executed."

(* ---------- Recent actions (agent.py:121-148, model.py:112-114) ---------- *)

type recent_action = {
  action : string;
  kind : string option; [@json.null]
  text : string option; [@json.null]
  page_changed : bool option; [@json.null]
}
[@@deriving yojson]

(* model.py:113 — history[-10:]. *)
let window recent =
  let length = List.length recent in
  if length <= 10 then recent else List.filteri (fun i _ -> i >= length - 10) recent

(* ---------- The page (model.py:110) ---------- *)

type page = { url : string; title : string; text : string } [@@deriving yojson]

(* ---------- Elements (snapshot.js:55-80, model.py:48-78) ---------- *)

type checked = Checked | Unchecked | Mixed
type select_target = { key : string; label : string; value : string; dom : int }

type element = {
  index : string;
  row : int;
  label : string;
  role : string;
  value : string;
  checked : checked option;
  selected : bool option;
  expanded : bool option;
  operations : P.Operation.t list;
  options : select_target list;
}

let operation name =
  match P.Operation.of_string name with
  | Ok operation -> operation
  | Error _ -> assert false

let states (row : P.row) =
  match row.state with None -> [] | Some states -> List.map P.Row_state.to_string states

let carries state (row : P.row) = List.mem state (states row)

let checked row =
  if carries "checked" row then Some Checked
  else if carries "unchecked" row then Some Unchecked
  else if carries "mixed" row then Some Mixed
  else None

(* snapshot.js:69 — the options a select offers: the ones that are not selected, not
   disabled, and not inside a disabled optgroup. *)
let offered (option_ : P.row_option) = (not option_.selected) && not option_.disabled

(* snapshot.js:61 — a node's label is its accessible name, or its role when it has none. *)
let label (row : P.row) = if row.name = "" then row.role else row.name

(* snapshot.js:56-80 — the operations a row is offered are the actions the page offers for
   its node. A native select offers one select action per offered option and nothing else
   (snapshot.js:68-71), so it is an element only while it still has one to offer; an
   editable text control offers fill and then click (snapshot.js:73-79); a read-only one
   offers click; every other action target offers click. A disabled row, and a purely
   informative one, are offered nothing and are not elements at all. *)
let operations (row : P.row) =
  if carries "disabled" row then []
  else
    match row.options with
    | Some options -> if List.exists offered options then [ operation "select" ] else []
    | None -> (
        match row.role with
        | "heading" | "paragraph" | "img" | "status" | "alert" -> []
        | "textbox" | "searchbox" | "spinbutton" | "combobox" ->
            if carries "readonly" row then [ operation "click" ]
            else [ operation "type_text"; operation "click" ]
        | _ -> [ operation "click" ])

(* snapshot.js:70 — a select's value is the labels of its selected options joined ", ". *)
let selected_labels (row : P.row) =
  match row.options with
  | None -> ""
  | Some options ->
      options
      |> List.filter (fun (option_ : P.row_option) -> option_.selected)
      |> List.map (fun (option_ : P.row_option) -> option_.label)
      |> String.concat ", "

(* model.py:74-76 — a select's targets are numbered "<element index>:<option number>" over
   the options it offers, and each carries the option action's full label
   "<select label> → <option label>" and the option's own value. [dom] is the index the
   option has in the select's own order, which is what the select action takes. *)
let select_targets index (row : P.row) =
  match row.options with
  | None -> []
  | Some options ->
      options |> List.filter offered
      |> List.mapi (fun position (option_ : P.row_option) ->
          {
            key = index ^ ":" ^ string_of_int (position + 1);
            label = label row ^ " → " ^ option_.label;
            value = option_.value;
            dom = option_.index;
          })

(* fly-eoqg field-sazr: the operator's table. The agent's snapshot lists password rows
   (field-8bzc); JEV is never offered one, nor a file input. *)
let operator_row (row : P.row) =
  row.role <> "file-input"
  && not
       (List.exists
          (fun state -> P.Row_state.to_string state = "password")
          (Option.value ~default:[] row.state))

let elements (snapshot : P.snapshot) =
  snapshot.rows
  |> List.filter (fun (row : P.row) -> operator_row row && operations row <> [])
  |> List.mapi (fun position (row : P.row) ->
      let index = string_of_int (position + 1) in
      let operations = operations row in
      {
        index;
        row = row.index;
        label = label row;
        role = row.role;
        (* model.py:64-65 — a select's value is its current value, and model.py:76-77
              gives every other action a value too, so the key is always on the wire. *)
        value =
          (if List.mem (operation "select") operations then selected_labels row
           else Option.value ~default:"" row.value);
        checked = checked row;
        selected = (if carries "selected" row then Some true else None);
        expanded =
          (if carries "expanded" row then Some true
           else if carries "collapsed" row then Some false
           else None);
        operations;
        options = select_targets index row;
      })
  (* snapshot.js:99-101 limits browser actions, not text rows. One select option
     is one action; an editable control offers two actions. Keep the first 250
     in DOM order, even when the cap falls in the middle of a row. *)
  |> List.fold_left
       (fun (budget, kept) element ->
         if budget = 0 then (budget, kept)
         else
           let options = List.filteri (fun i _ -> i < budget) element.options in
           let operations =
             if element.options <> [] then element.operations
             else List.filteri (fun i _ -> i < budget) element.operations
           in
           let cost =
             if element.options <> [] then List.length options else List.length operations
           in
           (budget - cost, { element with operations; options } :: kept))
       (250, [])
  |> snd |> List.rev

(* ---------- Operations, keys and labels (model.py:83-90, snapshot.js:102-104) ---------- *)

let operation_key operation = String.uppercase_ascii (P.Operation.to_string operation)

let click_label =
  "Click an element, button, menu option, autocomplete suggestion, or calendar day."

let type_text_label =
  "Enter or replace text in an editable field. A small LLM will supply the value from \
   the goal."

let select_label = "Select an observed dropdown value."
let done_label = "Every requirement is visibly satisfied."
let blocked_label = "No supported operation can progress."

(* snapshot.js:102-104, verbatim. *)
let scroll_down_label = "Scroll down"
let scroll_up_label = "Scroll up"
let wait_label = "Wait for the page to update"

(* pbk-otsl pbk-rai1: pinned verbatim. The operator option key is the prefix plus the
   script name; the criterion text is the script's one-sentence description. *)
let run_script_prefix = "run_script:"

let run_script_rule =
  "run_script:<name> runs that prepared script on the current page. Choose it to \
   collect    the page; its records are saved and do not need to be clicked."

type offered_script = { name : string; description : string }

type script_effect =
  | Script_continue of { summary : string }
  | Script_blocked of { argument : string }

(* snapshot.js:102-103 — a scroll is offered only while the page can still move that way:
   [can_scroll_down] is scrollY + innerHeight < height - 2 and [can_scroll_up] is
   scrollY > 0. Wait is always offered, and snapshot.js pushes the three in this order. *)
let controls ~can_scroll_down ~can_scroll_up =
  (if can_scroll_down then [ ("SCROLL_DOWN", scroll_down_label) ] else [])
  @ (if can_scroll_up then [ ("SCROLL_UP", scroll_up_label) ] else [])
  @ [ ("WAIT", wait_label) ]

let operation_label operation =
  match P.Operation.to_string operation with
  | "click" -> click_label
  | "type_text" -> type_text_label
  | "select" -> select_label
  | _ -> assert false

(* snapshot.js:78-79 — the click an editable control also offers is the action labelled
   "Open <label>"; the fill action keeps the node's own label. *)
let criterion_label ~operation:op (element : element) =
  if
    P.Operation.to_string op = "click"
    && List.mem (operation "type_text") element.operations
  then "Open " ^ element.label
  else element.label

(* model.py:88-90 — one entry per operation, in the order the elements first carry it. *)
let distinct_operations elements =
  List.fold_left
    (fun distinct element ->
      List.fold_left
        (fun distinct operation ->
          if List.mem operation distinct then distinct else distinct @ [ operation ])
        distinct element.operations)
    [] elements

(* ---------- The request ---------- *)

(* dmod-7w26: the viewport screenshot a multimodal decision model is shown: a PNG data URL,
   its pixel size and the PNG-to-CSS scale, so a chosen point maps back to CSS pixels. *)
type image = { data_url : string; width : int; height : int; scale : float }

let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

let png_data_url bytes =
  let n = Bytes.length bytes in
  let out = Buffer.create (((n + 2) / 3 * 4) + 22) in
  Buffer.add_string out "data:image/png;base64,";
  let byte i = if i < n then Char.code (Bytes.get bytes i) else 0 in
  let rec go i =
    if i < n then (
      let b = (byte i lsl 16) lor (byte (i + 1) lsl 8) lor byte (i + 2) in
      Buffer.add_char out alphabet.[(b lsr 18) land 63];
      Buffer.add_char out alphabet.[(b lsr 12) land 63];
      Buffer.add_char out (if i + 1 < n then alphabet.[(b lsr 6) land 63] else '=');
      Buffer.add_char out (if i + 2 < n then alphabet.[b land 63] else '=');
      go (i + 3))
  in
  go 0;
  Buffer.contents out

type request = {
  image : image option;
  look : bool;
  point_levels : int;
  model : string;
  goal : string;
  snapshot : P.snapshot;
  text : string;
  recent : recent_action list;
  can_scroll_down : bool;
  can_scroll_up : bool;
  elements : element list;
  scripts : offered_script list;
  coverage : Yojson.Safe.t;
  shown_url : string option;
}

(* pilot-02ij: model requests cannot carry secret values reflected by a page. *)
let redact secrets request =
  let text = P.redact_string secrets in
  let snapshot =
    match
      P.snapshot_of_yojson (P.redact_json secrets (P.yojson_of_snapshot request.snapshot))
    with
    | Ok snapshot -> snapshot
    | Error _ -> request.snapshot
  in
  {
    request with
    goal = text request.goal;
    text = text request.text;
    snapshot;
    recent =
      List.map
        (fun action ->
          { action with action = text action.action; text = Option.map text action.text })
        request.recent;
    elements =
      List.map
        (fun element ->
          {
            element with
            label = text element.label;
            value = text element.value;
            options =
              List.map
                (fun (option : select_target) ->
                  { option with label = text option.label; value = text option.value })
                element.options;
          })
        request.elements;
    scripts =
      List.map
        (fun script -> { name = text script.name; description = text script.description })
        request.scripts;
    shown_url = Option.map text request.shown_url;
    coverage = P.redact_json secrets request.coverage;
  }

(* fly-iodm, fly-crcc: enforce the Unicode viewport bound at the request boundary. *)
let bounded_text text =
  let at = ref 0 and count = ref 0 in
  while !at < String.length text && !count < 6000 do
    at := !at + Uchar.utf_decode_length (String.get_utf_8_uchar text !at);
    incr count
  done;
  (String.sub text 0 !at, !at < String.length text)

let make ~model ~goal ~snapshot ~text ~recent ~can_scroll_down ~can_scroll_up =
  let text, text_truncated = bounded_text text in
  {
    coverage =
      `Assoc
        [
          ("text_truncated", `Bool text_truncated);
          ("omitted_elements", `Int (max 0 (snapshot.P.total - List.length snapshot.rows)));
          ("scope", `String "visible viewport; offscreen and other pages unobserved");
        ];
    model;
    goal;
    snapshot;
    text;
    recent;
    can_scroll_down;
    can_scroll_up;
    elements = elements snapshot;
    scripts = [];
    shown_url = None;
    image = None;
    look = false;
    point_levels = 20;
  }

(* dmod-7w26 dmod-4ky5: a screenshot in the state also offers CLICK_AT on it. *)
let with_image request image = { request with image = Some image }

(* dmod-mcgn: offer LOOK on this step. *)
let with_look request look = { request with look }

let with_point_levels request point_levels =
  { request with point_levels = max 2 point_levels }

(* map-op12: remove only exact operation/row pairs. Other operations on that
   row remain available; targetless scrolls are page controls. *)
let without_actions request masked =
  let blocked op index = List.mem (op, index) masked in
  let elements =
    List.map
      (fun (element : element) ->
        {
          element with
          operations =
            List.filter (fun op -> not (blocked op (Some element.row))) element.operations;
        })
      request.elements
  in
  {
    request with
    elements;
    can_scroll_down =
      request.can_scroll_down && not (blocked (operation "scroll_down") None);
    can_scroll_up = request.can_scroll_up && not (blocked (operation "scroll_up") None);
  }

let with_scripts request scripts = { request with scripts }
let with_shown_url request url = { request with shown_url = Some url }

let with_coverage request coverage =
  match (request.coverage, coverage) with
  | `Assoc original, `Assoc exact ->
      let kept = List.filter (fun (key, _) -> not (List.mem_assoc key exact)) original in
      { request with coverage = `Assoc (kept @ exact) }
  | _, _ -> { request with coverage }

let checked_json = function
  | Checked -> E.string "true"
  | Unchecked -> E.string "false"
  | Mixed -> E.string "mixed"

(* snapshot.js:63-67 — checked, selected and expanded are the attribute strings Chrome
   reports ("true", "false", "mixed"), never booleans. *)
let state_json value = E.string (if value then "true" else "false")

let option_json (option_ : select_target) =
  E.object_
    [
      ("index", Some (E.string option_.key));
      ("label", Some (E.string option_.label));
      ("value", Some (E.string option_.value));
    ]

(* model.py:58-66 — role, value, checked, selected, expanded, then index, label and
   operations; a select's option list follows (model.py:66, 76). *)
let element_json (element : element) =
  E.object_
    [
      ("role", Some (E.string element.role));
      ("value", Some (E.string element.value));
      ("checked", Option.map checked_json element.checked);
      ("selected", Option.map state_json element.selected);
      ("expanded", Option.map state_json element.expanded);
      ("index", Some (E.string element.index));
      ("label", Some (E.string element.label));
      ( "operations",
        Some
          (E.array_map
             (fun operation -> E.string (operation_key operation))
             element.operations) );
      ( "options",
        if List.mem (operation "select") element.operations then
          Some (E.array_map option_json element.options)
        else None );
    ]

(* model.py:97-103 — a criterion names the target by its key, the value it holds now
   (empty when it holds none) and its state. *)
let criterion_json ~key ~label ~current_value (element : element) =
  E.object_
    [
      ("element", Some (E.string (Printf.sprintf "[%s] %s" key label)));
      ("current_value", Some (E.string current_value));
      ("role", Some (E.string element.role));
      ("checked", Option.map checked_json element.checked);
      ("selected", Option.map state_json element.selected);
      ("expanded", Option.map state_json element.expanded);
    ]

(* model.py:94-106 — the criteria of one target question: a select contributes one target
   per offered option (model.py:75-76), every other element contributes itself. *)
let target_criteria op (element : element) =
  if List.mem (operation "select") element.operations then
    List.map
      (fun option_ ->
        ( option_.key,
          Some
            (criterion_json ~key:option_.key ~label:option_.label
               ~current_value:element.value element) ))
      element.options
  else
    [
      ( element.index,
        Some
          (criterion_json ~key:element.index
             ~label:(criterion_label ~operation:op element)
             ~current_value:element.value element) );
    ]

(* The targets one element contributes: a select's offered options, each with the option
   the drive would act on, and every other element itself with none. *)
let target_keys_of op (element : element) =
  if List.mem (operation "select") element.operations then
    List.map (fun option_ -> (option_.key, Some option_)) element.options
  else [ (element.index, None) ]

let target_keys op (element : element) = List.map fst (target_keys_of op element)

(* model.py:88-90 — the criteria of the operation choice: the operations that have targets,
   in the order the elements first carry them, then the controls, then DONE and BLOCKED. The
   same list is what decide validates the answer against. *)
(* pbk-otsl: the operation choice stays under 255 criteria, scripts included. Element
   operations, then scroll/wait, then run_script:<name> in offer order, then DONE and
   BLOCKED. Scripts that would reach 255 are not offered. *)
let max_operation_options = 254

let operation_criteria request =
  let operations =
    List.map
      (fun operation -> (operation_key operation, operation_label operation))
      (distinct_operations request.elements)
  in
  let controls =
    controls ~can_scroll_down:request.can_scroll_down ~can_scroll_up:request.can_scroll_up
  in
  let terminal = [ ("DONE", done_label); ("BLOCKED", blocked_label) ] in
  let vision =
    (if request.look then [ ("LOOK", Questions.look_label) ] else [])
    @ if request.image <> None then [ ("CLICK_AT", Questions.click_at_label) ] else []
  in
  let room =
    max 0
      (max_operation_options - List.length operations - List.length controls
     - List.length vision - List.length terminal)
  in
  let scripts =
    request.scripts
    |> List.filteri (fun i _ -> i < room)
    |> List.map (fun script -> (run_script_prefix ^ script.name, script.description))
  in
  operations @ controls @ vision @ scripts @ terminal

let operation_keys request = List.map fst (operation_criteria request)

let operation_question request =
  E.object_
    [
      ("type", Some (E.string "choice"));
      ( "criteria",
        Some
          (E.object_
             (List.map
                (fun (key, label) -> (key, Some (E.string label)))
                (operation_criteria request))) );
      ( "instructions",
        Some
          (E.object_
             [
               ("goal", Some (E.string request.goal));
               ( "rules",
                 Some
                   (E.string
                      ((if
                          List.exists
                            (fun (key, _) ->
                              String.starts_with ~prefix:run_script_prefix key)
                            (operation_criteria request)
                        then Questions.next_action ^ "\n" ^ run_script_rule
                        else Questions.next_action)
                      ^
                      if request.image <> None then "\n" ^ Questions.click_at_rule else ""
                      )) );
             ]) );
    ]

let target_question request operation =
  let candidates =
    List.filter
      (fun (element : element) -> List.mem operation element.operations)
      request.elements
  in
  E.object_
    [
      ("type", Some (E.string "choice"));
      ( "criteria",
        Some
          (E.object_
             (List.concat_map
                (fun element -> target_criteria operation element)
                candidates)) );
      ( "instructions",
        Some
          (E.object_
             [
               ("goal", Some (E.string request.goal));
               ("operation", Some (E.string (operation_key operation)));
               ( "rules",
                 Some
                   (E.array [ E.string Questions.next_action; E.string Questions.target ])
               );
             ]) );
    ]

let target_key operation = P.Operation.to_string operation ^ "_target"

(* dmod-4ky5: the Decisions API has no point question; a point is two score questions,
   one per axis, over [point_levels] equal bands of the screenshot. *)
let point_question request ~axis ~rules =
  E.object_
    [
      ("type", Some (E.string "score"));
      ( "criteria",
        Some (E.array_map E.string (Questions.point_levels ~axis request.point_levels)) );
      ( "instructions",
        Some
          (E.object_
             [
               ("goal", Some (E.string request.goal));
               ("operation", Some (E.string "CLICK_AT"));
               ("rules", Some (E.string rules));
             ]) );
    ]

let questions request =
  E.object_
    (("operation", Some (operation_question request))
     :: List.map
          (fun operation ->
            (target_key operation, Some (target_question request operation)))
          (distinct_operations request.elements)
    @
    match request.image with
    | None -> []
    | Some _ ->
        [
          ( "click_at_x",
            Some (point_question request ~axis:"width" ~rules:Questions.point_x) );
          ( "click_at_y",
            Some (point_question request ~axis:"height" ~rules:Questions.point_y) );
        ])

let body request =
  (* dmod-7w26: an image travels beside the state object as a chat-style image part,
     the one form Clef read in the 2026-10-05 probe. *)
  let with_picture state =
    match request.image with
    | None -> state
    | Some image ->
        E.array
          [
            state;
            E.object_
              [
                ("type", Some (E.string "image_url"));
                ("image_url", Some (E.object_ [ ("url", Some (E.string image.data_url)) ]));
              ];
          ]
  in
  E.object_
    [
      ("model", Some (E.string request.model));
      ( "state",
        Some
          (with_picture
          @@ E.object_
               [
                 ("goal", Some (E.string request.goal));
                 ("can_scroll_down", Some (E.bool request.can_scroll_down));
                 ("can_scroll_up", Some (E.bool request.can_scroll_up));
                 ("coverage", Some request.coverage);
                 ( "page",
                   Some
                     (yojson_of_page
                        {
                          url =
                            Option.value ~default:request.snapshot.url request.shown_url;
                          title = request.snapshot.title;
                          text = request.text;
                        }) );
                 ("elements", Some (E.array_map element_json request.elements));
                 ( "recent_actions",
                   Some (E.array_map yojson_of_recent_action (window request.recent)) );
               ]) );
      ("questions", Some (questions request));
    ]

(* ---------- The decision (model.py:30-45, 81-148) ---------- *)

type decision = {
  operation : P.Operation.t;
  script : string option;
  index : int option;
  option : int option;
  confidence : float;
  target_confidence : float option;
  operation_probabilities : (string * float) list;
  target_probabilities : (string * float) list;
  targets : (string * float) list;
  point : P.point option;
}

let member key = function `Assoc fields -> List.assoc_opt key fields | _ -> None

let probabilities json =
  match json with
  | `Assoc fields ->
      List.fold_left
        (fun probabilities (key, value) ->
          match (probabilities, E.Of_json.float value) with
          | Ok probabilities, Ok number -> Ok ((key, number) :: probabilities)
          | _ -> Error invalid)
        (Ok []) fields
      |> Result.map List.rev
  | _ -> Error invalid

(* model.py:30-45 — the answer names an offered key, carries exactly the offered keys,
   holds finite numbers in [0,1] (the confidence among them), sums to one within 0.02 and
   puts its choice at the maximum within 1e-6. *)
let validated ~keys json =
  match (member "choice" json, member "probabilities" json, member "confidence" json) with
  | Some (`String choice), Some probabilities_json, Some confidence_json -> (
      match (probabilities probabilities_json, E.Of_json.float confidence_json) with
      | Ok probabilities, Ok confidence ->
          let numbers = List.map snd probabilities @ [ confidence ] in
          let total = List.fold_left ( +. ) 0. (List.map snd probabilities) in
          let highest =
            List.fold_left Float.max neg_infinity (List.map snd probabilities)
          in
          let offered keys = List.sort_uniq String.compare keys in
          let chosen = List.assoc_opt choice probabilities in
          if
            List.mem choice keys
            && offered (List.map fst probabilities) = offered keys
            && List.for_all
                 (fun number -> Float.is_finite number && number >= 0. && number <= 1.)
                 numbers
            && Float.abs (total -. 1.) < 0.02
            &&
            match chosen with
            | Some number -> number >= highest -. 1e-6
            | None -> false
          then Ok (choice, probabilities, confidence)
          else Error invalid
      | _ -> Error invalid)
  | _ -> Error invalid

let operation_of_key key =
  match P.Operation.of_string (String.lowercase_ascii key) with
  | Ok operation -> Some operation
  | Error _ ->
      None
      [@ox.allow
        "ox-discarded-result: a failed probe reads as absent; the caller decides"]

(* The target the model named, as the element and the option the drive would act on. *)
let chosen op candidates key =
  List.find_map
    (fun (element : element) ->
      List.find_map
        (fun (candidate, option_) ->
          if candidate = key then Some (element, option_) else None)
        (target_keys_of op element))
    candidates

(* model.py:130 — the reference keys its distribution by the action it would execute; here
   that is the row, and for a select option the row and the option's own index. *)
let targets ~operation:op candidates target_probabilities =
  List.concat_map
    (fun (element : element) ->
      List.filter_map
        (fun (key, option_) ->
          Option.map
            (fun number ->
              ( (match option_ with
                | Some option_ -> Printf.sprintf "%d:%d" element.row option_.dom
                | None -> string_of_int element.row),
                number ))
            (List.assoc_opt key target_probabilities))
        (target_keys_of op element))
    candidates

let decide request ~answers =
  let ( let* ) = Result.bind in
  let* chosen_key, operation_probabilities, confidence =
    match member "operation" answers with
    | Some answer -> validated ~keys:(operation_keys request) answer
    | None -> Error invalid
  in
  if String.starts_with ~prefix:run_script_prefix chosen_key then
    let name =
      String.sub chosen_key
        (String.length run_script_prefix)
        (String.length chosen_key - String.length run_script_prefix)
    in
    if List.exists (fun script -> script.name = name) request.scripts then
      Ok
        {
          operation = operation "blocked";
          script = Some name;
          index = None;
          option = None;
          confidence;
          target_confidence = None;
          point = None;
          operation_probabilities;
          target_probabilities = [];
          targets = [];
        }
    else Error invalid
  else
    let* operation =
      match operation_of_key chosen_key with
      | Some operation -> Ok operation
      | None -> Error invalid
    in
    let candidates =
      List.filter
        (fun (element : element) -> List.mem operation element.operations)
        request.elements
    in
    (* dmod-4ky5: a score answer on one axis is the band's index; the point is the band's
       centre on the screenshot, divided by its PNG-to-CSS scale. *)
    let axis name extent =
      match (member name answers, request.image) with
      | Some answer, Some image -> (
          match Option.map E.Of_json.float (member "score" answer) with
          | Some (Ok score)
            when Float.is_finite score && score >= 0.
                 && score <= float_of_int (request.point_levels - 1) ->
              Ok
                ((score +. 0.5)
                /. float_of_int request.point_levels
                *. float_of_int (extent image)
                /. image.scale)
          | _ -> Error invalid)
      | _ -> Error invalid
    in
    let* point =
      if P.Operation.to_string operation <> "click_at" then Ok None
      else
        let* x = axis "click_at_x" (fun image -> image.width) in
        let* y = axis "click_at_y" (fun image -> image.height) in
        Ok (Some P.{ x; y })
    in
    if candidates = [] then
      Ok
        {
          operation;
          script = None;
          index = None;
          option = None;
          confidence;
          target_confidence = None;
          operation_probabilities;
          target_probabilities = [];
          targets = [];
          point;
        }
    else
      let keys =
        List.concat_map (fun element -> target_keys operation element) candidates
      in
      let* target_key, target_probabilities, target_confidence =
        match member (target_key operation) answers with
        | Some answer -> validated ~keys answer
        | None -> Error invalid
      in
      match chosen operation candidates target_key with
      | None -> Error invalid
      | Some (element, option_) ->
          Ok
            {
              operation;
              script = None;
              index = Some element.row;
              option = Option.map (fun option_ -> option_.dom) option_;
              confidence;
              target_confidence = Some target_confidence;
              point = None;
              operation_probabilities;
              target_probabilities;
              targets = targets ~operation candidates target_probabilities;
            }

let distribution pairs =
  E.object_ (List.map (fun (key, number) -> (key, E.float number)) pairs)

let trace_probabilities decision =
  P.
    {
      op = distribution decision.operation_probabilities;
      target = distribution decision.targets;
    }

(* ---------- The stall rule (agent.py:153-157) ---------- *)

let stalled recent =
  let length = List.length recent in
  if length < 3 then false
  else
    List.filteri (fun position _ -> position >= length - 3) recent
    |> List.for_all (fun action ->
        action.page_changed = Some false && action.kind <> Some "wait")
