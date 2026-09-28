(* svc-f4op: optional OTLP exporter shares the Door's one logger. The exporter's
   reporter is added before that logger is built; never create another logger here. *)
let create ~sw ~net ~clock ~endpoint ~headers : Eta_app.telemetry =
  let http = Eta_http.Client.create ~sw ~net ~clock ~tls:(Eta_http.Client.tls ()) () in
  match
    Eta_otel.create ~sw ~clock ~http_client:http ~endpoint ~service_name:"leash" ~headers
      ()
  with
  | Error error ->
      invalid_arg (Format.asprintf "OTLP configuration: %a" Eta_otel.pp_error error)
  | Ok exporter ->
      (* The exporter owns its worker lifecycle on the Door switch. *)
      {
        reporters = [ Eta_otel.reporter exporter ];
        span_ids = Some (Eta_otel.span_ids exporter);
      }
