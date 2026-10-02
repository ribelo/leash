module B = Playbook
module P = Protocol
module S = Ox_caps.Cap_sys
module F = Ox_caps.Cap_stdlib
module U = Ox_caps.Cap_unix

type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >

type planner = Yojson.Safe.t -> (Yojson.Safe.t, string) result

type t = {
  caps : caps;
  config : Config.learning;
  planner : planner;
  warn : string -> unit;
  lock : Eio.Mutex.t;
}

let create ~caps ~config ?(planner = fun _ -> Error "learning planner unavailable")
    ?(warn = fun _ -> ()) () =
  { caps :> caps; config; planner; warn; lock = Eio.Mutex.create () }

let config t = t.config
let ( let* ) = Result.bind

let get key = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt key fields)
  | _ -> `Null

let protect f =
  try Ok (f ()) with
  | Sys_error why | Yojson.Json_error why -> Error why
  | Unix.Unix_error (code, fn, p) -> Error (fn ^ " " ^ p ^ ": " ^ Unix.error_message code)

let read t file =
  protect (fun () ->
      let ch = F.open_in_bin ~caps:t.caps file in
      Fun.protect ~finally:(fun () -> close_in ch) (fun () -> Yojson.Safe.from_channel ch))

let write t file json =
  let* () = Config.ensure_dir ~caps:t.caps (Filename.dirname file) in
  B.atomic_write_json ~caps:t.caps ~mode:0o600 file json

let root t = B.proposed_directory ~caps:t.caps ()
let state_file t = Filename.concat (Filename.dirname (root t)) "learning.json"
let state t = match read t (state_file t) with Ok (`Assoc fields) -> fields | _ -> []

let update t key value =
  let fields = state t in
  match
    write t (state_file t) (`Assoc ((key, value) :: List.remove_assoc key fields))
  with
  | Ok () -> ()
  | Error why -> t.warn why

let counter t key = match List.assoc_opt key (state t) with Some (`Int n) -> n | _ -> 0

let path kinds =
  let rec loop previous acc = function
    | [] -> List.rev acc
    | ("unknown" | "") :: rest -> loop previous acc rest
    | kind :: rest when Some (Page_kind.playbook_name kind) = previous ->
        loop previous acc rest
    | kind :: rest ->
        let kind = Page_kind.playbook_name kind in
        loop (Some kind) (kind :: acc) rest
  in
  loop None [] kinds

let steps (trace : Trace.t) =
  if trace.steps <> [] then trace.steps
  else List.concat_map (fun (p : Trace.trace_procedure) -> p.steps) trace.procedures

let signature trace =
  List.map (fun (s : Trace.trace_step) -> (s.operation, s.target)) (steps trace)

let agreement = function
  | [] -> false
  | first :: rest
    when first.Trace.outcome = "done"
         && List.for_all (fun t -> t.Trace.outcome = "done") rest ->
      let p = path first.Trace.page_kind_path and actions = signature first in
      p <> [] && actions <> []
      && List.for_all
           (fun trace ->
             trace.Trace.site = first.site && trace.error_code = None
             && List.for_all (fun (s : Trace.trace_step) -> s.error = None) (steps trace)
             && path trace.page_kind_path = p
             && signature trace = actions)
           (first :: rest)
  | _ -> false

let contains text needle =
  let text = String.lowercase_ascii text and needle = String.lowercase_ascii needle in
  let rec at n =
    n + String.length needle <= String.length text
    && (String.sub text n (String.length needle) = needle || at (n + 1))
  in
  needle <> "" && at 0

(* map-yzqp map-wm4v: authored false beats inference; never trial a destructive path. *)
let classify pages traces =
  let kinds =
    List.concat_map (fun (trace : Trace.t) -> path trace.page_kind_path) traces
  in
  match
    List.find_opt
      (fun (page : B.page) -> (not page.repeatable) && List.mem page.name kinds)
      pages
  with
  | Some page -> (false, "authored page " ^ page.name ^ " is non-repeatable")
  | None ->
      let risky trace =
        let context =
          String.concat " "
            (trace.Trace.page_kind_path
            @ List.concat_map
                (fun (s : Trace.trace_step) ->
                  (s.after.title :: Option.to_list s.text)
                  @ Option.fold ~none:[]
                      ~some:(fun (t : Trace.trace_target) -> [ t.label ])
                      s.target)
                (steps trace))
        in
        List.exists (fun (s : Trace.trace_step) -> s.non_repeatable) (steps trace)
        || B.non_repeatable_context context
           && List.exists
                (fun (s : Trace.trace_step) ->
                  List.mem
                    (String.lowercase_ascii s.operation)
                    [ "submit"; "press"; "click"; "upload"; "select"; "type_text" ])
                (steps trace)
      in
      if List.exists risky traces then
        (false, "submission action on an irreversible page kind or observed title")
      else (true, "no irreversible submission in the observed path")

let proposal_files t =
  match protect (fun () -> S.readdir ~caps:t.caps (root t)) with
  | Error _ -> []
  | Ok files ->
      Array.to_list files
      |> List.filter (fun name -> Filename.check_suffix name ".json")
      |> List.sort String.compare
      |> List.map (Filename.concat (root t))

type draft = { file : string; book : B.loaded; proc : B.procedure }

let proposals t =
  List.concat_map
    (fun file ->
      match read t file with
      | Error why ->
          t.warn why;
          []
      | Ok json -> (
          let book =
            match B.of_json ~file json with
            | Ok book -> Ok book
            | Error _ -> (
                let* proposal = B.proposal_of_yojson json in
                let* books = B.list ~caps:t.caps () in
                match
                  List.find_opt
                    (fun (b : B.loaded) -> b.playbook.site = proposal.site)
                    books
                with
                | None -> Error "procedure proposal has no installed book"
                | Some b ->
                    B.of_json ~file
                      (B.yojson_of_t
                         { b.playbook with procedures = [ proposal.procedure ] }))
          in
          match book with
          | Error why ->
              t.warn why;
              []
          | Ok book ->
              List.filter_map
                (fun (proc : B.procedure) ->
                  match proc.provenance with
                  | Some _ -> Some { file; book; proc }
                  | None -> None)
                book.playbook.procedures))
    (proposal_files t)

let drafts t ~site ~kind =
  if t.config.mode <> Config.Learning_mode.Auto then []
  else
    proposals t
    |> List.filter_map (fun d ->
        match d.proc.provenance with
        | Some p
          when d.book.playbook.site = site && p.repeatable && p.tries < t.config.max_tries
               &&
               match (p.path, kind) with
               | first :: _, Some kind ->
                   Page_kind.playbook_name first = Page_kind.playbook_name kind
               | _ -> false ->
            Some B.{ procedure = d.proc; revision = B.draft_revision d.book.playbook }
        | _ -> None)

let books t installed =
  if t.config.mode <> Config.Learning_mode.Auto then installed
  else
    List.fold_left
      (fun books draft ->
        if
          List.exists
            (fun (b : B.loaded) -> b.playbook.site = draft.book.playbook.site)
            books
        then books
        else
          match draft.proc.provenance with
          | Some p when p.repeatable && p.tries < t.config.max_tries ->
              books
              @ [
                  {
                    draft.book with
                    playbook = { draft.book.playbook with procedures = [] };
                  };
                ]
          | _ -> books)
      installed (proposals t)

let status t =
  let installed = match B.list ~caps:t.caps () with Ok books -> books | Error _ -> [] in
  let sites =
    List.sort_uniq String.compare
      (List.map (fun (b : B.loaded) -> b.playbook.site) installed
      @ List.map (fun d -> d.book.playbook.site) (proposals t)
      @ List.filter_map
          (fun (key, _) ->
            if String.starts_with ~prefix:"compile:" key then
              Some (String.sub key 8 (String.length key - 8))
            else None)
          (state t))
  in
  `Assoc
    [
      ("mode", `String (Config.Learning_mode.to_string t.config.mode));
      ("drafts", `Int (List.length (proposals t)));
      ( "sites",
        `List
          (List.map
             (fun site ->
               let procedures =
                 List.concat_map
                   (fun (b : B.loaded) ->
                     if b.playbook.site = site then b.playbook.procedures else [])
                   installed
               in
               let count gate =
                 List.fold_left
                   (fun n (p : B.procedure) ->
                     match p.provenance with
                     | Some v when contains v.gate gate -> n + 1
                     | _ -> n)
                   0 procedures
               in
               `Assoc
                 [
                   ("site", `String site);
                   ( "last_compile",
                     Option.value ~default:`Null
                       (List.assoc_opt ("compile:" ^ site) (state t)) );
                   ("installed_by_replay", `Int (count "replay"));
                   ("installed_by_agreement", `Int (count "agreement"));
                 ])
             sites) );
    ]

let inferred_pages traces =
  let session = Page_kind.session () in
  List.iter
    (fun trace ->
      Option.iter
        (fun url -> ignore (Page_kind.observe session ~url ~title:""))
        trace.Trace.start_url;
      List.iter
        (fun (s : Trace.trace_step) ->
          ignore (Page_kind.observe session ~url:s.after.url ~title:s.after.title))
        (steps trace))
    traces;
  let inferred = Page_kind.draft_pages session in
  let recorded = List.concat_map (fun trace -> trace.Trace.inferred_pages) traces in
  let inferred =
    if recorded = [] then inferred
    else
      List.map
        (fun (p : Trace.inferred_page) ->
          Page_kind.{ name = p.name; url_pattern = p.url_pattern })
        recorded
  in
  List.sort_uniq
    (fun (a : B.page) b -> String.compare a.name b.name)
    (List.map
       (fun (p : Page_kind.draft_page) ->
         B.
           {
             name = Page_kind.playbook_name p.name;
             description = "Inferred " ^ p.name;
             url_pattern = Some (Page_kind.playbook_pattern p.url_pattern);
             text_marker = None;
             repeatable = true;
           })
       inferred)

let trace_input trace =
  let session = Page_kind.session () in
  let declared = inferred_pages [ trace ] in
  let previous_url = ref trace.Trace.start_url in
  let before =
    ref
      (match path trace.Trace.page_kind_path with first :: _ -> first | _ -> "unknown")
  in
  `Assoc
    [
      ("path", `List (List.map (fun s -> `String s) (path trace.page_kind_path)));
      ( "steps",
        `List
          (List.map
             (fun (s : Trace.trace_step) ->
               let inferred =
                 (Page_kind.observe session ~url:s.after.url ~title:s.after.title).name
               in
               let after =
                 Option.value ~default:inferred
                   (B.page_kind declared ~url:s.after.url ~text:s.after.title)
               in
               let kind = !before in
               let navigation =
                 s.operation = "navigate"
                 || Option.fold ~none:false
                      ~some:(fun url -> url <> s.after.url)
                      !previous_url
               in
               previous_url := Some s.after.url;
               before := after;
               `Assoc
                 [
                   ("kind", `String kind);
                   ("after_kind", `String after);
                   ("navigation", `Bool navigation);
                   ("operation", `String s.operation);
                   ( "target",
                     Option.fold ~none:`Null ~some:Trace.yojson_of_trace_target s.target
                   );
                   ( "text",
                     Option.fold ~none:`Null
                       ~some:(fun text -> `Assoc [ ("arg_candidate", `String text) ])
                       s.text );
                   ("after", Trace.yojson_of_trace_page s.after);
                   ("error", Option.fold ~none:`Null ~some:(fun s -> `String s) s.error);
                 ])
             (steps trace)) );
      ("outcome", `String trace.outcome);
    ]

let placeholders text =
  let rec loop offset names =
    match String.index_from_opt text offset '{' with
    | None -> names
    | Some start -> (
        match String.index_from_opt text (start + 1) '}' with
        | None -> names
        | Some stop ->
            loop (stop + 1) (String.sub text (start + 1) (stop - start - 1) :: names))
  in
  loop 0 []

let validate_generalization book traces (proc : B.procedure) =
  let* () = B.check_procedure book proc in
  let goals =
    List.filter_map (function B.Goal goal -> Some goal | _ -> None) proc.steps
  in
  let* () =
    if List.length goals = List.length proc.steps then Ok ()
    else Error "compiled steps must be human-language goal steps"
  in
  let texts trace =
    List.filter_map (fun (s : Trace.trace_step) -> s.text) (steps trace)
  in
  let variations =
    match traces with
    | [] -> 0
    | first :: rest ->
        List.mapi
          (fun index text ->
            List.exists (fun trace -> List.nth_opt (texts trace) index <> Some text) rest)
          (texts first)
        |> List.filter Fun.id |> List.length
  in
  let args = Option.value ~default:[] proc.args in
  let* () =
    if
      List.length
        (List.filter
           (fun (arg : B.arg_decl) ->
             match arg.source with B.From_mission _ -> true | B.Const _ -> false)
           args)
      >= variations
    then Ok ()
    else Error "every differing typed value must be a declared argument"
  in
  let* () =
    if
      List.for_all
        (fun (arg : B.arg_decl) ->
          let name = arg.name in
          List.exists (fun (g : B.goal_step) -> contains g.goal ("{" ^ name ^ "}")) goals)
        args
    then Ok ()
    else Error "declared arguments must occur in goal steps"
  in
  let text =
    proc.expect
    @ List.concat_map
        (fun (g : B.goal_step) ->
          (g.goal :: Option.to_list g.hint) @ Option.value ~default:[] g.until)
        goals
  in
  let* () =
    if
      List.for_all
        (fun name -> List.exists (fun (arg : B.arg_decl) -> arg.name = name) args)
        (List.concat_map placeholders text)
    then Ok ()
    else Error "goal contains an undeclared argument"
  in
  let* () =
    if List.exists (fun (g : B.goal_step) -> contains g.goal "index ") goals then
      Error "goals must name accessible roles and labels, never indices"
    else Ok ()
  in
  let untils =
    List.concat_map (fun (g : B.goal_step) -> Option.value ~default:[] g.until) goals
  in
  let navigations =
    match traces with
    | [] -> []
    | trace :: _ ->
        let previous = ref trace.Trace.start_url in
        List.filter_map
          (fun (s : Trace.trace_step) ->
            let changed =
              List.mem s.operation [ "navigate"; "nav" ]
              || Option.fold ~none:false ~some:(fun url -> url <> s.after.url) !previous
            in
            previous := Some s.after.url;
            if changed then
              Some (B.page_kind book.B.pages ~url:s.after.url ~text:s.after.title)
            else None)
          (steps trace)
  in
  if
    List.for_all
      (function Some kind -> List.mem ("the page is " ^ kind) untils | None -> false)
      navigations
  then Ok ()
  else Error "every navigation needs an explicit the page is <kind> until expectation"

let snapshot_agrees (book : B.t) (snapshot : P.snapshot) (proc : B.procedure) =
  let goals = List.filter_map (function B.Goal g -> Some g | _ -> None) proc.steps in
  let kind =
    B.page_kind book.pages ~url:snapshot.url
      ~text:
        (snapshot.title ^ " "
        ^ String.concat " " (List.map (fun (r : P.row) -> r.name) snapshot.rows))
  in
  let normalized text = String.lowercase_ascii (String.trim text) in
  let equal_goal goal expected =
    normalized goal = normalized expected || normalized goal = normalized (expected ^ ".")
  in
  let target_agrees goal =
    (* Require one unambiguous action and one exact accessible target per goal.
       Substring matching cannot establish that ALL targets in compound prose exist. *)
    let prefixes =
      [
        "Click ";
        "Press ";
        "Select ";
        "Submit ";
        "Upload ";
        "Delete ";
        "Open ";
        "Check ";
        "Uncheck ";
        "Toggle ";
      ]
      @ List.concat_map
          (fun (arg : B.arg_decl) ->
            [ "Type {" ^ arg.name ^ "} in "; "Type {" ^ arg.name ^ "} into " ])
          (Option.value ~default:[] proc.args)
    in
    let matches =
      List.filter
        (fun (r : P.row) ->
          r.role <> "" && r.name <> ""
          && List.exists
               (fun prefix ->
                 List.exists
                   (fun label ->
                     List.exists
                       (fun article ->
                         equal_goal goal (prefix ^ article ^ r.role ^ " named " ^ label))
                       [ ""; "the " ])
                   [ r.name; "\"" ^ r.name ^ "\""; "'" ^ r.name ^ "'" ])
               prefixes)
        snapshot.rows
    in
    List.length matches = 1
  in
  List.for_all
    (fun (g : B.goal_step) ->
      let kind_ok =
        List.for_all
          (fun sentence ->
            match B.resolve book.pages sentence with
            | Ok (B.Page_kind expected) -> kind = Some expected
            | Ok (B.Not_page_kind expected) -> kind <> Some expected
            | _ -> false)
          (Option.value ~default:[] g.until)
      in
      kind_ok
      && (target_agrees g.goal
         || Option.fold ~none:false
              ~some:(fun name ->
                List.exists (equal_goal g.goal)
                  [
                    "Observe the " ^ name ^ " page";
                    "Wait for the " ^ name ^ " page";
                    "Verify that the page is " ^ name;
                    "Check that the page is " ^ name;
                  ])
              kind))
    goals

let persist ?revision t book proc =
  B.propose ?revision ~caps:t.caps ~book:{ book with scripts = None } ~site:book.B.site
    proc

let archive t draft =
  B.archive_proposal
    ~revision:(B.draft_revision draft.book.playbook)
    ~caps:t.caps draft.file

let install ?revision t file slug (result : P.run_result) =
  match B.accept ?revision ~consume:true ~caps:t.caps file with
  | Error why ->
      t.warn why;
      result
  | Ok _ ->
      update t ("fail:" ^ Option.value ~default:"" result.P.site ^ ":" ^ slug) (`Int 0);
      update t
        ("repair-fail:" ^ Option.value ~default:"" result.site ^ ":" ^ slug)
        (`Int 0);
      {
        result with
        P.installed = List.sort_uniq String.compare (slug :: result.installed);
      }

let compile ?prior ?revision t ~files ~traces ~existing ~repair ~snapshot
    (result : P.run_result) =
  let first =
    List.hd (List.sort (fun (a : Trace.t) b -> String.compare a.time b.time) traces)
  in
  let pages = inferred_pages traces in
  let seed =
    match existing with
    | Some (b : B.loaded) ->
        {
          b.playbook with
          pages =
            b.playbook.pages
            @ List.filter
                (fun (page : B.page) ->
                  not
                    (List.exists
                       (fun (old : B.page) -> old.name = page.name)
                       b.playbook.pages))
                pages;
        }
    | None ->
        B.
          {
            site = first.Trace.site;
            entry =
              Option.value
                ~default:
                  (Option.fold ~none:""
                     ~some:(fun (p : Trace.trace_page) -> p.url)
                     first.final)
                first.start_url;
            description = "Learned " ^ first.site;
            pages;
            procedures = [];
            shapes = None;
            scripts = None;
          }
  in
  let repeatable, reason =
    match repair with
    | Some (proc : B.procedure) -> (
        match proc.provenance with
        | Some p -> (p.repeatable, p.reason)
        | None -> classify seed.pages traces)
    | None -> classify seed.pages traces
  in
  let agreed = agreement traces in
  let request errors =
    `Assoc
      [
        ("prompt_version", `String Planner.learning_prompt_version);
        ("task", `String (if repair = None then "compile" else "repair"));
        ("traces", `List (List.map trace_input traces));
        ("trace_files", `List (List.map (fun s -> `String s) files));
        ("playbook", B.yojson_of_t seed);
        ("repair", Option.fold ~none:`Null ~some:B.yojson_of_procedure repair);
        ("snapshot", if repair = None then `Null else P.yojson_of_snapshot snapshot);
        ("agreement", `Bool agreed);
        ("repeatable", `Bool repeatable);
        ("validation_errors", `String errors);
      ]
  in
  let decode json =
    let procedure_json = match get "procedure" json with `Null -> json | p -> p in
    let* proc = B.procedure_of_yojson procedure_json in
    let proc =
      match repair with Some old -> { proc with B.slug = old.slug } | None -> proc
    in
    let* () = validate_generalization seed traces proc in
    if
      (not repeatable) && repair = None
      && ((not agreed) || get "confirm" json <> `Bool true)
    then
      Error
        "non-repeatable generalization requires independent agreement and planner \
         confirmation"
    else if
      (not repeatable) && repair <> None
      && (get "confirm" json <> `Bool true || not (snapshot_agrees seed snapshot proc))
    then
      Error
        "agreement-repair needs existing page kinds and target rows in the failing \
         snapshot"
    else Ok proc
  in
  let answer =
    let* json = t.planner (request "") in
    match decode json with
    | Ok proc -> Ok proc
    | Error why ->
        let* json = t.planner (request why) in
        decode json
  in
  update t ("compile:" ^ first.site)
    (`String (Traces.timestamp (U.gettimeofday ~caps:t.caps ())));
  match answer with
  | Error why ->
      t.warn ("learning compile dropped: " ^ why);
      result
  | Ok proc -> (
      let gate =
        if repeatable then "replay"
        else if repair <> None then "agreement-repair"
        else "agreement"
      in
      let provenance =
        B.
          {
            traces = files;
            model = Config.Text.to_string t.config.planner_model;
            time = Traces.timestamp (U.gettimeofday ~caps:t.caps ());
            tries = Option.fold ~none:0 ~some:(fun (p : B.provenance) -> p.tries) prior;
            last_failure = Option.bind prior (fun (p : B.provenance) -> p.last_failure);
            path =
              Option.fold ~none:(path first.page_kind_path)
                ~some:(fun (p : B.provenance) -> p.path)
                prior;
            repeatable;
            reason;
            gate;
            repair =
              Option.fold ~none:(repair <> None)
                ~some:(fun (p : B.provenance) -> p.repair)
                prior;
          }
      in
      let proc = { proc with B.provenance = Some provenance } in
      let book = { seed with B.procedures = [ proc ] } in
      match persist ?revision t book proc with
      | Error why ->
          t.warn why;
          result
      | Ok file ->
          List.iter
            (fun trace_file ->
              match read t trace_file with
              | Ok json -> (
                  match Trace.t_of_yojson json with
                  | Ok trace -> (
                      match
                        write t trace_file
                          (Trace.yojson_of_t { trace with compiled = true })
                      with
                      | Ok () -> ()
                      | Error why -> t.warn why)
                  | Error why -> t.warn why)
              | Error why -> t.warn why)
            files;
          let result = { result with P.proposals = file :: result.proposals } in
          if t.config.mode = Config.Learning_mode.Auto && not repeatable then
            install ~revision:(B.draft_revision book) t file proc.slug result
          else result)

let after_trace_unmetered t ~store ~file trace result =
  if t.config.mode = Config.Learning_mode.Off || trace.Trace.site = "unknown" then result
  else
    Eio.Mutex.use_rw ~protect:true t.lock (fun () ->
        let installed =
          match B.list ~caps:t.caps () with
          | Ok b -> b
          | Error why ->
              t.warn why;
              []
        in
        let existing =
          List.find_opt (fun (b : B.loaded) -> b.playbook.site = trace.site) installed
        in
        let done_ = P.Run_status.to_string result.P.status = "done" in
        let retired = ref [] in
        let result =
          List.fold_left
            (fun result draft ->
              if draft.book.playbook.site <> trace.site then result
              else
                match
                  ( List.find_opt
                      (fun (p : P.run_procedure) ->
                        p.site = trace.site
                        && p.slug = "draft:" ^ draft.proc.slug
                        && (not p.planned)
                        && p.revision = Some (B.draft_revision draft.book.playbook))
                      result.P.procedures,
                    draft.proc.provenance )
                with
                | Some attempted, Some provenance
                  when t.config.mode = Config.Learning_mode.Auto && provenance.repeatable
                  ->
                    if
                      done_
                      && attempted.outcome = "verified"
                      && List.for_all
                           (fun (e : P.run_expectation) -> e.passed)
                           attempted.expectations
                    then
                      install ?revision:attempted.revision t draft.file draft.proc.slug
                        result
                    else if attempted.outcome = "failed" then (
                      let tries = provenance.tries + 1 in
                      if provenance.repair then (
                        let key = "fail:" ^ trace.site ^ ":" ^ draft.proc.slug in
                        let failures = counter t key + 1 in
                        update t key (`Int failures);
                        if failures >= t.config.retire_after then
                          match
                            B.retire_draft ~caps:t.caps ~file:draft.file
                              ~revision:(B.draft_revision draft.book.playbook)
                              ~site:trace.site ~slug:draft.proc.slug
                          with
                          | Ok () -> retired := draft.proc.slug :: !retired
                          | Error why -> t.warn why);
                      if tries >= t.config.max_tries || List.mem draft.proc.slug !retired
                      then (
                        (match archive t draft with
                        | Ok () -> ()
                        | Error why -> t.warn why);
                        result)
                      else
                        let p =
                          {
                            provenance with
                            B.tries;
                            last_failure =
                              Some
                                (Option.value ~default:"expectation failed"
                                   attempted.reason);
                          }
                        in
                        let proc = { draft.proc with B.provenance = Some p } in
                        match
                          persist
                            ~revision:(B.draft_revision draft.book.playbook)
                            t
                            { draft.book.playbook with B.procedures = [ proc ] }
                            proc
                        with
                        | Error why ->
                            t.warn why;
                            result
                        | Ok _ ->
                            let updated =
                              {
                                draft.book.playbook with
                                B.scripts = None;
                                procedures = [ proc ];
                              }
                            in
                            compile ~prior:p ~revision:(B.draft_revision updated) t
                              ~files:(p.traces @ [ file ]) ~traces:[ trace ]
                              ~existing:(Some draft.book) ~repair:(Some proc)
                              ~snapshot:result.final result)
                    else result
                | _ -> result)
            result (proposals t)
        in
        let pending = proposals t in
        let attempts =
          List.filter
            (fun (p : P.run_procedure) ->
              (not p.planned) && not (String.starts_with ~prefix:"draft:" p.slug))
            result.procedures
        in
        let missions =
          List.sort_uniq
            (fun (a : P.run_procedure) b -> compare (a.site, a.slug) (b.site, b.slug))
            attempts
        in
        List.iter
          (fun (p : P.run_procedure) ->
            let same_outcome outcome =
              List.exists
                (fun (q : P.run_procedure) ->
                  q.site = p.site && q.slug = p.slug && q.outcome = outcome)
                attempts
            in
            let key = "fail:" ^ p.site ^ ":" ^ p.slug in
            if
              same_outcome "verified"
              || (p.site = trace.site && List.mem p.slug result.installed)
            then (
              update t key (`Int 0);
              update t ("repair-fail:" ^ p.site ^ ":" ^ p.slug) (`Int 0))
            else if same_outcome "failed" then (
              let failures = counter t key + 1 in
              update t key (`Int failures);
              if failures >= t.config.retire_after then
                match B.retire ~caps:t.caps ~site:p.site ~slug:p.slug with
                | Ok () -> retired := p.slug :: !retired
                | Error why -> t.warn why))
          missions;
        List.iter
          (fun draft ->
            if List.mem draft.proc.slug !retired && draft.book.playbook.site = trace.site
            then match archive t draft with Ok () -> () | Error why -> t.warn why)
          pending;
        let failing =
          List.find_opt
            (fun (p : P.run_procedure) ->
              p.outcome = "failed"
              && (not (String.starts_with ~prefix:"draft:" p.slug))
              && (p.attempts >= 2
                 || counter t ("fail:" ^ p.site ^ ":" ^ p.slug) >= 2
                 || not
                      (fst
                         (classify
                            (Option.fold ~none:[]
                               ~some:(fun (b : B.loaded) -> b.playbook.pages)
                               existing)
                            [ trace ])))
              && not (List.mem p.slug !retired))
            result.procedures
        in
        match (failing, existing) with
        | _ when result.installed <> [] -> result
        | Some failure, Some book
          when not
                 (List.exists
                    (fun d ->
                      d.book.playbook.site = trace.site && d.proc.slug = failure.slug)
                    pending) -> (
            match
              List.find_opt
                (fun (p : B.procedure) -> p.slug = failure.slug)
                book.playbook.procedures
            with
            | Some proc ->
                compile t ~files:[ file ] ~traces:[ trace ] ~existing ~repair:(Some proc)
                  ~snapshot:result.final result
            | None -> result)
        | _ when done_ ->
            let candidates =
              match Traces.list store ~site:trace.site ~outcome:"done" () with
              | Ok rows -> rows
              | Error why ->
                  t.warn why;
                  []
            in
            let current_path = path trace.page_kind_path in
            let candidates =
              List.filter
                (fun (_, t) ->
                  path t.Trace.page_kind_path = current_path
                  && current_path <> []
                  && steps t <> []
                  && not t.compiled)
                candidates
            in
            let covered =
              match existing with
              | None -> false
              | Some b ->
                  List.exists
                    (fun (p : B.procedure) ->
                      match p.provenance with
                      | Some prov -> prov.path = current_path
                      | None ->
                          List.exists
                            (fun (saved : Trace.trace_procedure) ->
                              saved.outcome = "verified" && saved.procedure = p.slug
                              && not saved.planned)
                            trace.procedures)
                    b.playbook.procedures
            in
            let pending =
              List.exists
                (fun d ->
                  d.book.playbook.site = trace.site
                  && Option.fold ~none:false
                       ~some:(fun p -> p.B.path = current_path)
                       d.proc.provenance)
                pending
            in
            let candidates =
              let traces = List.map snd candidates in
              let pages =
                match existing with
                | Some book -> book.playbook.pages
                | None -> inferred_pages traces
              in
              if fst (classify pages traces) then candidates
              else
                let groups =
                  List.fold_left
                    (fun groups ((_, trace) as item) ->
                      let same, different =
                        List.partition
                          (fun group ->
                            match group with
                            | (_, head) :: _ -> signature head = signature trace
                            | [] -> false)
                          groups
                      in
                      let group = List.concat same @ [ item ] in
                      group :: different)
                    [] candidates
                in
                match
                  List.find_opt
                    (fun group ->
                      List.length group >= t.config.successes
                      && agreement (List.map snd group))
                    groups
                with
                | Some group -> group
                | None -> []
            in
            if List.length candidates < t.config.successes || covered || pending then
              result
            else
              let candidates =
                List.filteri (fun i _ -> i < t.config.successes) candidates
              in
              compile t ~files:(List.map fst candidates) ~traces:(List.map snd candidates)
                ~existing ~repair:None ~snapshot:result.final result
        | _ -> result)

(* map-ptnk: learning is billed after the browser run; compiler, retry and
   confirmation requests still belong to that mission's total-work curve. *)
let after_trace t ~store ~file trace result =
  let calls = ref 0 and reports = ref 0 and cost = ref 0. and unknown = ref false in
  let meter = function
    | Model_usage.Start _ -> incr calls
    | Model_usage.Reported (_, value) -> (
        incr reports;
        match value with
        | Some value when Float.is_finite value && value >= 0. -> cost := !cost +. value
        | _ -> unknown := true)
  in
  let learned =
    Model_usage.with_meter meter (fun () ->
        after_trace_unmetered t ~store ~file trace result)
  in
  if !calls = 0 then learned
  else
    let model_cost =
      if !unknown || !reports <> !calls then None
      else
        match result.P.model_cost with
        | Some before -> Some (before +. !cost)
        | None when result.model_calls = 0 -> Some !cost
        | None -> None
    in
    let learned =
      { learned with P.model_calls = result.model_calls + !calls; model_cost }
    in
    (* map-ptnk: durable mission accounting includes compile, validation retry and
       confirmation work; keep any compiled marker written during that work. *)
    (match read t file with
    | Ok json -> (
        match Trace.t_of_yojson json with
        | Ok durable -> (
            let durable =
              { durable with Trace.cost = model_cost; model_calls = learned.model_calls }
            in
            match write t file (Trace.yojson_of_t durable) with
            | Ok () -> ()
            | Error why -> t.warn why)
        | Error why -> t.warn why)
    | Error why -> t.warn why);
    learned
