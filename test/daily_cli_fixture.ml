(* daily-azxe daily-3bwr daily-u1k2: a private one-request protocol peer and
   strict stream assertions. No Chrome or installed service is started. *)
module P = Leash.Protocol

let read_file path = In_channel.with_open_bin path In_channel.input_all

let serve path code ready =
  let socket = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      Unix.close socket;
      Unix.unlink path)
    (fun () ->
      Unix.bind socket (Unix.ADDR_UNIX path);
      Unix.listen socket 1;
      Out_channel.with_open_bin ready (fun out -> output_string out "ready");
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

let inspect expected status stdout stderr =
  let fail message = failwith (expected ^ ": " ^ message) in
  if read_file stdout <> "" then fail "failure wrote to stdout";
  let raw = read_file stderr in
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
  Printf.printf "%s: exit %s, JSON-only stderr, hint, empty stdout\n" expected status

let contains text fragment =
  let n = String.length fragment in
  let rec loop i =
    i + n <= String.length text && (String.sub text i n = fragment || loop (i + 1))
  in
  loop 0

let config_details path stderr =
  let raw = read_file stderr in
  List.iter
    (fun fragment ->
      if not (contains raw fragment) then
        failwith ("missing config diagnostic " ^ fragment))
    [ path; "/chrome/headless"; "/expiry/idle_s"; "/control/socket"; "/tabs/cap" ];
  print_endline "config path and all four problems are present"

let check_help path =
  let text = read_file path in
  List.iter
    (fun heading ->
      if not (contains text heading) then failwith ("missing help heading " ^ heading))
    [ "EXAMPLES"; "EXIT STATUS"; "124" ];
  if not (contains text "leash ") then failwith "help has no concrete example"

let top_help path =
  let text = read_file path in
  List.iter
    (fun heading ->
      if not (contains text heading) then failwith ("missing command group " ^ heading))
    [
      "TABS";
      "OBSERVE";
      "ACT";
      "NETWORK AND DEBUG";
      "MISSIONS";
      "PLAYBOOKS";
      "SERVICE";
      "SKILL";
    ];
  print_endline
    "top-level help groups tabs, observe, act, network/debug, missions, playbooks, \
     service and skill"

let error_help path =
  let actual = String.trim (read_file path) in
  if actual <> String.trim P.error_help then
    failwith "leash help errors is not the full canonical table";
  Printf.printf "all %d error codes, exit classes, meanings and hints are discoverable\n"
    (List.length P.Error_code.all)

let inspect_init path stdout stderr =
  if read_file stdout <> path ^ "\n" then
    failwith "config init changed its successful stdout";
  if read_file stderr <> "" then failwith "config init wrote to stderr";
  if read_file path <> Leash.Config.default_toml then
    failwith "config init changed the default file";
  print_endline "config init writes its path and empty stderr"

(* daily-yd8s daily-ulmi: inspect whole streams, not just a selected output line. *)
let skill_outcome action path stdout stderr =
  let raw = read_file stdout in
  let expected = `Assoc [ ("action", `String action); ("path", `String path) ] in
  if Yojson.Safe.from_string raw <> expected then failwith "wrong skill outcome";
  if read_file stderr <> "" then failwith "skill success wrote to stderr";
  Printf.printf "%s: one JSON outcome, empty stderr\n" action

let skill_show stdout stderr =
  let contents = read_file stdout in
  if contents <> Leash_cli_support.Skill_install.show then
    failwith "show is not the exact stamped entrypoint";
  List.iter
    (fun marker -> if not (contains contents marker) then failwith ("missing " ^ marker))
    [ "---\nname: leash\n"; "metadata:\n  leash-version:"; "\n  leash-commit:" ];
  if read_file stderr <> "" then failwith "show wrote to stderr";
  print_endline
    "show: exact bundled entrypoint, YAML version and commit stamp, empty stderr"

let serve_result path result ready =
  let socket = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
  Fun.protect
    ~finally:(fun () ->
      Unix.close socket;
      Unix.unlink path)
    (fun () ->
      Unix.bind socket (Unix.ADDR_UNIX path);
      Unix.listen socket 1;
      Out_channel.with_open_bin ready (fun out -> output_string out "ready");
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

let status_down code stdout stderr =
  let raw = read_file stderr in
  if read_file stdout <> "" then failwith "status failure wrote stdout";
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
  if contains raw "sk-leash" || contains (read_file stdout) "sk-leash" then
    failwith "status printed a key";
  Printf.printf "%s: %s %s hint=%s\n" code unit binary error.hint

let status_restart stdout stderr =
  let raw = read_file stderr in
  if read_file stdout <> "" then failwith "restarting status wrote stdout";
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
  Printf.printf "service-restarting: chrome generation relaunch, %s\n" error.hint

let status_healthy stdout stderr =
  let raw = read_file stdout in
  if read_file stderr <> "" then failwith "healthy status wrote stderr";
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
  Printf.printf
    "healthy: version %s chrome running generation 7 pid 4242 headed key_present skill %s\n"
    Leash.version
    (match field "state" skill with `String state -> state | _ -> "?")

let status_skill state stdout stderr =
  let result = Yojson.Safe.from_string (read_file stdout) in
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
  if read_file stderr <> "" then failwith "status wrote to stderr";
  Printf.printf "status: skill %s, running version and commit, service fields retained\n"
    state

let () =
  match Array.to_list Sys.argv with
  | [ _; "serve"; path; code; ready ] -> serve path code ready
  | [ _; "inspect"; code; status; stdout; stderr ] -> inspect code status stdout stderr
  | [ _; "config-details"; path; stderr ] -> config_details path stderr
  | [ _; "check-help"; path ] -> check_help path
  | [ _; "top-help"; path ] -> top_help path
  | [ _; "error-help"; path ] -> error_help path
  | [ _; "inspect-init"; path; stdout; stderr ] -> inspect_init path stdout stderr
  | [ _; "skill-outcome"; action; path; stdout; stderr ] ->
      skill_outcome action path stdout stderr
  | [ _; "skill-show"; stdout; stderr ] -> skill_show stdout stderr
  | [ _; "status-skill"; state; stdout; stderr ] -> status_skill state stdout stderr
  | [ _; "serve-result"; path; file; ready ] ->
      serve_result path (Yojson.Safe.from_string (read_file file)) ready
  | [ _; "status-down"; code; stdout; stderr ] -> status_down code stdout stderr
  | [ _; "status-restart"; stdout; stderr ] -> status_restart stdout stderr
  | [ _; "status-healthy"; stdout; stderr ] -> status_healthy stdout stderr
  | _ -> failwith "invalid fixture invocation"
