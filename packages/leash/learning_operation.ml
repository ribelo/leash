(* map-op01 map-op03: durable page-shape evidence, not whole missions. *)
module B = Playbook

type t = {
  entry_kind : string;
  exit_kind : string;
  entry : Trace.trace_page;
  exit : Trace.trace_page;
  steps : Trace.trace_step list;
  arguments : (int * string list) list;
  values : string list;
  repeatable : bool;
}

let steps (trace : Trace.t) =
  if trace.steps <> [] then trace.steps
  else List.concat_map (fun (p : Trace.trace_procedure) -> p.steps) trace.procedures

let pages (trace : Trace.t) =
  List.map
    (fun (p : Trace.inferred_page) ->
      B.
        {
          name = p.name;
          url_pattern = Some (Page_kind.playbook_pattern p.url_pattern);
          text_marker = None;
          repeatable = true;
        })
    trace.inferred_pages
  |> List.sort (fun (a : B.page) (b : B.page) ->
      compare
        (String.length (Option.value ~default:"" b.url_pattern))
        (String.length (Option.value ~default:"" a.url_pattern)))

let host url =
  match String.split_on_char '/' url with
  | _ :: "" :: authority :: _ -> Some (String.lowercase_ascii authority)
  | _ -> None

let kind ?(declared = []) trace page =
  match B.page_kind (pages trace @ declared) ~url:page.Trace.url ~text:page.title with
  | Some kind -> kind
  | None -> (Page_kind.infer ~url:page.url ~title:page.title).name

let interstitial ~mapping ~declared trace page =
  let key = kind ~declared trace page in
  key = "consent"
  || List.assoc_opt key mapping = Some "consent"
  ||
  match trace.Trace.final with
  | Some final -> host page.Trace.url <> host final.url
  | None -> true

let segment ?(mapping = []) ?(declared = []) (trace : Trace.t) =
  if trace.outcome <> "done" then []
  else
    let kind = kind ~declared in
    let all = steps trace in
    let start =
      match trace.start_url with
      | Some url -> Some Trace.{ url; title = "" }
      | None -> ( match all with [] -> None | s :: _ -> Some s.Trace.after)
    in
    let make entry exit rev_steps =
      let steps = List.rev rev_steps in
      let arguments =
        List.filter_map
          (fun (s : Trace.trace_step) ->
            match s.text with
            | None -> None
            | Some text ->
                let names =
                  List.filter_map
                    (fun (name, value) -> if value = text then Some name else None)
                    trace.arguments
                in
                if names = [] then None else Some (s.n, names))
          steps
      in
      {
        entry_kind = kind trace entry;
        exit_kind = kind trace exit;
        entry;
        exit;
        steps;
        arguments;
        values =
          List.map snd trace.arguments
          @ List.filter_map (fun (s : Trace.trace_step) -> s.text) steps;
        repeatable =
          (not
             (List.exists
                (fun (p : B.page) ->
                  (not p.repeatable)
                  && List.mem p.name [ kind trace entry; kind trace exit ])
                declared))
          && (not (List.exists (fun (s : Trace.trace_step) -> s.non_repeatable) steps))
          && not
               (B.non_repeatable_context
                  (String.concat " "
                     (List.concat_map
                        (fun (s : Trace.trace_step) ->
                          (s.after.title :: Option.to_list s.text)
                          @ Option.fold ~none:[]
                              ~some:(fun (t : Trace.trace_target) -> [ t.label ])
                              s.target)
                        steps))
               && List.exists
                    (fun (s : Trace.trace_step) ->
                      List.mem s.operation
                        [ "submit"; "press"; "click"; "upload"; "select"; "type_text" ])
                    steps);
      }
    in
    let flush entry exit pending acc =
      match pending with
      | [] -> acc
      | _ when interstitial ~mapping ~declared trace entry -> acc
      | _ -> make entry exit pending :: acc
    in
    match start with
    | None -> []
    | Some start ->
        let rec loop entry before pending acc = function
          | [] ->
              let exit = Option.value ~default:before trace.final in
              List.rev (flush entry exit pending acc)
          | (s : Trace.trace_step) :: rest ->
              if s.operation = "done" then
                (* DONE is a result observation, not an action to replay. It can be
                 the first settled observation of a delayed navigation. *)
                loop entry s.after pending acc rest
              else
                let pending = s :: pending in
                if kind trace before <> kind trace s.after then
                  let acc = flush entry s.after pending acc in
                  loop s.after s.after [] acc rest
                else loop entry s.after pending acc rest
        in
        loop start start [] [] all

let first_entry ?(mapping = []) ?(declared = []) trace =
  let candidates =
    Option.to_list
      (Option.map (fun url -> Trace.{ url; title = "" }) trace.Trace.start_url)
    @ List.map (fun (s : Trace.trace_step) -> s.after) (steps trace)
  in
  Option.map
    (fun page -> page.Trace.url)
    (List.find_opt
       (fun page -> not (interstitial ~mapping ~declared trace page))
       candidates)

(* map-op03: labels remain useful compiler evidence, but replay is the correctness
   gate for repeatable operations. Aliases and defaults may differ across forms. *)
let normalize_label values label =
  let label = String.lowercase_ascii label in
  let values =
    List.filter (( <> ) "") values
    |> List.sort (fun a b -> compare (String.length b) (String.length a))
  in
  let label =
    List.fold_left
      (fun label value ->
        Str.global_replace
          (Str.regexp_string (String.lowercase_ascii value))
          "{value}" label)
      label values
  in
  let label =
    Str.global_replace (Str.regexp "[0-9]+\\([.,:/-][0-9]+\\)*") "{number}" label
  in
  let label =
    Str.global_replace
      (Str.regexp
         "\\b\\(monday\\|tuesday\\|wednesday\\|thursday\\|friday\\|saturday\\|sunday\\|january\\|february\\|march\\|april\\|may\\|june\\|july\\|august\\|september\\|october\\|november\\|december\\)\\b")
      "{date}" label
  in
  let label =
    Str.global_replace
      (Str.regexp
         "\\b\\(polish \
          zlotys\\|zlotys\\|pln\\|usd\\|eur\\|gbp\\|dollars\\|euros\\|pounds\\)\\b\\|[$£€]")
      "{currency}" label
  in
  Str.global_replace (Str.regexp "[ \t\r\n]+") " " label |> String.trim

let strict_signature operation =
  List.map (fun (s : Trace.trace_step) -> (s.operation, s.target)) operation.steps

let signature operation =
  if not operation.repeatable then strict_signature operation
  else
    List.map
      (fun (s : Trace.trace_step) ->
        ( s.operation,
          Option.map
            (fun (target : Trace.trace_target) ->
              { target with label = normalize_label operation.values target.label })
            s.target ))
      operation.steps
    |> List.sort_uniq compare

let roles signature =
  List.map
    (fun (op, target) -> (op, Option.map (fun (t : Trace.trace_target) -> t.role) target))
    signature
  |> List.sort_uniq compare

let compatible a b =
  let a = roles a and b = roles b in
  let subset small large =
    List.for_all (fun item -> List.mem item large) small
    && List.for_all
         (fun ((operation, _) as item) ->
           (not (List.mem operation [ "type_text"; "select" ])) || List.mem item small)
         large
  in
  subset a b || subset b a

let agrees a b =
  a.entry_kind = b.entry_kind
  &&
  if a.repeatable && b.repeatable then
    a.exit_kind = b.exit_kind && compatible (signature a) (signature b)
  else strict_signature a = strict_signature b

let project (trace : Trace.t) operation =
  {
    trace with
    start_url = Some operation.entry.url;
    page_kind_path =
      (if operation.entry_kind = operation.exit_kind then [ operation.entry_kind ]
       else [ operation.entry_kind; operation.exit_kind ]);
    inferred_pages =
      List.filter
        (fun (p : Trace.inferred_page) ->
          p.name = operation.entry_kind || p.name = operation.exit_kind)
        trace.inferred_pages;
    steps = operation.steps;
    procedures = [];
    final = Some operation.exit;
  }
