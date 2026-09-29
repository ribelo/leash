(* svc-f4op: optional OTLP exporter shares the Door's one logger. The exporter's
   reporter is added before that logger is built; never create another logger here. *)
let create ~caps ~sw ~net ~clock ~endpoint ~headers : Ox_app.telemetry =
  let http = Ox_http.Client.create ~sw ~net ~clock ~tls:(Ox_http.Client.tls ()) () in
  match
    Ox_otel.create ~caps ~sw ~clock ~http_client:http ~endpoint ~service_name:"leash"
      ~headers ()
  with
  | Error error ->
      invalid_arg (Format.asprintf "OTLP configuration: %a" Ox_otel.pp_error error)
  | Ok exporter ->
      (* The exporter owns its worker lifecycle on the Door switch. *)
      {
        reporters = [ Ox_otel.reporter exporter ];
        span_ids = Some (Ox_otel.span_ids exporter);
      }
