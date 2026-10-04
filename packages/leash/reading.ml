module P = Protocol
module D = Ox_json.Of_json

type page_state = { loader : string; guard : (string * int) option }

type browser = {
  call : string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result;
  capture : full_page:bool -> (Yojson.Safe.t, Protocol.error) result;
  now : unit -> float;
  sleep : float -> unit;
  current : unit -> string * string;
  dialog : unit -> Protocol.dialog option;
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
  row : int -> int option;
  snapshot : unit -> Protocol.Snapshot_id.t option;
  baseline : Protocol.Snapshot_id.t -> page_state option;
  probe : unit -> (page_state, Protocol.error) result;
}

let ( let* ) = Result.bind
let obj xs = `Assoc xs
let str x = `String x
let value decoder json = Result.to_option (decoder json)
let field name decoder json = value (D.field name decoder) json
let nested names decoder json = value (D.at names decoder) json
let enum decode text = match decode text with Ok v -> v | Error _ -> assert false

let error code message : P.error =
  P.make_error (enum P.Error_code.of_string code) ~message

let too_large what = error "too-large" (what ^ " exceeds its size limit")
let invalid why = error "invalid-request" why
let internal why = error "internal" why
let remote_value json = nested [ "result"; "value" ] (fun x -> Ok x) json
let no_dialog () = error "no-dialog" "there is no open dialog"

(* daily-6pde daily-9ggi: Chrome withholds page reads behind a modal dialog.
   Refuse before sending them, rather than misclassifying that state as a timeout. *)
let dialog_open dialog =
  P.make_error
    (enum P.Error_code.of_string "dialog-open")
    ~message:"a dialog blocks page reads; answer it first"
    ~detail:(P.yojson_of_dialog dialog)

let check_dialog browser =
  match browser.dialog () with Some dialog -> Error (dialog_open dialog) | None -> Ok ()

let page_call browser meth params =
  let* () = check_dialog browser in
  match browser.call meth params with
  | Error e -> (
      match browser.dialog () with
      | Some dialog -> Error (dialog_open dialog)
      | None -> Error e)
  | result -> result

let stale browser = P.stale_snapshot (browser.snapshot ())

let evaluate browser expression =
  let* reply =
    page_call browser "Runtime.evaluate"
      (obj [ ("expression", str expression); ("returnByValue", `Bool true) ])
  in
  match remote_value reply with
  | Some x -> Ok x
  | None -> Error (internal "browser omitted evaluation value")

let remote_object browser =
  let* reply =
    page_call browser "Runtime.evaluate" (obj [ ("expression", str "globalThis") ])
  in
  match nested [ "result"; "objectId" ] D.string reply with
  | Some id -> Ok id
  | None -> Error (internal "browser omitted global object")

let call_function_with browser ~object_id ~body ~arguments =
  let* reply =
    page_call browser "Runtime.callFunctionOn"
      (obj
         [
           ("objectId", str object_id);
           ("functionDeclaration", str body);
           ("arguments", `List arguments);
           ("returnByValue", `Bool true);
           ("awaitPromise", `Bool true);
         ])
  in
  if field "exceptionDetails" (fun x -> Ok x) reply <> None then
    (* hdoc-vqj7: preserve the engine diagnostic for caller-owned eval bodies. *)
    let message =
      match nested [ "exceptionDetails"; "exception"; "description" ] D.string reply with
      | Some message -> message
      | None ->
          Option.value ~default:"page evaluation threw an exception"
            (nested [ "exceptionDetails"; "text" ] D.string reply)
    in
    Error (error "script-failed" message)
  else
    match remote_value reply with
    | Some x -> Ok x
    | None when nested [ "result"; "type" ] D.string reply = Some "undefined" -> Ok `Null
    | None -> Error (internal "browser omitted function result")

let call_function browser ~object_id ~body ~argument =
  call_function_with browser ~object_id ~body ~arguments:[ obj [ ("value", argument) ] ]

(* tab-gjo0: the call that runs the caller's own function is the one Chrome withholds
   when the function opens a window -- an evaluated [window.open] is answered only once the
   popup is gone (docs/cdp-shapes.md, L10) -- so it settles the way a trusted input does: a
   new target with this tab as its opener ends the wait with a null value, and this tab's
   own death ends it with [tab-gone] (own-teh1). Nothing is re-issued. *)
let evaluated ?(call = call_function_with) browser ~object_id ~body ~arguments =
  match
    Dialog_race.first browser.dialog_race (fun () ->
        Dispatch.first (browser.acknowledge ()) (fun () ->
            call browser ~object_id ~body ~arguments))
  with
  | `Dialog dialog ->
      Error
        {
          (error "dialog-open" "a dialog opened during eval; answer it first") with
          P.detail = Some (P.yojson_of_dialog dialog);
        }
  | `Value (`Acknowledged Dispatch.Popup) -> Ok `Null
  | `Value (`Acknowledged (Dispatch.Gone error)) -> Error error
  | `Value (`Reply result) -> result

let cap = 65_536

let row_object browser index =
  match browser.row index with
  | None -> Error (error "no-such-row" "the snapshot has no such row")
  | Some backend -> (
      match
        page_call browser "DOM.resolveNode" (obj [ ("backendNodeId", `Int backend) ])
      with
      | Error e when e.P.message = "browser refused DOM.resolveNode" ->
          Error (stale browser)
      | Error e -> Error e
      | Ok reply -> (
          match nested [ "object"; "objectId" ] D.string reply with
          | Some id -> Ok id
          | None -> Error (stale browser)))

(* hard-b20d: with a row, the caller's function is called as (argument, element) — the
   element is the row's node, resolved from the snapshot's backend id, so no selector is
   ever written. The snapshot must be the tab's current one: a row of an older table may
   name another element now. *)
let eval browser (args : P.eval_args) =
  let* () = check_dialog browser in
  if String.length args.expression > cap then Error (too_large "expression")
  else
    let argument = Option.value ~default:`Null args.argument in
    if String.length (Ox_json.to_string argument) > cap then Error (too_large "argument")
    else
      let* element =
        match (args.index, args.snapshot) with
        | None, None -> Ok None
        | Some index, Some snapshot ->
            if browser.snapshot () <> Some snapshot then Error (stale browser)
            else
              let* element = row_object browser index in
              Ok (Some element)
        | _ -> Error (invalid "eval takes --index and --snapshot together")
      in
      let* object_id = remote_object browser in
      let* value =
        match element with
        | None ->
            evaluated browser ~object_id
              ~body:("function(argument) {\n" ^ args.expression ^ "\n}")
              ~arguments:[ obj [ ("value", argument) ] ]
        | Some element ->
            evaluated browser ~object_id
              ~body:("function(argument, element) {\n" ^ args.expression ^ "\n}")
              ~arguments:
                [ obj [ ("value", argument) ]; obj [ ("objectId", str element) ] ]
      in
      if String.length (Ox_json.to_string value) > cap then Error (too_large "result")
      else Ok P.{ value }

(* extr-8o1h extr-vgir extr-k40c: running a playbook script. This is the one function that
   hands a script's text to the browser, and it takes a {!Playbook.script} — a value only
   the playbook loader makes, from a playbook directory. The text is called as the body of
   an async function of [args] on the page's global object, [returnByValue] and
   [awaitPromise], so a script may [await fetch(...)] the site's own endpoints with the
   page's cookies and origin. The result is bounded by {!Playbook.script_max_bytes} and
   validated against its [returns] before anyone sees it. *)
let script_failed message = error "script-failed" message

let bounded_message text =
  let text = String.trim text in
  if String.length text <= 500 then text else String.sub text 0 500 ^ "..."

(* The exception a script threw, as its author wants to read it: the description a
   thrown [Error] carries (name, message, stack head), else the plain text. *)
let thrown reply =
  let details = nested [ "exceptionDetails" ] (fun x -> Ok x) reply in
  Option.map
    (fun details ->
      match nested [ "exception"; "description" ] D.string details with
      | Some description -> description
      | None ->
          Option.value ~default:"the script threw" (nested [ "text" ] D.string details))
    details

let call_script browser ~object_id ~body ~arguments =
  match
    page_call browser "Runtime.callFunctionOn"
      (obj
         [
           ("objectId", str object_id);
           ("functionDeclaration", str body);
           ("arguments", `List arguments);
           ("returnByValue", `Bool true);
           ("awaitPromise", `Bool true);
         ])
  with
  | Error e when e.P.message = "browser refused Runtime.callFunctionOn" ->
      Error
        (script_failed
           "the browser refused the script or could not return its result by value")
  | Error e -> Error e
  | Ok reply -> (
      match thrown reply with
      | Some description -> Error (script_failed (bounded_message description))
      | None -> ( match remote_value reply with Some x -> Ok x | None -> Ok `Null))

type script_ran = { value : Yojson.Safe.t; records : int; bytes : int; elapsed_ms : int }

let script_args_cap = 65_536

let script browser (script : Playbook.script) ~args =
  let arguments = `Assoc (List.map (fun (name, value) -> (name, `String value)) args) in
  if String.length (Ox_json.to_string arguments) > script_args_cap then
    Error (too_large "script arguments")
  else
    let started = browser.now () in
    let* object_id = remote_object browser in
    let* value =
      evaluated ~call:call_script browser ~object_id
        ~body:("async function(args) {\n" ^ script.Playbook.code ^ "\n}")
        ~arguments:[ obj [ ("value", arguments) ] ]
    in
    let elapsed_ms = int_of_float ((browser.now () -. started) *. 1000.) in
    let bytes = String.length (Ox_json.to_string value) in
    if bytes > Playbook.script_max_bytes then
      Error
        (error "too-large"
           (Printf.sprintf "the script's result is %d bytes, over its bound of %d" bytes
              Playbook.script_max_bytes))
    else
      match Shape.validate script.Playbook.returns value with
      | Error why -> Error (error "script-invalid" why)
      | Ok () -> Ok { value; records = Shape.records value; bytes; elapsed_ms }

(* extr-lslp: a dry parse. The script's text is only ever handed to [new Function], as the
   text of the same async function [script] would call, in a blank page the caller owns:
   it is compiled and never called. A page with a CSP that forbids eval would refuse
   this, which is why the caller uses about:blank. Returns [None] when it parses and the
   engine's message when it does not. *)
let script_syntax browser (script : Playbook.script) =
  let expression =
    Printf.sprintf
      "(() => { try { new (Object.getPrototypeOf(async function () \
       {}).constructor)('args', %s); return null; } catch (e) { return String(e && \
       e.message ? e.message : e); } })()"
      (Yojson.Safe.to_string (`String script.Playbook.code))
  in
  let* value = evaluate browser expression in
  match value with
  | `Null -> Ok None
  | `String message -> Ok (Some (bounded_message message))
  | _ -> Error (internal "browser returned an unexpected syntax verdict")

let truncate_chars max_chars text =
  let length = String.length text in
  let rec advance offset count =
    if offset >= length || count > max_chars then (offset, count)
    else
      let next = ref (offset + 1) in
      while !next < length && Char.code text.[!next] land 0xc0 = 0x80 do
        incr next
      done;
      advance !next (count + 1)
  in
  let offset, count = advance 0 0 in
  if count <= max_chars then (text, false)
  else
    ( String.sub text 0
        (if max_chars = 0 then 0
         else
           let rec boundary pos remaining =
             if remaining = 0 then pos
             else
               let next = ref (pos + 1) in
               while !next < length && Char.code text.[!next] land 0xc0 = 0x80 do
                 incr next
               done;
               boundary !next (remaining - 1)
           in
           boundary 0 max_chars),
      true )

let text browser (args : P.text_args) =
  let* () = check_dialog browser in
  let max_chars = Option.value ~default:65_536 args.max_chars in
  if max_chars < 0 || max_chars > 65_536 then Error (invalid "max_chars must be 0..65536")
  else
    let* rendered =
      match args.index with
      | None ->
          evaluate browser
            (Printf.sprintf
               "Array.from(document.body?.innerText ?? '').slice(0,%d).join('')"
               (max_chars + 1))
      | Some index ->
          let* object_id = row_object browser index in
          call_function browser ~object_id
            ~body:
              "function(argument) { return Array.from(this.innerText ?? \
               '').slice(0,argument).join(''); }"
            ~argument:(`Int (max_chars + 1))
    in
    match rendered with
    | `String s ->
        let text, truncated = truncate_chars max_chars s in
        let url, title = browser.current () in
        Ok P.{ url; title; text; truncated }
    | _ -> Error (internal "browser returned non-text content")

let index_gone browser index =
  match browser.row index with
  | None -> Ok true
  | Some backend -> (
      match
        page_call browser "DOM.resolveNode" (obj [ ("backendNodeId", `Int backend) ])
      with
      | Error e when e.P.message = "browser refused DOM.resolveNode" -> Ok true
      | Error e -> Error e
      | Ok reply -> (
          match nested [ "object"; "objectId" ] D.string reply with
          | None -> Ok true
          | Some object_id -> (
              let* attached =
                call_function browser ~object_id
                  ~body:"function(argument) { return this.isConnected; }" ~argument:`Null
              in
              match attached with
              | `Bool is_connected -> Ok (not is_connected)
              | _ -> Error (internal "browser omitted node attachment state"))))

let page_contains browser needle =
  let expression =
    "Boolean(document.body && document.body.innerText.includes("
    ^ Yojson.Safe.to_string (`String needle)
    ^ "))"
  in
  let* value = evaluate browser expression in
  match value with
  | `Bool found -> Ok found
  | _ -> Error (invalid "browser did not return page text match")

let action_result browser tab =
  let url, title = browser.current () in
  P.
    {
      tab;
      url;
      title;
      snapshot = None;
      dialog = browser.dialog ();
      popups = [];
      hits = None;
      shots = None;
      via = None;
    }

(* hard-sr9v: a wait may last an hour. The control listener derives its handler budget from
   this same bound and cancels the handler when the client goes away, and a wait takes no
   lock of the tab's, so a long wait costs nobody else anything. *)
let max_wait_ms = 3_600_000

(* Polling is quick while a change is likely and slows for a long wait: an hour of
   fifty-millisecond probes would be wasteful, and a page that has not changed in half a
   minute is not about to change in the next fifty milliseconds. *)
let poll_interval elapsed =
  if elapsed < 2. then 0.05 else if elapsed < 30. then 0.25 else 0.5

(* hard-sckn: the page has changed since the snapshot when its main frame has another
   loader, or its mutation guard another epoch or count. A document that carries no guard
   was not the snapshot's. *)
let changed_since browser snapshot =
  match browser.baseline snapshot with
  | None -> Error (stale browser)
  | Some baseline ->
      Ok
        (fun () ->
          let* current = browser.probe () in
          Ok (current.loader <> baseline.loader || current.guard <> baseline.guard))

let wait browser (args : P.wait_args) =
  let timeout_ms = Option.value ~default:30_000 args.timeout_ms in
  if timeout_ms < 0 || timeout_ms > max_wait_ms then
    Error (invalid (Printf.sprintf "timeout_ms must be 0..%d" max_wait_ms))
  else
    let until = args.until in
    let started = browser.now () in
    let deadline = started +. (float timeout_ms /. 1000.) in
    let* changed =
      match until.changed_since with
      | None -> Ok (fun () -> Ok true)
      | Some snapshot -> changed_since browser snapshot
    in
    let rec loop () =
      let url, _ = browser.current () in
      let url_ok =
        Option.fold ~none:true
          ~some:(fun prefix -> String.starts_with ~prefix url)
          until.url_prefix
      in
      let dialog_ok =
        Option.fold ~none:true
          ~some:(fun wanted -> browser.dialog () <> None = wanted)
          until.dialog
      in
      let* changed_ok =
        if (not url_ok) || not dialog_ok then Ok false
        else if browser.dialog () <> None then Ok false
        else changed ()
      in
      let* text_ok =
        if (not url_ok) || (not dialog_ok) || not changed_ok then Ok false
        else
          match until.text with
          | None -> Ok true
          | Some needle ->
              if browser.dialog () <> None then Ok false else page_contains browser needle
      in
      let* gone_ok =
        if (not url_ok) || (not dialog_ok) || not text_ok then Ok false
        else
          match until.index_gone with
          | None -> Ok true
          | Some index when browser.dialog () <> None -> Ok false
          | Some index -> index_gone browser index
      in
      if url_ok && changed_ok && text_ok && gone_ok && dialog_ok then
        Ok (action_result browser args.tab)
      else if browser.now () >= deadline then
        Error (error "timeout" "wait conditions did not hold before timeout")
      else (
        browser.sleep
          (min (poll_interval (browser.now () -. started)) (deadline -. browser.now ()));
        loop ())
    in
    match Dialog_race.first browser.dialog_race loop with
    | `Value result -> result
    | `Dialog dialog ->
        Error
          {
            (error "dialog-open" "a dialog opened during wait; answer it first") with
            P.detail = Some (P.yojson_of_dialog dialog);
          }

let dialog browser (args : P.dialog_args) =
  if browser.dialog () = None then Error (no_dialog ())
  else
    let* _ =
      browser.call "Page.handleJavaScriptDialog"
        (obj
           ([ ("accept", `Bool (P.Answer.to_string args.answer = "accept")) ]
           @ match args.text with None -> [] | Some text -> [ ("promptText", str text) ]))
    in
    Ok P.{ (action_result browser args.tab) with dialog = None }

(* CDP delivers PNG bytes as base64. Decode in one allocation after checking the encoded
   length: a 20 MiB PNG cannot be confused with a short JSON result. *)
let max_png = 20 * 1024 * 1024

let digit = function
  | 'A' .. 'Z' as c -> Char.code c - 65
  | 'a' .. 'z' as c -> Char.code c - 71
  | '0' .. '9' as c -> Char.code c + 4
  | '+' -> 62
  | '/' -> 63
  | _ -> -1

let decode_png encoded =
  let n = String.length encoded in
  let pad = if n > 0 && encoded.[n - 1] = '=' then 1 else 0 in
  let pad = if n > 1 && encoded.[n - 2] = '=' then pad + 1 else pad in
  if n mod 4 <> 0 || (n / 4 * 3) - pad > max_png then Error (too_large "screenshot")
  else
    let length = (n / 4 * 3) - pad in
    let bytes = Bytes.create length in
    let rec decode i j =
      if i = n then Ok bytes
      else
        let c k = if encoded.[i + k] = '=' then 0 else digit encoded.[i + k] in
        let a, b, c2, d = (c 0, c 1, c 2, c 3) in
        if a < 0 || b < 0 || c2 < 0 || d < 0 then
          Error (internal "browser returned invalid screenshot")
        else
          let v = (a lsl 18) lor (b lsl 12) lor (c2 lsl 6) lor d in
          Bytes.set bytes j (Char.chr ((v lsr 16) land 255));
          if j + 1 < length then Bytes.set bytes (j + 1) (Char.chr ((v lsr 8) land 255));
          if j + 2 < length then Bytes.set bytes (j + 2) (Char.chr (v land 255));
          decode (i + 4) (j + 3)
    in
    decode 0 0

(* pic-ncu1: use actual PNG dimensions and CSS layout metrics, not an assumed DPR. *)
let png_size png =
  if
    Bytes.length png < 24
    || Bytes.sub_string png 0 8 <> "\137PNG\r\n\026\n"
    || Bytes.sub_string png 12 4 <> "IHDR"
  then Error (internal "browser returned a PNG without image dimensions")
  else
    let dimension offset =
      let n = ref 0 in
      for i = offset to offset + 3 do
        n := (!n lsl 8) lor Char.code (Bytes.get png i)
      done;
      !n
    in
    let width = dimension 16 and height = dimension 20 in
    if width <= 0 || height <= 0 then
      Error (internal "browser returned empty PNG dimensions")
    else Ok (width, height)

let shot ~caps browser (args : P.shot_args) =
  if Filename.is_relative args.path then
    Error (invalid "screenshot path must be absolute")
  else
    let* () = check_dialog browser in
    let full_page = Option.value ~default:false args.full_page in
    let* metrics = browser.call "Page.getLayoutMetrics" (obj []) in
    let* viewport =
      match
        ( nested [ "cssLayoutViewport"; "clientWidth" ] D.float metrics,
          nested [ "cssLayoutViewport"; "clientHeight" ] D.float metrics )
      with
      | Some width, Some height when width > 0. && height > 0. ->
          Ok (P.{ width; height } : P.viewport)
      | _ -> Error (internal "browser omitted CSS viewport dimensions")
    in
    let* capture_width =
      if not full_page then Ok viewport.width
      else
        match nested [ "cssContentSize"; "width" ] D.float metrics with
        | Some width when width > 0. -> Ok width
        | _ -> Error (internal "browser omitted CSS full-page dimensions")
    in
    let* reply = browser.capture ~full_page in
    match field "data" D.string reply with
    | None -> Error (internal "browser omitted screenshot")
    | Some encoded -> (
        let* png = decode_png encoded in
        let* width, height = png_size png in
        try
          let output = Ox_caps.Cap_stdlib.open_out_bin ~caps args.path in
          Fun.protect
            ~finally:(fun () -> close_out output)
            (fun () -> output_bytes output png);
          Ok
            P.
              {
                path = args.path;
                bytes = Bytes.length png;
                width;
                height;
                viewport;
                scale = float_of_int width /. capture_width;
                full_page;
              }
        with Sys_error _ -> Error (invalid "screenshot path is not writable"))

type t = {
  entries : P.debug_entry option array;
  mutable next : int;
  mutable length : int;
  net : Net_log.t;
  mutable challenge_signal : string option;
}

let create () =
  {
    entries = Array.make 200 None;
    next = 0;
    length = 0;
    net = Net_log.create ();
    challenge_signal = None;
  }

let challenge_signal t = t.challenge_signal

let push t entry =
  t.entries.(t.next) <- Some entry;
  t.next <- (t.next + 1) mod 200;
  t.length <- min 200 (t.length + 1)

let timestamp at =
  let tm = Unix.gmtime at in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.Unix.tm_year + 1900)
    (tm.Unix.tm_mon + 1) tm.Unix.tm_mday tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

(* field-vji1: match known hosts, not arbitrary URLs containing a vendor's name. *)
let challenge url =
  let url = String.lowercase_ascii url in
  match Snapshot_source.url_origin url with
  | None -> None
  | Some origin ->
      let host =
        match String.index_opt origin ':' with
        | None -> origin
        | Some at -> String.sub origin (at + 3) (String.length origin - at - 3)
      in
      let domain root = host = root || String.ends_with ~suffix:("." ^ root) host in
      if host = "challenges.cloudflare.com" then Some ("Turnstile", origin)
      else if domain "hcaptcha.com" then Some ("hCaptcha", origin)
      else if
        domain "recaptcha.net"
        || (domain "google.com" && String.starts_with ~prefix:(origin ^ "/recaptcha/") url)
      then Some ("reCAPTCHA", origin)
      else None

let observe t ~at json =
  Net_log.observe t.net json;
  let method_ = field "method" D.string json in
  let params = field "params" (fun x -> Ok x) json in
  let emit kind ?level text =
    let kind = enum P.Debug_kind.of_string kind in
    push t P.{ at = timestamp at; kind; level; text }
  in
  match (method_, params) with
  | Some "Runtime.consoleAPICalled", Some params ->
      let level = field "type" D.string params in
      let args =
        Option.value ~default:[] (field "args" (D.list (fun x -> Ok x)) params)
      in
      let texts =
        List.filter_map
          (fun arg ->
            match field "value" (fun x -> Ok x) arg with
            | Some (`String s) -> Some s
            | Some value -> Some (Ox_json.to_string value)
            | None -> field "description" D.string arg)
          args
      in
      emit "console" ?level (String.concat " " texts)
  | Some "Runtime.exceptionThrown", Some params ->
      let text =
        Option.value ~default:"uncaught exception"
          (match
             nested [ "exceptionDetails"; "exception"; "description" ] D.string params
           with
          | Some _ as description -> description
          | None -> nested [ "exceptionDetails"; "text" ] D.string params)
      in
      emit "exception" text
  | Some "Network.requestWillBeSent", Some params -> (
      match Option.bind (nested [ "request"; "url" ] D.string params) challenge with
      | Some (vendor, origin) ->
          t.challenge_signal <- Some origin;
          emit "console" ~level:"warn" (vendor ^ " challenge loaded: " ^ origin)
      | None -> ())
  | Some "Page.frameNavigated", Some params -> (
      (* notif-tdtz: debug history is not current challenge state. Navigation clears
         an old document's signal; unrelated DOM mutations cannot prove clearance. *)
      if nested [ "frame"; "parentId" ] D.string params = None then
        t.challenge_signal <- None;
      match Option.bind (nested [ "frame"; "url" ] D.string params) challenge with
      | Some (vendor, origin) ->
          t.challenge_signal <- Some origin;
          emit "console" ~level:"warn" (vendor ^ " challenge frame loaded: " ^ origin)
      | None -> ())
  | Some "Network.loadingFailed", Some params ->
      let text =
        Option.value ~default:"request failed" (field "errorText" D.string params)
      in
      emit "request-failed" text
  | Some "Network.responseReceived", Some params -> (
      let status = nested [ "response"; "status" ] D.float params in
      match status with
      | Some code when code >= 400. ->
          let url =
            Option.value ~default:"" (nested [ "response"; "url" ] D.string params)
          in
          emit "request-failed" (Printf.sprintf "HTTP %.0f %s" code url)
      | _ -> ())
  | _ -> ()

let debug t (args : P.debug_args) =
  let limit = Option.value ~default:200 args.limit in
  if limit < 0 || limit > 200 then Error (invalid "debug limit must be 0..200")
  else
    let rec collect n acc =
      if n >= min limit t.length then acc
      else
        let i = (t.next - 1 - n + 200) mod 200 in
        match t.entries.(i) with
        | Some entry -> collect (n + 1) (entry :: acc)
        | None -> assert false
    in
    let entries = List.rev (collect 0 []) in
    if Option.value ~default:false args.clear then (
      t.length <- 0;
      t.next <- 0;
      Array.fill t.entries 0 200 None);
    Ok P.{ entries }

(* ---------- hard-xg6y hard-ovbx hard-vq5s: the tab's request ring ---------- *)

let net t args = Net_log.list t.net args

let unknown_request () =
  error "unknown-request" "the tab's request ring has no such request"

let body_unavailable why = error "body-unavailable" why
let refused meth (e : P.error) = e.P.message = "browser refused " ^ meth

(* A body or post data over 1 MiB is cut there, on a character boundary for text and on a
   four-character group for base64 (1 MiB is one); the reply says it was cut. *)
let body_cap = 1_048_576

let string_member key json =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt key fields with Some (`String s) -> s | _ -> "")
  | _ -> ""

let bool_member key json =
  match json with
  | `Assoc fields -> List.assoc_opt key fields = Some (`Bool true)
  | _ -> false

let net_body browser t (args : P.net_entry_args) =
  match Net_log.find t.net args.id with
  | None -> Error (unknown_request ())
  | Some request when not request.has_body ->
      Error (body_unavailable "that request has no response body to read")
  | Some request -> (
      match
        page_call browser "Network.getResponseBody"
          (obj [ ("requestId", str request.chrome_id) ])
      with
      | Error e when refused "Network.getResponseBody" e ->
          Error (body_unavailable "Chrome no longer holds that response body")
      | Error e -> Error e
      | Ok reply ->
          let body, truncated = Net_log.clip body_cap (string_member "body" reply) in
          Ok
            P.
              {
                id = request.id;
                body;
                base64 = bool_member "base64Encoded" reply;
                bytes = String.length body;
                truncated;
              })

let net_request browser t (args : P.net_entry_args) =
  match Net_log.find t.net args.id with
  | None -> Error (unknown_request ())
  | Some request ->
      let* post_data, base64, truncated =
        if not request.has_post_data then Ok (None, false, false)
        else
          match
            page_call browser "Network.getRequestPostData"
              (obj [ ("requestId", str request.chrome_id) ])
          with
          | Error e when refused "Network.getRequestPostData" e ->
              Error (body_unavailable "Chrome no longer holds that request's post data")
          | Error e -> Error e
          | Ok reply ->
              let data, truncated =
                Net_log.clip body_cap (string_member "postData" reply)
              in
              Ok (Some data, bool_member "base64Encoded" reply, truncated)
      in
      Ok
        P.
          {
            id = request.id;
            method_ = request.method_;
            url = request.url;
            headers =
              `Assoc (List.map (fun (name, value) -> (name, str value)) request.headers);
            post_data;
            base64;
            truncated;
          }

(* ---------- hard-ufb7: cookies and storage, read-only ---------- *)

let cookies browser =
  let url, _ = browser.current () in
  let* reply =
    page_call browser "Network.getCookies" (obj [ ("urls", `List [ str url ]) ])
  in
  let cookie json =
    let text key = string_member key json in
    let expires =
      match json with
      | `Assoc fields when List.assoc_opt "session" fields <> Some (`Bool true) -> (
          match List.assoc_opt "expires" fields with
          | Some (`Int n) when n >= 0 -> Some (float_of_int n)
          | Some (`Float x) when x >= 0. -> Some x
          | _ -> None)
      | _ -> None
    in
    P.
      {
        name = text "name";
        value = text "value";
        domain = text "domain";
        path = text "path";
        expires;
        http_only = bool_member "httpOnly" json;
        secure = bool_member "secure" json;
        same_site = (match text "sameSite" with "" -> None | site -> Some site);
      }
  in
  match field "cookies" (fun x -> Ok x) reply with
  | Some (`List cookies) -> Ok P.{ cookies = List.map cookie cookies }
  | _ -> Error (internal "browser omitted cookies")

let http_origin origin =
  String.starts_with ~prefix:"http://" origin
  || String.starts_with ~prefix:"https://" origin

(* The origin DOMStorage names its storage by is the page's security origin, which the
   frame tree reports; an opaque origin (about:blank) has no storage to read. *)
let storage_origin browser =
  let* tree = page_call browser "Page.getFrameTree" (obj []) in
  match nested [ "frameTree"; "frame"; "securityOrigin" ] D.string tree with
  | Some origin when http_origin origin -> Ok origin
  | _ -> Error (invalid "this page has no web storage origin")

let max_storage_items = 1000
let max_storage_bytes = 1_048_576

let storage browser (args : P.storage_args) =
  let* origin = storage_origin browser in
  let local = P.Storage_area.to_string args.area = "local" in
  let* _ = page_call browser "DOMStorage.enable" (obj []) in
  let read =
    page_call browser "DOMStorage.getDOMStorageItems"
      (obj
         [
           ( "storageId",
             obj [ ("securityOrigin", str origin); ("isLocalStorage", `Bool local) ] );
         ])
  in
  (* Best effort: the domain only reports changes, which nobody here wants. *)
  ignore (page_call browser "DOMStorage.disable" (obj []));
  let* reply = read in
  match field "entries" (fun x -> Ok x) reply with
  | Some (`List entries) ->
      let pairs =
        List.filter_map
          (function
            | `List [ `String key; `String value ] -> Some (key, value) | _ -> None)
          entries
      in
      let rec take count bytes = function
        | [] -> ([], false)
        | (key, value) :: rest ->
            let bytes = bytes + String.length key + String.length value in
            if count >= max_storage_items || bytes > max_storage_bytes then ([], true)
            else
              let kept, truncated = take (count + 1) bytes rest in
              ((key, value) :: kept, truncated)
      in
      let kept, truncated = take 0 0 pairs in
      Ok
        P.
          {
            origin;
            area = args.area;
            items = `Assoc (List.map (fun (key, value) -> (key, str value)) kept);
            truncated;
          }
  | _ -> Error (internal "browser omitted storage entries")
