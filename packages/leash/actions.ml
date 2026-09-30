(* L7 actions: action-time revalidation, trusted dispatch, bounded settlement.
   tab-bw4j tab-j1z2 tab-p3x1 tab-luo5 tab-5deq tab-8dop tab-tm6c tab-hxld tab-60kn
   tab-1lhx tab-8la3. *)

module P = Protocol
module E = Ox_json

let ( let* ) = Result.bind
let ( let+ ) result f = Result.map f result

let error ?detail name message : P.error =
  let code =
    match P.Error_code.of_string name with Ok code -> code | Error _ -> assert false
  in
  P.make_error ?detail code ~message

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
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
      (** One pending acknowledgement of the tab (tab-0ohq): created before a trusted
          input is dispatched and woken by the registry when the popup that input opened
          appears, or when the tab's own target dies. *)
  all_tabs : unit -> (P.tab_info * string option) list;
      (** Every tab in the registry, all owners, ordered by handle, paired with the target
          id of the tab that opened it when Chrome reports one ([openerId]). *)
  engage : unit -> unit;
      (** Turn the page's focus emulation on for the rest of this operation (tab-8la3,
          chrome-9ex7). Called before anything the page sees -- focus, input, the settle
          -- and never for a request refused before that. *)
}

(* One CDP call. Only pre-dispatch observation may be repeated inside this module, and
   then only the read pair a revalidation is made of; a failure after dispatch is the
   action's failure and is never replayed (tab-1lhx). Every call is bounded by the one
   deadline, a dispatch included: a reply that is withheld is settled by the popup or by
   the target's death, never by a bound of the dispatch's own (tab-0ohq). *)
let call_deadline = Ox.Duration.seconds 30

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
  match attempt ~deadline:call_deadline cdp ~session method_ params with
  | Ok json -> Ok json
  | Error (Refused (number, message)) ->
      fail "internal"
        (Printf.sprintf "the browser refused %s (%d %s)" method_ number message)
  | Error (Transport why) ->
      fail "browser-unavailable" ("Chrome did not answer; try again shortly: " ^ why)

(* The two probes a dispatch that ran out the CDP deadline still makes: is the page
   answering at all, and does the browser still know the target (own-ehqa own-teh1). *)
let liveness_timeout = Ox.Duration.seconds 2

let disposition name =
  match P.Disposition.of_string name with Ok d -> d | Error _ -> assert false

let page_alive cdp tab =
  match
    attempt ~deadline:liveness_timeout cdp ~session:tab.session "Page.getFrameTree"
      (E.object_ [])
  with
  | Ok _ -> true
  | Error _ -> false

(* L14 (own-teh1): a dispatch whose handler closes the tab destroys its own reply:
   the page is silent because its target is gone, not because the browser wedged. A
   browser session that no longer knows the target is that death. *)
let target_gone cdp tab =
  match
    Cdp.call cdp ~deadline:liveness_timeout "Target.getTargetInfo"
      (E.object_ [ ("targetId", Some (E.string tab.target)) ])
  with
  | Ok reply -> Option.is_some (Cdp.error_of_reply reply)
  | Error _ -> false

let tab_gone_externally () = P.tab_gone (disposition "closed_externally")

(* tab-0ohq tab-1lhx own-ehqa own-teh1: Chrome withholds the reply of the trusted input
   whose handler opens a popup, sometimes for as long as the popup exists
   (docs/cdp-shapes.md, L10). A dispatch is therefore settled by whichever comes first: its
   own reply, the popup Chrome reports with this tab as its opener, or this tab's target
   destroyed. There is no dispatch bound of its own; the CDP call's deadline is the only
   one left, and the target probe stays for the handler that closes its own tab when the
   report does not arrive first -- then the action reports [tab-gone] with
   [closed_externally] (own-teh1), the same answer any later command on the handle gets. A
   page that answers nothing by the deadline is [browser-unavailable]. Nothing is ever sent
   twice: the race settles the call it was given, it never re-issues it. *)
let dispatch cdp tab method_ params =
  tab.engage ();
  match
    Dispatch.first (tab.acknowledge ()) (fun () ->
        Cdp.call cdp ~session:tab.session ~deadline:call_deadline method_ params)
  with
  | `Acknowledged Dispatch.Popup -> Ok ()
  | `Acknowledged (Dispatch.Gone error) -> Error error
  | `Reply (Ok reply) -> (
      match Cdp.error_of_reply reply with
      | Some (number, message) ->
          fail "internal"
            (Printf.sprintf "the browser refused %s (%d %s)" method_ number message)
      | None -> (
          match Cdp.result reply with
          | Some _ -> Ok ()
          | None ->
              fail "browser-unavailable"
                "Chrome did not answer; try again shortly: the browser's reply carried \
                 no result"))
  | `Reply (Error `Timeout) ->
      if page_alive cdp tab then Ok ()
      else if target_gone cdp tab then Error (tab_gone_externally ())
      else fail "browser-unavailable" "Chrome did not answer; try again shortly"
  | `Reply (Error _) ->
      fail "browser-unavailable" "Chrome did not answer; try again shortly"

let handles tab =
  List.map (fun ((info : P.tab_info), _) -> P.Handle.to_string info.tab) (tab.all_tabs ())

let stale tab _message =
  P.stale_snapshot (Option.map (fun (id, _, _) -> id) (tab.snapshot ()))

let fail_stale tab message = Error (stale tab message)

let current tab id =
  match tab.snapshot () with
  | Some (snapshot, loader, rows) when snapshot = id -> Ok (loader, rows)
  | Some _ | None -> fail_stale tab ""

let current_any tab =
  match tab.snapshot () with
  | Some (_, loader, rows) -> Ok (loader, rows)
  | None -> fail_stale tab ""

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
    attempt ~deadline:call_deadline cdp ~session:tab.session
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
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.describeNode"
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

(* hard-2gnf: a file input is a row of the table under the role [file-input], which is
   Leash's word and not the accessibility tree's, so the role-and-name comparison below
   cannot hold for it — and no pointer action makes sense on it: a click would open a
   native chooser nobody can answer. Only [upload] takes it, by its own revalidation. *)
let file_input = "file-input"

let revalidate cdp tab ?snapshot_id ~index () =
  (* tab-8la3 chrome-9ex7: a page in a background window is hidden and drops input until
     it renders again, so focus emulation goes on before the action's reads, which give
     the page its frame before the input arrives. *)
  tab.engage ();
  let* loader, rows =
    match snapshot_id with Some id -> current tab id | None -> current_any tab
  in
  let* row, backend =
    match List.find_opt (fun ((row : P.row), _) -> row.index = index) rows with
    | Some target -> Ok target
    | None -> fail "no-such-row" (Printf.sprintf "index %d is not in the snapshot" index)
  in
  if row.role = file_input then
    fail "row-not-actionable" "a file input takes upload, not this action"
  else if disabled row then fail "row-not-actionable" "the row is disabled"
  else
    let* () = loader_unchanged cdp tab loader in
    match accessed cdp tab backend with
    | None -> fail_stale tab "the row no longer resolves; snap again"
    | Some (role, name) when Snapshot_source.row_role role <> row.role || name <> row.name
      ->
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

(* A hit on a button icon is valid only when it belongs to that button. Font Awesome
   renders its icon in a CSS ::before pseudo-element, which Chrome reports as the hit
   node. Check both DOM children and pseudo-elements in the described subtree
   (tab-bw4j, L34). *)
let subtree_contains cdp tab ~backend ~hit =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.describeNode"
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
              | _ ->
                  let children =
                    Option.value ~default:[] (E.array_member "children" node)
                  in
                  let pseudo =
                    Option.value ~default:[] (E.array_member "pseudoElements" node)
                  in
                  List.exists walk children || List.exists walk pseudo)
          in
          walk node)

(* DOM.getNodeForLocation takes document-space coordinates, while content quads and
   Input.dispatchMouseEvent use viewport-space coordinates. A scrolled page can
   otherwise return Chrome -32000 for a visible link (tab-bw4j, L34). *)
let document_offset cdp tab =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "Page.getLayoutMetrics"
      (E.object_ [])
  with
  | Error _ -> None
  | Ok metrics -> (
      let read viewport =
        let open E.Of_json in
        match
          (at [ viewport; "pageX" ] float metrics, at [ viewport; "pageY" ] float metrics)
        with
        | Ok x, Ok y -> Some (x, y)
        | _ -> None
      in
      match read "cssVisualViewport" with
      | Some offset -> Some offset
      | None -> read "cssLayoutViewport")

(* The click point must hit-test to the row or to one of its descendants: an overlay that
   covers the row answers with another node, and a row scrolled out of the viewport has
   no node at the point at all. A scroll is not staleness (ADR-0004), so a miss is given
   one [scrollIntoViewIfNeeded] and a fresh aim before it is refused. *)
let hit_test cdp tab ~backend ~x ~y =
  match document_offset cdp tab with
  | None -> false
  | Some (page_x, page_y) -> (
      match
        attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.getNodeForLocation"
          (E.object_
             [
               ("x", Some (E.int (int_of_float (floor (x +. page_x +. 0.5)))));
               ("y", Some (E.int (int_of_float (floor (y +. page_y +. 0.5)))));
               ("includeUserAgentShadowDOM", Some (E.bool false));
             ])
      with
      | Error _ -> false
      | Ok json -> (
          match E.Of_json.(field "backendNodeId" (try_or_none int)) json with
          | Ok (Some hit) when hit = backend -> true
          | Ok (Some hit) -> subtree_contains cdp tab ~backend ~hit
          | _ -> false))

let aim cdp tab (target : target) =
  let* x, y = point cdp tab target.backend in
  if hit_test cdp tab ~backend:target.backend ~x ~y then Ok (x, y)
  else
    let* () =
      match
        attempt ~deadline:call_deadline cdp ~session:tab.session
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
  dispatch cdp tab "Input.dispatchMouseEvent"
    (E.object_
       [
         ("type", Some (E.string type_));
         ("x", E.float x);
         ("y", E.float y);
         ("button", Some (E.string "left"));
         ("buttons", Some (E.int buttons));
         ("clickCount", Some (E.int 1));
       ])

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
      match evaluate ~deadline:(Ox.Duration.ms 20) cdp tab suggestions_expression with
      | Error _ -> ()
      | Ok json -> (
          match E.Of_json.(at [ "result"; "value" ] (try_or_none bool)) json with
          | Ok (Some true) -> ()
          | _ -> poll (remaining - 1))
  in
  poll 10

let settle cdp tab ~combobox =
  tab.engage ();
  if combobox then settle_suggestions cdp tab
  else ignore (evaluate ~deadline:(Ox.Duration.ms 50) cdp tab frames_expression);
  Ok ()

let focus_row cdp tab backend =
  tab.engage ();
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.focus"
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
  dispatch cdp tab "Input.dispatchKeyEvent" (E.object_ fields)

let press_key cdp tab name =
  match key_spec name with
  | None ->
      let accepted =
        "Enter, Tab, Backspace, Delete, ArrowUp, ArrowDown, ArrowLeft, ArrowRight, Home, \
         End, PageUp, PageDown, Escape/Esc, Space, lowercase a-z, digits 0-9, and single \
         punctuation characters - = [ ] ; , . / '"
      in
      let error = error "invalid-request" (Printf.sprintf "unknown key name %S" name) in
      Error
        {
          error with
          hint = "use one accepted key: " ^ accepted;
          detail = Some (`Assoc [ ("accepted_keys", `String accepted) ]);
        }
  | Some spec ->
      let* () = key_event cdp tab ~type_:"keyDown" spec in
      key_event cdp tab ~type_:"keyUp" spec

let select_content cdp tab =
  let spec = { key = "a"; code = "KeyA"; vk = 65; text = None } in
  let* () = key_event ~modifiers:2 cdp tab ~type_:"keyDown" spec in
  key_event ~modifiers:2 cdp tab ~type_:"keyUp" spec

let insert_text cdp tab text =
  dispatch cdp tab "Input.insertText" (E.object_ [ ("text", Some (E.string text)) ])

(* Blur is what gives a framework-controlled input its change event after
   [Input.insertText]. It is bounded and best effort: a change handler that opens a
   dialog blocks the renderer, and the reply must still report that dialog. *)
let blur cdp tab =
  ignore
    (evaluate ~deadline:(Ox.Duration.seconds 1) cdp tab
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
  if tab.dialog () = None then tab.refresh ();
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
  match
    Dialog_race.first tab.dialog_race (fun () ->
        let* () = dispatch () in
        Ok (result tab before))
  with
  | `Dialog dialog -> Ok { (result tab before) with P.dialog = Some dialog }
  | `Value outcome -> outcome

let guarded tab dispatch =
  match tab.dialog () with
  | Some _ -> fail "dialog-open" "a dialog blocks the page; answer it first"
  | None -> dispatch ()

let click ?(settle_after = true) ~cdp tab (args : P.click_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* target =
            revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
          in
          let* x, y = aim cdp tab target in
          let* () = mouse cdp tab ~type_:"mousePressed" ~x ~y ~buttons:1 in
          let* () = mouse cdp tab ~type_:"mouseReleased" ~x ~y ~buttons:0 in
          if settle_after then settle cdp tab ~combobox:false else Ok ()))

let text_controls = [ "textbox"; "searchbox"; "combobox"; "spinbutton" ]

(* daily-9ggi: Chrome's segmented date/time editors ignore Input.insertText. Detect
   the native input, not an ARIA role, and keep the ordinary trusted text path intact. *)
let temporal_input cdp tab backend =
  let* json =
    call cdp ~session:tab.session "DOM.describeNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int 0)) ])
  in
  let attributes =
    match E.Of_json.(at [ "node"; "attributes" ] (list string)) json with
    | Ok attributes -> attributes
    | Error _ -> []
  in
  let rec kind = function
    | "type" :: value :: _ ->
        List.mem
          (String.lowercase_ascii value)
          [ "time"; "date"; "datetime-local"; "month"; "week" ]
    | _ :: _ :: rest -> kind rest
    | _ -> false
  in
  Ok (E.Of_json.(at [ "node"; "nodeName" ] string) json = Ok "INPUT" && kind attributes)

let temporal_expression =
  {|function (text) {
    if (this.disabled || this.readOnly) return 'readonly';
    const probe = this.ownerDocument.createElement('input');
    probe.type = this.type;
    probe.value = text;
    if (text !== '' && probe.value === '') return 'invalid';
    const setter = Object.getOwnPropertyDescriptor(
      this.ownerDocument.defaultView.HTMLInputElement.prototype, 'value').set;
    setter.call(this, probe.value);
    this.dispatchEvent(new Event('input', {bubbles:true}));
    this.dispatchEvent(new Event('change', {bubbles:true}));
    return this.value === probe.value ? 'ok' : 'rejected';
  }|}

let fill_temporal cdp tab backend text =
  let* object_id = resolve_node cdp tab backend in
  let* json =
    call cdp ~session:tab.session "Runtime.callFunctionOn"
      (E.object_
         [
           ("objectId", Some (E.string object_id));
           ("functionDeclaration", Some (E.string temporal_expression));
           ("arguments", Some (E.array [ E.object_ [ ("value", Some (E.string text)) ] ]));
           ("returnByValue", Some (E.bool true));
         ])
  in
  match E.Of_json.(at [ "result"; "value" ] string) json with
  | Ok "ok" -> Ok ()
  | Ok "readonly" ->
      fail "row-not-actionable" "the temporal input is readonly or disabled"
  | Ok ("invalid" | "rejected") ->
      fail "invalid-request" "the temporal input did not accept that date/time value"
  | _ -> fail "internal" "the temporal input fill did not return a result"

let fill ?(settle_after = true) ?(check_hit = false) ?(blur_after = true) ~cdp tab
    (args : P.fill_args) =
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
              let* () =
                if check_hit then Result.map (fun _ -> ()) (aim cdp tab target) else Ok ()
              in
              let* temporal = temporal_input cdp tab target.backend in
              let* () = focus_row cdp tab target.backend in
              let* () =
                if temporal then fill_temporal cdp tab target.backend args.text
                else
                  let* () = select_content cdp tab in
                  insert_text cdp tab args.text
              in
              let* () = if blur_after then blur cdp tab else Ok () in
              if settle_after then settle cdp tab ~combobox:(target.row.role = "combobox")
              else Ok ()))

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

let select ?(settle_after = true) ?(check_hit = false) ~cdp tab (args : P.select_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* target =
            revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
          in
          if not (List.mem target.row.role [ "combobox"; "listbox" ]) then
            fail "row-not-actionable" "the row is not a native select"
          else
            let* () =
              if check_hit then Result.map (fun _ -> ()) (aim cdp tab target) else Ok ()
            in
            let* object_id = resolve_node cdp tab target.backend in
            let* () = choose cdp tab object_id args.option in
            if settle_after then settle cdp tab ~combobox:false else Ok ()))

(* hard-v1gs: the mouse moves to the row's revalidated point, after the same hit test a
   click makes — a covered row would not receive the hover — and settles two frames, so a
   menu the hover opens is in the page when the caller next asks for a snapshot. Nothing is
   pressed. *)
let hover ~cdp tab (args : P.hover_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* target =
            revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
          in
          let* x, y = aim cdp tab target in
          let* () =
            dispatch cdp tab "Input.dispatchMouseEvent"
              (E.object_
                 [
                   ("type", Some (E.string "mouseMoved"));
                   ("x", E.float x);
                   ("y", E.float y);
                   ("button", Some (E.string "none"));
                   ("buttons", Some (E.int 0));
                 ])
          in
          settle cdp tab ~combobox:false))

(* hard-o3za: the files are the caller's, named by absolute path, and must be readable
   regular files here — the service and Chrome are one user's processes on one machine.
   At most ten, fifty MiB together; each limit is refused before anything reaches the
   browser. *)
let max_upload_files = 10
let max_upload_bytes = 50 * 1024 * 1024

let check_files ~caps paths =
  if paths = [] || List.length paths > max_upload_files then
    fail "invalid-request" (Printf.sprintf "upload takes 1 to %d files" max_upload_files)
  else
    let rec sizes total = function
      | [] -> Ok total
      | path :: rest -> (
          if Filename.is_relative path then
            fail "invalid-request" "upload paths must be absolute"
          else
            match
              try
                let stat = Unix.stat path in
                if stat.Unix.st_kind <> Unix.S_REG then None
                else (
                  close_in (Ox_caps.Cap_stdlib.open_in_bin ~caps path);
                  Some stat.Unix.st_size)
              with Unix.Unix_error _ | Sys_error _ -> None
            with
            | None -> fail "invalid-request" "upload paths must be readable regular files"
            | Some size -> sizes (total + size) rest)
    in
    let* total = sizes 0 paths in
    if total > max_upload_bytes then fail "too-large" "the files are over 50 MiB together"
    else Ok ()

(* The row must still be the file input the snapshot saw. Its role and name cannot be
   compared (see [file_input]), so the node itself is described: it has to resolve, be an
   <input type=file>, be enabled, and take several files only when it is [multiple]. *)
let file_input_attributes cdp tab backend =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.describeNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int 0)) ])
  with
  | Error _ -> None
  | Ok json -> (
      match E.member "node" json with
      | None -> None
      | Some node ->
          let rec pairs = function
            | `String name :: `String value :: rest ->
                (String.lowercase_ascii name, value) :: pairs rest
            | _ :: _ :: rest -> pairs rest
            | _ -> []
          in
          let attributes =
            pairs (Option.value ~default:[] (E.array_member "attributes" node))
          in
          if
            E.string_member "nodeName" node = Some "INPUT"
            && Option.map String.lowercase_ascii (List.assoc_opt "type" attributes)
               = Some "file"
          then Some attributes
          else None)

let upload ~caps ~cdp tab (args : P.upload_args) =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let* () = check_files ~caps args.paths in
          let* loader, rows = current tab args.snapshot in
          let* row, backend =
            match
              List.find_opt (fun ((row : P.row), _) -> row.index = args.index) rows
            with
            | Some target -> Ok target
            | None ->
                fail "no-such-row"
                  (Printf.sprintf "index %d is not in the snapshot" args.index)
          in
          if row.role <> file_input then
            fail "row-not-actionable" "the row is not a file input"
          else
            let* () = loader_unchanged cdp tab loader in
            match file_input_attributes cdp tab backend with
            | None -> fail_stale tab "the row no longer resolves; snap again"
            | Some attributes ->
                if List.mem_assoc "disabled" attributes then
                  fail "row-not-actionable" "the file input is disabled"
                else if
                  List.length args.paths > 1 && not (List.mem_assoc "multiple" attributes)
                then fail "invalid-request" "the file input takes one file"
                else
                  let () = tab.engage () in
                  let* _ =
                    call cdp ~session:tab.session "DOM.setFileInputFiles"
                      (E.object_
                         [
                           ("files", Some (E.array (List.map E.string args.paths)));
                           ("backendNodeId", Some (E.int backend));
                         ])
                  in
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
          let () = tab.engage () in
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

(* fly-2pn7: the reference dispatches the wheel at a fixed viewport point, 560 CSS pixels,
   and does not treat that as a row action. *)
let operator_scroll ~cdp tab ~down =
  guarded tab (fun () ->
      with_result tab (fun () ->
          let delta =
            if down then Snapshot_source.scroll_delta else -Snapshot_source.scroll_delta
          in
          let* width, height = viewport cdp tab in
          let x, y = clamp ~width ~height (550., 650.) in
          let () = tab.engage () in
          let* _ =
            call cdp ~session:tab.session "Input.dispatchMouseEvent"
              (E.object_
                 [
                   ("type", Some (E.string "mouseWheel"));
                   ("x", E.float x);
                   ("y", E.float y);
                   ("deltaX", Some (E.int 0));
                   ("deltaY", Some (E.int delta));
                   ("pointerType", Some (E.string "mouse"));
                 ])
          in
          Ok ()))

let operator_settle ~cdp tab ~autocomplete =
  let bound = if autocomplete then 200 else 50 in
  match
    evaluate ~deadline:(Ox.Duration.ms bound) cdp tab
      (Snapshot_source.settle_expression ~autocomplete)
  with
  | Error _ -> Ok ()
  | Ok _ -> Ok ()
