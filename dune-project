(lang dune 3.21)

(generate_opam_files true)

(name leash)

(package
 (name leash)
 (synopsis "Leash: a local browser service for coding agents")
 (description
  "Leash owns one headed Chrome on a dedicated profile, exposes tabs to agents over a private Unix socket, and drives a tab toward a goal with the JEV decision model.")
 (depends
  (ocaml (>= 5.4.0))
  (dune (>= 3.21))
  (eta (>= 0.1.0))
  eta_ai
  eta_ai_openrouter
  eta_eio
  eta_http
  eta_http_eio
  eta_observability
  eta_otel_eio
  eta_schema
  eta_schema_yojson
  eta_stream
  (eio (>= 1.0))
  eio_main
  cmdliner
  yojson
  (toml (>= 7.0))
  (alcotest :with-test)))
