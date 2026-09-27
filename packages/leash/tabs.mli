type t
(** Browser-generation tab registry. Handles never name a tab in a later generation.

    A tab enters the registry because Leash created it ({!new_tab}) or because Chrome
    reported the target: a tab opened in the Chrome UI is human-origin and unowned, and a
    page's popup belongs to whoever owns the tab that opened it (own-c0cl own-ehqa). What
    its first report decided is what it stays — origin and owner state are never rewritten
    — and a target destroyed without Leash closing it leaves a [closed_externally]
    tombstone (own-teh1). A discovered tab is listed, claimed, released, and closed with
    no page session at all; the first command that needs its page uses the session Chrome
    attached it under, or asks Chrome to attach. *)

(** Who a tab belongs to (ADR-0005): [Unowned] from the moment it appears unclaimed — a
    human's, or one an agent released — [Owned] by whoever created or claimed it, and
    [With_human] while a handoff has it (milestone 4). *)
type owner_state = Unowned | Owned of Protocol.Owner.t | With_human of Protocol.Owner.t

(** The command classes the one authorization function distinguishes: [Act] is everything
    that touches the page ([nav], [snap], [text], [eval], [shot], [debug], [wait],
    [click], [fill], [press], [select], [scroll]), [Resume] is the human's answer to a
    handoff, and only [Close] and [Release] can be forced. *)
type access = Act | Dialog | Close | Release | Claim | Resume

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
    - [Resume] requires [With_human] and nothing else: the human usually asks from a
      terminal that is not the owner's, and a resume only ever gives the tab back to its
      owner (hand-0sja); a tab nobody waits on is [no-handoff] (hand-szz7).
    - [force] is honoured only for [Close] and [Release], and then allows the command
      whatever the state and whoever calls: it is the human's override for an agent that
      died without releasing, and the registry logs every use of it (own-0pnk). *)

type 'clock deps = {
  chrome : Chrome.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
  desktop : Desktop.t;
      (** The human-facing steps {!handoff} runs (hand-04rb hand-phof). *)
}

val create :
  sw:Eio.Switch.t ->
  cap:int ->
  tombstone_s:int ->
  ?idle:Eta.Duration.t ->
  ?unclaimed:Eta.Duration.t ->
  'clock deps ->
  t
(** [idle] and [unclaimed] are the two expiry durations (own-vhqo). They default to the
    ADR's thirty minutes and one hour, and they are what the [expires] of every
    {!Protocol.tab_info} this registry reports counts down to. *)

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
    populated; a load that does not complete within 30 seconds is [`timeout], as [nav].
    The page session Chrome hands back gets the domains reading, action-time revalidation,
    focus emulation, and the debug ring need, best effort, before the load starts
    (tab-bw4j tab-8la3). *)

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
  reason:string ->
  Protocol.Handle.t ->
  (Protocol.tab_info, Protocol.error) result
(** hand-nisr hand-lz3p: moves the caller's tab to [With_human] holding the reason the
    human is shown and the promise a blocked request awaits, after which every command on
    it is refused with [with-human] — the owner's included — until {!resume}. This is
    {!handoff} without its wait, for a caller that only needs the state.

    A tab handed over here is [With_human] with nobody awaiting it unless the caller keeps
    the wait itself, so the {!handoff} command is the normal way in. hand-len8: the
    transition leaves the idle clock where it was — a handoff is not an owner action — and
    [With_human] is exempt from stage 1 anyway. *)

val handoff :
  t ->
  owner:Protocol.Owner.t ->
  reason:string ->
  timeout_s:int option ->
  Protocol.Handle.t ->
  (Protocol.handoff_result, Protocol.error) result
(** hand-lz3p hand-lmd5 hand-yytf: the handoff command: hands the caller's tab to the
    human and blocks until the handoff ends.

    - {!resume}, by anyone (hand-0sja), hands the tab back to its owner and answers with
      the page's current url and title.
    - The deadline (hand-lmd5), {!handoff_timeout} with the caller's [timeout_s], ends the
      wait with [`timeout] and restores [Owned] by the agent that handed the tab over. It
      is the request's own, so the human-facing steps it ran first count against it.
    - The caller's own cancellation — the control listener cancels a handler whose client
      disconnected — restores [Owned] the same way.
    - A tab that leaves the registry while the request waits ends it with the disposition
      that closed it: [tab-gone] with [browser_lost] for a browser loss (hand-yytf).
    - A forced {!release} or {!close} of the tab the human holds ends it at once, not at
      the deadline (own-0pnk): the release answers [not-owner] and leaves the tab unowned
      with no reason, the close answers [tab-gone] with its disposition.
    - A later [resume] finds nothing to resume: [no-handoff] (hand-szz7).

    Handing over a tab the caller does not own is [not-owner], and one that is already
    with the human is [with-human] (hand-beip).

    hand-04rb hand-phof hand-rg9h: once the tab is [With_human] the human-facing steps run
    — [Target.activateTarget] for the tab, the configured focus command, and the
    configured notification, whose Done action is a [resume]. They are best effort on a
    switch of their own, which stops the notifier when the handoff ends by any path: each
    step that fails is a log line and a warning the successful reply carries in
    [warnings], and an unanswered handoff carries them in the [timeout] error's
    [detail.warnings]. None of them fails the handoff. *)

val handoff_timeout : int option -> Eta.Duration.t
(** hand-lmd5: the deadline a handoff runs on: the caller's [timeout_s], or the contract's
    fifteen minutes when it names none. [Control.budget] derives the handler's budget from
    this same function. *)

val resume :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.Handle.t ->
  (Protocol.resumed_result, Protocol.error) result
(** hand-0sja hand-szz7: the human's signal, from any terminal and by any caller: the tab
    goes back to the owner it was handed off from and the request that waited on it is
    answered with the page. The resume resets the tab's idle clock, so the work the human
    just did does not expire the agent's tab a moment later. A tab nobody is waiting on —
    whether it was never handed over or its handoff already ended — is [no-handoff]; a
    tombstoned handle still answers [tab-gone] like every other command. *)

val release :
  t ->
  owner:Protocol.Owner.t ->
  ?force:bool ->
  Protocol.Handle.t ->
  (Protocol.released_result, Protocol.error) result
(** own-2zs7 own-0pnk: makes the caller's tab unowned without closing it, so the page
    stays up for another agent or the human to take; another agent's tab is [not-owner],
    and [--force] releases any — including one the human holds — and is logged. hand-lz3p:
    a forced release of a tab a handoff is waiting on ends that handoff at once — the
    waiting request answers [not-owner] and the tab is left unowned, with no reason and
    nothing to resume — so nothing waits out a deadline for a tab it no longer owns. *)

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
(** own-82jd own-c0cl: without [all], only the caller's tabs — [Owned] by it and the one
    the human is holding for it; with [all], every tab with its origin, state, and owner,
    the ones Leash discovered from Chrome's target stream included. *)

type idleness = {
  handle : Protocol.Handle.t;
  origin : Protocol.Origin.t;
  owner_state : owner_state;
  idle_for_s : float;
      (** seconds since the last action this tab's owner was allowed to take on it *)
  unowned_for_s : float option;
      (** seconds since it became unowned; [None] while it is owned *)
}
(** One tab's expiry facts (own-uo77 own-hslp own-ay3s): what the sweep policy decides on,
    with the registry's own notion of who owns the tab. *)

type sweep_step =
  | Release_idle
  | Close_idle
  | Keep_idle
      (** What one expiry sweep may do with one tab (ADR-0005): release it, close it, or
          leave it. *)

val idleness : t -> idleness list
(** Every live tab's facts, in handle order, for the caller's policy. *)

val sweep : t -> decide:(idleness -> sweep_step) -> (Protocol.Handle.t * sweep_step) list
(** own-uo77 own-hslp own-2zpi own-nbwk: one expiry pass. Each tab's decision is taken and
    applied with that tab's lock held, so a claim or an action that lands while the sweep
    runs is not overrun: [Release_idle] sets an owned tab unowned without closing it and
    starts its unclaimed clock; [Close_idle] closes an unowned tab of [Agent] origin with
    disposition [closed_by_ttl]; and a tab the human holds, like a human's own tab, is
    never closed. Returns the tabs it acted on, in handle order. *)

val stop : t -> unit
