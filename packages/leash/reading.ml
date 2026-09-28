module P = Protocol
module D = Eta_json.Of_json

type browser = {
  call : string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result;
  now : unit -> float;
  sleep : float -> unit;
  current : unit -> string * string;
  dialog : unit -> Protocol.dialog option;
  dialog_race : Dialog_race.t;
  acknowledge : unit -> Dispatch.t;
  row : int -> int option;
}

let ( let* ) = Result.bind
let obj xs = `Assoc xs
let str x = `String x
let value decoder json = Result.to_option (decoder json)
let field name decoder json = value (D.field name decoder) json
let nested names decoder json = value (D.at names decoder) json
let enum decode text = match decode text with Ok v -> v | Error _ -> assert false

let error code message : P.error =
  { code = enum P.Error_code.of_string code; message; detail = None }

let too_large what = error "too-large" (what ^ " exceeds its size limit")
let invalid why = error "invalid-request" why
let internal why = error "internal" why
let remote_value json = nested [ "result"; "value" ] (fun x -> Ok x) json
let no_dialog () = error "no-dialog" "there is no open dialog"

let evaluate browser expression =
  let* reply =
    browser.call "Runtime.evaluate"
      (obj [ ("expression", str expression); ("returnByValue", `Bool true) ])
  in
  match remote_value reply with
  | Some x -> Ok x
  | None -> Error (internal "browser omitted evaluation value")

let remote_object browser =
  let* reply =
    browser.call "Runtime.evaluate" (obj [ ("expression", str "globalThis") ])
  in
  match nested [ "result"; "objectId" ] D.string reply with
  | Some id -> Ok id
  | None -> Error (internal "browser omitted global object")

let call_function browser ~object_id ~body ~argument =
  let* reply =
    browser.call "Runtime.callFunctionOn"
      (obj
         [
           ("objectId", str object_id);
           ("functionDeclaration", str body);
           ("arguments", `List [ obj [ ("value", argument) ] ]);
           ("returnByValue", `Bool true);
           ("awaitPromise", `Bool true);
         ])
  in
  if field "exceptionDetails" (fun x -> Ok x) reply <> None then
    Error (internal "page evaluation threw an exception")
  else
    match remote_value reply with
    | Some x -> Ok x
    | None when nested [ "result"; "type" ] D.string reply = Some "undefined" -> Ok `Null
    | None -> Error (internal "browser omitted function result")

(* tab-gjo0: the call that runs the caller's own function is the one Chrome withholds
   when the function opens a window -- an evaluated [window.open] is answered only once the
   popup is gone (docs/cdp-shapes.md, L10) -- so it settles the way a trusted input does: a
   new target with this tab as its opener ends the wait with a null value, and this tab's
   own death ends it with [tab-gone] (own-teh1). Nothing is re-issued. *)
let evaluated browser ~object_id ~body ~argument =
  match
    Dialog_race.first browser.dialog_race (fun () ->
        Dispatch.first (browser.acknowledge ()) (fun () ->
            call_function browser ~object_id ~body ~argument))
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

let eval browser (args : P.eval_args) =
  if String.length args.expression > cap then Error (too_large "expression")
  else
    let argument = Option.value ~default:`Null args.argument in
    if String.length (Eta_json.to_string argument) > cap then Error (too_large "argument")
    else
      let* object_id = remote_object browser in
      let* value =
        evaluated browser ~object_id
          ~body:("function(argument) {\n" ^ args.expression ^ "\n}")
          ~argument
      in
      if String.length (Eta_json.to_string value) > cap then Error (too_large "result")
      else Ok P.{ value }

let row_object browser index =
  match browser.row index with
  | None -> Error (error "no-such-row" "the snapshot has no such row")
  | Some backend -> (
      let* reply =
        browser.call "DOM.resolveNode" (obj [ ("backendNodeId", `Int backend) ])
      in
      match nested [ "object"; "objectId" ] D.string reply with
      | Some id -> Ok id
      | None -> Error (error "stale-snapshot" "the row no longer resolves"))

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
      match browser.call "DOM.resolveNode" (obj [ ("backendNodeId", `Int backend) ]) with
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
  P.{ tab; url; title; snapshot = None; dialog = browser.dialog (); popups = [] }

let wait browser (args : P.wait_args) =
  let timeout_ms = Option.value ~default:30_000 args.timeout_ms in
  if timeout_ms < 0 || timeout_ms > 30_000 then
    Error (invalid "timeout_ms must be 0..30000")
  else
    let until = args.until in
    let deadline = browser.now () +. (float timeout_ms /. 1000.) in
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
      let* text_ok =
        if (not url_ok) || not dialog_ok then Ok false
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
      if url_ok && text_ok && gone_ok && dialog_ok then
        Ok (action_result browser args.tab)
      else if browser.now () >= deadline then
        Error (error "timeout" "wait conditions did not hold before timeout")
      else (
        browser.sleep (min 0.05 (deadline -. browser.now ()));
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

let shot browser (args : P.shot_args) =
  if Filename.is_relative args.path then
    Error (invalid "screenshot path must be absolute")
  else
    let* reply =
      browser.call "Page.captureScreenshot"
        (obj
           [
             ("format", str "png");
             ("captureBeyondViewport", `Bool (Option.value ~default:false args.full_page));
           ])
    in
    match field "data" D.string reply with
    | None -> Error (internal "browser omitted screenshot")
    | Some encoded -> (
        let* png = decode_png encoded in
        if Bytes.length png < 8 || Bytes.sub_string png 0 8 <> "\137PNG\r\n\026\n" then
          Error (internal "browser returned non-PNG screenshot")
        else
          try
            let output = open_out_bin args.path in
            Fun.protect
              ~finally:(fun () -> close_out output)
              (fun () -> output_bytes output png);
            Ok P.{ path = args.path; bytes = Bytes.length png }
          with Sys_error _ -> Error (invalid "screenshot path is not writable"))

type t = {
  entries : P.debug_entry option array;
  mutable next : int;
  mutable length : int;
}

let create () = { entries = Array.make 200 None; next = 0; length = 0 }

let push t entry =
  t.entries.(t.next) <- Some entry;
  t.next <- (t.next + 1) mod 200;
  t.length <- min 200 (t.length + 1)

let timestamp at =
  let tm = Unix.gmtime at in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" (tm.Unix.tm_year + 1900)
    (tm.Unix.tm_mon + 1) tm.Unix.tm_mday tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec

let observe t ~at json =
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
            | Some value -> Some (Eta_json.to_string value)
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
