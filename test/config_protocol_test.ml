module P = Leash.Protocol
module C = Leash.Config

let assoc fields = `Assoc fields

let assert_ok name = function
  | Ok x -> x
  | Error xs -> Alcotest.fail (name ^ ": " ^ Eta_schema.render_issues xs)

let example =
  assoc
    [
      ("v", `Int 1);
      ("owner", `String "dsh:test");
      ("cmd", `String "status");
      ("args", assoc []);
    ]

let request_validation () =
  ignore (assert_ok "status" (P.decode_request example));
  List.iter
    (fun request ->
      match P.decode_request request with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "malformed command accepted")
    [
      assoc
        [
          ("v", `Int 2);
          ("owner", `String "x");
          ("cmd", `String "status");
          ("args", assoc []);
        ];
      assoc
        [
          ("v", `Int 1);
          ("owner", `String "x");
          ("cmd", `String "bogus");
          ("args", assoc []);
        ];
      assoc
        [
          ("v", `Int 1);
          ("owner", `String "x");
          ("cmd", `String "status");
          ("args", assoc [ ("oops", `Int 1) ]);
        ];
      assoc
        [
          ("v", `Int 1);
          ("owner", `String "x");
          ("cmd", `String "click");
          ("args", assoc [ ("tab", `String "t") ]);
        ];
    ];
  List.iter
    (fun (cmd, schema) ->
      ignore (Eta_schema.json_schema schema);
      Alcotest.(check bool)
        (cmd ^ " has reply schema") true
        (List.mem_assoc cmd P.result_schemas))
    P.command_schemas;
  Alcotest.(check int) "all commands" 22 (List.length P.command_schemas)

let config_text binary profile =
  Printf.sprintf
    "[chrome]\n\
     binary = %S\n\
     profile_dir = %S\n\
     workspace = \"leash\"\n\
     [tabs]\n\
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

let config_decode text env =
  Eta_app.Config.decode ~schema:C.schema
    ~getenv:(fun key -> if key = "OPENROUTER_API_KEY" then env else None)
    text

let config_values () =
  let base = config_text "/tmp/chrome" "/tmp/profile" in
  let value =
    match config_decode base (Some "env-secret") with
    | Ok x -> x
    | Error (`Config msg) -> Alcotest.fail msg
  in
  Alcotest.(check (option string))
    "environment wins" (Some "env-secret") value.models.api_key;
  let redacted = assert_ok "redaction" (Eta_schema.encode_redacted C.schema value) in
  let printed = Eta_schema.Json.to_string redacted in
  Alcotest.(check bool)
    "secret absent" false
    (List.mem "env-secret" (String.split_on_char '"' printed));
  List.iter
    (fun (label, text) ->
      match config_decode text None with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail (label ^ " accepted"))
    [
      ("unknown", base ^ "unknown = true\n");
      ( "negative cap",
        String.concat "\n"
          (List.map
             (fun line -> if line = "cap = 8" then "cap = -1" else line)
             (String.split_on_char '\n' base)) );
    ];
  ()

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
        match config_decode (config_text binary profile) None with
        | Ok x -> x
        | Error (`Config msg) -> Alcotest.fail msg
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
      let out = open_out config_file in
      output_string out (config_text binary (Filename.concat dir "profile"));
      close_out out;
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
      Alcotest.(check bool) "redacted config printed" true (String.length output > 0))

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
          Alcotest.(check string) "command" expected_command decoded.cmd;
          Alcotest.(check string) "owner" expected_owner decoded.owner;
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

let () =
  Alcotest.run "L1 config, Door and protocol"
    [
      ( "chrome-38a4",
        [
          Alcotest.test_case "request schema and closed commands" `Quick
            request_validation;
        ] );
      ( "chrome-fuao",
        [
          Alcotest.test_case "status socket client" `Quick socket_cli;
          Alcotest.test_case "usage exit" `Quick cli_usage;
        ] );
      ( "svc-kzt6",
        [ Alcotest.test_case "environment override/redaction" `Quick config_values ] );
      ( "svc-ljl3",
        [
          Alcotest.test_case "boot path validation" `Quick path_validation;
          Alcotest.test_case "config check validates paths" `Quick config_check_cli;
        ] );
      ("svc-tkor", [ Alcotest.test_case "config schema checks" `Quick config_values ]);
    ]
