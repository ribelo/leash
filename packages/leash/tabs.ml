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
}

type tomb = { owner : P.Owner.t option; disposition : string; at : float }

type t = {
  chrome : Chrome.t;
  now : unit -> float;
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

let register t ~id ~session ~origin ~owner ~url ~title =
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
    }
  in
  Hashtbl.add t.tabs (key tab.handle) tab;
  Hashtbl.replace t.targets id (key tab.handle);
  tab

let ( let* ) = Result.bind

let flush_humans t =
  if t.creating = 0 then (
    Hashtbl.iter
      (fun id (session, info) ->
        if not (Hashtbl.mem t.targets id) then
          ignore
            (register t ~id ~session
               ~origin:(enum P.Origin.of_string "human")
               ~owner:(Some (enum P.Owner.of_string "human"))
               ~url:(Option.value ~default:"about:blank" (text "url" info))
               ~title:(Option.value ~default:"" (text "title" info))))
      t.pending_humans;
    Hashtbl.clear t.pending_humans)

let new_tab t ~owner ~url =
  if not (valid_url url) then Error (refusal ())
  else if Hashtbl.length t.tabs >= t.cap then Error (error "tab-cap" "tab cap reached")
  else
    let* cdp = ready t in
    t.creating <- t.creating + 1;
    Fun.protect
      ~finally:(fun () ->
        t.creating <- t.creating - 1;
        flush_humans t)
      (fun () ->
        let* created = cdp_call cdp "Target.createTarget" (obj [ ("url", str url) ]) in
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
                    ~owner:(Some owner) ~url ~title:""
                in
                let* _ = cdp_call ~session cdp "Page.enable" (obj []) in
                Ok (info tab)))

let navigate t ~owner handle url =
  if not (valid_url url) then Error (refusal ())
  else
    let* tab = lookup t ~owner handle in
    Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
        let* tab = lookup t ~owner handle in
        let* cdp = ready t in
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
            let* reply =
              cdp_call ~session:tab.session cdp "Page.navigate" (obj [ ("url", str url) ])
            in
            match text "errorText" reply with
            | Some _ -> Error (error "internal" "browser navigation failed")
            | None -> (
                match t.await_load promise with
                | Error `Timeout ->
                    Error (error "timeout" "navigation did not load within 30 seconds")
                | Ok () ->
                    let* _ = lookup t ~owner handle in
                    let* _ = ready t in
                    tab.url <- url;
                    Ok
                      P.
                        {
                          tab = handle;
                          url = tab.url;
                          title = tab.title;
                          snapshot = None;
                          dialog = None;
                          popups = [];
                        })))

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
  match (text "method" json, member "params" json) with
  | Some ("Target.targetCreated" | "Target.targetInfoChanged"), Some params -> (
      match member "targetInfo" params with
      | Some info when text "type" info = Some "page" -> (
          match text "targetId" info with
          | Some id -> (
              match Hashtbl.find_opt t.targets id with
              | Some k -> (
                  match Hashtbl.find_opt t.tabs k with
                  | Some tab ->
                      Option.iter (fun url -> tab.url <- url) (text "url" info);
                      Option.iter (fun title -> tab.title <- title) (text "title" info)
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
  | ( Some
        (("Page.loadEventFired" | "Page.frameNavigated" | "Page.domContentEventFired") as
         event),
      Some params ) -> (
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
