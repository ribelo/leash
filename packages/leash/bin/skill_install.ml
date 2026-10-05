(* daily-fiwd daily-yd8s daily-ulmi: Nema's discovered roots, consent and
   staged-directory replacement; the installed bundle also carries the CLI identity. *)
let version = Leash.version
let commit = Leash_build_commit.commit

let stamp =
  Printf.sprintf "metadata:\n  leash-version: %S\n  leash-commit: %S\n" version commit

let stamped_skill contents =
  match String.split_on_char '\n' contents with
  | "---" :: rest ->
      let rec insert acc = function
        | "---" :: tail -> String.concat "\n" (List.rev acc @ [ stamp ^ "---" ] @ tail)
        | line :: tail -> insert (line :: acc) tail
        | [] -> invalid_arg "bundled SKILL.md needs closed YAML frontmatter"
      in
      insert [ "---" ] rest
  | _ -> invalid_arg "bundled SKILL.md needs YAML frontmatter"

let bundle_files =
  List.map
    (fun (path, contents) ->
      (path, if path = "SKILL.md" then stamped_skill contents else contents))
    Leash_skill_data.files

let show = List.assoc "SKILL.md" bundle_files

type requested_action = Install | Replace

type disposition =
  | Installed
  | Replaced
  | Current
  | Declined
  | Planned_install
  | Planned_replace

type outcome = { path : string; disposition : disposition }
type error_kind = Usage | Permission | Internal
type failure = { path : string option; kind : error_kind; message : string }
type error = { completed : outcome list; failures : failure list }

let rec mkdir_p ~caps path =
  if path = "" || Sys.file_exists path then ()
  else (
    mkdir_p ~caps (Filename.dirname path);
    Ox_caps.Cap_unix.mkdir ~caps path 0o755)

let path_exists path =
  match Unix.lstat path with
  | _ -> true
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

let rec remove_path ~caps path =
  match Unix.lstat path with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  | stats when stats.Unix.st_kind = Unix.S_DIR ->
      Ox_caps.Cap_sys.readdir ~caps path
      |> Array.iter (fun name -> remove_path ~caps (Filename.concat path name));
      Ox_caps.Cap_unix.rmdir ~caps path
  | _ -> Ox_caps.Cap_unix.unlink ~caps path

let exception_kind = function
  | Unix.Unix_error ((Unix.EACCES | Unix.EPERM | Unix.EROFS), _, _) -> Permission
  | Sys_error message
    when List.exists
           (fun suffix -> String.ends_with ~suffix (String.lowercase_ascii message))
           [ "permission denied"; "operation not permitted"; "read-only file system" ] ->
      Permission
  | _ -> Internal

let exception_message exn =
  match exception_kind exn with
  | Permission -> "permission denied while accessing the skill directory"
  | Usage | Internal -> "cannot access the skill directory; check the path and its parent"

let write_bundle ~caps destination =
  List.iter
    (fun (relative, contents) ->
      let target = Filename.concat destination relative in
      mkdir_p ~caps (Filename.dirname target);
      Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps target (fun channel ->
          output_string channel contents))
    bundle_files

let unused_sibling destination label =
  let rec choose attempt =
    let candidate =
      Printf.sprintf "%s.%s-%d-%d" destination label (Unix.getpid ()) attempt
    in
    if path_exists candidate then choose (attempt + 1) else candidate
  in
  choose 0

let replace_bundle ~caps destination =
  let staging = unused_sibling destination "tmp" in
  let backup = unused_sibling destination "old" in
  (match write_bundle ~caps staging with
  | () -> ()
  | exception exn ->
      remove_path ~caps staging;
      raise exn);
  let existed = path_exists destination in
  (match if existed then Ox_caps.Cap_unix.rename ~caps destination backup with
  | () -> ()
  | exception exn ->
      remove_path ~caps staging;
      raise exn);
  match Ox_caps.Cap_unix.rename ~caps staging destination with
  | () ->
      if existed then
        match remove_path ~caps backup with
        | () -> None
        | exception (Eio.Cancel.Cancelled _ as exn) -> raise exn
        | exception exn ->
            Some
              ( backup,
                exception_kind exn,
                "replacement completed but backup cleanup failed: "
                ^ exception_message exn )
      else None
  | exception exn ->
      remove_path ~caps staging;
      if existed then Ox_caps.Cap_unix.rename ~caps backup destination;
      raise exn

let rec canonicalize_missing path suffix =
  match Unix.realpath path with
  | existing -> List.fold_left Filename.concat existing suffix
  | exception Unix.Unix_error (Unix.ENOENT, _, _) ->
      let parent = Filename.dirname path in
      if String.equal parent path then raise (Sys_error (path ^ " does not exist"))
      else canonicalize_missing parent (Filename.basename path :: suffix)

let canonicalize path = canonicalize_missing path []

let supported_mappings =
  [
    (".claude", [ "skills" ]);
    (".codex", [ "skills" ]);
    (".pi", [ "agent"; "skills" ]);
    (".agents", [ "skills" ]);
  ]

let failure ?path kind message = { path; kind; message }

let discovered_roots ~home =
  supported_mappings
  |> List.fold_left
       (fun (roots, failures) (configuration, suffix) ->
         let configuration_root = Filename.concat home configuration in
         match Unix.stat configuration_root with
         | stats when stats.Unix.st_kind = Unix.S_DIR ->
             (List.fold_left Filename.concat configuration_root suffix :: roots, failures)
         | _ ->
             ( roots,
               failure ~path:configuration_root Internal
                 (configuration_root ^ " is not an agent configuration directory")
               :: failures )
         | exception Unix.Unix_error (Unix.ENOENT, _, _) -> (roots, failures)
         | exception (Eio.Cancel.Cancelled _ as exn) -> raise exn
         | exception exn ->
             ( roots,
               failure ~path:configuration_root (exception_kind exn)
                 (exception_message exn)
               :: failures ))
       ([], [])
  |> fun (roots, failures) -> (List.rev roots, List.rev failures)

let deduplicate roots =
  let rec loop seen acc failures = function
    | [] -> (List.rev acc, List.rev failures)
    | root :: rest -> (
        match canonicalize root with
        | canonical ->
            if List.mem canonical seen then loop seen acc failures rest
            else loop (canonical :: seen) (root :: acc) failures rest
        | exception (Eio.Cancel.Cancelled _ as exn) -> raise exn
        | exception exn ->
            loop seen acc
              (failure ~path:root (exception_kind exn) (exception_message exn) :: failures)
              rest)
  in
  loop [] [] [] roots

type installed_node = Directory of string | File of string * string | Other of string

let relative_to ~root path =
  let prefix = root ^ Filename.dir_sep in
  String.sub path (String.length prefix) (String.length path - String.length prefix)

let rec installed_nodes ~caps ~root path acc =
  Ox_caps.Cap_sys.readdir ~caps path
  |> Array.to_list |> List.sort String.compare
  |> List.fold_left
       (fun acc name ->
         let child = Filename.concat path name in
         let relative = relative_to ~root child in
         match Unix.lstat child with
         | stats when stats.Unix.st_kind = Unix.S_DIR ->
             installed_nodes ~caps ~root child (Directory relative :: acc)
         | stats when stats.Unix.st_kind = Unix.S_REG ->
             File
               ( relative,
                 Ox_caps.Cap_stdlib.In_channel.with_open_bin ~caps child
                   In_channel.input_all )
             :: acc
         | _ -> Other relative :: acc)
       acc

let expected_nodes =
  let rec directories relative acc =
    let parent = Filename.dirname relative in
    if String.equal parent "." || String.equal parent "" then acc
    else directories parent (Directory parent :: acc)
  in
  bundle_files
  |> List.fold_left
       (fun acc (relative, contents) ->
         File (relative, contents) :: directories relative acc)
       []
  |> List.sort_uniq compare

let is_current ~caps destination =
  match Unix.lstat destination with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false
  | stats when stats.Unix.st_kind <> Unix.S_DIR -> false
  | _ ->
      let actual = installed_nodes ~caps ~root:destination destination [] in
      List.sort compare actual = expected_nodes

let process_target ~caps ~automatic ~force ~no_input ~dry_run ~stdin_is_tty ~confirm root
    =
  let destination = Filename.concat root "leash" in
  let exists = path_exists destination in
  if is_current ~caps destination then
    Ok ({ path = destination; disposition = Current }, None)
  else if dry_run then
    let disposition = if exists then Planned_replace else Planned_install in
    Ok ({ path = destination; disposition }, None)
  else
    let action = if exists then Replace else Install in
    let requires_consent = automatic || exists in
    if requires_consent && (not force) && (no_input || not stdin_is_tty) then
      Error
        (failure ~path:destination Usage
           (Printf.sprintf "confirmation required for %s; rerun with --force" destination))
    else if requires_consent && (not force) && not (confirm action destination) then
      Ok ({ path = destination; disposition = Declined }, None)
    else
      let cleanup_failure = replace_bundle ~caps destination in
      let disposition = if exists then Replaced else Installed in
      let cleanup_failure =
        Option.map
          (fun (path, kind, message) -> failure ~path kind message)
          cleanup_failure
      in
      Ok ({ path = destination; disposition }, cleanup_failure)

let run ~caps ~home ~roots:configured ~path ~force ~no_input ~dry_run ~stdin_is_tty
    ~confirm =
  let fail failure = Error { completed = []; failures = [ failure ] } in
  let automatic, roots, discovery_failures =
    match path with
    | Some "" -> (false, [], [ failure Usage "skill installation PATH must not be empty" ])
    | Some root ->
        let root =
          if Filename.is_relative root then Filename.concat (Sys.getcwd ()) root else root
        in
        (false, [ root ], [])
    | None when configured <> [] ->
        let roots, failures = deduplicate configured in
        (true, roots, failures)
    | None when home = "" || Filename.is_relative home ->
        ( true,
          [],
          [ failure Usage "HOME must be an absolute path for automatic discovery" ] )
    | None -> (
        let roots, discovery_failures = discovered_roots ~home in
        match (roots, discovery_failures) with
        | [], [] ->
            let checked =
              supported_mappings
              |> List.map (fun (configuration, _) -> Filename.concat home configuration)
              |> String.concat ", "
            in
            ( true,
              [],
              [
                failure Usage
                  ("no supported agent configuration found; checked: " ^ checked);
              ] )
        | roots, discovery_failures ->
            let roots, failures = deduplicate roots in
            (true, roots, discovery_failures @ failures))
  in
  if roots = [] then
    match discovery_failures with
    | _ :: _ -> Error { completed = []; failures = discovery_failures }
    | [] -> fail (failure Internal "no install target was selected")
  else
    let outcomes, failures =
      roots
      |> List.fold_left
           (fun (outcomes, failures) root ->
             match
               process_target ~caps ~automatic ~force ~no_input ~dry_run ~stdin_is_tty
                 ~confirm root
             with
             | Ok (outcome, None) -> (outcome :: outcomes, failures)
             | Ok (outcome, Some failure) -> (outcome :: outcomes, failure :: failures)
             | Error failure -> (outcomes, failure :: failures)
             | exception (Eio.Cancel.Cancelled _ as exn) -> raise exn
             | exception exn ->
                 ( outcomes,
                   failure
                     ~path:(Filename.concat root "leash")
                     (exception_kind exn) (exception_message exn)
                   :: failures ))
           ([], discovery_failures)
    in
    let outcomes = List.rev outcomes in
    let failures = List.rev failures in
    if failures = [] then Ok outcomes else Error { completed = outcomes; failures }

let installed_stamp ~caps destination =
  let path = Filename.concat destination "SKILL.md" in
  let read () =
    Ox_caps.Cap_stdlib.In_channel.with_open_bin ~caps path In_channel.input_all
  in
  let value prefix lines =
    List.find_map
      (fun line ->
        if String.starts_with ~prefix line then
          let text =
            String.trim
              (String.sub line (String.length prefix)
                 (String.length line - String.length prefix))
          in
          match Yojson.Safe.from_string text with `String text -> Some text | _ -> None
        else None)
      lines
  in
  try
    let lines = String.split_on_char '\n' (read ()) in
    (value "  leash-version:" lines, value "  leash-commit:" lines)
  with
  | Eio.Cancel.Cancelled _ as exn -> raise exn
  | _ -> (None, None)

let status ~caps ~home ~roots:configured =
  let roots, discovery_failures =
    if configured <> [] then (configured, [])
    else if home = "" || Filename.is_relative home then ([], [])
    else discovered_roots ~home
  in
  let roots, deduplication_failures = deduplicate roots in
  let installed =
    List.map
      (fun root ->
        let path = Filename.concat root "leash" in
        let state =
          try
            if not (path_exists path) then "missing"
            else if is_current ~caps path then "current"
            else "stale"
          with
          | Eio.Cancel.Cancelled _ as exn -> raise exn
          | _ -> "stale"
        in
        let version, commit = installed_stamp ~caps path in
        let json_option = function None -> `Null | Some text -> `String text in
        ( state,
          `Assoc
            [
              ("path", `String path);
              ("state", `String state);
              ("version", json_option version);
              ("commit", json_option commit);
            ] ))
      roots
  in
  let state =
    if
      discovery_failures <> [] || deduplication_failures <> []
      || List.exists (fun (state, _) -> state = "stale") installed
    then "stale"
    else if List.exists (fun (state, _) -> state = "current") installed then "current"
    else "missing"
  in
  `Assoc
    [
      ("state", `String state);
      ("version", `String version);
      ("commit", `String commit);
      ("installs", `List (List.map snd installed));
    ]
