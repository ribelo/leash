module P = Protocol

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
  desktop : Desktop.t;
}

let obj fields = `Assoc fields
let str s = `String s
let member key = function `Assoc fields -> List.assoc_opt key fields | _ -> None
let text key json = match member key json with Some (`String s) -> Some s | _ -> None

let enum of_string value =
  match of_string value with Ok v -> v | Error _ -> assert false

(* A tombstone's disposition is the protocol's closed set, not a string: the registry is
   the one place that decides why a tab is gone, and the wire reads it back by name
   (ADR-0005, own-teh1). *)
let disposition name : P.Disposition.t = enum P.Disposition.of_string name

let error ?detail code message : P.error =
  { code = enum P.Error_code.of_string code; message; detail }

let unavailable () = error "browser-unavailable" "Chrome is restarting; try again shortly"

let lost () =
  error "tab-gone" "the tab is gone"
    ~detail:
      (obj [ ("disposition", P.Disposition.yojson_of_t (disposition "browser_lost")) ])

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

(* ---------- Ownership (ADR-0005) ---------- *)

(* own-6ndc own-jua9 own-2zs7: who a tab belongs to is a closed variant rather than a
   nullable name, because the three states answer differently: [Unowned] is a tab nobody
   has claimed (a human's, or one an agent released), [Owned] is the one the caller
   created or claimed, and [With_human] is the one handed off while the human works on it
   (milestone 4). *)
type owner_state = Unowned | Owned of P.Owner.t | With_human of P.Owner.t

let owner_of = function Unowned -> None | Owned owner | With_human owner -> Some owner

let state_name = function
  | Unowned -> "unowned"
  | Owned _ -> "owned"
  | With_human _ -> "with_human"

(* The command classes the one authorization function distinguishes. Every tab command
   names one: [Act] is everything that touches the page (observe, navigate, act, wait),
   [Resume] is the human's answer to a handoff, and only [Close] and [Release] can be
   forced. *)
type access = Act | Dialog | Close | Release | Claim | Resume

let access_name = function
  | Act -> "act"
  | Dialog -> "dialog"
  | Close -> "close"
  | Release -> "release"
  | Claim -> "claim"
  | Resume -> "resume"

let forceable = function
  | Close | Release -> true
  | Act | Dialog | Claim | Resume -> false

let not_owner () = error "not-owner" "the tab belongs to another owner"
let unowned () = error "not-owner" "the tab is unowned; claim it first"
let already_owned () = error "already-owned" "the tab is already owned"
let held_by_human () = error "with-human" "the tab is with the human; resume it first"

let nothing_waiting () =
  error "no-handoff" "nobody is waiting on this tab; there is no handoff to resume"

(* own-pmr7 own-0np9 own-7pzw own-0pnk hand-nisr: the one authorization function. Acting,
   answering a dialog, releasing, and closing require that the caller owns the tab;
   claiming requires that nobody does; and no command at all reaches a tab the human
   holds. [force] is honoured only for [close] and [release], where it ignores ownership
   and the human's hold entirely, because an agent that died without releasing is exactly
   why the human needs it (ADR-0005).

   hand-0sja hand-szz7: [Resume] is the one class anybody may ask for — the human in
   another terminal is usually not the owner, and a resume only ever gives the tab back to
   the owner it was handed off from — and the only state that answers it is [With_human].
   A tab nobody is waiting on is [no-handoff] rather than a refusal about ownership, so a
   stale notification does nothing surprising. *)
let authorize ?(force = false) access ~caller state : (unit, P.error) result =
  match access with
  | Claim -> (
      match state with
      | Unowned -> Ok ()
      | Owned _ | With_human _ -> Error (already_owned ()))
  | Resume -> (
      match state with
      | With_human _ -> Ok ()
      | Unowned | Owned _ -> Error (nothing_waiting ()))
  | Act | Dialog | Close | Release -> (
      if force && forceable access then Ok ()
      else
        match state with
        | Owned owner when owner = caller -> Ok ()
        | Owned _ -> Error (not_owner ())
        | Unowned -> Error (unowned ())
        | With_human _ -> Error (held_by_human ()))

(* A tombstone keeps whose tab it was, so a caller still learns that a closed tab was
   never its own (own-teh1). *)
let held_by_other state caller =
  match state with Unowned -> false | Owned owner | With_human owner -> owner <> caller

(* own-uo77 own-hslp own-ay3s: what one sweep decides on — the sweep itself is at the end
   of this file, and the policy is [Expiry.decide]. It is declared before [tab] on
   purpose: both records name a handle, an origin, and an owner state, and when a value's
   type is not yet known OCaml's field disambiguation picks the most recent declaration,
   which must stay [tab] or every lambda in this file that only says [tab.id] breaks. *)
type idleness = {
  handle : P.Handle.t;
  origin : P.Origin.t;
  owner_state : owner_state;
  idle_for_s : float;  (** seconds since the last owner action on the tab *)
  unowned_for_s : float option;
      (** seconds since the tab became unowned; [None] while it is owned *)
}

(* What one sweep may do with one tab: release it, close it, or leave it. *)
type sweep_step = Release_idle | Close_idle | Keep_idle

(* hand-lz3p hand-lmd5 hand-yytf own-0pnk: how one handoff ended. The request that handed
   the tab over waits on [promise]; [Resumed] is the human's [resume], [Ended] is every
   other ending the registry decides — the tab leaving it (a browser loss, a close) or a
   forced release taking the tab away — and carries the error the waiting request answers
   with. The deadline is not in here at all: it cancels the wait instead of waking it. *)
type outcome = Resumed | Ended of P.error

(* hand-lz3p hand-r4t1: the record one live handoff leaves on its tab — the reason the
   human is shown, and the promise the blocked request awaits. [outcome] is written once,
   by whichever ending got there first, before the promise is resolved. *)
type waiting = {
  reason : string;
  promise : unit Eio.Promise.t;
  resolve : unit Eio.Promise.u;
  mutable outcome : outcome option;
}

type tab = {
  id : string;
  mutable session : string option;
      (** The page session Leash talks to the tab in: [Some] once Chrome attached — by
          auto-attach, or by {!page_session}'s own attach — and [None] for a target that
          is only discovered, which the first command that needs the page attaches
          (own-c0cl). *)
  mutable enabled_session : string option;
      (** The session the reading and action domains were enabled in; [None] until a
          command needs the page. *)
  handle : P.Handle.t;
  mutable url : string;
  mutable title : string;
  origin : P.Origin.t;
  mutable owner_state : owner_state;
  mutable last_activity : float;
      (** The instant of the last action this tab's owner was allowed to take on it, its
          creation included; stage 1 releases a tab this has not moved for [idle]
          (own-ay3s). *)
  mutable unowned_since : float option;
      (** The instant the tab last became unowned, [None] while it is owned; stage 2
          closes an agent-origin tab this has been unclaimed for [unclaimed] (own-hslp).
      *)
  generation : int;
  lock : Eio.Mutex.t;
  mutable loading : bool;
  mutable navigated : bool;
  mutable completed : bool;
  mutable load_waiter : unit Eio.Promise.u option;
  mutable navigations : int;
      (** svc-hi4f: main-frame navigations observed on this tab. An action's watch reads
          it before its dispatch and again when the action is done, so it knows whether
          this action navigated the page. *)
  mutable page_loading : bool;
      (** A main-frame navigation is in flight — set by [Page.frameNavigated], cleared by
          the load event, whether or not a load wait is armed. *)
  mutable page_loads : unit Eio.Promise.u list;
      (** The action watches waiting for that load to finish; resolved once, when it does,
          like the waiter of {!with_load_wait}. *)
  mutable snapshot : (P.Snapshot_id.t * string * (P.row * int) list) option;
  mutable dialog : P.dialog option;
  mutable main_frame : string option;
  mutable downloads : P.download_info list;
  mutable counter_installed : bool;
  mutable opener : string option;
      (** The target id of the tab that opened this one, Chrome's [openerId]. *)
  mutable settlements : (Dispatch.outcome -> unit) list;
      (** The dispatches currently waiting on an acknowledgement (tab-0ohq tab-gjo0): a
          trusted input's reply or an [eval]'s may never come because its handler opened a
          popup, so the registry wakes them when the popup's target appears or when this
          tab's target dies. Empty between dispatches. *)
  mutable handoff : waiting option;
      (** The handoff this tab is in the middle of, [Some] exactly while it is
          [With_human] because a [handoff] request is waiting on it (hand-lz3p). *)
  reading : Reading.t;
}

type tomb = { state : owner_state; disposition : P.Disposition.t; at : float }

type t = {
  chrome : Chrome.t;
  now : unit -> float;
  sleep : float -> unit;
  await_load : unit Eio.Promise.t -> (unit, [ `Timeout ]) result;
  await_handoff : Eta.Duration.t -> unit Eio.Promise.t -> (unit, [ `Timeout ]) result;
  desktop : Desktop.t;
  logger : Eta_observability.Logger.t;
  download_dir : string option;
  downloads_by_guid : (string, string) Hashtbl.t;
  cap : int;
  tombstone_s : int;
  idle : float;
  unclaimed : float;
  started : float;
  tabs : (string, tab) Hashtbl.t;
  targets : (string, string) Hashtbl.t;
  tombs : (string, tomb) Hashtbl.t;
  pending : (string, string option * Discovery.target) Hashtbl.t;
      (** Targets Chrome reported while Leash was creating one of its own, held until that
          create has registered its tab (own-6ndc). *)
  mutable creating : int;
  mutable stopping : bool;
}

let now t = t.now ()
let key handle = P.Handle.to_string handle

(* own-82jd own-uo77 own-hslp: [expires] is the next stage this tab faces and the seconds
   left before it, so [list --all] shows what is about to happen. An owned tab faces
   release; an unowned tab of agent origin faces close; a human's tab, and one the human
   holds, face nothing, because no timer may take them (ADR-0005). *)
let expires t (tab : tab) : P.expires option =
  let at = now t in
  let remaining seconds = max 0 (int_of_float (Float.ceil seconds)) in
  let stage name = enum P.Stage.of_string name in
  match tab.owner_state with
  | Owned _ ->
      Some
        P.
          {
            stage = stage "release";
            in_s = remaining (t.idle -. (at -. tab.last_activity));
          }
  | With_human _ -> None
  | Unowned ->
      if P.Origin.to_string tab.origin <> "agent" then None
      else
        Option.map
          (fun since ->
            P.{ stage = stage "close"; in_s = remaining (t.unclaimed -. (at -. since)) })
          tab.unowned_since

(* hand-lz3p hand-lmd5: whether the tab is still in the handoff a request installed. The
   comparison is physical on the record the request kept: an ending only cleans up after
   itself, never after the handoff that replaced it. *)
let waiting_is (tab : tab) (waiting : waiting) =
  match tab.handoff with Some current -> current == waiting | None -> false

(* hand-lz3p hand-lmd5 hand-yytf: the one place an outcome is written. Whichever
   ending gets there first wins and wakes the request that waited; a [resume] that landed
   while the tab was already dying is not overwritten by the death. *)
let settle (tab : tab) (waiting : waiting) outcome =
  if waiting.outcome = None then waiting.outcome <- Some outcome;
  Eio.Promise.resolve waiting.resolve ()

let info t (tab : tab) : P.tab_info =
  {
    tab = tab.handle;
    url = tab.url;
    title = tab.title;
    origin = tab.origin;
    state = enum P.State.of_string (state_name tab.owner_state);
    owner = owner_of tab.owner_state;
    generation = tab.generation;
    expires = expires t tab;
    (* hand-r4t1: why this tab is waiting on the human, which is what [list --all] shows
       so a human who stepped away can catch up. *)
    reason = Option.map (fun (waiting : waiting) -> waiting.reason) tab.handoff;
  }

let disappear t tab disposition =
  Hashtbl.remove t.tabs (key tab.handle);
  Hashtbl.remove t.targets tab.id;
  Hashtbl.replace t.tombs (key tab.handle)
    { state = tab.owner_state; disposition; at = now t };
  (match tab.load_waiter with
  | None -> ()
  | Some waiter ->
      tab.load_waiter <- None;
      Eio.Promise.resolve waiter ());
  (* hand-yytf: a tab that leaves the registry while a handoff is waiting on it ends the
     handoff with the disposition that closed it — a browser loss is [tab-gone] with
     [browser_lost] — rather than leaving the request blocked on a page that is gone. *)
  match tab.handoff with
  | None -> ()
  | Some waiting -> settle tab waiting (Ended (P.tab_gone disposition))

(* own-0pnk: the one gate every tab command passes through. The decision is the pure
   [authorize]; this is the only place that also records a forced override, with the
   command, the caller, the tab and the state it overrode. *)
let permitted t ~access ~force ~caller handle state =
  if force && forceable access then
    Eta_observability.Logger.warn t.logger
      ~fields:
        [
          ("cmd", Eta_observability.Logger.String (access_name access));
          ("owner", Eta_observability.Logger.String (P.Owner.to_string caller));
          ("tab", Eta_observability.Logger.String (key handle));
          ("state", Eta_observability.Logger.String (state_name state));
        ]
      "ownership forced";
  authorize ~force access ~caller state

(* own-pmr7 own-teh1: every command that names a tab resolves it here, and a handle with
   no live tab is answered from its tombstone. [--force] ignores whose tab that was,
   exactly as it ignores ownership for a live one. *)
let locate t ~access ?(force = false) ~owner handle =
  let key = key handle in
  match Hashtbl.find_opt t.tabs key with
  | Some tab -> (
      match permitted t ~access ~force ~caller:owner handle tab.owner_state with
      | Ok () ->
          (* own-ay3s: any action its owner is allowed to take resets the tab's idle
             clock, so the tab an agent is working on stays its own. A refused command is
             not an action and leaves the clock alone. A [Resume] is the human's answer
             rather than an owner action, and it moves the clock itself, once, when it
             actually resumes (hand-0sja). *)
          (match access with Resume -> () | _ -> tab.last_activity <- now t);
          Ok tab
      | Error _ as refusal -> refusal)
  | None -> (
      match Hashtbl.find_opt t.tombs key with
      | Some tomb when now t -. tomb.at >= float t.tombstone_s ->
          Hashtbl.remove t.tombs key;
          Error (error "unknown-tab" "unknown tab handle")
      | Some tomb when (not force) && held_by_other tomb.state owner ->
          Error (not_owner ())
      | Some tomb -> Error (P.tab_gone tomb.disposition)
      | None -> Error (error "unknown-tab" "unknown tab handle"))

let cdp_call ?(deadline = Eta.Duration.seconds 30) ?session cdp meth params =
  match Cdp.call cdp ?session ~deadline meth params with
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

let register t ~id ~session ~origin ~state ~url ~title ?opener () =
  let at = now t in
  let tab =
    {
      id;
      session;
      enabled_session = None;
      handle = handle ();
      url;
      title;
      origin;
      owner_state = state;
      last_activity = at;
      unowned_since =
        (match state with Unowned -> Some at | Owned _ | With_human _ -> None);
      generation = Chrome.generation t.chrome;
      lock = Eio.Mutex.create ();
      loading = false;
      navigated = false;
      completed = false;
      load_waiter = None;
      navigations = 0;
      page_loading = false;
      page_loads = [];
      snapshot = None;
      dialog = None;
      main_frame = None;
      downloads = [];
      counter_installed = false;
      opener;
      settlements = [];
      handoff = None;
      reading = Reading.create ();
    }
  in
  Hashtbl.add t.tabs (key tab.handle) tab;
  Hashtbl.replace t.targets id (key tab.handle);
  tab

let ( let* ) = Result.bind

(* tab-0ohq tab-gjo0 own-teh1: a dispatch Chrome may never answer -- the trusted input
   whose handler opens a popup, or the [eval] that runs [window.open] -- is settled by the
   registry, and this is where its waiters live. [acknowledge] registers one before the
   input is sent; [wake] resolves every waiter of the tab a report named; and the no-op
   release {!Dispatch.make} leaves is replaced with the closure that drops the waiter once
   the call has settled by its own reply, so a settled dispatch leaves nothing behind. *)
let acknowledge (tab : tab) : Dispatch.t =
  let pending, resolve = Dispatch.make () in
  tab.settlements <- resolve :: tab.settlements;
  {
    pending with
    release =
      (fun () ->
        tab.settlements <- List.filter (fun waiter -> waiter != resolve) tab.settlements);
  }

let wake (tab : tab) outcome =
  let waiters = tab.settlements in
  tab.settlements <- [];
  List.iter (fun resolve -> resolve outcome) waiters

(* The tab a target id names, when the registry knows one: what a popup's [openerId]
   resolves through, and which tab an acknowledgement is delivered to. *)
let tab_of_target t id =
  Option.bind (Hashtbl.find_opt t.targets id) (Hashtbl.find_opt t.tabs)

(* tab-bw4j tab-8la3: the domains a page session needs for observation, action-time
   revalidation, focus emulation, and the debug ring. They are asked for once per session,
   when Leash first uses that session: the discovery path itself only records the session,
   so a target Chrome reports is registered without waiting on the browser (own-c0cl), and
   a tab nobody acts on costs nothing. Best effort: a domain the browser refuses is
   ignored, and the command that needed it reports its own failure. *)
let use_session t cdp tab session =
  tab.session <- Some session;
  if tab.enabled_session <> Some session then (
    tab.enabled_session <- Some session;
    let enable meth params = ignore (cdp_call ~session cdp meth params) in
    enable "Page.enable" (obj []);
    enable "Runtime.enable" (obj []);
    enable "Network.enable" (obj []);
    enable "DOM.enable" (obj []);
    enable "Emulation.setFocusEmulationEnabled" (obj [ ("enabled", `Bool true) ]))

(* own-c0cl: a discovered target has no page session of its own until Chrome attaches to
   it. The first command that needs the page takes the session Chrome attached under, or
   attaches here, flattened as [new] does; either way that is where its domains are
   enabled, and what makes a claimed human tab usable. *)
let page_session t cdp tab =
  match tab.session with
  | Some session ->
      use_session t cdp tab session;
      Ok session
  | None -> (
      let* reply =
        cdp_call cdp "Target.attachToTarget"
          (obj [ ("targetId", str tab.id); ("flatten", `Bool true) ])
      in
      match text "sessionId" reply with
      | None -> Error (error "internal" "browser omitted sessionId")
      | Some session ->
          use_session t cdp tab session;
          Ok session)

(* own-ehqa: what the registry knows about the tab Chrome names in [openerId], which is
   what a popup inherits from. An opener Leash never saw is no opener at all, and
   [Discovery.born] decides what that means. *)
let creator_of t = function
  | None -> None
  | Some opener -> (
      match tab_of_target t opener with
      | Some tab ->
          Some Discovery.{ origin = tab.origin; owner = owner_of tab.owner_state }
      | None -> None)

(* own-c0cl own-ehqa: a target Chrome reports from outside the control protocol enters the
   registry here, with the origin and owner [Discovery.born] gives it: the tab that opened
   it when Leash knows that tab, and a human's unowned tab otherwise. *)
let adopt t ~id ~session (info : Discovery.target) =
  let creator = Discovery.born (creator_of t info.opener) in
  ignore
    (register t ~id ~session ~origin:creator.origin
       ~state:(match creator.owner with Some owner -> Owned owner | None -> Unowned)
       ~url:(Option.value ~default:"about:blank" info.url)
       ~title:(Option.value ~default:"" info.title)
       ?opener:info.opener ());
  (* tab-0ohq tab-gjo0: the first report Chrome makes about a target is the
     acknowledgement of the dispatch that opened it -- [Target.targetCreated], or the
     attachment or the info change that carries the opener first when the announcement was
     missed -- and the tab is registered before its opener's waiters are woken, so the
     action that settles already sees the popup in [popups] (tab-tm6c tab-8k2g). *)
  match info.opener with
  | Some opener -> (
      match tab_of_target t opener with
      | Some opener_tab -> wake opener_tab Dispatch.Popup
      | None -> ())
  | None -> ()

(* own-c0cl own-ehqa: the one road a target Chrome reports from outside the control
   protocol takes into the registry, whether Chrome announced it, attached to it, or both
   in that order. A known tab gains what a later report adds — the session it was attached
   under, once, and the page's url and title — and never another origin or owner: those are
   what the tab was born with, which is what "origin never changes" means. A target Leash
   is creating is not a discovery: the pending table holds its report until createTarget's
   reply has registered that tab, so an agent's own tab never enters as a human's
   (own-6ndc). *)
let discover t ~session (info : Discovery.target) =
  let id = info.id in
  match Hashtbl.find_opt t.targets id with
  | Some k -> (
      match Hashtbl.find_opt t.tabs k with
      | Some tab ->
          (match (tab.session, session) with
          | None, Some session -> tab.session <- Some session
          | _ -> ());
          Option.iter (fun url -> tab.url <- url) info.url;
          Option.iter (fun title -> tab.title <- title) info.title;
          Option.iter (fun opener -> tab.opener <- Some opener) info.opener
      | None -> ())
  | None ->
      if t.creating > 0 then Hashtbl.replace t.pending id (session, info)
      else adopt t ~id ~session info

(* Targets Chrome reported while Leash was creating one of its own: the tab it created —
   which createTarget's reply has registered by now — and anything else that appeared in
   that window, a human's tab included. *)
let flush_pending t =
  if t.creating = 0 then (
    Hashtbl.iter
      (fun id (session, info) ->
        if not (Hashtbl.mem t.targets id) then adopt t ~id ~session info)
      t.pending;
    Hashtbl.clear t.pending)

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

(* svc-hi4f: the page an action navigates to is titled only once its document has
   loaded, and the settle that ends an action is two frames — far too early, which is what
   the L23 live run saw: the reply and [list] carried the tab strip's formatted URL instead
   of the document title. A watch is armed before the action is dispatched, exactly as a
   load wait is armed before its navigate. [refresh] reads the tab's target back at once,
   waits — bounded like a load — when a main-frame navigation landed since the last watch
   and the document is still loading, and reads again. Best effort: a page that never
   finishes loading costs the wait, not the action. *)
let watch_navigation t cdp tab =
  let seen = ref tab.navigations in
  fun () ->
    let since = !seen in
    refresh_from_target cdp tab;
    if tab.navigations <> since && tab.page_loading then (
      let promise, waiter = Eio.Promise.create () in
      tab.page_loads <- waiter :: tab.page_loads;
      Fun.protect
        ~finally:(fun () ->
          tab.page_loads <- List.filter (fun pending -> pending != waiter) tab.page_loads)
        (fun () -> ignore (t.await_load promise)));
    if tab.navigations <> since then refresh_from_target cdp tab;
    seen := tab.navigations

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
        flush_pending t)
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
                (* own-6ndc: the tab an agent creates is owned by that agent from the
                   start. *)
                let tab =
                  register t ~id ~session:(Some session)
                    ~origin:(enum P.Origin.of_string "agent")
                    ~state:(Owned owner) ~url:target ~title:"" ()
                in
                (* chrome-qnul: a tab created with a url is only titled once its document
                   has loaded, so the reply waits exactly as [nav] does. Without a url (or
                   for [about:blank]) there is nothing to await and the reply is immediate. *)
                let* _ =
                  cdp_call ~session cdp "Page.addScriptToEvaluateOnNewDocument"
                    (obj [ ("source", str Snapshot_source.counter_script) ])
                in
                tab.counter_installed <- true;
                (* chrome-qnul: Page.enable before the navigate, so the load waiter cannot
                   miss the load's events; tab-bw4j tab-8la3: the domains actions need. *)
                use_session t cdp tab session;
                let* () =
                  if waits_for_load url then
                    with_load_wait t cdp tab (fun () ->
                        let* reply =
                          cdp_call ~session cdp "Page.navigate"
                            (obj [ ("url", str target) ])
                        in
                        (match text "frameId" reply with
                        | Some id -> tab.main_frame <- Some id
                        | None -> ());
                        match text "errorText" reply with
                        | Some _ -> Error (error "internal" "browser navigation failed")
                        | None -> Ok ())
                  else Ok ()
                in
                Ok (info t tab)))

let navigate t ~owner handle url =
  if not (valid_url url) then Error (refusal ())
  else
    let* tab = locate t ~access:Act ~owner handle in
    Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
        let* tab = locate t ~access:Act ~owner handle in
        let* cdp = ready t in
        let* session = page_session t cdp tab in
        (* chrome-1yn9: the tab is navigating to [url] now, so [url] is the fallback until
           Chrome speaks; the load wait's own [Target.getTargetInfo] refresh replaces it
           with the URL Chrome committed, which is what a redirect changes. *)
        tab.url <- url;
        tab.snapshot <- None;
        let* () =
          with_load_wait t cdp tab (fun () ->
              let* reply =
                cdp_call ~session cdp "Page.navigate" (obj [ ("url", str url) ])
              in
              (match text "frameId" reply with
              | Some id -> tab.main_frame <- Some id
              | None -> ());
              match text "errorText" reply with
              | Some _ -> Error (error "internal" "browser navigation failed")
              | None -> Ok ())
        in
        let* _ = locate t ~access:Act ~owner handle in
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

(* own-jua9: claiming takes a tab nobody owns for the caller, and leaves every other
   command's authorization untouched. *)
let claim t ~owner handle =
  let* tab = locate t ~access:Claim ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Claim ~owner handle in
      tab.owner_state <- Owned owner;
      (* own-hslp: the unclaimed clock stops when somebody takes the tab. *)
      tab.unowned_since <- None;
      (* tab-a7l3: a claim is the moment a discovered tab stops being lazy. Discovery
         itself only records the session Chrome reports (own-c0cl), so the page's event
         domains are enabled here, in the session the tab is talked to in, and a [debug]
         from the claim on covers what the page did while the agent held it. Best effort
         like every enable: a browser that refuses leaves the tab claimed, and the first
         command that needs the page reports its own failure. *)
      (match ready t with
      | Error _ -> ()
      | Ok cdp -> ignore (page_session t cdp tab));
      Ok (info t tab))

(* own-2zs7 own-0pnk: release drops the caller's ownership without touching the page, so
   another agent or the human can take it; [--force] does the same to a tab the caller
   does not own, and to one the human is holding (ADR-0005). *)
let release t ~owner ?(force = false) handle =
  let* tab = locate t ~access:Release ~force ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Release ~force ~owner handle in
      tab.owner_state <- Unowned;
      (* own-hslp: the unclaimed clock starts when a caller lets the tab go. *)
      tab.unowned_since <- Some (now t);
      (* own-0pnk hand-lz3p: a release that reaches a tab the human holds — only [--force]
         can; a plain one is [with-human] — ends the handoff there and then, under this
         lock, rather than leaving the agent to wait out its deadline for a tab it no
         longer owns. The waiting request answers [not-owner] and the record leaves with
         the hold: the tab is unowned, carries no reason, and a later [resume] is
         [no-handoff]. *)
      (match tab.handoff with
      | None -> ()
      | Some waiting ->
          tab.handoff <- None;
          settle tab waiting (Ended (unowned ())));
      Ok P.{ released = true })

(* own-7pzw own-0pnk: [close] is idempotent for the caller that closed the tab, and
   [--force] closes anyone's — including the tab the human holds — because an agent that
   died without releasing is why the flag exists. A close that reaches a held tab ends
   the handoff with it: [disappear] wakes the waiting request with [tab-gone] and the
   disposition that closed it, so nothing waits on a page that is gone (hand-lz3p). *)
let close t ~owner ?(force = false) handle =
  let k = key handle in
  match Hashtbl.find_opt t.tombs k with
  | Some tomb
    when P.Disposition.to_string tomb.disposition = "closed_by_owner"
         && (force || owner_of tomb.state = Some owner)
         && now t -. tomb.at < float t.tombstone_s ->
      Ok P.{ closed = true }
  | _ ->
      let* tab = locate t ~access:Close ~force ~owner handle in
      Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
          let* tab = locate t ~access:Close ~force ~owner handle in
          let* cdp = ready t in
          let* _ = cdp_call cdp "Target.closeTarget" (obj [ ("targetId", str tab.id) ]) in
          disappear t tab (disposition "closed_by_owner");
          Ok P.{ closed = true })

(* hand-lmd5: the deadline a handoff runs on — the caller's [timeout_s], fifteen minutes
   when it names none (or names something a clock cannot use). [Control.budget] asks this
   same question, so the handler's budget and the request's own deadline cannot drift
   apart. *)
let handoff_timeout = function
  | Some seconds when seconds > 0 -> Eta.Duration.seconds seconds
  | Some _ | None -> Eta.Duration.minutes 15

(* hand-nisr own-pmr7 hand-lz3p: the state transition a handoff is. It lands in the
   registry here because [With_human] is part of the owner state and the [with-human]
   refusal has to be reachable to be tested: the tab moves to [With_human] holding the
   reason the human is shown and the promise the blocked request awaits, and from that
   moment every command is refused, the owner's own included, until [resume]. *)
let begin_handoff t ~owner ~reason handle =
  let* tab = locate t ~access:Act ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Act ~owner handle in
      (* hand-len8: a handoff is not an owner action, so it leaves the idle clock where
         it was; [With_human] is exempt from stage 1 anyway (ADR-0005). *)
      let activity = tab.last_activity in
      let promise, resolve = Eio.Promise.create () in
      let waiting = { reason; promise; resolve; outcome = None } in
      tab.owner_state <- With_human owner;
      tab.unowned_since <- None;
      tab.last_activity <- activity;
      tab.handoff <- Some waiting;
      Ok (tab, waiting))

(* hand-nisr hand-lz3p: the transition without its wait, which is what [handoff] is built
   from and what a caller that only needs the state — the authorization matrix of
   ADR-0005, the suspended handoff a test resumes later — drives directly. *)
let hand_over t ~owner ~reason handle =
  let* tab, _ = begin_handoff t ~owner ~reason handle in
  Ok (info t tab)

(* hand-0sja hand-szz7: the human's answer, from any terminal — the notification action
   and [leash resume <tab>] arrive here as the same request. Whoever asks, the tab goes
   back to the owner it was handed off from, which is why [Resume] is the one command
   anybody may send and why a tab nobody is waiting on is [no-handoff] rather than a
   refusal about ownership. *)
let resume t ~owner handle =
  let* tab = locate t ~access:Resume ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Resume ~owner handle in
      match (tab.owner_state, tab.handoff) with
      | With_human owner, Some waiting ->
          (* hand-0sja own-ay3s: the resume resets the tab's idle clock, so the human's
             work does not expire the agent's tab a moment later. *)
          tab.owner_state <- Owned owner;
          tab.unowned_since <- None;
          tab.last_activity <- now t;
          tab.handoff <- None;
          settle tab waiting Resumed;
          Ok P.{ resumed = true }
      | _ -> Error (nothing_waiting ()))

(* hand-04rb: every human-facing step a handoff waits on is bounded by five seconds — the
   browser call that raises the view here, and the window lookup and focus command inside
   {!Desktop} — so a desktop that has stopped answering cannot hold the handler. *)
let step_deadline = Eta.Duration.seconds 5

(* hand-0sja: the notification's action return is the human resuming, from a terminal that
   is not the owner's, so it arrives as the same request a person types. *)
let human_owner =
  match P.Owner.of_string "human" with Ok owner -> owner | Error _ -> assert false

(* hand-04rb hand-phof hand-rg9h: the human-facing side of one handoff, best effort by
   contract. The tab is already [With_human] when this runs, every step that fails becomes
   a warning the reply carries and a log line, and no failure here ends the handoff: a
   missing notify-send must not break the agent.

   - hand-04rb: [Target.activateTarget] raises the tab inside the managed Chrome's window
     first — a compositor may still ignore it (ADR-0003) — and then the configured desktop
     command runs, bounded by its own five seconds.
   - hand-phof: the notification runs on the handoff's own switch, for as long as the
     handoff does, so the human's Done action can arrive at any moment and the child is
     stopped the moment the handoff ends by any path — resume, deadline, disconnect, or
     the tab going away. Its Done action is the human's [resume] (hand-0sja); one that
     arrives after the handoff already ended is logged, not retried. *)
let announce t ~sw ~tab ~reason ~warn =
  let context = Desktop.{ tab = tab.handle; reason; url = tab.url; title = tab.title } in
  let guarded step f =
    match
      try f () with
      | Eio.Cancel.Cancelled _ as cancelled -> raise cancelled
      | ex -> Error (Printexc.to_string ex)
    with
    | Ok () -> ()
    | Error message -> warn step message
  in
  guarded "activate-target" (fun () ->
      match ready t with
      | Error error -> Error error.P.message
      | Ok cdp -> (
          (* Five seconds, not the browser-op deadline: raising the view is best effort,
             and a wedged browser must not hold the handoff (control.ml's margin counts
             on this bound). *)
          match
            cdp_call ~deadline:step_deadline cdp "Target.activateTarget"
              (obj [ ("targetId", str tab.id) ])
          with
          | Ok _ -> Ok ()
          | Error error -> Error error.P.message));
  guarded "focus" (fun () -> Desktop.focus t.desktop context);
  (* A daemon, not a plain fork: Eio's [Switch.run] waits for plain fibers, so a notifier
     that outlives the handoff would hold the reply. The switch cancels a daemon once the
     handoff's own work is done and still waits for the cancellation to finish — which is
     what stops the child and reaps it before the request answers. *)
  Eio.Fiber.fork_daemon ~sw (fun () ->
      guarded "notify" (fun () ->
          Desktop.notify t.desktop ~sw context ~on_done:(fun () ->
              match resume t ~owner:human_owner tab.handle with
              | Ok _ -> ()
              | Error error ->
                  Eta_observability.Logger.info t.logger
                    ~fields:[ ("tab", Eta_observability.Logger.String (key tab.handle)) ]
                    ("the notification answered a handoff that had already ended: "
                   ^ error.P.message)));
      `Stop_daemon)

(* hand-lz3p hand-lmd5 hand-yytf hand-szz7: the wire path into [With_human], and the one
   request that blocks. It hands the tab over, then waits on the promise [resume] resolves
   while the deadline runs; whichever ending comes first decides the reply:

   - [resume] (hand-lz3p hand-0sja) hands the tab back to its owner and answers with the
     page's url and title, which is what the agent re-observes from;
   - the deadline (hand-lmd5) cancels the wait and the tab is the owner's again;
   - the tab's disappearance (hand-yytf) wakes the wait with the disposition that closed
     it, [browser_lost] for a browser loss;
   - the client going away cancels this handler, which is the same restore as the
     deadline: a disconnected agent does not leave the tab stranded with the human.

   Every path but a resume gives the tab back to the owner it was handed off from and
   drops the record, so a later [resume] is [no-handoff] rather than a second resume.

   hand-04rb hand-phof hand-rg9h: the human-facing steps run on a switch of their own
   between the transition and the wait, so the notification is stopped when this request
   ends and the reply says what did not work. *)
let handoff t ~owner ~reason ~timeout_s handle =
  let* tab, waiting = begin_handoff t ~owner ~reason handle in
  let started = now t in
  let warnings = ref [] in
  let warn step message =
    let warning = step ^ ": " ^ message in
    warnings := warning :: !warnings;
    Eta_observability.Logger.warn t.logger
      ~fields:
        [
          ("tab", Eta_observability.Logger.String (key tab.handle));
          ("reason", Eta_observability.Logger.String reason);
        ]
      ("handoff warning: " ^ warning)
  in
  let release () =
    (* The listener cancels this fiber when the client disconnects, so the restore runs
       under [Eio.Cancel.protect]: it must not be cancelled halfway, and it must not wait
       on a lock it will never get. *)
    Eio.Cancel.protect (fun () ->
        Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
            if waiting_is tab waiting then (
              tab.handoff <- None;
              match tab.owner_state with
              | With_human owner -> tab.owner_state <- Owned owner
              | Unowned | Owned _ -> ())))
  in
  let warnings_json () =
    match List.rev !warnings with
    | [] -> None
    | warnings -> Some (obj [ ("warnings", `List (List.map str warnings)) ])
  in
  let answer () =
    match waiting.outcome with
    | Some Resumed ->
        Ok
          P.
            {
              resumed = true;
              url = tab.url;
              title = tab.title;
              warnings =
                (match List.rev !warnings with [] -> None | warnings -> Some warnings);
            }
    | Some (Ended error) -> Error error
    | None ->
        (* hand-rg9h: an unanswered handoff is exactly when the human-facing failures
           explain it, so the timeout carries them in [detail]. *)
        Error (error ?detail:(warnings_json ()) "timeout" "the handoff timed out")
  in
  (* hand-lmd5: the deadline is the request's own, so the human-facing steps that ran
     before the wait count against it — a handoff never outlives the deadline its caller
     gave it — and a deadline already spent answers at once. *)
  let remaining () =
    let spent = Eta.Duration.ms (int_of_float ((now t -. started) *. 1000.)) in
    Eta.Duration.max Eta.Duration.zero
      (Eta.Duration.subtract (handoff_timeout timeout_s) spent)
  in
  Fun.protect ~finally:release (fun () ->
      Eio.Switch.run (fun human ->
          (* hand-04rb hand-phof: the human-facing steps, on this handoff's own switch, so
             the notifier is stopped when the request ends however it ends. *)
          announce t ~sw:human ~tab ~reason ~warn;
          let left = remaining () in
          if not (Eta.Duration.is_zero left) then
            ignore (t.await_handoff left waiting.promise);
          answer ()))

(* own-82jd: without [--all] a caller sees its own tabs — the ones it owns and the one the
   human is holding for it — and nothing of another agent's. *)
let list t ~owner ~all =
  let tabs =
    Hashtbl.fold
      (fun _ (tab : tab) acc ->
        if all || owner_of tab.owner_state = Some owner then info t tab :: acc else acc)
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

(* ---------- Expiry (ADR-0005) ---------- *)

let idleness_of t (tab : tab) : idleness =
  let at = now t in
  {
    handle = tab.handle;
    origin = tab.origin;
    owner_state = tab.owner_state;
    idle_for_s = at -. tab.last_activity;
    unowned_for_s = Option.map (fun since -> at -. since) tab.unowned_since;
  }

let idleness t : idleness list =
  Hashtbl.fold (fun _ tab acc -> idleness_of t tab :: acc) t.tabs []
  |> List.sort (fun (a : idleness) (b : idleness) ->
      String.compare (key a.handle) (key b.handle))

(* own-uo77 own-hslp own-2zpi own-nbwk: one expiry pass. Every decision is taken and
   applied with the tab's own lock held, so a claim or an action that lands while the
   sweep runs is not overrun: [Release_idle] only sets an owned tab unowned, and
   [Close_idle] only closes an unowned tab of agent origin, with disposition
   [closed_by_ttl]. The handles are collected before the first decision because closing
   suspends, and a suspended sweep must not walk a table other fibers mutate. *)
let sweep t ~decide =
  let handles =
    Hashtbl.fold (fun _ (tab : tab) acc -> tab.handle :: acc) t.tabs []
    |> List.sort (fun a b -> String.compare (key a) (key b))
  in
  List.filter_map
    (fun handle ->
      match Hashtbl.find_opt t.tabs (key handle) with
      | None -> None
      | Some tab ->
          Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
              match Hashtbl.find_opt t.tabs (key handle) with
              | None -> None
              | Some tab -> (
                  let step = decide (idleness_of t tab) in
                  match step with
                  | Keep_idle -> None
                  | Release_idle -> (
                      match tab.owner_state with
                      | Owned _ ->
                          tab.owner_state <- Unowned;
                          tab.unowned_since <- Some (now t);
                          Some (handle, step)
                      | Unowned | With_human _ -> None)
                  | Close_idle -> (
                      match tab.owner_state with
                      | Unowned when P.Origin.to_string tab.origin = "agent" -> (
                          match ready t with
                          | Error _ -> None
                          | Ok cdp -> (
                              match
                                cdp_call cdp "Target.closeTarget"
                                  (obj [ ("targetId", str tab.id) ])
                              with
                              | Error _ -> None
                              | Ok _ ->
                                  disappear t tab (disposition "closed_by_ttl");
                                  Some (handle, step)))
                      | Unowned | Owned _ | With_human _ -> None))))
    handles

(* tab-of0i tab-tmoc tab-1r34 tab-hyap tab-1rx9 tab-0vh8:
   retain the unfiltered node table for later action-time revalidation. *)
let snap_locked t tab (args : P.snap_args) =
  let offset = Option.value ~default:0 args.offset in
  let limit = Option.value ~default:120 args.limit in
  if offset < 0 || limit < 0 || limit > 1000 then
    Error (error "invalid-request" "snap offset must be nonnegative and limit 0..1000")
  else
    let* cdp = ready t in
    let* session = page_session t cdp tab in
    let call meth params = cdp_call ~session cdp meth params in
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
      if (not settled) && remaining > 0 && tab.dialog = None then attempt (remaining - 1)
      else Ok (rows, settled, loader_id)
    in
    let* rows, settled, loader_id = attempt 2 in
    let snapshot = enum P.Snapshot_id.of_string ("s_" ^ P.Handle.to_string (handle ())) in
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
              at + n <= String.length s && (String.sub s at n = pattern || scan (at + 1))
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
        }

let snap t ~owner (args : P.snap_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Act ~owner args.tab in
      snap_locked t tab args)

(* tab-9x5e tab-x4v0 tab-a33o tab-qmei tab-5vnm tab-un75 tab-fepr tab-0lax:
   the registry owns identity and the page session; Reading owns browser-specific work. *)
let reading_browser t ~session tab cdp : Reading.browser =
  {
    call = (fun meth params -> cdp_call ~session cdp meth params);
    now = (fun () -> now t);
    sleep = t.sleep;
    current = (fun () -> (tab.url, tab.title));
    dialog = (fun () -> tab.dialog);
    acknowledge = (fun () -> acknowledge tab);
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

let with_reading t ~access ~owner handle f =
  let* tab = locate t ~access ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access ~owner handle in
      let* cdp = ready t in
      let* session = page_session t cdp tab in
      f tab (reading_browser t ~session tab cdp))

let read_text t ~owner (args : P.text_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser -> Reading.text browser args)

let eval t ~owner (args : P.eval_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser -> Reading.eval browser args)

let shot t ~owner (args : P.shot_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser -> Reading.shot browser args)

let debug t ~owner (args : P.debug_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  Reading.debug tab.reading args

(* own-pmr7: answering a dialog is the owner's, exactly as acting is — a dialog is the
   page asking the tab's owner, and a stranger answering it is the "stomping" ADR-0005
   refuses. *)
let dialog t ~owner (args : P.dialog_args) =
  (* Do not take the tab action mutex: an in-flight action can itself be blocked
     by a JavaScript dialog, and this command is the only way to release it. *)
  let* tab = locate t ~access:Dialog ~owner args.tab in
  let* cdp = ready t in
  let* session = page_session t cdp tab in
  Reading.dialog (reading_browser t ~session tab cdp) args

let wait t ~owner (args : P.wait_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  let* cdp = ready t in
  let* session = page_session t cdp tab in
  Reading.wait (reading_browser t ~session tab cdp) args

(* L7 tab-bw4j tab-j1z2 tab-p3x1 tab-luo5 tab-5deq tab-8dop tab-tm6c tab-hxld tab-60kn
   tab-1lhx tab-8la3: the registry owns the tab's identity, its page session, and its
   lock; Actions owns revalidation, dispatch, and settlement. The lock is what makes one
   tab's actions run one at a time in arrival order while another tab's proceed. *)
let action_view t ~session ~owner tab cdp : Actions.tab =
  {
    Actions.session;
    target = tab.id;
    handle = tab.handle;
    owner;
    page = (fun () -> (tab.url, tab.title));
    refresh = watch_navigation t cdp tab;
    snapshot = (fun () -> tab.snapshot);
    dialog = (fun () -> tab.dialog);
    acknowledge = (fun () -> acknowledge tab);
    all_tabs =
      (fun () ->
        Hashtbl.fold (fun _ (tab : tab) acc -> (info t tab, tab.opener) :: acc) t.tabs []
        |> List.sort (fun ((a : P.tab_info), _) ((b : P.tab_info), _) ->
            String.compare (key a.tab) (key b.tab)));
  }

let with_action t ~owner handle f =
  let* tab = locate t ~access:Act ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Act ~owner handle in
      let* cdp = ready t in
      let* session = page_session t cdp tab in
      f cdp (action_view t ~session ~owner tab cdp))

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

(* drive-8n2z drive-tfqh: keep the lock across observe/decide/act. Never call
   a public Tabs action here: each would reacquire this very same mutex. The
   metric expression reads one document state; the fingerprint hashes visible
   text, URL/title, scroll position and actionable AX rows, not snapshot IDs. *)
let drive
    ?(decide =
      fun ~deadline:_ _ ->
        Error
          (error "model-unavailable" "System One client unavailable"
             ~detail:(obj [ ("code", str "client-unavailable") ])))
    ?(text_helper = fun () -> Text_helper.unavailable) t ~owner ~model
    (args : P.drive_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* tab = locate t ~access:Act ~owner args.tab in
      (* drive-kh2u drive-ix5t: one Decide is one System One call, and it is inside the
         drive's own deadline: the caller's remaining budget is what the model call is
         bounded by, so a slow provider cannot outlast the reply the client is waiting
         for. The text helper's completion is bounded by the same budget (drive-ls3c). *)
      let started = now t in
      let budget = float_of_int (Option.value ~default:120 args.deadline_s) in
      let remaining () =
        Eta.Duration.ms (max 1 (int_of_float ((budget -. (now t -. started)) *. 1000.)))
      in
      let decide request = decide ~deadline:(remaining ()) request in
      (* drive-ls3c: one helper per drive. It carries the one-entry memo that reuses an
         answer for an unchanged context — what a stale-row retry is — so it is taken
         here and goes away with the drive. *)
      let helper = text_helper () in
      let text_value context =
        helper.Text_helper.complete ~deadline:(remaining ()) context
      in
      let* cdp = ready t in
      let* session = page_session t cdp tab in
      let browser = reading_browser t ~session tab cdp in
      let view = action_view t ~session ~owner tab cdp in
      let observe () =
        let* snapshot =
          snap_locked t tab
            P.{ tab = args.tab; match_ = None; limit = Some 250; offset = None }
        in
        let* rendered =
          Reading.text browser P.{ tab = args.tab; index = None; max_chars = Some 12_000 }
        in
        let* metrics =
          Reading.eval browser
            P.
              {
                tab = args.tab;
                expression =
                  (* drive-y7v8: the document of a navigation in flight has no
                     documentElement yet; without the guard the query throws, the
                     observe fails, and the step after a navigation-ending action
                     errors instead of observing the new page. *)
                  "return \
                   {y:scrollY,viewport:innerHeight,height:Math.max(document.documentElement?.scrollHeight||0,document.body?.scrollHeight||0)};";
                argument = None;
              }
        in
        let value = metrics.value in
        let number key =
          match member key value with
          | Some (`Int n) -> float_of_int n
          | Some (`Float n) -> n
          | _ -> 0.
        in
        let y, viewport, height = (number "y", number "viewport", number "height") in
        let fingerprint =
          Digest.to_hex
            (Digest.string
               (Yojson.Safe.to_string
                  (`List
                     [
                       str snapshot.url;
                       str snapshot.title;
                       str rendered.text;
                       value;
                       `List (List.map P.yojson_of_row snapshot.rows);
                     ])))
        in
        Ok
          Drive.
            {
              snapshot;
              text = rendered.text;
              can_scroll_down = y +. viewport < height -. 2.;
              can_scroll_up = y > 0.;
              fingerprint;
            }
      in
      let act (page : Drive.observation) (choice : Jev_request.decision) ~text =
        let snapshot = page.snapshot.snapshot in
        let index = Option.value ~default:0 choice.index in
        match P.Operation.to_string choice.operation with
        | "click" -> Actions.click ~cdp view P.{ tab = args.tab; snapshot; index }
        | "select" ->
            Actions.select ~cdp view
              P.
                {
                  tab = args.tab;
                  snapshot;
                  index;
                  option = Option.value ~default:0 choice.option;
                }
        | "scroll_down" ->
            Actions.scroll ~cdp view
              P.
                {
                  tab = args.tab;
                  direction = enum P.Direction.of_string "down";
                  index = None;
                }
        | "scroll_up" ->
            Actions.scroll ~cdp view
              P.
                {
                  tab = args.tab;
                  direction = enum P.Direction.of_string "up";
                  index = None;
                }
        | "wait" ->
            t.sleep 0.5;
            Ok
              P.
                {
                  tab = args.tab;
                  url = tab.url;
                  title = tab.title;
                  snapshot = None;
                  dialog = tab.dialog;
                  popups = [];
                }
        (* drive-ls3c: the helper's value is written with the same fill the [fill] command
           uses — focus, select, Input.insertText, blur, settle — and the loop never calls
           an act without one. *)
        | "type_text" -> (
            match text with
            | Some value ->
                Actions.fill ~cdp view P.{ tab = args.tab; snapshot; index; text = value }
            | None ->
                Error
                  (error "internal" "a type_text step reached the browser without a value")
            )
        | _ -> Error (error "invalid-request" "unsupported drive operation")
      in
      Drive.run
        ~handler:Drive.{ observe; decide; text_value; act }
        ~now:(fun () -> now t)
        ~model ~args
        ~dry_run:(Option.value ~default:false args.dry_run))

let report t : P.status_result =
  let chrome = Chrome.status t.chrome in
  {
    generation = chrome.generation;
    tabs = { open_ = Hashtbl.length t.tabs; cap = t.cap };
    chrome =
      enum P.Chrome_phase.of_string
        (if chrome.phase = `Running then "running" else "restarting");
    uptime_s = max 0. (now t -. t.started);
    (* L19: the models section belongs to the models service, which the control listener
       merges in before the reply goes out; the registry has no opinion about it. *)
    models = None;
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

(* run-ykq4: browser-level events carry the main frame id; page-level legacy
   events carry a session. Never credit an unattributed download to another tab. *)
let download_event t json method_ params =
  let session = text "sessionId" json in
  match method_ with
  | "Browser.downloadWillBegin" | "Page.downloadWillBegin" -> (
      match (text "guid" params, text "suggestedFilename" params) with
      | Some id, Some suggested_name ->
          let frame = text "frameId" params in
          let target =
            Hashtbl.fold
              (fun _ (tab : tab) found ->
                if
                  match frame with
                  | Some frame -> tab.main_frame = Some frame
                  | None -> session <> None && tab.session = session
                then Some tab
                else found)
              t.tabs None
          in
          Option.iter
            (fun (tab : tab) ->
              let mime =
                if String.ends_with ~suffix:".pdf" (String.lowercase_ascii suggested_name)
                then "application/pdf"
                else "application/octet-stream"
              in
              tab.downloads <-
                P.{ id; suggested_name; mime; state = "in_progress"; path = None }
                :: tab.downloads;
              Hashtbl.replace t.downloads_by_guid id (key tab.handle))
            target
      | _ -> ())
  | "Browser.downloadProgress" | "Page.downloadProgress" -> (
      match (text "guid" params, text "state" params) with
      | Some id, Some cdp_state ->
          let state =
            match cdp_state with "inProgress" -> "in_progress" | other -> other
          in
          Option.iter
            (fun handle ->
              Option.iter
                (fun (tab : tab) ->
                  tab.downloads <-
                    List.map
                      (fun (download : P.download_info) ->
                        if download.id <> id then download
                        else
                          {
                            download with
                            state;
                            path =
                              (if state = "completed" then text "filePath" params
                               else None);
                          })
                      tab.downloads)
                (Hashtbl.find_opt t.tabs handle))
            (Hashtbl.find_opt t.downloads_by_guid id)
      | _ -> ())
  | _ -> ()

let downloads t ~owner handle =
  let* tab = locate t ~access:Act ~owner handle in
  Ok P.{ downloads = List.rev tab.downloads }

let inspect t json =
  (match text "sessionId" json with
  | None -> ()
  | Some session ->
      Hashtbl.iter
        (fun _ tab ->
          if tab.session = Some session then Reading.observe tab.reading ~at:(now t) json)
        t.tabs);
  (match (text "method" json, member "params" json) with
  | Some method_, Some params -> download_event t json method_ params
  | _ -> ());
  match (text "method" json, member "params" json) with
  | Some ("Target.targetCreated" | "Target.targetInfoChanged"), Some params -> (
      (* own-c0cl: the announcement every target Chrome reports arrives as, the ones Leash
         itself asked for included — [discover] tells them apart by the pending table. *)
      match Discovery.announced params with
      | Some info -> discover t ~session:None info
      | None -> ())
  | Some "Target.attachedToTarget", Some params -> (
      match Discovery.attached params with
      | Some info -> discover t ~session:info.session info
      | None -> ())
  | Some "Target.targetDestroyed", Some params -> (
      (* own-teh1: a target that goes away without Leash closing it is gone externally. A
         tab Leash closed left the registry when it issued the close, so its tombstone
         keeps closed_by_owner (or, with the TTL sweep, closed_by_ttl) and this report
         finds no live tab to rewrite. *)
      match Discovery.destroyed params with
      | Some id -> (
          match tab_of_target t id with
          | Some tab ->
              (* tab-0ohq own-teh1: a tab's death settles the dispatch whose handler closed
                 it -- [tab-gone] with [closed_externally], the same answer the handle reads
                 from the tombstone afterwards -- before the tab leaves the registry. *)
              wake tab (Dispatch.Gone (P.tab_gone (disposition "closed_externally")));
              disappear t tab (disposition "closed_externally")
          | None -> ())
      | None -> ())
  | Some "Page.javascriptDialogOpening", Some params ->
      Hashtbl.iter
        (fun _ tab ->
          if tab.session = text "sessionId" json then
            match (text "type" params, text "message" params) with
            | Some kind, Some message ->
                tab.dialog <- Some P.{ kind = enum P.Dialog_kind.of_string kind; message }
            | _ -> ())
        t.tabs
  | Some "Page.javascriptDialogClosed", _ ->
      Hashtbl.iter
        (fun _ tab -> if tab.session = text "sessionId" json then tab.dialog <- None)
        t.tabs
  | Some "Page.frameNavigated", Some params -> (
      (* svc-hi4f: a main-frame navigation is what clears the tab's snapshot and what an
          action's watch counts; a subframe's is neither. *)
      let main_frame =
        match member "frame" params with
        | Some frame -> text "parentId" frame = None
        | None -> false
      in
      Hashtbl.iter
        (fun _ tab ->
          if main_frame && tab.session = text "sessionId" json then (
            tab.main_frame <- Option.bind (member "frame" params) (text "id");
            tab.snapshot <- None;
            tab.navigations <- tab.navigations + 1;
            tab.page_loading <- true))
        t.tabs;
      match text "sessionId" json with
      | Some session ->
          Hashtbl.iter
            (fun _ tab ->
              if tab.session = Some session && tab.loading then tab.navigated <- true)
            t.tabs
      | None -> ())
  | Some (("Page.loadEventFired" | "Page.domContentEventFired") as event), Some params
    -> (
      match text "sessionId" json with
      | None -> ()
      | Some session ->
          Hashtbl.iter
            (fun _ tab ->
              if tab.session = Some session then (
                if
                  tab.loading
                  && (event = "Page.loadEventFired"
                     || (event = "Page.domContentEventFired" && tab.navigated))
                then (
                  tab.completed <- true;
                  match tab.load_waiter with
                  | None -> ()
                  | Some waiter ->
                      tab.load_waiter <- None;
                      Eio.Promise.resolve waiter ());
                (* svc-hi4f: the watch an action armed before it dispatched waits for the
                   navigation it counted to finish before its reply reads the title. *)
                if tab.page_loading then (
                  tab.page_loading <- false;
                  let pending = tab.page_loads in
                  tab.page_loads <- [];
                  List.iter (fun resolve -> Eio.Promise.resolve resolve ()) pending)))
            t.tabs)
  | _ -> ()

let create ~sw ~cap ~tombstone_s ?download_dir ?(idle = Eta.Duration.minutes 30)
    ?(unclaimed = Eta.Duration.hours 1) (deps : 'clock deps) =
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
      (* hand-lmd5: the handoff deadline, measured by the service clock and cancelled —
         not raced — when it runs out, so the restore of {!handoff} still runs. *)
      await_handoff =
        (fun timeout promise ->
          Eta.Timeout.timeout ~clock:deps.clock timeout (fun () ->
              Eio.Promise.await promise;
              Ok ()));
      desktop = deps.desktop;
      logger = deps.logger;
      download_dir;
      downloads_by_guid = Hashtbl.create 32;
      cap;
      tombstone_s;
      (* own-vhqo: the two expiry durations are config; the ADR's defaults stand in when a
         caller does not name them, which is what a test registry gets. *)
      idle = Eta.Duration.to_seconds_float idle;
      unclaimed = Eta.Duration.to_seconds_float unclaimed;
      started = Eio.Time.now deps.clock;
      tabs = Hashtbl.create 32;
      targets = Hashtbl.create 32;
      tombs = Hashtbl.create 32;
      pending = Hashtbl.create 16;
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
                Option.iter
                  (fun download_dir ->
                    match
                      cdp_call cdp "Browser.setDownloadBehavior"
                        (obj
                           [
                             ("behavior", str "allow");
                             ("downloadPath", str download_dir);
                             ("eventsEnabled", `Bool true);
                           ])
                    with
                    | Ok _ -> ()
                    | Error _ ->
                        Eta_observability.Logger.warn t.logger
                          "run-ykq4: Browser.setDownloadBehavior failed; downloads \
                           unavailable")
                  t.download_dir;
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
                if tab.generation = generation then
                  disappear t tab (disposition "browser_lost"))
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
