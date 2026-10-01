open Cmdliner

(* daily-iisr: each command documents its own surface. The shared client boundary
   can return config, connection, permission, usage, parsing and internal failures. *)
let exit_doc = function
  | 0 -> "Success."
  | 64 -> "Invalid request or invocation; fix the input."
  | 65 -> "Invalid configuration, playbook, or stale page data."
  | 66 -> "Unknown or gone tab, row, or network request."
  | 69 -> "Service, browser, or model unavailable."
  | 70 -> "Internal failure or invalid service response."
  | 75 -> "Retryable timeout or tab capacity limit."
  | 77 -> "Filesystem or socket permission, or tab capability refused."
  | 124 -> "Command-line parsing failed; the command did not run."
  | _ -> invalid_arg "undocumented CLI exit class"

let exit_infos codes =
  List.map (fun code -> Cmd.Exit.info code ~doc:(exit_doc code)) codes

let all_exits =
  let codes =
    0 :: List.map Leash.Protocol.Error_code.exit_code Leash.Protocol.Error_code.all
    |> List.sort_uniq Int.compare
  in
  exit_infos codes

let docs = function
  | "new" | "list" | "take" | "close" | "handoff" | "resume" -> "TABS"
  | "snap" | "text" | "shot" | "downloads" -> "OBSERVE"
  | "nav" | "click" | "fill" | "press" | "select" | "scroll" | "wait" | "upload" | "hover"
  | "check" | "uncheck" | "dialog" ->
      "ACT"
  | "net" | "debug" | "eval" | "cookies" | "storage" -> "NETWORK AND DEBUG"
  | "drive" | "discover" -> "MISSIONS"
  | "playbook" -> "PLAYBOOKS"
  | _ -> "SERVICE"

let exits name =
  let common = [ 0; 64; 65; 69; 70; 77; 124 ] in
  match name with
  | "status" -> exit_infos (List.sort Int.compare (75 :: common))
  | "list" -> exit_infos common
  | "new" | "discover" -> exit_infos (List.sort Int.compare (75 :: common))
  | _ -> exit_infos (List.sort Int.compare (66 :: 75 :: common))

let local_exits = exit_infos [ 0; 64; 65; 70; 77; 124 ]
let examples lines = `S "EXAMPLES" :: List.map (fun line -> `P line) lines

let command_info ?(man = []) name ~doc ~examples:lines =
  Cmd.info name ~doc ~docs:(docs name) ~exits:(exits name)
    ~man:
      (examples lines @ man
      @ [
          `S "ERRORS";
          `P
            "Failures are one JSON record on stderr. Run $(b,leash help errors) for \
             codes and recovery hints.";
        ])

let local_info ?docs name ~doc ~examples:lines =
  Cmd.info name ~doc ?docs ~exits:local_exits ~man:(examples lines)

let top_man =
  [
    `S "DESCRIPTION";
    `P
      "One local service owns the managed Chrome. Commands send one JSON request over \
       its private Unix socket. Only skill install may ask for local installation \
       consent; use --force or --no-input in automation.";
    `P
      "Handles are secret capabilities; save the handle from leash new or leash take. \
       leash list never reveals handles.";
    `P
      "agent tabs close after 30 idle minutes; your tabs are never closed unless an \
       agent takes one";
    `P "leash status";
    `P "leash list --table";
    `P "leash new https://example.com --label research";
    `P "leash snap TAB --limit 20";
    `S "SERVICE";
    `I
      ( "serve",
        "Start the service in the foreground; normally systemctl --user start leash owns \
         it." );
    `I
      ( "config init / config check",
        "Write the default configuration, then report all setup problems before starting."
      );
    `S "SKILL";
    `P
      "$(b,leash skill show) prints the bundled entrypoint. $(b,leash skill install \
       --dry-run) previews configured skill.roots (or discovered skills roots when \
       unset); --force authorizes installation or replacement. PATH means a skills root, \
       with the bundle at PATH/leash/.";
    `S "EXAMPLES";
    `P "leash click --help; leash help errors";
    `P "leash config init; leash config check; leash serve";
    `S "ERRORS";
    `P
      "Run $(b,leash help errors) for every code, exit class, meaning and recovery hint. \
       --socket PATH overrides the configured control socket.";
  ]
