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

let () =
  match Array.to_list Sys.argv with
  | [ _; "serve"; path; code; ready ] -> serve path code ready
  | [ _; "inspect"; code; status; stdout; stderr ] -> inspect code status stdout stderr
  | [ _; "config-details"; path; stderr ] -> config_details path stderr
  | [ _; "check-help"; path ] -> check_help path
  | [ _; "top-help"; path ] -> top_help path
  | [ _; "error-help"; path ] -> error_help path
  | [ _; "inspect-init"; path; stdout; stderr ] -> inspect_init path stdout stderr
  | _ -> failwith "invalid fixture invocation"
