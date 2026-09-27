(* L19 — models wiring (docs/issues/drive/01-drive.md, milestone 5).

   drive-e7oi: the JEV model id is pinned in config and the reply's model is checked
   against it. drive-yqxg: the System One endpoint and the text-helper base URL are
   configurable and default to OpenRouter, with TypeSafe's direct endpoint accepted.
   drive-kh2u: a provider failure ends the drive with model-unavailable and the completed
   steps in the detail; a missing key fails fast and status says so.

   The model client is served by a local plaintext System One server
   (leash_test_support.Fake_systemone) and the browser by the scripted CDP peer, so nothing
   here touches the network or a real browser. The clock is Eio's real one, as eta-next's
   AI tests explain: the client's socket wait and a mock clock cannot both make progress in
   one domain. *)

module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Server = Leash_test_support.Fake_systemone
module Chrome = Leash.Chrome
module Config = Leash.Config
module Models = Leash.Models
module Logger = Eta_observability.Logger

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

let owner name =
  match P.Owner.of_string name with Ok value -> value | Error why -> Alcotest.fail why

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

(* ---------- The scripted page ---------- *)

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

(* The fixture is the recorded headless Chrome shape of a page with an unlabelled select,
   a bare text input and a button (tab-zc36); the metric body is the one control_test's dry
   run uses, so the drive observes a page it can scroll down. *)
let script_page fake =
  let fixture = fixture "unlabelled-controls-chrome.json" in
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
  Fake.on_method fake "Runtime.evaluate" (fun request ->
      let params = get "params" request in
      let expression = get "expression" params in
      let value =
        match expression with
        | `String expression
          when String.starts_with ~prefix:"Array.from(document.body?.innerText" expression
          ->
            str "Example content"
        | _ -> get "guard" fixture
      in
      if expression = str "globalThis" then
        obj [ ("result", obj [ ("objectId", str "global-object") ]) ]
      else obj [ ("result", obj [ ("type", str "object"); ("value", value) ]) ]);
  Fake.on_method fake "Runtime.callFunctionOn" (fun _ ->
      obj
        [
          ( "result",
            obj
              [
                ( "value",
                  obj [ ("y", `Int 0); ("viewport", `Int 400); ("height", `Int 1000) ] );
              ] );
        ])

(* ---------- The rig: a real clock, the fake browser, the fake models ---------- *)

let rig f =
  Eio_main.run (fun env ->
      Eio.Switch.run (fun sw ->
          let mgr = Eta_test.Process.make [ Block_until_signal; Block_until_signal ] in
          let current = ref None in
          let launch ~sw ~clock ~mgr:_ config =
            let fake, client = Fake.create ~sw () in
            current := Some fake;
            match
              Eta_process.Child.spawn ~sw ~clock ~mgr:(Eta_test.Process.mgr mgr)
                ~argv:(Chrome.argv config) ~grace:(Eta.Duration.ms 50) ~fds:[] ()
            with
            | Error error -> Error error
            | Ok child ->
                Ok (child, { Leash.Cdp.read = client.read; write = client.write })
          in
          let memory = Logger.Memory.create () in
          let logger =
            Logger.create ~level:Logger.Debug ~service:"leash-models-tests"
              ~clock:env#clock ~mono_clock:env#mono_clock
              ~reporter:(Logger.Memory.reporter memory)
              ()
          in
          let chrome =
            Chrome.create ~sw ~launch
              (Chrome.make ~binary:"/bin/sh" ~profile_dir:"/tmp/leash-models-profile"
                 ~workspace:"test" ~headless:true ())
              { Chrome.clock = env#clock; mgr = env#process_mgr; logger }
          in
          let tabs =
            Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
              {
                Leash.Tabs.chrome;
                clock = env#clock;
                logger;
                desktop = Leash.Desktop.disabled;
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

(* ---------- The models service and its server ---------- *)

let jev_model = "typesafe/jev-1.13-20260917"
let text_model = "inception/mercury-2.5"
let key = "test-key"

let models_config ?(api_key = Some key)
    ?(endpoint = "https://openrouter.ai/api/v1/systemone") () : Config.models =
  {
    Config.api_key = Option.map Eta_observability.Redact.make api_key;
    systemone_endpoint = text_value endpoint;
    jev_model = text_value jev_model;
    chat_base_url = text_value "https://openrouter.ai/api/v1";
    text_model = text_value text_model;
  }

(* One System One answer, valid against the criteria the request actually offered: the
   chosen key carries 1 and every other key 0, which is what Jev_request.decide validates
   (exactly the offered keys, a sum of one, the choice at the maximum). *)
let answer ~model ?reply_model ~choice body =
  let criteria =
    match field "questions" body with
    | Some questions -> (
        match field "operation" questions with
        | Some operation -> (
            match field "criteria" operation with
            | Some (`Assoc criteria) -> List.map fst criteria
            | _ -> Alcotest.fail "the request offered no operation criteria")
        | None -> Alcotest.fail "the request has no operation question")
    | None -> Alcotest.fail "the request has no questions"
  in
  let probabilities =
    `Assoc
      (List.map
         (fun name -> (name, if name = choice then `Float 1. else `Float 0.))
         criteria)
  in
  Yojson.Safe.to_string
    (obj
       [
         ("model", str (Option.value ~default:model reply_model));
         ( "answers",
           obj
             [
               ( "operation",
                 obj
                   [
                     ("type", str "choice");
                     ("choice", str choice);
                     ("probabilities", probabilities);
                     ("confidence", `Float 1.);
                   ] );
             ] );
         ( "usage",
           obj
             [
               ("input_tokens", `Int 10);
               ("output_tokens", `Int 2);
               ("cost", `Float 0.0001);
             ] );
         ("id", str "gen-1");
       ])

type step = Answer of string | Refused of int * string

let scripted ~model ?reply_model steps =
  let remaining = ref steps in
  fun (request : Server.request) ->
    match !remaining with
    | [] -> Server.failure 500 "the script is exhausted"
    | step :: rest -> (
        remaining := rest;
        match step with
        | Answer choice ->
            Server.ok
              (answer ~model ?reply_model ~choice (Yojson.Safe.from_string request.body))
        | Refused (status, body) -> Server.failure status body)

(* ---------- The control seam ---------- *)

let raw ?models ?decide ?model tabs command =
  let wire =
    P.encode_request { owner = owner "alice"; command } |> Yojson.Safe.to_string
  in
  let answer =
    Leash.Control.handle ?model ?decide
      ?models_status:(Option.map (fun models () -> Models.status models) models)
      tabs wire
  in
  match P.decode_reply (Yojson.Safe.from_string answer) with
  | Ok reply -> reply
  | Error why -> Alcotest.fail why

(* The tab the drive works on: created at a url, so the load wait populates its url and
   title from the document the fake reports. *)
let new_tab tabs = tab (result (raw tabs (P.New { url = Some "https://example.com/" })))

let drive models tabs handle goal =
  raw ~model:jev_model
    ~decide:(fun ~deadline request -> Models.decide ~deadline models request)
    tabs
    (P.Drive
       { tab = handle; goal; max_steps = Some 4; deadline_s = Some 30; dry_run = None })

(* ---------- drive-y7v8 drive-xjh6 drive-4zlp drive-y37b drive-zml5 ---------- *)

(* A whole drive over the fake browser with the real client: observe, one System One call
   per step, the first step acted on, the second DONE, and the trace the reply carries. *)
let drive_to_done () =
  rig (fun env sw tabs fake logger memory ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw
          (scripted ~model:jev_model [ Answer "SCROLL_DOWN"; Answer "DONE" ])
      in
      let config = models_config ~endpoint:(Server.url server "/api/v1/systemone") () in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle "Open the Wikipedia article") in
      Alcotest.(check string) "drive-y7v8 done" "done" (text "status" reply);
      let steps = list (get "steps" reply) in
      Alcotest.(check int) "drive-xjh6 two steps" 2 (List.length steps);
      let first = List.hd steps in
      Alcotest.(check string)
        "drive-xjh6 the first operation" "scroll_down" (text "operation" first);
      Alcotest.(check bool)
        "drive-xjh6 the operation distribution" true
        (match field "op" (get "probabilities" first) with
        | Some (`Assoc fields) -> List.assoc_opt "SCROLL_DOWN" fields = Some (`Float 1.)
        | _ -> false);
      Alcotest.(check string)
        "drive-xjh6 the last operation" "done"
        (text "operation" (List.nth steps 1));
      let final = get "final" reply in
      Alcotest.(check string)
        "drive-4zlp the final url" "https://example.com/" (text "url" final);
      Alcotest.(check string) "drive-4zlp the final title" "Example" (text "title" final);
      (* The System One requests: one per decision, shaped by Jev_request. *)
      Alcotest.(check int) "drive-y7v8 two System One calls" 2 (Server.connections server);
      let requests = Server.requests server in
      let first_request = List.hd requests in
      Alcotest.(check string) "the method" "POST" first_request.Server.method_;
      Alcotest.(check string)
        "drive-yqxg the configured endpoint" "/api/v1/systemone"
        first_request.Server.target;
      Alcotest.(check (option string))
        "the bearer header"
        (Some ("Bearer " ^ key))
        (Server.header "authorization" first_request);
      Alcotest.(check (option string))
        "the content type" (Some "application/json")
        (Server.header "content-type" first_request);
      let body = Yojson.Safe.from_string first_request.Server.body in
      Alcotest.(check string) "drive-e7oi the pinned model" jev_model (text "model" body);
      let state = get "state" body in
      let page = get "page" state in
      Alcotest.(check string)
        "drive-y37b the page url" "https://example.com/" (text "url" page);
      Alcotest.(check string) "drive-y37b the page title" "Example" (text "title" page);
      Alcotest.(check string)
        "drive-y37b the page text" "Example content" (text "text" page);
      Alcotest.(check bool)
        "drive-zml5 the element table is in the request" true
        (List.length (list (get "elements" state)) > 0);
      Alcotest.(check bool)
        "drive-zml5 the operation criteria" true
        (match field "operation" (get "questions" body) with
        | Some question -> (
            match field "criteria" question with
            | Some (`Assoc criteria) ->
                List.mem_assoc "DONE" criteria && List.mem_assoc "SCROLL_DOWN" criteria
            | _ -> false)
        | None -> false);
      Alcotest.(check bool)
        "drive-zml5 no target head for a control" true
        (match field "questions" body with
        | Some questions ->
            not
              (List.mem_assoc "scroll_down_target"
                 (match questions with `Assoc fields -> fields | _ -> []))
        | None -> false);
      let second = Yojson.Safe.from_string (List.nth requests 1).Server.body in
      let recent = list (get "recent_actions" (get "state" second)) in
      Alcotest.(check int) "drive-y37b one recent action" 1 (List.length recent);
      let action = List.hd recent in
      Alcotest.(check string)
        "drive-y37b the recent action" "scroll_down" (text "action" action);
      Alcotest.(check string) "drive-y37b its kind" "scroll" (text "kind" action);
      (* Status reports the models; the key is on no rendering path. *)
      let status = result (raw ~models tabs P.Status) in
      let reported = get "models" status in
      Alcotest.(check bool)
        "drive-e7oi status says configured" true
        (get "configured" reported = `Bool true);
      Alcotest.(check string)
        "drive-e7oi status names the pinned model" jev_model (text "jev_model" reported);
      Alcotest.(check string)
        "drive-yqxg status names the endpoint"
        (Server.url server "/api/v1/systemone")
        (text "systemone_endpoint" reported);
      Alcotest.(check bool)
        "the key is not in the status reply" false
        (contains (Yojson.Safe.to_string status) key);
      let logged = Logger.Memory.records memory |> List.map Logger.to_string in
      Alcotest.(check bool) "the models service logged" true (logged <> []);
      Alcotest.(check bool)
        "the key never reaches a log line" false
        (List.exists (fun line -> contains line key) logged))

(* ---------- drive-kh2u: a provider failure, with the completed steps ---------- *)

let model_error () =
  rig (fun env sw tabs fake logger _ ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw
          (scripted ~model:jev_model
             [ Answer "SCROLL_DOWN"; Refused (500, "the provider fell over") ])
      in
      let config = models_config ~endpoint:(Server.url server "/api/v1/systemone") () in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let error = failure (drive models tabs handle "Open the Wikipedia article") in
      check_code "drive-kh2u model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-kh2u the provider's kind" "unavailable" (detail_code error);
      Alcotest.(check bool)
        "drive-kh2u the message names the provider failure" true
        (contains error.message "HTTP 500");
      let steps = detail_steps error in
      Alcotest.(check int) "drive-kh2u one completed step" 1 (List.length steps);
      Alcotest.(check string)
        "drive-kh2u the step that completed" "scroll_down"
        (text "operation" (List.hd steps));
      Alcotest.(check int) "drive-kh2u one attempt per call" 2 (Server.connections server))

(* ---------- drive-e7oi: a provider substitution is caught ---------- *)

let model_mismatch () =
  rig (fun env sw tabs fake logger _ ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw
          (scripted ~model:jev_model ~reply_model:"someone/else" [ Answer "DONE" ])
      in
      let config = models_config ~endpoint:(Server.url server "/api/v1/systemone") () in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let error = failure (drive models tabs handle "Open the Wikipedia article") in
      check_code "drive-e7oi model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-e7oi the substituted model" "model-mismatch" (detail_code error);
      Alcotest.(check bool)
        "drive-e7oi the message names both models" true
        (contains error.message "someone/else" && contains error.message jev_model);
      Alcotest.(check int)
        "drive-e7oi a substitution is not retried" 1 (Server.connections server);
      Alcotest.(check int)
        "drive-e7oi no step completed" 0
        (List.length (detail_steps error)))

(* ---------- drive-kh2u: a missing key fails fast, and status says so ---------- *)

let missing_key () =
  rig (fun env sw tabs fake logger _ ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw (scripted ~model:jev_model [ Answer "DONE" ])
      in
      let config =
        models_config ~api_key:None ~endpoint:(Server.url server "/api/v1/systemone") ()
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let status = result (raw ~models tabs P.Status) in
      let reported = get "models" status in
      Alcotest.(check bool)
        "drive-kh2u status reports the missing key" false
        (get "configured" reported = `Bool true);
      Alcotest.(check string)
        "the endpoint is still reported"
        (Server.url server "/api/v1/systemone")
        (text "systemone_endpoint" reported);
      Alcotest.(check bool)
        "the key is not in the status reply" false
        (contains (Yojson.Safe.to_string status) key);
      let handle = new_tab tabs in
      let error = failure (drive models tabs handle "Open the Wikipedia article") in
      check_code "drive-kh2u model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-kh2u the reason is the missing key" "missing-key" (detail_code error);
      Alcotest.(check int)
        "drive-kh2u no step completed" 0
        (List.length (detail_steps error));
      Alcotest.(check int) "drive-kh2u nothing was sent" 0 (Server.connections server))

(* ---------- drive-yqxg: the endpoints are configurable and default to OpenRouter ---- *)

let endpoints () =
  let decode text =
    match Eta_app.Config.decode ~spec:Config.spec ~getenv:(fun _ -> None) text with
    | Ok config -> config
    | Error (`Config why) -> Alcotest.fail why
  in
  let base =
    {|
[chrome]
binary = "/bin/sh"
profile_dir = "/tmp/leash-models-profile"
workspace = "leash"
headless = true
[tabs]
cap = 8
[expiry]
idle_s = 1800
unclaimed_s = 3600
tombstone_s = 3600
|}
  in
  let defaults = decode base in
  Alcotest.(check string)
    "drive-yqxg the default System One endpoint" "https://openrouter.ai/api/v1/systemone"
    (Config.Text.to_string defaults.models.systemone_endpoint);
  Alcotest.(check string)
    "drive-yqxg the default chat base URL" "https://openrouter.ai/api/v1"
    (Config.Text.to_string defaults.models.chat_base_url);
  Alcotest.(check string)
    "drive-e7oi the default JEV model" jev_model
    (Config.Text.to_string defaults.models.jev_model);
  Alcotest.(check string)
    "the default text model" text_model
    (Config.Text.to_string defaults.models.text_model);
  Alcotest.(check bool)
    "drive-yqxg no key by default" true
    (defaults.models.api_key = None);
  (* svc-kzt6 drive-yqxg: the environment key alone is enough — the section may be absent,
     and the endpoints and model ids are still the defaults. *)
  let from_env =
    match
      Eta_app.Config.decode ~spec:Config.spec
        ~getenv:(fun name -> if name = "OPENROUTER_API_KEY" then Some key else None)
        base
    with
    | Ok config -> config
    | Error (`Config why) -> Alcotest.fail why
  in
  (match from_env.models.api_key with
  | Some api_key ->
      Alcotest.(check string)
        "svc-kzt6 the environment key wins" key
        (Config.Redact.expose api_key)
  | None -> Alcotest.fail "the environment key must be present");
  Alcotest.(check string)
    "drive-yqxg the defaults beside it" "https://openrouter.ai/api/v1/systemone"
    (Config.Text.to_string from_env.models.systemone_endpoint);
  let typesafe =
    decode
      (base
     ^ {|
[models]
systemone_endpoint = "https://api.typesafe.ai/v1/systemone"
chat_base_url = "https://api.typesafe.ai/v1"
jev_model = "jev-latest"
|}
      )
  in
  Alcotest.(check string)
    "drive-yqxg TypeSafe's direct endpoint is accepted"
    "https://api.typesafe.ai/v1/systemone"
    (Config.Text.to_string typesafe.models.systemone_endpoint);
  Alcotest.(check string)
    "drive-yqxg the chat base URL is configurable" "https://api.typesafe.ai/v1"
    (Config.Text.to_string typesafe.models.chat_base_url);
  (* The models service reports exactly what the file said, and the key stays a Redact. *)
  rig (fun env sw _ _ logger _ ->
      let config =
        { typesafe.models with api_key = Some (Eta_observability.Redact.make key) }
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let status = Models.status models in
      Alcotest.(check bool) "drive-yqxg configured" true status.P.configured;
      Alcotest.(check string)
        "drive-yqxg the reported endpoint" "https://api.typesafe.ai/v1/systemone"
        status.P.systemone_endpoint;
      Alcotest.(check string)
        "drive-e7oi the reported model" "jev-latest" status.P.jev_model;
      Alcotest.(check string)
        "drive-yqxg the reported chat base" "https://api.typesafe.ai/v1"
        status.P.chat_base_url;
      Alcotest.(check bool)
        "the key is not in the models status" false
        (contains (Yojson.Safe.to_string (P.yojson_of_models_status status)) key))

let () =
  Alcotest.run "L19 models"
    [
      ( "models",
        [
          Alcotest.test_case "drive-y7v8 xjh6 4zlp y37b zml5 e7oi yqxg full drive" `Quick
            drive_to_done;
          Alcotest.test_case "drive-kh2u model error" `Quick model_error;
          Alcotest.test_case "drive-e7oi model mismatch" `Quick model_mismatch;
          Alcotest.test_case "drive-kh2u missing key" `Quick missing_key;
          Alcotest.test_case "drive-yqxg endpoints" `Quick endpoints;
        ] );
    ]
