type t
(** Browser-generation tab registry. Handles never name a tab in a later generation. *)

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
(** With a url, the tab's document is loaded before the reply (chrome-qnul), so [title] is
    populated; a load that does not complete within 30 seconds is [`timeout], as [nav]. A
    created tab also gets focus emulation (tab-8la3) and the DOM agent enabled (tab-bw4j),
    best effort, once its document is there. *)

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

val close :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.Handle.t ->
  (Protocol.closed_result, Protocol.error) result

val list : t -> owner:Protocol.Owner.t -> all:bool -> Protocol.list_result
val stop : t -> unit
