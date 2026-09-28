(* hard-6eei hard-dljv hard-s719 hard-t6cq hard-owci: the one tab wait race.
   Subscribe before starting work, then check again so an opening between those steps
   cannot be lost. Capture the opening, not a later (possibly closed) tab state. *)
type t = {
  current : unit -> Protocol.dialog option;
  subscribe : (Protocol.dialog -> unit) -> unit -> unit;
}

let first tab work =
  let promise, resolve = Eio.Promise.create () in
  let release =
    tab.subscribe (fun dialog -> ignore (Eio.Promise.try_resolve resolve dialog))
  in
  Fun.protect ~finally:release (fun () ->
      match tab.current () with
      | Some dialog -> `Dialog dialog
      | None ->
          Eio.Fiber.first
            (fun () -> `Value (work ()))
            (fun () -> `Dialog (Eio.Promise.await promise)))
