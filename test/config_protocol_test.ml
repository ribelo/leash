(* L1: the config type, the Door's validator, the protocol types and the CLI client.

   ^chrome-38a4: a malformed request is refused with the offending path named, and every
   command of [docs/protocol.md] decodes and re-encodes. ^chrome-fuao: [status]'s reply
   shape. ^svc-ljl3: an unknown config key or a bad value fails at boot with its path.
   ^svc-kzt6: [OPENROUTER_API_KEY] overrides the file and never renders. ^svc-tkor:
   [config check] validates the file without starting the service. *)

module P = Leash.Protocol
module C = Leash.Config

let assoc fields = `Assoc fields

let contains needle haystack =
  let n = String.length needle in
  let h = String.length haystack in
  let rec loop i = i + n <= h && (String.sub haystack i n = needle || loop (i + 1)) in
  n = 0 || loop 0

let assert_ok name = function
  | Ok value -> value
  | Error message -> Alcotest.fail (name ^ ": " ^ message)

let check_needles name message needles =
  List.iter
    (fun needle ->
      if not (contains needle message) then
        Alcotest.failf "%s: message %S does not name %S" name message needle)
    needles

let expect_error name needles = function
  | Ok _ -> Alcotest.fail (name ^ ": expected an error")
  | Error message -> check_needles name message needles

let field key = function
  | `Assoc fields -> (
      match List.assoc_opt key fields with Some value -> value | None -> `Null)
  | _ -> `Null

let request_json ?(v = 1) ?(owner = "dsh:test") cmd args =
  assoc [ ("v", `Int v); ("owner", `String owner); ("cmd", `String cmd); ("args", args) ]

(* ---------- chrome-38a4: the envelope and the per-command arguments ---------- *)

let request_validation () =
  let request =
    assert_ok "status" (P.decode_request (request_json "status" (assoc [])))
  in
  Alcotest.(check string) "command" "status" (P.command_name request.command);
  Alcotest.(check string) "owner" "dsh:test" (P.Owner.to_string request.owner);
  expect_error "unsupported version" [ "v"; "2" ]
    (P.decode_request (request_json ~v:2 "status" (assoc [])));
  expect_error "unknown command" [ "cmd"; "bogus" ]
    (P.decode_request (request_json "bogus" (assoc [])));
  expect_error "unknown argument"
    [ "args"; "unknown field"; "oops" ]
    (P.decode_request (request_json "status" (assoc [ ("oops", `Int 1) ])));
  expect_error "missing argument"
    [ "args"; "snapshot"; "missing field" ]
    (P.decode_request (request_json "click" (assoc [ ("tab", `String "t_9xk") ])));
  expect_error "blank owner"
    [ "owner"; "must not be empty" ]
    (P.decode_request (request_json ~owner:" " "status" (assoc [])));
  expect_error "unknown envelope field"
    [ "request"; "unknown field"; "extra" ]
    (P.decode_request
       (assoc
          [
            ("v", `Int 1);
            ("owner", `String "x");
            ("cmd", `String "status");
            ("args", assoc []);
            ("extra", `Bool true);
          ]));
  let snap =
    assert_ok "snap"
      (P.decode_request
         (request_json "snap"
            (assoc [ ("tab", `String "t_9xk"); ("match", `String "Save") ])))
  in
  (match snap.command with
  | P.Snap { match_; _ } ->
      Alcotest.(check (option string)) "[@key \"match\"]" (Some "Save") match_
  | _ -> Alcotest.fail "snap decoded to another command");
  let list = assert_ok "list" (P.decode_request (request_json "list" (assoc []))) in
  match list.command with
  | P.List_tabs { all } ->
      Alcotest.(check bool) "all defaults to false" false all;
      Alcotest.(check bool)
        "all is written back" true
        (contains "\"all\":false" (Yojson.Safe.to_string (P.args_to_json list.command)))
  | _ -> Alcotest.fail "list decoded to another command"

let command_table =
  [
    ("new", assoc [ ("url", `String "https://example.com") ]);
    ("list", assoc []);
    ("claim", assoc [ ("tab", `String "t_9xk") ]);
    ("release", assoc [ ("tab", `String "t_9xk") ]);
    ("close", assoc [ ("tab", `String "t_9xk") ]);
    ("status", assoc []);
    ( "snap",
      assoc
        [
          ("tab", `String "t_9xk");
          ("match", `String "Save");
          ("limit", `Int 10);
          ("offset", `Int 20);
        ] );
    ( "text",
      assoc [ ("tab", `String "t_9xk"); ("index", `Int 0); ("max_chars", `Int 1000) ] );
    ( "shot",
      assoc
        [
          ("tab", `String "t_9xk");
          ("path", `String "/tmp/shot.png");
          ("full_page", `Bool true);
        ] );
    ("debug", assoc [ ("tab", `String "t_9xk"); ("limit", `Int 5); ("clear", `Bool true) ]);
    ( "eval",
      assoc
        [
          ("tab", `String "t_9xk");
          ("expression", `String "() => 1");
          ("argument", assoc [ ("a", `Int 1) ]);
        ] );
    ("nav", assoc [ ("tab", `String "t_9xk"); ("url", `String "https://example.com") ]);
    ( "click",
      assoc [ ("tab", `String "t_9xk"); ("snapshot", `String "s_3"); ("index", `Int 7) ]
    );
    ( "fill",
      assoc
        [
          ("tab", `String "t_9xk");
          ("snapshot", `String "s_3");
          ("index", `Int 7);
          ("text", `String "hello");
        ] );
    ( "press",
      assoc
        [
          ("tab", `String "t_9xk"); ("snapshot", `String "s_3"); ("key", `String "Enter");
        ] );
    ( "select",
      assoc
        [
          ("tab", `String "t_9xk");
          ("snapshot", `String "s_3");
          ("index", `Int 3);
          ("option", `Int 2);
        ] );
    ("scroll", assoc [ ("tab", `String "t_9xk"); ("direction", `String "down") ]);
    ( "wait",
      assoc
        [
          ("tab", `String "t_9xk");
          ("until", assoc [ ("text", `String "Ready"); ("dialog", `Bool true) ]);
          ("timeout_ms", `Int 1000);
        ] );
    ("dialog", assoc [ ("tab", `String "t_9xk"); ("answer", `String "dismiss") ]);
    ( "handoff",
      assoc
        [
          ("tab", `String "t_9xk"); ("reason", `String "captcha"); ("timeout_s", `Int 60);
        ] );
    ("resume", assoc [ ("tab", `String "t_9xk") ]);
    ( "drive",
      assoc
        [
          ("tab", `String "t_9xk");
          ("goal", `String "buy the thing");
          ("max_steps", `Int 5);
          ("deadline_s", `Int 60);
        ] );
  ]

let command_round_trip () =
  Alcotest.(check int) "every command of docs/protocol.md" 22 (List.length command_table);
  List.iter
    (fun (name, args) ->
      let request = assert_ok name (P.decode_request (request_json name args)) in
      Alcotest.(check string) (name ^ " name") name (P.command_name request.command);
      let encoded = P.encode_request request in
      Alcotest.(check int)
        (name ^ " version") 1
        (match field "v" encoded with `Int v -> v | _ -> 0);
      let again = assert_ok (name ^ " again") (P.decode_request encoded) in
      Alcotest.(check string)
        (name ^ " is a wire fixpoint")
        (Yojson.Safe.to_string encoded)
        (Yojson.Safe.to_string (P.encode_request again)))
    command_table

let tab_json =
  assoc
    [
      ("tab", `String "t_9xk");
      ("url", `String "https://example.com/");
      ("title", `String "Example");
      ("origin", `String "agent");
      ("state", `String "owned");
      ("owner", `String "dsh:test");
      ("generation", `Int 2);
      ("expires", `Null);
    ]

let snapshot_json =
  assoc
    [
      ("snapshot", `String "s_3");
      ("tab", `String "t_9xk");
      ("url", `String "https://example.com/");
      ("title", `String "Example");
      ( "rows",
        `List
          [
            assoc
              [
                ("index", `Int 0);
                ("role", `String "button");
                ("name", `String "Save");
                ("value", `String "1");
                ("state", `List [ `String "disabled"; `String "required" ]);
              ];
          ] );
      ("total", `Int 1);
      ("offset", `Int 0);
      ("truncated", `Bool false);
      ("dialog", assoc [ ("kind", `String "confirm"); ("message", `String "Sure?") ]);
    ]

let result_shapes () =
  let tab = assert_ok "tab info" (P.tab_info_of_yojson tab_json) in
  Alcotest.(check string) "handle" "t_9xk" (P.Handle.to_string tab.tab);
  Alcotest.(check string) "origin" "agent" (P.Origin.to_string tab.origin);
  Alcotest.(check string) "state" "owned" (P.State.to_string tab.state);
  Alcotest.(check (option string))
    "owner" (Some "dsh:test")
    (Option.map P.Owner.to_string tab.owner);
  Alcotest.(check bool) "no expiry" true (tab.expires = None);
  Alcotest.(check string)
    "TabInfo names its fields"
    (Yojson.Safe.to_string tab_json)
    (Yojson.Safe.to_string (P.yojson_of_tab_info tab));
  let snapshot = assert_ok "snapshot" (P.snapshot_of_yojson snapshot_json) in
  Alcotest.(check int) "one row" 1 (List.length snapshot.rows);
  let row = List.hd snapshot.rows in
  Alcotest.(check string) "row name" "Save" row.name;
  (match row.state with
  | Some states ->
      Alcotest.(check string)
        "row states" "disabled,required"
        (String.concat "," (List.map P.Row_state.to_string states))
  | None -> Alcotest.fail "row state present");
  (match snapshot.dialog with
  | Some dialog ->
      Alcotest.(check string)
        "dialog kind" "confirm"
        (P.Dialog_kind.to_string dialog.kind)
  | None -> Alcotest.fail "dialog present");
  Alcotest.(check string)
    "Snapshot names its fields"
    (Yojson.Safe.to_string snapshot_json)
    (Yojson.Safe.to_string (P.yojson_of_snapshot snapshot));
  expect_error "unknown row state" [ "state"; "hidden" ]
    (P.row_of_yojson
       (assoc
          [
            ("index", `Int 0);
            ("role", `String "button");
            ("name", `String "Save");
            ("state", `List [ `String "hidden" ]);
          ]))

let status_result () =
  let json =
    assoc
      [
        ("generation", `Int 3);
        ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
        ("chrome", `String "restarting");
        ("uptime_s", `Float 12.5);
      ]
  in
  let result = assert_ok "status result" (P.status_result_of_yojson json) in
  Alcotest.(check int) "generation" 3 result.generation;
  Alcotest.(check int) "open tabs" 2 result.tabs.open_;
  Alcotest.(check int) "cap" 8 result.tabs.cap;
  Alcotest.(check string)
    "chrome phase" "restarting"
    (P.Chrome_phase.to_string result.chrome);
  Alcotest.(check (float 0.0)) "uptime" 12.5 result.uptime_s;
  Alcotest.(check string)
    "[@key \"open\"]" (Yojson.Safe.to_string json)
    (Yojson.Safe.to_string (P.yojson_of_status_result result));
  expect_error "unknown phase" [ "chrome"; "crashed" ]
    (P.status_result_of_yojson
       (assoc
          [
            ("generation", `Int 3);
            ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
            ("chrome", `String "crashed");
            ("uptime_s", `Float 1.0);
          ]))

let drive_result () =
  let step =
    assoc
      [
        ("n", `Int 1);
        ("snapshot", `String "s_3");
        ("operation", `String "type_text");
        ("index", `Null);
        ( "probabilities",
          assoc
            [
              ("op", assoc [ ("type_text", `Float 0.4) ]);
              ("target", assoc [ ("row", `Int 3) ]);
            ] );
        ("text", `String "hello");
        ( "after",
          assoc [ ("url", `String "https://example.com/"); ("title", `String "Example") ]
        );
        ("elapsed_ms", `Int 120);
      ]
  in
  let json =
    assoc
      [
        ("status", `String "step-cap"); ("steps", `List [ step ]); ("final", snapshot_json);
      ]
  in
  let result = assert_ok "drive result" (P.drive_result_of_yojson json) in
  Alcotest.(check string) "status" "step-cap" (P.Drive_status.to_string result.status);
  (match result.steps with
  | [ step ] ->
      Alcotest.(check string)
        "operation" "type_text"
        (P.Operation.to_string step.operation);
      Alcotest.(check (option int)) "index absent" None step.index
  | _ -> Alcotest.fail "one step");
  Alcotest.(check string)
    "Step names its fields" (Yojson.Safe.to_string json)
    (Yojson.Safe.to_string (P.yojson_of_drive_result result))

let reply_shapes () =
  let success = assoc [ ("ok", `Bool true); ("result", assoc [ ("tabs", `List []) ]) ] in
  (match assert_ok "success reply" (P.decode_reply success) with
  | P.Success result ->
      Alcotest.(check string)
        "result passes through" "{\"tabs\":[]}"
        (Yojson.Safe.to_string result)
  | P.Failure _ -> Alcotest.fail "a success reply decoded as a failure");
  let failure =
    assoc
      [
        ("ok", `Bool false);
        ( "error",
          assoc
            [
              ("code", `String "stale-snapshot");
              ("message", `String "snapshot s_3 is stale; snap again");
              ("detail", assoc [ ("snapshot", `String "s_4") ]);
            ] );
      ]
  in
  let decoded = assert_ok "failure reply" (P.decode_reply failure) in
  (match decoded with
  | P.Failure error ->
      Alcotest.(check string) "code" "stale-snapshot" (P.Error_code.to_string error.code);
      Alcotest.(check (option string))
        "detail" (Some "{\"snapshot\":\"s_4\"}")
        (Option.map Yojson.Safe.to_string error.detail)
  | P.Success _ -> Alcotest.fail "a failure reply decoded as a success");
  Alcotest.(check string)
    "the success wire shape"
    (Yojson.Safe.to_string success)
    (Yojson.Safe.to_string (P.encode_reply (P.Success (assoc [ ("tabs", `List []) ]))));
  Alcotest.(check string)
    "the failure wire shape"
    (Yojson.Safe.to_string failure)
    (Yojson.Safe.to_string (P.encode_reply decoded));
  expect_error "both shapes at once" [ "error" ]
    (P.decode_reply
       (assoc [ ("ok", `Bool true); ("result", assoc []); ("error", assoc []) ]));
  expect_error "success without a result" [ "result" ]
    (P.decode_reply (assoc [ ("ok", `Bool true) ]));
  expect_error "failure without an error" [ "error" ]
    (P.decode_reply (assoc [ ("ok", `Bool false) ]));
  expect_error "unknown error code" [ "code"; "mystery" ]
    (P.decode_reply
       (assoc
          [
            ("ok", `Bool false);
            ("error", assoc [ ("code", `String "mystery"); ("message", `String "x") ]);
          ]));
  expect_error "unknown reply field"
    [ "reply"; "unknown field"; "extra" ]
    (P.decode_reply
       (assoc [ ("ok", `Bool true); ("result", `Null); ("extra", `Bool true) ]))

(* ---------- svc-ljl3, svc-kzt6, svc-tkor: the config type ---------- *)

let config_text ?(headless = false) binary profile =
  Printf.sprintf
    "[chrome]\n\
     binary = %S\n\
     profile_dir = %S\n\
     workspace = \"leash\"\n\
     %s[tabs]\n\
     cap = 8\n\
     [expiry]\n\
     idle_s = 1800\n\
     unclaimed_s = 3600\n\
     tombstone_s = 3600\n\
     [models]\n\
     api_key = \"file-secret\"\n\
     jev_model = \"jev\"\n\
     text_model = \"helper\"\n"
    binary profile
    (if headless then "headless = true\n" else "")

let config_decode ?(getenv = fun _ -> None) text =
  Eta_app.Config.decode ~spec:C.spec ~getenv text

let expect_config_error name needles = function
  | Ok _ -> Alcotest.fail (name ^ ": expected an error")
  | Error (`Config message) -> check_needles name message needles

let config_values () =
  let base = config_text "/tmp/chrome" "/tmp/profile" in
  let getenv key = if key = "OPENROUTER_API_KEY" then Some "env-secret" else None in
  let value =
    match config_decode ~getenv base with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  (match value.models.api_key with
  | Some key ->
      Alcotest.(check string) "environment wins" "env-secret" (C.Redact.expose key)
  | None -> Alcotest.fail "the environment key must be present");
  Alcotest.(check bool) "production is headed by default" false value.chrome.headless;
  let headless =
    match config_decode (config_text ~headless:true "/tmp/chrome" "/tmp/profile") with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  Alcotest.(check bool) "headless is opt-in" true headless.chrome.headless;
  let printed = Yojson.Safe.to_string (C.yojson_of_t value) in
  Alcotest.(check bool) "environment secret absent" false (contains "env-secret" printed);
  Alcotest.(check bool) "file secret absent" false (contains "file-secret" printed);
  Alcotest.(check bool) "redacted" true (contains "<redacted>" printed);
  let chrome = C.chrome_config value.chrome in
  Alcotest.(check string) "chrome binary" "/tmp/chrome" chrome.binary;
  Alcotest.(check string) "chrome profile" "/tmp/profile" chrome.profile_dir;
  Alcotest.(check string) "chrome workspace" "leash" chrome.workspace;
  Alcotest.(check bool) "chrome headed" false chrome.headless;
  expect_config_error "unknown key" [ "unknown field"; "oops" ]
    (config_decode (base ^ "oops = true\n"));
  expect_config_error "negative cap" [ "tabs.cap"; "positive" ]
    (config_decode
       (String.concat "\n"
          (List.map
             (fun line -> if line = "cap = 8" then "cap = -1" else line)
             (String.split_on_char '\n' base))));
  expect_config_error "empty binary"
    [ "chrome.binary"; "must not be empty" ]
    (config_decode (config_text "" "/tmp/profile"));
  Alcotest.(check bool) "cap must be positive" true (Result.is_error (C.Tab_cap.of_int 0));
  Alcotest.(check bool)
    "durations must be positive" true
    (Result.is_error (C.Seconds.of_int (-5)));
  Alcotest.(check bool)
    "text must not be blank" true
    (Result.is_error (C.Text.of_string " "));
  Alcotest.(check bool)
    "handles must not be blank" true
    (Result.is_error (P.Handle.of_string ""))

let with_temp f =
  let path = Filename.temp_file "leash-l1-" "" in
  Unix.unlink path;
  Unix.mkdir path 0o700;
  Fun.protect
    ~finally:(fun () ->
      (try Unix.unlink (Filename.concat (Filename.concat path "leash") "control.sock")
       with _ -> ());
      (try Unix.rmdir (Filename.concat path "leash") with _ -> ());
      List.iter
        (fun name -> try Unix.unlink (Filename.concat path name) with _ -> ())
        [ "binary"; "config.toml"; "stdout"; "stderr" ];
      (try Unix.rmdir (Filename.concat path "profile") with _ -> ());
      Unix.rmdir path)
    (fun () -> f path)

let path_validation () =
  with_temp (fun dir ->
      let binary = Filename.concat dir "binary" in
      let profile = Filename.concat dir "profile" in
      let config =
        match config_decode (config_text binary profile) with
        | Ok value -> value
        | Error (`Config message) -> Alcotest.fail message
      in
      Eio_main.run (fun env ->
          let check () = C.validate_paths ~fs:env#fs config in
          Alcotest.(check bool) "missing binary" true (Result.is_error (check ()));
          let out = open_out binary in
          close_out out;
          Unix.chmod binary 0o700;
          Alcotest.(check bool) "creatable profile" true (Result.is_ok (check ()));
          Unix.mkdir profile 0o700;
          Alcotest.(check bool) "readable profile" true (Result.is_ok (check ()));
          Unix.chmod profile 0o000;
          Alcotest.(check bool) "unreadable profile" true (Result.is_error (check ()));
          Unix.chmod profile 0o700))

let config_check_cli () =
  with_temp (fun dir ->
      let binary = Filename.concat dir "binary" in
      let config_file = Filename.concat dir "config.toml" in
      let write text =
        let out = open_out config_file in
        output_string out text;
        close_out out
      in
      write (config_text binary (Filename.concat dir "profile"));
      let executable =
        Filename.concat
          (Filename.dirname Sys.executable_name)
          "../packages/leash/bin/main.exe"
      in
      let check () =
        let output = Filename.concat dir "stdout" in
        let error = Filename.concat dir "stderr" in
        let stdout =
          Unix.openfile output [ Unix.O_CREAT; Unix.O_TRUNC; Unix.O_WRONLY ] 0o600
        in
        let stderr =
          Unix.openfile error [ Unix.O_CREAT; Unix.O_TRUNC; Unix.O_WRONLY ] 0o600
        in
        let pid =
          Unix.create_process_env executable
            [| executable; "config"; "check"; "--config"; config_file |]
            (Unix.environment ()) Unix.stdin stdout stderr
        in
        Unix.close stdout;
        Unix.close stderr;
        let _, status = Unix.waitpid [] pid in
        let contents file =
          let channel = open_in file in
          Fun.protect
            ~finally:(fun () -> close_in channel)
            (fun () -> really_input_string channel (in_channel_length channel))
        in
        (status, contents output, contents error)
      in
      let status, _, error = check () in
      Alcotest.(check bool) "missing executable rejected" true (status = Unix.WEXITED 2);
      Alcotest.(check bool)
        "JSON pointer in diagnostic" true
        (List.mem "chrome" (String.split_on_char '/' error));
      close_out (open_out binary);
      Unix.chmod binary 0o700;
      let status, output, _ = check () in
      Alcotest.(check bool) "valid filesystem accepted" true (status = Unix.WEXITED 0);
      Alcotest.(check bool) "redacted config printed" true (String.length output > 0);
      Alcotest.(check bool) "secret absent" false (contains "file-secret" output);
      write (config_text binary (Filename.concat dir "profile") ^ "oops = true\n");
      let status, _, error = check () in
      Alcotest.(check bool) "unknown key exits two" true (status = Unix.WEXITED 2);
      Alcotest.(check bool) "unknown key named" true (contains "oops" error))

let socket_cli_case argv reply expected_status expected_command expected_owner =
  with_temp (fun runtime ->
      let dir = Filename.concat runtime "leash" in
      Unix.mkdir dir 0o700;
      let path = Filename.concat dir "control.sock" in
      let listener = Unix.socket Unix.PF_UNIX Unix.SOCK_STREAM 0 in
      Fun.protect
        ~finally:(fun () -> Unix.close listener)
        (fun () ->
          Unix.bind listener (Unix.ADDR_UNIX path);
          Unix.listen listener 1;
          let out_read, out_write = Unix.pipe () in
          let err_read, err_write = Unix.pipe () in
          let binary =
            Filename.concat
              (Filename.dirname Sys.executable_name)
              "../packages/leash/bin/main.exe"
          in
          let env =
            Array.to_list (Unix.environment ())
            |> List.filter (fun item ->
                not
                  (String.starts_with ~prefix:"XDG_RUNTIME_DIR=" item
                  || String.starts_with ~prefix:"DSH_SESSION_ID=" item))
          in
          let env =
            Array.of_list
              (("XDG_RUNTIME_DIR=" ^ runtime) :: "DSH_SESSION_ID=test-l1" :: env)
          in
          let pid =
            Unix.create_process_env binary
              (Array.of_list (binary :: argv))
              env Unix.stdin out_write err_write
          in
          Unix.close out_write;
          Unix.close err_write;
          let ready, _, _ = Unix.select [ listener ] [] [] 3. in
          if ready = [] then Alcotest.fail "CLI did not connect to the fake listener";
          let peer, _ = Unix.accept listener in
          let input = Unix.in_channel_of_descr peer in
          let req = Yojson.Safe.from_string (input_line input) in
          let decoded = assert_ok "CLI request" (P.decode_request req) in
          Alcotest.(check string)
            "command" expected_command
            (P.command_name decoded.command);
          Alcotest.(check string) "owner" expected_owner (P.Owner.to_string decoded.owner);
          let output = Unix.out_channel_of_descr (Unix.dup peer) in
          output_string output (reply ^ "\n");
          flush output;
          close_out output;
          close_in input;
          let _, status = Unix.waitpid [] pid in
          Alcotest.(check bool)
            "CLI exit code" true
            (status = Unix.WEXITED expected_status);
          let text = input_line (Unix.in_channel_of_descr out_read) in
          Alcotest.(check bool) "prints JSON or table" true (String.length text > 0);
          Unix.close err_read))

let socket_cli () =
  socket_cli_case [ "status" ]
    "{\"ok\":true,\"result\":{\"generation\":1,\"tabs\":{\"open\":0,\"cap\":8},\"chrome\":\"running\",\"uptime_s\":1.0}}"
    0 "status" "dsh:test-l1";
  socket_cli_case
    [ "new"; "--owner"; "human"; "https://example.com" ]
    "{\"ok\":false,\"error\":{\"code\":\"tab-cap\",\"message\":\"full\"}}" 1 "new" "human";
  socket_cli_case [ "list"; "--table" ] "{\"ok\":true,\"result\":{\"tabs\":[]}}" 0 "list"
    "dsh:test-l1"

let cli_usage () =
  let binary =
    Filename.concat
      (Filename.dirname Sys.executable_name)
      "../packages/leash/bin/main.exe"
  in
  let null = Unix.openfile "/dev/null" [ Unix.O_WRONLY ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close null)
    (fun () ->
      let pid =
        Unix.create_process_env binary
          [| binary; "status"; "unexpected" |]
          (Unix.environment ()) Unix.stdin null null
      in
      let _, status = Unix.waitpid [] pid in
      Alcotest.(check bool) "CLI usage exits two" true (status = Unix.WEXITED 2))

let test name case = Alcotest.test_case name `Quick case

let () =
  Alcotest.run "L1 config, Door and protocol"
    [
      ( "chrome-38a4",
        [
          test "request envelope and closed arguments" request_validation;
          test "every command decodes and round-trips" command_round_trip;
          test "tab, snapshot and dialog shapes" result_shapes;
          test "drive result shape" drive_result;
          test "reply shapes" reply_shapes;
        ] );
      ( "chrome-fuao",
        [
          test "status result shape" status_result;
          test "status socket client" socket_cli;
          test "usage exit" cli_usage;
        ] );
      ("svc-kzt6", [ test "environment override/redaction" config_values ]);
      ( "svc-ljl3",
        [
          test "boot path validation" path_validation;
          test "config check fails fast" config_check_cli;
        ] );
      ( "svc-tkor",
        [
          test "config decode and defaults" config_values;
          test "config check prints the redacted config" config_check_cli;
        ] );
    ]
