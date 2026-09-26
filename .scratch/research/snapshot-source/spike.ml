(* Throwaway L4 measurement. Run only explicitly; Chrome is always headless. *)
module Chrome = Leash.Chrome
module Cdp = Leash.Cdp

let fail fmt = Printf.ksprintf failwith fmt
let field key = function `Assoc xs -> List.assoc_opt key xs | _ -> None
let string = function Some (`String s) -> s | _ -> ""
let list = function Some (`List xs) -> xs | _ -> []
let obj xs = `Assoc xs
let str s = `String s
let read path = In_channel.with_open_bin path In_channel.input_all
let trim = String.trim

let normalize s =
  String.split_on_char ' '
    (String.map (fun c -> if c = '\n' || c = '\t' then ' ' else c) s)
  |> List.filter (( <> ) "")
  |> String.concat " "

let js =
  {|(() => {
  const viewport = e => {
    const cs = getComputedStyle(e), r = e.getBoundingClientRect();
    return cs.display !== 'none' && cs.visibility !== 'hidden' && !e.hidden &&
      !e.closest('[hidden],[aria-hidden="true"]') &&
      !(e.closest('details:not([open])') && e.tagName !== 'SUMMARY') && r.width > 0 && r.height > 0 &&
      r.bottom > 0 && r.right > 0 && r.top < innerHeight && r.left < innerWidth;
  };
  const name = e => {
    const refs = e.getAttribute('aria-labelledby');
    if (refs) { const text = refs.split(/\s+/).map(id => document.getElementById(id)?.textContent || '').join(' ').trim(); if (text) return text; }
    const aria = e.getAttribute('aria-label'); if (aria) return aria;
    if (e.labels?.length) return Array.from(e.labels, l => l.textContent).join(' ').trim();
    return (e.getAttribute('alt') || e.textContent || e.getAttribute('title') || e.getAttribute('placeholder') || '').trim();
  };
  const role = e => {
    const explicit = e.getAttribute('role'); if (explicit) return explicit;
    const tag = e.tagName.toLowerCase();
    if (/^h[1-6]$/.test(tag)) return 'heading';
    if (tag === 'p') return 'paragraph';
    if (tag === 'a') return e.hasAttribute('href') ? 'link' : '';
    if (tag === 'button' || tag === 'summary') return 'button';
    if (tag === 'select') return 'combobox';
    if (tag === 'textarea') return 'textbox';
    if (tag === 'input') { const t = e.type; return t === 'checkbox' || t === 'radio' ? t : t === 'button' || t === 'submit' ? 'button' : 'textbox'; }
    return '';
  };
  return Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6,p,a,button,summary,input,select,textarea,[role]'))
    .filter(viewport).map(e => ({role:role(e), name:name(e), id:e.id || ''}))
    .filter(row => row.role && row.name);
})()|}

let quote_data html =
  let b = Buffer.create (String.length html * 3) in
  String.iter
    (fun c ->
      let n = Char.code c in
      if
        (n >= 65 && n <= 90)
        || (n >= 97 && n <= 122)
        || (n >= 48 && n <= 57)
        || String.contains "-_.~" c
      then Buffer.add_char b c
      else Buffer.add_string b (Printf.sprintf "%%%02X" n))
    html;
  "data:text/html;charset=utf-8," ^ Buffer.contents b

let call c ?session method_ params =
  match Cdp.call c ?session ~deadline:(Eta.Duration.seconds 20) method_ params with
  | Error _ -> fail "CDP %s failed (transport/deadline)" method_
  | Ok reply -> (
      match Cdp.error_of_reply reply with
      | Some (n, msg) -> fail "CDP %s: %d %s" method_ n msg
      | None -> Option.value ~default:(obj []) (Cdp.result reply))

let result_of_eval reply =
  match field "exceptionDetails" reply with
  | Some e -> fail "JS exception: %s" (Yojson.Safe.to_string e)
  | None -> (
      ();
      match field "value" (Option.value ~default:`Null (field "result" reply)) with
      | Some x -> x
      | None -> fail "Runtime.evaluate had no by-value result")

let evaluate c session expression =
  call c ~session "Runtime.evaluate"
    (obj
       [
         ("expression", str expression);
         ("returnByValue", `Bool true);
         ("awaitPromise", `Bool true);
       ])
  |> result_of_eval

let pair row = (string (field "role" row), normalize (string (field "name" row)))

let rows_of_ax tree =
  let nodes = list (field "nodes" tree) in
  let by_id = Hashtbl.create 128 in
  List.iter (fun n -> Hashtbl.replace by_id (string (field "nodeId" n)) n) nodes;
  let role n = string (field "value" (Option.value ~default:`Null (field "role" n))) in
  let name n = string (field "value" (Option.value ~default:`Null (field "name" n))) in
  let parent n =
    Option.bind (field "parentId" n) (fun x -> Hashtbl.find_opt by_id (string (Some x)))
  in
  let convert n =
    let r = role n in
    let r =
      if r = "StaticText" then
        match parent n with Some p when role p = "paragraph" -> "paragraph" | _ -> ""
      else if r = "DisclosureTriangle" then "button"
      else r
    in
    if
      List.mem r
        [
          "heading";
          "paragraph";
          "link";
          "button";
          "textbox";
          "checkbox";
          "radio";
          "combobox";
        ]
      && name n <> ""
      && field "ignored" n <> Some (`Bool true)
    then
      Some
        (obj
           [
             ("role", str r);
             ("name", str (name n));
             ( "backendDOMNodeId",
               Option.value ~default:`Null
                 (field "backendDOMNodeId"
                    (if role n = "StaticText" then Option.value ~default:n (parent n)
                     else n)) );
           ])
    else None
  in
  let visited = Hashtbl.create 128 in
  let rec walk n =
    let id = string (field "nodeId" n) in
    if Hashtbl.mem visited id then []
    else begin
      Hashtbl.add visited id ();
      let here = match convert n with None -> [] | Some row -> [ row ] in
      let children =
        list (field "childIds" n)
        |> List.filter_map (fun id -> Hashtbl.find_opt by_id (string (Some id)))
      in
      here @ List.concat_map walk children
    end
  in
  match nodes with root :: _ -> walk root | [] -> []

let integer = function `Int n -> n | _ -> -1
let float = function `Float x -> x | `Int x -> float_of_int x | _ -> 0.

(* DOMSnapshot layout indices address nodes.backendNodeId; AX rows carry those ids.
   Text from a paragraph is attributed to the parent paragraph element. *)
let visible_ids snapshot ~width ~height =
  let ids = Hashtbl.create 128 in
  let document =
    match list (field "documents" snapshot) with
    | d :: _ -> d
    | [] -> fail "no DOMSnapshot document"
  in
  let nodes = Option.value ~default:`Null (field "nodes" document) in
  let backends = Array.of_list (list (field "backendNodeId" nodes)) in
  let layout = Option.value ~default:`Null (field "layout" document) in
  let indices = list (field "nodeIndex" layout) in
  let bounds = list (field "bounds" layout) in
  List.iter2
    (fun index rect ->
      let i = integer index in
      if i >= 0 && i < Array.length backends then
        match rect with
        | `List [ x; y; w; h ]
          when float w > 0.
               && float h > 0.
               && float x +. float w > 0.
               && float y +. float h > 0.
               && float x < width
               && float y < height ->
            Hashtbl.replace ids (integer backends.(i)) ()
        | _ -> ())
    indices bounds;
  ids

let score expected actual =
  let remaining = ref expected in
  let matches =
    List.fold_left
      (fun count row ->
        let key = pair row in
        if List.mem key !remaining then (
          let rec remove = function
            | [] -> []
            | x :: xs when x = key -> xs
            | x :: xs -> x :: remove xs
          in
          remaining := remove !remaining;
          count + 1)
        else count)
      0 actual
  in
  (matches, List.length !remaining)

let elapsed f =
  let start = Unix.gettimeofday () in
  let x = f () in
  (x, (Unix.gettimeofday () -. start) *. 1000.)

let files = [ "form"; "aria"; "navigation"; "select"; "state" ]

let run env ~binary ~profile =
  let clock = Eio.Stdenv.clock env in
  let logger =
    Eta_observability.Logger.create ~service:"snapshot-spike" ~clock
      ~mono_clock:(Eio.Stdenv.mono_clock env)
      ~reporter:(Eta_observability.Logger.Reporter.journal (Eio.Stdenv.stderr env))
      ()
  in
  let config =
    Chrome.make ~binary ~profile_dir:profile ~workspace:"dev" ~headless:true ()
  in
  if not (List.mem "--headless=new" (Chrome.argv config)) then
    fail "headless flag missing";
  let labels = Yojson.Safe.from_file "labels.json" in
  Eio.Switch.run (fun sw ->
      let chrome =
        Chrome.create ~sw config
          { Chrome.clock; mgr = Eio.Stdenv.process_mgr env; logger }
      in
      (match
         Eta.Timeout.timeout ~clock (Eta.Duration.seconds 30) (fun () ->
             Ok (Eio.Stream.take (Chrome.events chrome)))
       with
      | Ok (Chrome.Started _) -> ()
      | _ -> fail "Chrome failed to start");
      let c =
        match Chrome.connection chrome with
        | Ok c -> c
        | Error _ -> fail "connection unavailable"
      in
      let version = call c "Browser.getVersion" (obj []) |> field "product" |> string in
      let consistency = ref `Null in
      let output =
        List.map
          (fun page ->
            let html = read ("fixtures/" ^ page ^ ".html") in
            let target =
              call c "Target.createTarget" (obj [ ("url", str "about:blank") ])
              |> field "targetId" |> string
            in
            let session =
              call c "Target.attachToTarget"
                (obj [ ("targetId", str target); ("flatten", `Bool true) ])
              |> field "sessionId" |> string
            in
            ignore
              (call c ~session "Page.navigate" (obj [ ("url", str (quote_data html)) ]));
            let viewport =
              evaluate c session
                "new Promise(resolve => { if (document.readyState === 'complete') \
                 resolve(true); else addEventListener('load', () => resolve(true), \
                 {once:true}); }).then(() => [innerWidth, innerHeight])"
            in
            let width, height =
              match viewport with
              | `List [ w; h ] -> (float w, float h)
              | _ -> fail "invalid viewport"
            in
            let expected =
              list (field page labels)
              |> List.map (function
                | `List [ `String r; `String n ] -> (r, n)
                | _ -> fail "invalid labels")
            in
            let samples =
              List.init 15 (fun i ->
                  let order =
                    if i mod 2 = 0 then [ "dom"; "ax"; "ax+snapshot" ]
                    else [ "ax+snapshot"; "ax"; "dom" ]
                  in
                  List.map
                    (fun source ->
                      let rows, ms =
                        elapsed (fun () ->
                            if source = "dom" then list (Some (evaluate c session js))
                            else
                              let ax =
                                call c ~session "Accessibility.getFullAXTree" (obj [])
                                |> rows_of_ax
                              in
                              if source = "ax" then ax
                              else
                                let snapshot =
                                  call c ~session "DOMSnapshot.captureSnapshot"
                                    (obj
                                       [
                                         ( "computedStyles",
                                           `List [ str "display"; str "visibility" ] );
                                         ("includeDOMRects", `Bool true);
                                       ])
                                in
                                let visible = visible_ids snapshot ~width ~height in
                                List.filter
                                  (fun row ->
                                    Hashtbl.mem visible
                                      (integer
                                         (Option.value ~default:`Null
                                            (field "backendDOMNodeId" row))))
                                  ax)
                      in
                      let matches, missing = score expected rows in
                      Printf.printf "%s %s %02d %.3fms rows=%d matched=%d/%d\n%!" page
                        source (i + 1) ms (List.length rows) matches
                        (List.length expected);
                      ( source,
                        obj
                          [
                            ("page", str page);
                            ("source", str source);
                            ("iteration", `Int (i + 1));
                            ("latency_ms", `Float ms);
                            ("cdp_calls", `Int (if source = "ax+snapshot" then 2 else 1));
                            ("row_count", `Int (List.length rows));
                            ("correct_names", `Int matches);
                            ("missing_names", `Int missing);
                            ("expected_count", `Int (List.length expected));
                            ("rows", `List rows);
                          ] ))
                    order)
              |> List.concat |> List.map snd
            in
            if page = "state" then begin
              let before =
                evaluate c session
                  "window.__leashMutation=0; window.__leashObserver=new \
                   MutationObserver(() => window.__leashMutation++); \
                   window.__leashObserver.observe(document.documentElement,{subtree:true,childList:true,attributes:true,characterData:true}); \
                   window.__leashMutation"
              in
              ignore (call c ~session "Accessibility.getFullAXTree" (obj []));
              ignore
                (evaluate c session
                   "document.querySelector('h1').textContent += ' updated'; true");
              ignore
                (call c ~session "DOMSnapshot.captureSnapshot"
                   (obj [ ("computedStyles", `List []); ("includeDOMRects", `Bool true) ]));
              let after = evaluate c session "window.__leashMutation" in
              consistency :=
                obj
                  [
                    ("page", str page);
                    ("mutation_counter_before", before);
                    ("mutation_counter_after", after);
                    ("detected", `Bool (integer after > integer before));
                    ("probe_cdp_calls", `Int 5);
                  ]
            end;
            ignore (call c "Target.closeTarget" (obj [ ("targetId", str target) ]));
            samples)
          files
        |> List.concat
      in
      Chrome.stop chrome;
      let probe_file = open_out "consistency.json" in
      Fun.protect
        ~finally:(fun () -> close_out probe_file)
        (fun () ->
          Yojson.Safe.pretty_to_channel probe_file !consistency;
          output_char probe_file '\n');
      let metadata = open_out "environment.json" in
      Fun.protect
        ~finally:(fun () -> close_out metadata)
        (fun () ->
          Yojson.Safe.pretty_to_channel metadata
            (obj
               [
                 ("chrome", str version);
                 ("headless", `Bool true);
                 ("iterations_per_page_source", `Int 15);
               ]);
          output_char metadata '\n');
      let channel = open_out "measurements.json" in
      Fun.protect
        ~finally:(fun () -> close_out channel)
        (fun () ->
          Yojson.Safe.pretty_to_channel channel (`List output);
          output_char channel '\n'))

let () =
  let binary =
    match Sys.getenv_opt "CHROME_BINARY" with
    | Some x -> x
    | None -> "google-chrome-stable"
  in
  let profile =
    Filename.concat
      (Filename.get_temp_dir_name ())
      (Printf.sprintf "leash-spike-%d" (Unix.getpid ()))
  in
  Unix.mkdir profile 0o700;
  let status =
    try
      Eio_main.run (fun env -> run env ~binary ~profile);
      0
    with ex ->
      prerr_endline (Printexc.to_string ex);
      1
  in
  ignore (Unix.system ("rm -rf " ^ Filename.quote profile));
  exit status
