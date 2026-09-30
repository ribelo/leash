type t
(** One-request private control socket. *)

type caps = < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network >

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Ox_app.Status.t list;
  models_status : unit -> Protocol.models_status;
      (** L19: the models section [status] reports, read live from the models service. *)
  fs : Eio.Fs.dir_ty Eio.Path.t;
  net : 'net Eio.Net.ty Eio.Resource.t;
  clock : 'clock Eio.Time.clock;
  logger : Ox_observability.Logger.t;
  caps : caps;
}

val create :
  ?model:string ->
  ?levels:Run.levels ->
  ?decide:
    (deadline:Ox.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?text_helper:(unit -> Text_helper.t) ->
  ?installed:Playbook.loaded list ->
  ?chrome_pid:(unit -> int option) ->
  sw:Eio.Switch.t ->
  path:string ->
  ('clock, 'net) deps ->
  (t, Ox_ipc.Listener.error) result
(** svc-o4wt: [path] is the configured control socket — [control.socket], default
    ["$XDG_RUNTIME_DIR/leash/control.sock"] — and the listener verifies the directory it
    sits in and refuses a second instance on the same path.

    [decide] is the drive's production Decide, {!Models.decide} in the program that owns
    the models service; a listener created without one refuses every drive with
    [model-unavailable] (L19). [text_helper] is the drive's text helper — production
    passes a thunk over {!Models.text_helper}, so every drive gets the fresh instance its
    reuse memo belongs to (drive-ls3c); without one a [type_text] step refuses.

    L31 run-7blx run-4mzm: [levels] are the run's upper levels — production passes
    {!Models.levels}, one System One client for the playbook level, the procedure level
    and the judgment score, whose planner is L31's stub; without one every upper-level
    call refuses with [model-unavailable]. [installed] hands a listener the playbooks a
    run works from, which is how a scripted test runs a known playbook without touching
    the operator's XDG configuration; production leaves it [None] and the run loads them.
*)

val policy : Ox_ipc.Listener.policy
(** The listener's policy: 1 MiB request lines, 8 MiB replies (a 1 MiB response body,
    escaped), and 64 concurrent requests (hard-b1na) — up from ox_ipc's default of 16, so
    that long waits on many tabs never queue anyone else. *)

val budget : (Protocol.request, string) result -> Ox.Duration.t option
(** The handler budget per decoded command. [new] with a url and [nav] outlast the
    registry's 30-second load wait (chrome-qnul, chrome-1yn9); a [handoff] outlasts its
    own deadline, {!Tabs.handoff_timeout}, plus a margin, so the listener never cancels
    the handler at the instant the handoff is due to answer [timeout] (hand-lmd5); a
    [wait] gets its own [timeout_ms] — up to an hour — plus a second (hard-sr9v);
    everything else stays at one second. *)

val status : t -> Ox_app.Status.t

val report :
  ?models_status:(unit -> Protocol.models_status) ->
  ?chrome_pid:(unit -> int option) ->
  Tabs.t ->
  Protocol.status_result
(** [Tabs.report] plus the models section when a models service is given; without one the
    reply carries [models: null] and [key_present: false] (L19, daily-smli). [chrome_pid]
    is consulted only while Chrome is running; a relaunch reports [pid: null]. *)

val dispatch :
  ?model:string ->
  ?levels:Run.levels ->
  ?decide:
    (deadline:Ox.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?text_helper:(unit -> Text_helper.t) ->
  ?installed:Playbook.loaded list ->
  ?models_status:(unit -> Protocol.models_status) ->
  ?chrome_pid:(unit -> int option) ->
  Tabs.t ->
  Protocol.request ->
  Protocol.reply

val decode : string -> (Protocol.request, string) result

val handle :
  ?model:string ->
  ?levels:Run.levels ->
  ?decide:
    (deadline:Ox.Duration.t ->
    Jev_request.request ->
    (Jev_request.decision, Protocol.error) result) ->
  ?text_helper:(unit -> Text_helper.t) ->
  ?installed:Playbook.loaded list ->
  ?models_status:(unit -> Protocol.models_status) ->
  ?chrome_pid:(unit -> int option) ->
  ?logger:Ox_observability.Logger.t ->
  Tabs.t ->
  string ->
  string
