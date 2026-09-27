(* L7 actions: action-time revalidation, trusted dispatch, bounded settlement.
   tab-bw4j tab-j1z2 tab-p3x1 tab-luo5 tab-5deq tab-8dop tab-tm6c tab-hxld tab-60kn
   tab-1lhx tab-8la3. *)

module P = Protocol
module E = Eta_json

let ( let* ) = Result.bind
let ( let+ ) result f = Result.map f result

let error ?detail name message : P.error =
  let code =
    match P.Error_code.of_string name with Ok code -> code | Error _ -> assert false
  in
  { P.code; message; detail }

let fail ?detail name message = Error (error ?detail name message)
let issue why = Format.asprintf "%a" E.pp_issue why

type tab = {
  session : string;
  target : string;  (** The tab's Chrome target id: what a popup's [openerId] names. *)
  handle : P.Handle.t;
  owner : P.Owner.t;
      (** The caller: the acted-on tab was reached through it, so a popup it opened is the
          caller's and no one else's (tab-8k2g). *)
  page : unit -> string * string;
  refresh : unit -> unit;
  snapshot : unit -> (P.Snapshot_id.t * string * (P.row * int) list) option;
  dialog : unit -> P.dialog option;
  all_tabs : unit -> (P.tab_info * string option) list;
      (** Every tab in the registry, all owners, ordered by handle, paired with the target
          id of the tab that opened it when Chrome reports one ([openerId]). *)
}

(* One CDP call. Only pre-dispatch observation may be repeated inside this module, and
   then only the read pair a revalidation is made of; a failure after dispatch is the
   action's failure and is never replayed (tab-1lhx). *)

type failure = Refused of int * string | Transport of string

let attempt ?deadline cdp ~session method_ params =
  match Cdp.call cdp ~session ?deadline method_ params with
  | Error _ -> Error (Transport "the browser connection failed")
  | Ok reply -> (
      match Cdp.error_of_reply reply with
      | Some (number, message) -> Error (Refused (number, message))
      | None -> (
          match Cdp.result reply with
          | Some result -> Ok result
          | None -> Error (Transport "the browser's reply carried no result")))

let call cdp ~session method_ params =
  match attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session method_ params with
  | Ok json -> Ok json
  | Error (Refused (number, message)) ->
      fail "internal"
        (Printf.sprintf "the browser refused %s (%d %s)" method_ number message)
  | Error (Transport why) ->
      fail "browser-unavailable" ("Chrome did not answer; try again shortly: " ^ why)

let handles tab =
  List.map (fun ((info : P.tab_info), _) -> P.Handle.to_string info.tab) (tab.all_tabs ())

let stale tab message =
  match tab.snapshot () with
  | Some (snapshot, _, _) ->
      error "stale-snapshot" message
        ~detail:
          (E.object_ [ ("snapshot", Some (E.string (P.Snapshot_id.to_string snapshot))) ])
  | None -> error "stale-snapshot" message

let fail_stale tab message = Error (stale tab message)

let current tab id =
  match tab.snapshot () with
  | Some (snapshot, loader, rows) when snapshot = id -> Ok (loader, rows)
  | Some (snapshot, _, _) ->
      fail "stale-snapshot" "that snapshot is not the current one; snap again"
        ~detail:
          (E.object_ [ ("snapshot", Some (E.string (P.Snapshot_id.to_string snapshot))) ])
  | None -> fail "stale-snapshot" "there is no snapshot for this tab; snap first"

let current_any tab =
  match tab.snapshot () with
  | Some (_, loader, rows) -> Ok (loader, rows)
  | None -> fail "stale-snapshot" "there is no snapshot for this tab; snap first"

let loader_id cdp tab =
  let* json = call cdp ~session:tab.session "Page.getFrameTree" (E.object_ []) in
  match E.Of_json.(at [ "frameTree"; "frame"; "loaderId" ] string) json with
  | Ok id -> Ok id
  | Error why ->
      fail "internal" ("the browser omitted the frame's loader id: " ^ issue why)

let loader_unchanged cdp tab loader =
  let* now = loader_id cdp tab in
  if now = loader then Ok ()
  else fail_stale tab "the page navigated since that snapshot; snap again"

let ax_pair : (string * string) list E.Of_json.t =
  E.Of_json.(
    field "nodes"
      (list (fun json ->
           let* role = field "role" (field "value" string) json in
           let+ name = field "name" (field "value" string) json in
           (role, name))))

(* The row's accessible role and name now. A node that no longer resolves, or that
   resolves to another role or name, is what the spec calls a replaced row (tab-j1z2). *)
let accessed cdp tab backend =
  match
    attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session
      "Accessibility.getPartialAXTree"
      (E.object_
         [
           ("backendNodeId", Some (E.int backend)); ("fetchRelatives", Some (E.bool false));
         ])
  with
  | Error _ -> None
  | Ok json -> ( match ax_pair json with Ok (pair :: _) -> Some pair | _ -> None)

let described cdp tab backend =
  match
    attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session
      "DOM.describeNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int 0)) ])
  with
  | Error _ -> None
  | Ok json -> (
      match E.Of_json.(at [ "node"; "nodeId" ] int) json with
      | Ok node -> Some node
      | Error _ -> None)

let disabled (row : P.row) =
  match row.state with
  | Some states ->
      List.exists (fun state -> P.Row_state.to_string state = "disabled") states
  | None -> false

type target = { row : P.row; backend : int; node : int }

let revalidate cdp tab ?snapshot_id ~index () =
  let* loader, rows =
    match snapshot_id with Some id -> current tab id | None -> current_any tab
  in
  let* row, backend =
    match List.find_opt (fun ((row : P.row), _) -> row.index = index) rows with
    | Some target -> Ok target
    | None -> fail "no-such-row" (Printf.sprintf "index %d is not in the snapshot" index)
  in
  if disabled row then fail "row-not-actionable" "the row is disabled"
  else
    let* () = loader_unchanged cdp tab loader in
    match accessed cdp tab backend with
    | None -> fail_stale tab "the row no longer resolves; snap again"
    | Some (role, name) when role <> row.role || name <> row.name ->
        fail_stale tab "the row changed since the snapshot; snap again"
    | Some _ -> (
        match described cdp tab backend with
        | None -> fail_stale tab "the row no longer resolves; snap again"
        | Some node -> Ok { row; backend; node })

let quads cdp tab backend =
  let* json =
    call cdp ~session:tab.session "DOM.getContentQuads"
      (E.object_ [ ("backendNodeId", Some (E.int backend)) ])
  in
  match E.Of_json.(field "quads" (list (list float))) json with
  | Ok quads -> Ok quads
  | Error why -> fail "internal" ("the browser's quads did not decode: " ^ issue why)

let centre quads =
  List.find_map
    (function
      | [ x1; y1; x2; y2; x3; y3; x4; y4 ] ->
          let xs = [ x1; x2; x3; x4 ] and ys = [ y1; y2; y3; y4 ] in
          let width = List.fold_left max x1 xs -. List.fold_left min x1 xs in
          let height = List.fold_left max y1 ys -. List.fold_left min y1 ys in
          if width > 0. && height > 0. then
            Some ((x1 +. x2 +. x3 +. x4) /. 4., (y1 +. y2 +. y3 +. y4) /. 4.)
          else None
      | _ -> None)
    quads

let point cdp tab backend =
  let* quads = quads cdp tab backend in
  match centre quads with
  | Some point -> Ok point
  | None -> fail "row-not-actionable" "the row has no box at its click point"

(* Whether the hit node is the row or one of its descendants. The hit test answers with
   the deepest node at the point — a button with a label span answers with the span — and
   Chrome's DOM.describeNode carries no parent chain for the nodes it describes (a subtree
   describe reports a zero parentId), so descendanthood is decided by walking the row's
   own subtree: one call, bounded here. *)
let subtree_contains cdp tab ~backend ~hit =
  match
    attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session
      "DOM.describeNode"
      (E.object_
         [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int (-1))) ])
  with
  | Error _ -> false
  | Ok json -> (
      match E.member "node" json with
      | None -> false
      | Some node ->
          let budget = ref 8192 in
          let rec walk node =
            if !budget <= 0 then false
            else (
              decr budget;
              match E.Of_json.(field "backendNodeId" (try_or_none int)) node with
              | Ok (Some id) when id = hit -> true
              | _ -> (
                  match E.array_member "children" node with
                  | Some children -> List.exists walk children
                  | None -> false))
          in
          walk node)

(* The click point must hit-test to the row or to one of its descendants: an overlay that
   covers the row answers with another node, and a row scrolled out of the viewport has
   no node at the point at all. A scroll is not staleness (ADR-0004), so a miss is given
   one [scrollIntoViewIfNeeded] and a fresh aim before it is refused. *)
let hit_test cdp tab ~backend ~x ~y =
  match
    attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session
      "DOM.getNodeForLocation"
      (E.object_
         [
           ("x", Some (E.int (int_of_float (floor (x +. 0.5)))));
           ("y", Some (E.int (int_of_float (floor (y +. 0.5)))));
           ("includeUserAgentShadowDOM", Some (E.bool false));
         ])
  with
  | Error _ -> false
  | Ok json -> (
      match E.Of_json.(field "backendNodeId" (try_or_none int)) json with
      | Ok (Some hit) when hit = backend -> true
      | Ok (Some hit) -> subtree_contains cdp tab ~backend ~hit
      | _ -> false)

let aim cdp tab (target : target) =
  let* x, y = point cdp tab target.backend in
  if hit_test cdp tab ~backend:target.backend ~x ~y then Ok (x, y)
  else
    let* () =
      match
        attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session
          "DOM.scrollIntoViewIfNeeded"
          (E.object_ [ ("backendNodeId", Some (E.int target.backend)) ])
      with
      | Ok _ -> Ok ()
      | Error _ -> Ok ()
    in
    let* x, y = point cdp tab target.backend in
    if hit_test cdp tab ~backend:target.backend ~x ~y then Ok (x, y)
    else fail "row-not-actionable" "the row is covered at its click point"

let mouse cdp tab ~type_ ~x ~y ~buttons =
  let* _ =
    call cdp ~session:tab.session "Input.dispatchMouseEvent"
      (E.object_
         [
           ("type", Some (E.string type_));
           ("x", E.float x);
           ("y", E.float y);
           ("button", Some (E.string "left"));
           ("buttons", Some (E.int buttons));
           ("clickCount", Some (E.int 1));
         ])
  in
  Ok ()

let frames_expression =
  "new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => \
   resolve(true))));"

let suggestions_expression =
  "new Promise(resolve => requestAnimationFrame(() => { const visible = () => \
   Array.from(document.querySelectorAll('[role=listbox],[role=option],datalist \
   option')).some(el => { const rect = el.getBoundingClientRect(); const style = \
   getComputedStyle(el); return rect.width > 0 && rect.height > 0 && style.display !== \
   'none' && style.visibility !== 'hidden'; }); resolve(visible()); }));"

let evaluate ?deadline cdp tab expression =
  attempt ?deadline cdp ~session:tab.session "Runtime.evaluate"
    (E.object_
       [
         ("expression", Some (E.string expression));
         ("returnByValue", Some (E.bool true));
         ("awaitPromise", Some (E.bool true));
       ])

(* Settlement is bounded and never fails the action: two animation frames or fifty
   milliseconds, and after typing into a combobox up to ten frames (about two hundred
   milliseconds) polling for visible suggestions. A page that stops answering ends the
   wait rather than the action. *)
let settle_suggestions cdp tab =
  let rec poll remaining =
    if remaining = 0 then ()
    else
      match evaluate ~deadline:(Eta.Duration.ms 20) cdp tab suggestions_expression with
      | Error _ -> ()
      | Ok json -> (
          match E.Of_json.(at [ "result"; "value" ] (try_or_none bool)) json with
          | Ok (Some true) -> ()
          | _ -> poll (remaining - 1))
  in
  poll 10

let settle cdp tab ~combobox =
  if combobox then settle_suggestions cdp tab
  else ignore (evaluate ~deadline:(Eta.Duration.ms 50) cdp tab frames_expression);
  Ok ()

let focus_row cdp tab backend =
  match
    attempt ~deadline:(Eta.Duration.seconds 30) cdp ~session:tab.session "DOM.focus"
      (E.object_ [ ("backendNodeId", Some (E.int backend)) ])
  with
  | Ok _ -> Ok ()
  | Error _ -> fail "row-not-actionable" "the row cannot take focus"

type key = { key : string; code : string; vk : int; text : string option }

let key_spec = function
  | "Enter" ->
      Some
        {
          key = "Enter";
          code = "Enter";
          vk = 13;
          text = Some (String.make 1 (Char.chr 13));
        }
  | "Escape" | "Esc" -> Some { key = "Escape"; code = "Escape"; vk = 27; text = None }
  | "Tab" -> Some { key = "Tab"; code = "Tab"; vk = 9; text = None }
  | "Backspace" -> Some { key = "Backspace"; code = "Backspace"; vk = 8; text = None }
  | "Delete" -> Some { key = "Delete"; code = "Delete"; vk = 46; text = None }
  | "ArrowUp" -> Some { key = "ArrowUp"; code = "ArrowUp"; vk = 38; text = None }
  | "ArrowDown" -> Some { key = "ArrowDown"; code = "ArrowDown"; vk = 40; text = None }
  | "ArrowLeft" -> Some { key = "ArrowLeft"; code = "ArrowLeft"; vk = 37; text = None }
  | "ArrowRight" -> Some { key = "ArrowRight"; code = "ArrowRight"; vk = 39; text = None }
  | "Home" -> Some { key = "Home"; code = "Home"; vk = 36; text = None }
  | "End" -> Some { key = "End"; code = "End"; vk = 35; text = None }
  | "PageUp" -> Some { key = "PageUp"; code = "PageUp"; vk = 33; text = None }
  | "PageDown" -> Some { key = "PageDown"; code = "PageDown"; vk = 34; text = None }
  | "Space" -> Some { key = " "; code = "Space"; vk = 32; text = Some " " }
  | name when String.length name = 1 -> (
      let c = name.[0] in
      if c >= 'a' && c <= 'z' then
        Some
          {
            key = name;
            code = "Key" ^ String.uppercase_ascii name;
            vk = Char.code (Char.uppercase_ascii c);
            text = Some name;
          }
      else if c >= '0' && c <= '9' then
        Some { key = name; code = "Digit" ^ name; vk = Char.code c; text = Some name }
      else
        let punctuation =
          [
            ("-", ("Minus", 189));
            ("=", ("Equal", 187));
            ("[", ("BracketLeft", 219));
            ("]", ("BracketRight", 221));
            (";", ("Semicolon", 186));
            (",", ("Comma", 188));
            (".", ("Period", 190));
            ("/", ("Slash", 191));
            ("'", ("Quote", 222));
          ]
        in
        match List.assoc_opt name punctuation with
        | Some (code, vk) -> Some { key = name; code; vk; text = Some name }
        | None -> None)
  | _ -> None

let key_event ?(modifiers = 0) cdp tab ~type_ spec =
  let fields =
    [
      ("type", Some (E.string type_));
      ("modifiers", Some (E.int modifiers));
      ("key", Some (E.string spec.key));
      ("code", Some (E.string spec.code));
      ("windowsVirtualKeyCode", Some (E.int spec.vk));
      ("nativeVirtualKeyCode", Some (E.int spec.vk));
    ]
    @
    match spec.text with
    | Some text ->
        [ ("text", Some (E.string text)); ("unmodifiedText", Some (E.string text)) ]
    | None -> []
  in
  let* _ = call cdp ~session:tab.session "Input.dispatchKeyEvent" (E.object_ fields) in
  Ok ()

let press_key cdp tab name =
  match key_spec name with
  | None -> fail "invalid-request" (Printf.sprintf "unknown key name %s" name)
  | Some spec ->
      let* () = key_event cdp tab ~type_:"keyDown" spec in
      key_event cdp tab ~type_:"keyUp" spec

let select_content cdp tab =
  let spec = { key = "a"; code = "KeyA"; vk = 65; text = None } in
  let* () = key_event ~modifiers:2 cdp tab ~type_:"keyDown" spec in
  key_event ~modifiers:2 cdp tab ~type_:"keyUp" spec

let insert_text cdp tab text =
  let* _ =
    call cdp ~session:tab.session "Input.insertText"
      (E.object_ [ ("text", Some (E.string text)) ])
  in
  Ok ()

(* Blur is what gives a framework-controlled input its change event after
   [Input.insertText]. It is bounded and best effort: a change handler that opens a
   dialog blocks the renderer, and the reply must still report that dialog. *)
let blur cdp tab =
  ignore
    (evaluate ~deadline:(Eta.Duration.seconds 1) cdp tab
       "document.activeElement && document.activeElement.blur()");
  Ok ()

let resolve_node cdp tab backend =
  let* json =
    call cdp ~session:tab.session "DOM.resolveNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)) ])
  in
  match E.Of_json.(at [ "object"; "objectId" ] string) json with
  | Ok object_id -> Ok object_id
  | Error _ -> fail "row-not-actionable" "the row cannot be resolved as an object"

let choose_expression =
  "function (index) { const option = this.options[index]; if (!option) { return null; } \
   option.selected = true; this.dispatchEvent(new Event('input', { bubbles: true })); \
   this.dispatchEvent(new Event('change', { bubbles: true })); return this.value; }"

let choose cdp tab object_id index =
  let* json =
    call cdp ~session:tab.session "Runtime.callFunctionOn"
      (E.object_
         [
           ("objectId", Some (E.string object_id));
           ("functionDeclaration", Some (E.string choose_expression));
           ("arguments", Some (E.array [ E.object_ [ ("value", Some (E.int index)) ] ]));
           ("returnByValue", Some (E.bool true));
         ])
  in
  match E.Of_json.(at [ "result"; "value" ] (try_or_none string)) json with
  | Ok (Some _) -> Ok ()
  | _ -> fail "invalid-request" (Printf.sprintf "the select has no option %d" index)

let viewport cdp tab =
  let* json = call cdp ~session:tab.session "Page.getLayoutMetrics" (E.object_ []) in
  let decode =
    E.Of_json.(
      fun json ->
        let* width =
          one_of
            [
              at [ "cssLayoutViewport"; "clientWidth" ] float;
              at [ "layoutViewport"; "clientWidth" ] float;
            ]
            json
        in
        let+ height =
          one_of
            [
              at [ "cssLayoutViewport"; "clientHeight" ] float;
              at [ "layoutViewport"; "clientHeight" ] float;
            ]
            json
        in
        (width, height))
  in
  match decode json with
  | Ok (width, height) -> Ok (width, height)
  | Error why -> fail "internal" ("the browser's viewport did not decode: " ^ issue why)

let clamp ~width ~height (x, y) =
  (max 1. (min (width -. 1.) x), max 1. (min (height -. 1.) y))

(* The reply reports the page as it is after the action: url and title from the tab's
   target, any dialog that opened, and the tabs this action opened (tab-tm6c, tab-8k2g).
   Taking a fresh snapshot is not part of settling, so the snapshot id is always null and
   the caller decides when to observe again. *)
let result tab before =
  tab.refresh ();
  let url, title = tab.page () in
  (* tab-8k2g: only a tab that was not there when the action began, that Chrome says
     this tab opened, and that the caller owns. Another agent's concurrent tab has
     another opener, or another owner, and is never reported as this caller's. *)
  let popups =
    tab.all_tabs ()
    |> List.filter_map (fun ((info : P.tab_info), opener) ->
        let fresh = not (List.mem (P.Handle.to_string info.tab) before) in
        if fresh && opener = Some tab.target && info.owner = Some tab.owner then Some info
        else None)
  in
  P.{ tab = tab.handle; url; title; snapshot = None; dialog = tab.dialog (); popups }

let with_result tab dispatch =
  let before = handles tab in
  let* () = dispatch () in
  Ok (result tab before)

let guarded tab dispatch =
  match tab.dialog () with
  | Some _ -> fail "dialog-open" "a dialog blocks the page; answer it first"
  | None -> dispatch ()

let click ~cdp tab (args : P.click_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* target =
            revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
          in
          let* x, y = aim cdp tab target in
          let* () = mouse cdp tab ~type_:"mousePressed" ~x ~y ~buttons:1 in
          let* () = mouse cdp tab ~type_:"mouseReleased" ~x ~y ~buttons:0 in
          settle cdp tab ~combobox:false))

let text_controls = [ "textbox"; "searchbox"; "combobox"; "spinbutton" ]

let fill ~cdp tab (args : P.fill_args) =
  if String.length args.text > 65_536 then fail "too-large" "fill text is over 64 KiB"
  else
    guarded tab (fun () ->
        with_result tab (fun () ->
            let* target =
              revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
            in
            if not (List.mem target.row.role text_controls) then
              fail "row-not-actionable" "the row is not a text control"
            else
              let* () = focus_row cdp tab target.backend in
              let* () = select_content cdp tab in
              let* () = insert_text cdp tab args.text in
              let* () = blur cdp tab in
              settle cdp tab ~combobox:(target.row.role = "combobox")))

let press ~cdp tab (args : P.press_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* loader, _ = current tab args.snapshot in
          let* () = loader_unchanged cdp tab loader in
          let* () =
            match args.index with
            | None -> Ok ()
            | Some index ->
                let* target = revalidate cdp tab ~snapshot_id:args.snapshot ~index () in
                focus_row cdp tab target.backend
          in
          press_key cdp tab args.key))

let select ~cdp tab (args : P.select_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* target =
            revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
          in
          if not (List.mem target.row.role [ "combobox"; "listbox" ]) then
            fail "row-not-actionable" "the row is not a native select"
          else
            let* object_id = resolve_node cdp tab target.backend in
            let* () = choose cdp tab object_id args.option in
            settle cdp tab ~combobox:false))

let scroll ~cdp tab (args : P.scroll_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let down = P.Direction.to_string args.direction = "down" in
          let* width, height = viewport cdp tab in
          let* x, y =
            match args.index with
            | None -> Ok (width /. 2., height /. 2.)
            | Some index ->
                let* target = revalidate cdp tab ~index () in
                let* point = point cdp tab target.backend in
                Ok (clamp ~width ~height point)
          in
          let delta = if down then height else -.height in
          let* _ =
            call cdp ~session:tab.session "Input.dispatchMouseEvent"
              (E.object_
                 [
                   ("type", Some (E.string "mouseWheel"));
                   ("x", E.float x);
                   ("y", E.float y);
                   ("deltaX", Some (E.int 0));
                   ("deltaY", Some (E.int (int_of_float delta)));
                   ("pointerType", Some (E.string "mouse"));
                 ])
          in
          settle cdp tab ~combobox:false))
