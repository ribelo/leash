open Cmdliner
module P = Leash.Protocol

let obj fields = `Assoc fields
let str s = `String s

let usage msg =
  prerr_endline ("leash: " ^ msg);
  2

let failure msg =
  prerr_endline ("leash: " ^ msg);
  1

let send path request =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let socket = Eio.Net.connect ~sw env#net (`Unix path) in
          let data = Yojson.Safe.to_string request ^ "\n" in
          Eio.Flow.copy_string data socket;
          let reader = Eio.Buf_read.of_flow ~max_size:1_048_576 socket in
          Eio.Buf_read.line reader))

let field key = function
  | `Assoc fields -> ( match List.assoc_opt key fields with Some x -> x | None -> `Null)
  | _ -> `Null

let cell = function
  | `String s -> s
  | `Int n -> string_of_int n
  | `Bool b -> string_of_bool b
  | `Null -> "-"
  | other -> Yojson.Safe.to_string other

let table command result =
  let tabs = match field "tabs" result with `List xs -> xs | _ -> [] in
  match command with
  | "list" ->
      (* hand-r4t1: REASON is what the tab is waiting on the human for, "-" on every tab
         nobody is waiting on, so a human who stepped away can see what is asked. *)
      print_endline "TAB\tURL\tTITLE\tORIGIN\tSTATE\tOWNER\tREASON";
      List.iter
        (fun row ->
          Printf.printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n"
            (cell (field "tab" row))
            (cell (field "url" row))
            (cell (field "title" row))
            (cell (field "origin" row))
            (cell (field "state" row))
            (cell (field "owner" row))
            (cell (field "reason" row)))
        tabs
  | "snap" ->
      print_endline "INDEX\tROLE\tNAME\tVALUE\tSTATE";
      (match field "rows" result with `List xs -> xs | _ -> [])
      |> List.iter (fun row ->
          Printf.printf "%s\t%s\t%s\t%s\t%s\n"
            (cell (field "index" row))
            (cell (field "role" row))
            (cell (field "name" row))
            (cell (field "value" row))
            (match field "state" row with
            | `List xs -> String.concat "," (List.map cell xs)
            | _ -> ""))
  | _ -> ()

(* svc-hi4f: the options every command shares and the request fields it must not carry —
   the CLI's own, peeled off here so a command's table entry lists exactly what goes on
   the wire. *)
let cli_options = [ "owner"; "pretty"; "table"; "config"; "socket" ]

(* svc-o4wt svc-x8rp: --socket wins for one call; otherwise the CLI reads the same
   configuration the service does — --config, or $XDG_CONFIG_HOME/leash/config.toml — and
   the Door's rule decides whether an absent file is allowed (napp-9x0s): nothing at the
   default path is the defaults, so the client works before `leash config init` has run,
   while a --config path that is not there is an error naming it, exactly what the service
   reports. A file that is there and wrong is an error either way. *)
let service_socket ~config ~socket =
  match socket with
  | Some path -> Ok path
  | None -> (
      let source = Eta_app.Config.resolve ~name:"leash" ~config ~getenv:Sys.getenv_opt in
      (* The Door's read outcome, not a message: a path with nothing at it is [`Missing],
         which is only an error where --config named it. *)
      let read path =
        if not (Sys.file_exists path) then Error `Missing
        else
          try Ok (In_channel.with_open_bin path In_channel.input_all)
          with Sys_error message -> Error (`Unreadable message)
      in
      match
        Eta_app.Config.load ~spec:Leash.Config.spec ~getenv:Sys.getenv_opt ~read ~source
      with
      | Error (`Config message) ->
          let file = match source with `Explicit path | `Default path -> path in
          Error ("invalid configuration in " ^ file ^ ": " ^ message)
      | Ok (config : Leash.Config.t) ->
          let path = Leash.Config.Text.to_string config.control.socket in
          if String.contains path '$' then
            Error
              ("the control socket " ^ path
             ^ " does not resolve; set XDG_RUNTIME_DIR or pass --socket")
          else Ok path)

let perform command fields positionals options =
  let actual = List.length positionals in
  let options = List.filter_map Fun.id options in
  let cli = List.filter (fun (name, _) -> List.mem name cli_options) options in
  let request = List.filter (fun (name, _) -> not (List.mem name cli_options)) options in
  let flag name =
    match List.assoc_opt name cli with Some (`Bool true) -> true | _ -> false
  in
  let text name =
    match List.assoc_opt name cli with Some (`String value) -> Some value | _ -> None
  in
  let pretty = flag "pretty" and use_table = flag "table" in
  if use_table && pretty then usage "--table and --pretty cannot both be given"
  else
    let owner =
      match text "owner" with
      | Some owner when String.trim owner <> "" -> Some owner
      | Some _ | None ->
          Option.bind (Sys.getenv_opt "DSH_SESSION_ID") (fun id ->
              if id = "" then None else Some ("dsh:" ^ id))
    in
    match owner with
    | None -> usage "set --owner or DSH_SESSION_ID"
    | Some owner -> (
        let encode_pos key value =
          if List.mem key [ "index"; "option" ] then
            match int_of_string_opt value with
            | Some number -> Ok (key, `Int number)
            | None -> Error (key ^ " must be an integer")
          else Ok (key, str value)
        in
        let fields =
          List.map2 encode_pos (List.filteri (fun n _ -> n < actual) fields) positionals
        in
        let rec collect = function
          | [] -> Ok []
          | Error e :: _ -> Error e
          | Ok x :: xs -> Result.map (fun tail -> x :: tail) (collect xs)
        in
        match collect fields with
        | Error why -> usage why
        | Ok fields -> (
            let options =
              try
                Ok
                  (List.map
                     (fun (key, value) ->
                       if List.mem key [ "argument"; "until" ] then
                         match value with
                         | `String text -> (key, Yojson.Safe.from_string text)
                         | _ -> assert false
                       else (key, value))
                     request)
              with Yojson.Json_error why -> Error ("invalid JSON option: " ^ why)
            in
            match options with
            | Error why -> usage why
            | Ok options -> (
                let options =
                  if command <> "wait" then options
                  else
                    let condition_names =
                      [ "url_prefix"; "text"; "index_gone"; "dialog" ]
                    in
                    let conditions, rest =
                      List.partition
                        (fun (key, _) -> List.mem key condition_names)
                        options
                    in
                    let previous =
                      match List.assoc_opt "until" rest with
                      | Some (`Assoc fields) ->
                          List.filter
                            (fun (key, _) -> not (List.mem_assoc key conditions))
                            fields
                      | _ -> []
                    in
                    let rest = List.remove_assoc "until" rest in
                    let timeout =
                      match List.assoc_opt "timeout" rest with
                      | Some value when not (List.mem_assoc "timeout_ms" rest) ->
                          [ ("timeout_ms", value) ]
                      | _ -> []
                    in
                    let rest = List.remove_assoc "timeout" rest in
                    (("until", obj (conditions @ previous)) :: timeout) @ rest
                in
                let args = obj (fields @ options) in
                match P.command_of_args ~cmd:command args with
                | Error why -> usage why
                | Ok decoded -> (
                    match P.Owner.of_string owner with
                    | Error why -> usage why
                    | Ok owner -> (
                        let request = P.encode_request P.{ owner; command = decoded } in
                        match
                          service_socket ~config:(text "config") ~socket:(text "socket")
                        with
                        | Error why -> usage why
                        | Ok path -> (
                            try
                              let raw = Yojson.Safe.from_string (send path request) in
                              match P.decode_reply raw with
                              | Error why -> failure ("invalid service reply: " ^ why)
                              | Ok reply ->
                                  let body =
                                    match reply with
                                    | P.Success result -> result
                                    | P.Failure error -> P.yojson_of_error error
                                  in
                                  let ok =
                                    match reply with
                                    | P.Success _ -> true
                                    | P.Failure _ -> false
                                  in
                                  if use_table && ok then table command body
                                  else
                                    print_endline
                                      (if pretty then Yojson.Safe.pretty_to_string body
                                       else Yojson.Safe.to_string body);
                                  if ok then 0 else 1
                            with
                            | Unix.Unix_error (code, _, _) ->
                                failure (Unix.error_message code)
                            | Eio.Io _ as err -> failure (Printexc.to_string err)
                            | Yojson.Json_error msg ->
                                failure ("invalid JSON reply: " ^ msg)
                            | End_of_file -> failure "service closed without a reply")))))
        )

(* svc-hi4f: the table is the CLI's contract. Every command names its positionals in the
   protocol's order — TAB, SNAPSHOT, INDEX — and lists exactly the options it takes, so
   `leash <command> --help` shows the whole call. The four shared options go on every
   command; --table only on the two that render one. *)
type option_kind = Str | Int | Bool | Json
type option_ = { name : string; kind : option_kind; docv : string; doc : string }
type positional = { field : string; docv : string; optional : bool }

let opt name kind docv doc = { name; kind; docv; doc }
let pos field docv = { field; docv; optional = false }
let pos_opt field docv = { field; docv; optional = true }
let owner_opt = opt "owner" Str "NAME" "Request owner (default dsh:\\$DSH_SESSION_ID)."
let pretty_opt = opt "pretty" Bool "" "Indent JSON output."
let table_opt = opt "table" Bool "" "Render list and snap rows as a table."

let config_opt =
  opt "config" Str "FILE" "TOML configuration file the control socket is read from."

let socket_opt = opt "socket" Str "PATH" "Control socket path; overrides control.socket."
let shared_options = [ owner_opt; pretty_opt; config_opt; socket_opt ]

let option_term { name; kind; docv; doc } =
  let long = String.map (fun c -> if c = '_' then '-' else c) name in
  let arg_info = Arg.info ?docv:(if docv = "" then None else Some docv) ~doc [ long ] in
  match kind with
  | Bool ->
      Term.(
        const (fun value -> if value then Some (name, `Bool true) else None)
        $ Arg.(value & flag & arg_info))
  | Int ->
      Term.(
        const (Option.map (fun number -> (name, `Int number)))
        $ Arg.(value & opt (some int) None & arg_info))
  | Str ->
      Term.(
        const (Option.map (fun value -> (name, str value)))
        $ Arg.(value & opt (some string) None & arg_info))
  | Json ->
      Term.(
        const (Option.map (fun value -> (name, str value)))
        $ Arg.(value & opt (some string) None & arg_info))

let positional_term positionals =
  List.fold_left
    (fun term (index, spec) ->
      let arg =
        if spec.optional then
          Term.(
            const (fun value -> Option.to_list value)
            $ Arg.(value & pos index (some string) None & info [] ~docv:spec.docv))
        else
          Term.(
            const (fun value -> [ value ])
            $ Arg.(required & pos index (some string) None & info [] ~docv:spec.docv))
      in
      Term.(const ( @ ) $ term $ arg))
    (Term.const [])
    (List.mapi (fun index spec -> (index, spec)) positionals)

let command name doc positionals options examples =
  let fields = List.map (fun spec -> spec.field) positionals in
  let collected =
    List.fold_left
      (fun term spec -> Term.(const (fun xs x -> xs @ [ x ]) $ term $ option_term spec))
      (Term.const []) options
  in
  let man =
    match examples with
    | [] -> []
    | examples -> `S "EXAMPLES" :: List.map (fun example -> `P example) examples
  in
  Cmd.v (Cmd.info name ~doc ~man)
    Term.(
      const (fun args opts () -> perform name fields args opts)
      $ positional_term positionals $ collected)

(* run-tcuz run-dbji run-ykq4: these authoring commands need no service. *)
let playbook_command =
  let output = function
    | Error message -> failure message
    | Ok book ->
        print_endline (Yojson.Safe.pretty_to_string (Leash.Playbook.inspect book));
        0
  in
  let name = Arg.(required & pos 0 (some string) None & info [] ~docv:"NAME") in
  let file = Arg.(required & pos 0 (some string) None & info [] ~docv:"FILE") in
  let list =
    Cmd.v
      (Cmd.info "list" ~doc:"List validated installed site playbooks.")
      Term.(
        const (fun () () ->
            match Leash.Playbook.list () with
            | Error message -> failure message
            | Ok books ->
                List.iter
                  (fun (book : Leash.Playbook.loaded) ->
                    Printf.printf "%s\t%s\n" book.playbook.site book.playbook.description)
                  books;
                0)
        $ const ())
  in
  let show =
    Cmd.v
      (Cmd.info "show" ~doc:"Show a named installed playbook and resolved checkers.")
      Term.(const (fun name () () -> output (Leash.Playbook.show name)) $ name $ const ())
  in
  let check =
    Cmd.v
      (Cmd.info "check" ~doc:"Check a JSON playbook file and show resolved checkers.")
      Term.(const (fun file () () -> output (Leash.Playbook.load file)) $ file $ const ())
  in
  Cmd.group
    (Cmd.info "playbook" ~doc:"Inspect and validate site playbooks.")
    [ list; show; check ]

let commands =
  List.map
    (fun (name, doc, positionals, options, examples) ->
      command name doc positionals (options @ shared_options) examples)
    [
      ( "new",
        "Open an agent-owned tab.",
        [ pos_opt "url" "URL" ],
        [],
        [ "leash new https://example.com" ] );
      ( "downloads",
        "List downloads started by this tab.",
        [ pos "tab" "TAB" ],
        [],
        [ "leash downloads t_9xk" ] );
      ( "list",
        "List the tabs this caller owns.",
        [],
        [
          opt "all" Bool "" "Include every tab with its origin, state and owner.";
          table_opt;
        ],
        [ "leash list"; "leash list --all --table" ] );
      ("claim", "Claim an unowned tab.", [ pos "tab" "TAB" ], [], [ "leash claim t_9xk" ]);
      ( "release",
        "Release a tab (own tab; --force for any).",
        [ pos "tab" "TAB" ],
        [ opt "force" Bool "" "Ignore ownership; every use is logged." ],
        [ "leash release t_9xk" ] );
      ( "close",
        "Close a tab (own tab; --force for any).",
        [ pos "tab" "TAB" ],
        [ opt "force" Bool "" "Ignore ownership; every use is logged." ],
        [ "leash close t_9xk" ] );
      ( "status",
        "Report browser health and the models section.",
        [],
        [],
        [ "leash status" ] );
      ( "snap",
        "Observe an indexed snapshot of a tab.",
        [ pos "tab" "TAB" ],
        [
          opt "match" Str "TEXT" "Keep rows whose role, name or value contains TEXT.";
          opt "limit" Int "N" "At most N rows (default 120).";
          opt "offset" Int "N" "Skip the first N rows.";
          table_opt;
        ],
        [ "leash snap t_9xk --match Save --limit 10" ] );
      ( "text",
        "Extract the page's visible text.",
        [ pos "tab" "TAB" ],
        [
          opt "index" Int "N" "Read only the row at index N.";
          opt "max_chars" Int "N" "At most N characters (default and maximum 65536).";
        ],
        [ "leash text t_9xk --max-chars 300" ] );
      ( "shot",
        "Write a screenshot as a PNG to PATH.",
        [ pos "tab" "TAB"; pos "path" "PATH" ],
        [ opt "full_page" Bool "" "Capture the whole page, not the viewport." ],
        [ "leash shot t_9xk /tmp/page.png" ] );
      ( "debug",
        "Show the console, exception and failed-request ring.",
        [ pos "tab" "TAB" ],
        [
          opt "limit" Int "N" "At most N entries (default 200).";
          opt "clear" Bool "" "Discard the ring after reading it.";
        ],
        [ "leash debug t_9xk --limit 10" ] );
      ( "eval",
        "Evaluate EXPRESSION as a function body in the page.",
        [ pos "tab" "TAB"; pos "expression" "EXPRESSION" ],
        [ opt "argument" Json "JSON" "JSON value bound to argument in the expression." ],
        [ "leash eval t_9xk 'return document.title'" ] );
      ( "nav",
        "Navigate a tab to a URL (http, https or about:blank).",
        [ pos "tab" "TAB"; pos "url" "URL" ],
        [],
        [ "leash nav t_9xk https://example.com" ] );
      ( "click",
        "Click the row at INDEX of SNAPSHOT.",
        [ pos "tab" "TAB"; pos "snapshot" "SNAPSHOT"; pos "index" "INDEX" ],
        [],
        [ "leash click t_9xk s_3 7" ] );
      ( "fill",
        "Fill the row at INDEX of SNAPSHOT with TEXT.",
        [
          pos "tab" "TAB";
          pos "snapshot" "SNAPSHOT";
          pos "index" "INDEX";
          pos "text" "TEXT";
        ],
        [],
        [ "leash fill t_9xk s_3 1 'Ada Lovelace'" ] );
      ( "press",
        "Press KEY; with --index the row is focused first.",
        [ pos "tab" "TAB"; pos "snapshot" "SNAPSHOT"; pos "key" "KEY" ],
        [ opt "index" Int "N" "Focus the row at index N before the key." ],
        [ "leash press t_9xk s_3 Enter" ] );
      ( "select",
        "Choose OPTION, the row's observed option index.",
        [
          pos "tab" "TAB";
          pos "snapshot" "SNAPSHOT";
          pos "index" "INDEX";
          pos "option" "OPTION";
        ],
        [],
        [ "leash select t_9xk s_3 2 0" ] );
      ( "scroll",
        "Scroll the page, or the row --index names, one viewport.",
        [ pos "tab" "TAB"; pos "direction" "UP|DOWN" ],
        [ opt "index" Int "N" "Scroll the row at index N into view." ],
        [ "leash scroll t_9xk down" ] );
      ( "wait",
        "Wait for the ANDed page conditions.",
        [ pos "tab" "TAB" ],
        [
          opt "until" Json "JSON" "JSON object of the conditions below.";
          opt "url_prefix" Str "PREFIX" "Until the url starts with PREFIX.";
          opt "text" Str "TEXT" "Until the page text contains TEXT.";
          opt "index_gone" Int "N" "Until row N is gone.";
          opt "dialog" Bool "" "Until a dialog is open.";
          opt "timeout" Int "MS" "Alias of --timeout-ms.";
          opt "timeout_ms" Int "MS" "Bound the wait in milliseconds (max 30000).";
        ],
        [ "leash wait t_9xk --text Done --timeout-ms 5000" ] );
      ( "dialog",
        "Answer the page's dialog (never automatic).",
        [ pos "tab" "TAB"; pos "answer" "ACCEPT|DISMISS" ],
        [ opt "text" Str "TEXT" "Answer text for a prompt." ],
        [ "leash dialog t_9xk accept" ] );
      ( "handoff",
        "Hand the tab to the human and block until resume or timeout.",
        [ pos "tab" "TAB"; pos "reason" "REASON" ],
        [ opt "timeout_s" Int "S" "Seconds before the handoff ends (default 900)." ],
        [ "leash handoff t_9xk 'The captcha needs you'" ] );
      ( "resume",
        "Resume a tab a handoff is waiting on.",
        [ pos "tab" "TAB" ],
        [],
        [ "leash resume t_9xk" ] );
      ( "drive",
        "Drive the tab toward GOAL with the decision model.",
        [ pos "tab" "TAB"; pos "goal" "GOAL" ],
        [
          opt "max_steps" Int "N" "At most N steps (default 30).";
          opt "deadline_s" Int "S" "Seconds for the whole drive (default 120).";
          opt "dry_run" Bool "" "Observe and decide once without acting.";
        ],
        [ "leash drive t_9xk 'Find the article about Goedel' --max-steps 10" ] );
    ]
  @ [ playbook_command ]

let ( let* ) = Result.bind

let program env (config : Leash.Config.t) sw =
  let base = env.Eta_app.Env.base in
  (* Test-only: the live-acceptance gate shortens the sweep period through
     LEASH_SWEEP_INTERVAL_S so stage 1 then stage 2 are observable on a real clock in
     seconds; production always uses the 30 s contract default. A bad value fails fast,
     before Chrome launches, rather than silently changing the cadence. *)
  let* sweep_interval =
    match Sys.getenv_opt "LEASH_SWEEP_INTERVAL_S" with
    | None | Some "" -> Ok None
    | Some text -> (
        match int_of_string_opt (String.trim text) with
        | Some n when n > 0 -> Ok (Some (Eta.Duration.seconds n))
        | Some _ | None ->
            Error (`Service "LEASH_SWEEP_INTERVAL_S must be a positive integer"))
  in
  (* svc-x8rp: the default profile is [$XDG_DATA_HOME/leash/profile], which a first run
     has not created; the owner makes it 0700 before Chrome starts, the way the listener
     makes its own runtime directory. The validator accepted what it can create. *)
  let* () =
    match
      Leash.Config.ensure_dir (Leash.Config.Text.to_string config.chrome.profile_dir)
    with
    | Ok () -> Ok ()
    | Error message ->
        Error (`Service ("cannot create the profile directory: " ^ message))
  in
  let chrome =
    Leash.Chrome.create ~sw
      (Leash.Config.chrome_config config.chrome)
      { Leash.Chrome.clock = base#clock; mgr = base#process_mgr; logger = env.logger }
  in
  (* own-vhqo: the two expiry durations are config. The registry counts every tab down
     to them and the sweep applies them. *)
  let seconds duration = Eta.Duration.seconds (Leash.Config.Seconds.to_int duration) in
  let idle = seconds config.expiry.idle_s in
  let unclaimed = seconds config.expiry.unclaimed_s in
  (* hand-04rb hand-phof hand-rg9h: the two human-facing commands a handoff runs go through
     Eta's child process, and the registry turns whatever they report into warnings. *)
  let desktop =
    Leash.Desktop.create ~clock:base#clock ~mgr:base#process_mgr
      {
        Leash.Desktop.focus_command = config.handoff.focus_command;
        notify_command = config.handoff.notify_command;
      }
  in
  let download_dir =
    Filename.concat (Leash.Config.Text.to_string config.chrome.profile_dir) "downloads"
  in
  let* () =
    match Leash.Config.ensure_dir download_dir with
    | Ok () -> Ok ()
    | Error message -> Error (`Service ("cannot create downloads directory: " ^ message))
  in
  let tabs =
    Leash.Tabs.create ~sw ~download_dir
      ~cap:(Leash.Config.Tab_cap.to_int config.tabs.cap)
      ~tombstone_s:(Leash.Config.Seconds.to_int config.expiry.tombstone_s)
      ~idle ~unclaimed
      { Leash.Tabs.chrome; clock = base#clock; logger = env.logger; desktop }
  in
  (* own-uo77 own-hslp: the sweep is one more service in the owner, released with the
     switch. *)
  let _expiry =
    Leash.Expiry.create ~sw ?interval:sweep_interval ~idle ~unclaimed ~clock:base#clock
      ~logger:env.logger tabs
  in
  (* drive-e7oi drive-yqxg: the models service is one more scoped resource in the owner,
     created before the listener that hands its Decide to every drive. Without a key it
     still exists — status reports that — and a drive refuses at its first Decide. *)
  let models =
    Leash.Models.create ~sw ~net:base#net ~clock:base#clock ~logger:env.logger
      config.models
  in
  Eio.Switch.on_release sw (fun () -> Leash.Tabs.stop tabs);
  let status_query = Eta_app.status_query [ (fun () -> Leash.Tabs.status tabs) ] in
  (* svc-o4wt: the listener owns the configured socket path; validation refused anything
     that is not a real absolute path, so the variable is resolved by now. *)
  let socket = Leash.Config.Text.to_string config.control.socket in
  let* _control =
    Leash.Control.create
      ~model:(Leash.Config.Text.to_string config.models.jev_model)
      ~decide:(fun ~deadline request -> Leash.Models.decide ~deadline models request)
        (* drive-ls3c: the helper is a thunk, not a value — each drive takes its own
         instance, and with it the one-entry memo the stale-row reuse rule needs. *)
      ~text_helper:(fun () -> Leash.Models.text_helper models)
      ~sw ~path:socket
      {
        Leash.Control.tabs;
        status_query;
        models_status = (fun () -> Leash.Models.status models);
        fs = base#fs;
        net = base#net;
        clock = base#clock;
        logger = env.logger;
      }
    |> Result.map_error (fun _ -> `Service "control socket acquisition failed")
  in
  Eta_app.serve ~sw ()

(* svc-x8rp: `leash config init` writes the commented default file. It is a Door subcommand
   of `config` (napp-wf22), not an ordinary command: it needs no service and sends no
   request, only the path the Door reads — which is exactly the file it writes — so
   --config and its XDG resolution stay the Door's. *)
let init_command =
  let config_file =
    Arg.(
      value
      & opt (some string) None
      & info [ "config" ] ~docv:"FILE" ~doc:"TOML configuration file to write.")
  in
  let force = Arg.(value & flag & info [ "force" ] ~doc:"Overwrite an existing file.") in
  let run config_file force () =
    let path =
      Eta_app.Config.path ~name:"leash" ~config:config_file ~getenv:Sys.getenv_opt
    in
    match Leash.Config.init ~force ~path () with
    | Ok path ->
        print_endline path;
        0
    | Error (`Exists path) ->
        usage (path ^ " already exists; pass --force to overwrite it")
    | Error (`Write message) -> failure ("cannot write " ^ path ^ ": " ^ message)
  in
  Cmd.v
    (Cmd.info "init" ~doc:"Write a commented default configuration file.")
    Term.(const run $ config_file $ force)

let telemetry ~sw env config =
  match config.Leash.Config.otlp.endpoint with
  | None -> { Eta_app.reporters = []; span_ids = None }
  | Some endpoint ->
      Leash.Telemetry.create ~sw ~net:env.Eta_app.Env.base#net
        ~clock:env.Eta_app.Env.base#clock
        ~endpoint:(Leash.Config.Text.to_string endpoint)
        ~headers:
          (List.map
             (fun (header : Leash.Config.otlp_header) ->
               ( Leash.Config.Text.to_string header.name,
                 Leash.Config.Redact.expose header.value ))
             config.otlp.headers)

let () =
  exit
    (Eta_app.run ~name:"leash" ~config:Leash.Config.spec ~commands ~telemetry
       ~config_commands:[ init_command ] ~validate:Leash.Config.validate
       ~pp_err:(fun fmt (`Service msg) -> Format.pp_print_string fmt msg)
       program)
