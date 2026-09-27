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

let perform command fields owner pretty use_table positionals options =
  let expected = List.length fields in
  let actual = List.length positionals in
  if (command = "new" && actual > 1) || (command <> "new" && actual <> expected) then
    usage
      (Printf.sprintf "%s expects %d positional argument(s), got %d" command expected
         actual)
  else if use_table && (pretty || not (List.mem command [ "list"; "snap" ])) then
    usage "--table is only available for list/snap and conflicts with --pretty"
  else
    let owner =
      match owner with
      | Some s when String.trim s <> "" -> Some s
      | Some _ -> None
      | None ->
          Option.bind (Sys.getenv_opt "DSH_SESSION_ID") (fun id ->
              if id = "" then None else Some ("dsh:" ^ id))
    in
    match (owner, Sys.getenv_opt "XDG_RUNTIME_DIR") with
    | None, _ -> usage "set --owner or DSH_SESSION_ID"
    | _, None -> failure "XDG_RUNTIME_DIR is unset"
    | _, Some "" -> failure "XDG_RUNTIME_DIR is empty"
    | Some owner, Some runtime -> (
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
                     (List.filter_map Fun.id options))
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
                        let path =
                          Filename.concat (Filename.concat runtime "leash") "control.sock"
                        in
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
                        | Yojson.Json_error msg -> failure ("invalid JSON reply: " ^ msg)
                        | End_of_file -> failure "service closed without a reply")))))

type option_kind = Str | Int | Bool | Json

let option_term (name, kind) =
  let doc = "Optional " ^ String.map (fun c -> if c = '_' then ' ' else c) name ^ "." in
  match kind with
  | Bool ->
      Term.(
        const (fun b -> if b then Some (name, `Bool true) else None)
        $ Arg.(
            value & flag
            & info [ String.map (fun c -> if c = '_' then '-' else c) name ] ~doc))
  | Int ->
      Term.(
        const (Option.map (fun n -> (name, `Int n)))
        $ Arg.(
            value
            & opt (some int) None
            & info
                [ String.map (fun c -> if c = '_' then '-' else c) name ]
                ~docv:"N" ~doc))
  | Str ->
      Term.(
        const (Option.map (fun s -> (name, str s)))
        $ Arg.(
            value
            & opt (some string) None
            & info
                [ String.map (fun c -> if c = '_' then '-' else c) name ]
                ~docv:"TEXT" ~doc))
  | Json ->
      Term.(
        const (Option.map (fun text -> (name, str text)))
        $ Arg.(
            value
            & opt (some string) None
            & info
                [ String.map (fun c -> if c = '_' then '-' else c) name ]
                ~docv:"JSON" ~doc))

let owner =
  Arg.(
    value
    & opt (some string) None
    & info [ "owner" ] ~docv:"NAME" ~doc:"Request owner (default dsh:$DSH_SESSION_ID).")

let pretty = Arg.(value & flag & info [ "pretty" ] ~doc:"Indent JSON output.")
let use_table = Arg.(value & flag & info [ "table" ] ~doc:"Show list/snap in a table.")
let args = Arg.(value & pos_all string [] & info [] ~docv:"ARG")

let command name doc fields options =
  let collected =
    List.fold_left
      (fun term spec -> Term.(const (fun xs x -> xs @ [ x ]) $ term $ option_term spec))
      (Term.const []) options
  in
  Cmd.v (Cmd.info name ~doc)
    Term.(
      const (fun owner pretty use_table args opts () ->
          perform name fields owner pretty use_table args opts)
      $ owner $ pretty $ use_table $ args $ collected)

let commands =
  [
    command "new" "Open an agent-owned tab." [ "url" ] [];
    command "list" "List tabs owned by this caller." [] [ ("all", Bool) ];
    command "claim" "Claim a tab." [ "tab" ] [];
    command "release" "Release a tab (own tab; --force for any)." [ "tab" ]
      [ ("force", Bool) ];
    command "close" "Close a tab (own tab; --force for any)." [ "tab" ]
      [ ("force", Bool) ];
    command "status" "Report browser health." [] [];
    command "snap" "Observe an indexed snapshot." [ "tab" ]
      [ ("match", Str); ("limit", Int); ("offset", Int) ];
    command "text" "Extract page text." [ "tab" ] [ ("index", Int); ("max_chars", Int) ];
    command "shot" "Write a screenshot." [ "tab"; "path" ] [ ("full_page", Bool) ];
    command "debug" "Show page diagnostics." [ "tab" ] [ ("limit", Int); ("clear", Bool) ];
    command "eval" "Evaluate a bounded expression." [ "tab"; "expression" ]
      [ ("argument", Json) ];
    command "nav" "Navigate to a URL." [ "tab"; "url" ] [];
    command "click" "Click a snapshot row." [ "tab"; "snapshot"; "index" ] [];
    command "fill" "Fill a snapshot row." [ "tab"; "snapshot"; "index"; "text" ] [];
    command "press" "Press a key." [ "tab"; "snapshot"; "key" ] [ ("index", Int) ];
    command "select" "Choose a select option." [ "tab"; "snapshot"; "index"; "option" ] [];
    command "scroll" "Scroll a page or row." [ "tab"; "direction" ] [ ("index", Int) ];
    command "wait" "Wait for page conditions." [ "tab" ]
      [
        ("until", Json);
        ("url_prefix", Str);
        ("text", Str);
        ("index_gone", Int);
        ("dialog", Bool);
        ("timeout", Int);
        ("timeout_ms", Int);
      ];
    command "dialog" "Answer a page dialog." [ "tab"; "answer" ] [ ("text", Str) ];
    command "handoff" "Hand a tab to the human." [ "tab"; "reason" ]
      [ ("timeout_s", Int) ];
    command "resume" "Resume the handed-off tab." [ "tab" ] [];
    command "drive" "Drive a tab toward a goal." [ "tab"; "goal" ]
      [ ("max_steps", Int); ("deadline_s", Int) ];
  ]

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
    Leash.Desktop.create ~clock:base#clock
      ~runner:(Leash.Desktop.process_runner ~clock:base#clock ~mgr:base#process_mgr)
      {
        Leash.Desktop.focus_command = config.handoff.focus_command;
        notify_command = config.handoff.notify_command;
      }
  in
  let tabs =
    Leash.Tabs.create ~sw
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
  Eio.Switch.on_release sw (fun () -> Leash.Tabs.stop tabs);
  let status_query = Eta_app.status_query [ (fun () -> Leash.Tabs.status tabs) ] in
  let runtime_dir = Option.value ~default:"" (Sys.getenv_opt "XDG_RUNTIME_DIR") in
  let* _control =
    Leash.Control.create ~sw ~runtime_dir
      {
        Leash.Control.tabs;
        status_query;
        fs = base#fs;
        net = base#net;
        clock = base#clock;
        logger = env.logger;
      }
    |> Result.map_error (fun _ -> `Service "control socket acquisition failed")
  in
  Eta_app.serve ~sw ()

let () =
  exit
    (Eta_app.run ~name:"leash" ~config:Leash.Config.spec ~commands
       ~validate:Leash.Config.validate
       ~pp_err:(fun fmt (`Service msg) -> Format.pp_print_string fmt msg)
       program)
