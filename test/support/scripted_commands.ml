type step = Print of string | Exit of int | Failure of string | Block
type t = { mutable scripts : step list list; mutable spawns : string list list }

let make scripts = { scripts; spawns = [] }
let spawns t = List.rev t.spawns

let runner t : Leash.Desktop.runner =
  {
    run =
      (fun ~sw:_ ~argv ~on_line ->
        t.spawns <- argv :: t.spawns;
        match t.scripts with
        | [] -> Error "Scripted_commands: no script left for this command"
        | script :: rest ->
            t.scripts <- rest;
            let rec steps = function
              | [] -> Ok ()
              | Print line :: rest ->
                  on_line line;
                  steps rest
              | Exit 0 :: _ -> Ok ()
              | Exit status :: _ -> Error (Printf.sprintf "exited %d" status)
              | Failure message :: _ -> Error message
              | Block :: _ ->
                  (* The command a handoff waits on forever: the fiber is cancelled, and
                     with it this promise, when the handoff's switch is released. *)
                  let promise, _resolver = Eio.Promise.create () in
                  Eio.Promise.await promise;
                  Ok ()
            in
            steps script);
  }
