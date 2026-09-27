module P = Protocol

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
}

let obj fields = `Assoc fields
let str s = `String s
let member key = function `Assoc fields -> List.assoc_opt key fields | _ -> None
let text key json = match member key json with Some (`String s) -> Some s | _ -> None

let enum of_string value =
  match of_string value with Ok v -> v | Error _ -> assert false

let error ?detail code message : P.error =
  { code = enum P.Error_code.of_string code; message; detail }

let unavailable () = error "browser-unavailable" "Chrome is restarting; try again shortly"

let lost () =
  error "tab-gone" "the tab is gone" ~detail:(obj [ ("disposition", str "browser_lost") ])

let refusal () =
  error "url-refused" "only http(s) URLs without userinfo and about:blank are allowed"

let valid_url url =
  if url = "about:blank" then true
  else
    let scheme =
      if String.starts_with ~prefix:"https://" url then Some 8
      else if String.starts_with ~prefix:"http://" url then Some 7
      else None
    in
    match scheme with
    | None -> false
    | Some start ->
        let last =
          let rec scan i =
            if i = String.length url || String.contains "/?#" url.[i] then i
            else scan (i + 1)
          in
          scan start
        in
        last > start
        && (not (String.contains (String.sub url start (last - start)) '@'))
        && not (String.exists (fun c -> Char.code c <= 32 || Char.code c = 127) url)

(* chrome-qnul: [new] waits for a load exactly when it was asked for a document with one
   to come. [about:blank] is already the loaded document when the target exists, so there
   is no event left to await; [Control.budget] asks this same question, so the handler's
   budget and the registry's wait cannot drift apart. *)
let waits_for_load = function Some url -> url <> "about:blank" | None -> false

let handle () =
  let bytes =
    In_channel.with_open_bin "/dev/urandom" (fun ch -> really_input_string ch 16)
  in
  let hex = "0123456789abcdef" in
  let buf = Buffer.create 34 in
  Buffer.add_string buf "t_";
  String.iter
    (fun c ->
      let v = Char.code c in
      Buffer.add_char buf hex.[v lsr 4];
      Buffer.add_char buf hex.[v land 15])
    bytes;
  enum P.Handle.of_string (Buffer.contents buf)

type tab = {
  id : string;
  session : string;
  handle : P.Handle.t;
  mutable url : string;
  mutable title : string;
  origin : P.Origin.t;
  owner : P.Owner.t option;
  generation : int;
  lock : Eio.Mutex.t;
  mutable loading : bool;
  mutable navigated : bool;
  mutable completed : bool;
  mutable load_waiter : unit Eio.Promise.u option;
  mutable snapshot : (P.Snapshot_id.t * string * (P.row * int) list) option;
  mutable dialog : P.dialog option;
  mutable counter_installed : bool;
  mutable opener : string option;
      (** The target id of the tab that opened this one, Chrome's [openerId]. *)
  reading : Reading.t;
}

type tomb = { owner : P.Owner.t option; disposition : string; at : float }

type t = {
  chrome : Chrome.t;
  now : unit -> float;
  sleep : float -> unit;
  await_load : unit Eio.Promise.t -> (unit, [ `Timeout ]) result;
  logger : Eta_observability.Logger.t;
  cap : int;
  tombstone_s : int;
  started : float;
  tabs : (string, tab) Hashtbl.t;
  targets : (string, string) Hashtbl.t;
  tombs : (string, tomb) Hashtbl.t;
  pending_humans : (string, string * Yojson.Safe.t) Hashtbl.t;
  mutable creating : int;
  mutable stopping : bool;
}

let now t = t.now ()
let key handle = P.Handle.to_string handle

let info tab : P.tab_info =
  {
    tab = tab.handle;
    url = tab.url;
    title = tab.title;
    origin = tab.origin;
    state = enum P.State.of_string (if tab.owner = None then "unowned" else "owned");
    owner = tab.owner;
    generation = tab.generation;
    expires = None;
  }

let disappear t tab disposition =
  Hashtbl.remove t.tabs (key tab.handle);
  Hashtbl.remove t.targets tab.id;
  Hashtbl.replace t.tombs (key tab.handle) { owner = tab.owner; disposition; at = now t };
  match tab.load_waiter with
  | None -> ()
  | Some waiter ->
      tab.load_waiter <- None;
      Eio.Promise.resolve waiter ()

let lookup t ~owner handle =
  let key = key handle in
  match Hashtbl.find_opt t.tabs key with
  | Some tab when tab.owner = Some owner -> Ok tab
  | Some _ -> Error (error "not-owner" "the tab belongs to another owner")
  | None -> (
      match Hashtbl.find_opt t.tombs key with
      | Some tomb when now t -. tomb.at >= float t.tombstone_s ->
          Hashtbl.remove t.tombs key;
          Error (error "unknown-tab" "unknown tab handle")
      | Some tomb when tomb.owner <> Some owner ->
          Error (error "not-owner" "the tab belongs to another owner")
      | Some tomb ->
          Error
            (error
               ~detail:(obj [ ("disposition", str tomb.disposition) ])
               "tab-gone" "the tab is gone")
      | None -> Error (error "unknown-tab" "unknown tab handle"))

let cdp_call ?session cdp meth params =
  match Cdp.call cdp ?session ~deadline:(Eta.Duration.seconds 30) meth params with
  | Error `Timeout -> Error (error "timeout" "browser operation timed out")
  | Error _ -> Error (unavailable ())
  | Ok reply -> (
      match Cdp.error_of_reply reply with
      | Some _ -> Error (error "internal" ("browser refused " ^ meth))
      | None -> (
          match Cdp.result reply with
          | Some result -> Ok result
          | None -> Error (error "internal" ("browser omitted " ^ meth ^ " result"))))

let ready t =
  match Chrome.connection t.chrome with
  | Ok cdp -> Ok cdp
  | Error _ -> Error (unavailable ())

let register t ~id ~session ~origin ~owner ~url ~title ?opener () =
  let tab =
    {
      id;
      session;
      handle = handle ();
      url;
      title;
      origin;
      owner;
      generation = Chrome.generation t.chrome;
      lock = Eio.Mutex.create ();
      loading = false;
      navigated = false;
      completed = false;
      load_waiter = None;
      snapshot = None;
      dialog = None;
      counter_installed = false;
      opener;
      reading = Reading.create ();
    }
  in
  Hashtbl.add t.tabs (key tab.handle) tab;
  Hashtbl.replace t.targets id (key tab.handle);
  tab

let ( let* ) = Result.bind

(* tab-8k2g, own-ehqa: a target Chrome reports with an [openerId] belongs to whoever owns
   the tab that opened it, so a page's popup is its opener agent's tab and not another
   agent's. A target with no opener, or one whose opener Leash does not know, is a
   human's, as before. *)
let adoption t info =
  match text "openerId" info with
  | Some opener -> (
      match Option.bind (Hashtbl.find_opt t.targets opener) (Hashtbl.find_opt t.tabs) with
      | Some opener_tab -> (opener_tab.origin, opener_tab.owner, Some opener)
      | None ->
          ( enum P.Origin.of_string "human",
            Some (enum P.Owner.of_string "human"),
            Some opener ))
  | None -> (enum P.Origin.of_string "human", Some (enum P.Owner.of_string "human"), None)

let flush_humans t =
  if t.creating = 0 then (
    Hashtbl.iter
      (fun id (session, info) ->
        if not (Hashtbl.mem t.targets id) then (
          let origin, owner, opener = adoption t info in
          ignore
            (register t ~id ~session ~origin ~owner
               ~url:(Option.value ~default:"about:blank" (text "url" info))
               ~title:(Option.value ~default:"" (text "title" info))
               ?opener ());
          match ready t with
          | Error _ -> ()
          | Ok cdp ->
              List.iter
                (fun domain ->
                  ignore (cdp_call ~session cdp (domain ^ ".enable") (obj [])))
                [ "Page"; "Runtime"; "Network" ]))
      t.pending_humans;
    Hashtbl.clear t.pending_humans)

(* chrome-qnul: Chrome pushes the *tab-strip* title in Target.targetInfoChanged — the
   formatted URL, "example.com" for example.com — and does not push the document title
   that the load brings. A query right after the load carries the document title and the
   committed URL, so the reply and [list] report the page rather than the tab strip. Best
   effort: a tab that vanished during the load is reported by the caller's own lookup, not
   by this call. *)
let refresh_from_target cdp tab =
  match cdp_call cdp "Target.getTargetInfo" (obj [ ("targetId", str tab.id) ]) with
  | Error _ -> ()
  | Ok result -> (
      match member "targetInfo" result with
      | None -> ()
      | Some info ->
          Option.iter (fun url -> tab.url <- url) (text "url" info);
          Option.iter (fun title -> tab.title <- title) (text "title" info))

(* chrome-1yn9, chrome-qnul: a url is loaded when the load event fires, or when the
   document's main frame navigated and its DOM content is in — never when the network is
   idle. [start] issues whatever begins the load; the waiter is armed before it runs, so
   no event it provokes can be missed. Bounded to 30 seconds. The caller holds the tab's
   lock. *)
let with_load_wait t cdp tab start =
  let promise, waiter = Eio.Promise.create () in
  tab.loading <- true;
  tab.navigated <- false;
  tab.completed <- false;
  tab.load_waiter <- Some waiter;
  Fun.protect
    ~finally:(fun () ->
      tab.loading <- false;
      tab.load_waiter <- None)
    (fun () ->
      let* () = start () in
      match t.await_load promise with
      | Error `Timeout ->
          Error (error "timeout" "navigation did not load within 30 seconds")
      | Ok () ->
          refresh_from_target cdp tab;
          Ok ())

let new_tab t ~owner ~url =
  let target = Option.value ~default:"about:blank" url in
  if not (valid_url target) then Error (refusal ())
  else if Hashtbl.length t.tabs >= t.cap then Error (error "tab-cap" "tab cap reached")
  else
    let* cdp = ready t in
    t.creating <- t.creating + 1;
    Fun.protect
      ~finally:(fun () ->
        t.creating <- t.creating - 1;
        flush_humans t)
      (fun () ->
        let* created =
          (* Creating directly at [target] can finish a fast local load before
            Page.enable has subscribed to events. Create blank, subscribe, then
            navigate explicitly so the load waiter cannot miss it (chrome-qnul). *)
          cdp_call cdp "Target.createTarget" (obj [ ("url", str "about:blank") ])
        in
        match text "targetId" created with
        | None -> Error (error "internal" "browser omitted targetId")
        | Some id -> (
            let* attached =
              cdp_call cdp "Target.attachToTarget"
                (obj [ ("targetId", str id); ("flatten", `Bool true) ])
            in
            match text "sessionId" attached with
            | None -> Error (error "internal" "browser omitted sessionId")
            | Some session ->
                let tab =
                  register t ~id ~session
                    ~origin:(enum P.Origin.of_string "agent")
                    ~owner:(Some owner) ~url:target ~title:"" ()
                in
                (* chrome-qnul: a tab created with a url is only titled once its document
                   has loaded, so the reply waits exactly as [nav] does. Without a url (or
                   for [about:blank]) there is nothing to await and the reply is immediate. *)
                let* _ =
                  cdp_call ~session cdp "Page.addScriptToEvaluateOnNewDocument"
                    (obj [ ("source", str Snapshot_source.counter_script) ])
                in
                tab.counter_installed <- true;
                let* _ = cdp_call ~session cdp "Runtime.enable" (obj []) in
                let* _ = cdp_call ~session cdp "Network.enable" (obj []) in
                let* _ = cdp_call ~session cdp "Page.enable" (obj []) in
                let* () =
                  if waits_for_load url then
                    with_load_wait t cdp tab (fun () ->
                        let* reply =
                          cdp_call ~session cdp "Page.navigate"
                            (obj [ ("url", str target) ])
                        in
                        match text "errorText" reply with
                        | Some _ -> Error (error "internal" "browser navigation failed")
                        | None -> Ok ())
                  else Ok ()
                in
                (* tab-8la3: a tab Leash acts on keeps rendering and animating while it
                   is not the visible one, so an action on a background tab settles the
                   same way. tab-bw4j: action-time revalidation reads geometry and
                   hit-tests through the DOM agent, so it is enabled once per tab. Both
                   are best effort (a browser that refuses them still has [Page.enable]),
                   and both come after the load so a load that never completes keeps its
                   own bounded reply. *)
                ignore
                  (cdp_call ~session cdp "Emulation.setFocusEmulationEnabled"
                     (obj [ ("enabled", `Bool true) ]));
                ignore (cdp_call ~session cdp "DOM.enable" (obj []));
                Ok (info tab)))

let navigate t ~owner handle url =
  if not (valid_url url) then Error (refusal ())
  else
    let* tab = lookup t ~owner handle in
    Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
        let* tab = lookup t ~owner handle in
        let* cdp = ready t in
        (* chrome-1yn9: the tab is navigating to [url] now, so [url] is the fallback until
           Chrome speaks; the load wait's own [Target.getTargetInfo] refresh replaces it
           with the URL Chrome committed, which is what a redirect changes. *)
        tab.url <- url;
        tab.snapshot <- None;
        let* () =
          with_load_wait t cdp tab (fun () ->
              let* reply =
                cdp_call ~session:tab.session cdp "Page.navigate"
                  (obj [ ("url", str url) ])
              in
              match text "errorText" reply with
              | Some _ -> Error (error "internal" "browser navigation failed")
              | None -> Ok ())
        in
        let* _ = lookup t ~owner handle in
        let* _ = ready t in
        Ok
          P.
            {
              tab = handle;
              url = tab.url;
              title = tab.title;
              snapshot = None;
              dialog = None;
              popups = [];
            })

let close t ~owner handle =
  let k = key handle in
  match Hashtbl.find_opt t.tombs k with
  | Some tomb
    when tomb.owner = Some owner
         && tomb.disposition = "closed_by_owner"
         && now t -. tomb.at < float t.tombstone_s ->
      Ok P.{ closed = true }
  | _ ->
      let* tab = lookup t ~owner handle in
      Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
          let* tab = lookup t ~owner handle in
          let* cdp = ready t in
          let* _ = cdp_call cdp "Target.closeTarget" (obj [ ("targetId", str tab.id) ]) in
          disappear t tab "closed_by_owner";
          Ok P.{ closed = true })

let list t ~owner ~all =
  let tabs =
    Hashtbl.fold
      (fun _ (tab : tab) acc ->
        if all || tab.owner = Some owner then info tab :: acc else acc)
      t.tabs []
  in
  P.
    {
      tabs =
        List.sort
          (fun (a : P.tab_info) (b : P.tab_info) ->
            String.compare (key a.tab) (key b.tab))
          tabs;
    }

(* tab-of0i tab-tmoc tab-1r34 tab-hyap tab-1rx9 tab-0vh8:
   retain the unfiltered node table for later action-time revalidation. *)
let snap t ~owner (args : P.snap_args) =
  let* tab = lookup t ~owner args.tab in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = lookup t ~owner args.tab in
      let offset = Option.value ~default:0 args.offset in
      let limit = Option.value ~default:120 args.limit in
      if offset < 0 || limit < 0 || limit > 1000 then
        Error
          (error "invalid-request" "snap offset must be nonnegative and limit 0..1000")
      else
        let* cdp = ready t in
        let call meth params = cdp_call ~session:tab.session cdp meth params in
        let* () =
          if tab.counter_installed then Ok ()
          else
            let* _ =
              call "Page.addScriptToEvaluateOnNewDocument"
                (obj [ ("source", str Snapshot_source.counter_script) ])
            in
            tab.counter_installed <- true;
            Ok ()
        in
        let loader () =
          let* reply = call "Page.getFrameTree" (obj []) in
          match member "frameTree" reply with
          | Some tree ->
              let frame = Option.value ~default:`Null (member "frame" tree) in
              Ok (Option.value ~default:"" (text "loaderId" frame))
          | None -> Error (error "internal" "browser omitted frame tree")
        in
        let guard () =
          let evaluate expression =
            let* reply =
              call "Runtime.evaluate"
                (obj [ ("expression", str expression); ("returnByValue", `Bool true) ])
            in
            match member "result" reply with
            | Some result -> Ok (Option.value ~default:`Null (member "value" result))
            | None -> Error (error "internal" "browser omitted guard result")
          in
          let* current = evaluate Snapshot_source.guard_expression in
          match Snapshot_source.guard current with
          | Some guard -> Ok guard
          | None -> (
              let* _ = evaluate Snapshot_source.counter_script in
              let* reply = evaluate Snapshot_source.guard_expression in
              match Snapshot_source.guard reply with
              | Some guard -> Ok guard
              | None -> Error (error "internal" "document mutation guard unavailable"))
        in
        let capture () =
          let* before_loader = loader () in
          let* before = guard () in
          let* ax = call "Accessibility.getFullAXTree" (obj []) in
          let* dom =
            call "DOMSnapshot.captureSnapshot"
              (obj
                 [
                   ("computedStyles", `List [ str "display"; str "visibility" ]);
                   ("includeDOMRects", `Bool true);
                 ])
          in
          let* after = guard () in
          let* after_loader = loader () in
          let _, _, width, height, scroll_x, scroll_y = before in
          let rows = Snapshot_source.rows ~ax ~dom ~width ~height ~scroll_x ~scroll_y in
          Ok (rows, before = after && before_loader = after_loader, after_loader)
        in
        let rec attempt remaining =
          let* rows, settled, loader_id =
            if tab.dialog <> None then Ok ([], false, "") else capture ()
          in
          if (not settled) && remaining > 0 && tab.dialog = None then
            attempt (remaining - 1)
          else Ok (rows, settled, loader_id)
        in
        let* rows, settled, loader_id = attempt 2 in
        let snapshot =
          enum P.Snapshot_id.of_string ("s_" ^ P.Handle.to_string (handle ()))
        in
        tab.snapshot <- Some (snapshot, loader_id, rows);
        let matches row =
          match args.match_ with
          | None -> true
          | Some pattern ->
              let pattern = String.lowercase_ascii pattern in
              let contains s =
                let s = String.lowercase_ascii s in
                let n = String.length pattern in
                let rec scan at =
                  at + n <= String.length s
                  && (String.sub s at n = pattern || scan (at + 1))
                in
                scan 0
              in
              contains row.P.role || contains row.name
              || Option.fold ~none:false ~some:contains row.value
        in
        let all = rows |> List.map fst |> List.filter matches in
        let total = List.length all in
        let shown = all |> List.filteri (fun i _ -> i >= offset && i - offset < limit) in
        Ok
          P.
            {
              snapshot;
              tab = tab.handle;
              url = tab.url;
              title = tab.title;
              rows = shown;
              total;
              offset;
              truncated = offset + List.length shown < total;
              settled;
              dialog = tab.dialog;
            })

(* tab-9x5e tab-x4v0 tab-a33o tab-qmei tab-5vnm tab-un75 tab-fepr tab-0lax:
   the registry owns identity and the page session; Reading owns browser-specific work. *)
let reading_browser t tab cdp : Reading.browser =
  {
    call = (fun meth params -> cdp_call ~session:tab.session cdp meth params);
    now = (fun () -> now t);
    sleep = t.sleep;
    current = (fun () -> (tab.url, tab.title));
    dialog = (fun () -> tab.dialog);
    row =
      (fun index ->
        match tab.snapshot with
        | None -> None
        | Some (_, _, rows) ->
            List.find_map
              (fun ((row : P.row), backend) ->
                if row.P.index = index then Some backend else None)
              rows);
  }

let with_reading t ~owner handle f =
  let* tab = lookup t ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = lookup t ~owner handle in
      let* cdp = ready t in
      f tab (reading_browser t tab cdp))

let read_text t ~owner (args : P.text_args) =
  with_reading t ~owner args.tab (fun _ browser -> Reading.text browser args)

let eval t ~owner (args : P.eval_args) =
  with_reading t ~owner args.tab (fun _ browser -> Reading.eval browser args)

let shot t ~owner (args : P.shot_args) =
  with_reading t ~owner args.tab (fun _ browser -> Reading.shot browser args)

let debug t ~owner (args : P.debug_args) =
  let* tab = lookup t ~owner args.tab in
  Reading.debug tab.reading args

let dialog t ~owner (args : P.dialog_args) =
  (* Do not take the tab action mutex: an in-flight action can itself be blocked
     by a JavaScript dialog, and this command is the only way to release it. *)
  let* tab = lookup t ~owner args.tab in
  let* cdp = ready t in
  Reading.dialog (reading_browser t tab cdp) args

let wait t ~owner (args : P.wait_args) =
  let* tab = lookup t ~owner args.tab in
  let* cdp = ready t in
  Reading.wait (reading_browser t tab cdp) args

(* L7 tab-bw4j tab-j1z2 tab-p3x1 tab-luo5 tab-5deq tab-8dop tab-tm6c tab-hxld tab-60kn
   tab-1lhx tab-8la3: the registry owns the tab's identity, its page session, and its
   lock; Actions owns revalidation, dispatch, and settlement. The lock is what makes one
   tab's actions run one at a time in arrival order while another tab's proceed. *)
let action_view t ~owner tab cdp : Actions.tab =
  {
    Actions.session = tab.session;
    target = tab.id;
    handle = tab.handle;
    owner;
    page = (fun () -> (tab.url, tab.title));
    refresh = (fun () -> refresh_from_target cdp tab);
    snapshot = (fun () -> tab.snapshot);
    dialog = (fun () -> tab.dialog);
    all_tabs =
      (fun () ->
        Hashtbl.fold (fun _ (tab : tab) acc -> (info tab, tab.opener) :: acc) t.tabs []
        |> List.sort (fun ((a : P.tab_info), _) ((b : P.tab_info), _) ->
            String.compare (key a.tab) (key b.tab)));
  }

let with_action t ~owner handle f =
  let* tab = lookup t ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = lookup t ~owner handle in
      let* cdp = ready t in
      f cdp (action_view t ~owner tab cdp))

let click t ~owner (args : P.click_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.click ~cdp view args)

let fill t ~owner (args : P.fill_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.fill ~cdp view args)

let press t ~owner (args : P.press_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.press ~cdp view args)

let select t ~owner (args : P.select_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.select ~cdp view args)

let scroll t ~owner (args : P.scroll_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.scroll ~cdp view args)

let report t : P.status_result =
  let chrome = Chrome.status t.chrome in
  {
    generation = chrome.generation;
    tabs = { open_ = Hashtbl.length t.tabs; cap = t.cap };
    chrome =
      enum P.Chrome_phase.of_string
        (if chrome.phase = `Running then "running" else "restarting");
    uptime_s = max 0. (now t -. t.started);
  }

let status t =
  let state =
    match (Chrome.status t.chrome).phase with
    | `Running -> Eta_app.Status.Ok
    | _ -> Eta_app.Status.Degraded "Chrome restarting"
  in
  Eta_app.Status.make
    ~details:
      [ ("open", string_of_int (Hashtbl.length t.tabs)); ("cap", string_of_int t.cap) ]
    "tabs" state

let inspect t json =
  (match text "sessionId" json with
  | None -> ()
  | Some session ->
      Hashtbl.iter
        (fun _ tab ->
          if tab.session = session then Reading.observe tab.reading ~at:(now t) json)
        t.tabs);
  match (text "method" json, member "params" json) with
  | Some ("Target.targetCreated" | "Target.targetInfoChanged"), Some params -> (
      match member "targetInfo" params with
      | Some info when text "type" info = Some "page" -> (
          match text "targetId" info with
          | Some id -> (
              match Hashtbl.find_opt t.targets id with
              | Some k -> (
                  match Hashtbl.find_opt t.tabs k with
                  | Some tab -> (
                      Option.iter (fun url -> tab.url <- url) (text "url" info);
                      Option.iter (fun title -> tab.title <- title) (text "title" info);
                      (* tab-8k2g: a popup's opener is pushed with its target
                         info; a tab Leash created never carries one. *)
                      match text "openerId" info with
                      | Some opener -> tab.opener <- Some opener
                      | None -> ())
                  | None -> ())
              | None ->
                  (* A creation notification can precede createTarget's reply. Delay adoption
                  until the matching auto-attach event, which carries the session. *)
                  ())
          | None -> ())
      | _ -> ())
  | Some "Target.attachedToTarget", Some params -> (
      match (text "sessionId" params, member "targetInfo" params) with
      | Some session, Some info when text "type" info = Some "page" -> (
          match text "targetId" info with
          | Some id when not (Hashtbl.mem t.targets id) ->
              (* Chrome sends this for programmatically created targets as well. The
             target is reconciled by createTarget before it becomes a human tab. *)
              Hashtbl.replace t.pending_humans id (session, info);
              flush_humans t
          | _ -> ())
      | _ -> ())
  | Some "Target.targetDestroyed", Some params -> (
      match text "targetId" params with
      | Some id -> (
          match Hashtbl.find_opt t.targets id with
          | Some k ->
              Option.iter
                (fun tab -> disappear t tab "closed_externally")
                (Hashtbl.find_opt t.tabs k)
          | None -> ())
      | None -> ())
  | Some "Page.javascriptDialogOpening", Some params ->
      Hashtbl.iter
        (fun _ tab ->
          if Some tab.session = text "sessionId" json then
            match (text "type" params, text "message" params) with
            | Some kind, Some message ->
                tab.dialog <- Some P.{ kind = enum P.Dialog_kind.of_string kind; message }
            | _ -> ())
        t.tabs
  | Some "Page.javascriptDialogClosed", _ ->
      Hashtbl.iter
        (fun _ tab -> if Some tab.session = text "sessionId" json then tab.dialog <- None)
        t.tabs
  | Some "Page.frameNavigated", Some params -> (
      Hashtbl.iter
        (fun _ tab ->
          if
            Some tab.session = text "sessionId" json
            &&
            match member "frame" params with
            | Some frame -> text "parentId" frame = None
            | None -> false
          then tab.snapshot <- None)
        t.tabs;
      match text "sessionId" json with
      | Some session ->
          Hashtbl.iter
            (fun _ tab ->
              if tab.session = session && tab.loading then tab.navigated <- true)
            t.tabs
      | None -> ())
  | Some (("Page.loadEventFired" | "Page.domContentEventFired") as event), Some params
    -> (
      match text "sessionId" json with
      | None -> ()
      | Some session ->
          Hashtbl.iter
            (fun _ tab ->
              if tab.session = session && tab.loading then (
                (if event = "Page.frameNavigated" then
                   match member "frame" params with
                   | Some frame when text "parentId" frame = None -> tab.navigated <- true
                   | _ -> ());
                if
                  event = "Page.loadEventFired"
                  || (event = "Page.domContentEventFired" && tab.navigated)
                then (
                  tab.completed <- true;
                  match tab.load_waiter with
                  | None -> ()
                  | Some waiter ->
                      tab.load_waiter <- None;
                      Eio.Promise.resolve waiter ())))
            t.tabs)
  | _ -> ()

let create ~sw ~cap ~tombstone_s (deps : 'clock deps) =
  let t =
    {
      chrome = deps.chrome;
      now = (fun () -> Eio.Time.now deps.clock);
      sleep = (fun seconds -> Eio.Time.sleep deps.clock seconds);
      await_load =
        (fun promise ->
          Eta.Timeout.timeout ~clock:deps.clock (Eta.Duration.seconds 30) (fun () ->
              Eio.Promise.await promise;
              Ok ()));
      logger = deps.logger;
      cap;
      tombstone_s;
      started = Eio.Time.now deps.clock;
      tabs = Hashtbl.create 32;
      targets = Hashtbl.create 32;
      tombs = Hashtbl.create 32;
      pending_humans = Hashtbl.create 16;
      creating = 0;
      stopping = false;
    }
  in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      let rec lifecycle () : [ `Stop_daemon ] =
        (match Eio.Stream.take (Chrome.events t.chrome) with
        | Chrome.Started _ -> (
            match ready t with
            | Ok cdp ->
                Eio.Fiber.fork_daemon ~sw (fun () ->
                    let rec notifications () : [ `Stop_daemon ] =
                      match Eio.Stream.take (Cdp.events cdp) with
                      | Eta_rpc.Correlator.Message json ->
                          inspect t json;
                          notifications ()
                      | Eta_rpc.Correlator.Closed _ -> `Stop_daemon
                    in
                    notifications ());
                ignore
                  (cdp_call cdp "Target.setDiscoverTargets"
                     (obj [ ("discover", `Bool true) ]));
                ignore
                  (cdp_call cdp "Target.setAutoAttach"
                     (obj
                        [
                          ("autoAttach", `Bool true);
                          ("waitForDebuggerOnStart", `Bool false);
                          ("flatten", `Bool true);
                        ]))
            | Error _ -> ())
        | Chrome.Lost generation ->
            Hashtbl.iter
              (fun _ tab ->
                if tab.generation = generation then disappear t tab "browser_lost")
              (Hashtbl.copy t.tabs)
        | Chrome.Gave_up _ | Chrome.Stopped -> ());
        lifecycle ()
      in
      lifecycle ());
  t

let stop t =
  if not t.stopping then (
    t.stopping <- true;
    match ready t with
    | Error _ -> ()
    | Ok cdp ->
        Hashtbl.iter
          (fun _ tab ->
            if P.Origin.to_string tab.origin = "agent" then
              ignore
                (cdp_call cdp "Target.closeTarget" (obj [ ("targetId", str tab.id) ])))
          (Hashtbl.copy t.tabs))

let text = read_text
