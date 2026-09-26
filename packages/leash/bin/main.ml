(* L0 Door placeholder: L1 supplies Config.schema and composes the Services. *)
let config = Eta_schema.record0 ~name:"leash-placeholder" () ~equal:( = ) ()

let () =
  exit
    (Eta_app.run ~name:"leash" ~config
       ~pp_err:(fun _fmt (_ : unit) -> ())
       (fun _env () sw -> Eta_app.serve ~sw ()))
