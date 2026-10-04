(* hdoc-ztwo: stdout is docs/help/errors.md. Do not edit that file by hand. *)

open Ox_caps

let run ~(caps : < Cap.stdout ; .. >) () =
  Cap_stdlib.print_string ~caps Leash.Protocol.Error_code.topic_markdown

let () =
  let caps = (Ox_caps_door.powerbox () :> Cap.stdout) in
  run ~caps ()
