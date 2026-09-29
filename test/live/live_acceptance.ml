(* Live acceptance for the managed-Chrome row: real Chrome through Leash's own Chrome
   service over [--remote-debugging-pipe]. Stories: chrome-p2n4 (the configured binary on
   a dedicated profile), chrome-9ex7 (a pipe and no debugging port), chrome-b288 (the
   orderly SIGTERM-grace stop). It lives outside [test/] so [dune test] never runs it;
   scripts/live-acceptance builds it and runs it. It runs Chrome headless
   (Chrome.config.headless), so no window appears and none steals focus. *)

module Chrome = Leash.Chrome
module Cdp = Leash.Cdp

exception Failed of string

let fail fmt = Printf.ksprintf (fun message -> raise (Failed message)) fmt
let ok fmt = Printf.ksprintf (fun message -> print_endline ("  ok    " ^ message)) fmt
let warn fmt = Printf.ksprintf (fun message -> print_endline ("  warn  " ^ message)) fmt
let note fmt = Printf.ksprintf print_endline fmt

let starts_with prefix value =
  String.length value >= String.length prefix
  && String.sub value 0 (String.length prefix) = prefix

let contains haystack needle =
  let length = String.length needle in
  let rec scan index =
    index + length <= String.length haystack
    && (String.sub haystack index length = needle || scan (index + 1))
  in
  scan 0

let member name = function `Assoc fields -> List.assoc_opt name fields | _ -> None

let show_event = function
  | Chrome.Started generation -> Printf.sprintf "Started %d" generation
  | Chrome.Lost generation -> Printf.sprintf "Lost %d" generation
  | Chrome.Gave_up _ -> "Gave_up"
  | Chrome.Stopped -> "Stopped"

let read_file path =
  try In_channel.with_open_bin path In_channel.input_all with Sys_error _ -> ""

let argv_of pid =
  read_file (Printf.sprintf "/proc/%d/cmdline" pid)
  |> String.split_on_char '\000'
  |> List.filter (fun arg -> arg <> "")

let exe_of pid =
  try Unix.readlink (Printf.sprintf "/proc/%d/exe" pid) with Unix.Unix_error _ -> ""

let realpath path = try Unix.realpath path with Unix.Unix_error _ -> path

let pids () =
  try Sys.readdir "/proc" |> Array.to_list |> List.filter_map int_of_string_opt
  with Sys_error _ -> []

(* The browser process, not the launcher script and not a zygote, renderer or crash
   handler: an executable whose name is Chrome's, on our profile, holding the debugging
   pipe. [google-chrome-stable] is a wrapper script, so the browser appears a moment
   after the spawn and {!await_browser} polls for it. *)
let is_browser ~profile pid args =
  let cmdline = String.concat " " args in
  contains (String.lowercase_ascii (Filename.basename (exe_of pid))) "chrome"
  && contains cmdline ("--user-data-dir=" ^ profile)
  && contains cmdline "--remote-debugging-pipe"
  && not (contains cmdline "--type=")

let scan_browser ~profile =
  List.find_opt (fun pid -> is_browser ~profile pid (argv_of pid)) (pids ())

(* Chrome reports the browser process's own pid over the same pipe; the /proc scan is the
   fallback when the domain is missing. *)
let browser_pid ~call ~profile =
  let reported () =
    match Cdp.result (call "SystemInfo.getProcessInfo" (`Assoc [])) with
    | Some (`Assoc fields) -> (
        match List.assoc_opt "processInfo" fields with
        | Some (`List infos) ->
            List.find_map
              (fun info ->
                match (member "type" info, member "id" info) with
                | Some (`String "browser"), Some (`Int pid) -> Some pid
                | _ -> None)
              infos
        | _ -> None)
    | _ -> None
  in
  match (reported (), scan_browser ~profile) with
  | Some pid, _ ->
      note "  SystemInfo.getProcessInfo reports browser pid %d" pid;
      pid
  | None, Some pid ->
      warn "SystemInfo.getProcessInfo did not answer; using /proc pid %d" pid;
      pid
  | None, None ->
      fail "neither SystemInfo.getProcessInfo nor /proc found the browser process"

let socket_inodes pid =
  let dir = Printf.sprintf "/proc/%d/fd" pid in
  try
    Sys.readdir dir |> Array.to_list
    |> List.filter_map (fun name ->
        match Unix.readlink (Filename.concat dir name) with
        | link when starts_with "socket:[" link ->
            Some (String.sub link 8 (String.length link - 9))
        | _ -> None)
  with Sys_error _ | Unix.Unix_error _ -> []

(* A listening socket of the browser: /proc/net/tcp sees the whole network namespace, so
   its rows are matched against the socket inodes this process holds. *)
let listeners ~inodes path =
  match String.split_on_char '\n' (read_file path) with
  | [] | [ _ ] -> []
  | _ :: rows ->
      List.filter_map
        (fun row ->
          let fields =
            String.split_on_char ' ' row |> List.filter (fun field -> field <> "")
          in
          let field index =
            match List.nth_opt fields index with Some field -> field | None -> ""
          in
          if field 3 = "0A" && List.mem (field 9) inodes then Some (field 1) else None)
        rows

let await_started ~clock chrome =
  let started () =
    match Eio.Stream.take (Chrome.events chrome) with
    | Chrome.Started generation -> Ok generation
    | event -> Error (`Unexpected (show_event event))
  in
  match Ox.Timeout.timeout ~clock (Ox.Duration.seconds 30) started with
  | Ok generation -> generation
  | Error `Timeout -> fail "Chrome did not start within 30 seconds"
  | Error (`Unexpected event) -> fail "expected Started, got %s" event

let run env ~binary ~profile =
  let clock = Eio.Stdenv.clock env in
  let logger =
    Ox_observability.Logger.create ~service:"leash-live" ~clock
      ~mono_clock:(Eio.Stdenv.mono_clock env)
      ~reporter:(Ox_observability.Logger.Reporter.journal (Eio.Stdenv.stderr env))
      ()
  in
  (* Headless: the gate is about the pipe, the profile and the flags, and a headed
     window steals the operator's focus for no evidence. *)
  let config =
    Chrome.make ~binary ~profile_dir:profile ~workspace:"dev"
      ~grace:(Ox.Duration.seconds 10) ~headless:true ()
  in
  let grace = Ox.Duration.to_seconds_float config.Chrome.grace in
  note "L2 live acceptance: real Chrome over a private CDP pipe";
  note "  binary  %s" binary;
  note "  profile %s" profile;
  note "  argv    %s" (String.concat " " (Chrome.argv config));
  Eio.Switch.run (fun sw ->
      let chrome =
        Chrome.create ~sw config
          {
            Chrome.clock;
            mgr = Eio.Stdenv.process_mgr env;
            logger;
            caps = (Ox_test.powerbox () :> Leash.Chrome.caps);
          }
      in
      let generation = await_started ~clock chrome in
      ok "started, generation %d" generation;
      let connection =
        match Chrome.connection chrome with
        | Ok connection -> connection
        | Error `Browser_unavailable ->
            fail "no CDP connection for generation %d" generation
      in
      let call method_ params =
        match Cdp.call connection ~deadline:(Ox.Duration.seconds 15) method_ params with
        | Ok reply -> reply
        | Error `Timeout -> fail "%s timed out" method_
        | Error (`Transport_closed _) -> fail "%s: the transport closed" method_
        | Error (`Write_failed exn) ->
            fail "%s: write failed (%s)" method_ (Printexc.to_string exn)
        | Error `Id_exhausted -> fail "%s: request ids exhausted" method_
      in
      (* The pipe carries a call before anything about the process is checked. *)
      let targets = call "Target.getTargets" (`Assoc []) in
      note "  Target.getTargets -> %s" (Yojson.Safe.to_string targets);
      ok "Target.getTargets answered over the pipe";
      let pid = browser_pid ~call ~profile in
      (* Chrome rewrites its own command line, so flags are read as text, not as a list
         of arguments. *)
      let cmdline = String.concat " " (argv_of pid) in
      ok "browser process %d runs %s" pid (exe_of pid);
      if contains cmdline "--class=leash" then ok "--class=leash"
      else fail "no --class=leash in %s" cmdline;
      if
        contains cmdline "--no-first-run"
        && contains cmdline "--no-default-browser-check"
        && contains cmdline "--hide-crash-restore-bubble"
      then ok "--no-first-run, --no-default-browser-check, --hide-crash-restore-bubble"
      else fail "missing first-run or restore flags in %s" cmdline;
      if contains cmdline "--headless=new" then ok "--headless=new"
      else fail "missing --headless=new in %s" cmdline;
      let inodes = socket_inodes pid in
      let listening =
        listeners ~inodes "/proc/net/tcp" @ listeners ~inodes "/proc/net/tcp6"
      in
      if listening <> [] then
        fail "the browser listens on %s" (String.concat ", " listening)
      else
        ok "no listening socket among the browser's %d descriptors" (List.length inodes);
      let marker = Filename.concat profile "DevToolsActivePort" in
      if Sys.file_exists marker then
        fail "DevToolsActivePort exists: Chrome opened a debugging port"
      else ok "no DevToolsActivePort file";
      let created =
        call "Target.createTarget" (`Assoc [ ("url", `String "about:blank") ])
      in
      note "  Target.createTarget -> %s" (Yojson.Safe.to_string created);
      ok "Target.createTarget answered over the pipe";
      let after = call "Target.getTargets" (`Assoc []) in
      note "  Target.getTargets -> %s" (Yojson.Safe.to_string after);
      let stop_started = Unix.gettimeofday () in
      Chrome.stop chrome;
      let elapsed = Unix.gettimeofday () -. stop_started in
      if elapsed < grace then
        ok "stopped in %.2fs, inside the %.0fs grace (SIGTERM)" elapsed grace
      else
        warn "the stop took %.2fs of the %.0fs grace: check that Chrome takes SIGTERM"
          elapsed grace;
      let rec gone attempts =
        if not (Sys.file_exists (Printf.sprintf "/proc/%d" pid)) then true
        else if attempts = 0 then false
        else begin
          Eio.Time.sleep clock 0.1;
          gone (attempts - 1)
        end
      in
      if gone 50 then ok "browser process %d is gone" pid
      else fail "browser process %d outlived the stop" pid)

let resolve name =
  if String.contains name '/' then if Sys.file_exists name then Some name else None
  else
    Sys.getenv_opt "PATH" |> Option.value ~default:"" |> String.split_on_char ':'
    |> List.find_map (fun dir ->
        let path = Filename.concat dir name in
        if Sys.file_exists path then Some path else None)

let () =
  let binary = ref "google-chrome-stable" in
  let profile = ref "" in
  let keep = ref false in
  let rec parse = function
    | [] -> ()
    | "--binary" :: value :: rest ->
        binary := value;
        parse rest
    | "--profile" :: value :: rest ->
        profile := value;
        parse rest
    | "--keep" :: rest ->
        keep := true;
        parse rest
    | arg :: _ -> fail "unknown argument %s" arg
  in
  (try parse (List.tl (Array.to_list Sys.argv))
   with Failed message ->
     prerr_endline ("LIVE FAIL: " ^ message);
     exit 2);
  let binary =
    match resolve !binary with Some path -> path | None -> fail "no %s on PATH" !binary
  in
  let profile =
    if !profile <> "" then !profile
    else
      Filename.concat
        (Filename.get_temp_dir_name ())
        (Printf.sprintf "leash-live-%d" (Unix.getpid ()))
  in
  (try Unix.mkdir profile 0o700 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  let status =
    try
      Eio_main.run (fun env -> run env ~binary ~profile);
      print_endline "LIVE OK: managed Chrome over the debugging pipe";
      0
    with
    | Failed message ->
        prerr_endline ("LIVE FAIL: " ^ message);
        1
    | ex ->
        prerr_endline ("LIVE FAIL: " ^ Printexc.to_string ex);
        1
  in
  if not !keep then ignore (Unix.system ("rm -rf " ^ Filename.quote profile));
  exit status
