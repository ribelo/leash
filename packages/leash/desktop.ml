(** The human-facing side of a handoff: the two best-effort desktop steps that raise the
    live view and tell the human what is asked (hand-04rb hand-phof hand-rg9h). The {!mli}
    is the contract; this file is how a command is rendered, bounded and run. *)

(* hand-rg9h: five seconds is both a command's deadline for the steps a handoff waits on
   and the retirement grace of every child it starts. *)
let step_timeout = Eta.Duration.seconds 5
let retirement_grace = Eta.Duration.seconds 5

type runner = {
  run :
    sw:Eio.Switch.t ->
    argv:string list ->
    on_line:(string -> unit) ->
    (unit, string) result;
}

let process_runner ~clock ~mgr =
  let run ~sw ~argv ~on_line =
    try
      match
        Eta_process.Child.spawn ~sw ~clock ~mgr ~argv ~grace:retirement_grace
          ~stdout:Eta_process.Child.Pipe ~fds:[] ()
      with
      | Error (`Invalid_fd descriptor) ->
          Error (Printf.sprintf "invalid descriptor %d" descriptor)
      | Error (`Duplicate_fd descriptor) ->
          Error (Printf.sprintf "duplicate descriptor %d" descriptor)
      | Ok child -> (
          (match Eta_process.Child.stdout child with
          | None -> ()
          | Some source -> (
              let lines = Eio.Buf_read.of_flow ~max_size:(64 * 1024) source in
              try
                let rec read () =
                  on_line (Eio.Buf_read.line lines);
                  read ()
                in
                read ()
              with End_of_file -> ()));
          match Eta_process.Child.await child with
          | Exited 0 -> Ok ()
          | Exited status -> Error (Printf.sprintf "exited %d" status)
          | Signaled signal -> Error (Printf.sprintf "killed by signal %d" signal))
    with
    | Eio.Cancel.Cancelled _ as cancelled -> raise cancelled
    (* hand-rg9h: Eio resolves the executable — the argv head, through PATH — before the
       process manager is asked to spawn it, so a command that is not installed fails
       here, with the name the config gave. *)
    | Eio.Io (Eio.Process.E (Eio.Process.Executable_not_found name), _) ->
        Error (Printf.sprintf "%s: executable not found" name)
    | Unix.Unix_error (code, _, argument) ->
        if argument = "" then Error (Unix.error_message code)
        else Error (Printf.sprintf "%s: %s" argument (Unix.error_message code))
    | ex -> Error (Printexc.to_string ex)
  in
  { run }

type commands = { focus_command : string list; notify_command : string list }
type context = { tab : Protocol.Handle.t; reason : string; url : string; title : string }

type t = {
  focus : context -> (unit, string) result;
  notify : sw:Eio.Switch.t -> context -> on_done:(unit -> unit) -> (unit, string) result;
}

(* A configuration comes from a file, so its values are untrusted text: a NUL byte cannot
   reach an argv element (the kernel would truncate it there), and it is dropped rather
   than handed to [execve]. *)
let clean value = String.concat "" (String.split_on_char '\000' value)

let contains haystack needle =
  let hay = String.length haystack and width = String.length needle in
  let rec at start index =
    index = width || (haystack.[start + index] = needle.[index] && at start (index + 1))
  in
  let rec scan start = start + width <= hay && (at start 0 || scan (start + 1)) in
  width = 0 || scan 0

(* hand-rg9h: one pass, literal substitution. A value is inserted as it is and never read
   back as a template, so a reason that says "{tab}" stays a reason. A placeholder with no
   value is left as written rather than silently dropped. *)
let render values element =
  let buffer = Buffer.create (String.length element + 8) in
  let length = String.length element in
  let rec scan index =
    if index < length then
      if element.[index] <> '{' then (
        Buffer.add_char buffer element.[index];
        scan (index + 1))
      else
        match String.index_from_opt element index '}' with
        | Some stop -> (
            let name = String.sub element (index + 1) (stop - index - 1) in
            match List.assoc_opt name values with
            | Some value ->
                Buffer.add_string buffer value;
                scan (stop + 1)
            | None ->
                Buffer.add_char buffer element.[index];
                scan (index + 1))
        | None ->
            Buffer.add_char buffer element.[index];
            scan (index + 1)
  in
  scan 0;
  Buffer.contents buffer

let values context =
  [
    ("tab", clean (Protocol.Handle.to_string context.tab));
    ("reason", clean context.reason);
    ("url", clean context.url);
    ("title", clean context.title);
  ]

(* hand-04rb: the managed Chrome runs with [--class=leash] (chrome.ml), and the window the
   focus command names is the one with that app id; a title that says leash is the
   fallback the ADR names, for a compositor that reports no app id. *)
let niri_windows = [ "niri"; "msg"; "--json"; "windows" ]

let chrome_window = function
  | `List windows -> (
      let field name = function
        | `Assoc fields -> (
            match List.assoc_opt name fields with
            | Some (`String value) -> Some value
            | _ -> None)
        | _ -> None
      in
      let id = function
        | `Assoc fields -> (
            match List.assoc_opt "id" fields with Some (`Int id) -> Some id | _ -> None)
        | _ -> None
      in
      let by_app =
        List.find_opt (fun window -> field "app_id" window = Some "leash") windows
      in
      let by_title =
        List.find_opt
          (fun window ->
            match field "title" window with
            | Some title -> contains (String.lowercase_ascii title) "leash"
            | None -> false)
          windows
      in
      match by_app with Some window -> id window | None -> Option.bind by_title id)
  | _ -> None

let create ~clock ~runner commands =
  let run_bounded argv ~on_line =
    match
      Eta.Timeout.timeout ~clock step_timeout (fun () ->
          Eio.Switch.run (fun sw -> runner.run ~sw ~argv ~on_line)
          |> Result.map_error (fun message -> `Failed message))
    with
    | Ok () -> Ok ()
    | Error (`Failed message) -> Error message
    | Error `Timeout -> Error "the command did not finish within five seconds"
  in
  let window_id () =
    let output = Buffer.create 1024 in
    match
      run_bounded niri_windows ~on_line:(fun line ->
          Buffer.add_string output line;
          Buffer.add_char output '\n')
    with
    | Error message -> Error ("the window lookup failed: " ^ message)
    | Ok () -> (
        match Yojson.Safe.from_string (Buffer.contents output) with
        | exception Yojson.Json_error why -> Error ("the window list is not JSON: " ^ why)
        | json -> Ok (chrome_window json))
  in
  let focus context =
    match commands.focus_command with
    | [] -> Ok ()
    | command -> (
        let substitutions = values context in
        if not (List.exists (fun element -> contains element "{window_id}") command) then
          run_bounded (List.map (render substitutions) command) ~on_line:ignore
        else
          match window_id () with
          | Error message -> Error message
          | Ok None -> Ok ()
          | Ok (Some id) ->
              run_bounded
                (List.map
                   (render (("window_id", string_of_int id) :: substitutions))
                   command)
                ~on_line:ignore)
  in
  let notify ~sw context ~on_done =
    match commands.notify_command with
    | [] -> Ok ()
    | command ->
        runner.run ~sw
          ~argv:(List.map (render (values context)) command)
          ~on_line:(fun line ->
            if String.lowercase_ascii (String.trim line) = "done" then on_done ())
  in
  { focus; notify }

let focus t context = t.focus context
let notify t ~sw context ~on_done = t.notify ~sw context ~on_done
let disabled = { focus = (fun _ -> Ok ()); notify = (fun ~sw:_ _ ~on_done:_ -> Ok ()) }
