(** The human-facing side of a handoff: the two best-effort desktop steps that raise the
    live view and tell the human what is asked (hand-04rb hand-phof hand-rg9h). The {!mli}
    is the contract; this file is how a command is rendered, bounded and run. *)

(* hand-rg9h: five seconds is both a command's deadline for the steps a handoff waits on
   and the retirement grace of every child it starts. *)
let step_timeout = Ox.Duration.seconds 5

type caps = < Ox_caps.Cap.fork ; Ox_caps.Cap.exec ; Ox_caps.Cap.fs_write >

let retirement_grace = Ox.Duration.seconds 5

(* hand-phof hand-rg9h: one command's whole life, as a real child. It is spawned on the
   switch the caller gives — the handoff's own switch for a notification — with a
   five-second retirement grace and its stdout read as lines, and answers [Ok] for a zero
   exit and [Error reason] for anything else. A command stopped because that switch was
   released is cancelled, not reported. *)
let run_command ~grace ~caps ~clock ~mgr ~sw ~argv ~on_line =
  try
    match
      Ox_process.Child.spawn ~caps ~sw ~clock ~mgr ~argv ~grace
        ~stdout:Ox_process.Child.Pipe ~fds:[] ()
    with
    | Error (`Invalid_fd descriptor) ->
        Error (Printf.sprintf "invalid descriptor %d" descriptor)
    | Error (`Duplicate_fd descriptor) ->
        Error (Printf.sprintf "duplicate descriptor %d" descriptor)
    | Ok child -> (
        (match Ox_process.Child.stdout child with
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
        match Ox_process.Child.await child with
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

type commands = { focus_command : string list; notify_command : string list }
type context = { tab : Protocol.Handle.t; reason : string; url : string; title : string }

type t = {
  focus : context -> (unit, string) result;
  notify :
    sw:Eio.Switch.t ->
    context ->
    on_done:(unit -> unit) ->
    on_cancel:(unit -> unit) ->
    (unit, string) result;
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

let create ~(caps : caps) ~clock ~mgr commands =
  let run_bounded argv ~on_line =
    match
      Ox.Timeout.timeout ~clock step_timeout (fun () ->
          Eio.Switch.run (fun sw ->
              run_command ~grace:retirement_grace ~caps ~clock ~mgr ~sw ~argv ~on_line)
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
  let notify ~sw context ~on_done ~on_cancel =
    match commands.notify_command with
    | [] -> Ok ()
    | command ->
        (* pilot-9u3q: notify-send prints an action, or exits zero without one when
           dismissed. Cancellation of this fiber and failed delivery are neither. *)
        let answered = ref false in
        let answer f =
          if not !answered then (
            answered := true;
            f ())
        in
        let outcome =
          run_command ~grace:retirement_grace ~caps ~clock ~mgr ~sw
            ~argv:(List.map (render (values context)) command)
            ~on_line:(fun line ->
              match String.lowercase_ascii (String.trim line) with
              | "done" -> answer on_done
              | "cancel" -> answer on_cancel
              | _ -> ())
        in
        (match outcome with Ok () -> answer on_cancel | Error _ -> ());
        outcome
  in
  { focus; notify }

let focus t context = t.focus context
let notify t ~sw context ~on_done ~on_cancel = t.notify ~sw context ~on_done ~on_cancel

let disabled =
  { focus = (fun _ -> Ok ()); notify = (fun ~sw:_ _ ~on_done:_ ~on_cancel:_ -> Ok ()) }

(* notif-7pha: argv only, bounded best effort; no shell or notification action wait. *)
let notifier ~(caps : caps) ~clock ~mgr ~command =
 fun message ->
  if command = [] then Ok ()
  else
    match
      Ox.Timeout.timeout ~clock step_timeout (fun () ->
          Eio.Switch.run (fun sw ->
              run_command ~grace:Ox.Duration.zero ~caps ~clock ~mgr ~sw
                ~argv:(List.map (render [ ("message", message) ]) command)
                ~on_line:ignore)
          |> Result.map_error (fun message -> `Failed message))
    with
    | Ok () -> Ok ()
    | Error (`Failed message) -> Error message
    | Error `Timeout -> Error "notification command timed out"
