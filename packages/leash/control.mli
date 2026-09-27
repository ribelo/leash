type t
(** One-request private control socket. *)

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Eta_app.Status.t list;
  models_status : unit -> Protocol.models_status;
      (** L19: the models section [status] reports, read live from the models service. *)
  fs : Eio.Fs.dir_ty Eio.Path.t;
  net : 'net Eio.Net.ty Eio.Resource.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
}

val create :
  ?model:string ->
  ?decide:
    (deadline:Eta.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  sw:Eio.Switch.t ->
  runtime_dir:string ->
  ('clock, 'net) deps ->
  (t, Eta_ipc.Listener.error) result
(** [decide] is the drive's production Decide, {!Models.decide} in the program that owns
    the models service; a listener created without one refuses every drive with
    [model-unavailable] (L19). *)

val budget : (Protocol.request, string) result -> Eta.Duration.t option
(** The handler budget per decoded command. [new] with a url and [nav] outlast the
    registry's 30-second load wait (chrome-qnul, chrome-1yn9); a [handoff] outlasts its
    own deadline, {!Tabs.handoff_timeout}, plus a margin, so the listener never cancels
    the handler at the instant the handoff is due to answer [timeout] (hand-lmd5);
    everything else stays at one second. *)

val status : t -> Eta_app.Status.t

val report :
  ?models_status:(unit -> Protocol.models_status) -> Tabs.t -> Protocol.status_result
(** [Tabs.report] plus the models section when a models service is given; without one the
    reply carries [models: null] (L19). *)

val dispatch :
  ?model:string ->
  ?decide:
    (deadline:Eta.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?models_status:(unit -> Protocol.models_status) ->
  Tabs.t ->
  Protocol.request ->
  Protocol.reply

val decode : string -> (Protocol.request, string) result

val handle :
  ?model:string ->
  ?decide:
    (deadline:Eta.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?models_status:(unit -> Protocol.models_status) ->
  Tabs.t ->
  string ->
  string
