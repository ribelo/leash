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
    populated; a load that does not complete within 30 seconds is [`timeout], as [nav]. *)

val snap :
  t ->
  owner:Protocol.Owner.t ->
  Protocol.snap_args ->
  (Protocol.snapshot, Protocol.error) result

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
