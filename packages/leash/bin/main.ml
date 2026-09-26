open Cmdliner
module P = Leash.Protocol
module J = Eta_schema.Json

let obj xs = Result.get_ok (J.object_ xs)
let str s = Result.get_ok (J.string s)

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

let json_value = function
  | Some value -> Eta_schema_yojson.to_yojson value
  | None -> `Null

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
      print_endline "TAB\tURL\tTITLE\tOWNER\tSTATE";
      List.iter
        (fun row ->
          Printf.printf "%s\t%s\t%s\t%s\t%s\n"
            (cell (field "tab" row))
            (cell (field "url" row))
            (cell (field "title" row))
            (cell (field "owner" row))
            (cell (field "state" row)))
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
            | Some number -> Ok (key, J.int number)
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
            let options = List.filter_map Fun.id options in
            let options =
              try
                Ok
                  (List.map
                     (fun (key, value) ->
                       if List.mem key [ "argument"; "until" ] then
                         match value with
                         | J.String text ->
                             ( key,
                               Result.get_ok
                                 (Eta_schema_yojson.of_yojson
                                    (Yojson.Safe.from_string text)) )
                         | _ -> assert false
                       else (key, value))
                     options)
              with Yojson.Json_error why -> Error ("invalid JSON option: " ^ why)
            in
            match options with
            | Error why -> usage why
            | Ok options -> (
                let args = obj (fields @ options) in
                let request = P.{ v = 1; owner; cmd = command; args } in
                match P.encode_request request with
                | Error issues -> usage (Eta_schema.render_issues issues)
                | Ok request -> (
                    let path =
                      Filename.concat (Filename.concat runtime "leash") "control.sock"
                    in
                    try
                      let raw = Yojson.Safe.from_string (send path request) in
                      match P.decode_reply raw with
                      | Error issues ->
                          failure
                            ("invalid service reply: " ^ Eta_schema.render_issues issues)
                      | Ok reply ->
                          let body =
                            if reply.ok then json_value reply.result
                            else
                              match reply.error with
                              | Some error -> (
                                  match
                                    Eta_schema_yojson.encode_result P.error_schema error
                                  with
                                  | Ok json -> json
                                  | Error _ -> assert false)
                              | None -> assert false
                          in
                          if use_table && reply.ok then table command body
                          else
                            print_endline
                              (if pretty then Yojson.Safe.pretty_to_string body
                               else Yojson.Safe.to_string body);
                          if reply.ok then 0 else 1
                    with
                    | Unix.Unix_error (code, _, _) -> failure (Unix.error_message code)
                    | Eio.Io _ as err -> failure (Printexc.to_string err)
                    | Yojson.Json_error msg -> failure ("invalid JSON reply: " ^ msg)
                    | End_of_file -> failure "service closed without a reply"))))

type option_kind = Str | Int | Bool | Json

let option_term (name, kind) =
  let doc = "Optional " ^ String.map (fun c -> if c = '_' then ' ' else c) name ^ "." in
  match kind with
  | Bool ->
      Term.(
        const (fun b -> if b then Some (name, J.bool true) else None)
        $ Arg.(
            value & flag
            & info [ String.map (fun c -> if c = '_' then '-' else c) name ] ~doc))
  | Int ->
      Term.(
        const (Option.map (fun n -> (name, J.int n)))
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
    command "release" "Release a tab." [ "tab" ] [];
    command "close" "Close a tab." [ "tab" ] [];
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
      [ ("until", Json); ("timeout_ms", Int) ];
    command "dialog" "Answer a page dialog." [ "tab"; "answer" ] [ ("text", Str) ];
    command "handoff" "Hand a tab to the human." [ "tab"; "reason" ]
      [ ("timeout_s", Int) ];
    command "resume" "Resume the handed-off tab." [ "tab" ] [];
    command "drive" "Drive a tab toward a goal." [ "tab"; "goal" ]
      [ ("max_steps", Int); ("deadline_s", Int) ];
  ]

let ( let* ) = Result.bind

let program _env (_config : Leash.Config.t) sw =
  (* L3 replaces this placeholder with Chrome.create, Tabs.create, status_query,
     Control.create, then Eta_app.serve. Keep the acquisition chain visible. *)
  let* () = Ok () in
  Eta_app.serve ~sw ()

let () =
  exit
    (Eta_app.run ~name:"leash" ~config:Leash.Config.schema ~commands
       ~validate:(fun env config ->
         Leash.Config.validate_paths ~fs:env.base#fs config
         |> Result.map_error
              (List.map (fun (issue : Leash.Config.validation_error) ->
                   ({ pointer = issue.pointer; message = issue.message }
                     : Eta_app.validation_error))))
       ~pp_err:(fun fmt (`Config msg) -> Format.pp_print_string fmt msg)
       program)
