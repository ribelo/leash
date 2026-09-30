module P = Protocol

type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.random >

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Ox_observability.Logger.t;
  desktop : Desktop.t;
  caps : caps;
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
  P.make_error ?detail (enum P.Error_code.of_string code) ~message

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

let handle ~caps =
  let bytes = Ox_caps.Cap_sys.urandom ~caps 16 in
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
  mutable baselines : (P.Snapshot_id.t * Reading.page_state) list;
      (** The page's loader id and mutation guard as each of the last few snapshots saw
          them, newest first (hard-sckn). Unlike [snapshot] this survives a navigation. *)
  mutable dialog : P.dialog option;
  mutable dialog_listeners : (P.dialog -> unit) list;
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
  reading : Reading.t;
}

let baselines_kept = 8

type tomb = { state : owner_state; disposition : P.Disposition.t; at : float }

let key handle = P.Handle.to_string handle

(* ---------- The ledger: ownership, owned by one actor ---------- *)

module Keys = Map.Make (String)

(* What the registry knows about one live tab: the page record ([tab], whose mutable fields
   belong to the tab's lock and the event fiber) and the ownership facts, which belong to
   the ledger and change only by folding a request. *)
type entry = {
  tab : tab;
  owner_state : owner_state;
  last_activity : float;
      (** The instant of the last action this tab's owner was allowed to take on it, its
          creation included; stage 1 releases a tab this has not moved for [idle]
          (own-ay3s). *)
  unowned_since : float option;
      (** The instant the tab last became unowned, [None] while it is owned; stage 2
          closes an agent-origin tab this has been unclaimed for [unclaimed] (own-hslp).
      *)
  handoff : waiting option;
      (** The handoff this tab is in the middle of, [Some] exactly while it is
          [With_human] because a [handoff] request is waiting on it (hand-lz3p). *)
}

(* The registry's whole bookkeeping as one immutable value: every live tab, the target ids
   that name them, the tombstones of the tabs that left, the targets Chrome reported while
   Leash was creating one of its own (own-6ndc), and how many creations are in flight.
   Nothing else writes any of it (^nactor-8z1n). *)
type ledger = {
  entries : entry Keys.t;
  targets : string Keys.t;  (** target id to handle key *)
  tombs : tomb Keys.t;
  pending : (string option * Discovery.target) Keys.t;
  creating : int;
}

let empty_ledger =
  {
    entries = Keys.empty;
    targets = Keys.empty;
    tombs = Keys.empty;
    pending = Keys.empty;
    creating = 0;
  }

(* Everything that changes the ledger is one of these, handled one at a time in arrival
   order by the actor, so no transition can interleave with another. *)
type request =
  | Locate of {
      access : access;
      force : bool;
      caller : P.Owner.t;
      handle : P.Handle.t;
      at : float;
    }  (** [permitted] and, unless it is a [Resume], the idle-clock touch (own-ay3s). *)
  | Claim of { caller : P.Owner.t; handle : P.Handle.t; at : float }
  | Release of { caller : P.Owner.t; force : bool; handle : P.Handle.t; at : float }
  | Hand_over of { caller : P.Owner.t; reason : string; handle : P.Handle.t; at : float }
      (** authorization as [Act], then [With_human] with a fresh handoff record. *)
  | Hand_over_held of {
      caller : P.Owner.t;
      reason : string;
      handle : P.Handle.t;
      at : float;
    }
      (** the same transition for a caller that already holds the tab's lock and has been
          authorized: the run's [hand_off] (run-d82w). *)
  | Resume of { caller : P.Owner.t; handle : P.Handle.t; at : float }
  | Restore of { handle : P.Handle.t; waiting : waiting }
      (** a handoff that ended without a resume gives the tab back to its owner. *)
  | Touch of { handle : P.Handle.t; owner : P.Owner.t; at : float }
  | Release_idle of { handle : P.Handle.t; at : float }
  | Register of {
      id : string;
      session : string option;
      origin : P.Origin.t;
      state : owner_state;
      url : string;
      title : string;
      opener : string option;
      at : float;
    }
  | Disappear of { handle : P.Handle.t; disposition : P.Disposition.t; at : float }
  | Creating of { delta : int; at : float }
      (** a creation began (+1) or ended (-1); the last one to end adopts what Chrome
          reported meanwhile *)
  | Discover of { session : string option; info : Discovery.target; at : float }

type answer =
  | Entry of entry
  | Known of entry  (** a report about a tab the ledger already had *)
  | Adopted of (entry * tab option) list
      (** tabs registered from Chrome's reports, each with the tab that opened it *)
  | Gone of entry  (** the entry that left *)
  | Nothing

type t = {
  chrome : Chrome.t;
  caps : caps;
      (** ^ncaps-4tjy: handles from the system's randomness; screenshots, [run --out] and
          proposals written, uploads and playbooks read, the XDG directories looked up. *)
  now : unit -> float;
  sleep : float -> unit;
  await_load : unit Eio.Promise.t -> (unit, [ `Timeout ]) result;
  await_handoff : Ox.Duration.t -> unit Eio.Promise.t -> (unit, [ `Timeout ]) result;
  desktop : Desktop.t;
  logger : Ox_observability.Logger.t;
  download_dir : string option;
  downloads_by_guid : (string, string) Hashtbl.t;
  cap : int;
  tombstone_s : int;
  idle : float;
  unclaimed : float;
  started : float;
  ledger :
    ( ledger,
      request,
      answer,
      [ `Refused of P.error | `Actor_stopped | `Timeout ] )
    Ox.Actor.t;
      (** The registry's bookkeeping, owned by one fiber (^nactor-8z1n). Reads that need
          no ordering — [list], [status], the event fiber's routing — take
          {!Ox.Actor.state} and never queue behind a transition. *)
  mutable stopping : bool;
}

let now t = t.now ()

(* The ledger as of now, without a message (^nactor-l87k). *)
let snapshot t = Ox.Actor.state t.ledger
let live_entries t = Keys.fold (fun _ entry acc -> entry :: acc) (snapshot t).entries []
let live_tabs t = List.map (fun entry -> entry.tab) (live_entries t)
let open_tabs t = Keys.cardinal (snapshot t).entries
let iter_tabs t f = List.iter f (live_tabs t)

(* own-82jd own-uo77 own-hslp: [expires] is the next stage this tab faces and the seconds
   left before it, so [list --all] shows what is about to happen. An owned tab faces
   release; an unowned tab of agent origin faces close; a human's tab, and one the human
   holds, face nothing, because no timer may take them (ADR-0005). *)
let expires t (entry : entry) : P.expires option =
  let at = now t in
  let remaining seconds = max 0 (int_of_float (Float.ceil seconds)) in
  let stage name = enum P.Stage.of_string name in
  match entry.owner_state with
  | Owned _ ->
      Some
        P.
          {
            stage = stage "release";
            in_s = remaining (t.idle -. (at -. entry.last_activity));
          }
  | With_human _ -> None
  | Unowned ->
      if P.Origin.to_string entry.tab.origin <> "agent" then None
      else
        Option.map
          (fun since ->
            P.{ stage = stage "close"; in_s = remaining (t.unclaimed -. (at -. since)) })
          entry.unowned_since

(* hand-lz3p hand-lmd5 hand-yytf: the one place an outcome is written. Whichever
   ending gets there first wins and wakes the request that waited; a [resume] that landed
   while the tab was already dying is not overwritten by the death. *)
let settle (waiting : waiting) outcome =
  if waiting.outcome = None then waiting.outcome <- Some outcome;
  Eio.Promise.resolve waiting.resolve ()

(* ---------- The ledger's fold ---------- *)

let refused error = Error (`Refused error)
let refuse = function Ok _ as ok -> ok | Error error -> refused error

let with_entry ledger entry =
  { ledger with entries = Keys.add (key entry.tab.handle) entry ledger.entries }

(* A tombstone outlives the tab for [tombstone_s]; older ones are dropped whenever the
   ledger next changes shape, and are already answered as unknown before that. *)
let prune ~tombstone_s ~at ledger =
  {
    ledger with
    tombs = Keys.filter (fun _ tomb -> at -. tomb.at < float tombstone_s) ledger.tombs;
  }

(* own-0pnk: the one gate every tab command passes through. The decision is the pure
   [authorize]; this is the only place that also records a forced override, with the
   command, the caller, the tab and the state it overrode. *)
let permitted ~logger ~access ~force ~caller handle state =
  if force && forceable access then
    Ox_observability.Logger.warn logger
      ~fields:
        [
          ("cmd", Ox_observability.Logger.String (access_name access));
          ("owner", Ox_observability.Logger.String (P.Owner.to_string caller));
          ("tab", Ox_observability.Logger.String (key handle));
          ("state", Ox_observability.Logger.String (state_name state));
        ]
      "ownership forced";
  authorize ~force access ~caller state

(* own-pmr7 own-teh1: a handle with no live tab is answered from its tombstone.
   [--force] ignores whose tab that was, exactly as it ignores ownership for a live
   one. *)
let refusal_for_gone ~tombstone_s ledger ~force ~caller ~at handle =
  match Keys.find_opt (key handle) ledger.tombs with
  | Some tomb when at -. tomb.at >= float tombstone_s ->
      error "unknown-tab" "unknown tab handle"
  | Some tomb when (not force) && held_by_other tomb.state caller -> not_owner ()
  | Some tomb -> P.tab_gone tomb.disposition
  | None -> error "unknown-tab" "unknown tab handle"

(* own-pmr7: every command that names a tab resolves it here: the entry, once the caller
   is allowed, or the refusal.

   own-ay3s: any action its owner is allowed to take resets the tab's idle clock, so the
   tab an agent is working on stays its own. A refused command is not an action and leaves
   the clock alone. A [Resume] is the human's answer rather than an owner action, and it
   moves the clock itself, once, when it actually resumes (hand-0sja). *)
let authorized ~logger ~tombstone_s ledger ~access ~force ~caller ~at handle =
  match Keys.find_opt (key handle) ledger.entries with
  | Some entry -> (
      match permitted ~logger ~access ~force ~caller handle entry.owner_state with
      | Ok () -> (
          match access with
          | Resume -> Ok entry
          | Act | Dialog | Close | Release | Claim -> Ok { entry with last_activity = at }
          )
      | Error _ as refusal -> refusal)
  | None -> Error (refusal_for_gone ~tombstone_s ledger ~force ~caller ~at handle)

(* hand-nisr hand-lz3p: the entry as [With_human] holding the reason the human is shown
   and the promise the blocked request awaits. hand-len8: a handoff is not an owner action,
   so it leaves the idle clock where it was; [With_human] is exempt from stage 1 anyway
   (ADR-0005). *)
let handed_over entry ~caller ~reason =
  let promise, resolve = Eio.Promise.create () in
  let waiting = { reason; promise; resolve; outcome = None } in
  {
    entry with
    owner_state = With_human caller;
    unowned_since = None;
    handoff = Some waiting;
  }

let register_entry ~tombstone_s ~at ledger tab state =
  let entry =
    {
      tab;
      owner_state = state;
      last_activity = at;
      unowned_since =
        (match state with Unowned -> Some at | Owned _ | With_human _ -> None);
      handoff = None;
    }
  in
  let ledger =
    {
      (prune ~tombstone_s ~at ledger) with
      entries = Keys.add (key tab.handle) entry ledger.entries;
      targets = Keys.add tab.id (key tab.handle) ledger.targets;
    }
  in
  (ledger, entry)

let new_record ~fresh ~generation ~id ~session ~origin ~url ~title ~opener =
  {
    id;
    session;
    enabled_session = None;
    handle = fresh ();
    url;
    title;
    origin;
    generation;
    lock = Eio.Mutex.create ();
    loading = false;
    navigated = false;
    completed = false;
    load_waiter = None;
    navigations = 0;
    page_loading = false;
    page_loads = [];
    snapshot = None;
    baselines = [];
    dialog = None;
    dialog_listeners = [];
    main_frame = None;
    downloads = [];
    counter_installed = false;
    opener;
    settlements = [];
    reading = Reading.create ();
  }

(* own-c0cl own-ehqa: a target Chrome reports from outside the control protocol enters the
   registry here, with the origin and owner [Discovery.born] gives it: the tab that opened
   it when the ledger knows that tab, and a human's unowned tab otherwise. *)
let adopt ~fresh ~tombstone_s ~generation ~at ledger ~id ~session
    (info : Discovery.target) =
  let opener_entry =
    Option.bind info.opener (fun opener ->
        Option.bind (Keys.find_opt opener ledger.targets) (fun k ->
            Keys.find_opt k ledger.entries))
  in
  let creator =
    Discovery.born
      (Option.map
         (fun entry ->
           Discovery.{ origin = entry.tab.origin; owner = owner_of entry.owner_state })
         opener_entry)
  in
  let tab =
    new_record ~fresh ~generation ~id ~session ~origin:creator.origin
      ~url:(Option.value ~default:"about:blank" info.url)
      ~title:(Option.value ~default:"" info.title)
      ~opener:info.opener
  in
  let state = match creator.owner with Some owner -> Owned owner | None -> Unowned in
  let ledger, entry = register_entry ~tombstone_s ~at ledger tab state in
  (ledger, (entry, Option.map (fun opener -> opener.tab) opener_entry))

(* Targets Chrome reported while Leash was creating one of its own: the tab it created —
   which createTarget's reply has registered by now — and anything else that appeared in
   that window, a human's tab included. *)
let flush_pending ~fresh ~tombstone_s ~generation ~at ledger =
  let ledger, adopted =
    Keys.fold
      (fun id (session, info) (ledger, adopted) ->
        if Keys.mem id ledger.targets then (ledger, adopted)
        else
          let ledger, one =
            adopt ~fresh ~tombstone_s ~generation ~at ledger ~id ~session info
          in
          (ledger, one :: adopted))
      ledger.pending (ledger, [])
  in
  ({ ledger with pending = Keys.empty }, List.rev adopted)

(* The whole behaviour of the registry's actor: one request against the current ledger,
   answered with the next ledger and what the caller needs. A refusal is an [Error] and
   leaves the ledger as it was (^nactor-7qi7). It never suspends. *)
let fold ~fresh ~logger ~tombstone_s ~generation ledger request =
  let authorized = authorized ~logger ~tombstone_s ledger in
  match request with
  | Locate { access; force; caller; handle; at } -> (
      match authorized ~access ~force ~caller ~at handle with
      | Error error -> refused error
      | Ok entry -> Ok (with_entry ledger entry, Entry entry))
  | Claim { caller; handle; at } -> (
      (* own-jua9 own-hslp: claiming takes a tab nobody owns for the caller, and the
         unclaimed clock stops when somebody takes it. *)
      match authorized ~access:Claim ~force:false ~caller ~at handle with
      | Error error -> refused error
      | Ok entry ->
          let entry = { entry with owner_state = Owned caller; unowned_since = None } in
          Ok (with_entry ledger entry, Entry entry))
  | Release { caller; force; handle; at } -> (
      match authorized ~access:Release ~force ~caller ~at handle with
      | Error error -> refused error
      | Ok entry ->
          (* own-hslp: the unclaimed clock starts when a caller lets the tab go.
             own-0pnk hand-lz3p: a release that reaches a tab the human holds — only
             [--force] can; a plain one is [with-human] — ends the handoff there and then:
             the waiting request answers [not-owner] and the record leaves with the hold,
             so a later [resume] is [no-handoff]. *)
          Option.iter (fun waiting -> settle waiting (Ended (unowned ()))) entry.handoff;
          let entry =
            { entry with owner_state = Unowned; unowned_since = Some at; handoff = None }
          in
          Ok (with_entry ledger entry, Entry entry))
  | Hand_over { caller; reason; handle; at } -> (
      match authorized ~access:Act ~force:false ~caller ~at handle with
      | Error error -> refused error
      | Ok entry ->
          let entry = handed_over entry ~caller ~reason in
          Ok (with_entry ledger entry, Entry entry))
  | Hand_over_held { caller; reason; handle; at } -> (
      match Keys.find_opt (key handle) ledger.entries with
      | None ->
          refused (refusal_for_gone ~tombstone_s ledger ~force:false ~caller ~at handle)
      | Some entry ->
          let entry = handed_over entry ~caller ~reason in
          Ok (with_entry ledger entry, Entry entry))
  | Resume { caller; handle; at } -> (
      match authorized ~access:Resume ~force:false ~caller ~at handle with
      | Error error -> refused error
      | Ok entry -> (
          match (entry.owner_state, entry.handoff) with
          | With_human owner, Some waiting ->
              (* hand-0sja own-ay3s: the resume resets the tab's idle clock, so the human's
                 work does not expire the agent's tab a moment later. *)
              let entry =
                {
                  entry with
                  owner_state = Owned owner;
                  unowned_since = None;
                  last_activity = at;
                  handoff = None;
                }
              in
              settle waiting Resumed;
              Ok (with_entry ledger entry, Entry entry)
          | _ -> refused (nothing_waiting ())))
  | Restore { handle; waiting } -> (
      (* hand-lz3p hand-lmd5: an ending only cleans up after the handoff it installed
         (compared physically), never after the one that replaced it. *)
      match Keys.find_opt (key handle) ledger.entries with
      | Some ({ handoff = Some current; _ } as entry) when current == waiting ->
          let owner_state =
            match entry.owner_state with
            | With_human owner -> Owned owner
            | (Unowned | Owned _) as state -> state
          in
          Ok (with_entry ledger { entry with handoff = None; owner_state }, Nothing)
      | _ -> Ok (ledger, Nothing))
  | Touch { handle; owner; at } -> (
      match Keys.find_opt (key handle) ledger.entries with
      | Some ({ owner_state = Owned holder; _ } as entry) when holder = owner ->
          Ok (with_entry ledger { entry with last_activity = at }, Nothing)
      | _ -> Ok (ledger, Nothing))
  | Release_idle { handle; at } -> (
      match Keys.find_opt (key handle) ledger.entries with
      | Some ({ owner_state = Owned _; _ } as entry) ->
          let entry = { entry with owner_state = Unowned; unowned_since = Some at } in
          Ok (with_entry ledger entry, Entry entry)
      | _ -> Ok (ledger, Nothing))
  | Register { id; session; origin; state; url; title; opener; at } ->
      let tab =
        new_record ~fresh ~generation:(generation ()) ~id ~session ~origin ~url ~title
          ~opener
      in
      let ledger, entry = register_entry ~tombstone_s ~at ledger tab state in
      Ok (ledger, Entry entry)
  | Disappear { handle; disposition; at } -> (
      match Keys.find_opt (key handle) ledger.entries with
      | None -> Ok (ledger, Nothing)
      | Some entry ->
          (* hand-yytf: a tab that leaves the registry while a handoff is waiting on it
             ends the handoff with the disposition that closed it — a browser loss is
             [tab-gone] with [browser_lost] — rather than leaving the request blocked on a
             page that is gone. *)
          Option.iter
            (fun waiting -> settle waiting (Ended (P.tab_gone disposition)))
            entry.handoff;
          let ledger =
            {
              ledger with
              entries = Keys.remove (key handle) ledger.entries;
              targets = Keys.remove entry.tab.id ledger.targets;
              tombs =
                Keys.add (key handle)
                  { state = entry.owner_state; disposition; at }
                  ledger.tombs;
            }
          in
          Ok (prune ~tombstone_s ~at ledger, Gone entry))
  | Creating { delta; at } ->
      let ledger = { ledger with creating = max 0 (ledger.creating + delta) } in
      if ledger.creating > 0 then Ok (ledger, Nothing)
      else
        let ledger, adopted =
          flush_pending ~fresh ~tombstone_s ~generation:(generation ()) ~at ledger
        in
        Ok (ledger, Adopted adopted)
  | Discover { session; info; at } -> (
      (* own-c0cl own-ehqa: the one road a target Chrome reports from outside the control
         protocol takes into the registry. A known tab is the caller's to update — with the
         session it was attached under, once, and the page's url and title — and never
         another origin or owner: those are what the tab was born with. A target Leash is
         creating is not a discovery: it waits in [pending] until the creation that owns it
         has registered its tab, so an agent's own tab never enters as a human's
         (own-6ndc). *)
      match Keys.find_opt info.id ledger.targets with
      | Some k -> (
          match Keys.find_opt k ledger.entries with
          | Some entry -> Ok (ledger, Known entry)
          | None -> Ok (ledger, Nothing))
      | None ->
          if ledger.creating > 0 then
            Ok
              ( { ledger with pending = Keys.add info.id (session, info) ledger.pending },
                Nothing )
          else
            let ledger, adopted =
              adopt ~fresh ~tombstone_s ~generation:(generation ()) ~at ledger ~id:info.id
                ~session info
            in
            Ok (ledger, Adopted [ adopted ]))

(* The ledger's own arguments never need a clock of their own: every request that reads
   time carries the caller's [at]. *)
let entry_of_answer = function
  | Entry entry | Known entry | Gone entry -> entry
  | _ -> assert false

(* One request, answered. The actor's fold never suspends, so the wait is as short as the
   mailbox. A caller cancelled while it waits leaves its request applied and unanswered;
   the ones that must not be left half-done — a tab leaving, a creation ending — ask
   through {!call_protected}. *)
let call t request =
  match Ox.Actor.ask t.ledger request with
  | Ok answer -> Ok answer
  | Error (`Refused error) -> Error error
  | Error _ -> Error (error "internal" "the tab registry has stopped")

let call_protected t request = Eio.Cancel.protect (fun () -> call t request)
let transition t request = Result.map entry_of_answer (call t request)

let info_of t (entry : entry) : P.tab_info =
  let tab = entry.tab in
  {
    tab = tab.handle;
    url = tab.url;
    title = tab.title;
    origin = tab.origin;
    state = enum P.State.of_string (state_name entry.owner_state);
    owner = owner_of entry.owner_state;
    generation = tab.generation;
    dialog = tab.dialog;
    expires = expires t entry;
    (* hand-r4t1: why this tab is waiting on the human, which is what [list --all] shows
       so a human who stepped away can catch up. *)
    reason = Option.map (fun (waiting : waiting) -> waiting.reason) entry.handoff;
  }

(* The entry as the ledger has it now. A tab that already left is answered from its
   tombstone, so a late reader still names the state it left in. *)
let entry_of t (tab : tab) : entry =
  let ledger = snapshot t in
  match Keys.find_opt (key tab.handle) ledger.entries with
  | Some entry -> entry
  | None ->
      let owner_state =
        match Keys.find_opt (key tab.handle) ledger.tombs with
        | Some tomb -> tomb.state
        | None -> Unowned
      in
      { tab; owner_state; last_activity = now t; unowned_since = None; handoff = None }

let info t tab = info_of t (entry_of t tab)

(* own-pmr7 own-teh1: every command that names a tab resolves it here. *)
let locate_entry t ~access ?(force = false) ~owner handle =
  transition t (Locate { access; force; caller = owner; handle; at = now t })

let locate t ~access ?force ~owner handle =
  Result.map (fun entry -> entry.tab) (locate_entry t ~access ?force ~owner handle)

(* The refusal [locate] would give, and the tab it would return, read from the ledger as it
   is now, without a message and without the idle-clock touch or the forced-override log.
   It is what a command asks before it queues on the tab's lock, so a caller that will be
   refused is never made to wait behind another's action; the authoritative check is
   [locate] or the transition under the lock, which see the ledger as the actor has it. *)
let peek t ~access ?(force = false) ~owner handle =
  let ledger = snapshot t in
  match Keys.find_opt (key handle) ledger.entries with
  | Some entry -> (
      match authorize ~force access ~caller:owner entry.owner_state with
      | Ok () -> Ok entry.tab
      | Error _ as refusal -> refusal)
  | None ->
      Error
        (refusal_for_gone ~tombstone_s:t.tombstone_s ledger ~force ~caller:owner
           ~at:(now t) handle)

(* The tab a target id names, when the registry knows one: what a popup's [openerId]
   resolves through, and which tab an acknowledgement is delivered to. *)
let tab_of_target t id =
  let ledger = snapshot t in
  Option.bind (Keys.find_opt id ledger.targets) (fun k ->
      Option.map (fun entry -> entry.tab) (Keys.find_opt k ledger.entries))

(* A tab leaves the ledger, and whatever waited on its load is woken. *)
let disappear t (tab : tab) disposition =
  ignore (call_protected t (Disappear { handle = tab.handle; disposition; at = now t }));
  match tab.load_waiter with
  | None -> ()
  | Some waiter ->
      tab.load_waiter <- None;
      Eio.Promise.resolve waiter ()

let cdp_call ?(deadline = Ox.Duration.seconds 30) ?session cdp meth params =
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

(* own-6ndc: a tab Leash created, or one Chrome reported, enters the ledger here. *)
let register t ~id ~session ~origin ~state ~url ~title ?opener () =
  transition t (Register { id; session; origin; state; url; title; opener; at = now t })

let ( let* ) = Result.bind

(* tab-0ohq tab-gjo0 own-teh1: a dispatch Chrome may never answer -- the trusted input
   whose handler opens a popup, or the [eval] that runs [window.open] -- is settled by the
   registry, and this is where its waiters live. [acknowledge] registers one before the
   input is sent; [wake] resolves every waiter of the tab a report named; and the no-op
   release {!Dispatch.make} leaves is replaced with the closure that drops the waiter once
   the call has settled by its own reply, so a settled dispatch leaves nothing behind. *)
let dialog_race (tab : tab) : Dialog_race.t =
  {
    current = (fun () -> tab.dialog);
    subscribe =
      (fun notify ->
        tab.dialog_listeners <- notify :: tab.dialog_listeners;
        fun () ->
          tab.dialog_listeners <-
            List.filter (fun listener -> listener != notify) tab.dialog_listeners);
  }

(* hard-yi0a: CDP calls under a tab lock must remain cancellable by the listener
   budget. Eio.Mutex.use_rw ~protect:true masks cancellation for the entire handler;
   ~protect:false poisons the lock on cancellation. Each mutating operation leaves
   its registry fields consistent at yield points, so unlock in a finally instead.
   Synchronous bookkeeping-only sections still use protected use_rw below. *)
let with_tab_lock tab fn =
  Eio.Mutex.lock tab.lock;
  Fun.protect ~finally:(fun () -> Eio.Mutex.unlock tab.lock) fn

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

(* tab-0ohq tab-gjo0: the first report Chrome makes about a target is the acknowledgement
   of the dispatch that opened it -- [Target.targetCreated], or the attachment or the info
   change that carries the opener first when the announcement was missed -- and the tab is
   registered before its opener's waiters are woken, so the action that settles already
   sees the popup in [popups] (tab-tm6c tab-8k2g). *)
let wake_openers adopted =
  List.iter
    (fun (_, opener) ->
      Option.iter (fun opener_tab -> wake opener_tab Dispatch.Popup) opener)
    adopted

let adopted_of = function Adopted adopted -> adopted | _ -> []

(* own-c0cl own-ehqa: the one road a target Chrome reports from outside the control
   protocol takes into the registry, whether Chrome announced it, attached to it, or both
   in that order; the ledger decides what it is ([fold]'s [Discover]). A known tab gains
   what a later report adds — the session it was attached under, once, and the page's url
   and title — and never another origin or owner: those are what the tab was born with,
   which is what "origin never changes" means. *)
let discover t ~session (info : Discovery.target) =
  match call t (Discover { session; info; at = now t }) with
  | Error _ -> ()
  | Ok (Known { tab; _ }) ->
      (match (tab.session, session) with
      | None, Some session -> tab.session <- Some session
      | _ -> ());
      Option.iter (fun url -> tab.url <- url) info.url;
      Option.iter (fun title -> tab.title <- title) info.title;
      Option.iter (fun opener -> tab.opener <- Some opener) info.opener
  | Ok answer -> wake_openers (adopted_of answer)

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
    if tab.dialog = None && tab.navigations <> since && tab.page_loading then (
      let promise, waiter = Eio.Promise.create () in
      tab.page_loads <- waiter :: tab.page_loads;
      Fun.protect
        ~finally:(fun () ->
          tab.page_loads <- List.filter (fun pending -> pending != waiter) tab.page_loads)
        (fun () -> ignore (t.await_load promise)));
    if tab.dialog = None && tab.navigations <> since then refresh_from_target cdp tab;
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
      match
        Dialog_race.first (dialog_race tab) (fun () ->
            let* () = start () in
            match t.await_load promise with
            | Error `Timeout ->
                Error (error "timeout" "navigation did not load within 30 seconds")
            | Ok () ->
                refresh_from_target cdp tab;
                Ok ())
      with
      | `Dialog _ -> Ok ()
      | `Value result -> result)

let new_tab t ~owner ~url =
  let target = Option.value ~default:"about:blank" url in
  if not (valid_url target) then Error (refusal ())
  else if open_tabs t >= t.cap then Error (error "tab-cap" "tab cap reached")
  else
    let* cdp = ready t in
    Ox.Actor.tell t.ledger (Creating { delta = 1; at = now t });
    Fun.protect
      ~finally:(fun () ->
        (* The last creation to end adopts what Chrome reported meanwhile. The ask must
           not be cancelled halfway, whatever ended the creation. *)
        match call_protected t (Creating { delta = -1; at = now t }) with
        | Ok answer -> wake_openers (adopted_of answer)
        | Error _ -> ())
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
                let* { tab; _ } =
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

(* chrome-1yn9: the lock-free body, for a caller that already holds the tab's lock (the
   run's playbook switch, run-xh5d). *)
let navigate_locked t ~owner ~tab url =
  let* cdp = ready t in
  let* session = page_session t cdp tab in
  (* chrome-1yn9: the tab is navigating to [url] now, so [url] is the fallback until
     Chrome speaks; the load wait's own [Target.getTargetInfo] refresh replaces it with
     the URL Chrome committed, which is what a redirect changes. *)
  tab.url <- url;
  tab.snapshot <- None;
  let* () =
    with_load_wait t cdp tab (fun () ->
        let* reply = cdp_call ~session cdp "Page.navigate" (obj [ ("url", str url) ]) in
        (match text "frameId" reply with
        | Some id -> tab.main_frame <- Some id
        | None -> ());
        match text "errorText" reply with
        | Some _ -> Error (error "internal" "browser navigation failed")
        | None -> Ok ())
  in
  let* _ = locate t ~access:Act ~owner tab.handle in
  let* _ = ready t in
  Ok (info t tab)

let navigate t ~owner handle url =
  if not (valid_url url) then Error (refusal ())
  else
    let* tab = peek t ~access:Act ~owner handle in
    with_tab_lock tab (fun () ->
        let* tab = locate t ~access:Act ~owner handle in
        navigate_locked t ~owner ~tab url)

(* own-jua9: claiming takes a tab nobody owns for the caller, and leaves every other
   command's authorization untouched. *)
let claim t ~owner handle =
  let* tab = peek t ~access:Claim ~owner handle in
  with_tab_lock tab (fun () ->
      let* { tab; _ } = transition t (Claim { caller = owner; handle; at = now t }) in
      (* tab-a7l3: a claim is the moment a discovered tab stops being lazy. Discovery
         itself only records the session Chrome reports (own-c0cl), so the page's event
         domains are enabled here, in the session the tab is talked to in, and a [debug]
         from the claim on covers what the page did while the agent held it. Best effort
         like every enable: a browser that refuses leaves the tab claimed, and the first
         command that needs the page reports its own failure. *)
      (match ready t with Error _ -> () | Ok cdp -> ignore (page_session t cdp tab));
      Ok (info t tab))

(* own-2zs7 own-0pnk: release drops the caller's ownership without touching the page, so
   another agent or the human can take it; [--force] does the same to a tab the caller
   does not own, and to one the human is holding (ADR-0005). *)
let release t ~owner ?(force = false) handle =
  let* tab = locate t ~access:Release ~force ~owner handle in
  (* own-0pnk hand-lz3p: a release that reaches a tab the human holds ends the handoff
     there and then, under this lock, rather than leaving the agent to wait out its
     deadline for a tab it no longer owns (the ledger's [Release] does that). *)
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* _ = transition t (Release { caller = owner; force; handle; at = now t }) in
      Ok P.{ released = true })

(* own-7pzw own-0pnk: [close] is idempotent for the caller that closed the tab, and
   [--force] closes anyone's — including the tab the human holds — because an agent that
   died without releasing is why the flag exists. A close that reaches a held tab ends
   the handoff with it: [disappear] wakes the waiting request with [tab-gone] and the
   disposition that closed it, so nothing waits on a page that is gone (hand-lz3p). *)
let close t ~owner ?(force = false) handle =
  let k = key handle in
  match Keys.find_opt k (snapshot t).tombs with
  | Some tomb
    when P.Disposition.to_string tomb.disposition = "closed_by_owner"
         && (force || owner_of tomb.state = Some owner)
         && now t -. tomb.at < float t.tombstone_s ->
      Ok P.{ closed = true }
  | _ ->
      let* tab = peek t ~access:Close ~force ~owner handle in
      with_tab_lock tab (fun () ->
          let* tab = locate t ~access:Close ~force ~owner handle in
          let* cdp = ready t in
          let* session = page_session t cdp tab in
          let close_target () =
            cdp_call cdp "Target.closeTarget" (obj [ ("targetId", str tab.id) ])
          in
          let already_open = tab.dialog <> None in
          let* _ =
            match Dialog_race.first (dialog_race tab) close_target with
            | `Value result -> result
            | `Dialog dialog when P.Dialog_kind.to_string dialog.kind = "beforeunload" ->
                let* _ =
                  cdp_call ~session cdp "Page.handleJavaScriptDialog"
                    (obj [ ("accept", `Bool true) ])
                in
                (* An already-open beforeunload needs the close dispatched now; an
                   opening during this call came from the close already in flight. *)
                if already_open then close_target () else Ok (`Assoc [])
            | `Dialog _ ->
                Error (error "dialog-open" "answer the dialog before closing the tab")
          in
          disappear t tab (disposition "closed_by_owner");
          Ok P.{ closed = true })

(* hand-lmd5: the deadline a handoff runs on — the caller's [timeout_s], fifteen minutes
   when it names none (or names something a clock cannot use). [Control.budget] asks this
   same question, so the handler's budget and the request's own deadline cannot drift
   apart. *)
let handoff_timeout = function
  | Some seconds when seconds > 0 -> Ox.Duration.seconds seconds
  | Some _ | None -> Ox.Duration.minutes 15

(* hand-nisr own-pmr7 hand-lz3p: the state transition a handoff is. It lands in the
   registry here because [With_human] is part of the owner state and the [with-human]
   refusal has to be reachable to be tested: the tab moves to [With_human] holding the
   reason the human is shown and the promise the blocked request awaits, and from that
   moment every command is refused, the owner's own included, until [resume]. *)
(* hand-len8 hand-nisr: the transition itself, for a caller that already holds the tab's
   lock — which the run does for its whole duration (run-d82w) — and for the command
   below. *)
let begin_handoff_locked t ~owner ~reason tab =
  let* entry =
    transition t
      (Hand_over_held { caller = owner; reason; handle = tab.handle; at = now t })
  in
  match entry.handoff with
  | Some waiting -> Ok (entry, waiting)
  | None -> Error (error "internal" "a handoff was not installed")

let begin_handoff t ~owner ~reason handle =
  let* tab = peek t ~access:Act ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      let* entry =
        transition t (Hand_over { caller = owner; reason; handle; at = now t })
      in
      match entry.handoff with
      | Some waiting -> Ok (entry, waiting)
      | None -> Error (error "internal" "a handoff was not installed"))

(* hand-nisr hand-lz3p: the transition without its wait, which is what [handoff] is built
   from and what a caller that only needs the state — the authorization matrix of
   ADR-0005, the suspended handoff a test resumes later — drives directly. *)
let hand_over t ~owner ~reason handle =
  let* entry, _ = begin_handoff t ~owner ~reason handle in
  Ok (info_of t entry)

(* hand-0sja hand-szz7: the human's answer, from any terminal — the notification action
   and [leash resume <tab>] arrive here as the same request. Whoever asks, the tab goes
   back to the owner it was handed off from, which is why [Resume] is the one command
   anybody may send and why a tab nobody is waiting on is [no-handoff] rather than a
   refusal about ownership. *)
let resume t ~owner handle =
  let* tab = peek t ~access:Resume ~owner handle in
  Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
      (* hand-0sja own-ay3s: the resume resets the tab's idle clock, so the human's work
         does not expire the agent's tab a moment later. *)
      let* _ = transition t (Resume { caller = owner; handle; at = now t }) in
      Ok P.{ resumed = true })

(* hand-04rb: every human-facing step a handoff waits on is bounded by five seconds — the
   browser call that raises the view here, and the window lookup and focus command inside
   {!Desktop} — so a desktop that has stopped answering cannot hold the handler. *)
let step_deadline = Ox.Duration.seconds 5

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
                  Ox_observability.Logger.info t.logger
                    ~fields:[ ("tab", Ox_observability.Logger.String (key tab.handle)) ]
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
  (* hand-lmd5: the deadline counts from the request, not from the moment the ledger's
     answer reaches this fiber. *)
  let started = now t in
  let* { tab; _ }, waiting = begin_handoff t ~owner ~reason handle in
  let warnings = ref [] in
  let warn step message =
    let warning = step ^ ": " ^ message in
    warnings := warning :: !warnings;
    Ox_observability.Logger.warn t.logger
      ~fields:
        [
          ("tab", Ox_observability.Logger.String (key tab.handle));
          ("reason", Ox_observability.Logger.String reason);
        ]
      ("handoff warning: " ^ warning)
  in
  let release () =
    (* The listener cancels this fiber when the client disconnects, so the restore runs
       under [Eio.Cancel.protect]: it must not be cancelled halfway, and it must not wait
       on a lock it will never get. *)
    Eio.Cancel.protect (fun () ->
        Eio.Mutex.use_rw ~protect:true tab.lock (fun () ->
            ignore (call t (Restore { handle = tab.handle; waiting }))))
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
    let spent = Ox.Duration.ms (int_of_float ((now t -. started) *. 1000.)) in
    Ox.Duration.max Ox.Duration.zero
      (Ox.Duration.subtract (handoff_timeout timeout_s) spent)
  in
  Fun.protect ~finally:release (fun () ->
      Eio.Switch.run (fun human ->
          (* hand-04rb hand-phof: the human-facing steps, on this handoff's own switch, so
             the notifier is stopped when the request ends however it ends. *)
          announce t ~sw:human ~tab ~reason ~warn;
          let left = remaining () in
          if not (Ox.Duration.is_zero left) then
            ignore (t.await_handoff left waiting.promise);
          answer ()))

(* own-82jd: without [--all] a caller sees its own tabs — the ones it owns and the one the
   human is holding for it — and nothing of another agent's. *)
let list t ~owner ~all =
  let tabs =
    Keys.fold
      (fun _ (entry : entry) acc ->
        if all || owner_of entry.owner_state = Some owner then info_of t entry :: acc
        else acc)
      (snapshot t).entries []
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

let idleness_of t (entry : entry) : idleness =
  let at = now t in
  {
    handle = entry.tab.handle;
    origin = entry.tab.origin;
    owner_state = entry.owner_state;
    idle_for_s = at -. entry.last_activity;
    unowned_for_s = Option.map (fun since -> at -. since) entry.unowned_since;
  }

let idleness t : idleness list =
  Keys.fold (fun _ entry acc -> idleness_of t entry :: acc) (snapshot t).entries []
  |> List.sort (fun (a : idleness) (b : idleness) ->
      String.compare (key a.handle) (key b.handle))

(* own-uo77 own-hslp own-2zpi own-nbwk: one expiry pass. Every decision is taken and
   applied with the tab's own lock held, so a claim or an action that lands while the
   sweep runs is not overrun: [Release_idle] only sets an owned tab unowned (the ledger
   checks the state again when it applies it), and [Close_idle] only closes an unowned
   tab of agent origin, with disposition [closed_by_ttl]. The handles are collected before
   the first decision because closing suspends. *)
let sweep t ~decide =
  let handles =
    Keys.fold
      (fun _ (entry : entry) acc -> entry.tab.handle :: acc)
      (snapshot t).entries []
    |> List.sort (fun a b -> String.compare (key a) (key b))
  in
  List.filter_map
    (fun handle ->
      match Keys.find_opt (key handle) (snapshot t).entries with
      | None -> None
      | Some { tab; _ } ->
          with_tab_lock tab (fun () ->
              match Keys.find_opt (key handle) (snapshot t).entries with
              | None -> None
              | Some entry -> (
                  let step = decide (idleness_of t entry) in
                  match step with
                  | Keep_idle -> None
                  | Release_idle -> (
                      match entry.owner_state with
                      | Owned _ -> (
                          match call t (Release_idle { handle; at = now t }) with
                          | Ok (Entry _) -> Some (handle, step)
                          | Ok _ | Error _ -> None)
                      | Unowned | With_human _ -> None)
                  | Close_idle -> (
                      match entry.owner_state with
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

(* The two reads a snapshot's currency rests on, shared by `snap` and by `wait
   --changed-since` (hard-sckn): the main frame's loader id, and the document's mutation
   guard — installed on the spot when this document has none. [call] is a page-session
   CDP call. *)
let frame_loader call =
  let* reply = call "Page.getFrameTree" (obj []) in
  match member "frameTree" reply with
  | Some tree ->
      let frame = Option.value ~default:`Null (member "frame" tree) in
      Ok (Option.value ~default:"" (text "loaderId" frame))
  | None -> Error (error "internal" "browser omitted frame tree")

let page_guard call =
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
    let loader () = frame_loader call in
    let guard () = page_guard call in
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
      let epoch, count, _, _, _, _ = after in
      Ok
        ( rows,
          before = after && before_loader = after_loader,
          after_loader,
          Some (epoch, count) )
    in
    let rec attempt remaining =
      let* rows, settled, loader_id, guard =
        if tab.dialog <> None then Ok ([], false, "", None) else capture ()
      in
      if (not settled) && remaining > 0 && tab.dialog = None then attempt (remaining - 1)
      else Ok (rows, settled, loader_id, guard)
    in
    let* rows, settled, loader_id, guard = attempt 2 in
    let snapshot =
      enum P.Snapshot_id.of_string ("s_" ^ P.Handle.to_string (handle ~caps:t.caps))
    in
    tab.snapshot <- Some (snapshot, loader_id, rows);
    (* hard-sckn: what the page was when this table was taken, kept beyond the next
       navigation (which clears the table itself) so `wait --changed-since` can tell that
       the page moved on. The last few tables are remembered. *)
    (match guard with
    | Some guard ->
        tab.baselines <-
          (snapshot, Reading.{ loader = loader_id; guard = Some guard })
          :: List.filteri (fun i _ -> i < baselines_kept - 1) tab.baselines
    | None -> ());
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
  let* tab = peek t ~access:Act ~owner args.tab in
  with_tab_lock tab (fun () ->
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
    dialog_race = dialog_race tab;
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
    snapshot_current =
      (fun id ->
        match tab.snapshot with Some (current, _, _) -> current = id | None -> false);
    baseline = (fun id -> List.assoc_opt id tab.baselines);
    probe =
      (fun () ->
        let call meth params = cdp_call ~session cdp meth params in
        let* loader = frame_loader call in
        let* epoch, count, _, _, _, _ = page_guard call in
        Ok Reading.{ loader; guard = Some (epoch, count) });
  }

let with_reading t ~access ~owner handle f =
  let* tab = peek t ~access ~owner handle in
  with_tab_lock tab (fun () ->
      let* tab = locate t ~access ~owner handle in
      let* cdp = ready t in
      let* session = page_session t cdp tab in
      f tab (reading_browser t ~session tab cdp))

let read_text t ~owner (args : P.text_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser -> Reading.text browser args)

let eval t ~owner (args : P.eval_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser -> Reading.eval browser args)

let shot t ~owner (args : P.shot_args) =
  with_reading t ~access:Act ~owner args.tab (fun _ browser ->
      Reading.shot ~caps:t.caps browser args)

let debug t ~owner (args : P.debug_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  Reading.debug tab.reading args

(* hard-xg6y hard-ovbx hard-vq5s hard-ufb7: the request ring, cookies and storage are
   reads. They take no action lock, like [debug] and [wait]: reading a body while a long
   [drive] holds the tab is the point, and they change nothing a running action could
   trip over. Ownership is still checked, and the page session still comes from the
   registry. *)
let with_reading_unlocked t ~owner handle f =
  let* tab = locate t ~access:Act ~owner handle in
  let* cdp = ready t in
  let* session = page_session t cdp tab in
  f tab (reading_browser t ~session tab cdp)

let net t ~owner (args : P.net_args) =
  let* tab = locate t ~access:Act ~owner args.tab in
  Reading.net tab.reading args

let net_body t ~owner (args : P.net_entry_args) =
  with_reading_unlocked t ~owner args.tab (fun tab browser ->
      Reading.net_body browser tab.reading args)

let net_request t ~owner (args : P.net_entry_args) =
  with_reading_unlocked t ~owner args.tab (fun tab browser ->
      Reading.net_request browser tab.reading args)

let cookies t ~owner (args : P.tab_args) =
  with_reading_unlocked t ~owner args.tab (fun _ browser -> Reading.cookies browser)

let storage t ~owner (args : P.storage_args) =
  with_reading_unlocked t ~owner args.tab (fun _ browser -> Reading.storage browser args)

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
  let browser = reading_browser t ~session tab cdp in
  (* hard-sr9v hard-b1na: a wait takes no lock of the tab's — an action on the same tab
     runs beside it — and, being the owner's work in progress, keeps the tab from idling
     out: a wait of an hour outlasts the idle clock's thirty minutes, which counts owner
     activity. *)
  let touch () =
    Ox.Actor.tell t.ledger (Touch { handle = tab.handle; owner; at = now t })
  in
  Reading.wait
    {
      browser with
      sleep =
        (fun seconds ->
          touch ();
          browser.sleep seconds);
    }
    args

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
    dialog_race = dialog_race tab;
    acknowledge = (fun () -> acknowledge tab);
    all_tabs =
      (fun () ->
        Keys.fold
          (fun _ (entry : entry) acc -> (info_of t entry, entry.tab.opener) :: acc)
          (snapshot t).entries []
        |> List.sort (fun ((a : P.tab_info), _) ((b : P.tab_info), _) ->
            String.compare (key a.tab) (key b.tab)));
  }

let with_action t ~owner handle f =
  let* tab = peek t ~access:Act ~owner handle in
  with_tab_lock tab (fun () ->
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

let upload t ~owner (args : P.upload_args) =
  with_action t ~owner args.tab (fun cdp view ->
      Actions.upload ~caps:t.caps ~cdp view args)

let hover t ~owner (args : P.hover_args) =
  with_action t ~owner args.tab (fun cdp view -> Actions.hover ~cdp view args)

(* drive-8n2z drive-tfqh: keep the lock across observe/decide/act. Never call
   a public Tabs action here: each would reacquire this very same mutex. The
   metric expression reads one document state; the fingerprint hashes visible
   text, URL/title, scroll position and actionable AX rows, not snapshot IDs. *)
let drive_locked
    ?(decide =
      fun ~deadline:_ _ ->
        Error
          (error "model-unavailable" "System One client unavailable"
             ~detail:(obj [ ("code", str "client-unavailable") ])))
    ?(text_helper = fun () -> Text_helper.unavailable)
    ?(guard = fun (_ : P.snapshot) (_ : Jev_request.decision) -> None) t ~owner ~model tab
    (args : P.drive_args) =
  (* drive-kh2u drive-ix5t: one Decide is one System One call, and it is inside the
         drive's own deadline: the caller's remaining budget is what the model call is
         bounded by, so a slow provider cannot outlast the reply the client is waiting
         for. The text helper's completion is bounded by the same budget (drive-ls3c). *)
  let started = now t in
  let budget = float_of_int (Option.value ~default:120 args.deadline_s) in
  let remaining () =
    Ox.Duration.ms (max 1 (int_of_float ((budget -. (now t -. started)) *. 1000.)))
  in
  let decide request = decide ~deadline:(remaining ()) request in
  (* drive-ls3c: one helper per drive. It carries the one-entry memo that reuses an
         answer for an unchanged context — what a stale-row retry is — so it is taken
         here and goes away with the drive. *)
  let helper = text_helper () in
  let text_value context = helper.Text_helper.complete ~deadline:(remaining ()) context in
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
            index = None;
            snapshot = None;
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
    match guard page.snapshot choice with
    | Some kind ->
        Error (error "invalid-request" ("discovery stopped before " ^ kind ^ " action"))
    | None -> (
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
        | _ -> Error (error "invalid-request" "unsupported drive operation"))
  in
  Drive.run
    ~handler:Drive.{ observe; decide; text_value; act }
    ~now:(fun () -> now t)
    ~model ~args
    ~dry_run:(Option.value ~default:false args.dry_run)

(* drive-8n2z: the public drive takes the tab's lock for the whole computation; the body
   above is what a caller that already holds it (the run's every step, run-d82w) uses. *)
let drive ?decide ?text_helper t ~owner ~model (args : P.drive_args) =
  let* tab = peek t ~access:Act ~owner args.tab in
  with_tab_lock tab (fun () ->
      let* tab = locate t ~access:Act ~owner args.tab in
      drive_locked ?decide ?text_helper t ~owner ~model tab args)

(* L31 run-9ypy run-vj48 run-shgh run-fwl8, L32 run-m0r8: a mission over the installed
   playbooks, with the
   tab's action lock held for the whole run. Every step is one [drive_locked] call — the
   very operator level the [drive] command runs — and every judgment goes through
   [Run.loop]'s handler, which this builds over the browser and the models service's levels
   (Control installs them; a scripted test installs its own, which is what makes the whole
   loop testable offline). The playbooks are loaded here, once, from the XDG directory the
   [playbook] commands read (run-tcuz) unless a test hands them in. *)
let no_levels : Run.levels =
  Run.
    {
      choose =
        (fun ~deadline:_ _ ->
          Error
            (error "model-unavailable"
               "no model client is configured for the run's playbook and procedure levels"));
      score =
        (fun ~deadline:_ ~sentence:_ ~state:_ ->
          Error
            (error "model-unavailable"
               "no model client is configured for the run's judgment score"));
      plan =
        (fun ~deadline:_ _ ->
          Error
            (error "model-unavailable"
               "no model client is configured for the run's planner"));
    }

let run ?(levels = no_levels) ?(model = "unconfigured")
    ?(decide =
      fun ~deadline:_ _ ->
        Error
          (error "model-unavailable" "System One client unavailable"
             ~detail:(obj [ ("code", str "client-unavailable") ])))
    ?(text_helper = fun () -> Text_helper.unavailable) ?discovery t ~owner ~tab ?installed
    (args : P.run_args) =
  let handle = tab in
  let* tab = peek t ~access:Act ~owner handle in
  with_tab_lock tab (fun () ->
      let* tab = locate t ~access:Act ~owner handle in
      (* run-fwl8: a run starts from a state it can act in. Ownership and the human's hold
         are [locate]'s refusals; a dialog waiting to be answered is this one. *)
      match tab.dialog with
      | Some dialog ->
          Error
            (error "dialog-open"
               (Printf.sprintf "a %s dialog is open on the tab; answer it before the run"
                  (P.Dialog_kind.to_string dialog.P.kind)))
      | None -> (
          let* cdp = ready t in
          let* session = page_session t cdp tab in
          let browser = reading_browser t ~session tab cdp in
          let started = now t in
          let run_args = Run.of_args args in
          let run_args =
            match discovery with
            | None -> run_args
            | Some (_, turns) -> { run_args with Run.max_plans = turns }
          in
          let discovered =
            ref
              (Option.map
                 (fun ((seed : Run.discovery), _) -> seed.book.playbook)
                 discovery)
          in
          let budget = float_of_int run_args.Run.deadline_s in
          let remaining () =
            Ox.Duration.ms
              (max 1 (int_of_float ((budget -. (now t -. started)) *. 1000.)))
          in
          let bounded limit text =
            if String.length text <= limit then text else String.sub text 0 limit
          in
          (* run-pvmc: the page text stays on this side of the loop; the upper levels are
             asked over the small state Run builds. *)
          let observe () =
            let* snapshot =
              snap_locked t tab
                P.{ tab = handle; match_ = None; limit = Some 250; offset = None }
            in
            let* rendered =
              if snapshot.P.dialog <> None then
                Ok
                  P.
                    {
                      url = snapshot.url;
                      title = snapshot.title;
                      text = "";
                      truncated = false;
                    }
              else
                Reading.text browser
                  P.{ tab = handle; index = None; max_chars = Some 12_000 }
            in
            Ok
              Run.
                {
                  url = snapshot.P.url;
                  title = snapshot.P.title;
                  text = rendered.P.text;
                  dialog = snapshot.P.dialog;
                  rows =
                    List.map
                      (fun (row : P.row) -> (row.P.role, row.P.name))
                      snapshot.P.rows;
                  downloads =
                    List.map
                      (fun (download : P.download_info) ->
                        (download.P.suggested_name, download.P.mime, download.P.state))
                      (List.rev tab.downloads);
                  snapshot;
                }
          in
          (* run-l06s run-vbys run-xqh8: the checkers first and the JEV score only where no
             checker applies. The score is one model call per unchanged page — the bounded
             wait would otherwise ask it every 100 ms — so the answer is memoized on the
             sentence and the text it was asked over. *)
          let verify ~pages ~checks ~timeout_s =
            let failure = ref None in
            let memo = Hashtbl.create 4 in
            let last = ref None in
            let observe_page () =
              match observe () with
              | Error _ ->
                  Playbook.
                    { kind = None; text = ""; dialog = false; rows = []; downloads = [] }
              | Ok observation ->
                  last := Some observation;
                  Playbook.
                    {
                      kind =
                        Playbook.page_kind pages ~url:observation.Run.url
                          ~text:observation.Run.text;
                      text = observation.Run.text;
                      dialog = Option.is_some observation.Run.dialog;
                      rows = observation.Run.rows;
                      downloads = observation.Run.downloads;
                    }
            in
            let score sentence (observation : Playbook.observation) =
              let key = sentence ^ "\000" ^ observation.Playbook.text in
              match Hashtbl.find_opt memo key with
              | Some value -> value
              | None ->
                  let state =
                    match !last with
                    | Some observation ->
                        `Assoc
                          [
                            ("title", `String observation.Run.title);
                            ("url", `String observation.Run.url);
                            ( "page_kind",
                              match
                                Playbook.page_kind pages ~url:observation.Run.url
                                  ~text:observation.Run.text
                              with
                              | Some kind -> `String kind
                              | None -> `Null );
                            ("text", `String (bounded 6_000 observation.Run.text));
                          ]
                    | None -> `Null
                  in
                  let value =
                    match levels.Run.score ~deadline:(remaining ()) ~sentence ~state with
                    | Ok value -> value
                    | Error error ->
                        if !failure = None then failure := Some error;
                        0.
                  in
                  Hashtbl.replace memo key value;
                  value
            in
            let outcome =
              Dialog_race.first (dialog_race tab) (fun () ->
                  Playbook.await_results
                    ~now:(fun () -> now t)
                    ~sleep:t.sleep ~observe:observe_page ~score ~timeout_s checks)
            in
            let results =
              match outcome with `Dialog _ -> [] | `Value results -> results
            in
            match outcome with
            | `Dialog _ ->
                let* observation = observe () in
                Ok ([], observation)
            | `Value _ -> (
                match !failure with
                | Some error -> Error error
                | None -> (
                    match !last with
                    | None -> Error (error "internal" "the verification observed nothing")
                    | Some observation ->
                        Ok
                          ( List.map
                              (fun (checked : Playbook.checked) ->
                                P.
                                  {
                                    sentence = checked.Playbook.expectation;
                                    checker =
                                      Playbook.checker_name checked.Playbook.checker;
                                    passed = checked.Playbook.passed;
                                    score = checked.Playbook.score;
                                  })
                              results,
                            observation )))
          in
          let handler : Run.handler =
            Run.
              {
                observe;
                navigate =
                  (fun url ->
                    let* _ = navigate_locked t ~owner ~tab url in
                    Ok ());
                choose =
                  (fun question -> levels.Run.choose ~deadline:(remaining ()) question);
                text_value =
                  (fun context ->
                    (text_helper ()).Text_helper.complete ~deadline:(remaining ()) context);
                step =
                  (fun request ->
                    let guard snapshot choice =
                      match discovery with
                      | None -> None
                      | Some _ -> (
                          let operation =
                            P.Operation.to_string choice.Jev_request.operation
                          in
                          if
                            operation = "wait" || operation = "scroll_down"
                            || operation = "scroll_up"
                          then None
                          else
                            match
                              List.find_opt
                                (fun (row : P.row) -> Some row.index = choice.index)
                                snapshot.P.rows
                            with
                            | None -> Some "unrecognized target"
                            | Some row -> Run.unsafe_action (row.name ^ " " ^ row.role))
                    in
                    drive_locked ~decide ~text_helper ~guard t ~owner ~model tab
                      P.
                        {
                          tab = handle;
                          goal = request.Run.goal;
                          max_steps = Some request.Run.max_steps;
                          deadline_s = Some request.Run.deadline_s;
                          dry_run = Some request.Run.dry_run;
                        });
                verify;
                plan =
                  (fun request ->
                    let* reply = levels.Run.plan ~deadline:(remaining ()) request in
                    (match !discovered with
                    | None -> ()
                    | Some book ->
                        discovered :=
                          Some { book with Playbook.pages = book.pages @ reply.Run.pages });
                    Ok reply);
                (* run-m0r8: a planner-written procedure that ran and passed its
                   expectations is written to XDG state here; the playbook the operator
                   authored is never written by a run, only by [playbook accept]. *)
                propose =
                  (fun ~site proc ->
                    match !discovered with
                    | Some book ->
                        discovered :=
                          Some
                            { book with Playbook.procedures = book.procedures @ [ proc ] };
                        Ok
                          (Filename.concat
                             (Playbook.proposed_directory ~caps:t.caps ())
                             (site ^ ".json"))
                    | None -> (
                        match Playbook.propose ~caps:t.caps ~site proc with
                        | Ok path -> Ok path
                        | Error why -> Error (error "internal" why)));
                hand_off =
                  (fun ~reason ->
                    let* entry, _ = begin_handoff_locked t ~owner ~reason tab in
                    Ok (info_of t entry));
                (* extr-8o1h extr-k40c: the only script text that reaches the page in a run
                   is a loaded playbook's, through {!Reading.script}. A script that threw,
                   broke its shape or was too large is the procedure's failure; a browser
                   failure ends the run. *)
                script =
                  (fun script ~args ->
                    let started = now t in
                    match Reading.script browser script ~args with
                    | Ok ran ->
                        Ok
                          (Run.Collected
                             {
                               value = ran.Reading.value;
                               records = ran.Reading.records;
                               bytes = ran.Reading.bytes;
                               elapsed_ms = ran.Reading.elapsed_ms;
                             })
                    | Error failure
                      when List.mem
                             (P.Error_code.to_string failure.P.code)
                             [ "script-failed"; "script-invalid"; "too-large" ] ->
                        Ok
                          (Run.Rejected
                             {
                               reason = failure.P.message;
                               elapsed_ms = int_of_float ((now t -. started) *. 1000.);
                             })
                    | Error failure -> Error failure);
              }
          in
          match
            match installed with
            | Some books -> Ok books
            | None -> Playbook.list ~caps:t.caps ()
          with
          | Error why -> Error (error "invalid-request" why)
          | Ok books -> (
              let execute on_record =
                Run.loop ~handler ~on_record
                  ~pause_ms:(fun ms -> t.sleep (float_of_int ms /. 1000.))
                  ~now:(fun () -> now t)
                  ~installed:books ?discovery:(Option.map fst discovery) run_args
              in
              let* result =
                match args.P.out with
                | None -> execute (fun _ -> Ok ())
                | Some path -> (
                    try
                      let channel = Ox_caps.Cap_stdlib.open_out ~caps:t.caps path in
                      Fun.protect
                        ~finally:(fun () -> close_out channel)
                        (fun () ->
                          execute (fun record ->
                              try
                                output_string channel (Yojson.Safe.to_string record);
                                output_char channel '\n';
                                flush channel;
                                Ok ()
                              with Sys_error why -> Error (error "internal" why)))
                    with Sys_error why -> Error (error "invalid-request" why))
              in
              match !discovered with
              | None -> Ok result
              | Some book -> (
                  match Playbook.propose_book ~caps:t.caps book with
                  | Error why -> Error (error "internal" why)
                  | Ok path -> Ok { result with P.proposals = [ path ] }))))

(* extr-mp5z extr-lslp: the playbook commands that need a page. The script is looked up in
   the playbook directory by name — nothing on the wire carries script text — and [installed]
   hands a control test its playbooks the way it does a run's. *)
let find_playbook ~caps ?installed name =
  match installed with
  | Some books -> (
      match
        List.find_opt
          (fun (book : Playbook.loaded) ->
            Option.map Filename.basename book.Playbook.dir = Some name)
          books
      with
      | Some book -> Ok book
      | None ->
          Error
            (error "invalid-request" (Printf.sprintf "no playbook %s is installed" name)))
  | None -> (
      match Playbook.show ~caps name with
      | Ok book -> Ok book
      | Error why -> Error (error "invalid-request" why))

let script_arguments = function
  | None -> Ok []
  | Some (`Assoc fields) ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | (name, `String value) :: rest -> go ((name, value) :: acc) rest
        | (name, _) :: _ ->
            Error
              (error "invalid-request"
                 (Printf.sprintf "argument %s must be a string" name))
      in
      go [] fields
  | Some _ -> Error (error "invalid-request" "args must be an object of strings")

let echo_limit = 1_048_576

let playbook_test ?installed t ~owner (args : P.playbook_test_args) =
  let* playbook, name =
    match String.split_on_char '/' args.script with
    | [ playbook; script ] when playbook <> "" && script <> "" -> Ok (playbook, script)
    | _ -> Error (error "invalid-request" "script must be <playbook>/<script>")
  in
  let* book = find_playbook ~caps:t.caps ?installed playbook in
  let* script =
    match Playbook.script_named book name with
    | Some script -> Ok script
    | None ->
        Error
          (error "invalid-request"
             (Printf.sprintf "playbook %s has no script %s" playbook name))
  in
  let* arguments = script_arguments args.args in
  with_reading t ~access:Act ~owner args.tab (fun _ browser ->
      let* ran = Reading.script browser script ~args:arguments in
      let value, truncated =
        if ran.Reading.bytes <= echo_limit then (ran.Reading.value, false)
        else
          match ran.Reading.value with
          | `List items -> (`List (List.filteri (fun i _ -> i < 5) items), true)
          | _ -> (`Null, true)
      in
      Ok
        P.
          {
            script = args.script;
            value;
            records = ran.Reading.records;
            bytes = ran.Reading.bytes;
            elapsed_ms = ran.Reading.elapsed_ms;
            truncated;
          })

(* extr-lslp: every script of the playbook is compiled, never called, in a blank page of
   its own that the caller owns for the duration and that is closed after. *)
let playbook_check ?installed t ~owner (args : P.playbook_check_args) =
  let* book = find_playbook ~caps:t.caps ?installed args.playbook in
  match book.Playbook.scripts with
  | [] -> Ok P.{ playbook = args.playbook; scripts = [] }
  | scripts -> (
      let* blank = new_tab t ~owner ~url:None in
      let close () = Eio.Cancel.protect (fun () -> ignore (close t ~owner blank.P.tab)) in
      match
        with_reading t ~access:Act ~owner blank.P.tab (fun _ browser ->
            let rec go acc = function
              | [] -> Ok (List.rev acc)
              | (script : Playbook.script) :: rest -> (
                  match Reading.script_syntax browser script with
                  | Error failure -> Error failure
                  | Ok verdict ->
                      go
                        (P.
                           {
                             script = script.Playbook.name;
                             ok = verdict = None;
                             error = verdict;
                           }
                        :: acc)
                        rest)
            in
            go [] scripts)
      with
      | exception exn ->
          close ();
          raise exn
      | Error failure ->
          close ();
          Error failure
      | Ok verdicts ->
          close ();
          Ok P.{ playbook = args.playbook; scripts = verdicts })

let report t : P.status_result =
  let chrome = Chrome.status t.chrome in
  {
    generation = chrome.generation;
    tabs = { open_ = open_tabs t; cap = t.cap };
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
    | `Running -> Ox_app.Status.Ok
    | _ -> Ox_app.Status.Degraded "Chrome restarting"
  in
  Ox_app.Status.make
    ~details:[ ("open", string_of_int (open_tabs t)); ("cap", string_of_int t.cap) ]
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
            List.fold_left
              (fun found (tab : tab) ->
                if
                  match frame with
                  | Some frame -> tab.main_frame = Some frame
                  | None -> session <> None && tab.session = session
                then Some tab
                else found)
              None (live_tabs t)
          in
          Option.iter
            (fun (tab : tab) ->
              let mime =
                if String.ends_with ~suffix:".pdf" (String.lowercase_ascii suggested_name)
                then "application/pdf"
                else "application/octet-stream"
              in
              if
                not
                  (List.exists
                     (fun (download : P.download_info) -> download.id = id)
                     tab.downloads)
              then (
                tab.downloads <-
                  P.{ id; suggested_name; mime; state = "in_progress"; path = None }
                  :: tab.downloads;
                Hashtbl.replace t.downloads_by_guid id (key tab.handle)))
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
                (Option.map
                   (fun entry -> entry.tab)
                   (Keys.find_opt handle (snapshot t).entries)))
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
      iter_tabs t (fun (tab : tab) ->
          if tab.session = Some session then Reading.observe tab.reading ~at:(now t) json));
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
      iter_tabs t (fun (tab : tab) ->
          if tab.session = text "sessionId" json then
            match (text "type" params, text "message" params) with
            | Some kind, Some message ->
                let dialog =
                  P.
                    {
                      kind = enum P.Dialog_kind.of_string kind;
                      message;
                      default_prompt = text "defaultPrompt" params;
                    }
                in
                tab.dialog <- Some dialog;
                List.iter (fun notify -> notify dialog) tab.dialog_listeners
            | _ -> ())
  | Some "Page.javascriptDialogClosed", _ ->
      iter_tabs t (fun (tab : tab) ->
          if tab.session = text "sessionId" json then tab.dialog <- None)
  | Some "Page.frameNavigated", Some params -> (
      (* svc-hi4f: a main-frame navigation is what clears the tab's snapshot and what an
          action's watch counts; a subframe's is neither. *)
      let main_frame =
        match member "frame" params with
        | Some frame -> text "parentId" frame = None
        | None -> false
      in
      iter_tabs t (fun (tab : tab) ->
          if main_frame && tab.session = text "sessionId" json then (
            tab.main_frame <- Option.bind (member "frame" params) (text "id");
            tab.snapshot <- None;
            tab.navigations <- tab.navigations + 1;
            tab.page_loading <- true));
      match text "sessionId" json with
      | Some session ->
          iter_tabs t (fun (tab : tab) ->
              if tab.session = Some session && tab.loading then tab.navigated <- true)
      | None -> ())
  | Some (("Page.loadEventFired" | "Page.domContentEventFired") as event), Some params
    -> (
      match text "sessionId" json with
      | None -> ()
      | Some session ->
          iter_tabs t (fun (tab : tab) ->
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
                  List.iter (fun resolve -> Eio.Promise.resolve resolve ()) pending))))
  | _ -> ()

let create ~sw ~cap ~tombstone_s ?download_dir ?(idle = Ox.Duration.minutes 30)
    ?(unclaimed = Ox.Duration.hours 1) (deps : 'clock deps) =
  (* ^nactor-8z1n: the registry's bookkeeping is one actor's state, folded by [fold], for
     as long as the switch lives. A handler that raises fails the switch. *)
  let ledger =
    Ox.Actor.create ~sw ~init:empty_ledger
      ~handle:
        (fold
           ~fresh:(fun () -> handle ~caps:deps.caps)
           ~logger:deps.logger ~tombstone_s
           ~generation:(fun () -> Chrome.generation deps.chrome))
      ()
  in
  let t =
    {
      chrome = deps.chrome;
      caps = deps.caps;
      now = (fun () -> Eio.Time.now deps.clock);
      sleep = (fun seconds -> Eio.Time.sleep deps.clock seconds);
      await_load =
        (fun promise ->
          Ox.Timeout.timeout ~clock:deps.clock (Ox.Duration.seconds 30) (fun () ->
              Eio.Promise.await promise;
              Ok ()));
      (* hand-lmd5: the handoff deadline, measured by the service clock and cancelled —
         not raced — when it runs out, so the restore of {!handoff} still runs. *)
      await_handoff =
        (fun timeout promise ->
          Ox.Timeout.timeout ~clock:deps.clock timeout (fun () ->
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
      idle = Ox.Duration.to_seconds_float idle;
      unclaimed = Ox.Duration.to_seconds_float unclaimed;
      started = Eio.Time.now deps.clock;
      ledger;
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
                      | Ox_rpc.Correlator.Message json ->
                          inspect t json;
                          notifications ()
                      | Ox_rpc.Correlator.Closed _ -> `Stop_daemon
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
                        Ox_observability.Logger.warn t.logger
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
            List.iter
              (fun (tab : tab) ->
                if tab.generation = generation then
                  disappear t tab (disposition "browser_lost"))
              (live_tabs t)
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
        List.iter
          (fun (tab : tab) ->
            if P.Origin.to_string tab.origin = "agent" then
              ignore
                (cdp_call cdp "Target.closeTarget" (obj [ ("targetId", str tab.id) ])))
          (live_tabs t))

let text = read_text
