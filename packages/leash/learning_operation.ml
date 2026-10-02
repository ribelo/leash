(* map-op01 map-op03: durable page-shape evidence, not whole missions. *)
module B = Playbook

type t = {
  entry_kind : string;
  exit_kind : string;
  entry : Trace.trace_page;
  exit : Trace.trace_page;
  steps : Trace.trace_step list;
  arguments : (int * string list) list;
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
          description = p.name;
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

let signature operation =
  List.map (fun (s : Trace.trace_step) -> (s.operation, s.target)) operation.steps

let agrees a b = a.entry_kind = b.entry_kind && signature a = signature b

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
