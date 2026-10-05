val create :
  caps:< Ox_caps.Cap.random ; .. > ->
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  clock:_ Eio.Time.clock ->
  endpoint:string ->
  headers:(string * string) list ->
  Ox_app.telemetry
(** svc-f4op: start one optional OTLP reporter for the Door's logger. [endpoint] and
    [headers] are validated by Config before this is called; the exporter borrows [sw].
    The exporter handles its worker lifecycle when the switch closes.

    Suspension: may suspend while starting the switch-owned exporter worker; export I/O
    runs in that worker; configuration-error printer callback invocation is delegated to
    Format.asprintf with Ox_otel.pp_error. Cancellation: propagates from exporter startup
    and switch teardown; configuration-error printer callback invocation is delegated to
    Format.asprintf with Ox_otel.pp_error. Finalizers: sw owns exporter ending with its
    five-second budget. Locking: exporter queue synchronization belongs to Ox_otel.
    Cancellation safety: safe to re-run on a fresh switch after the previous exporter
    ends; do not register duplicate reporters. [Invalid_argument] is raised when Ox_otel
    rejects the endpoint or headers. *)
