(* L22 — the text helper step (docs/issues/drive/01-drive.md, milestone 5; drive-ls3c
   drive-fh1h).

   The chat helper is served by a local plaintext HTTP server
   (leash_test_support.Fake_systemone) and the browser by the scripted CDP peer over the
   page recorded in test/fixtures/unlabelled-controls-chrome.json, so nothing here touches
   the network or a real browser. The clock is Eio's real one, as ox's AI tests
   explain: a client's socket wait and a mock clock cannot both make progress in one
   domain. *)

module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Chat = Leash_test_support.Fake_systemone
module Chrome = Leash.Chrome
module Config = Leash.Config
module Models = Leash.Models
module Logger = Ox_observability.Logger

let obj fields = `Assoc fields
let str value = `String value
let field key = function `Assoc fields -> List.assoc_opt key fields | _ -> None

let get key json =
  match field key json with
  | Some value -> value
  | None -> Alcotest.fail ("missing " ^ key)

let text key json =
  match field key json with
  | Some (`String value) -> value
  | _ -> Alcotest.fail ("not a string: " ^ key)

let list json = match json with `List items -> items | _ -> Alcotest.fail "not a list"

let contains haystack needle =
  let n = String.length needle and h = String.length haystack in
  let rec scan at = at + n <= h && (String.sub haystack at n = needle || scan (at + 1)) in
  n = 0 || scan 0

let text_value value =
  match Config.Text.of_string value with
  | Ok text -> text
  | Error why -> Alcotest.fail why

let tab json =
  match P.Handle.t_of_yojson (get "tab" json) with
  | Ok value -> value
  | Error why -> Alcotest.fail why

let result = function
  | P.Success json -> json
  | P.Failure error ->
      Alcotest.failf "%s: %s" (P.Error_code.to_string error.code) error.message

let failure = function
  | P.Failure error -> error
  | P.Success _ -> Alcotest.fail "expected a protocol error"

let detail_code (error : P.error) =
  match error.detail with
  | Some (`Assoc fields) -> (
      match List.assoc_opt "code" fields with Some (`String code) -> code | _ -> "")
  | _ -> ""

let detail_steps (error : P.error) =
  match error.detail with
  | Some (`Assoc fields) -> (
      match List.assoc_opt "steps" fields with Some (`List steps) -> steps | _ -> [])
  | _ -> []

let check_code label expected (error : P.error) =
  Alcotest.(check string) label expected (P.Error_code.to_string error.code)

let calls fake name =
  Fake.received fake
  |> List.filter (fun json -> field "method" json = Some (`String name))

let params json = get "params" json

(* ---------- The recorded page ---------- *)

let jev_model = "typesafe/jev-1.13-20260917"
let text_model = "inception/mercury-2.5"
let key = "test-key"

let fixture name =
  let load path = Yojson.Safe.from_file path in
  try load ("fixtures/" ^ name) with Sys_error _ -> load ("test/fixtures/" ^ name)

let document ~title ~url =
  obj
    [
      ( "targetInfo",
        obj
          [
            ("targetId", str "target-1");
            ("type", str "page");
            ("title", str title);
            ("url", str url);
          ] );
    ]

(* The recorded accessibility tree's node for one backend id: what the fake answers an
   action-time revalidation with, unless a test makes it answer a changed row. *)
let ax_node fixture backend =
  let nodes = list (get "nodes" (get "ax" fixture)) in
  match
    List.find_opt (fun node -> field "backendDOMNodeId" node = Some (`Int backend)) nodes
  with
  | Some node -> node
  | None -> Alcotest.failf "the fixture has no AX node for backend %d" backend

let changed_row backend =
  obj
    [
      ( "nodes",
        `List
          [
            obj
              [
                ("role", obj [ ("type", str "role"); ("value", str "textbox") ]);
                ("name", obj [ ("type", str "computedString"); ("value", str "Other") ]);
                ("backendDOMNodeId", `Int backend);
              ];
          ] );
    ]

(* [stale_row] makes the first action-time revalidation answer a row whose name changed,
   which is [stale-snapshot] at the action layer: the drive observes and decides again
   (drive-ls3c's reuse case). *)
let script_page ?(stale_row = false) fake =
  let fixture = fixture "unlabelled-controls-chrome.json" in
  let fresh = ref (not stale_row) in
  Fake.on_method fake "Accessibility.getFullAXTree" (fun _ -> get "ax" fixture);
  Fake.on_method fake "DOMSnapshot.captureSnapshot" (fun _ -> get "dom" fixture);
  Fake.on_method fake "Page.getFrameTree" (fun _ -> get "frameTree" fixture);
  Fake.on_method fake "Target.getTargetInfo" (fun _ ->
      document ~title:"Example" ~url:"https://example.com/");
  Fake.on_method fake "Page.navigate" (fun request ->
      let session =
        match field "sessionId" request with Some (`String id) -> id | _ -> "session-1"
      in
      Fake.emit ~session fake ~method_:"Page.loadEventFired"
        ~params:(Fake.event "Page.loadEventFired");
      obj []);
  let aimed = ref 0 in
  let operator_observation =
    obj
      [
        ("kind", str "leash-operator");
        ("url", str "https://example.com/");
        ("title", str "Example");
        ("timeOrigin", `Int 1);
        ("text", str "Example content");
        ("truncated", `Bool false);
        ("omitted", `Int 0);
        ( "scroll",
          obj
            [
              ("x", `Int 0);
              ("y", `Int 0);
              ("height", `Int 1000);
              ("viewport", `Int 600);
              ("width", `Int 800);
            ] );
        ("semantics", `List []);
        ("guard", obj []);
      ]
  in
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      let expression = get "expression" (get "params" request) in
      match expression with
      | `String s when s = Leash__Snapshot_source.interactive_count_expression ->
          obj [ ("result", obj [ ("type", str "number"); ("value", `Int 0) ]) ]
      | `String "globalThis" ->
          obj [ ("result", obj [ ("objectId", str "global-object") ]) ]
      | `String expression when contains expression "leash-operator-read" ->
          obj
            [
              ("result", obj [ ("type", str "object"); ("value", operator_observation) ]);
            ]
      | `String expression
        when String.starts_with ~prefix:"Array.from(document.body?.innerText" expression
        ->
          obj
            [
              ("result", obj [ ("type", str "object"); ("value", str "Example content") ]);
            ]
      | _ ->
          obj
            [ ("result", obj [ ("type", str "object"); ("value", get "guard" fixture) ]) ]);
  (* fly-4lmg: operator TYPE_TEXT and SELECT hit-test. The aimed backend is the node
     just measured, so the point hits the row rather than an overlay. *)
  Fake.on_method fake "DOM.getContentQuads" (fun request ->
      (match field "backendNodeId" (get "params" request) with
      | Some (`Int backend) -> aimed := backend
      | _ -> ());
      obj
        [
          ( "quads",
            `List
              [
                `List
                  [
                    `Float 10.;
                    `Float 10.;
                    `Float 30.;
                    `Float 10.;
                    `Float 30.;
                    `Float 30.;
                    `Float 10.;
                    `Float 30.;
                  ];
              ] );
        ]);
  Fake.on_method fake "DOM.getNodeForLocation" (fun _ ->
      obj [ ("backendNodeId", `Int !aimed); ("nodeId", `Int !aimed) ]);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      obj
        [
          ( "result",
            obj
              [
                ( "value",
                  obj [ ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000) ] );
              ] );
        ]);
  Fake.on_method fake "Accessibility.getPartialAXTree" (fun request ->
      let backend =
        match field "backendNodeId" (get "params" request) with
        | Some (`Int backend) -> backend
        | _ -> Alcotest.fail "no backend node id"
      in
      if !fresh then obj [ ("nodes", `List [ ax_node fixture backend ]) ]
      else begin
        fresh := true;
        changed_row backend
      end);
  Fake.on_method fake "DOM.describeNode" (fun request ->
      let backend =
        match field "backendNodeId" (get "params" request) with
        | Some (`Int backend) -> backend
        | _ -> Alcotest.fail "no backend node id"
      in
      obj [ ("node", obj [ ("nodeId", `Int backend) ]) ])

(* ---------- The two fakes ---------- *)

(* One System One answer, valid against the criteria the request actually offered: the
   chosen key carries 1 and every other 0 (what Jev_request.decide validates). For a
   TYPE_TEXT operation the target head names the element the request offered under
   [label], so the fake answers the row the drive was given rather than guessing an
   index. *)
let answer ~choice ?label body =
  let criteria name =
    match field name (get "questions" body) with
    | Some question -> (
        match field "criteria" question with
        | Some (`Assoc criteria) -> List.map fst criteria
        | _ -> Alcotest.fail ("no criteria for " ^ name))
    | None -> Alcotest.fail ("no question " ^ name)
  in
  let distribution keys chosen =
    `Assoc
      (List.map (fun key -> (key, if key = chosen then `Float 1. else `Float 0.)) keys)
  in
  let choice_answer keys chosen =
    obj
      [
        ("type", str "choice");
        ("choice", str chosen);
        ("probabilities", distribution keys chosen);
        ("confidence", `Float 1.);
      ]
  in
  let answers =
    [ ("operation", choice_answer (criteria "operation") choice) ]
    @
    match label with
    | None -> []
    | Some label ->
        let keys = criteria "type_text_target" in
        let chosen =
          match
            list (get "elements" (get "state" body))
            |> List.find_opt (fun element -> text "label" element = label)
          with
          | Some element -> text "index" element
          | None -> Alcotest.fail ("the request offered no element labelled " ^ label)
        in
        [ ("type_text_target", choice_answer keys chosen) ]
  in
  Yojson.Safe.to_string
    (obj
       [
         ("model", str jev_model);
         ("answers", obj answers);
         ( "usage",
           obj
             [
               ("input_tokens", `Int 10);
               ("output_tokens", `Int 2);
               ("cost", `Float 0.0001);
             ] );
         ("id", str "gen-1");
       ])

(* A scripted server: every connection is answered by the next script entry, applied to
   the request body. *)
let scripted ~sw ~net script =
  let remaining = ref script in
  Chat.serve ~net ~sw (fun (request : Chat.request) ->
      match !remaining with
      | next :: rest ->
          remaining := rest;
          next (Yojson.Safe.from_string request.Chat.body)
      | [] -> Chat.failure 500 "the script is exhausted")

(* One OpenAI-compatible completion whose first choice carries [content]. *)
let chat_content content =
  Chat.ok
    (Yojson.Safe.to_string
       (obj
          [
            ("id", str "gen-1");
            ("model", str text_model);
            ( "choices",
              `List
                [
                  obj
                    [
                      ("index", `Int 0);
                      ( "message",
                        obj [ ("role", str "assistant"); ("content", str content) ] );
                      ("finish_reason", str "stop");
                    ];
                ] );
            ( "usage",
              obj
                [
                  ("prompt_tokens", `Int 10);
                  ("completion_tokens", `Int 2);
                  ("total_tokens", `Int 12);
                  ("cost", `Float 0.00042);
                ] );
          ]))

let chat_reply value = chat_content (Yojson.Safe.to_string (obj [ ("text", value) ]))

let chat_server ~sw ~net replies =
  let remaining = ref replies in
  Chat.serve ~net ~sw (fun (_ : Chat.request) ->
      match !remaining with
      | reply :: rest ->
          remaining := rest;
          reply
      | [] -> Chat.failure 500 "the chat script is exhausted")

(* L32: the planner's three keys keep their defaults here — the text helper's tests ask
   the chat route, not the planner's. *)
let models_config ~systemone_endpoint ~chat_base_url : Config.models =
  {
    Config.default.models with
    api_key = Some (Ox_observability.Redact.make key);
    systemone_endpoint = text_value systemone_endpoint;
    jev_model = text_value jev_model;
    chat_base_url = text_value chat_base_url;
    text_model = text_value text_model;
  }

(* ---------- The rigs ---------- *)

(* The whole service over the fakes: the managed Chrome process manager, the registry, the
   scripted CDP peer and the models service. *)
let rig
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) f =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
          let current = ref None in
          let launch
              ~(caps :
                 < Ox_caps.Cap.exec ; Ox_caps.Cap.fork ; Ox_caps.Cap.fs_write ; .. >) ~sw
              ~clock ~mgr:_ config =
            let fake, client = Fake.create ~sw () in
            current := Some fake;
            match
              Ox_process.Child.spawn ~caps ~sw ~clock ~mgr:(Ox_test.Process.mgr mgr)
                ~argv:(Chrome.argv config) ~grace:(Ox.Duration.ms 50) ~fds:[] ()
            with
            | Error error -> Error error
            | Ok child ->
                Ok (child, { Leash.Cdp.read = client.read; write = client.write })
          in
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Debug ~service:"leash-text-helper-tests"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let chrome =
            Chrome.create ~sw ~launch:(launch ~caps)
              (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-text-helper-profile"
                 ~workspace:"test" ~headless:true ())
              {
                Chrome.clock = env#clock;
                mgr = env#process_mgr;
                logger;
                caps :> Leash.Chrome.caps;
              }
          in
          let tabs =
            Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
              {
                Leash.Tabs.chrome;
                clock = env#clock;
                logger;
                desktop = Leash.Desktop.disabled;
                caps :> Leash.Tabs.caps;
              }
          in
          let rec ready remaining =
            if remaining = 0 then Alcotest.fail "no Chrome"
            else if (Chrome.status chrome).phase <> `Running then (
              Eio.Fiber.yield ();
              ready (remaining - 1))
          in
          ready 1000;
          let fake () =
            match !current with Some fake -> fake | None -> Alcotest.fail "no fake"
          in
          f env sw tabs (fake ()) logger memory))

(* The chat client alone, over the fake chat server: the helper's own tests need no
   browser. *)
let helper_rig ?(on_usage = fun _ -> ()) ?(replies = [ chat_reply (`String "hello") ]) f =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Debug ~service:"leash-text-helper-tests"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let server = chat_server ~sw ~net:env#net replies in
          let http =
            Ox_http.Client.create ~sw ~net:env#net ~clock:env#clock
              ~tls:(Ox_http.Client.tls ()) ()
          in
          let client =
            Ox_ai_chat.create ~http ~clock:env#clock ~logger
              ~endpoint:(Chat.url server "/chat/completions")
              ~api_key:(Ox_observability.Redact.make key)
              ()
          in
          let helper =
            Leash.Text_helper.create ~on_usage ~client
              ~now:(fun () -> Eio.Time.now env#clock)
              ~model:text_model ~logger ()
          in
          f env sw helper server memory))

(* ---------- The control seam ---------- *)

let raw ?models ?decide ?text_helper ?levels tabs command =
  let wire = P.encode_request { command } |> Yojson.Safe.to_string in
  let answer =
    Leash.Control.handle ?model:(Some jev_model) ?decide ?text_helper ?levels
      ?models_status:(Option.map (fun models () -> Models.status models) models)
      tabs wire
  in
  match P.decode_reply (Yojson.Safe.from_string answer) with
  | Ok reply -> reply
  | Error why -> Alcotest.fail why

let new_tab tabs =
  tab (result (raw tabs (P.New { url = Some "https://example.com/"; label = None })))

let drive ?levels models tabs handle goal =
  let supplied = Option.value ~default:(Models.levels models) levels in
  let plans = ref 0 in
  let levels =
    {
      supplied with
      Leash.Run.plan =
        (fun ~deadline request ->
          incr plans;
          if !plans = 1 then
            Ok
              Leash.Run.
                {
                  answer = Leg goal;
                  expect = [];
                  reasoning_summary = None;
                  secrets_for_operator = [];
                  usage = None;
                }
          else
            match List.rev request.legs with
            | leg :: _ when leg.outcome <> "done" -> (
                match levels with
                | Some _ -> supplied.plan ~deadline request
                | None ->
                    Ok
                      Leash.Run.
                        {
                          answer = Fail "Navigation leg failed";
                          expect = [];
                          reasoning_summary = None;
                          secrets_for_operator = [];
                          usage = None;
                        })
            | _ ->
                Ok
                  Leash.Run.
                    {
                      answer = Done { result = "Navigation leg completed"; evidence = [] };
                      expect = [];
                      reasoning_summary = None;
                      secrets_for_operator = [];
                      usage = None;
                    });
    }
  in
  raw ~levels ~models
    ~decide:(fun ~deadline request -> Models.decide ~deadline models request)
    ~text_helper:(fun () -> Models.text_helper models)
    tabs
    (P.Drive
       {
         tab = Some handle;
         mission = goal;
         max_procedures = Some 4;
         deadline_s = Some 30;
         dry_run = None;
         expect = None;
         out = None;
         secrets = [];
         max_steps = None;
         start_url = None;
       })

(* ---------- drive-ls3c drive-fh1h: the value the helper answers is typed ---------- *)

let goal = "Type the phrase \"Gödel, Escher, Bach\" into the search field"

let fills
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw tabs fake logger memory ->
      script_page fake;
      let systemone =
        scripted ~sw ~net:env#net
          [
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
            (fun body -> Chat.ok (answer ~choice:"DONE" body));
          ]
      in
      let chat =
        chat_server ~sw ~net:env#net [ chat_reply (`String "Gödel, Escher, Bach") ]
      in
      let config =
        models_config
          ~systemone_endpoint:(Chat.url systemone "/api/v1/systemone")
          ~chat_base_url:(Chat.url chat "")
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle goal) in
      Alcotest.(check string) "drive-ls3c done" "done" (text "status" reply);
      let steps = list (get "operator_steps" reply) in
      Alcotest.(check int) "drive-ls3c two steps" 2 (List.length steps);
      let step = List.hd steps in
      Alcotest.(check string)
        "drive-ls3c the step operation" "type_text" (text "operation" step);
      Alcotest.(check bool)
        "drive-ls3c the row is the offered element" true
        (match field "index" step with Some (`Int index) -> index > 0 | _ -> false);
      Alcotest.(check string)
        "drive-xjh6 the typed text is in the trace" "Gödel, Escher, Bach"
        (text "text" step);
      (* the fill went through the action path the fill command uses *)
      let inserted = calls fake "Input.insertText" in
      Alcotest.(check int) "drive-ls3c one fill" 1 (List.length inserted);
      Alcotest.(check string)
        "drive-ls3c the value is typed verbatim" "Gödel, Escher, Bach"
        (text "text" (params (List.hd inserted)));
      Alcotest.(check int)
        "drive-ls3c no other row action" 0
        (List.length (calls fake "Input.dispatchMouseEvent"));
      (* the helper request: one chat call to the configured base URL *)
      Alcotest.(check int) "drive-ls3c one chat call" 1 (Chat.connections chat);
      let request =
        match Chat.request chat with
        | Some request -> request
        | None -> Alcotest.fail "no chat request"
      in
      Alcotest.(check string) "the chat method" "POST" request.Chat.method_;
      Alcotest.(check string)
        "drive-ls3c the chat route" "/chat/completions" request.Chat.target;
      Alcotest.(check (option string))
        "the bearer key"
        (Some ("Bearer " ^ key))
        (Chat.header "authorization" request);
      let body = Yojson.Safe.from_string request.Chat.body in
      Alcotest.(check string)
        "drive-ls3c the pinned text model" text_model (text "model" body);
      Alcotest.(check bool)
        "no output token budget (operator 2026-10-02)" true
        (field "max_tokens" body = None);
      Alcotest.(check string)
        "drive-ls3c json_object is required" "json_object"
        (text "type" (get "response_format" body));
      Alcotest.(check bool)
        "drive-ls3c reasoning is disabled" true
        (get "reasoning" body = obj [ ("enabled", `Bool false) ]);
      (match list (get "messages" body) with
      | [ system; user ] ->
          Alcotest.(check string)
            "drive-ls3c the system message is TEXT_VALUE" Leash__Questions.text_value
            (text "content" system);
          Alcotest.(check string) "the system role" "system" (text "role" system);
          Alcotest.(check string) "the user role" "user" (text "role" user);
          let context = Yojson.Safe.from_string (text "content" user) in
          (* drive-fh1h: the goal the agent stated reaches the helper verbatim *)
          Alcotest.(check string)
            "drive-fh1h the goal verbatim" goal (text "goal" context);
          let field_json = get "field" context in
          Alcotest.(check string)
            "drive-ls3c the field label" "Search terms" (text "label" field_json);
          Alcotest.(check string)
            "drive-ls3c the field role" "textbox" (text "role" field_json);
          Alcotest.(check string)
            "drive-ls3c the field value" "" (text "value" field_json);
          let page = get "page" context in
          Alcotest.(check string)
            "drive-ls3c the page title" "Example" (text "title" page);
          Alcotest.(check string)
            "drive-ls3c the page text" "Example content" (text "text" page);
          Alcotest.(check int)
            "drive-ls3c no history on the first step" 0
            (List.length (list (get "recent_actions" context)))
      | messages ->
          Alcotest.(check int) "drive-ls3c two messages" 2 (List.length messages));
      Alcotest.(check int)
        "drive-ls3c one System One call per decision" 2 (Chat.connections systemone);
      (* the key never reaches a log line *)
      let logged = Logger.Memory.records memory |> List.map Logger.to_string in
      Alcotest.(check bool) "drive-ls3c something was logged" true (logged <> []);
      Alcotest.(check bool)
        "the key never reaches a log line" false
        (List.exists (fun line -> contains line key) logged))

(* drive-ls3c: null means the value is missing: the drive ends blocked with the field
   named, and nothing reaches the browser. *)
let null_is_blocked
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw tabs fake logger _ ->
      script_page fake;
      let systemone =
        scripted ~sw ~net:env#net
          [
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
          ]
      in
      let chat = chat_server ~sw ~net:env#net [ chat_reply `Null ] in
      let models =
        Models.create ~sw ~net:env#net ~clock:env#clock ~logger
          (models_config
             ~systemone_endpoint:(Chat.url systemone "/api/v1/systemone")
             ~chat_base_url:(Chat.url chat ""))
      in
      let handle = new_tab tabs in
      let levels =
        {
          (Models.levels models) with
          Leash.Run.plan =
            (fun ~deadline:_ _request ->
              Ok
                Leash.Run.
                  {
                    answer = Fail "required field value is missing";
                    expect = [];
                    reasoning_summary = None;
                    secrets_for_operator = [];
                    usage = None;
                  });
        }
      in
      let reply = result (drive ~levels models tabs handle goal) in
      Alcotest.(check string)
        "pilot fails after blocked leg" "failed" (text "status" reply);
      Alcotest.(check (option string))
        "drive-ls3c the field is named" (Some "required field value is missing")
        (match field "reason" reply with
        | Some (`String reason) -> Some reason
        | _ -> None);
      Alcotest.(check int)
        "drive-ls3c nothing is typed" 0
        (List.length (calls fake "Input.insertText"));
      Alcotest.(check int) "drive-ls3c one chat call" 1 (Chat.connections chat);
      let steps = list (get "operator_steps" reply) in
      Alcotest.(check int)
        "drive-ls3c the blocked decision is in the trace" 1 (List.length steps);
      Alcotest.(check string)
        "drive-ls3c the blocked step" "type_text"
        (text "operation" (List.hd steps)))

(* drive-ls3c: the text is bounded at 2000 characters — 2000 bytes are typed, 2001 are refused and
   nothing is typed. *)
let bound
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw tabs fake logger _ ->
      script_page fake;
      let systemone =
        scripted ~sw ~net:env#net
          [
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
            (fun body -> Chat.ok (answer ~choice:"DONE" body));
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
          ]
      in
      let at_bound = String.make 2000 'x' and over = String.make 2001 'x' in
      let chat =
        chat_server ~sw ~net:env#net
          [
            chat_reply (`String at_bound);
            chat_reply (`String over);
            chat_reply (`String over);
          ]
      in
      let models =
        Models.create ~sw ~net:env#net ~clock:env#clock ~logger
          (models_config
             ~systemone_endpoint:(Chat.url systemone "/api/v1/systemone")
             ~chat_base_url:(Chat.url chat ""))
      in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle goal) in
      Alcotest.(check string) "drive-ls3c the bound is met" "done" (text "status" reply);
      let inserted = calls fake "Input.insertText" in
      Alcotest.(check int) "drive-ls3c one fill" 1 (List.length inserted);
      Alcotest.(check int)
        "drive-ls3c 2000 characters is typed" 2000
        (String.length (text "text" (params (List.hd inserted))));
      (* the same drive, one byte over *)
      let reply = result (drive models tabs handle goal) in
      Alcotest.(check string)
        "pilot fails after overlong helper" "failed" (text "status" reply);
      let operator = get "operator_state" reply in
      let error =
        match P.error_of_yojson (get "error" operator) with
        | Ok error -> error
        | Error message -> Alcotest.fail message
      in
      check_code "fly-qr70 over 2000 characters is refused" "model-unavailable" error;
      Alcotest.(check string)
        "map-op07 repeated invalid text remains refused" "invalid-response"
        (detail_code error);
      Alcotest.(check int)
        "drive-ls3c the over-long text is not typed" 1
        (List.length (calls fake "Input.insertText")))

(* drive-ls3c: an identical context is answered from the helper's memo — a stale row
   re-asks the helper, and the helper makes one chat call. *)
let reuse
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw tabs fake logger _ ->
      script_page ~stale_row:true fake;
      let systemone =
        scripted ~sw ~net:env#net
          [
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
            (fun body -> Chat.ok (answer ~choice:"DONE" body));
          ]
      in
      let chat = chat_server ~sw ~net:env#net [ chat_reply (`String "alice") ] in
      let models =
        Models.create ~sw ~net:env#net ~clock:env#clock ~logger
          (models_config
             ~systemone_endpoint:(Chat.url systemone "/api/v1/systemone")
             ~chat_base_url:(Chat.url chat ""))
      in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle goal) in
      Alcotest.(check string)
        "drive-ls3c done after the stale retry" "done" (text "status" reply);
      Alcotest.(check int)
        "drive-ls3c one chat call for two asks" 1 (Chat.connections chat);
      Alcotest.(check int)
        "drive-ls3c one System One call per decision" 3 (Chat.connections systemone);
      let inserted = calls fake "Input.insertText" in
      Alcotest.(check int) "drive-ls3c the fill happened once" 1 (List.length inserted);
      Alcotest.(check string)
        "drive-ls3c the reused value is typed" "alice"
        (text "text" (params (List.hd inserted)));
      let steps = list (get "operator_steps" reply) in
      Alcotest.(check int)
        "drive-9y2s the stale decision is not a trace step" 2 (List.length steps);
      Alcotest.(check string)
        "drive-ls3c the typed step follows the retry" "type_text"
        (text "operation" (List.hd steps)))

(* drive-kh2u drive-ls3c: a chat failure ends the drive with model-unavailable and the
   steps that completed. *)
let chat_failure
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.exec
       ; Ox_caps.Cap.fork
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.random
       ; .. >) () =
  rig ~caps (fun env sw tabs fake logger _ ->
      script_page fake;
      let systemone =
        scripted ~sw ~net:env#net
          [
            (fun body -> Chat.ok (answer ~choice:"SCROLL_DOWN" body));
            (fun body -> Chat.ok (answer ~choice:"TYPE_TEXT" ~label:"Search terms" body));
          ]
      in
      let chat =
        chat_server ~sw ~net:env#net [ Chat.failure 500 "the provider fell over" ]
      in
      let models =
        Models.create ~sw ~net:env#net ~clock:env#clock ~logger
          (models_config
             ~systemone_endpoint:(Chat.url systemone "/api/v1/systemone")
             ~chat_base_url:(Chat.url chat ""))
      in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle goal) in
      Alcotest.(check string)
        "pilot failure retains operator error evidence" "failed" (text "status" reply);
      let operator = get "operator_state" reply in
      let error =
        match P.error_of_yojson (get "error" operator) with
        | Ok error -> error
        | Error message -> Alcotest.fail message
      in
      check_code "fly-8fgl provider failure" "model-unavailable" error;
      Alcotest.(check string)
        "fly-8fgl provider subtype" "unavailable" (detail_code error);
      let steps = list (get "operator_steps" reply) in
      Alcotest.(check int) "fly-4mio completed action retained" 1 (List.length steps);
      Alcotest.(check string)
        "fly-4mio completed scroll" "scroll_down"
        (text "operation" (List.hd steps));
      Alcotest.(check int)
        "drive-ls3c nothing is typed" 0
        (List.length (calls fake "Input.insertText")))

(* ---------- drive-ls3c: jev's field_context, shaped and bounded ---------- *)

let recent_action index =
  Leash__Jev_request.
    {
      action = "step" ^ string_of_int index;
      kind = Some "click";
      text = (if index = 3 then None else Some ("text" ^ string_of_int index));
      page_changed = Some true;
    }

let context =
  Leash.Text_helper.
    {
      goal = "Find and open the Wikipedia article about Gödel";
      field = { label = "Search"; role = "textbox"; value = "now" };
      page_title = "Example";
      page_text = String.make 7000 'x';
      recent = List.init 8 recent_action;
    }

let user_context server =
  let request =
    match Chat.request server with
    | Some request -> request
    | None -> Alcotest.fail "no chat request"
  in
  let body = Yojson.Safe.from_string request.Chat.body in
  match list (get "messages" body) with
  | [ _system; user ] -> Yojson.Safe.from_string (text "content" user)
  | messages -> Alcotest.failf "expected two messages, got %d" (List.length messages)

(* model.py:154-159: the goal verbatim, the field's three members, the page's title and
   its text bounded at 6000 bytes, and the last six actions with only their action and
   text. *)
let field_context () =
  (* the first ask, the memo hit, and the changed input's own ask *)
  helper_rig
    ~replies:[ chat_reply (`String "hello"); chat_reply (`String "hello") ]
    (fun _ _ helper server _ ->
      match helper.Leash.Text_helper.complete context with
      | Error error -> Alcotest.fail error.Leash.Protocol.message
      | Ok value -> (
          Alcotest.(check (option string)) "drive-ls3c the value" (Some "hello") value;
          let asked = user_context server in
          Alcotest.(check string)
            "drive-fh1h the goal verbatim"
            "Find and open the Wikipedia article about Gödel" (text "goal" asked);
          let field_json = get "field" asked in
          Alcotest.(check string) "the field label" "Search" (text "label" field_json);
          Alcotest.(check string) "the field role" "textbox" (text "role" field_json);
          Alcotest.(check string) "the field value" "now" (text "value" field_json);
          let page = get "page" asked in
          Alcotest.(check string) "the page title" "Example" (text "title" page);
          let page_text = text "text" page in
          Alcotest.(check int)
            "the page text is bounded at 6000" 6000 (String.length page_text);
          Alcotest.(check bool)
            "the page text is the page's own prefix" true
            (page_text = String.sub context.Leash.Text_helper.page_text 0 6000);
          let recent = list (get "recent_actions" asked) in
          Alcotest.(check int) "the window is the last six" 6 (List.length recent);
          Alcotest.(check string)
            "the window starts at the second of eight" "step2"
            (text "action" (List.hd recent));
          Alcotest.(check string)
            "the window ends at the last" "step7"
            (text "action" (List.nth recent 5));
          List.iter
            (fun entry ->
              Alcotest.(check (list string))
                "an action carries only its action and text" [ "action"; "text" ]
                (match entry with `Assoc fields -> List.map fst fields | _ -> []))
            recent;
          Alcotest.(check bool)
            "a step without text is null" true
            (get "text" (List.nth recent 1) = `Null);
          (* the same input is answered from the memo; a changed one is asked again *)
          let again = helper.Leash.Text_helper.complete context in
          Alcotest.(check (option string))
            "drive-ls3c the memo reuses the answer" (Some "hello")
            (match again with Ok value -> value | Error _ -> None);
          Alcotest.(check int) "drive-ls3c one chat call" 1 (Chat.connections server);
          (* the helper input is the context as written to the wire: a page tail past the
             6000-character bound is not part of it, and does not force a second call *)
          let tail =
            { context with Leash.Text_helper.page_text = context.page_text ^ "tail" }
          in
          (match helper.Leash.Text_helper.complete tail with
          | Error error -> Alcotest.fail error.Leash.Protocol.message
          | Ok _ -> ());
          Alcotest.(check int)
            "drive-ls3c a bounded-away tail is still the same input" 1
            (Chat.connections server);
          let changed = { context with Leash.Text_helper.goal = "another goal" } in
          match helper.Leash.Text_helper.complete changed with
          | Error error -> Alcotest.fail error.Leash.Protocol.message
          | Ok _ ->
              Alcotest.(check int)
                "drive-ls3c a changed input is asked again" 2 (Chat.connections server)))

(* drive-ls3c, L34: a real provider added a bare Markdown fence after valid
   JSON. A bounded correction asks again; the malformed first answer is never typed. *)
let empty_response_retry () =
  let null_content =
    Chat.ok
      ("{\"id\":\"gen-null\",\"model\":\"" ^ text_model
     ^ "\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":null},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":0,\"total_tokens\":10}}"
      )
  in
  List.iter
    (fun first ->
      helper_rig
        ~replies:[ first; chat_reply (`String "Blue Top") ]
        (fun _ _ helper server _ ->
          let answer = helper.Leash.Text_helper.complete context in
          Alcotest.(check (option string))
            "map-op07 invalid/empty helper reply recovers" (Some "Blue Top")
            (match answer with Ok x -> x | Error e -> Alcotest.fail e.message);
          Alcotest.(check int) "map-op07 one helper retry" 2 (Chat.connections server)))
    [ null_content; chat_content ""; chat_reply (`String "") ]

let corrective_retry () =
  helper_rig
    ~replies:
      [ chat_content "{\"text\":\"Blue Top\"}\n```"; chat_reply (`String "Blue Top") ]
    (fun _ _ helper server _ ->
      let answer = helper.Leash.Text_helper.complete context in
      Alcotest.(check (option string))
        "drive-ls3c corrected strict JSON" (Some "Blue Top")
        (match answer with Ok text -> text | Error error -> Alcotest.fail error.message);
      Alcotest.(check int) "drive-ls3c one bounded correction" 2 (Chat.connections server);
      let requests = Chat.requests server in
      let second = List.nth requests 1 in
      let messages = list (get "messages" (Yojson.Safe.from_string second.Chat.body)) in
      Alcotest.(check int)
        "drive-ls3c original answer and corrective reason" 4 (List.length messages);
      let correction = text "content" (List.nth messages 3) in
      Alcotest.(check bool)
        "drive-ls3c asks for no Markdown fences" true
        (contains correction "Markdown fences"))

(* drive-ls3c: the answer must be exactly {"text": string|null}; anything else, and a
   text over 2000 characters, is a refusal with nothing typed. *)
let answer_shape () =
  let replies =
    [
      chat_reply (`String (String.make 2000 'y'));
      chat_reply `Null;
      chat_reply (`Assoc [ ("text", `String "hello"); ("other", `Int 1) ]);
      chat_reply (`Assoc [ ("text", `String "hello"); ("other", `Int 1) ]);
      chat_content "not json";
      chat_content "not json";
      chat_reply (`Int 5);
      chat_reply (`Int 5);
    ]
  in
  helper_rig ~replies (fun _ _ helper _ _ ->
      (* every ask is a different input, or the helper's memo answers it *)
      let ask label =
        helper.Leash.Text_helper.complete { context with Leash.Text_helper.goal = label }
      in
      Alcotest.(check (option string))
        "drive-ls3c 2000 characters is accepted"
        (Some (String.make 2000 'y'))
        (match ask "at the bound" with
        | Ok value -> value
        | Error error -> Alcotest.fail error.Leash.Protocol.message);
      Alcotest.(check (option string))
        "drive-ls3c null is [None]" None
        (match ask "null" with
        | Ok value -> value
        | Error error -> Alcotest.fail error.Leash.Protocol.message);
      List.iter
        (fun (label, expected) ->
          match ask label with
          | Ok value ->
              Alcotest.failf "%s: expected a refusal, got %s" label
                (match value with Some value -> value | None -> "null")
          | Error error ->
              Alcotest.(check string)
                (label ^ " code") "model-unavailable"
                (P.Error_code.to_string error.code);
              Alcotest.(check string)
                (label ^ " detail") "invalid-response" (detail_code error);
              Alcotest.(check bool)
                (label ^ " sentence: " ^ error.message)
                true
                (contains error.message expected))
        [ ("two members", "text"); ("not json", "text"); ("not a string", "text") ])

(* drive-7tvn: every answered helper call logs its model, tokens and cost at info; a
   memo reuse makes no call and logs nothing. *)
let usage_is_logged () =
  helper_rig
    ~replies:[ chat_reply (`String "hello") ]
    (fun _ _ helper _ memory ->
      let ask () =
        match helper.Leash.Text_helper.complete context with
        | Ok value -> value
        | Error error -> Alcotest.fail error.Leash.Protocol.message
      in
      Alcotest.(check (option string)) "drive-ls3c the value" (Some "hello") (ask ());
      Alcotest.(check (option string)) "drive-ls3c the reuse" (Some "hello") (ask ());
      let open Logger in
      let usage =
        List.filter
          (fun r -> r.level = Info && String.equal r.msg "text helper usage")
          (Memory.records memory)
      in
      Alcotest.(check int) "drive-7tvn one usage line per call" 1 (List.length usage);
      let fields = (List.hd usage).fields in
      let field name =
        match List.assoc_opt name fields with
        | Some value -> value
        | None -> Alcotest.fail ("no " ^ name ^ " field")
      in
      Alcotest.(check string)
        "drive-7tvn the model" text_model
        (match field "model" with String model -> model | _ -> Alcotest.fail "model");
      Alcotest.(check int)
        "drive-7tvn prompt tokens" 10
        (match field "prompt_tokens" with Int n -> n | _ -> Alcotest.fail "prompt");
      Alcotest.(check int)
        "drive-7tvn completion tokens" 2
        (match field "completion_tokens" with
        | Int n -> n
        | _ -> Alcotest.fail "completion");
      Alcotest.(check int)
        "drive-7tvn total tokens" 12
        (match field "total_tokens" with Int n -> n | _ -> Alcotest.fail "total");
      Alcotest.(check (float 0.000001))
        "drive-7tvn provider cost" 0.00042
        (match field "cost" with Float n -> n | _ -> Alcotest.fail "cost"))

(* fly-gysl fly-qr70 fly-9e0f: strict Unicode length, no empty value, actual usage. *)
let unicode_and_usage () =
  let emoji = "😀" in
  let repeat n = String.concat "" (List.init n (fun _ -> emoji)) in
  let reported = ref [] in
  helper_rig
    ~on_usage:(fun json -> reported := json :: !reported)
    ~replies:
      [
        chat_reply (`String (repeat 2000));
        chat_reply (`String (repeat 2001));
        chat_reply (`String (repeat 2001));
        chat_reply (`String "");
        chat_reply (`String "");
      ]
    (fun _ _ helper server _ ->
      let ask goal =
        helper.Leash.Text_helper.complete { context with goal; page_text = repeat 6001 }
      in
      Alcotest.(check (option string))
        "fly-gysl 2000 Unicode characters accepted"
        (Some (repeat 2000))
        (match ask "bound" with
        | Ok value -> value
        | Error error -> Alcotest.fail error.message);
      let page = get "page" (user_context server) in
      Alcotest.(check string)
        "fly-gysl viewport bounded by characters" (repeat 6000) (text "text" page);
      (* The first answer was checked above; this call measures memoized HTTP traffic. *)
      let _memoized_reply = ask "bound" in
      Alcotest.(check int)
        "fly-gysl unchanged memo makes no model call" 1 (Chat.connections server);
      List.iter
        (fun goal ->
          match ask goal with
          | Error _ -> ()
          | Ok _ -> Alcotest.fail "fly-qr70 unsafe helper value")
        [ "over"; "empty" ];
      Alcotest.(check int)
        "map-op07 invalid text retried once" 5 (Chat.connections server);
      Alcotest.(check int)
        "fly-9e0f callback records answered calls, not memo" 5 (List.length !reported);
      let usage = List.hd !reported in
      Alcotest.(check int)
        "fly-9e0f token count" 10
        (match get "input_tokens" usage with `Int n -> n | _ -> 0);
      Alcotest.(check bool)
        "fly-9e0f retry uncertainty explicit" true
        (get "retries" usage = `Null))

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "L22 text helper"
    [
      ( "text helper",
        [
          Alcotest.test_case "fly-gysl fly-qr70 fly-9e0f Unicode and usage" `Quick
            unicode_and_usage;
          Alcotest.test_case "drive-ls3c type_text fills the value" `Quick (fills ~caps);
          Alcotest.test_case "drive-ls3c null blocks naming the field" `Quick
            (null_is_blocked ~caps);
          Alcotest.test_case "drive-ls3c the 2000 characters bound" `Quick (bound ~caps);
          Alcotest.test_case "drive-ls3c reuse on unchanged input" `Quick (reuse ~caps);
          Alcotest.test_case "drive-kh2u chat failure with steps" `Quick
            (chat_failure ~caps);
          Alcotest.test_case "drive-ls3c jev's field_context" `Quick field_context;
          Alcotest.test_case "map-op07 null content and empty response retry" `Quick
            empty_response_retry;
          Alcotest.test_case "drive-ls3c Markdown corrective retry" `Quick
            corrective_retry;
          Alcotest.test_case "drive-ls3c the answer shape" `Quick answer_shape;
          Alcotest.test_case "drive-7tvn usage is logged" `Quick usage_is_logged;
        ] );
    ]
