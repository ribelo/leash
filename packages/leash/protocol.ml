open Eta_schema
module J = Eta_schema.Json

let object_ fields = Result.get_ok (J.object_ fields)
let string s = Result.get_ok (J.string s)
let prop key value = (key, value)

type field = Spec : string * bool * 'a Eta_schema.t -> field

let req name schema = Spec (name, true, schema)
let opt name schema = Spec (name, false, schema)

let shape name fields =
  let properties =
    List.map (fun (Spec (key, _, schema)) -> prop key (json_schema schema)) fields
  in
  let required =
    List.filter_map
      (fun (Spec (key, needed, _)) -> if needed then Some (string key) else None)
      fields
  in
  let metadata =
    object_
      [
        prop "type" (string "object");
        prop "properties" (object_ properties);
        prop "required" (J.array required);
        prop "additionalProperties" (J.bool false);
      ]
  in
  let check value =
    match value with
    | J.Object members -> (
        let unknown =
          List.filter_map
            (fun (key, _) ->
              if List.exists (fun (Spec (known, _, _)) -> known = key) fields then None
              else Some (issue ~path:[ Field key ] "unknown field"))
            members
        in
        let problems =
          List.concat_map
            (fun (Spec (key, needed, schema)) ->
              match List.assoc_opt key members with
              | None -> if needed then [ missing_field ~path:[ Field key ] key ] else []
              | Some value -> (
                  match decode_result schema value with
                  | Ok _ -> []
                  | Error issues -> at_field key issues))
            fields
        in
        match unknown @ problems with [] -> Ok value | issues -> Error issues)
    | _ -> Error [ type_mismatch ~expected:"object" ~got:"non-object" () ]
  in
  custom ~equal:J.equal ~decode:check ~encode:check ~json_schema:metadata ()

let e name values =
  let allowed = List.map (fun s -> (s, s)) values in
  let schema = enum ~name allowed ~equal:String.equal in
  custom ~equal:J.equal
    ~decode:(fun j ->
      match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs)
    ~encode:(fun j ->
      match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs)
    ~json_schema:(json_schema schema) ()

let scalar schema =
  custom ~equal:J.equal
    ~decode:(fun j ->
      match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs)
    ~encode:(fun j ->
      match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs)
    ~json_schema:(json_schema schema) ()

let s = scalar Eta_schema.string
let i = scalar Eta_schema.int
let b = scalar Eta_schema.bool
let f = scalar Eta_schema.float

let nullable schema =
  custom ~equal:J.equal
    ~decode:(function
      | J.Null as j -> Ok j
      | j -> ( match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs))
    ~encode:(function
      | J.Null as j -> Ok j
      | j -> ( match decode_result schema j with Ok _ -> Ok j | Error xs -> Error xs))
    ~json_schema:
      (object_
         [
           prop "anyOf"
             (J.array [ json_schema schema; object_ [ prop "type" (string "null") ] ]);
         ])
    ()

let arr schema =
  let schema = array schema in
  scalar schema

let empty = shape "empty" []
let identity = Eta_schema.json
let kv name value = shape name [ req name value ]
let origin_schema = e "origin" [ "agent"; "human" ]
let state_schema = e "state" [ "unowned"; "owned"; "with_human" ]

let expires_schema =
  shape "expires" [ req "stage" (e "stage" [ "release"; "close" ]); req "in_s" i ]

let tab_info_schema =
  shape "TabInfo"
    [
      req "tab" s;
      req "url" s;
      req "title" s;
      req "origin" origin_schema;
      req "state" state_schema;
      req "owner" (nullable s);
      req "generation" i;
      req "expires" (nullable expires_schema);
    ]

let dialog_schema =
  shape "Dialog"
    [
      req "kind" (e "dialog-kind" [ "alert"; "confirm"; "prompt"; "beforeunload" ]);
      req "message" s;
    ]

let row_schema =
  shape "Row"
    [
      req "index" i;
      req "role" s;
      req "name" s;
      opt "value" s;
      opt "state"
        (arr
           (e "row-state"
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
              ]));
    ]

let snapshot_schema =
  shape "Snapshot"
    [
      req "snapshot" s;
      req "tab" s;
      req "url" s;
      req "title" s;
      req "rows" (arr row_schema);
      req "total" i;
      req "offset" i;
      req "truncated" b;
      req "dialog" (nullable dialog_schema);
    ]

let action_result_schema =
  shape "ActionResult"
    [
      req "tab" s;
      req "url" s;
      req "title" s;
      req "snapshot" (nullable s);
      req "dialog" (nullable dialog_schema);
      req "popups" (arr tab_info_schema);
    ]

let debug_entry_schema =
  shape "DebugEntry"
    [
      req "at" s;
      req "kind" (e "debug-kind" [ "console"; "exception"; "request-failed" ]);
      opt "level" s;
      req "text" s;
    ]

let operation_schema =
  e "Operation"
    [
      "click";
      "type_text";
      "select";
      "scroll_up";
      "scroll_down";
      "wait";
      "done";
      "blocked";
    ]

let probabilities_schema =
  shape "probabilities" [ req "op" json_object; req "target" json_object ]

let step_schema =
  shape "Step"
    [
      req "n" i;
      req "snapshot" s;
      req "operation" operation_schema;
      req "index" (nullable i);
      req "probabilities" probabilities_schema;
      opt "text" s;
      req "after" (shape "after" [ req "url" s; req "title" s ]);
      req "elapsed_ms" i;
    ]

let wait_until_schema =
  shape "wait-until"
    [ opt "url_prefix" s; opt "text" s; opt "index_gone" i; opt "dialog" b ]

let tab = req "tab" s

let command_schemas =
  [
    ("new", shape "new" [ opt "url" s ]);
    ("list", shape "list" [ opt "all" b ]);
    ("claim", shape "claim" [ tab ]);
    ("release", shape "release" [ tab ]);
    ("close", shape "close" [ tab ]);
    ("status", empty);
    ("snap", shape "snap" [ tab; opt "match" s; opt "limit" i; opt "offset" i ]);
    ("text", shape "text" [ tab; opt "index" i; opt "max_chars" i ]);
    ("shot", shape "shot" [ tab; req "path" s; opt "full_page" b ]);
    ("debug", shape "debug" [ tab; opt "limit" i; opt "clear" b ]);
    ("eval", shape "eval" [ tab; req "expression" s; opt "argument" identity ]);
    ("nav", shape "nav" [ tab; req "url" s ]);
    ("click", shape "click" [ tab; req "snapshot" s; req "index" i ]);
    ("fill", shape "fill" [ tab; req "snapshot" s; req "index" i; req "text" s ]);
    ("press", shape "press" [ tab; req "snapshot" s; opt "index" i; req "key" s ]);
    ("select", shape "select" [ tab; req "snapshot" s; req "index" i; req "option" i ]);
    ( "scroll",
      shape "scroll"
        [ tab; req "direction" (e "direction" [ "up"; "down" ]); opt "index" i ] );
    ("wait", shape "wait" [ tab; req "until" wait_until_schema; opt "timeout_ms" i ]);
    ( "dialog",
      shape "dialog"
        [ tab; req "answer" (e "answer" [ "accept"; "dismiss" ]); opt "text" s ] );
    ("handoff", shape "handoff" [ tab; req "reason" s; opt "timeout_s" i ]);
    ("resume", shape "resume" [ tab ]);
    ("drive", shape "drive" [ tab; req "goal" s; opt "max_steps" i; opt "deadline_s" i ]);
  ]

let result_schemas =
  let acknowledgment key = kv key b in
  [
    ("new", tab_info_schema);
    ("list", kv "tabs" (arr tab_info_schema));
    ("claim", tab_info_schema);
    ("release", acknowledgment "released");
    ("close", acknowledgment "closed");
    ( "status",
      shape "status"
        [
          req "generation" i;
          req "tabs" (shape "counts" [ req "open" i; req "cap" i ]);
          req "chrome" (e "chrome-state" [ "running"; "restarting" ]);
          req "uptime_s" f;
        ] );
    ("snap", snapshot_schema);
    ( "text",
      shape "text-result" [ req "url" s; req "title" s; req "text" s; req "truncated" b ]
    );
    ("shot", shape "shot-result" [ req "path" s; req "bytes" i ]);
    ("debug", kv "entries" (arr debug_entry_schema));
    ("eval", kv "value" identity);
    ("nav", action_result_schema);
    ("click", action_result_schema);
    ("fill", action_result_schema);
    ("press", action_result_schema);
    ("select", action_result_schema);
    ("scroll", action_result_schema);
    ("wait", action_result_schema);
    ("dialog", action_result_schema);
    ("handoff", shape "handoff-result" [ req "resumed" b; req "url" s; req "title" s ]);
    ("resume", acknowledgment "resumed");
    ( "drive",
      shape "drive-result"
        [
          req "status"
            (e "drive-status" [ "done"; "blocked"; "step-cap"; "deadline"; "error" ]);
          req "steps" (arr step_schema);
          req "final" snapshot_schema;
        ] );
  ]

type request = { v : int; owner : string; cmd : string; args : Eta_schema.json }

let request_schema =
  refine ~name:"control-request"
    (fun request ->
      match List.assoc_opt request.cmd command_schemas with
      | None -> [ issue ~path:[ Field "cmd" ] "unknown command" ]
      | Some schema -> (
          match decode_result schema request.args with
          | Ok _ -> []
          | Error xs -> at_field "args" xs))
    (closed
       (record4 ~name:"control-request"
          (fun v owner cmd args -> { v; owner; cmd; args })
          (required "v"
             (refine ~name:"version"
                (fun n -> if n = 1 then [] else [ issue "unsupported version" ])
                int)
             (fun r -> r.v))
          (required "owner"
             (refine ~name:"owner"
                (fun s ->
                  if String.trim s <> "" then [] else [ issue "owner must not be empty" ])
                Eta_schema.string)
             (fun r -> r.owner))
          (required "cmd" Eta_schema.string (fun r -> r.cmd))
          (required "args" Eta_schema.json (fun r -> r.args))
          ~equal:( = ) ()))

let error_codes =
  [
    "invalid-request";
    "not-owner";
    "already-owned";
    "with-human";
    "tab-gone";
    "unknown-tab";
    "stale-snapshot";
    "no-such-row";
    "row-not-actionable";
    "dialog-open";
    "no-dialog";
    "url-refused";
    "tab-cap";
    "timeout";
    "browser-unavailable";
    "model-unavailable";
    "too-large";
    "internal";
  ]

type error = { code : string; message : string; detail : Eta_schema.json option }

let error_schema =
  closed
    (record3 ~name:"control-error"
       (fun code message detail -> { code; message; detail })
       (required "code"
          (enum ~name:"error-code"
             (List.map (fun x -> (x, x)) error_codes)
             ~equal:String.equal)
          (fun e -> e.code))
       (required "message" Eta_schema.string (fun e -> e.message))
       (optional "detail" Eta_schema.json (fun e -> e.detail))
       ~equal:( = ) ())

type reply = { ok : bool; result : Eta_schema.json option; error : error option }

let reply_schema =
  refine ~name:"control-reply"
    (fun r ->
      match (r.ok, r.result, r.error) with
      | true, Some _, None | false, None, Some _ -> []
      | _ -> [ issue "reply must contain result only on success, error only on failure" ])
    (closed
       (record3 ~name:"control-reply"
          (fun ok result error -> { ok; result; error })
          (required "ok" Eta_schema.bool (fun r -> r.ok))
          (optional "result" Eta_schema.json (fun r -> r.result))
          (optional "error" error_schema (fun r -> r.error))
          ~equal:( = ) ()))

let decode_request = Eta_schema_yojson.decode_result request_schema
let encode_request = Eta_schema_yojson.encode_result request_schema
let decode_reply = Eta_schema_yojson.decode_result reply_schema
let encode_reply = Eta_schema_yojson.encode_result reply_schema
