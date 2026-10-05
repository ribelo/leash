(* daily-9396: [Config.decode_all] reports every config problem in one pass. A type
   error must not hide a semantic refusal, a relative socket, or another bad field. *)

module C = Leash.Config

let contains needle haystack =
  let n = String.length needle in
  let h = String.length haystack in
  let rec loop i = i + n <= h && (String.sub haystack i n = needle || loop (i + 1)) in
  n = 0 || loop 0

let show issues =
  String.concat "; "
    (List.map
       (fun issue -> issue.Ox_app.Config.pointer ^ " " ^ issue.Ox_app.Config.message)
       issues)

let issues name = function
  | Ok _ -> Alcotest.fail (name ^ ": expected errors")
  | Error issues -> issues

let message pointer issues =
  match List.find_opt (fun issue -> issue.Ox_app.Config.pointer = pointer) issues with
  | Some issue -> issue.Ox_app.Config.message
  | None -> Alcotest.failf "missing %s in %s" pointer (show issues)

let pointers issues = List.map (fun issue -> issue.Ox_app.Config.pointer) issues

let assert_message name pointer needle issues =
  let text = message pointer issues in
  if not (contains needle text) then
    Alcotest.failf "%s: %s message %S does not contain %S" name pointer text needle

(* The derived decoder stops at chrome.headless. decode_all must still name the negative
   duration, the zero cap, and the relative socket. *)
let four_at_once () =
  let json =
    `Assoc
      [
        ("chrome", `Assoc [ ("headless", `String "yes") ]);
        ("expiry", `Assoc [ ("idle_s", `Int (-1)) ]);
        ("control", `Assoc [ ("socket", `String "relative.sock") ]);
        ("tabs", `Assoc [ ("cap", `Int 0) ]);
      ]
  in
  (match C.t_of_yojson json with
  | Ok _ -> Alcotest.fail "the derived decoder accepted a bad document"
  | Error message ->
      Alcotest.(check bool)
        "the derived decoder still stops before the other three" true
        (contains "headless" message
        && (not (contains "idle_s" message))
        && not (contains "absolute" message)));
  let found = issues "four at once" (C.decode_all json) in
  assert_message "headless type" "/chrome/headless" "bool" found;
  assert_message "idle semantic" "/expiry/idle_s" "-1" found;
  assert_message "cap semantic" "/tabs/cap" "positive" found;
  assert_message "relative socket" "/control/socket" "absolute" found;
  Alcotest.(check int) "exactly those four" 4 (List.length found)

let success_unchanged () =
  let json = `Assoc [] in
  match (C.decode_all json, C.t_of_yojson json) with
  | Ok got, Ok expected ->
      Alcotest.(check string)
        "env is not applied" "$XDG_DATA_HOME/leash/profile"
        (C.Text.to_string got.chrome.profile_dir);
      Alcotest.(check string)
        "Ok is t_of_yojson"
        (Yojson.Safe.to_string (C.yojson_of_t expected))
        (Yojson.Safe.to_string (C.yojson_of_t got))
  | Error found, _ -> Alcotest.fail (show found)
  | _, Error message -> Alcotest.fail message

let rich_success () =
  let json =
    `Assoc
      [
        ( "chrome",
          `Assoc
            [
              ("binary", `String "/bin/sh");
              ("profile_dir", `String "/tmp/leash-profile");
              ("workspace", `String "desk");
              ("headless", `Bool true);
              ("window_size", `String "800,600");
            ] );
        ("tabs", `Assoc [ ("cap", `Int 4) ]);
        ("expiry", `Assoc [ ("idle_s", `Int 1800) ]);
        ("control", `Assoc [ ("socket", `String "/tmp/leash.sock") ]);
        ( "otlp",
          `Assoc
            [
              ("endpoint", `String "http://127.0.0.1:4318/v1/traces");
              ( "headers",
                `List
                  [
                    `Assoc
                      [ ("name", `String "Authorization"); ("value", `String "secret") ];
                  ] );
            ] );
        ("models", `Assoc [ ("api_key", `String "sk-test"); ("planner_endpoint", `Null) ]);
        ( "handoff",
          `Assoc
            [
              ("focus_command", `List []);
              ("notify_command", `List [ `String "notify-send"; `String "{reason}" ]);
            ] );
      ]
  in
  match (C.decode_all json, C.t_of_yojson json) with
  | Ok got, Ok expected -> (
      Alcotest.(check string)
        "same document"
        (Yojson.Safe.to_string (C.yojson_of_t expected))
        (Yojson.Safe.to_string (C.yojson_of_t got));
      match (got.models.api_key, expected.models.api_key) with
      | Some got_key, Some expected_key ->
          Alcotest.(check string)
            "secret kept"
            (C.Redact.expose expected_key)
            (C.Redact.expose got_key)
      | _ -> Alcotest.fail "api_key dropped")
  | Error found, _ -> Alcotest.fail (show found)
  | _, Error message -> Alcotest.fail message

let otlp_and_unknown () =
  let json =
    `Assoc
      [
        ("oops", `Bool true);
        ("also", `Int 1);
        ( "otlp",
          `Assoc
            [
              ("endpoint", `String "not a url");
              ( "headers",
                `List
                  [
                    `Assoc
                      [
                        ("name", `String "Bad Name");
                        ("value", `String "evil\r\nX");
                        ("extra", `Bool true);
                      ];
                  ] );
            ] );
        ("tabs", `Assoc [ ("nope", `Null) ]);
      ]
  in
  let found = issues "otlp and unknown" (C.decode_all json) in
  assert_message "unknown root" "/oops" "unknown field" found;
  assert_message "second unknown" "/also" "also" found;
  assert_message "nested unknown" "/tabs/nope" "nope" found;
  assert_message "header extra" "/otlp/headers/0/extra" "extra" found;
  assert_message "bad url" "/otlp/endpoint" "http(s)" found;
  assert_message "bad header name" "/otlp/headers/0/name" "header name" found;
  assert_message "bad header value" "/otlp/headers/0/value" "header value" found;
  Alcotest.(check int) "all seven" 7 (List.length found)

let headers_without_endpoint () =
  let json =
    `Assoc
      [
        ( "otlp",
          `Assoc
            [
              ( "headers",
                `List [ `Assoc [ ("name", `String "Bad Name"); ("value", `String "ok") ] ]
              );
            ] );
      ]
  in
  let found = issues "headers without endpoint" (C.decode_all json) in
  assert_message "require" "/otlp/headers" "endpoint" found;
  assert_message "name" "/otlp/headers/0/name" "header name" found;
  Alcotest.(check int) "both OTLP problems" 2 (List.length found);
  match C.t_of_yojson json with
  | Error message -> Alcotest.fail message
  | Ok config -> (
      match C.validate_otlp config with
      | Ok () -> Alcotest.fail "validate_otlp accepted headers without an endpoint"
      | Error door ->
          Alcotest.(check (list string))
            "the Door reports both too" (pointers found) (pointers door))

let every_field_wrong_type () =
  let bad = `Int 1 in
  let json =
    `Assoc
      [
        ( "chrome",
          `Assoc
            [
              ("binary", bad);
              ("profile_dir", bad);
              ("workspace", bad);
              ("headless", bad);
              ("window_size", bad);
            ] );
        ("tabs", `Assoc [ ("cap", `String "x") ]);
        ("expiry", `Assoc [ ("idle_s", `String "x"); ("tombstone_s", `String "x") ]);
        ("control", `Assoc [ ("socket", bad) ]);
        ("otlp", `Assoc [ ("endpoint", bad); ("headers", bad) ]);
        ( "models",
          `Assoc
            [
              ("api_key", bad);
              ("systemone_endpoint", bad);
              ("decision_model", bad);
              ("chat_base_url", bad);
              ("text_model", bad);
              ("planner_model", bad);
              ("planner_reasoning", bad);
              ("planner_endpoint", bad);
            ] );
        ("handoff", `Assoc [ ("focus_command", bad); ("notify_command", bad) ]);
      ]
  in
  let found = issues "every field" (C.decode_all json) in
  Alcotest.(check (list string))
    "every field, none dropped"
    [
      "/chrome/binary";
      "/chrome/profile_dir";
      "/chrome/workspace";
      "/chrome/headless";
      "/chrome/window_size";
      "/tabs/cap";
      "/expiry/idle_s";
      "/expiry/tombstone_s";
      "/control/socket";
      "/otlp/endpoint";
      "/otlp/headers";
      "/models/api_key";
      "/models/systemone_endpoint";
      "/models/decision_model";
      "/models/chat_base_url";
      "/models/text_model";
      "/models/planner_model";
      "/models/planner_reasoning";
      "/models/planner_endpoint";
      "/handoff/focus_command";
      "/handoff/notify_command";
    ]
    (pointers found)

let list_elements () =
  let json =
    `Assoc
      [
        ( "handoff",
          `Assoc [ ("focus_command", `List [ `Int 1; `String "ok"; `Bool false ]) ] );
      ]
  in
  let found = issues "list elements" (C.decode_all json) in
  Alcotest.(check (list string))
    "both bad elements"
    [ "/handoff/focus_command/0"; "/handoff/focus_command/2" ]
    (pointers found)

let missing_header_members () =
  let json = `Assoc [ ("otlp", `Assoc [ ("headers", `List [ `Assoc [] ]) ]) ] in
  let found = issues "missing header members" (C.decode_all json) in
  assert_message "name" "/otlp/headers/0/name" "missing" found;
  assert_message "value" "/otlp/headers/0/value" "missing" found;
  assert_message "require" "/otlp/headers" "endpoint" found;
  Alcotest.(check int) "three" 3 (List.length found)

let path_checks_agree () =
  let getenv _ = None in
  let json =
    `Assoc
      [
        ( "skill",
          `Assoc
            [ ("roots", `List [ `String "$TEAM_SKILLS/reference"; `String "~/skills" ]) ]
        );
      ]
  in
  let config =
    match C.t_of_yojson json with
    | Ok config -> C.env ~getenv config
    | Error message -> Alcotest.fail message
  in
  Eio_main.run (fun env ->
      let door =
        match C.validate_paths ~getenv ~fs:env#fs config with
        | Ok () -> Alcotest.fail "expected path errors"
        | Error issues -> issues
      in
      let decoded =
        match C.decode_all ~getenv ~fs:env#fs json with
        | Ok _ -> Alcotest.fail "expected path errors"
        | Error issues -> issues
      in
      Alcotest.(check (list string))
        "binary, then socket, then profile"
        [
          "/chrome/binary";
          "/control/socket";
          "/chrome/profile_dir";
          "/skill/roots/0";
          "/skill/roots/1";
        ]
        (pointers door);
      (* hdoc-vqj7: fields alone are not enough to repair an unset environment. *)
      List.iter
        (fun (pointer, variable) ->
          let issue =
            List.find (fun issue -> issue.Ox_app.Config.pointer = pointer) door
          in
          Alcotest.(check string)
            ("hdoc-vqj7 " ^ variable)
            ("the environment variable " ^ variable ^ " in this path is unset")
            issue.Ox_app.Config.message)
        [
          ("/control/socket", "XDG_RUNTIME_DIR");
          ("/chrome/profile_dir", "XDG_DATA_HOME");
          ("/skill/roots/0", "TEAM_SKILLS");
          ("/skill/roots/1", "HOME");
        ];
      let pair issue = (issue.Ox_app.Config.pointer, issue.Ox_app.Config.message) in
      Alcotest.(check (list (pair string string)))
        "decode_all matches validate_paths" (List.map pair door) (List.map pair decoded))

let () =
  Alcotest.run "daily-config"
    [
      ( "daily-9396",
        List.map
          (fun (name, test) -> Alcotest.test_case name `Quick test)
          [
            ("four problems at once", four_at_once);
            ("success unchanged", success_unchanged);
            ("rich success", rich_success);
            ("otlp and unknown fields", otlp_and_unknown);
            ("headers without endpoint", headers_without_endpoint);
            ("every field", every_field_wrong_type);
            ("list elements", list_elements);
            ("missing header members", missing_header_members);
            ("path checks agree", path_checks_agree);
          ] );
    ]
