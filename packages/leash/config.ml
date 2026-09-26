open Eta_schema

type chrome = { binary : string; profile_dir : string; workspace : string }
type tabs = { cap : int }
type expiry = { idle_s : int; unclaimed_s : int; tombstone_s : int }
type models = { api_key : string option; jev_model : string; text_model : string }
type t = { chrome : chrome; tabs : tabs; expiry : expiry; models : models }

let positive name schema =
  refine ~name (fun n -> if n > 0 then [] else [ issue "must be positive" ]) schema

let nonempty name schema =
  refine ~name
    (fun s -> if String.trim s <> "" then [] else [ issue "must not be empty" ])
    schema

let chrome_schema =
  closed
    (record3 ~name:"chrome"
       (fun binary profile_dir workspace -> { binary; profile_dir; workspace })
       (required "binary" (nonempty "binary" string) (fun x -> x.binary))
       (required "profile_dir" (nonempty "profile_dir" string) (fun x -> x.profile_dir))
       (required "workspace" (nonempty "workspace" string) (fun x -> x.workspace))
       ~equal:( = ) ())

let tabs_schema =
  closed
    (record1 ~name:"tabs"
       (fun cap -> { cap })
       (required "cap" (positive "cap" int) (fun x -> x.cap))
       ~equal:( = ) ())

let expiry_schema =
  closed
    (record3 ~name:"expiry"
       (fun idle_s unclaimed_s tombstone_s -> { idle_s; unclaimed_s; tombstone_s })
       (required "idle_s" (positive "idle_s" int) (fun x -> x.idle_s))
       (required "unclaimed_s" (positive "unclaimed_s" int) (fun x -> x.unclaimed_s))
       (required "tombstone_s" (positive "tombstone_s" int) (fun x -> x.tombstone_s))
       ~equal:( = ) ())

let models_schema =
  closed
    (record3 ~name:"models"
       (fun api_key jev_model text_model -> { api_key; jev_model; text_model })
       (optional ~secret:true ~env:"OPENROUTER_API_KEY" "api_key" string (fun x ->
            x.api_key))
       (required "jev_model" (nonempty "jev_model" string) (fun x -> x.jev_model))
       (required "text_model" (nonempty "text_model" string) (fun x -> x.text_model))
       ~equal:( = ) ())

let schema =
  closed
    (record4 ~name:"leash-config"
       (fun chrome tabs expiry models -> { chrome; tabs; expiry; models })
       (required "chrome" chrome_schema (fun x -> x.chrome))
       (required "tabs" tabs_schema (fun x -> x.tabs))
       (required "expiry" expiry_schema (fun x -> x.expiry))
       (required "models" models_schema (fun x -> x.models))
       ~equal:( = ) ())

type validation_error = { pointer : string; message : string }

let validate_paths ~fs config =
  let error pointer message = Error [ { pointer; message } ] in
  let check pointer path expected permissions =
    let path = Eio.Path.(fs / path) in
    try
      let stat = Eio.Path.stat ~follow:true path in
      if stat.Eio.File.Stat.kind <> expected then error pointer "wrong file type"
      else if stat.perm land permissions <> permissions then
        error pointer "insufficient permissions"
      else Ok ()
    with Eio.Io _ -> error pointer "path missing or unreadable"
  in
  let ( let* ) = Result.bind in
  let* () = check "/chrome/binary" config.chrome.binary `Regular_file 0o100 in
  let profile = config.chrome.profile_dir in
  let parent = Filename.dirname profile in
  match Eio.Path.kind ~follow:true Eio.Path.(fs / profile) with
  | `Directory -> check "/chrome/profile_dir" profile `Directory 0o700
  | `Not_found -> check "/chrome/profile_dir" parent `Directory 0o300
  | _ -> error "/chrome/profile_dir" "not a directory"
