(* L19 — models wiring (docs/issues/drive/01-drive.md, milestone 5).

   drive-e7oi: the JEV model id is pinned in config and the reply's model is checked
   against it. drive-yqxg: the System One endpoint and the text-helper base URL are
   configurable and default to OpenRouter, with TypeSafe's direct endpoint accepted.
   drive-kh2u: a provider failure ends the drive with model-unavailable and the completed
   steps in the detail; a missing key fails fast and status says so.

   The model client is served by a local plaintext System One server
   (leash_test_support.Fake_systemone) and the browser by the scripted CDP peer, so nothing
   here touches the network or a real browser. The clock is Eio's real one, as ox's
   AI tests explain: the client's socket wait and a mock clock cannot both make progress in
   one domain. *)

module P = Leash.Protocol
module Fake = Leash_test_support.Fake_browser
module Server = Leash_test_support.Fake_systemone
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

(* fly-8fgl: once a page exists, a provider failure is terminal evidence, not a
   discarded protocol error. *)
let evidence reply =
  match reply with
  | P.Failure error ->
      Alcotest.failf "fly-8fgl discarded terminal evidence: %s" error.message
  | P.Success json ->
      let error =
        match P.error_of_yojson (get "error" (get "operator_state" json)) with
        | Ok error -> error
        | Error why -> Alcotest.fail why
      in
      let steps = match get "operator_steps" json with `List steps -> steps | _ -> [] in
      (json, error, steps)

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
   a bare text input and a button (tab-zc36). The operator read is the Runtime.evaluate
   whose expression contains leash-operator-read; its scroll height is the old metric
   fixture, so the drive still observes a page it can scroll down. *)
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
          let mgr = Ox_test.Process.make [ Block_until_signal; Block_until_signal ] in
          let current = ref None in
          let launch ~sw ~clock ~mgr:_ config =
            let fake, client = Fake.create ~sw () in
            current := Some fake;
            match
              Ox_process.Child.spawn ~caps:(Ox_test.powerbox ()) ~sw ~clock
                ~mgr:(Ox_test.Process.mgr mgr) ~argv:(Chrome.argv config)
                ~grace:(Ox.Duration.ms 50) ~fds:[] ()
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
              {
                Chrome.clock = env#clock;
                mgr = env#process_mgr;
                logger;
                caps = (Ox_test.powerbox () :> Leash.Chrome.caps);
              }
          in
          let tabs =
            Leash.Tabs.create ~sw ~cap:2 ~tombstone_s:3600
              {
                Leash.Tabs.chrome;
                clock = env#clock;
                logger;
                desktop = Leash.Desktop.disabled;
                caps = (Ox_test.powerbox () :> Leash.Tabs.caps);
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
    Config.default.models with
    api_key = Option.map Ox_observability.Redact.make api_key;
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
       {
         tab = Some handle;
         mission = goal;
         max_steps = None;
         start_url = None;
         max_procedures = Some 4;
         deadline_s = Some 30;
         dry_run = None;
         expect = None;
         out = None;
       })

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
      let steps = list (get "operator_steps" reply) in
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
        (List.exists (fun line -> contains line key) logged);
      (* drive-y7v8 fly-iodm: scroll metrics now travel in the operator read, not a
         separate callFunctionOn. The expression must still survive a document with no
         documentElement, or the step after a navigation errors instead of observing. *)
      let metrics =
        Fake.received fake
        |> List.filter_map (fun call ->
            match field "method" call with
            | Some (`String "Runtime.evaluate") -> (
                match field "params" call with
                | Some params -> field "expression" params
                | None -> None)
            | _ -> None)
        |> List.filter (fun body ->
            contains
              (match body with `String body -> body | _ -> "")
              "leash-operator-read")
      in
      Alcotest.(check bool)
        "drive-y7v8 the drive takes scroll metrics" true (metrics <> []);
      List.iter
        (fun body ->
          Alcotest.(check bool)
            "drive-y7v8 metrics survive a missing documentElement" true
            (contains
               (match body with `String body -> body | _ -> "")
               "document.documentElement?.scrollHeight"))
        metrics)

(* ---------- drive-7tvn: the usage and cost of each decision, logged ---------- *)

(* One answered decision writes one info line with the model, the token counts and the
   cost the provider reported — the operator's view of what the drive cost. *)
let usage_is_logged () =
  rig (fun env sw tabs fake logger memory ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw (scripted ~model:jev_model [ Answer "DONE" ])
      in
      let config = models_config ~endpoint:(Server.url server "/api/v1/systemone") () in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let reply = result (drive models tabs handle "Open the Wikipedia article") in
      Alcotest.(check string) "drive-y7v8 done" "done" (text "status" reply);
      let open Logger in
      let usage =
        List.filter
          (fun r -> r.level = Info && String.equal r.msg "systemone usage")
          (Memory.records memory)
      in
      Alcotest.(check int) "drive-7tvn one usage line per decision" 1 (List.length usage);
      let fields = (List.hd usage).fields in
      let field name =
        match List.assoc_opt name fields with
        | Some value -> value
        | None -> Alcotest.fail ("no " ^ name ^ " field")
      in
      Alcotest.(check string)
        "drive-7tvn the model" jev_model
        (match field "model" with String model -> model | _ -> Alcotest.fail "model");
      Alcotest.(check int)
        "drive-7tvn input tokens" 10
        (match field "input_tokens" with Int n -> n | _ -> Alcotest.fail "input");
      Alcotest.(check int)
        "drive-7tvn output tokens" 2
        (match field "output_tokens" with Int n -> n | _ -> Alcotest.fail "output");
      Alcotest.(check (float 0.0000001))
        "drive-7tvn the cost" 0.0001
        (match field "cost" with Float cost -> cost | _ -> Alcotest.fail "cost"))

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
      let json, error, steps =
        evidence (drive models tabs handle "Open the Wikipedia article")
      in
      Alcotest.(check string) "fly-8fgl terminal status" "error" (text "status" json);
      check_code "drive-kh2u model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-kh2u the provider's kind" "unavailable" (detail_code error);
      Alcotest.(check bool)
        "drive-kh2u the message names the provider failure" true
        (contains error.message "HTTP 500");
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
      let json, error, steps =
        evidence (drive models tabs handle "Open the Wikipedia article")
      in
      Alcotest.(check string) "fly-8fgl terminal status" "error" (text "status" json);
      check_code "drive-e7oi model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-e7oi the substituted model" "model-mismatch" (detail_code error);
      Alcotest.(check bool)
        "drive-e7oi the message names both models" true
        (contains error.message "someone/else" && contains error.message jev_model);
      Alcotest.(check int)
        "drive-e7oi a substitution is not retried" 1 (Server.connections server);
      Alcotest.(check int) "drive-e7oi no step completed" 0 (List.length steps))

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
      let json, error, steps =
        evidence (drive models tabs handle "Open the Wikipedia article")
      in
      Alcotest.(check string) "fly-8fgl terminal status" "error" (text "status" json);
      check_code "drive-kh2u model-unavailable" "model-unavailable" error;
      Alcotest.(check string)
        "drive-kh2u the reason is the missing key" "missing-key" (detail_code error);
      Alcotest.(check int) "drive-kh2u no step completed" 0 (List.length steps);
      Alcotest.(check int) "drive-kh2u nothing was sent" 0 (Server.connections server))

(* ---------- drive-yqxg: the endpoints are configurable and default to OpenRouter ---- *)

let endpoints () =
  let decode text =
    match Ox_app.Config.decode ~spec:Config.spec ~getenv:(fun _ -> None) text with
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
      Ox_app.Config.decode ~spec:Config.spec
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
        { typesafe.models with api_key = Some (Ox_observability.Redact.make key) }
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

(* daily-9ggi daily-6pde: per-attempt timeouts are not the mission budget. A
   healthy slow reply must survive raising only the relevant model timeout; a
   short caller deadline still bounds both attempts and backoff. *)
let seconds n =
  match Config.Seconds.of_int n with Ok n -> n | Error why -> Alcotest.fail why

let provider_timeout ~attempt ~deadline ~succeeds () =
  rig (fun env sw tabs fake logger _ ->
      script_page fake;
      let server =
        Server.serve ~net:env#net ~sw (fun request ->
            Eio.Time.sleep env#clock 1.3;
            Server.ok
              (answer ~model:jev_model ~choice:"DONE"
                 (Yojson.Safe.from_string request.Server.body)))
      in
      let config =
        {
          (models_config ~endpoint:(Server.url server "/systemone") ()) with
          jev_timeout = seconds attempt;
        }
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let handle = new_tab tabs in
      let started = Eio.Time.now env#clock in
      let reply =
        raw ~model:jev_model
          ~decide:(fun ~deadline:_ request -> Models.decide ~deadline models request)
          tabs
          (P.Drive
             {
               tab = Some handle;
               mission = "Finish";
               max_steps = None;
               start_url = None;
               max_procedures = Some 1;
               deadline_s = Some 30;
               dry_run = None;
               expect = None;
               out = None;
             })
      in
      if succeeds then ignore (result reply)
      else begin
        let json, error, _steps = evidence reply in
        Alcotest.(check string) "fly-8fgl terminal status" "error" (text "status" json);
        check_code "daily-6pde retryable provider timeout" "model-timeout" error;
        Alcotest.(check string) "daily-9ggi timeout kind" "timeout" (detail_code error);
        Alcotest.(check string)
          "daily-9ggi timed-out model" "jev"
          (text "model_kind" (Option.get error.detail));
        Alcotest.(check bool)
          "daily-6pde timeout does not blame the key" false
          (contains error.hint "API_KEY");
        Alcotest.(check bool)
          "daily-9ggi total deadline bounds retries" true
          (Eio.Time.now env#clock -. started < Ox.Duration.to_seconds_float deadline +. 1.);
        Alcotest.(check int)
          "daily-9ggi bounded attempts"
          (if attempt = 1 then 2 else 1)
          (Server.connections server)
      end)

let chat_timeout ~kind ~attempt ~expected () =
  rig (fun env sw _ _ logger _ ->
      let server =
        Server.serve ~net:env#net ~sw (fun _ ->
            Eio.Time.sleep env#clock 1.3;
            Server.failure 401 "invalid test key")
      in
      let config =
        {
          (models_config ()) with
          chat_base_url = text_value (Server.url server "");
          planner_endpoint = Some (text_value (Server.url server "/planner"));
          jev_timeout = seconds 1;
          text_timeout = seconds (if kind = "text" then attempt else 1);
          planner_timeout = seconds (if kind = "planner" then attempt else 1);
        }
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let deadline = Ox.Duration.seconds 5 in
      let reply =
        if kind = "text" then
          Result.map
            (fun _ -> ())
            ((Models.text_helper models).complete ~deadline
               {
                 Leash.Text_helper.goal = "fill";
                 field = { label = "Name"; role = "textbox"; value = "" };
                 page_title = "Form";
                 page_text = "Name";
                 recent = [];
               })
        else
          Result.map
            (fun _ -> ())
            ((Models.levels models).plan ~deadline
               {
                 Leash.Run.trigger = Blocked;
                 reason = "blocked";
                 mission = "collect";
                 site = None;
                 playbook = None;
                 recent = [];
                 arguments = [];
                 page_kind = None;
                 title = "Books";
                 url = "https://example.com";
                 text = "Books";
               })
      in
      let error =
        match reply with Error error -> error | Ok _ -> Alcotest.fail "expected failure"
      in
      Alcotest.(check string)
        "daily-9ggi independent client budget" expected (detail_code error);
      Alcotest.(check string)
        "daily-9ggi identifies client kind" kind
        (text "model_kind" (Option.get error.detail));
      Alcotest.(check int)
        "daily-9ggi bounded retries; no auth retry"
        (if expected = "timeout" then 2 else 1)
        (Server.connections server))

(* daily-9ggi: a formatting correction shares the original total budget. *)
let text_correction_budget ~deadline ~succeeds () =
  rig (fun env sw _ _ logger _ ->
      let calls = ref 0 in
      let server =
        Server.serve ~net:env#net ~sw (fun _ ->
            incr calls;
            Eio.Time.sleep env#clock 0.25;
            let content = if !calls = 1 then "not json" else {|{"text":"hello"}|} in
            Server.ok
              (Yojson.Safe.to_string
                 (obj
                    [
                      ("id", str "test");
                      ("model", str text_model);
                      ( "choices",
                        `List
                          [
                            obj
                              [
                                ("index", `Int 0);
                                ("finish_reason", str "stop");
                                ( "message",
                                  obj
                                    [
                                      ("role", str "assistant"); ("content", str content);
                                    ] );
                              ];
                          ] );
                      ( "usage",
                        obj
                          [
                            ("prompt_tokens", `Int 1);
                            ("completion_tokens", `Int 1);
                            ("total_tokens", `Int 2);
                          ] );
                    ])))
      in
      let config =
        { (models_config ()) with chat_base_url = text_value (Server.url server "") }
      in
      let models = Models.create ~sw ~net:env#net ~clock:env#clock ~logger config in
      let reply =
        (Models.text_helper models).complete ~deadline
          {
            Leash.Text_helper.goal = "fill";
            field = { label = "Name"; role = "textbox"; value = "" };
            page_title = "Form";
            page_text = "Name";
            recent = [];
          }
      in
      (match reply with
      | Ok value when succeeds ->
          Alcotest.(check (option string)) "corrected" (Some "hello") value
      | Error error when not succeeds ->
          check_code "daily-9ggi correction cannot refresh deadline" "model-timeout" error
      | _ -> Alcotest.fail "unexpected correction outcome");
      Alcotest.(check int) "daily-9ggi one bounded correction" 2 !calls)

let timeout_config () =
  let json =
    obj
      [
        ( "models",
          obj
            [
              ("jev_timeout", `Int 4);
              ("text_timeout", `Int 7);
              ("planner_timeout", `Int 90);
            ] );
      ]
  in
  let config =
    match Config.t_of_yojson json with Ok c -> c | Error e -> Alcotest.fail e
  in
  Alcotest.(check (list int))
    "daily-9ggi independent budgets" [ 4; 7; 90 ]
    (List.map Config.Seconds.to_int
       [
         config.models.jev_timeout;
         config.models.text_timeout;
         config.models.planner_timeout;
       ]);
  List.iter
    (fun name ->
      let json = obj [ ("models", obj [ (name, `Int 0) ]) ] in
      Alcotest.(check bool)
        "daily-9ggi rejects nonpositive timeout" true
        (Result.is_error (Config.t_of_yojson json));
      match Config.decode_all json with
      | Ok _ -> Alcotest.fail "daily-9ggi aggregate decoder accepted zero"
      | Error errors ->
          Alcotest.(check bool)
            "daily-9ggi precise config pointer" true
            (List.exists (fun e -> e.Ox_app.Config.pointer = "/models/" ^ name) errors))
    [ "jev_timeout"; "text_timeout"; "planner_timeout" ];
  Alcotest.(check bool)
    "daily-9ggi unknown models setting rejected" true
    (Result.is_error (Config.t_of_yojson (obj [ ("models", obj [ ("typo", `Int 1) ]) ])));
  let decoded =
    match Config.t_of_yojson (Config.yojson_of_t config) with
    | Ok c -> c
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check int)
    "daily-9ggi config roundtrip" 90
    (Config.Seconds.to_int decoded.models.planner_timeout)

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
          Alcotest.test_case "drive-7tvn usage is logged" `Quick usage_is_logged;
          Alcotest.test_case "daily-9ggi configured provider timeout retries" `Quick
            (provider_timeout ~attempt:1 ~deadline:(Ox.Duration.seconds 5) ~succeeds:false);
          Alcotest.test_case "daily-9ggi slow provider succeeds with raised timeout"
            `Quick
            (provider_timeout ~attempt:3 ~deadline:(Ox.Duration.seconds 5) ~succeeds:true);
          Alcotest.test_case "daily-9ggi caller budget bounds retries" `Quick
            (provider_timeout ~attempt:3 ~deadline:(Ox.Duration.ms 100) ~succeeds:false);
          Alcotest.test_case "daily-9ggi model timeout config" `Quick timeout_config;
          Alcotest.test_case "daily-9ggi text correction shares deadline" `Quick
            (text_correction_budget ~deadline:(Ox.Duration.ms 400) ~succeeds:false);
          Alcotest.test_case "daily-9ggi text correction within budget succeeds" `Quick
            (text_correction_budget ~deadline:(Ox.Duration.seconds 2) ~succeeds:true);
          Alcotest.test_case "daily-9ggi text attempt timeout" `Quick
            (chat_timeout ~kind:"text" ~attempt:1 ~expected:"timeout");
          Alcotest.test_case "daily-9ggi text uses own budget" `Quick
            (chat_timeout ~kind:"text" ~attempt:3 ~expected:"authentication");
          Alcotest.test_case "daily-9ggi planner attempt timeout" `Quick
            (chat_timeout ~kind:"planner" ~attempt:1 ~expected:"timeout");
          Alcotest.test_case "daily-9ggi planner uses own budget" `Quick
            (chat_timeout ~kind:"planner" ~attempt:3 ~expected:"authentication");
        ] );
    ]
