(** Row actions: the dispatch path of the action commands in [docs/protocol.md].

    Every row action revalidates at action time (tab-bw4j, tab-j1z2): the frame's loader
    id must be unchanged, the row's backend node id must still resolve through
    [DOM.describeNode], its accessible role and name must still be the snapshot's, and
    geometry is read now through [DOM.getContentQuads]. Scrolling and animation are never
    staleness (ADR-0004), so a snapshot stays usable until the next [snap]; only a changed
    loader, a node that no longer resolves, or a different role or name refuse with
    [stale-snapshot]. A row that is disabled, has no layout box, or is covered at its
    click point (hit-tested with [DOM.getNodeForLocation]) refuses with
    [row-not-actionable]. Nothing is ever retried (tab-1lhx), and an open dialog refuses
    every action (tab-60kn).

    Dispatch is trusted CDP input: a click is [Input.dispatchMouseEvent] press and
    release; a fill focuses the node with [DOM.focus], selects its content, inserts text
    with [Input.insertText] and blurs (tab-p3x1); a press is [Input.dispatchKeyEvent] from
    a small key-name table (tab-luo5); a select resolves the native select and sets the
    observed option index (tab-5deq); a scroll is a wheel event one viewport tall at the
    page's center or the row's (tab-8dop). Settlement is bounded (tab-p3x1): after a fill
    into a combobox up to two hundred milliseconds of animation frames polling for visible
    suggestions, otherwise two animation frames bounded by fifty milliseconds. Each action
    replies with the tab's url and title after the action, the dialogs state, and the tabs
    it opened (tab-tm6c). A popup is a tab that was not in the registry when the action
    began, whose Chrome [openerId] is the acted-on tab, and that the caller owns, so
    another agent's concurrent tab is never reported as this caller's (tab-8k2g). Chrome
    withholds the reply of the trusted input that opens a popup (docs/cdp-shapes.md, L10),
    so every input dispatch is settled by whichever comes first: its own reply, the popup
    Chrome reports with this tab as its opener, or this tab's target destroyed (tab-0ohq).
    Nothing has a fixed dispatch bound -- the CDP call's deadline is the only one -- and
    nothing is ever sent twice (tab-1lhx). A page that answers nothing by that deadline is
    [browser-unavailable], unless the browser no longer knows the target: then the handler
    closed the tab, and the action reports [tab-gone] with [closed_externally] (own-teh1).
    [action_result.snapshot] is always [null] in this version: settling takes no snapshot,
    and a caller that wants a fresh table asks for one with [snap]. The registry runs
    actions under the tab's lock, so one tab's actions proceed in arrival order while
    another tab's are unaffected (tab-hxld). *)

type tab = {
  session : string;  (** The tab's flat page session. *)
  target : string;
      (** The tab's Chrome target id: the [openerId] a popup of this tab carries. *)
  handle : Protocol.Handle.t;
  owner : Protocol.Owner.t;
      (** The caller, which a popup must be owned by to be reported. *)
  page : unit -> string * string;
      (** The registry's current url and title for the tab. *)
  refresh : unit -> unit;
      (** Re-read the tab's committed url and document title from Chrome, so a reply after
          a navigation the action caused reports the page rather than the tab strip. *)
  snapshot : unit -> (Protocol.Snapshot_id.t * string * (Protocol.row * int) list) option;
      (** The current snapshot: its id, the loader id it was taken under, and every row
          with the backend node id it came from. *)
  dom_snapshot : unit -> bool;
      (** field-jkx6: true when the current table came from the DOM fallback. Revalidation
          then keeps the loader, disabled and hit-test checks and identifies the row by
          backend node ([DOM.describeNode]) instead of the AX role and name. *)
  popup : Protocol.tab_info -> Protocol.popup_info;
      (** field-drpx: map a freshly opened tab to the popup record the reply reports. *)
  dialog : unit -> Protocol.dialog option;
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
      (** One pending acknowledgement of this tab (tab-0ohq tab-gjo0): taken before a
          trusted input is dispatched and woken by the registry when the popup that input
          opened appears, or when the tab's own target dies. *)
  all_tabs : unit -> (Protocol.tab_info * string option) list;
      (** Every tab in the registry, all owners, ordered by handle, paired with the target
          id of the tab that opened it when Chrome reports one ([openerId]): the action's
          own popups are the fresh entries whose opener is its own target id. *)
  engage : unit -> unit;
      (** Turn the page's focus emulation on for the rest of the operation (tab-8la3,
          chrome-9ex7): called just before the first thing the page can see -- a focus, an
          input, the settle -- and never for a request refused before that. *)
}

val click :
  ?settle_after:bool ->
  cdp:Cdp.t ->
  tab ->
  Protocol.click_args ->
  (Protocol.action_result, Protocol.error) result
(** [settle_after] defaults to true. The operator path settles with {!operator_settle}
    instead, so autocomplete and ordinary input keep the reference bounds (fly-2pn7). *)

val fill :
  ?settle_after:bool ->
  ?check_hit:bool ->
  ?blur_after:bool ->
  cdp:Cdp.t ->
  tab ->
  Protocol.fill_args ->
  (Protocol.action_result, Protocol.error) result
(** [check_hit] additionally resolves and hit-tests the current target before input. The
    operator enables it for fill and select (fly-4lmg). *)

val press :
  cdp:Cdp.t ->
  tab ->
  Protocol.press_args ->
  (Protocol.action_result, Protocol.error) result
(** With an index the row is revalidated and focused first; without one the key goes to
    the page, and only the snapshot's currency and the loader id are checked. *)

val select :
  ?settle_after:bool ->
  ?check_hit:bool ->
  cdp:Cdp.t ->
  tab ->
  Protocol.select_args ->
  (Protocol.action_result, Protocol.error) result
(** The row must be a native select (role [combobox] or [listbox]); [option] is its index
    in the observed option order, and an index the select does not have is
    [invalid-request]. *)

val hover :
  cdp:Cdp.t ->
  tab ->
  Protocol.hover_args ->
  (Protocol.action_result, Protocol.error) result
(** hard-v1gs: the row is revalidated and hit-tested like a click's, then the mouse is
    moved to its point with a single [mouseMoved]; nothing is pressed, and two frames of
    settling let a hover menu open. *)

val check :
  cdp:Cdp.t ->
  tab ->
  Protocol.click_args ->
  (Protocol.action_result, Protocol.error) result
(** field-guda: click the row, following a covering label, and require [checked] to become
    true. Already checked, or a click that does not flip it, is [state-unchanged]. A row
    with no checked state is [row-not-actionable]. *)

val uncheck :
  cdp:Cdp.t ->
  tab ->
  Protocol.click_args ->
  (Protocol.action_result, Protocol.error) result
(** field-guda: the unchecked twin of {!check}. *)

val upload :
  caps:< Ox_caps.Cap.fs_read ; .. > ->
  cdp:Cdp.t ->
  tab ->
  Protocol.upload_args ->
  (Protocol.action_result, Protocol.error) result
(** hard-o3za: sets absolute, readable files on a [file-input] row with
    [DOM.setFileInputFiles]. At most 10 files and 50 MiB (a path that is not an absolute
    readable regular file is [invalid-request], the total [too-large]); the row is
    revalidated as an [<input type=file>] rather than by role and name, and several files
    need [multiple]. Every other action refuses a [file-input] row with
    [row-not-actionable] (hard-2gnf). *)

val scroll :
  cdp:Cdp.t ->
  tab ->
  Protocol.scroll_args ->
  (Protocol.action_result, Protocol.error) result
(** Without an index the page's viewport is scrolled from its center; with one the row is
    revalidated and the wheel is aimed at the row, which is what scrolls its nearest
    scrollable ancestor. [scroll] carries no snapshot id in [docs/protocol.md], so an
    indexed scroll revalidates against the tab's current snapshot. *)

val operator_scroll :
  cdp:Cdp.t -> tab -> down:bool -> (Protocol.action_result, Protocol.error) result
(** fly-2pn7: the operator's page scroll. A wheel of {!Snapshot_source.scroll_delta} CSS
    pixels at (550, 650), the reference's point, not one viewport. *)

val operator_settle :
  cdp:Cdp.t -> tab -> autocomplete:bool -> (unit, Protocol.error) result
(** fly-2pn7: after confirmed input. Autocomplete waits up to 200 ms for a visible option;
    other input waits two frames or 50 ms. A page that stops answering ends the wait, not
    the action. *)
