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
      (** The caller: the acted-on tab was reached through it, so a popup it opened is the
          caller's and no one else's (tab-8k2g). *)
  page : unit -> string * string;
  refresh : unit -> unit;
  snapshot : unit -> (P.Snapshot_id.t * string * (P.row * int) list) option;
  dom_snapshot : unit -> bool;
      (** field-jkx6: the current table was derived from the DOM, not the AX tree.
          Revalidation then identifies the row by backend node, not by accessible role and
          name. *)
  dialog : unit -> P.dialog option;
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
      (** One pending acknowledgement of the tab (tab-0ohq): created before a trusted
          input is dispatched and woken by the registry when the popup that input opened
          appears, or when the tab's own target dies. *)
  all_tabs : unit -> (P.popup_info * string * string option) list;
  engage : unit -> unit;
      (** Turn the page's focus emulation on for the rest of this operation (tab-8la3,
          chrome-9ex7). Called before anything the page sees -- focus, input, the settle
          -- and never for a request refused before that. *)
  sleep : float -> unit;
      (** A bounded wait that dispatches no input. Used only to re-check a fully
          transparent cover. *)
  same_document : unit -> int;
  net_seq : unit -> int;
  requests_since : int -> bool;
  reread : unit -> unit;
  arm_transition : unit -> unit;
  armed_document : unit -> int;
  armed_net : unit -> int;
}

(* One CDP call. Only pre-dispatch observation may be repeated inside this module, and
   then only the read pair a revalidation is made of; a failure after dispatch is the
   action's failure and is never replayed (tab-1lhx). Every call is bounded by the one
   deadline, a dispatch included: a reply that is withheld is settled by the popup or by
   the target's death, never by a bound of the dispatch's own (tab-0ohq). *)
let call_deadline = Ox.Duration.seconds 30

type failure = Refused of int * string | Transport of string | Timed_out

let attempt ?deadline cdp ~session method_ params =
  match Cdp.call cdp ~session ?deadline method_ params with
  | Error `Timeout -> Error Timed_out
  | Error _ -> Error (Transport "the browser connection failed")
  | Ok reply -> (
      match Cdp.error_of_reply reply with
      | Some (number, message) -> Error (Refused (number, message))
      | None -> (
          match Cdp.result reply with
          | Some result -> Ok result
          | None -> Error (Transport "the browser's reply carried no result")))

(* field-cde7: a session call that runs out its deadline is the renderer, not the
   browser. Browser-level calls do not come through here. *)
let unresponsive () = fail "renderer-unresponsive" "browser operation timed out"

let call cdp ~session method_ params =
  match attempt ~deadline:call_deadline cdp ~session method_ params with
  | Ok json -> Ok json
  | Error Timed_out -> unresponsive ()
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
      else unresponsive ()
  | `Reply (Error _) ->
      fail "browser-unavailable" "Chrome did not answer; try again shortly"

let handles tab = List.map (fun (_, id, _) -> id) (tab.all_tabs ())

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

(* field-jkx6: a DOM-derived row has no AX role to compare, so identity is the node
   itself. A connected node has a nonzero nodeId, and the backend id Chrome returns must
   be the one that was asked for. A reply that names another backend, or a disconnected
   node, is staleness. *)
let described_identity cdp tab backend =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.describeNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int 0)) ])
  with
  | Error _ -> None
  | Ok json -> (
      match
        ( E.Of_json.(at [ "node"; "nodeId" ] int) json,
          E.Of_json.(at [ "node"; "backendNodeId" ] int) json )
      with
      | Ok node, Ok returned when node <> 0 && returned = backend -> Some node
      | _ -> None)

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
    if tab.dom_snapshot () then
      (* field-jkx6: a DOM-derived row has no AX role to compare. The backend node
         still resolving is the identity check; visibility stays with the hit test. *)
      match described_identity cdp tab backend with
      | None -> fail_stale tab "the row no longer resolves; snap again"
      | Some node -> Ok { row; backend; node }
    else
      match accessed cdp tab backend with
      | None -> fail_stale tab "the row no longer resolves; snap again"
      | Some (role, name)
        when Snapshot_source.row_role role <> row.role || name <> row.name ->
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
   one [scrollIntoViewIfNeeded] and a fresh aim before it is refused. field-uls3: a
   covering LABEL whose control is the target, or which contains it, is the click. *)
let hit_backend cdp tab ~x ~y =
  match document_offset cdp tab with
  | None -> Ok None
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
      | Error Timed_out -> unresponsive ()
      | Error _ -> Ok None
      | Ok json -> (
          match E.Of_json.(field "backendNodeId" (try_or_none int)) json with
          | Ok hit -> Ok hit
          | Error _ -> Ok None))

let node_name cdp tab backend =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.describeNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)); ("depth", Some (E.int 0)) ])
  with
  | Error _ -> Error `Probe
  | Ok json -> (
      match E.Of_json.(at [ "node"; "nodeName" ] string) json with
      | Ok name -> Ok (Some (String.uppercase_ascii name))
      | Error _ -> Ok None)

(* HTMLLabelElement.control is the labeled element, whether the label wraps it or names
   it with for=. The object id comes back from the page; describeNode turns it into the
   backend id the snapshot row carries. *)
let label_control cdp tab label =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.resolveNode"
      (E.object_ [ ("backendNodeId", Some (E.int label)) ])
  with
  | Error Timed_out -> unresponsive ()
  | Error _ -> Ok None
  | Ok resolved -> (
      match E.Of_json.(at [ "object"; "objectId" ] string) resolved with
      | Error _ -> Ok None
      | Ok object_id -> (
          match
            attempt ~deadline:call_deadline cdp ~session:tab.session
              "Runtime.callFunctionOn"
              (E.object_
                 [
                   ("objectId", Some (E.string object_id));
                   ( "functionDeclaration",
                     Some (E.string "function () { return this.control || null; }") );
                   ("returnByValue", Some (E.bool false));
                 ])
          with
          | Error Timed_out -> unresponsive ()
          | Error _ -> Ok None
          | Ok called -> (
              match
                E.Of_json.(at [ "result"; "objectId" ] (try_or_none string)) called
              with
              | Ok (Some control_id) -> (
                  match
                    attempt ~deadline:call_deadline cdp ~session:tab.session
                      "DOM.describeNode"
                      (E.object_
                         [
                           ("objectId", Some (E.string control_id));
                           ("depth", Some (E.int 0));
                         ])
                  with
                  | Error Timed_out -> unresponsive ()
                  | Error _ -> Ok None
                  | Ok described -> (
                      match E.Of_json.(at [ "node"; "backendNodeId" ] int) described with
                      | Ok id -> Ok (Some id)
                      | Error _ -> Ok None))
              | _ -> Ok None)))

(* A probe the fixture does not answer, or that fails, is not a label. It must not
   become browser-unavailable or renderer-unresponsive: the old covered verdict stands. *)
let label_covers cdp tab ~target ~hit =
  match node_name cdp tab hit with
  | Error `Probe -> Error `Probe
  | Ok (Some "LABEL") -> (
      if subtree_contains cdp tab ~backend:hit ~hit:target.backend then Ok true
      else
        match label_control cdp tab hit with
        | Error _ -> Error `Probe
        | Ok control -> Ok (control = Some target.backend))
  | Ok _ -> Ok false

type aim = { x : float; y : float; via : string option }

(* Computed opacity 0, on the hit or an ancestor, is a transition layer: the
   element still receives the hit test (pointer-events stay auto) but it is not a
   cover to click through. A failed probe is not transparency. *)
let fully_transparent_expression =
  "function () { let node = this; while (node && node.nodeType === 1) { const opacity \
   =    getComputedStyle(node).opacity; if (opacity === '0') return true; node =    \
   node.parentElement; } return false; }"

let fully_transparent cdp tab backend =
  match
    attempt ~deadline:call_deadline cdp ~session:tab.session "DOM.resolveNode"
      (E.object_ [ ("backendNodeId", Some (E.int backend)) ])
  with
  | Error _ -> false
  | Ok resolved -> (
      match E.Of_json.(at [ "object"; "objectId" ] string) resolved with
      | Error _ -> false
      | Ok object_id -> (
          match
            attempt ~deadline:call_deadline cdp ~session:tab.session
              "Runtime.callFunctionOn"
              (E.object_
                 [
                   ("objectId", Some (E.string object_id));
                   ("functionDeclaration", Some (E.string fully_transparent_expression));
                   ("returnByValue", Some (E.bool true));
                 ])
          with
          | Error _ -> false
          | Ok called -> (
              match E.Of_json.(at [ "result"; "value" ] (try_or_none bool)) called with
              | Ok (Some true) -> true
              | _ -> false)))

let classify cdp tab (target : target) x y =
  let* hit = hit_backend cdp tab ~x ~y in
  match hit with
  | Some id
    when id = target.backend || subtree_contains cdp tab ~backend:target.backend ~hit:id
    ->
      Ok `Direct
  | Some id -> (
      match label_covers cdp tab ~target ~hit:id with
      | Error `Probe -> Ok `Probe_failed
      | Ok true -> Ok `Label
      | Ok false when fully_transparent cdp tab id -> Ok `Transparent
      | Ok false -> Ok `Covered)
  | None -> Ok `Miss

(* A fully transparent cover is re-checked, not clicked through and not aimed by
   a coordinate. Twenty steps of 100 ms is the two-second bound. *)
let transparent_step_s = 0.1
let transparent_steps = 20

let aim cdp tab (target : target) =
  let poll () =
    let* x, y = point cdp tab target.backend in
    let* kind = classify cdp tab target x y in
    match kind with
    | `Direct -> Ok (`Ready { x; y; via = None })
    | `Label -> Ok (`Ready { x; y; via = Some "label" })
    | `Transparent -> Ok `Wait
    | `Probe_failed -> fail "row-not-actionable" "the row is covered at its click point"
    | `Covered | `Miss -> Ok `Blocked
  in
  let rec wait_clear left =
    match poll () with
    | Error e -> Error e
    | Ok (`Ready point) -> Ok (Some point)
    | Ok `Wait when left > 0 ->
        tab.sleep transparent_step_s;
        wait_clear (left - 1)
    | Ok (`Wait | `Blocked) -> Ok None
  in
  match wait_clear transparent_steps with
  | Error e -> Error e
  | Ok (Some point) -> Ok point
  | Ok None -> (
      let* () =
        match
          attempt ~deadline:call_deadline cdp ~session:tab.session
            "DOM.scrollIntoViewIfNeeded"
            (E.object_ [ ("backendNodeId", Some (E.int target.backend)) ])
        with
        | Ok _ -> Ok ()
        | Error Timed_out -> unresponsive ()
        | Error _ -> Ok ()
      in
      match poll () with
      | Error e -> Error e
      | Ok (`Ready point) -> Ok point
      | Ok (`Wait | `Blocked) ->
          fail "row-not-actionable" "the row is covered at its click point")

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

(* A same-document navigation can land hundreds of milliseconds after the input
   acknowledgement. Poll while one is in progress, the URL is still moving, or a request
   started by this action is in flight. A quiet page returns on the first check, so a
   click that changes nothing does not wait out the bound. *)
let transition_bound_s = 1.5
let transition_poll_s = 0.05

let wait_for_transition tab =
  let url () = fst (tab.page ()) in
  let started = tab.armed_net () in
  let armed_doc = tab.armed_document () in
  Eio.Fiber.yield ();
  (* A quiet action does not read the target again. Cross-document loads already do that
     in [refresh]; an extra read here changes the count those tests pin. *)
  if not (tab.requests_since started || tab.same_document () > armed_doc) then ()
  else
    let rec loop elapsed last_url last_doc =
      tab.reread ();
      let url = url () in
      let doc = tab.same_document () in
      let moving = url <> last_url || doc <> last_doc || tab.requests_since started in
      if (not moving) || elapsed +. transition_poll_s > transition_bound_s then ()
      else (
        tab.sleep transition_poll_s;
        loop (elapsed +. transition_poll_s) url doc)
    in
    loop 0. (url ()) (tab.same_document ())

let settle cdp tab ~combobox =
  tab.engage ();
  if combobox then settle_suggestions cdp tab
  else ignore (evaluate ~deadline:(Ox.Duration.ms 50) cdp tab frames_expression);
  wait_for_transition tab;
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

let checked_expression =
  "function () { if (typeof this.checked === 'boolean') return this.checked; const aria \
   = this.getAttribute && this.getAttribute('aria-checked'); if (aria === 'true') return \
   true; if (aria === 'false') return false; return null; }"

let read_checked cdp tab backend =
  let* object_id = resolve_node cdp tab backend in
  let* json =
    call cdp ~session:tab.session "Runtime.callFunctionOn"
      (E.object_
         [
           ("objectId", Some (E.string object_id));
           ("functionDeclaration", Some (E.string checked_expression));
           ("returnByValue", Some (E.bool true));
         ])
  in
  match E.Of_json.(at [ "result"; "value" ] (try_or_none bool)) json with
  | Ok value -> Ok value
  | Error _ -> Ok None

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
   A fresh snapshot is not taken here; the registry attaches one when the request asked
   (field-swvb). [via] stays absent until a click sets it (field-uls3). *)
let result tab before =
  if tab.dialog () = None then tab.refresh ();
  let url, title = tab.page () in

  let popups =
    tab.all_tabs ()
    |> List.filter_map (fun ((info : P.popup_info), id, opener) ->
        let fresh = not (List.mem id before) in
        if fresh && opener = Some tab.target then Some info else None)
  in
  P.
    {
      tab = tab.handle;
      url;
      title;
      snapshot = None;
      dialog = tab.dialog ();
      popups;
      via = None;
    }

let with_result tab dispatch =
  let before = handles tab in
  tab.arm_transition ();
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
  let via = ref None in
  let* result =
    guarded tab (fun () ->
        with_result tab (fun () ->
            let* target =
              revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index ()
            in
            let* point = aim cdp tab target in
            via := point.via;
            let* () =
              mouse cdp tab ~type_:"mousePressed" ~x:point.x ~y:point.y ~buttons:1
            in
            let* () =
              mouse cdp tab ~type_:"mouseReleased" ~x:point.x ~y:point.y ~buttons:0
            in
            if settle_after then settle cdp tab ~combobox:false else Ok ()))
  in
  Ok { result with P.via = !via }

(* field-guda: click the control (following a covering label, field-uls3), then read
   checked. Already in the requested state is state-unchanged without a click, so a
   second check does not flip the control the other way. *)
let set_checked ~want ~cdp tab (args : P.click_args) =
  guarded tab (fun () ->
      let* target = revalidate cdp tab ~snapshot_id:args.snapshot ~index:args.index () in
      let* before = read_checked cdp tab target.backend in
      match before with
      | None -> fail "row-not-actionable" "the row is not a checkable control"
      | Some current when current = want ->
          fail "state-unchanged"
            (if want then "the control was already checked"
             else "the control was already unchecked")
      | Some _ -> (
          let via = ref None in
          let* result =
            with_result tab (fun () ->
                let* point = aim cdp tab target in
                via := point.via;
                let* () =
                  mouse cdp tab ~type_:"mousePressed" ~x:point.x ~y:point.y ~buttons:1
                in
                let* () =
                  mouse cdp tab ~type_:"mouseReleased" ~x:point.x ~y:point.y ~buttons:0
                in
                settle cdp tab ~combobox:false)
          in
          let* after = read_checked cdp tab target.backend in
          match after with
          | Some value when value = want -> Ok { result with P.via = !via }
          | _ -> fail "state-unchanged" "the control's checked state did not change"))

let check ~cdp = set_checked ~want:true ~cdp
let uncheck ~cdp = set_checked ~want:false ~cdp
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
          let* point = aim cdp tab target in
          let* () =
            dispatch cdp tab "Input.dispatchMouseEvent"
              (E.object_
                 [
                   ("type", Some (E.string "mouseMoved"));
                   ("x", E.float point.x);
                   ("y", E.float point.y);
                   ("button", Some (E.string "none"));
                   ("buttons", Some (E.int 0));
                 ])
          in
          settle cdp tab ~combobox:false))

(* hard-o3za hard-qimz: the files are the caller's, named by absolute path, and must
   be readable regular files here — the service and Chrome are one user's processes on
   one machine. At most ten, 10 GiB together; sizes are int64 so a multi-gigabyte file
   is not truncated. Each limit is refused before anything reaches the browser. *)
let max_upload_files = 10
let max_upload_bytes = Int64.mul 10L (Int64.mul 1024L (Int64.mul 1024L 1024L))

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
                let stat = Unix.LargeFile.stat path in
                if stat.Unix.LargeFile.st_kind <> Unix.S_REG then None
                else (
                  close_in (Ox_caps.Cap_stdlib.open_in_bin ~caps path);
                  Some stat.Unix.LargeFile.st_size)
              with Unix.Unix_error _ | Sys_error _ -> None
            with
            | None -> fail "invalid-request" "upload paths must be readable regular files"
            | Some size -> sizes (Int64.add total size) rest)
    in
    let* total = sizes 0L paths in
    if total > max_upload_bytes then fail "too-large" "the files are over 10 GiB together"
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
          (* pbk-eyya: a wheel scroll lands asynchronously (smooth scrolling). The next
             observation must see where it landed, or three scrolls read as a stall — the
             Default category's page 4 did. Wait, bounded, for scrollY to move. *)
          let before =
            match
              evaluate ~deadline:(Ox.Duration.ms 50) cdp tab "String(window.scrollY)"
            with
            | Ok json -> (
                match E.Of_json.(at [ "result"; "value" ] (try_or_none string)) json with
                | Ok (Some y)
                  when y <> ""
                       && String.for_all
                            (fun c ->
                              (c >= '0' && c <= '9') || c = '.' || c = '-' || c = 'e')
                            y ->
                    Some y
                | _ -> None)
            | Error _ -> None
          in
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
          (match before with
          | None -> ()
          | Some y -> (
              let landed =
                evaluate ~deadline:(Ox.Duration.ms 700) cdp tab
                  (Printf.sprintf
                     "new Promise(r=>{const s=performance.now();let \
                      last=window.scrollY,still=0;(function f(){const \
                      y=window.scrollY;if(y!==%s){if(y===last){still++;if(still>=2)return \
                      r(String(y))}else{still=0;last=y}}if(performance.now()-s>500)return \
                      r(String(y));setTimeout(f,16)})()})"
                     y)
              in
              match landed with
              | Ok json -> (
                  match
                    E.Of_json.(at [ "result"; "value" ] (try_or_none string)) json
                  with
                  | Ok (Some after) when after = y ->
                      (* The wheel has not landed within half a second (a renderer
                         short of frames defers it): put the document where the wheel
                         was taking it, instantly. An absolute instant scroll replaces a
                         smooth one still in flight, so the wheel cannot land twice. *)
                      ignore
                        (evaluate ~deadline:(Ox.Duration.ms 300) cdp tab
                           (Printf.sprintf
                              "window.scrollTo({top:Math.max(0,%s+(%d)),behavior:'instant'}),String(window.scrollY)"
                              y delta))
                  | _ -> ())
              | Error _ -> ()));
          Ok ()))

let operator_settle ~cdp tab ~autocomplete =
  let bound = if autocomplete then 200 else 50 in
  ignore
    (evaluate ~deadline:(Ox.Duration.ms bound) cdp tab
       (Snapshot_source.settle_expression ~autocomplete));
  wait_for_transition tab;
  Ok ()
