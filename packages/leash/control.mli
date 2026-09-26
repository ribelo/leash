type t
(** One-request private control socket. *)

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Eta_app.Status.t list;
  fs : Eio.Fs.dir_ty Eio.Path.t;
  net : 'net Eio.Net.ty Eio.Resource.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
}

val create :
  sw:Eio.Switch.t ->
  runtime_dir:string ->
  ('clock, 'net) deps ->
  (t, Eta_ipc.Listener.error) result

val status : t -> Eta_app.Status.t
val dispatch : Tabs.t -> Protocol.request -> Protocol.reply
val decode : string -> (Protocol.request, string) result
val handle : Tabs.t -> string -> string
