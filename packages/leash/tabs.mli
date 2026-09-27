type t
(** Browser-generation tab registry. Handles never name a tab in a later generation. *)

(** Who a tab belongs to (ADR-0005): [Unowned] from the moment it appears unclaimed — a
    human's, or one an agent released — [Owned] by whoever created or claimed it, and
    [With_human] while a handoff has it (milestone 4). *)
type owner_state = Unowned | Owned of Protocol.Owner.t | With_human of Protocol.Owner.t

(** The command classes the one authorization function distinguishes: [Act] is everything
    that touches the page ([nav], [snap], [text], [eval], [shot], [debug], [wait],
    [click], [fill], [press], [select], [scroll]), and only [Close] and [Release] can be
    forced. *)
type access = Act | Dialog | Close | Release | Claim

val authorize :
  ?force:bool ->
  access ->
  caller:Protocol.Owner.t ->
  owner_state ->
  (unit, Protocol.error) result
(** own-pmr7 own-0np9 own-7pzw own-0pnk hand-nisr: the one authorization function, applied
    before every tab command.

    - [Act], [Dialog], [Release], and [Close] require that the caller owns the tab:
      [Owned caller] is allowed; [Owned] another's and [Unowned] are [not-owner]; and
      [With_human] is [with-human] whoever asks, the owner included.
    - [Claim] requires [Unowned]; [Owned] and [With_human] are [already-owned].
    - [force] is honoured only for [Close] and [Release], and then allows the command
      whatever the state and whoever calls: it is the human's override for an agent that
      died without releasing, and the registry logs every use of it (own-0pnk). *)

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
}

val create : sw:Eio.Switch.t -> cap:int -> tombstone_s:int -> 'clock deps -> t
val status : t -> Eta_app.Status.t
val report : t -> Protocol.status_result

val waits_for_load : string option -> bool
(** The rule [new] applies (chrome-qnul): a url other than [about:blank] is waited for
    until it has loaded, exactly as {!navigate} does; [None] and [about:blank] reply at
    once. The control listener's handler budget asks the same question. *)

val new_tab :
  t ->
  owner:Protocol.Owner.t ->
  url:string option ->
  (Protocol.tab_info, Protocol.error) result
(** own-6ndc: the tab an agent creates is [Owned] by that agent from the start. With a
    url, the tab's document is loaded before the reply (chrome-qnul), so [title] is
    populated; a load that does not complete within 30 seconds is [`timeout], as [nav]. A
    created tab also gets focus emulation (tab-8la3) and the DOM agent enabled (tab-bw4j),
    best effort, once its document is there. *)

val claim :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.Handle.t ->
  (Protocol.tab_info, Protocol.error) result
(** own-jua9 own-0np9: takes a tab nobody owns for the caller, which is how an agent picks
    up a page the human prepared; a tab someone owns — the caller included — is
    [already-owned] and is left as it was. *)

val hand_over :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.Handle.t ->
  (Protocol.tab_info, Protocol.error) result
(** hand-nisr: moves the caller's tab to [With_human], the state handoff (milestone 4)
    puts a tab in while the human works on it, after which every command on it is refused
    with [with-human]. Milestone 3 has no [handoff] command, so this transition is what
    reaches the state here; milestone 4's [handoff] drives the same transition and adds
    the reason and the promise the blocked request awaits. *)

val release :
  t ->
  owner:Protocol.Owner.t ->
  ?force:bool ->
  Protocol.Handle.t ->
  (Protocol.released_result, Protocol.error) result
(** own-2zs7 own-0pnk: makes the caller's tab unowned without closing it, so the page
    stays up for another agent or the human to take; another agent's tab is [not-owner],
    and [--force] releases any — including one the human holds — and is logged. *)

val close :
  t ->
  owner:Protocol.Owner.t ->
  ?force:bool ->
  Protocol.Handle.t ->
  (Protocol.closed_result, Protocol.error) result
(** own-7pzw own-0pnk: closing a tab the caller owns is idempotent while its tombstone
    lives, another agent's is [not-owner], and a tab the human holds answers [with-human]
    until resume; [--force] closes any tab and is logged. *)

val snap :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.snap_args ->
  (Protocol.snapshot, Protocol.error) result

val text :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.text_args ->
  (Protocol.text_result, Protocol.error) result

val eval :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.eval_args ->
  (Protocol.eval_result, Protocol.error) result

val shot :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.shot_args ->
  (Protocol.shot_result, Protocol.error) result

val debug :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.debug_args ->
  (Protocol.debug_result, Protocol.error) result

val wait :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.wait_args ->
  (Protocol.action_result, Protocol.error) result

val dialog :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.dialog_args ->
  (Protocol.action_result, Protocol.error) result

val click :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.click_args ->
  (Protocol.action_result, Protocol.error) result
(** tab-bw4j tab-j1z2 tab-hxld tab-60kn tab-1lhx tab-tm6c: the row is revalidated at
    action time, the click point hit-tested, and the action dispatched once. *)

val fill :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.fill_args ->
  (Protocol.action_result, Protocol.error) result
(** tab-p3x1 tab-0lax: focus, select, [Input.insertText], blur, then a bounded settle;
    text over 64 KiB is a [too-large] error. *)

val press :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.press_args ->
  (Protocol.action_result, Protocol.error) result
(** tab-luo5: with an index the row is focused first, without one the key goes to the
    page. *)

val select :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.select_args ->
  (Protocol.action_result, Protocol.error) result
(** tab-5deq: a native select's observed option index. *)

val scroll :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.scroll_args ->
  (Protocol.action_result, Protocol.error) result
(** tab-8dop: one viewport, from the page's centre or the row's scrollable ancestor. *)

val navigate :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.Handle.t ->
  string ->
  (Protocol.action_result, Protocol.error) result

val list : t -> owner:Protocol.Owner.t -> all:bool -> Protocol.list_result
(** own-82jd: without [all], only the caller's tabs — [Owned] by it and the one the human
    is holding for it; with [all], every tab with its origin, state, and owner. *)

val stop : t -> unit
