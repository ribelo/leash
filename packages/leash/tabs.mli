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

val new_tab :
  t -> owner:Protocol.Owner.t -> url:string -> (Protocol.tab_info, Protocol.error) result

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
