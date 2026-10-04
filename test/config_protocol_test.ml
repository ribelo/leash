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

let request_json ?(v = 1) cmd args =
  assoc [ ("v", `Int v); ("cmd", `String cmd); ("args", args) ]

(* ---------- chrome-38a4: the envelope and the per-command arguments ---------- *)

let request_validation () =
  let r =
    assert_ok "anonymous status" (P.decode_request (request_json "status" (assoc [])))
  in
  Alcotest.(check string) "command" "status" (P.command_name r.command);
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
  expect_error "unknown envelope field"
    [ "request"; "unknown field"; "extra" ]
    (P.decode_request
       (assoc [ ("cmd", `String "status"); ("args", assoc []); ("extra", `Bool true) ]));
  expect_error "take needs selector" [ "selector" ]
    (P.decode_request (request_json "take" (assoc [])));
  let r = assert_ok "list" (P.decode_request (request_json "list" (assoc []))) in
  Alcotest.(check string)
    "list has no arguments" "{}"
    (Yojson.Safe.to_string (P.args_to_json r.command))

let command_table =
  [
    ("new", assoc [ ("url", `String "https://example.com") ]);
    ("list", assoc []);
    ("take", assoc [ ("url", `String "https://example.com") ]);
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
          ("snapshot", `String "s_3");
          ("index", `Int 4);
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
          ( "until",
            assoc
              [
                ("text", `String "Ready");
                ("dialog", `Bool true);
                ("changed_since", `String "s_3");
              ] );
          ("timeout_ms", `Int 3_600_000);
        ] );
    ( "net",
      assoc
        [
          ("tab", `String "t_9xk");
          ("match", `String "/api/");
          ("limit", `Int 20);
          ("type", `String "fetch");
        ] );
    ("net_body", assoc [ ("tab", `String "t_9xk"); ("id", `String "1000.5") ]);
    ("net_request", assoc [ ("tab", `String "t_9xk"); ("id", `String "1000.5") ]);
    ( "upload",
      assoc
        [
          ("tab", `String "t_9xk");
          ("snapshot", `String "s_3");
          ("index", `Int 2);
          ("paths", `List [ `String "/tmp/a.txt"; `String "/tmp/b.txt" ]);
        ] );
    ( "hover",
      assoc [ ("tab", `String "t_9xk"); ("snapshot", `String "s_3"); ("index", `Int 4) ]
    );
    ("cookies", assoc [ ("tab", `String "t_9xk") ]);
    ("storage", assoc [ ("tab", `String "t_9xk"); ("area", `String "session") ]);
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
          ("mission", `String "buy the thing");
          ("max_procedures", `Int 3);
          ("deadline_s", `Int 60);
          ("dry_run", `Bool true);
          ("expect", `List [ `String "the page is cart" ]);
          ("out", `String "/tmp/leash-output.jsonl");
        ] );
  ]

let command_round_trip () =
  Alcotest.(check int)
    "hand-scaz handle command round trips" 28 (List.length command_table);
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

(* chrome-38a4: every closed set is a derived variant whose wire names are the [@json.name]s of
   [docs/protocol.md]; the string form an error or a log line prints is read back out of
   the same codec, so a name cannot exist in one and not the other. *)
let closed_sets () =
  let speaks name of_string to_string values =
    List.iter
      (fun wire ->
        match of_string wire with
        | Error message -> Alcotest.failf "%s: %S did not decode: %s" name wire message
        | Ok value -> Alcotest.(check string) (name ^ " " ^ wire) wire (to_string value))
      values
  in
  speaks "origin" P.Origin.of_string P.Origin.to_string [ "agent"; "human" ];
  speaks "dialog kind" P.Dialog_kind.of_string P.Dialog_kind.to_string
    [ "alert"; "confirm"; "prompt"; "beforeunload" ];
  speaks "row state" P.Row_state.of_string P.Row_state.to_string
    [
      "checked";
      "unchecked";
      "mixed";
      "selected";
      "expanded";
      "collapsed";
      "disabled";
      "required";
      "readonly";
    ];
  speaks "debug kind" P.Debug_kind.of_string P.Debug_kind.to_string
    [ "console"; "exception"; "request-failed" ];
  speaks "operation" P.Operation.of_string P.Operation.to_string
    [
      "click";
      "type_text";
      "select";
      "scroll_up";
      "scroll_down";
      "wait";
      "done";
      "blocked";
    ];
  speaks "direction" P.Direction.of_string P.Direction.to_string [ "up"; "down" ];
  speaks "answer" P.Answer.of_string P.Answer.to_string [ "accept"; "dismiss" ];
  speaks "storage area" P.Storage_area.of_string P.Storage_area.to_string
    [ "local"; "session" ];
  speaks "drive status" P.Drive_status.of_string P.Drive_status.to_string
    [ "done"; "blocked"; "step-cap"; "deadline"; "error" ];
  speaks "chrome phase" P.Chrome_phase.of_string P.Chrome_phase.to_string
    [ "running"; "restarting" ];
  speaks "error code" P.Error_code.of_string P.Error_code.to_string
    [
      "invalid-request";
      "ambiguous";
      "no-match";
      "taken";
      "with-human";
      "tab-gone";
      "unknown-tab";
      "stale-snapshot";
      "no-such-row";
      "body-unavailable";
      "unknown-request";
      "row-not-actionable";
      "dialog-open";
      "no-dialog";
      "no-handoff";
      "url-refused";
      "tab-cap";
      "timeout";
      "browser-unavailable";
      "model-unavailable";
      "too-large";
      "internal";
    ];
  match P.Error_code.of_string "mystery" with
  | Ok _ -> Alcotest.fail "a value outside the error-code set decoded"
  | Error message ->
      check_needles "a value outside the set names the set" message
        [ "mystery"; "invalid-request"; "internal" ]

let tab_json =
  assoc
    [
      ("tab", `String "t_9xk");
      ("label", `Null);
      ("url", `String "https://example.com/");
      ("title", `String "Example");
      ("origin", `String "agent");
      ("age_s", `Int 5);
      ("idle_s", `Int 2);
      ("closes_in_s", `Int 1798);
      ("with_human", `Bool false);
      ("generation", `Int 2);
      ("dialog", `Null);
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
      ("settled", `Bool true);
      (* field-jkx6: the codec writes the default AX source; absent reason stays omitted. *)
      ("source", `String "ax");
      ( "dialog",
        assoc
          [
            ("kind", `String "confirm");
            ("message", `String "Sure?");
            ("default_prompt", `Null);
          ] );
    ]

let result_shapes () =
  let tab = assert_ok "tab info" (P.tab_info_of_yojson tab_json) in
  Alcotest.(check string) "capability" "t_9xk" (P.Handle.to_string tab.tab);
  Alcotest.(check int) "age" 5 tab.age_s;
  Alcotest.(check bool) "no hold" false tab.with_human;
  let encoded = P.yojson_of_tab_info tab in
  Alcotest.(check bool) "nullable label" true (field "label" encoded = `Null);
  Alcotest.(check int) "idle" 2 tab.idle_s;
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
  (* docs/protocol.md: [Row.value] and [Row.state] are [key?]; [ActionResult.snapshot] and
     [ActionResult.dialog] are [T|null]; [DebugEntry.level] is [key?]. *)
  let bare_row_json =
    assoc [ ("index", `Int 1); ("role", `String "textbox"); ("name", `String "Search") ]
  in
  let bare_row : P.row =
    {
      index = 1;
      role = "textbox";
      name = "Search";
      value = None;
      state = None;
      options = None;
    }
  in
  Alcotest.(check string)
    "Row key? fields are omitted when None"
    (Yojson.Safe.to_string bare_row_json)
    (Yojson.Safe.to_string (P.yojson_of_row bare_row));
  let absent_row =
    assert_ok "row without value or state" (P.row_of_yojson bare_row_json)
  in
  Alcotest.(check bool)
    "an absent Row key? field is None" true
    (absent_row.value = None && absent_row.state = None && absent_row.options = None);
  (* tab-5deq: a select row carries the options the accessibility tree exposes, each with
     the index the select action takes. *)
  let select_row_json =
    assoc
      [
        ("index", `Int 2);
        ("role", `String "combobox");
        ("name", `String "Course:");
        ( "options",
          `List
            [
              assoc
                [
                  ("index", `Int 0);
                  ("label", `String "Alpha");
                  ("value", `String "a");
                  ("selected", `Bool true);
                  ("disabled", `Bool false);
                ];
            ] );
      ]
  in
  let select_row = assert_ok "select row" (P.row_of_yojson select_row_json) in
  Alcotest.(check string)
    "a Row options list round-trips"
    (Yojson.Safe.to_string select_row_json)
    (Yojson.Safe.to_string (P.yojson_of_row select_row));
  (match select_row.options with
  | Some [ option_ ] ->
      Alcotest.(check int) "the option index is the select action's" 0 option_.index;
      Alcotest.(check bool) "the option is selected" true option_.selected
  | _ -> Alcotest.fail "the select row lost its options");
  let action : P.action_result =
    {
      tab = tab.tab;
      url = "https://example.com/";
      title = "Example";
      snapshot = None;
      dialog = None;
      popups = [];
      hits = None;
      shots = None;
      via = None;
    }
  in
  Alcotest.(check string)
    "ActionResult.snapshot and .dialog stay on the wire as null"
    {|{"tab":"t_9xk","url":"https://example.com/","title":"Example","snapshot":null,"dialog":null,"popups":[]}|}
    (Yojson.Safe.to_string (P.yojson_of_action_result action));
  let action_again =
    assert_ok "action result"
      (P.action_result_of_yojson (P.yojson_of_action_result action))
  in
  Alcotest.(check bool)
    "an ActionResult round-trips" true
    (action_again.snapshot = None && action_again.dialog = None
   && action_again.popups = []);
  let entry : P.debug_entry =
    {
      at = "2026-01-01T00:00:00Z";
      kind = assert_ok "debug kind" (P.Debug_kind.of_string "request-failed");
      level = None;
      text = "boom";
    }
  in
  Alcotest.(check string)
    "DebugEntry.level is key?"
    {|{"at":"2026-01-01T00:00:00Z","kind":"request-failed","text":"boom"}|}
    (Yojson.Safe.to_string (P.yojson_of_debug_entry entry));
  expect_error "unknown row state" [ "state"; "hidden" ]
    (P.row_of_yojson
       (assoc
          [
            ("index", `Int 0);
            ("role", `String "button");
            ("name", `String "Save");
            ("state", `List [ `String "hidden" ]);
          ]))

(* L19: the models section is [T|null] on the reply — the service's own models service is
   always there, a dispatch without one says null — and it never carries the key. *)
let status_result () =
  let json =
    assoc
      [
        ("generation", `Int 3);
        ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
        ("chrome", `String "restarting");
        ("uptime_s", `Float 12.5);
        ("models", `Null);
        ("version", `String "0.0.0");
        ("pid", `Null);
        ("headed", `Bool true);
        ("key_present", `Bool false);
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
  Alcotest.(check (option string))
    "a dispatch without a models service" None
    (Option.map (fun (models : P.models_status) -> models.jev_model) result.models);
  Alcotest.(check string)
    "[@json.key \"open\"]" (Yojson.Safe.to_string json)
    (Yojson.Safe.to_string (P.yojson_of_status_result result));
  let configured =
    assoc
      [
        ("generation", `Int 3);
        ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
        ("chrome", `String "restarting");
        ("uptime_s", `Float 12.5);
        ( "models",
          assoc
            [
              ("configured", `Bool true);
              ("jev_model", `String "typesafe/jev-1.13-20260917");
              ("text_model", `String "inception/mercury-2.5");
              ("systemone_endpoint", `String "https://openrouter.ai/api/v1/systemone");
              ("chat_base_url", `String "https://openrouter.ai/api/v1");
            ] );
        ("version", `String "0.0.0");
        ("pid", `Null);
        ("headed", `Bool true);
        ("key_present", `Bool true);
      ]
  in
  let result = assert_ok "configured status" (P.status_result_of_yojson configured) in
  (match result.models with
  | Some models ->
      Alcotest.(check bool) "drive-e7oi configured" true models.configured;
      Alcotest.(check string)
        "drive-e7oi the pinned model" "typesafe/jev-1.13-20260917" models.jev_model;
      Alcotest.(check string)
        "drive-yqxg the endpoint" "https://openrouter.ai/api/v1/systemone"
        models.systemone_endpoint
  | None -> Alcotest.fail "the models section must decode");
  Alcotest.(check string)
    "the models section round-trips"
    (Yojson.Safe.to_string configured)
    (Yojson.Safe.to_string (P.yojson_of_status_result result));
  expect_error "unknown models field" [ "models"; "oops" ]
    (P.status_result_of_yojson
       (assoc
          [
            ("generation", `Int 3);
            ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
            ("chrome", `String "running");
            ("uptime_s", `Float 1.0);
            ( "models",
              assoc
                [
                  ("configured", `Bool false);
                  ("jev_model", `String "jev");
                  ("text_model", `String "helper");
                  ("systemone_endpoint", `String "https://openrouter.ai/api/v1/systemone");
                  ("chat_base_url", `String "https://openrouter.ai/api/v1");
                  ("oops", `Bool true);
                ] );
            ("version", `String "0.0.0");
            ("pid", `Null);
            ("headed", `Bool true);
            ("key_present", `Bool false);
          ]));
  expect_error "unknown phase" [ "chrome"; "crashed" ]
    (P.status_result_of_yojson
       (assoc
          [
            ("generation", `Int 3);
            ("tabs", assoc [ ("open", `Int 2); ("cap", `Int 8) ]);
            ("chrome", `String "crashed");
            ("uptime_s", `Float 1.0);
            ("models", `Null);
            ("version", `String "0.0.0");
            ("pid", `Null);
            ("headed", `Bool true);
            ("key_present", `Bool false);
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
  let step = match result.steps with [ step ] -> step | _ -> Alcotest.fail "one step" in
  Alcotest.(check string) "operation" "type_text" (P.Operation.to_string step.operation);
  Alcotest.(check (option int)) "index null is None" None step.index;
  Alcotest.(check bool) "map-itbt legacy step has no risk bit" false step.non_repeatable;
  let expected =
    match json with
    | `Assoc fields ->
        `Assoc
          (List.map
             (function
               | "steps", `List [ `Assoc fields ] ->
                   ("steps", `List [ `Assoc (("non_repeatable", `Bool false) :: fields) ])
               | field -> field)
             fields)
    | _ -> assert false
  in
  Alcotest.(check string)
    "Step names its fields including bounded risk"
    (Yojson.Safe.to_string expected)
    (Yojson.Safe.to_string (P.yojson_of_drive_result result));
  let without_text = Yojson.Safe.to_string (P.yojson_of_step { step with text = None }) in
  Alcotest.(check bool)
    "Step.index stays on the wire as null" true
    (contains "\"index\":null" without_text);
  Alcotest.(check bool) "Step.text is key?" true (not (contains "\"text\"" without_text))

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
              ("hint", `String "run `leash snap TAB` again and use its snapshot id");
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
            ( "error",
              assoc
                [
                  ("code", `String "mystery");
                  ("message", `String "x");
                  ("hint", `String "h");
                ] );
          ]));
  expect_error "unknown reply field"
    [ "reply"; "unknown field"; "extra" ]
    (P.decode_reply
       (assoc [ ("ok", `Bool true); ("result", `Null); ("extra", `Bool true) ]))

(* ---------- svc-ljl3, svc-kzt6, svc-tkor: the config type ---------- *)

let config_text ?(headless = false) ?window_size binary profile =
  Printf.sprintf
    "[chrome]\n\
     binary = %S\n\
     profile_dir = %S\n\
     workspace = \"leash\"\n\
     %s%s[tabs]\n\
     cap = 8\n\
     [expiry]\n\
     idle_s = 1800\n\
     tombstone_s = 3600\n\
     [models]\n\
     api_key = \"file-secret\"\n\
     jev_model = \"jev\"\n\
     text_model = \"helper\"\n"
    binary profile
    (if headless then "headless = true\n" else "")
    (match window_size with
    | None -> ""
    | Some size -> Printf.sprintf "window_size = %S\n" size)

(* svc-x8rp svc-o4wt: the two XDG variables a service session has, so the defaults a file
   leaves out resolve the way they do in production; a test that wants them unset says so. *)
let config_decode
    ?(getenv =
      function
      | "XDG_DATA_HOME" -> Some "/tmp/leash-xdg-data"
      | "XDG_RUNTIME_DIR" -> Some "/tmp/leash-xdg-runtime"
      | _ -> None) text =
  Ox_app.Config.decode ~spec:C.spec ~getenv text

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
  Alcotest.(check string)
    "chrome-p2n4 default headless viewport" "1366,900"
    (C.Text.to_string headless.chrome.window_size);
  let custom =
    match
      config_decode
        (config_text ~headless:true ~window_size:"1440,960" "/tmp/chrome" "/tmp/profile")
    with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  Alcotest.(check string)
    "chrome-p2n4 custom TOML viewport" "1440,960"
    (C.Text.to_string custom.chrome.window_size);
  Alcotest.(check bool)
    "chrome-p2n4 custom launch flag" true
    (List.mem "--window-size=1440,960"
       (Leash.Chrome.argv (C.chrome_config custom.chrome)));
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

(* hand-04rb hand-phof hand-rg9h: the two desktop commands a handoff runs are config with
   the spec's defaults — niri's window focus for the managed Chrome and notify-send's Done
   action — and an empty list turns that step off. *)
let handoff_commands () =
  let base = config_text "/tmp/chrome" "/tmp/profile" in
  let value =
    match config_decode base with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  Alcotest.(check (list string))
    "daily-n7on a handoff takes no focus by default (operator 2026-10-01)" []
    value.C.handoff.focus_command;
  Alcotest.(check (list string))
    "pilot-9u3q persistent notification offers Done and Cancel"
    [
      "notify-send";
      "--urgency=critical";
      "--expire-time=0";
      "--app-name=Leash";
      "--action";
      "done=Done";
      "--action";
      "cancel=Cancel";
      "Leash needs you";
      "{reason}";
    ]
    value.C.handoff.notify_command;
  let configured =
    base
    ^ "[handoff]\n\
       focus_command = [ \"focus-it\", \"--tab\", \"{tab}\" ]\n\
       notify_command = []\n"
  in
  let value =
    match config_decode configured with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  Alcotest.(check (list string))
    "hand-rg9h a configured focus command replaces the default"
    [ "focus-it"; "--tab"; "{tab}" ]
    value.C.handoff.focus_command;
  Alcotest.(check (list string))
    "hand-rg9h an empty notification command turns that step off" []
    value.C.handoff.notify_command;
  Alcotest.(check bool)
    "hand-rg9h the handoff section is part of the printed config" true
    (contains "notify_command" (Yojson.Safe.to_string (C.yojson_of_t value)))

let with_temp ~(caps : < Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) f =
  let path = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-l1-" "" in
  Ox_caps.Cap_unix.unlink ~caps path;
  Ox_caps.Cap_unix.mkdir ~caps path 0o700;
  Fun.protect
    ~finally:(fun () ->
      (try
         Ox_caps.Cap_unix.unlink ~caps
           (Filename.concat (Filename.concat path "leash") "control.sock")
       with _ -> ());
      (try Ox_caps.Cap_unix.rmdir ~caps (Filename.concat path "leash") with _ -> ());
      List.iter
        (fun name ->
          try Ox_caps.Cap_unix.unlink ~caps (Filename.concat path name) with _ -> ())
        [ "binary"; "config.toml"; "stdout"; "stderr" ];
      (try Ox_caps.Cap_unix.rmdir ~caps (Filename.concat path "profile") with _ -> ());
      Ox_caps.Cap_unix.rmdir ~caps path)
    (fun () -> f path)

let path_validation
    ~(caps : < Ox_caps.Cap.env ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp ~caps (fun dir ->
      let binary = Filename.concat dir "binary" in
      let profile = Filename.concat dir "profile" in
      let config =
        match config_decode (config_text binary profile) with
        | Ok value -> value
        | Error (`Config message) -> Alcotest.fail message
      in
      Eio_main.run (fun env ->
          let check ~(caps : < Ox_caps.Cap.env ; .. >) () =
            C.validate_paths ~getenv:(Ox_caps.Cap_sys.getenv_opt ~caps) ~fs:env#fs config
          in
          Alcotest.(check bool) "missing binary" true (Result.is_error (check ~caps ()));
          let out = Ox_caps.Cap_stdlib.open_out ~caps binary in
          close_out out;
          Ox_caps.Cap_unix.chmod ~caps binary 0o700;
          Alcotest.(check bool) "creatable profile" true (Result.is_ok (check ~caps ()));
          Ox_caps.Cap_unix.mkdir ~caps profile 0o700;
          Alcotest.(check bool) "readable profile" true (Result.is_ok (check ~caps ()));
          Ox_caps.Cap_unix.chmod ~caps profile 0o000;
          Alcotest.(check bool)
            "unreadable profile" true
            (Result.is_error (check ~caps ()));
          Ox_caps.Cap_unix.chmod ~caps profile 0o700))

let config_check_cli
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_temp ~caps (fun dir ->
      let binary = Filename.concat dir "binary" in
      let config_file = Filename.concat dir "config.toml" in
      let write ~(caps : < Ox_caps.Cap.fs_write ; .. >) text =
        let out = Ox_caps.Cap_stdlib.open_out ~caps config_file in
        output_string out text;
        close_out out
      in
      write ~caps (config_text binary (Filename.concat dir "profile"));
      let executable =
        Filename.concat
          (Filename.dirname Sys.executable_name)
          "../packages/leash/bin/main.exe"
      in
      let check
          ~(caps :
             < Ox_caps.Cap.env
             ; Ox_caps.Cap.exec
             ; Ox_caps.Cap.fork
             ; Ox_caps.Cap.fs_read
             ; Ox_caps.Cap.fs_write
             ; Ox_caps.Cap.stdin
             ; .. >) () =
        let output = Filename.concat dir "stdout" in
        let error = Filename.concat dir "stderr" in
        let stdout =
          Ox_caps.Cap_unix.openfile ~caps output
            [ Unix.O_CREAT; Unix.O_TRUNC; Unix.O_WRONLY ]
            0o600
        in
        let stderr =
          Ox_caps.Cap_unix.openfile ~caps error
            [ Unix.O_CREAT; Unix.O_TRUNC; Unix.O_WRONLY ]
            0o600
        in
        let pid =
          Ox_caps.Cap_unix.create_process_env ~caps executable
            [| executable; "config"; "check"; "--config"; config_file |]
            (Ox_caps.Cap_unix.environment ~caps ())
            (Unix.descr_of_in_channel (Ox_caps.Cap_stdlib.stdin ~caps))
            stdout stderr
        in
        Unix.close stdout;
        Unix.close stderr;
        let _, status = Unix.waitpid [] pid in
        let contents ~(caps : < Ox_caps.Cap.fs_read ; .. >) file =
          let channel = Ox_caps.Cap_stdlib.open_in ~caps file in
          Fun.protect
            ~finally:(fun () -> close_in channel)
            (fun () -> really_input_string channel (in_channel_length channel))
        in
        (status, contents ~caps output, contents ~caps error)
      in
      let status, _, error = check ~caps () in
      Alcotest.(check bool)
        "missing executable rejected with config-data exit" true (status = Unix.WEXITED 65);
      Alcotest.(check bool)
        "JSON pointer in diagnostic" true
        (List.mem "chrome" (String.split_on_char '/' error));
      close_out (Ox_caps.Cap_stdlib.open_out ~caps binary);
      Ox_caps.Cap_unix.chmod ~caps binary 0o700;
      let status, output, _ = check ~caps () in
      Alcotest.(check bool) "valid filesystem accepted" true (status = Unix.WEXITED 0);
      Alcotest.(check bool) "redacted config printed" true (String.length output > 0);
      Alcotest.(check bool) "secret absent" false (contains "file-secret" output);
      write ~caps (config_text binary (Filename.concat dir "profile") ^ "oops = true\n");
      let status, _, error = check ~caps () in
      Alcotest.(check bool)
        "unknown key exits config-data class" true (status = Unix.WEXITED 65);
      Alcotest.(check bool) "unknown key named" true (contains "oops" error))

let socket_cli_case
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) ?(expected_lines = []) ?on_command argv reply expected_status
    expected_command =
  with_temp ~caps (fun runtime ->
      let dir = Filename.concat runtime "leash" in
      Ox_caps.Cap_unix.mkdir ~caps dir 0o700;
      let path = Filename.concat dir "control.sock" in
      let listener = Ox_caps.Cap_unix.socket ~caps Unix.PF_UNIX Unix.SOCK_STREAM 0 in
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
          (* svc-o4wt: a fresh XDG_CONFIG_HOME, so the CLI reads no configuration and
             falls back to the runtime directory these cases write in. *)
          let env =
            Array.to_list (Ox_caps.Cap_unix.environment ~caps ())
            |> List.filter (fun item ->
                not
                  (String.starts_with ~prefix:"XDG_RUNTIME_DIR=" item
                  || String.starts_with ~prefix:"XDG_CONFIG_HOME=" item))
          in
          let env =
            Array.of_list
              (("XDG_RUNTIME_DIR=" ^ runtime)
              :: ("XDG_CONFIG_HOME=" ^ Filename.concat runtime "config")
              :: env)
          in
          let pid =
            Ox_caps.Cap_unix.create_process_env ~caps binary
              (Array.of_list (binary :: argv))
              env
              (Unix.descr_of_in_channel (Ox_caps.Cap_stdlib.stdin ~caps))
              out_write err_write
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
          (match on_command with None -> () | Some check -> check decoded.command);
          let output = Unix.out_channel_of_descr (Unix.dup peer) in
          output_string output (reply ^ "\n");
          flush output;
          close_out output;
          close_in input;
          let _, status = Unix.waitpid [] pid in
          Alcotest.(check bool)
            "CLI exit code" true
            (status = Unix.WEXITED expected_status);
          let stream =
            Unix.in_channel_of_descr (if expected_status = 0 then out_read else err_read)
          in
          let text = input_line stream in
          Alcotest.(check bool) "prints JSON or table" true (String.length text > 0);
          (match expected_lines with
          | [] -> ()
          | header :: rows ->
              Alcotest.(check string) "table header" header text;
              List.iter
                (fun expected ->
                  Alcotest.(check string) "table row" expected (input_line stream))
                rows);
          close_in stream;
          Unix.close (if expected_status = 0 then err_read else out_read)))

let socket_cli
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  socket_cli_case ~caps [ "status" ] "{\"ok\":true,\"result\":{}}" 0 "status";
  socket_cli_case ~caps
    ~on_command:(function
      | P.New { label = Some "Research"; _ } -> () | _ -> Alcotest.fail "label")
    [ "new"; "--label"; "Research" ]
    (Yojson.Safe.to_string (P.encode_reply (P.Success tab_json)))
    0 "new";
  socket_cli_case ~caps
    ~on_command:(function
      | P.Take { title = Some "Inbox"; _ } -> () | _ -> Alcotest.fail "selector")
    [ "take"; "--title"; "Inbox" ]
    (Yojson.Safe.to_string (P.encode_reply (P.Success tab_json)))
    0 "take";
  socket_cli_case ~caps [ "close"; "t_9xk" ] "{\"ok\":true,\"result\":{\"closed\":true}}"
    0 "close";
  socket_cli_case ~caps
    ~expected_lines:
      [
        "LABEL\tURL\tTITLE\tPAGE_KIND\tKIND_SOURCE\tORIGIN\tAGE_S\tIDLE_S\tCLOSES_IN_S\tWITH_HUMAN";
      ]
    [ "list"; "--table" ] "{\"ok\":true,\"result\":{\"tabs\":[]}}" 0 "list";
  socket_cli_case ~caps
    ~expected_lines:
      [
        "PAGE_KIND\t-\tKIND_SOURCE\t-";
        "INDEX\tROLE\tNAME\tVALUE\tSTATE";
        "0\tbutton\tSave\t1\tdisabled,required";
      ]
    [ "snap"; "t_9xk"; "--table" ]
    (Yojson.Safe.to_string (P.encode_reply (P.Success snapshot_json)))
    0 "snap"

let cli_usage
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; .. >) () =
  let binary =
    Filename.concat
      (Filename.dirname Sys.executable_name)
      "../packages/leash/bin/main.exe"
  in
  let null = Ox_caps.Cap_unix.openfile ~caps "/dev/null" [ Unix.O_WRONLY ] 0o600 in
  Fun.protect
    ~finally:(fun () -> Unix.close null)
    (fun () ->
      let pid =
        Ox_caps.Cap_unix.create_process_env ~caps binary
          [| binary; "status"; "unexpected" |]
          (Ox_caps.Cap_unix.environment ~caps ())
          (Unix.descr_of_in_channel (Ox_caps.Cap_stdlib.stdin ~caps))
          null null
      in
      let _, status = Unix.waitpid [] pid in
      Alcotest.(check bool)
        "CLI parsing exits Cmdliner class" true (status = Unix.WEXITED 124))

(* svc-f4op: default-off OTLP, enabled endpoint, secret-wrapped headers, bad URLs. *)
let otlp_config () =
  let base = config_text "/tmp/chrome" "/tmp/profile" in
  let decode text =
    match config_decode text with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail message
  in
  let absent = decode base in
  Alcotest.(check bool)
    "OTLP disabled by default" true
    (absent.C.otlp.endpoint = None && absent.C.otlp.headers = []);
  let enabled =
    decode
      (base ^ "[otlp]\nendpoint = \"http://127.0.0.1:4318/base\"\n"
     ^ "[[otlp.headers]]\nname = \"Authorization\"\nvalue = \"secret-collector-token\"\n"
      )
  in
  Alcotest.(check (option string))
    "configured endpoint" (Some "http://127.0.0.1:4318/base")
    (Option.map C.Text.to_string enabled.C.otlp.endpoint);
  let header = List.hd enabled.C.otlp.headers in
  Alcotest.(check string) "header name" "Authorization" (C.Text.to_string header.C.name);
  Alcotest.(check string)
    "export-only header" "secret-collector-token"
    (C.Redact.expose header.C.value);
  let rendered = C.yojson_of_t enabled |> Yojson.Safe.to_string in
  Alcotest.(check bool)
    "header redacted" false
    (contains "secret-collector-token" rendered);
  Alcotest.(check bool) "marked redacted" true (contains "<redacted>" rendered);
  Alcotest.(check bool) "valid endpoint" true (Result.is_ok (C.validate_otlp enabled));
  let endpoint value =
    match C.Text.of_string value with
    | Ok text -> text
    | Error message -> Alcotest.fail message
  in
  let error_pointer expected value =
    match C.validate_otlp value with
    | Ok () -> Alcotest.fail ("expected invalid " ^ expected)
    | Error issues ->
        Alcotest.(check string)
          "error pointer" expected (List.hd issues).Ox_app.Config.pointer
  in
  error_pointer "/otlp/headers"
    { enabled with otlp = { endpoint = None; headers = enabled.otlp.headers } };
  error_pointer "/otlp/endpoint"
    {
      enabled with
      otlp =
        {
          enabled.otlp with
          endpoint = Some (endpoint "https://user:password@example.com");
        };
    };
  error_pointer "/otlp/endpoint"
    {
      enabled with
      otlp =
        { enabled.otlp with endpoint = Some (endpoint "http://127.0.0.1:4318/?token=x") };
    };
  error_pointer "/otlp/headers/0/value"
    {
      enabled with
      otlp =
        {
          enabled.otlp with
          headers = [ { header with value = C.Redact.make "evil\r\nX-Test: attack" } ];
        };
    }

(* ---------- svc-x8rp, svc-o4wt, svc-hi4f: defaults, config init, the socket, help ---------- *)

let binary_path () =
  Filename.concat (Filename.dirname Sys.executable_name) "../packages/leash/bin/main.exe"

let file_contents ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
  let channel = Ox_caps.Cap_stdlib.open_in ~caps path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

(* A temporary tree this test owns end to end: every file and directory it made goes away
   with it, sockets and nested configuration directories included. *)
let with_tree
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) f =
  let root = Ox_caps.Cap_stdlib.Filename.temp_file ~caps "leash-cli-" "" in
  Ox_caps.Cap_unix.unlink ~caps root;
  Ox_caps.Cap_unix.mkdir ~caps root 0o700;
  let rec remove ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
    match (Unix.lstat path).Unix.st_kind with
    | Unix.S_DIR ->
        Array.iter
          (fun name -> remove ~caps (Filename.concat path name))
          (Ox_caps.Cap_sys.readdir ~caps path);
        Ox_caps.Cap_unix.rmdir ~caps path
    | _ -> Ox_caps.Cap_unix.unlink ~caps path
  in
  Fun.protect ~finally:(fun () -> try remove ~caps root with _ -> ()) (fun () -> f root)

(* The CLI with [env] replacing the inherited values of those names, answering its status,
   stdout and stderr. *)
let run_cli
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) ?(env = []) argv =
  let binary = binary_path () in
  with_tree ~caps (fun root ->
      let stdout = Filename.concat root "stdout"
      and stderr = Filename.concat root "stderr" in
      let out =
        Ox_caps.Cap_unix.openfile ~caps stdout [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600
      in
      let err =
        Ox_caps.Cap_unix.openfile ~caps stderr [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600
      in
      let keys = List.map (fun (key, _) -> key ^ "=") env in
      let inherited =
        Array.to_list (Ox_caps.Cap_unix.environment ~caps ())
        |> List.filter (fun item ->
            not (List.exists (fun key -> String.starts_with ~prefix:key item) keys))
      in
      let pid =
        Ox_caps.Cap_unix.create_process_env ~caps binary
          (Array.of_list (binary :: argv))
          (Array.of_list
             (List.map (fun (key, value) -> key ^ "=" ^ value) env @ inherited))
          (Unix.descr_of_in_channel (Ox_caps.Cap_stdlib.stdin ~caps))
          out err
      in
      Unix.close out;
      Unix.close err;
      let _, status = Unix.waitpid [] pid in
      (status, file_contents ~caps stdout, file_contents ~caps stderr))

(* The CLI answered once on [listener]; how a test drives it where a service would be. *)
let run_cli_at
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) listener ~env argv reply =
  let binary = binary_path () in
  with_tree ~caps (fun root ->
      let stdout = Filename.concat root "stdout"
      and stderr = Filename.concat root "stderr" in
      let out =
        Ox_caps.Cap_unix.openfile ~caps stdout [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600
      in
      let err =
        Ox_caps.Cap_unix.openfile ~caps stderr [ Unix.O_CREAT; Unix.O_WRONLY ] 0o600
      in
      let keys = List.map (fun (key, _) -> key ^ "=") env in
      let inherited =
        Array.to_list (Ox_caps.Cap_unix.environment ~caps ())
        |> List.filter (fun item ->
            not (List.exists (fun key -> String.starts_with ~prefix:key item) keys))
      in
      let pid =
        Ox_caps.Cap_unix.create_process_env ~caps binary
          (Array.of_list (binary :: argv))
          (Array.of_list
             (List.map (fun (key, value) -> key ^ "=" ^ value) env @ inherited))
          (Unix.descr_of_in_channel (Ox_caps.Cap_stdlib.stdin ~caps))
          out err
      in
      Unix.close out;
      Unix.close err;
      let ready, _, _ = Unix.select [ listener ] [] [] 5. in
      if ready = [] then Alcotest.fail "the CLI did not connect";
      let peer, _ = Unix.accept listener in
      let input = Unix.in_channel_of_descr peer in
      ignore (Yojson.Safe.from_string (input_line input));
      let output = Unix.out_channel_of_descr (Unix.dup peer) in
      output_string output (reply ^ "\n");
      flush output;
      close_out output;
      close_in input;
      let _, status = Unix.waitpid [] pid in
      (status, file_contents ~caps stdout, file_contents ~caps stderr))

(* svc-x8rp: the default binary is a bare name, so validation looks it up on PATH and
   names the field when nothing provides it. *)
let binary_on_path
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_tree ~caps (fun root ->
      let bin = Filename.concat root "bin" in
      let empty = Filename.concat root "empty" in
      Ox_caps.Cap_unix.mkdir ~caps bin 0o700;
      Ox_caps.Cap_unix.mkdir ~caps empty 0o700;
      let stub = Filename.concat bin "google-chrome-stable" in
      close_out (Ox_caps.Cap_stdlib.open_out ~caps stub);
      Ox_caps.Cap_unix.chmod ~caps stub 0o700;
      let environment path key =
        match key with
        | "PATH" -> Some path
        | "XDG_DATA_HOME" -> Some (Filename.concat root "data")
        | "XDG_RUNTIME_DIR" -> Some (Filename.concat root "runtime")
        | _ -> None
      in
      let decode path text =
        match Ox_app.Config.decode ~spec:C.spec ~getenv:(environment path) text with
        | Ok value -> value
        | Error (`Config message) -> Alcotest.fail message
      in
      let found = decode bin "[tabs]\ncap = 2\n" in
      let missing = decode empty "" in
      let refusal fs label config =
        match C.validate_paths ~getenv:(environment empty) ~fs config with
        | Ok () -> Alcotest.fail (label ^ ": expected a refusal")
        | Error issues -> issues
      in
      Eio_main.run (fun env ->
          Alcotest.(check bool)
            "svc-x8rp google-chrome-stable is found on PATH" true
            (Result.is_ok (C.validate_paths ~getenv:(environment bin) ~fs:env#fs found));
          let issues = refusal env#fs "missing binary" missing in
          Alcotest.(check string)
            "svc-x8rp a bare name nothing provides is refused by pointer" "/chrome/binary"
            (List.hd issues).Ox_app.Config.pointer;
          Alcotest.(check bool)
            "svc-x8rp and the message says PATH" true
            (contains "PATH" (List.hd issues).Ox_app.Config.message)))

(* svc-o4wt svc-x8rp: a variable that is unset leaves its placeholder in the path, and
   validation names that field instead of letting the service write a directory called
   $XDG_DATA_HOME or a socket called $XDG_RUNTIME_DIR. *)
let unset_xdg_paths
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_tree ~caps (fun root ->
      let stub = Filename.concat root "chrome" in
      close_out (Ox_caps.Cap_stdlib.open_out ~caps stub);
      Ox_caps.Cap_unix.chmod ~caps stub 0o700;
      let decode text =
        match Ox_app.Config.decode ~spec:C.spec ~getenv:(fun _ -> None) text with
        | Ok value -> value
        | Error (`Config message) -> Alcotest.fail message
      in
      let pointer ~(caps : < Ox_caps.Cap.env ; .. >) ~fs label config =
        match C.validate_paths ~getenv:(Ox_caps.Cap_sys.getenv_opt ~caps) ~fs config with
        | Ok () -> Alcotest.fail (label ^ ": expected a refusal")
        | Error issues -> (List.hd issues).Ox_app.Config.pointer
      in
      let chrome = Printf.sprintf "[chrome]\nbinary = %S\n" stub in
      Eio_main.run (fun env ->
          Alcotest.(check string)
            "svc-o4wt an unset XDG_RUNTIME_DIR is refused at control.socket"
            "/control/socket"
            (pointer ~caps ~fs:env#fs "socket" (decode chrome));
          Alcotest.(check string)
            "svc-x8rp an unset XDG_DATA_HOME is refused at chrome.profile_dir"
            "/chrome/profile_dir"
            (pointer ~caps ~fs:env#fs "profile"
               (decode (chrome ^ "[control]\nsocket = \"/tmp/leash-unset.sock\"\n")))))

(* svc-x8rp svc-o4wt: a file that says nothing — or names one setting — is a
   configuration, and the two XDG paths expand from the environment. *)
let config_defaults () =
  let getenv key =
    match key with
    | "XDG_DATA_HOME" -> Some "/tmp/leash-xdg-data"
    | "XDG_RUNTIME_DIR" -> Some "/tmp/leash-runtime"
    | _ -> None
  in
  let default = C.env ~getenv C.default in
  let decode name text =
    match Ox_app.Config.decode ~spec:C.spec ~getenv text with
    | Ok value -> value
    | Error (`Config message) -> Alcotest.fail (name ^ ": " ^ message)
  in
  Alcotest.(check string)
    "svc-x8rp a file that says nothing is the defaults"
    (Yojson.Safe.to_string (C.yojson_of_t default))
    (Yojson.Safe.to_string (C.yojson_of_t (decode "empty" "")));
  let partial = decode "partial" "[tabs]\ncap = 4\n" in
  Alcotest.(check int)
    "svc-x8rp the named setting wins" 4
    (C.Tab_cap.to_int partial.C.tabs.cap);
  Alcotest.(check string)
    "svc-x8rp the profile default expands XDG_DATA_HOME"
    "/tmp/leash-xdg-data/leash/profile"
    (C.Text.to_string partial.C.chrome.profile_dir);
  Alcotest.(check string)
    "svc-o4wt the socket default expands XDG_RUNTIME_DIR"
    "/tmp/leash-runtime/leash/control.sock"
    (C.Text.to_string partial.C.control.socket);
  Alcotest.(check int) "svc-x8rp ADR-0005's cap" 32 (C.Tab_cap.to_int default.C.tabs.cap);
  Alcotest.(check int)
    "svc-x8rp ADR-0005's idle" 1800
    (C.Seconds.to_int default.C.expiry.idle_s);
  Alcotest.(check string)
    "svc-x8rp the commented file is the same defaults"
    (Yojson.Safe.to_string (C.yojson_of_t default))
    (Yojson.Safe.to_string (C.yojson_of_t (decode "the commented file" C.default_toml)));
  List.iter
    (fun name ->
      Alcotest.(check bool)
        ("svc-x8rp the file documents " ^ name)
        true
        (contains name C.default_toml))
    [
      "binary";
      "profile_dir";
      "workspace";
      "cap";
      "idle_s";
      "tombstone_s";
      "socket";
      "systemone_endpoint";
      "jev_model";
      "chat_base_url";
      "text_model";
      "focus_command";
      "notify_command";
    ]

(* svc-x8rp: init writes the commented defaults, refuses to overwrite, and --force is the
   operator's yes. Both go through the file mode the config's API key deserves. *)
let config_init
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_tree ~caps (fun root ->
      let dir = Filename.concat root "leash" in
      let path = Filename.concat dir "config.toml" in
      (match C.init ~caps ~path () with
      | Ok written ->
          Alcotest.(check string) "svc-x8rp init answers the path it wrote" path written
      | Error _ -> Alcotest.fail "svc-x8rp init refused a fresh path");
      Alcotest.(check string)
        "svc-x8rp init writes the commented defaults" C.default_toml
        (file_contents ~caps path);
      Alcotest.(check int)
        "svc-x8rp the file is private" 0o600 (Unix.stat path).Unix.st_perm;
      Alcotest.(check int)
        "svc-x8rp its directory is private too" 0o700 (Unix.stat dir).Unix.st_perm;
      (match C.init ~caps ~path () with
      | Ok _ -> Alcotest.fail "svc-x8rp init overwrote a file without --force"
      | Error (`Exists refused) ->
          Alcotest.(check string) "svc-x8rp it names what it refused" path refused
      | Error (`Write error) -> Alcotest.fail ("svc-x8rp init failed: " ^ error.message));
      Alcotest.(check string)
        "svc-x8rp the refused file is untouched" C.default_toml (file_contents ~caps path);
      let out = Ox_caps.Cap_stdlib.open_out ~caps path in
      output_string out "oops = true\n";
      close_out out;
      (match C.init ~caps ~force:true ~path () with
      | Ok _ -> ()
      | Error _ -> Alcotest.fail "svc-x8rp init --force did not overwrite");
      Alcotest.(check string)
        "svc-x8rp --force restores the defaults" C.default_toml (file_contents ~caps path))

(* svc-x8rp: the same through the Door, which is where the operator meets it. *)
let config_init_cli
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_tree ~caps (fun root ->
      let home = Filename.concat root "config" in
      let file = Filename.concat (Filename.concat home "leash") "config.toml" in
      let env = [ ("XDG_CONFIG_HOME", home) ] in
      let status, output, error = run_cli ~caps ~env [ "config"; "init" ] in
      Alcotest.(check bool)
        "svc-x8rp config init exits zero" true (status = Unix.WEXITED 0);
      Alcotest.(check string) "svc-x8rp it names the file" (file ^ "\n") output;
      Alcotest.(check string) "svc-x8rp it writes no diagnostic" "" error;
      Alcotest.(check string)
        "svc-x8rp the CLI writes the commented defaults" C.default_toml
        (file_contents ~caps file);
      let status, _, error = run_cli ~caps ~env [ "config"; "init" ] in
      Alcotest.(check bool)
        "svc-x8rp a second init exits usage class" true (status = Unix.WEXITED 64);
      Alcotest.(check bool)
        "svc-x8rp and says how to overwrite" true (contains "--force" error);
      let status, _, _ = run_cli ~caps ~env [ "config"; "init"; "--force" ] in
      Alcotest.(check bool) "svc-x8rp --force overwrites" true (status = Unix.WEXITED 0))

(* svc-x8rp: a first run has no file at $XDG_CONFIG_HOME/leash/config.toml. The Door
   decodes the empty document as the defaults and enters the program — that is the service
   starting, before Chrome is anywhere in the picture — while a --config path that is not
   there stays an error naming it (napp-9x0s). The program here is a stub: what the service
   does once it is entered belongs to the other stories, and unit tests launch no browser. *)
let service_starts_without_config
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_tree ~caps (fun root ->
      let config_home = Filename.concat root "config" in
      let runtime = Filename.concat root "runtime" in
      let data = Filename.concat root "data" in
      List.iter
        (fun path -> Ox_caps.Cap_unix.mkdir ~caps path 0o700)
        [ config_home; runtime; data ];
      let getenv key =
        match key with
        | "XDG_CONFIG_HOME" -> Some config_home
        | "XDG_RUNTIME_DIR" -> Some runtime
        | "XDG_DATA_HOME" -> Some data
        | _ -> None
      in
      let expected = C.env ~getenv C.default in
      let default_path =
        Filename.concat (Filename.concat config_home "leash") "config.toml"
      in
      Ox_test.run (fun env _sw ->
          let entered = ref None in
          let read_paths = ref [] in
          let read path =
            read_paths := path :: !read_paths;
            Error `Missing
          in
          let run argv =
            let stderr = Buffer.create 256 in
            let stdout = Buffer.create 256 in
            let code =
              Ox_app.run_for_test ~env
                ~journal:(Ox_observability.Logger.Reporter.writer ignore)
                ~name:"leash" ~config:C.spec
                ~pp_err:(fun fmt (`Service message) -> Format.pp_print_string fmt message)
                ~getenv ~read
                ~stderr:(fun text -> Buffer.add_string stderr text)
                ~stdout:(fun text -> Buffer.add_string stdout text)
                ~argv
                (fun _env config _sw ->
                  entered := Some config;
                  Ok ())
            in
            (code, Buffer.contents stdout, Buffer.contents stderr)
          in
          let code, _, error = run [| "leash"; "run" |] in
          Alcotest.(check int) "svc-x8rp run with no config file exits zero" 0 code;
          Alcotest.(check string) "svc-x8rp it writes no diagnostic" "" error;
          Alcotest.(check (list string))
            "svc-x8rp the Door reads the default path" [ default_path ]
            (List.rev !read_paths);
          (match !entered with
          | None -> Alcotest.fail "svc-x8rp the program was never entered"
          | Some config ->
              Alcotest.(check string)
                "svc-x8rp the service starts on the defaults"
                (Yojson.Safe.to_string (C.yojson_of_t expected))
                (Yojson.Safe.to_string (C.yojson_of_t config)));
          entered := None;
          read_paths := [];
          let missing = Filename.concat root "nowhere.toml" in
          let code, _, error = run [| "leash"; "run"; "--config"; missing |] in
          Alcotest.(check int) "svc-x8rp an absent --config exits two" 2 code;
          Alcotest.(check bool)
            "svc-x8rp and names the path" true (contains missing error);
          Alcotest.(check bool)
            "svc-x8rp and enters no program" true (Option.is_none !entered)))

(* svc-x8rp: the same through the real binary, where the Door's own filesystem read
   supplies [`Missing] and the CLI is the operator's first call. *)
let config_check_without_file
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_tree ~caps (fun root ->
      let config_home = Filename.concat root "config" in
      let runtime = Filename.concat root "runtime" in
      let data = Filename.concat root "data" in
      let bin = Filename.concat root "bin" in
      List.iter
        (fun path -> Ox_caps.Cap_unix.mkdir ~caps path 0o700)
        [ config_home; runtime; data; bin ];
      let stub = Filename.concat bin "google-chrome-stable" in
      close_out (Ox_caps.Cap_stdlib.open_out ~caps stub);
      Ox_caps.Cap_unix.chmod ~caps stub 0o700;
      let env =
        [
          ("XDG_CONFIG_HOME", config_home);
          ("XDG_RUNTIME_DIR", runtime);
          ("XDG_DATA_HOME", data);
          ("PATH", bin);
        ]
      in
      let status, output, error = run_cli ~caps ~env [ "config"; "check" ] in
      Alcotest.(check bool)
        "svc-x8rp config check with no file exits zero" true (status = Unix.WEXITED 0);
      Alcotest.(check string) "svc-x8rp it writes no diagnostic" "" error;
      Alcotest.(check bool)
        "svc-x8rp the defaults carry the runtime socket" true
        (contains
           (Filename.concat (Filename.concat runtime "leash") "control.sock")
           output);
      let missing = Filename.concat root "nowhere.toml" in
      let status, _, error =
        run_cli ~caps ~env [ "config"; "check"; "--config"; missing ]
      in
      Alcotest.(check bool)
        "svc-x8rp an absent --config exits config-data class" true
        (status = Unix.WEXITED 65);
      Alcotest.(check bool) "svc-x8rp and names the path" true (contains missing error))

(* svc-o4wt: the CLI connects where control.socket says — not where XDG_RUNTIME_DIR would
   put a socket — and --socket overrides the file for one call. *)
let socket_config_cli
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.network
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_tree ~caps (fun root ->
      let config_home = Filename.concat root "config" in
      let dir = Filename.concat config_home "leash" in
      let runtime = Filename.concat root "runtime" in
      Ox_caps.Cap_unix.mkdir ~caps config_home 0o700;
      Ox_caps.Cap_unix.mkdir ~caps dir 0o700;
      Ox_caps.Cap_unix.mkdir ~caps runtime 0o700;
      let configured = Filename.concat root "configured.sock" in
      let override = Filename.concat root "override.sock" in
      let out = Ox_caps.Cap_stdlib.open_out ~caps (Filename.concat dir "config.toml") in
      output_string out (Printf.sprintf "[control]\nsocket = %S\n" configured);
      close_out out;
      let listen ~(caps : < Ox_caps.Cap.network ; .. >) path =
        let listener = Ox_caps.Cap_unix.socket ~caps Unix.PF_UNIX Unix.SOCK_STREAM 0 in
        Unix.bind listener (Unix.ADDR_UNIX path);
        Unix.listen listener 1;
        listener
      in
      let configured_listener = listen ~caps configured in
      let override_listener = listen ~caps override in
      Fun.protect
        ~finally:(fun () ->
          Unix.close configured_listener;
          Unix.close override_listener)
        (fun () ->
          let env = [ ("XDG_CONFIG_HOME", config_home); ("XDG_RUNTIME_DIR", runtime) ] in
          let reply = "{\"ok\":true,\"result\":{\"tabs\":[]}}" in
          let status, output, _ =
            run_cli_at ~caps configured_listener ~env [ "list" ] reply
          in
          Alcotest.(check bool)
            "svc-o4wt the configured socket answers the CLI" true (status = Unix.WEXITED 0);
          Alcotest.(check bool)
            "svc-o4wt it prints the reply" true (contains "tabs" output);
          (* a relative or unset socket is refused before anything connects *)
          let status, _, error =
            run_cli ~caps ~env [ "list"; "--socket"; "$XDG_RUNTIME_DIR/nope.sock" ]
          in
          Alcotest.(check bool)
            "svc-o4wt an unresolved --socket is an error, not a silent default" false
            (status = Unix.WEXITED 0);
          Alcotest.(check bool)
            "svc-o4wt and it says so" true
            (contains "XDG_RUNTIME_DIR" error || contains "No such file" error);
          let status, _, _ =
            run_cli_at ~caps override_listener ~env [ "list"; "--socket"; override ] reply
          in
          Alcotest.(check bool)
            "svc-o4wt --socket overrides control.socket" true (status = Unix.WEXITED 0)))

(* svc-hi4f: every command's help names its positionals in the protocol's order, and the
   page renders without a Cmdliner markup diagnostic. *)
let client_help =
  [
    ([ "new" ], [ "URL" ]);
    ([ "list" ], []);
    ([ "take" ], []);
    ([ "close" ], [ "TAB" ]);
    ([ "status" ], []);
    ([ "snap" ], [ "TAB" ]);
    ([ "text" ], [ "TAB" ]);
    ([ "shot" ], [ "TAB"; "PATH" ]);
    ([ "debug" ], [ "TAB" ]);
    ([ "eval" ], [ "TAB"; "EXPRESSION" ]);
    ([ "nav" ], [ "TAB"; "URL" ]);
    ([ "click" ], [ "TAB"; "SNAPSHOT"; "INDEX" ]);
    ([ "fill" ], [ "TAB"; "SNAPSHOT"; "INDEX"; "TEXT" ]);
    ([ "press" ], [ "TAB"; "SNAPSHOT"; "KEY" ]);
    ([ "select" ], [ "TAB"; "SNAPSHOT"; "INDEX"; "OPTION" ]);
    ([ "scroll" ], [ "TAB"; "UP|DOWN" ]);
    ([ "wait" ], [ "TAB" ]);
    ([ "dialog" ], [ "TAB"; "ACCEPT|DISMISS" ]);
    ([ "handoff" ], [ "TAB"; "REASON" ]);
    ([ "resume" ], [ "TAB" ]);
    ([ "drive" ], [ "MISSION" ]);
    ([ "net" ], [ "TAB"; "ID" ]);
    ([ "upload" ], [ "TAB"; "SNAPSHOT"; "INDEX"; "PATH" ]);
    ([ "hover" ], [ "TAB"; "SNAPSHOT"; "INDEX" ]);
    ([ "cookies" ], [ "TAB" ]);
    ([ "storage" ], [ "TAB"; "local|session" ]);
  ]

let help_matrix
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  List.iter
    (fun (argv, docvs) ->
      let name = "leash " ^ String.concat " " argv in
      let status, output, error = run_cli ~caps (argv @ [ "--help" ]) in
      Alcotest.(check bool) (name ^ " --help exits zero") true (status = Unix.WEXITED 0);
      Alcotest.(check string) (name ^ " --help leaves stderr empty") "" error;
      Alcotest.(check bool)
        (name ^ " --help names its positionals")
        true
        (List.for_all (fun docv -> contains docv output) docvs);
      Alcotest.(check bool)
        (name ^ " --help shows an example")
        true (contains "EXAMPLES" output);
      Alcotest.(check bool)
        (name ^ " --help lists the client options")
        true
        (List.for_all (fun flag -> contains flag output) [ "--config"; "--socket" ]))
    client_help;
  List.iter
    (fun argv ->
      let name = "leash " ^ String.concat " " argv in
      let status, output, error = run_cli ~caps (argv @ [ "--help" ]) in
      Alcotest.(check bool) (name ^ " --help exits zero") true (status = Unix.WEXITED 0);
      Alcotest.(check string) (name ^ " --help leaves stderr empty") "" error;
      Alcotest.(check bool)
        (name ^ " --help says what it does")
        true
        (String.length output > 0))
    [ [ "config"; "check" ]; [ "config"; "init" ]; [ "config" ] ]

(* svc-hi4f: a command accepts only the options it uses, so the first call is the right
   call rather than one corrected after an ignored flag. *)
let help_scope
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.stdin
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  let help
      ~(caps :
         < Ox_caps.Cap.env
         ; Ox_caps.Cap.exec
         ; Ox_caps.Cap.fork
         ; Ox_caps.Cap.fs_read
         ; Ox_caps.Cap.fs_write
         ; Ox_caps.Cap.stdin
         ; Ox_caps.Cap.tmp
         ; .. >) argv =
    let _, output, _ = run_cli ~caps (argv @ [ "--help" ]) in
    output
  in
  Alcotest.(check bool)
    "svc-hi4f only list and snap render a table" true
    (contains "--table" (help ~caps [ "list" ])
    && contains "--table" (help ~caps [ "snap" ])
    && (not (contains "--table" (help ~caps [ "new" ])))
    && not (contains "--table" (help ~caps [ "text" ])));

  Alcotest.(check bool)
    "svc-hi4f press names its row option and click has none" true
    (contains "--index" (help ~caps [ "press" ])
    && not (contains "--index" (help ~caps [ "click" ])));
  let status, _, _ = run_cli ~caps [ "new"; "--table" ] in
  Alcotest.(check bool)
    "svc-hi4f an option a command does not use is refused" true (status = Unix.WEXITED 124);
  let status, _, _ = run_cli ~caps [ "press"; "t_9xk"; "s_3"; "Enter"; "--force" ] in
  Alcotest.(check bool)
    "svc-hi4f --force is refused where it means nothing" true (status = Unix.WEXITED 124)

let test name case = Alcotest.test_case name `Quick case

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L1 config, Door and protocol"
    [
      ( "chrome-38a4",
        [
          test "request envelope and closed arguments" request_validation;
          test "every command decodes and round-trips" command_round_trip;
          test "tab, snapshot and dialog shapes" result_shapes;
          test "one wire name per closed set" closed_sets;
          test "drive result shape" drive_result;
          test "reply shapes" reply_shapes;
        ] );
      ( "chrome-fuao",
        [
          test "status result shape" status_result;
          test "status socket client" (socket_cli ~caps);
          test "usage exit" (cli_usage ~caps);
        ] );
      ("svc-kzt6", [ test "environment override/redaction" config_values ]);
      ("svc-f4op", [ test "OTLP disabled, enabled, redacted headers" otlp_config ]);
      ( "svc-ljl3",
        [
          test "boot path validation" (path_validation ~caps);
          test "config check fails fast" (config_check_cli ~caps);
        ] );
      ( "svc-tkor",
        [
          test "config decode and defaults" config_values;
          test "hand-04rb hand-phof hand-rg9h" handoff_commands;
          test "config check prints the redacted config" (config_check_cli ~caps);
        ] );
      ( "svc-x8rp",
        [
          test "defaults for every non-secret field" config_defaults;
          test "the default binary is found on PATH" (binary_on_path ~caps);
          test "the service starts with no config file"
            (service_starts_without_config ~caps);
          test "config check with no config file" (config_check_without_file ~caps);
          test "config init writes, refuses and --force" (config_init ~caps);
          test "config init through the CLI" (config_init_cli ~caps);
        ] );
      ( "svc-o4wt",
        [
          test "the socket default and the configured path" config_defaults;
          test "an unset XDG variable is refused by pointer" (unset_xdg_paths ~caps);
          test "the CLI connects where the config says" (socket_config_cli ~caps);
        ] );
      ( "svc-hi4f",
        [
          test "every command's help names its positionals" (help_matrix ~caps);
          test "each command accepts only its own options" (help_scope ~caps);
        ] );
    ]
