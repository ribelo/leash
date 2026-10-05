(* daily-azxe daily-3bwr daily-u1k2: a private one-request protocol peer and
   strict stream assertions. No Chrome or installed service is started. *)
module P = Leash.Protocol

let read_file ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
  Ox_caps.Cap_stdlib.In_channel.with_open_bin ~caps path In_channel.input_all

let serve ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) path code ready =
  let socket = Ox_caps.Cap_unix.socket ~caps Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      Unix.close socket;
      Ox_caps.Cap_unix.unlink ~caps path)
    (fun () ->
      Unix.bind socket (Unix.ADDR_UNIX path);
      Unix.listen socket 1;
      Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps ready (fun out ->
          output_string out "ready");
      let client, _ = Unix.accept socket in
      let input = Unix.in_channel_of_descr client in
      let output = Unix.out_channel_of_descr client in
      ignore (input_line input);
      let response =
        if code = "invalid-response" then "not json"
        else if code = "invalid-envelope" then
          "{\"error\":{\"code\":\"mystery\",\"message\":\"unexpected\"}}"
        else if code = "success" then
          Yojson.Safe.to_string
            (P.encode_reply (P.Success (`Assoc [ ("fixture", `Bool true) ])))
        else
          let code = Result.get_ok (P.Error_code.of_string code) in
          let error = P.make_error code ~message:"fixture failure" in
          Yojson.Safe.to_string (P.encode_reply (P.Failure error))
      in
      output_string output (response ^ "\n");
      flush output;
      Unix.close client)

let inspect ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) expected status
    stdout stderr =
  let fail message = failwith (expected ^ ": " ^ message) in
  if read_file ~caps stdout <> "" then fail "failure wrote to stdout";
  let raw = read_file ~caps stderr in
  if raw = "" || raw.[String.length raw - 1] <> '\n' then fail "missing JSON line";
  let line = String.sub raw 0 (String.length raw - 1) in
  if String.contains line '\n' then fail "more than one stderr record";
  let error =
    match P.error_of_yojson (Yojson.Safe.from_string line) with
    | Ok error -> error
    | Error message -> fail message
  in
  if P.Error_code.to_string error.code <> expected then fail "wrong code";
  if P.Error_code.exit_code error.code <> int_of_string status then
    fail "wrong exit class";
  if error.hint = "" || String.contains error.hint '\n' then fail "hint is not one line";
  Ox_caps.Cap_stdlib.printf ~caps "%s: exit %s, JSON-only stderr, hint, empty stdout\n"
    expected status

let contains text fragment =
  let n = String.length fragment in
  let rec loop i =
    i + n <= String.length text && (String.sub text i n = fragment || loop (i + 1))
  in
  loop 0

let config_details ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path stderr
    =
  let raw = read_file ~caps stderr in
  List.iter
    (fun fragment ->
      if not (contains raw fragment) then
        failwith ("missing config diagnostic " ^ fragment))
    [ path; "/chrome/headless"; "/expiry/idle_s"; "/control/socket"; "/tabs/cap" ];
  Ox_caps.Cap_stdlib.print_endline ~caps "config path and all four problems are present"

let check_help ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
  let text = read_file ~caps path in
  List.iter
    (fun heading ->
      if not (contains text heading) then failwith ("missing help heading " ^ heading))
    [ "EXAMPLES"; "EXIT STATUS"; "124" ];
  if not (contains text "leash ") then failwith "help has no concrete example"

let top_help ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path =
  let text = read_file ~caps path in
  List.iter
    (fun heading ->
      if not (contains text heading) then failwith ("missing command group " ^ heading))
    [
      "TABS";
      "OBSERVE";
      "ACT";
      "NETWORK AND DEBUG";
      "MISSIONS";
      "SERVICE";
      "SKILL";
      "take";
      "human tabs are never closed unless an agent takes one";
    ];
  Ox_caps.Cap_stdlib.print_endline ~caps
    "top-level help groups tabs, observe, act, network/debug, missions, service and skill"

let error_help ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path =
  let actual = read_file ~caps path in
  if contains actual "\x1b" then failwith "help errors contains ANSI";
  List.iter
    (fun code ->
      let name = P.Error_code.to_string code in
      let exit = string_of_int (P.Error_code.exit_code code) in
      if not (contains actual name) then failwith (name ^ " missing from help errors");
      if not (contains actual exit) then failwith (name ^ " exit missing from help errors");
      if not (contains actual (P.Error_code.meaning code)) then
        failwith (name ^ " meaning missing from help errors");
      if not (contains actual (P.Error_code.hint code)) then
        failwith (name ^ " hint missing from help errors"))
    P.Error_code.all;
  Ox_caps.Cap_stdlib.printf ~caps
    "all %d error codes, exit classes, meanings and hints are discoverable\n"
    (List.length P.Error_code.all)

let help_topics ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path =
  let text = read_file ~caps path in
  List.iter
    (fun topic ->
      if not (contains text topic) then failwith ("help list missing " ^ topic))
    [ "handles"; "drive"; "errors"; "traces" ];
  (* hdoc-vqj7: each offline topic has a useful one-line description. *)
  String.split_on_char '\n' text
  |> List.filter (fun line -> String.trim line <> "")
  |> List.iter (fun line ->
      match String.split_on_char '\t' line with
      | [ _topic; description ] when String.length description > 20 -> ()
      | _ -> failwith ("hdoc-vqj7 topic lacks a description: " ^ line));
  Ox_caps.Cap_stdlib.print_endline ~caps "help lists handles, drive, errors, traces"

let run_leash ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; .. >) args =
  let cmd = Filename.quote_command "leash" args in
  let channel = Ox_caps.Cap_unix.open_process_in ~caps cmd in
  let text = In_channel.input_all channel in
  match Unix.close_process_in channel with
  | Unix.WEXITED 0 -> text
  | Unix.WEXITED code ->
      failwith (Printf.sprintf "leash %s exited %d" (String.concat " " args) code)
  | _ -> failwith "leash help walk failed"

let is_option_line line =
  String.length line > 8
  && String.sub line 0 7 = "       "
  && line.[7] = '-'
  && line.[8] <> ' '

let option_name line =
  let trimmed = String.trim line in
  let stop =
    let rec go i =
      if i >= String.length trimmed then i
      else match trimmed.[i] with ' ' | '[' | '=' -> i | _ -> go (i + 1)
    in
    go 0
  in
  String.sub trimmed 0 stop

let option_docs text =
  let lines = String.split_on_char '\n' text in
  let options_section name = name = "OPTIONS" || name = "COMMON OPTIONS" in
  let rec go i inside acc =
    if i >= List.length lines then List.rev acc
    else
      let line = List.nth lines i in
      if line <> "" && line.[0] <> ' ' then go (i + 1) (options_section line) acc
      else if (not inside) || not (is_option_line line) then go (i + 1) inside acc
      else
        let rec doc j parts =
          if j >= List.length lines then (String.concat " " (List.rev parts), j)
          else
            let next = List.nth lines j in
            if next = "" || is_option_line next then
              (String.concat " " (List.rev parts), j)
            else doc (j + 1) (String.trim next :: parts)
        in
        let doc, next = doc (i + 1) [] in
        go next inside ((option_name line, String.trim doc) :: acc)
  in
  go 0 false []

let rec walk_command ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; .. >) prefix =
  let text = run_leash ~caps (prefix @ [ "--help=plain" ]) in
  List.iter
    (fun (name, doc) ->
      if doc = "" then
        failwith
          (Printf.sprintf "empty option doc: leash %s %s" (String.concat " " prefix) name))
    (option_docs text);
  let lines = String.split_on_char '\n' text in
  let commands =
    let rec go i acc =
      if i + 1 >= List.length lines then List.rev acc
      else
        let line = List.nth lines i in
        let next = List.nth lines (i + 1) in
        let trimmed = String.trim line in
        let is_cmd =
          String.length line > 7
          && String.sub line 0 7 = "       "
          && trimmed <> ""
          && trimmed.[0] <> '-'
          && (not (String.contains trimmed '/'))
          && String.length next > 11
          && String.sub next 0 11 = "           "
        in
        if not is_cmd then go (i + 1) acc
        else
          let name =
            match String.split_on_char ' ' trimmed with name :: _ -> name | [] -> ""
          in
          let ok =
            name <> ""
            && String.length name <= 32
            && String.for_all
                 (function 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false)
                 name
            && not (List.mem name acc)
          in
          if ok then go (i + 1) (name :: acc) else go (i + 1) acc
    in
    go 0 []
  in
  List.iter (fun name -> walk_command ~caps (prefix @ [ name ])) commands

let option_docs_file ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
  let text = read_file ~caps path in
  List.iter
    (fun (name, doc) -> if doc = "" then failwith ("empty option doc: " ^ name))
    (option_docs text)

let walk_options
    ~(caps : < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.stdout ; .. >) () =
  walk_command ~caps [];
  Ox_caps.Cap_stdlib.print_endline ~caps
    "every option on every command has a one-line doc"

let inspect_init ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path stdout
    stderr =
  if read_file ~caps stdout <> path ^ "\n" then
    failwith "config init changed its successful stdout";
  if read_file ~caps stderr <> "" then failwith "config init wrote to stderr";
  if read_file ~caps path <> Leash.Config.default_toml then
    failwith "config init changed the default file";
  Ox_caps.Cap_stdlib.print_endline ~caps "config init writes its path and empty stderr"

(* daily-yd8s daily-ulmi: inspect whole streams, not just a selected output line. *)
let skill_outcome ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) action path
    stdout stderr =
  let raw = read_file ~caps stdout in
  let expected = `Assoc [ ("action", `String action); ("path", `String path) ] in
  if Yojson.Safe.from_string raw <> expected then failwith "wrong skill outcome";
  if read_file ~caps stderr <> "" then failwith "skill success wrote to stderr";
  Ox_caps.Cap_stdlib.printf ~caps "%s: one JSON outcome, empty stderr\n" action

let skill_show ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) stdout stderr =
  let contents = read_file ~caps stdout in
  if contents <> Leash_cli_support.Skill_install.show then
    failwith "show is not the exact stamped entrypoint";
  List.iter
    (fun marker -> if not (contains contents marker) then failwith ("missing " ^ marker))
    [ "---\nname: leash\n"; "metadata:\n  leash-version:"; "\n  leash-commit:" ];
  if read_file ~caps stderr <> "" then failwith "show wrote to stderr";
  Ox_caps.Cap_stdlib.print_endline ~caps
    "show: exact bundled entrypoint, YAML version and commit stamp, empty stderr"

let serve_result ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) path result
    ready =
  let socket = Ox_caps.Cap_unix.socket ~caps Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      Unix.close socket;
      Ox_caps.Cap_unix.unlink ~caps path)
    (fun () ->
      Unix.bind socket (Unix.ADDR_UNIX path);
      Unix.listen socket 1;
      Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps ready (fun out ->
          output_string out "ready");
      let client, _ = Unix.accept socket in
      let input = Unix.in_channel_of_descr client in
      let output = Unix.out_channel_of_descr client in
      ignore (input_line input);
      let response = Yojson.Safe.to_string (P.encode_reply (P.Success result)) ^ "\n" in
      output_string output response;
      flush output;
      Unix.close client)

let field key json =
  match json with
  | `Assoc fields -> List.assoc key fields
  | _ -> failwith "expected an object"

let status_down ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) code stdout
    stderr =
  let raw = read_file ~caps stderr in
  if read_file ~caps stdout <> "" then failwith "status failure wrote stdout";
  let error =
    match P.error_of_yojson (Yojson.Safe.from_string (String.trim raw)) with
    | Ok error -> error
    | Error message -> failwith message
  in
  if P.Error_code.to_string error.code <> code then failwith "wrong status code";
  let detail =
    match error.detail with Some detail -> detail | None -> failwith "no detail"
  in
  let show name =
    match field name detail with
    | `Bool value -> Printf.sprintf "%s=%b" name value
    | `String value -> Printf.sprintf "%s=%s" name value
    | `Int value -> Printf.sprintf "%s=%d" name value
    | `Null -> name ^ "=null"
    | other -> name ^ "=" ^ Yojson.Safe.to_string other
  in
  let unit = show "unit" in
  let binary = show "binary" in
  if contains raw "sk-leash" || contains (read_file ~caps stdout) "sk-leash" then
    failwith "status printed a key";
  Ox_caps.Cap_stdlib.printf ~caps "%s: %s %s hint=%s\n" code unit binary error.hint

let status_restart ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) stdout
    stderr =
  let raw = read_file ~caps stderr in
  if read_file ~caps stdout <> "" then failwith "restarting status wrote stdout";
  let error =
    match P.error_of_yojson (Yojson.Safe.from_string (String.trim raw)) with
    | Ok error -> error
    | Error message -> failwith message
  in
  if P.Error_code.to_string error.code <> "service-restarting" then
    failwith "chrome relaunch was not service-restarting";
  let detail =
    match error.detail with Some detail -> detail | None -> failwith "no detail"
  in
  if field "chrome" detail <> `String "restarting" then failwith "chrome phase lost";
  if field "generation" detail <> `Int 4 then failwith "generation lost";
  if field "pid" detail <> `Null then failwith "relaunch kept a pid";
  if field "headed" detail <> `Bool true then failwith "headed lost";
  if field "key_present" detail <> `Bool false then failwith "key flag lost";
  if field "skill" detail = `Null then failwith "skill missing from restart detail";
  if contains raw "sk-leash" then failwith "restart detail printed a key";
  Ox_caps.Cap_stdlib.printf ~caps "service-restarting: chrome generation relaunch, %s\n"
    error.hint

let status_healthy ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) stdout
    stderr =
  let raw = read_file ~caps stdout in
  if read_file ~caps stderr <> "" then failwith "healthy status wrote stderr";
  let result = Yojson.Safe.from_string raw in
  if field "version" result <> `String Leash.version then failwith "wrong version";
  if field "commit" result <> `String Leash_cli_support.Leash_build_commit.commit then
    failwith "wrong commit";
  if field "chrome" result <> `String "running" then failwith "chrome not running";
  if field "generation" result <> `Int 7 then failwith "wrong generation";
  if field "pid" result <> `Int 4242 then failwith "wrong pid";
  if field "headed" result <> `Bool true then failwith "not headed";
  if field "key_present" result <> `Bool true then failwith "key not reported present";
  let models = field "models" result in
  if field "configured" models <> `Bool true then failwith "models.configured lost";
  let skill = field "skill" result in
  if field "state" skill <> `String "missing" then failwith "skill state lost";
  if contains raw "sk-leash" || contains raw "OPENROUTER" then
    failwith "status printed a key";
  Ox_caps.Cap_stdlib.printf ~caps
    "healthy: version %s chrome running generation 7 pid 4242 headed key_present skill %s\n"
    Leash.version
    (match field "state" skill with `String state -> state | _ -> "?")

let status_skill ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) state stdout
    stderr =
  let result = Yojson.Safe.from_string (read_file ~caps stdout) in
  let field key = function
    | `Assoc fields -> List.assoc key fields
    | _ -> failwith "expected an object"
  in
  let skill = field "skill" result in
  if field "state" skill <> `String state then failwith "wrong skill state";
  if field "version" skill <> `String Leash.version then failwith "wrong running version";
  if field "commit" skill <> `String Leash_cli_support.Leash_build_commit.commit then
    failwith "wrong running commit";
  if field "fixture" result <> `Bool true then failwith "lost successful service fields";
  if read_file ~caps stderr <> "" then failwith "status wrote to stderr";
  Ox_caps.Cap_stdlib.printf ~caps
    "status: skill %s, running version and commit, service fields retained\n" state

let capture ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network ; .. >) path
    request_file ready =
  let socket = Ox_caps.Cap_unix.socket ~caps Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      Unix.close socket;
      Ox_caps.Cap_unix.unlink ~caps path)
    (fun () ->
      Unix.bind socket (Unix.ADDR_UNIX path);
      Unix.listen socket 1;
      Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps ready (fun out ->
          output_string out "ready");
      let client, _ = Unix.accept socket in
      let input = Unix.in_channel_of_descr client in
      let output = Unix.out_channel_of_descr client in
      let request = input_line input in
      Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps request_file (fun out ->
          output_string out request;
          output_char out '\n');
      let response =
        Yojson.Safe.to_string
          (P.encode_reply (P.Success (`Assoc [ ("captured", `Bool true) ])))
      in
      output_string output (response ^ "\n");
      flush output;
      Unix.close client)

let drive_help ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path =
  let text = read_file ~caps path in
  List.iter
    (fun fragment ->
      if not (contains text fragment) then failwith ("drive help missing " ^ fragment))
    [
      "--url";
      "--max-steps";
      "(default 256)";
      "operator-state";
      "planner-record";
      "result: the file path";
      "EXAMPLES";
    ];
  Ox_caps.Cap_stdlib.print_endline ~caps
    "drive help: the takeover, a goal with its result, operator-state"

let drive_request ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.stdout ; .. >) path =
  let json = Yojson.Safe.from_string (String.trim (read_file ~caps path)) in
  if field "cmd" json <> `String "drive" then failwith "not a drive request";
  let args = field "args" json in
  let fields = match args with `Assoc fields -> fields | _ -> failwith "args" in
  if List.mem_assoc "url" fields then
    failwith "wire key url was not remapped to start_url";
  let show name =
    match List.assoc_opt name fields with
    | None -> "absent"
    | Some (`String text) -> text
    | Some (`Int n) -> string_of_int n
    | Some other -> Yojson.Safe.to_string other
  in
  let out =
    match List.assoc_opt "out" fields with
    | None -> "absent"
    | Some (`String text) when String.ends_with ~suffix:"out.jsonl" text ->
        if Filename.is_relative text then
          failwith "trace-qe8c relative output crossed the socket";
        "present"
    | Some _ -> "unexpected"
  in
  Ox_caps.Cap_stdlib.printf ~caps "mission=%s start_url=%s max_steps=%s tab=%s out=%s\n"
    (show "mission") (show "start_url") (show "max_steps") (show "tab") out

let main
    ~(caps :
       < Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.stdout
       ; .. >) () =
  match Array.to_list Sys.argv with
  | [ _; "serve"; path; code; ready ] -> serve ~caps path code ready
  | [ _; "inspect"; code; status; stdout; stderr ] ->
      inspect ~caps code status stdout stderr
  | [ _; "config-details"; path; stderr ] -> config_details ~caps path stderr
  | [ _; "check-help"; path ] -> check_help ~caps path
  | [ _; "top-help"; path ] -> top_help ~caps path
  | [ _; "list-help"; path ] ->
      let text =
        read_file ~caps path |> String.split_on_char '\n' |> List.map String.trim
        |> String.concat " "
      in
      let rule =
        "agent tabs close after 30 idle minutes; human tabs are never closed unless an \
         agent takes one"
      in
      if not (contains text rule) then failwith "hand-3v5u list help omits the tab rule";
      if contains text "--all" then failwith "list help still documents --all";
      Ox_caps.Cap_stdlib.print_endline ~caps
        "hand-3v5u list help states the tab rule and never shows handles"
  | [ _; "error-help"; path ] -> error_help ~caps path
  | [ _; "help-topics"; path ] -> help_topics ~caps path
  | [ _; "option-docs"; path ] -> option_docs_file ~caps path
  | [ _; "drive-help"; path ] -> drive_help ~caps path
  | [ _; "capture"; path; request_file; ready ] -> capture ~caps path request_file ready
  | [ _; "anonymous-request"; path ] ->
      let json = read_file ~caps path |> Yojson.Safe.from_string in
      let keys =
        match json with `Assoc f -> List.map fst f |> List.sort String.compare | _ -> []
      in
      if keys <> [ "args"; "cmd"; "v" ] then failwith "hand-scaz extra request fields";
      Ox_caps.Cap_stdlib.print_endline ~caps
        "hand-scaz only v, cmd and args, even in a harness environment"
  | [ _; "drive-request"; path ] -> drive_request ~caps path
  | [ _; "drive-relative-out"; path ] ->
      let json = read_file ~caps path |> String.trim |> Yojson.Safe.from_string in
      if
        field "out" (field "args" json)
        <> `String (Filename.concat (Sys.getcwd ()) "out.jsonl")
      then failwith "trace-qe8c output was not resolved against caller cwd";
      Ox_caps.Cap_stdlib.print_endline ~caps
        "trace-qe8c relative out resolved against caller cwd"
  | [ _; "inspect-init"; path; stdout; stderr ] -> inspect_init ~caps path stdout stderr
  | [ _; "skill-outcome"; action; path; stdout; stderr ] ->
      skill_outcome ~caps action path stdout stderr
  | [ _; "skill-show"; stdout; stderr ] -> skill_show ~caps stdout stderr
  | [ _; "status-skill"; state; stdout; stderr ] -> status_skill ~caps state stdout stderr
  | [ _; "serve-result"; path; file; ready ] ->
      serve_result ~caps path (Yojson.Safe.from_string (read_file ~caps file)) ready
  | [ _; "status-down"; code; stdout; stderr ] -> status_down ~caps code stdout stderr
  | [ _; "status-restart"; stdout; stderr ] -> status_restart ~caps stdout stderr
  | [ _; "status-healthy"; stdout; stderr ] -> status_healthy ~caps stdout stderr
  | _ -> failwith "invalid fixture invocation"

let () = main ~caps:(Ox_test.powerbox ()) ()
