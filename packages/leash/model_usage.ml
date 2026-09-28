(* extr-5x9e: per-run billing follows child verifier fibers but never leaks into
   other runs. The callback mutates a run-local ledger without yielding. *)
type event = Start of string | Reported of string * float option

let key = Eio.Fiber.create_key ()
let binding () = try Eio.Fiber.get key with Effect.Unhandled _ -> None

let with_meter meter fn =
  match
    try
      ignore (Eio.Fiber.get key);
      true
    with Effect.Unhandled _ -> false
  with
  | true -> Eio.Fiber.with_binding key meter fn
  | false -> fn () (* pure loop unit tests do not run under an Eio scheduler *)

let active () = Option.is_some (binding ())
let emit event = match binding () with Some meter -> meter event | None -> ()
let start kind = emit (Start kind)
let report kind cost = emit (Reported (kind, cost))
