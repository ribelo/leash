open Cmdliner
module P = Leash.Protocol
module Cap_stdlib = Ox_caps.Cap_stdlib
module Cap_sys = Ox_caps.Cap_sys

(* ^ncaps-4tjy: every command gets its capabilities from the Door's powerbox
   ([Ox_app.Env.caps], handed to the command builders below); nothing here touches the
   environment, the standard streams or a file except through them. *)

let obj fields = `Assoc fields
let str s = `String s

(* daily-azxe daily-6pde daily-3bwr: the same record and code table on both sides
   of the socket. Errors are always one compact JSON line, never affected by --pretty. *)
let make_error ?detail name message : P.error =
  let code =
    match P.Error_code.of_string name with
    | Ok code -> code
    | Error _ -> invalid_arg "unknown CLI error code"
  in
  P.make_error ?detail code ~message

let emit_error ~caps (error : P.error) =
  Cap_stdlib.prerr_endline ~caps (Yojson.Safe.to_string (P.yojson_of_error error));
  P.Error_code.exit_code error.code

let report ~caps ?detail code message = emit_error ~caps (make_error ?detail code message)
let usage ~caps message = report ~caps "usage" message
let failure ~caps message = report ~caps "internal" message
let invalid_playbook ~caps message = report ~caps "script-invalid" message

let protect ~caps run =
  try run () with
  | Eio.Cancel.Cancelled _ as exn -> raise exn
  | Unix.Unix_error ((Unix.EACCES | Unix.EPERM | Unix.EROFS), _, _) ->
      report ~caps "permission-denied"
        "permission denied while accessing a local resource"
  | Eio.Io (Eio.Fs.E (Eio.Fs.Permission_denied _), _) ->
      report ~caps "permission-denied"
        "permission denied while accessing a local resource"
  | _ ->
      failure ~caps "the command failed unexpectedly; no successful result was produced"

let send ?timeout_s ~base path request =
  let run () =
    Eio.Switch.run (fun sw ->
        let socket = Eio.Net.connect ~sw base#net (`Unix path) in
        let data = Yojson.Safe.to_string request ^ "\n" in
        Eio.Flow.copy_string data socket;
        let reader = Eio.Buf_read.of_flow ~max_size:8_388_608 socket in
        Eio.Buf_read.line reader)
  in
  match timeout_s with
  | None -> run ()
  | Some seconds -> Eio.Time.with_timeout_exn base#clock seconds run

let field key = function
  | `Assoc fields -> ( match List.assoc_opt key fields with Some x -> x | None -> `Null)
  | _ -> `Null

let cell = function
  | `String s -> s
  | `Int n -> string_of_int n
  | `Bool b -> string_of_bool b
  | `Null -> "-"
  | other -> Yojson.Safe.to_string other

let table ~caps command result =
  let tabs = match field "tabs" result with `List xs -> xs | _ -> [] in
  match command with
  | "list" ->
      (* hand-r4t1: REASON is what the tab is waiting on the human for, "-" on every tab
         nobody is waiting on, so a human who stepped away can see what is asked. *)
      Cap_stdlib.print_endline ~caps "TAB\tURL\tTITLE\tORIGIN\tSTATE\tOWNER\tREASON";
      List.iter
        (fun row ->
          Cap_stdlib.printf ~caps "%s\t%s\t%s\t%s\t%s\t%s\t%s\n"
            (cell (field "tab" row))
            (cell (field "url" row))
            (cell (field "title" row))
            (cell (field "origin" row))
            (cell (field "state" row))
            (cell (field "owner" row))
            (cell (field "reason" row)))
        tabs
  | "snap" ->
      Cap_stdlib.print_endline ~caps "INDEX\tROLE\tNAME\tVALUE\tSTATE";
      (match field "rows" result with `List xs -> xs | _ -> [])
      |> List.iter (fun row ->
          Cap_stdlib.printf ~caps "%s\t%s\t%s\t%s\t%s\n"
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
let service_socket ~caps ~config ~socket =
  match socket with
  | Some path -> Ok path
  | None -> (
      let source =
        Ox_app.Config.resolve ~name:"leash" ~config ~getenv:(Cap_sys.getenv_opt ~caps)
      in
      (* The Door's read outcome, not a message: a path with nothing at it is [`Missing],
         which is only an error where --config named it. *)
      let read path =
        if not (Sys.file_exists path) then Error `Missing
        else
          try Ok (Cap_stdlib.In_channel.with_open_bin ~caps path In_channel.input_all)
          with Sys_error _ ->
            Error (`Unreadable "cannot read the configuration file; check permissions")
      in
      match
        Ox_app.Config.load
          ~spec:
            {
              Leash.Config.spec with
              of_yojson =
                (fun json ->
                  match
                    Leash.Config.decode_all ~getenv:(Cap_sys.getenv_opt ~caps) json
                  with
                  | Ok config -> Ok config
                  | Error problems ->
                      Error (Ox_app.Config.render_validation_errors problems));
            }
          ~getenv:(Cap_sys.getenv_opt ~caps) ~read ~source
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

(* One request to the service and its decoded reply; an error is the exit status to
   return after saying what went wrong. *)
let exchange ~caps ~send ~config ~socket request =
  match service_socket ~caps ~config ~socket with
  | Error why -> Error (report ~caps "config-invalid" why)
  | Ok path -> (
      let detail = obj [ ("socket", str path) ] in
      let unreachable () =
        Error
          (report ~caps ~detail "service-unreachable"
             ("cannot reach the Leash service at " ^ path))
      in
      let denied () =
        Error
          (report ~caps ~detail "socket-permission"
             ("cannot access the control socket at " ^ path))
      in
      try
        let raw = Yojson.Safe.from_string (send path request) in
        match P.decode_reply raw with
        | Error _ ->
            Error
              (report ~caps ~detail "invalid-response"
                 "the service returned an invalid reply")
        | Ok reply -> Ok reply
      with
      | Unix.Unix_error ((Unix.EACCES | Unix.EPERM), _, _) -> denied ()
      | Eio.Io (Eio.Fs.E (Eio.Fs.Permission_denied _), _) -> denied ()
      | Unix.Unix_error _ | Eio.Io _ | End_of_file -> unreachable ()
      | Eio.Time.Timeout ->
          Error (report ~caps ~detail "timeout" "the service request timed out")
      | Yojson.Json_error _ | Eio.Buf_read.Buffer_limit_exceeded ->
          Error
            (report ~caps ~detail "invalid-response"
               "the service returned unreadable JSON"))

let owner_of ~caps ~owner =
  match owner with
  | Some owner when String.trim owner <> "" -> Some owner
  | Some _ | None ->
      Option.bind (Cap_sys.getenv_opt ~caps "DSH_SESSION_ID") (fun id ->
          if id = "" then None else Some ("dsh:" ^ id))

let rec perform ~caps ~send command fields positionals options =
  match (command, positionals) with
  (* hard-xg6y hard-ovbx hard-vq5s: `net TAB` lists; `net TAB body ID` and `net TAB request
     ID` are commands of their own on the wire. *)
  | "net", [ tab; (("body" | "request") as part); id ] ->
      perform ~caps ~send ("net_" ^ part) [ "tab"; "id" ] [ tab; id ] options
  | "net", [ _; verb; _ ] -> usage ~caps ("net takes body or request, not " ^ verb)
  | "net", [ _; _ ] -> usage ~caps "net takes body ID or request ID after the tab"
  | "net", _ :: _ :: _ :: _ ->
      usage ~caps "net takes a tab, and optionally body or request with an ID"
  (* hard-o3za: the files are the trailing positionals. *)
  | "upload", tab :: snapshot :: index :: (_ :: _ as paths) ->
      perform_wire ~caps ~send command
        [ "tab"; "snapshot"; "index" ]
        [ tab; snapshot; index ]
        (Some ("paths", `List (List.map str paths)) :: options)
  | _ -> perform_wire ~caps ~send command fields positionals options

and perform_wire ~caps ~send command fields positionals options =
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
  if use_table && pretty then usage ~caps "--table and --pretty cannot both be given"
  else
    match owner_of ~caps ~owner:(text "owner") with
    | None -> usage ~caps "set --owner or DSH_SESSION_ID"
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
        | Error why -> usage ~caps why
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
            | Error why -> usage ~caps why
            | Ok options -> (
                let options =
                  if command <> "wait" then options
                  else
                    let condition_names =
                      [ "url_prefix"; "text"; "index_gone"; "dialog"; "changed_since" ]
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
                | Error why -> usage ~caps why
                | Ok decoded -> (
                    match P.Owner.of_string owner with
                    | Error why -> usage ~caps why
                    | Ok owner -> (
                        let request = P.encode_request P.{ owner; command = decoded } in
                        match
                          exchange ~caps ~send ~config:(text "config")
                            ~socket:(text "socket") request
                        with
                        | Error status -> status
                        | Ok (P.Failure error) -> emit_error ~caps error
                        | Ok (P.Success body) ->
                            if use_table then table ~caps command body
                            else
                              Cap_stdlib.print_endline ~caps
                                (if pretty then Yojson.Safe.pretty_to_string body
                                 else Yojson.Safe.to_string body);
                            0)))))

(* svc-hi4f: the table is the CLI's contract. Every command names its positionals in the
   protocol's order — TAB, SNAPSHOT, INDEX — and lists exactly the options it takes, so
   `leash <command> --help` shows the whole call. The four shared options go on every
   command; --table only on the two that render one. *)
type option_kind = Str | Int | Float | Bool | Json | Strings | Pairs

(* [Strings] is the repeated mission-expectation option [leash run] will carry
   (run-4j1v), declared here so the command lands as one table entry once the Door's name
   is free. *)
type option_ = { name : string; kind : option_kind; docv : string; doc : string }
type positional = { field : string; docv : string; optional : bool; many : bool }

let opt name kind docv doc = { name; kind; docv; doc }

(* svc-hi4f run-4j1v: an option a caller repeats — the mission's own expectations — becomes
   one JSON array on the wire. *)
let opt_list name kind docv doc = { name; kind; docv; doc }
let pos field docv = { field; docv; optional = false; many = false }
let pos_opt field docv = { field; docv; optional = true; many = false }

(* hard-o3za: the trailing positionals, one or more (the files `upload` sets). *)
let pos_many field docv = { field; docv; optional = false; many = true }
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
  | Float ->
      Term.(
        const (Option.map (fun number -> (name, `Float number)))
        $ Arg.(value & opt (some float) None & arg_info))
  | Str ->
      Term.(
        const (Option.map (fun value -> (name, str value)))
        $ Arg.(value & opt (some string) None & arg_info))
  | Json ->
      Term.(
        const (Option.map (fun value -> (name, str value)))
        $ Arg.(value & opt (some string) None & arg_info))
  | Pairs ->
      (* extr-mp5z: --arg K=V, repeated, is the wire's `args` object of strings. *)
      Term.(
        const (fun pairs ->
            if pairs = [] then None
            else
              Some
                ( "args",
                  `Assoc (List.map (fun (key, value) -> (key, `String value)) pairs) ))
        $ Arg.(value & opt_all (pair ~sep:'=' string string) [] & arg_info))
  | Strings ->
      Term.(
        const (fun values ->
            if values = [] then None
            else Some (name, `List (List.map (fun value -> `String value) values)))
        $ Arg.(value & opt_all string [] & arg_info))

let positional_term positionals =
  List.fold_left
    (fun term (index, spec) ->
      let arg =
        if spec.many then
          Term.(
            const Fun.id
            $ Arg.(non_empty & pos_right (index - 1) string [] & info [] ~docv:spec.docv))
        else if spec.optional then
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

let command ~caps ~send ~run_owned ?wire name doc positionals options examples =
  let wire = Option.value ~default:name wire in
  let fields = List.map (fun spec -> spec.field) positionals in
  let collected =
    List.fold_left
      (fun term spec -> Term.(const (fun xs x -> xs @ [ x ]) $ term $ option_term spec))
      (Term.const []) options
  in
  Cmd.v
    (Cli_help.command_info name ~doc ~examples)
    Term.(
      const (fun args opts () ->
          run_owned (fun _sw ->
              protect ~caps (fun () -> perform ~caps ~send wire fields args opts)))
      $ positional_term positionals $ collected)

(* run-tcuz run-dbji run-ykq4: these authoring commands need no service. *)
let playbook_command ~caps ~send ~run_owned =
  let owned run = run_owned (fun _sw -> protect ~caps run) in
  let output ?code = function
    | Error message -> invalid_playbook ~caps message
    | Ok book ->
        Cap_stdlib.print_endline ~caps
          (Yojson.Safe.pretty_to_string (Leash.Playbook.inspect ?code book));
        0
  in
  let name = Arg.(required & pos 0 (some string) None & info [] ~docv:"NAME") in
  let file = Arg.(required & pos 0 (some string) None & info [] ~docv:"FILE") in
  let list =
    Cmd.v
      (Cli_help.local_info "list" ~doc:"List validated installed site playbooks."
         ~examples:[ "leash playbook list" ])
      Term.(
        const (fun () () ->
            owned (fun () ->
                match Leash.Playbook.list ~caps () with
                | Error message -> invalid_playbook ~caps message
                | Ok books ->
                    List.iter
                      (fun (book : Leash.Playbook.loaded) ->
                        Cap_stdlib.printf ~caps "%s\t%s\n" book.playbook.site
                          book.playbook.description)
                      books;
                    0))
        $ const ())
  in
  let show =
    Cmd.v
      (Cli_help.local_info "show"
         ~doc:
           "Show a named installed playbook: scripts, their text and resolved checkers."
         ~examples:[ "leash playbook show books.toscrape.com" ])
      Term.(
        const (fun name () () ->
            owned (fun () -> output ~code:true (Leash.Playbook.show ~caps name)))
        $ name $ const ())
  in
  (* extr-lslp: the local checks — the file resolves, no escape, `returns` well formed,
     expectations resolve — are the loader's; the syntax check needs a page, so an
     installed playbook (named, not a path) is sent to the service, which compiles each
     script in a blank tab of its own. *)
  let check =
    let collected =
      List.fold_left
        (fun term spec -> Term.(const (fun xs x -> xs @ [ x ]) $ term $ option_term spec))
        (Term.const []) shared_options
    in
    let target = Arg.(required & pos 0 (some string) None & info [] ~docv:"NAME|DIR") in
    let run target opts () =
      let options = List.filter_map Fun.id opts in
      let text key =
        match List.assoc_opt key options with Some (`String v) -> Some v | _ -> None
      in
      let installed = not (String.contains target '/') in
      match
        if installed then Leash.Playbook.show ~caps target
        else Leash.Playbook.load ~caps target
      with
      | Error message -> invalid_playbook ~caps message
      | Ok book -> (
          let local = match Leash.Playbook.inspect book with `Assoc f -> f | _ -> [] in
          let print syntax =
            Cap_stdlib.print_endline ~caps
              (Yojson.Safe.pretty_to_string (`Assoc (local @ [ ("syntax", syntax) ])))
          in
          if not installed then (
            print
              (str
                 "skipped: only an installed playbook (its name, not a path) is compiled");
            0)
          else if book.Leash.Playbook.scripts = [] then (
            print (`List []);
            0)
          else
            match owner_of ~caps ~owner:(text "owner") with
            | None -> usage ~caps "set --owner or DSH_SESSION_ID"
            | Some owner -> (
                match P.Owner.of_string owner with
                | Error why -> usage ~caps why
                | Ok owner -> (
                    let request =
                      P.encode_request
                        P.{ owner; command = Playbook_check { playbook = target } }
                    in
                    match
                      exchange ~caps ~send ~config:(text "config") ~socket:(text "socket")
                        request
                    with
                    | Error status -> status
                    | Ok (P.Failure error) -> emit_error ~caps error
                    | Ok (P.Success result) ->
                        let scripts =
                          match field "scripts" result with `List xs -> xs | _ -> []
                        in
                        if List.for_all (fun s -> field "ok" s = `Bool true) scripts then (
                          print (`List scripts);
                          0)
                        else
                          report ~caps
                            ~detail:(obj [ ("scripts", `List scripts) ])
                            "script-invalid"
                            "one or more playbook scripts did not compile")))
    in
    Cmd.v
      (Cli_help.command_info "check"
         ~doc:"Check local playbook data and, for an installed NAME, compile its scripts."
         ~examples:
           [
             "leash playbook check books.toscrape.com";
             "leash playbook check ./my-playbook";
           ])
      Term.(
        const (fun target opts () -> owned (fun () -> run target opts ()))
        $ target $ collected)
  in
  (* extr-mp5z: runs one script of an installed playbook on a tab's page; the service
     looks the script up by name, and nothing of it travels on the wire. *)
  let test =
    command ~caps ~send ~run_owned ~wire:"playbook_test" "test"
      "Run one playbook script on a tab and print its validated output."
      [ pos "script" "PLAYBOOK/SCRIPT" ]
      ([
         opt "tab" Str "TAB" "The tab whose page runs the script (required).";
         opt_list "arg" Pairs "K=V" "A string argument for the script (repeatable).";
       ]
      @ shared_options)
      [
        "leash playbook test books.toscrape.com/list_books --tab t_9xk";
        "leash playbook test shop/search --tab t_9xk --arg q=gpu --arg max=2000";
      ]
  in
  (* run-m0r8: the operator's one way to merge a proposal the planner wrote. The run
     writes proposals to XDG state and never touches a playbook; this command is the hand
     that accepts one, and it validates the merged playbook before it writes. *)
  let accept =
    Cmd.v
      (Cli_help.local_info "accept"
         ~doc:"Merge a proposed procedure into its site's playbook."
         ~examples:[ "leash playbook accept ~/.local/state/leash/proposed/shop.json" ])
      Term.(
        const (fun file () () ->
            owned (fun () ->
                match Leash.Playbook.accept ~caps file with
                | Error message -> invalid_playbook ~caps message
                | Ok accepted ->
                    Cap_stdlib.print_endline ~caps
                      (Yojson.Safe.pretty_to_string
                         (Leash.Playbook.yojson_of_accepted accepted));
                    0))
        $ file $ const ())
  in
  Cmd.group
    (Cli_help.command_info "playbook" ~doc:"Inspect, validate and grow site playbooks."
       ~examples:[ "leash playbook list"; "leash playbook check ./my-playbook" ])
    [ list; show; check; test; accept ]

let commands ~caps ~send ~run_owned =
  List.map
    (fun (name, doc, positionals, options, examples) ->
      command ~caps ~send ~run_owned name doc positionals (options @ shared_options)
        examples)
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
        [
          opt "argument" Json "JSON" "JSON value bound to argument in the expression.";
          opt "index" Int "N"
            "Call the expression as (argument, element), element being the row at index \
             N.";
          opt "snapshot" Str "SNAPSHOT" "The snapshot --index names (required with it).";
        ],
        [
          "leash eval t_9xk 'return document.title'";
          "leash eval t_9xk 'return element.getBoundingClientRect().width' --snapshot \
           s_3 --index 7";
        ] );
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
          opt "changed_since" Str "SNAPSHOT"
            "Until the page's loader or mutation counter differs from SNAPSHOT's.";
          opt "timeout" Int "MS" "Alias of --timeout-ms.";
          opt "timeout_ms" Int "MS"
            "Bound the wait in milliseconds (default 30000, max 3600000: one hour).";
        ],
        [
          "leash wait t_9xk --text Done --timeout-ms 5000";
          "leash wait t_9xk --changed-since s_3 --timeout-ms 600000";
        ] );
      ( "upload",
        "Set PATH... on the file input at INDEX of SNAPSHOT.",
        [
          pos "tab" "TAB";
          pos "snapshot" "SNAPSHOT";
          pos "index" "INDEX";
          pos_many "paths" "PATH";
        ],
        [],
        [ "leash upload t_9xk s_3 12 /home/me/report.pdf" ] );
      ( "hover",
        "Move the mouse to the row at INDEX of SNAPSHOT.",
        [ pos "tab" "TAB"; pos "snapshot" "SNAPSHOT"; pos "index" "INDEX" ],
        [],
        [ "leash hover t_9xk s_3 4" ] );
      ( "net",
        "List the tab's recent requests; `net TAB body ID` and `net TAB request ID` read \
         one.",
        [ pos "tab" "TAB"; pos_opt "part" "body|request"; pos_opt "id" "ID" ],
        [
          opt "match" Str "TEXT" "Keep requests whose URL contains TEXT.";
          opt "limit" Int "N" "The most recent N requests (default 100, at most 500).";
          opt "type" Str "TYPE"
            "Keep one resource type: xhr, fetch, document, script, ...";
        ],
        [
          "leash net t_9xk --type fetch --match /api/";
          "leash net t_9xk body 1000.5";
          "leash net t_9xk request 1000.5";
        ] );
      ( "cookies",
        "Read the cookies of the tab's URL, httpOnly included (read-only).",
        [ pos "tab" "TAB" ],
        [],
        [ "leash cookies t_9xk" ] );
      ( "storage",
        "Read the tab's local or session storage (read-only).",
        [ pos "tab" "TAB"; pos "area" "local|session" ],
        [],
        [ "leash storage t_9xk local" ] );
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
        "Drive MISSION through a playbook, or the single-goal operator when none fits.",
        [ pos "mission" "MISSION" ],
        [
          opt "tab" Str "TAB" "Reuse TAB instead of opening one.";
          opt "max_procedures" Int "N" "At most N procedures (default 40).";
          opt "out" Str "FILE" "Stream collected records to FILE as JSONL.";
          opt "deadline_s" Int "S" "Seconds for the whole run (default 900).";
          opt "dry_run" Bool "" "Ask the two levels and report; never act.";
          opt_list "expect" Strings "SENTENCE"
            "Mission expectation the DONE guard verifies (repeatable).";
        ],
        [
          "leash drive 'Buy a Logitech MX Master 3S on allegro.pl' --deadline-s 300";
          "leash drive 'Add Blue Top to the cart' --expect 'the page is cart' --dry-run";
        ] );
      ( "discover",
        "Explore SITE with the planner; write a proposed playbook without applying it.",
        [ pos "site" "SITE-OR-URL" ],
        [
          opt "goal" Str "TEXT" "What to learn (default: explore this site).";
          opt "max_turns" Int "N" "At most N planner turns (default 20).";
          opt "max_steps" Int "N" "At most N operator steps (default 100).";
          opt "deadline_s" Int "S" "Seconds for discovery (default 900).";
          opt "max_cost" Float "USD" "Reported model cost cap in USD (default 1).";
        ],
        [ "leash discover https://example.com --goal 'Find the documentation'" ] );
    ]
  @ [ playbook_command ~caps ~send ~run_owned ]

let ( let* ) = Result.bind

let program env (config : Leash.Config.t) sw =
  let base = env.Ox_app.Env.base in
  (* Test-only: the live-acceptance gate shortens the sweep period through
     LEASH_SWEEP_INTERVAL_S so stage 1 then stage 2 are observable on a real clock in
     seconds; production always uses the 30 s contract default. A bad value fails fast,
     before Chrome launches, rather than silently changing the cadence. *)
  let* sweep_interval =
    match Cap_sys.getenv_opt ~caps:env.Ox_app.Env.caps "LEASH_SWEEP_INTERVAL_S" with
    | None | Some "" -> Ok None
    | Some text -> (
        match int_of_string_opt (String.trim text) with
        | Some n when n > 0 -> Ok (Some (Ox.Duration.seconds n))
        | Some _ | None ->
            Error (`Service "LEASH_SWEEP_INTERVAL_S must be a positive integer"))
  in
  (* svc-x8rp: the default profile is [$XDG_DATA_HOME/leash/profile], which a first run
     has not created; the owner makes it 0700 before Chrome starts, the way the listener
     makes its own runtime directory. The validator accepted what it can create. *)
  let* () =
    match
      Leash.Config.ensure_dir ~caps:env.caps
        (Leash.Config.Text.to_string config.chrome.profile_dir)
    with
    | Ok () -> Ok ()
    | Error message ->
        Error (`Service ("cannot create the profile directory: " ^ message))
  in
  let chrome =
    Leash.Chrome.create ~sw
      (Leash.Config.chrome_config config.chrome)
      {
        Leash.Chrome.clock = base#clock;
        mgr = base#process_mgr;
        logger = env.logger;
        (* ^ncaps-4tjy: the powerbox narrowed by ascription to what Chrome may touch. *)
        caps = (env.caps :> Leash.Chrome.caps);
      }
  in
  (* own-vhqo: the two expiry durations are config. The registry counts every tab down
     to them and the sweep applies them. *)
  let seconds duration = Ox.Duration.seconds (Leash.Config.Seconds.to_int duration) in
  let idle = seconds config.expiry.idle_s in
  let unclaimed = seconds config.expiry.unclaimed_s in
  (* hand-04rb hand-phof hand-rg9h: the two human-facing commands a handoff runs go through
     Ox's child process, and the registry turns whatever they report into warnings. *)
  let desktop =
    Leash.Desktop.create
      ~caps:(env.caps :> Leash.Desktop.caps)
      ~clock:base#clock ~mgr:base#process_mgr
      {
        Leash.Desktop.focus_command = config.handoff.focus_command;
        notify_command = config.handoff.notify_command;
      }
  in
  let download_dir =
    Filename.concat (Leash.Config.Text.to_string config.chrome.profile_dir) "downloads"
  in
  let* () =
    match Leash.Config.ensure_dir ~caps:env.caps download_dir with
    | Ok () -> Ok ()
    | Error message -> Error (`Service ("cannot create downloads directory: " ^ message))
  in
  let tabs =
    Leash.Tabs.create ~sw ~download_dir
      ~cap:(Leash.Config.Tab_cap.to_int config.tabs.cap)
      ~tombstone_s:(Leash.Config.Seconds.to_int config.expiry.tombstone_s)
      ~idle ~unclaimed
      {
        Leash.Tabs.chrome;
        clock = base#clock;
        logger = env.logger;
        desktop;
        caps = (env.caps :> Leash.Tabs.caps);
      }
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
  let status_query = Ox_app.status_query [ (fun () -> Leash.Tabs.status tabs) ] in
  (* svc-o4wt: the listener owns the configured socket path; validation refused anything
     that is not a real absolute path, so the variable is resolved by now. *)
  let socket = Leash.Config.Text.to_string config.control.socket in
  let* _control =
    Leash.Control.create
      ~model:(Leash.Config.Text.to_string config.models.jev_model)
        (* run-7blx: the run's three upper levels over the same one models service — the
           playbook question, the procedure question and the judgment score — and L31's
           planner stub inside them. *)
      ~levels:(Leash.Models.levels models)
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
        caps = (env.caps :> Leash.Control.caps);
      }
    |> Result.map_error (fun _ -> `Service "control socket acquisition failed")
  in
  Ox_app.serve ~sw ()

(* svc-x8rp: `leash config init` writes the commented default file. It is a Door subcommand
   of `config` (napp-wf22), not an ordinary command: it needs no service and sends no
   request, only the path the Door reads — which is exactly the file it writes — so
   --config and its XDG resolution stay the Door's. *)
let init_command ~caps =
  let config_file =
    Arg.(
      value
      & opt (some string) None
      & info [ "config" ] ~docv:"FILE" ~doc:"TOML configuration file to write.")
  in
  let force = Arg.(value & flag & info [ "force" ] ~doc:"Overwrite an existing file.") in
  let run config_file force () =
    let path =
      Ox_app.Config.path ~name:"leash" ~config:config_file
        ~getenv:(Cap_sys.getenv_opt ~caps)
    in
    match Leash.Config.init ~caps ~force ~path () with
    | Ok path ->
        Cap_stdlib.print_endline ~caps path;
        0
    | Error (`Exists path) ->
        usage ~caps (path ^ " already exists; pass --force to overwrite it")
    | Error (`Write error) when error.permission ->
        report ~caps
          ~detail:(obj [ ("path", str error.path) ])
          "permission-denied"
          ("cannot write configuration to " ^ error.path)
    | Error (`Write _) ->
        failure ~caps
          ("cannot write configuration to " ^ path
         ^ "; check its parent directory and permissions")
  in
  Cmd.v
    (Cli_help.local_info "init" ~doc:"Write a commented default configuration file."
       ~examples:[ "leash config init"; "leash config init --config /tmp/leash.toml" ])
    Term.(
      const (fun config_file force () ->
          protect ~caps (fun () -> run config_file force ()))
      $ config_file $ force)

let telemetry ~sw env config =
  match config.Leash.Config.otlp.endpoint with
  | None -> { Ox_app.reporters = []; span_ids = None }
  | Some endpoint ->
      Leash.Telemetry.create ~caps:env.Ox_app.Env.caps ~sw ~net:env.Ox_app.Env.base#net
        ~clock:env.Ox_app.Env.base#clock
        ~endpoint:(Leash.Config.Text.to_string endpoint)
        ~headers:
          (List.map
             (fun (header : Leash.Config.otlp_header) ->
               ( Leash.Config.Text.to_string header.name,
                 Leash.Config.Redact.expose header.value ))
             config.otlp.headers)

(* daily-azxe: the Door owns parsing, config and defects; it classifies each complete
   diagnostic before this formatter produces one JSON record. Never expose Cause.pp. *)
let problem_json (problem : Ox_app.validation_error) =
  obj [ ("pointer", str problem.pointer); ("message", str problem.message) ]

let decode_config env json =
  match
    Leash.Config.decode_all
      ~getenv:(Cap_sys.getenv_opt ~caps:env.Ox_app.Env.caps)
      ~fs:env.Ox_app.Env.base#fs json
  with
  | Ok config -> Ok config
  | Error problems ->
      Error (Yojson.Safe.to_string (`List (List.map problem_json problems)))

let diagnostic ~config_path ~kind ~message =
  let message = String.trim message in
  let record =
    match kind with
    | `Usage ->
        make_error
          ~detail:(obj [ ("diagnostic", str message) ])
          "cli-parse" "invalid command line; the command did not run"
    | `Defect ->
        make_error "internal"
          "the command failed unexpectedly; no successful result was produced"
    | `Config | `Validation -> (
        match
          try P.error_of_yojson (Yojson.Safe.from_string message)
          with _ -> Error "not an error record"
        with
        | Ok error -> error
        | Error _ ->
            let location =
              match config_path with None -> [] | Some path -> [ ("config", str path) ]
            in
            let problems =
              match try Some (Yojson.Safe.from_string message) with _ -> None with
              | Some (`List problems) -> [ ("problems", `List problems) ]
              | _ -> []
            in
            let message =
              if problems = [] then message
              else "invalid configuration; fix the reported problems"
            in
            let message =
              match config_path with
              | None -> message
              | Some path -> path ^ ": " ^ message
            in
            make_error ~detail:(obj (location @ problems)) "config-invalid" message)
  in
  Yojson.Safe.to_string (P.yojson_of_error record) ^ "\n"

let help_command ~caps =
  let topic = Arg.(value & pos 0 (some string) None & info [] ~docv:"TOPIC") in
  let run topic () =
    match topic with
    | Some "errors" ->
        Cap_stdlib.print_endline ~caps P.error_help;
        0
    | None ->
        Cap_stdlib.print_endline ~caps
          "Use leash --help, leash COMMAND --help, or leash help errors.";
        0
    | Some _ ->
        usage ~caps "unknown help topic; run leash help errors or leash COMMAND --help"
  in
  Cmd.v
    (Cli_help.local_info "help"
       ~doc:"Discover help topics without contacting the service."
       ~examples:[ "leash help errors"; "leash click --help" ])
    Term.(const run $ topic)

(* daily-k9cs: a bounded read-only probe, not config loading followed by service start. *)
let orientation env () =
  let caps = env.Ox_app.Env.caps in
  let state =
    match service_socket ~caps ~config:None ~socket:None with
    | Error _ -> "unknown (run leash config check)"
    | Ok path -> (
        try
          let response =
            send ~timeout_s:0.25 ~base:env.Ox_app.Env.base path
              (obj
                 [ ("owner", str "orientation"); ("cmd", str "status"); ("args", obj []) ])
          in
          match P.decode_reply (Yojson.Safe.from_string response) with
          | Ok (P.Success _) -> "running"
          | Ok (P.Failure _) -> "reachable, but not healthy (run leash status)"
          | Error _ -> "reachable, but returned an invalid reply"
        with
        | Eio.Cancel.Cancelled _ as exn -> raise exn
        | _ -> "unreachable")
  in
  Cap_stdlib.printf ~caps
    "Leash: local managed Chrome for agents.\n\
     Service: %s\n\
     Start: systemctl --user start leash\n\
     Begin: leash status; leash new https://example.com; leash snap TAB\n\
     Set --owner NAME or DSH_SESSION_ID. Help: leash --help; leash COMMAND --help; leash \
     help errors\n"
    state;
  0

(* ^ncaps-4tjy: only the Door mints; its owned-code runner preserves each command's
   classified exit code and owns cancellation and finalizers. *)
let () =
  let config_path = ref None in
  let read_file base path =
    config_path := Some path;
    match Ox_app.Config.read_regular ~max_bytes:1_048_576 Eio.Path.(base#fs / path) with
    | Error (`Unreadable _) ->
        Error
          (`Unreadable
             "cannot read a regular configuration file within the 1 MiB limit; check the \
              path and permissions")
    | result -> result
  in
  let diagnostic ~kind ~message = diagnostic ~config_path:!config_path ~kind ~message in
  exit
    (Ox_app.run_with_args ~name:"leash" ~service_command:"serve" ~config:Leash.Config.spec
       ~service_args:(Term.const ())
       ~bare:(`Command (fun env -> Term.const (orientation env)))
       ~doc:"A local managed Chrome for agents." ~man:Cli_help.top_man
       ~exits:Cli_help.all_exits ~usage_exit:124 ~validation_exit:65 ~defect_exit:70
       ~exit_code:(fun _ -> 70)
       ~diagnostic ~read_file ~decode_with_env:decode_config
       ~journal_level:Ox_observability.Logger.Warn
       ~commands_with_env_code:(fun env _run_owned run_owned_code ->
         let caps = env.Ox_app.Env.caps in
         let send path request = send ~base:env.Ox_app.Env.base path request in
         commands ~caps ~send ~run_owned:run_owned_code @ [ help_command ~caps ])
       ~telemetry
       ~config_commands_with_env:(fun env -> [ init_command ~caps:env.Ox_app.Env.caps ])
       ~validate:Leash.Config.validate
       ~pp_err:(fun fmt (`Service _) ->
         Format.pp_print_string fmt
           (Yojson.Safe.to_string
              (P.yojson_of_error
                 (make_error "internal"
                    "the Leash service failed to start or stopped unexpectedly"))))
       (fun env _source config () sw -> program env config sw))
