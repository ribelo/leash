type outcome = Popup | Gone of Protocol.error
type t = { promise : outcome Eio.Promise.t; release : unit -> unit }

let make () =
  let promise, resolver = Eio.Promise.create () in
  ( { promise; release = (fun () -> ()) },
    fun outcome -> ignore (Eio.Promise.try_resolve resolver outcome) )

let first t call =
  Fun.protect ~finally:t.release (fun () ->
      Eio.Fiber.first
        (fun () -> `Reply (call ()))
        (fun () -> `Acknowledged (Eio.Promise.await t.promise)))
