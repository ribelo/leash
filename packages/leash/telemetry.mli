val create :
  sw:Eio.Switch.t ->
  net:_ Eio.Net.t ->
  clock:_ Eio.Time.clock ->
  endpoint:string ->
  headers:(string * string) list ->
  Ox_app.telemetry
(** svc-f4op: start one optional OTLP reporter for the Door's logger. [endpoint] and
    [headers] are validated by Config before this is called; the exporter borrows [sw].
    The exporter handles its worker lifecycle when the switch closes. *)
