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
    so every input dispatch is awaited only briefly: when the page still answers
    afterwards the input was delivered and the action proceeds to the popup it opened
    (own-ehqa). A page that answers nothing is [browser-unavailable], unless the browser
    no longer knows the target: then the handler closed the tab, and the action reports
    [tab-gone] with [closed_externally] (own-teh1). [action_result.snapshot] is always
    [null] in this version: settling takes no snapshot, and a caller that wants a fresh
    table asks for one with [snap]. The registry runs actions under the tab's lock, so one
    tab's actions proceed in arrival order while another tab's are unaffected (tab-hxld).
*)

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
  dialog : unit -> Protocol.dialog option;
  all_tabs : unit -> (Protocol.tab_info * string option) list;
      (** Every tab in the registry, all owners, ordered by handle, paired with the target
          id of the tab that opened it when Chrome reports one ([openerId]): the action's
          own popups are the fresh entries whose opener is its own target id. *)
}

val click :
  cdp:Cdp.t ->
  tab ->
  Protocol.click_args ->
  (Protocol.action_result, Protocol.error) result

val fill :
  cdp:Cdp.t ->
  tab ->
  Protocol.fill_args ->
  (Protocol.action_result, Protocol.error) result

val press :
  cdp:Cdp.t ->
  tab ->
  Protocol.press_args ->
  (Protocol.action_result, Protocol.error) result
(** With an index the row is revalidated and focused first; without one the key goes to
    the page, and only the snapshot's currency and the loader id are checked. *)

val select :
  cdp:Cdp.t ->
  tab ->
  Protocol.select_args ->
  (Protocol.action_result, Protocol.error) result
(** The row must be a native select (role [combobox] or [listbox]); [option] is its index
    in the observed option order, and an index the select does not have is
    [invalid-request]. *)

val scroll :
  cdp:Cdp.t ->
  tab ->
  Protocol.scroll_args ->
  (Protocol.action_result, Protocol.error) result
(** Without an index the page's viewport is scrolled from its center; with one the row is
    revalidated and the wheel is aimed at the row, which is what scrolls its nearest
    scrollable ancestor. [scroll] carries no snapshot id in [docs/protocol.md], so an
    indexed scroll revalidates against the tab's current snapshot. *)
