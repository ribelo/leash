(* map-op04: the planner names page evidence, never URL slugs. Patterns remain
   service-owned and generalized; provenance records the shape-to-name mapping. *)
module B = Playbook

let get name = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt name fields)
  | _ -> `Null

let mapping (book : B.t) =
  List.concat_map
    (fun (p : B.procedure) ->
      Option.fold ~none:[] ~some:(fun (p : B.provenance) -> p.kind_mapping) p.provenance)
    book.procedures

let observations traces =
  let rows =
    List.concat_map
      (fun (trace : Trace.t) ->
        List.map
          (fun (p : Trace.inferred_page) ->
            let matches page =
              let declared =
                B.
                  {
                    name = p.name;
                    description = "";
                    url_pattern = Some (Page_kind.playbook_pattern p.url_pattern);
                    text_marker = None;
                    repeatable = true;
                  }
              in
              B.page_kind [ declared ] ~url:page.Trace.url ~text:page.title <> None
            in
            let steps =
              if trace.steps <> [] then trace.steps
              else
                List.concat_map
                  (fun (p : Trace.trace_procedure) -> p.steps)
                  trace.procedures
            in
            let titles =
              List.map (fun (s : Trace.trace_step) -> s.after) steps
              @ Option.to_list trace.final
              |> List.filter_map (fun page ->
                  if matches page && page.Trace.title <> "" then Some page.title else None)
              |> List.sort_uniq String.compare
            in
            let _, labels =
              List.fold_left
                (fun (before, labels) (s : Trace.trace_step) ->
                  let labels =
                    if Option.fold ~none:false ~some:matches before then
                      Option.to_list s.target @ labels
                    else labels
                  in
                  (Some s.after, labels))
                (Option.map (fun url -> Trace.{ url; title = "" }) trace.start_url, [])
                steps
            in
            `Assoc
              [
                ("key", `String p.name);
                ("url_pattern", `String (Page_kind.playbook_pattern p.url_pattern));
                ("titles", `List (List.map (fun t -> `String t) titles));
                ( "labels",
                  `List
                    (List.sort_uniq compare
                       (List.map Trace.yojson_of_trace_target labels)) );
              ])
          trace.inferred_pages)
      traces
  in
  `List (List.sort_uniq compare rows)

let name ~known (seed : B.t) json =
  let declared =
    match get "kinds" json with
    | `Assoc fields ->
        List.filter_map
          (fun (key, value) ->
            match value with `String name -> Some (key, name) | _ -> None)
          fields
    | _ -> []
  in
  let all =
    List.fold_left
      (fun acc (key, value) ->
        if List.mem_assoc key acc then acc else (key, value) :: acc)
      known declared
  in
  let named key = Option.value ~default:key (List.assoc_opt key all) in
  let invalid =
    List.find_opt
      (fun (p : B.page) ->
        let key = p.name and name = named p.name in
        let inferred = not (List.mem_assoc key known) in
        inferred
        && (String.length name < 2
           || not
                (List.for_all
                   (fun word ->
                     word <> ""
                     && String.for_all (function 'a' .. 'z' -> true | _ -> false) word)
                   (String.split_on_char '-' name))))
      seed.pages
  in
  match invalid with
  | Some p ->
      Error
        ("name page kind " ^ p.name
       ^ " with lowercase words separated by hyphens, without placeholders or single \
          letters")
  | None ->
      let pages =
        List.map (fun (p : B.page) -> { p with name = named p.name }) seed.pages
        |> List.sort (fun (a : B.page) (b : B.page) ->
            compare
              (String.length (Option.value ~default:"" b.url_pattern))
              (String.length (Option.value ~default:"" a.url_pattern)))
      in
      let names = List.map (fun (p : B.page) -> p.name) pages in
      if List.length names <> List.length (List.sort_uniq String.compare names) then
        Error "kinds names must be distinct"
      else Ok ({ seed with pages }, all)
