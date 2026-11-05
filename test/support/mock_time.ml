(* etagap-mono-advance: see the interface. *)
let advance env duration =
  let mono = env#mono_clock in
  let span =
    Mtime.Span.of_uint64_ns
      (Int64.mul (Int64.of_int (Ox.Duration.to_ms duration)) 1_000_000L)
  in
  (match Mtime.add_span (Eio.Time.Mono.now mono) span with
  | Some later -> Eio_mock.Clock.Mono.set_time mono later
  | None -> invalid_arg "Mock_time.advance: monotonic time overflow");
  Ox_test.advance env#clock duration

let mono_seconds clock =
  Int64.to_float (Mtime.to_uint64_ns (Eio.Time.Mono.now clock)) /. 1e9
