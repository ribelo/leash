module B = Playbook
module P = Protocol
module S = Ox_caps.Cap_sys
module F = Ox_caps.Cap_stdlib
module U = Ox_caps.Cap_unix
module O = Learning_operation

let operations = O.segment

type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >

type planner = Yojson.Safe.t -> (Yojson.Safe.t, string) result

type meter = {
  mutable calls : int;
  mutable reports : int;
  mutable cost : float;
  mutable unknown : bool;
}

type t = {
  caps : caps;
  config : Config.learning;
  planner : planner;
  warn : string -> unit;
  sw : Eio.Switch.t;
  locks : Eio.Mutex.t;
  sites : (string, Eio.Mutex.t) Hashtbl.t;
  pending_mu : Eio.Mutex.t;
  pending_done : Eio.Condition.t;
  mutable pending : int;
}

let create ~sw ~caps ~config ?(planner = fun _ -> Error "learning planner unavailable")
    ?(warn = fun _ -> ()) () =
  {
    caps :> caps;
    config;
    planner;
    warn;
    sw;
    locks = Eio.Mutex.create ();
    sites = Hashtbl.create 8;
    pending_mu = Eio.Mutex.create ();
    pending_done = Eio.Condition.create ();
    pending = 0;
  }

let site_lock t site =
  Eio.Mutex.use_rw ~protect:true t.locks (fun () ->
      match Hashtbl.find_opt t.sites site with
      | Some lock -> lock
      | None ->
          let lock = Eio.Mutex.create () in
          Hashtbl.add t.sites site lock;
          lock)

let await_pending t =
  Eio.Mutex.use_rw ~protect:true t.pending_mu (fun () ->
      while t.pending > 0 do
        Eio.Condition.await t.pending_done t.pending_mu
      done)

let finish_pending t =
  Eio.Mutex.use_rw ~protect:true t.pending_mu (fun () ->
      t.pending <- t.pending - 1;
      if t.pending = 0 then Eio.Condition.broadcast t.pending_done)

let schedule t ~site work =
  Eio.Mutex.use_rw ~protect:true t.pending_mu (fun () -> t.pending <- t.pending + 1);
  match
    Eio.Fiber.fork ~sw:t.sw (fun () ->
        Fun.protect
          ~finally:(fun () -> finish_pending t)
          (fun () ->
            try Eio.Mutex.use_rw ~protect:true (site_lock t site) work with
            | Eio.Cancel.Cancelled _ as exn -> raise exn
            | exn -> t.warn (Printexc.to_string exn)))
  with
  | () -> ()
  | exception exn ->
      finish_pending t;
      raise exn

let config t = t.config
let empty_meter () = { calls = 0; reports = 0; cost = 0.; unknown = false }

let observe_usage meter = function
  | Model_usage.Start _ -> meter.calls <- meter.calls + 1
  | Model_usage.Reported (_, value) -> (
      meter.reports <- meter.reports + 1;
      match value with
      | Some value when Float.is_finite value && value >= 0. ->
          meter.cost <- meter.cost +. value
      | _ -> meter.unknown <- true)

let priced meter =
  if meter.calls = 0 then Some 0.
  else if meter.unknown || meter.reports <> meter.calls then None
  else Some meter.cost

let account_key site = "account:" ^ site
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

let record_account t site meter =
  let cost = match priced meter with Some value -> `Float value | None -> `Null in
  update t (account_key site)
    (`Assoc [ ("model_calls", `Int meter.calls); ("model_cost", cost) ])

let account_field site fields name =
  match List.assoc_opt (account_key site) fields with
  | Some (`Assoc account) -> List.assoc_opt name account
  | _ -> None

(* map-cnee: the matching path is the distinct kinds in first-visit order.
   Consecutive repeats and later revisits both collapse (A,B,A,B is A,B). [unknown]
   and empty names are not kinds. *)
let path kinds =
  let rec loop seen acc = function
    | [] -> List.rev acc
    | ("unknown" | "") :: rest -> loop seen acc rest
    | kind :: rest ->
        let kind = Page_kind.playbook_name kind in
        if List.mem kind seen then loop seen acc rest
        else loop (kind :: seen) (kind :: acc) rest
  in
  loop [] [] kinds

(* A kind observed only on a host other than the mission's final page — a consent
   interstitial on consent.google.com, for example — is not part of the matching
   path. The stored [page_kind_path] is left as recorded. A kind with no pattern, or
   any pattern on the final host, stays: exclusion needs positive evidence. *)
let foreign_only (trace : Trace.t) kind =
  match trace.final with
  | None -> false
  | Some final -> (
      match Page_kind.host final.url with
      | None -> false
      | Some final_host ->
          let patterns =
            List.filter
              (fun (page : Trace.inferred_page) ->
                Page_kind.playbook_name page.name = kind)
              trace.inferred_pages
          in
          patterns <> []
          && List.for_all
               (fun (page : Trace.inferred_page) ->
                 match Page_kind.host page.url_pattern with
                 | Some host -> host <> final_host
                 | None -> false)
               patterns)

let matching_path trace =
  List.filter
    (fun kind -> not (foreign_only trace kind))
    (path trace.Trace.page_kind_path)

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
      let p = matching_path first and actions = signature first in
      p <> [] && actions <> []
      && List.for_all
           (fun trace ->
             trace.Trace.site = first.site && trace.error_code = None
             && List.for_all (fun (s : Trace.trace_step) -> s.error = None) (steps trace)
             && matching_path trace = p
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
                   let named =
                     Option.value ~default:kind (List.assoc_opt kind p.kind_mapping)
                   in
                   first = named
                   || p.kind_mapping = []
                      && Page_kind.playbook_name first = Page_kind.playbook_name kind
               | _ -> false ->
            Some
              B.
                {
                  procedure = d.proc;
                  pages = d.book.playbook.pages;
                  scripts = d.book.scripts;
                  revision = B.draft_revision d.book.playbook;
                }
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
      (* map-w62c: learning runs after the reply, so a caller (an agent, the live gates)
         needs to see whether a compile is still running before the next mission. *)
      ("pending", `Int (Eio.Mutex.use_ro t.pending_mu (fun () -> t.pending)));
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
               let fields = state t in
               let calls =
                 match account_field site fields "model_calls" with
                 | Some (`Int n) -> n
                 | _ -> 0
               in
               `Assoc
                 [
                   ("site", `String site);
                   ( "last_compile",
                     Option.value ~default:`Null
                       (List.assoc_opt ("compile:" ^ site) fields) );
                   ("installed_by_replay", `Int (count "replay"));
                   ("installed_by_agreement", `Int (count "agreement"));
                   ("learning_calls", `Int calls);
                   ( "learning_cost",
                     Option.value ~default:`Null (account_field site fields "model_cost")
                   );
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
             name = p.name;
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
    ref (match matching_path trace with first :: _ -> first | _ -> "unknown")
  in
  `Assoc
    [
      ("mission", `String trace.mission);
      ( "structural_outline",
        Option.fold ~none:`Null
          ~some:(fun outline -> `String outline)
          trace.structural_outline );
      ( "final_title",
        match trace.final with Some page -> `String page.title | None -> `Null );
      ("path", `List (List.map (fun s -> `String s) (matching_path trace)));
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
                   ("source", `String s.source);
                   ( "mission_arguments",
                     `List
                       (List.filter_map
                          (fun (name, value) ->
                            if s.text = Some value then Some (`String name) else None)
                          trace.arguments) );
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
  let* () = B.check_goal_count ~minimum:2 book proc in
  let goals =
    List.filter_map (function B.Goal goal -> Some goal | _ -> None) proc.steps
  in
  let* () =
    if List.for_all (function B.Goal _ | B.Script _ -> true | _ -> false) proc.steps
    then Ok ()
    else
      Error "compiled steps must be human-language goals or read-only collection scripts"
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
  let* () =
    if
      List.for_all
        (function Some kind -> List.mem ("the page is " ^ kind) untils | None -> false)
        navigations
    then Ok ()
    else Error "every navigation needs an explicit the page is <kind> until expectation"
  in
  (* map-bjon: a page-kind check can pass while the page still says it is loading.
     The mission result needs its own expectation. *)
  let page_kind_sentence sentence =
    match B.resolve book.B.pages sentence with
    | Ok (B.Page_kind _ | B.Not_page_kind _) -> true
    | _ -> false
  in
  if List.exists (fun sentence -> not (page_kind_sentence sentence)) proc.expect then
    Ok ()
  else
    Error
      "final expectations must check the mission result, not only the page kind: keep \
       the page-kind checks and add a result check. Use \"the page shows <stable text>\" \
       only when that exact text is body text on every trace's final page. When no \
       stable text is known, write a judgment sentence in the mission's words, for \
       example \"destination prices are shown\" when the mission asked to see \
       destination prices (not \"the page shows destination prices\", which is a literal \
       text check)"

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

let persist ?revision t (book : B.t) (proc : B.procedure) =
  let names =
    List.filter_map (function B.Script s -> Some s.script | _ -> None) proc.steps
  in
  let scripts =
    Option.map (List.filter (fun (name, _) -> List.mem name names)) book.B.scripts
  in
  let scripts = match scripts with Some [] -> None | other -> other in
  B.propose ?revision ~caps:t.caps ~book:{ book with scripts } ~site:book.B.site proc

let archive t draft =
  B.archive_proposal
    ~revision:(B.draft_revision draft.book.playbook)
    ~caps:t.caps draft.file

let install ?revision ?(replayed_scripts = []) t file slug (result : P.run_result) =
  match B.accept ?revision ~consume:true ~replayed_scripts ~caps:t.caps file with
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

let compile ?prior ?revision ?operation ?entry_url t ~meter ~files ~traces ~existing
    ~repair ~snapshot (result : P.run_result) =
  let planner request =
    Model_usage.with_meter (observe_usage meter) (fun () -> t.planner request)
  in
  let traces = List.sort (fun (a : Trace.t) b -> String.compare a.time b.time) traces in
  let first = List.hd traces in
  let operation =
    Option.map
      (fun operation ->
        let mapping =
          Option.fold ~none:[]
            ~some:(fun (book : B.loaded) -> Learning_pages.mapping book.playbook)
            existing
        in
        let declared =
          Option.fold ~none:[]
            ~some:(fun (book : B.loaded) -> book.playbook.pages)
            existing
        in
        match O.segment ~mapping ~declared first with
        | representative :: _ -> representative
        | [] -> operation)
      operation
  in
  let pages = inferred_pages traces in
  let known =
    match existing with
    | None -> []
    | Some (b : B.loaded) ->
        Learning_pages.mapping b.playbook
        @ List.map (fun (p : B.page) -> (p.name, p.name)) b.playbook.pages
        @ List.filter_map
            (fun (page : B.page) ->
              Option.map
                (fun (old : B.page) -> (page.name, old.name))
                (List.find_opt
                   (fun (old : B.page) -> old.url_pattern = page.url_pattern)
                   b.playbook.pages))
            pages
  in
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
                       (fun (old : B.page) ->
                         old.name = page.name || old.url_pattern = page.url_pattern)
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
                (match entry_url with Some url -> Some url | None -> first.start_url);
            description = "Learned " ^ first.site;
            pages;
            procedures = [];
            shapes = None;
            scripts = None;
          }
  in
  let name_kind mapping key =
    match
      List.find_opt
        (fun (raw, _) -> raw = key || Page_kind.playbook_name raw = key)
        mapping
    with
    | Some (_, name) -> name
    | None -> key
  in
  let classify_named (book : B.t) mapping =
    classify book.B.pages
      (List.map
         (fun (trace : Trace.t) ->
           {
             trace with
             page_kind_path = List.map (name_kind mapping) trace.page_kind_path;
           })
         traces)
  in
  let repeatable, reason = classify_named seed known in
  let repeatable, reason =
    match repair with
    | Some { B.provenance = Some p; _ } ->
        (p.repeatable && repeatable, if repeatable then p.reason else reason)
    | _ -> (repeatable, reason)
  in
  let agreed =
    match operation with
    | None -> agreement traces
    | Some operation ->
        List.for_all
          (fun (trace : Trace.t) ->
            trace.outcome = "done" && trace.error_code = None
            && List.for_all (fun (s : Trace.trace_step) -> s.error = None) (steps trace)
            && (if repeatable then O.compatible (signature trace) (O.signature operation)
                else signature trace = O.signature operation)
            &&
            match trace.page_kind_path with
            | entry :: _ -> entry = operation.entry_kind
            | [] -> false)
          traces
  in
  let request errors =
    `Assoc
      [
        ("prompt_version", `String Planner.learning_prompt_version);
        ("task", `String (if repair = None then "compile" else "repair"));
        ("traces", `List (List.map trace_input traces));
        ("page_observations", Learning_pages.observations traces);
        ("kind_mapping", `Assoc (List.map (fun (key, name) -> (key, `String name)) known));
        ( "operation",
          Option.fold ~none:`Null
            ~some:(fun (op : O.t) ->
              `Assoc
                [
                  ("entry_kind", `String op.entry_kind);
                  ("exit_kind", `String op.exit_kind);
                  ( "arguments",
                    `List
                      (List.map
                         (fun (n, names) ->
                           `Assoc
                             [
                               ("step", `Int n);
                               ("names", `List (List.map (fun name -> `String name) names));
                             ])
                         op.arguments) );
                ])
            operation );
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
    let* book, mapping = Learning_pages.name ~known seed json in
    let* book =
      match get "scripts" json with
      | `Null -> Ok book
      | scripts ->
          let fields =
            match B.yojson_of_t book with `Assoc fields -> fields | _ -> assert false
          in
          let* declared =
            B.t_of_yojson
              (`Assoc (("scripts", scripts) :: List.remove_assoc "scripts" fields))
          in
          let names =
            List.filter_map
              (function B.Script s -> Some s.script | _ -> None)
              proc.steps
          in
          if
            (not repeatable)
            || not
                 (List.for_all
                    (fun (trace : Trace.t) -> Structural_outline.collection trace.mission)
                    traces)
          then Error "compiled scripts require a repeatable collection procedure"
          else if
            not
              (List.exists
                 (fun (trace : Trace.t) -> trace.structural_outline <> None)
                 traces)
          then Error "compiled collection scripts require observed structural_outline"
          else if
            not
              (List.for_all
                 (fun (name, _) -> List.mem name names)
                 (Option.value ~default:[] declared.scripts))
          then
            Error "every compiled script must be a procedure step and run through replay"
          else if
            List.exists
              (fun (name, _) ->
                List.mem_assoc name (Option.value ~default:[] book.scripts))
              (Option.value ~default:[] declared.scripts)
          then Error "compiled scripts must not replace existing script names"
          else
            Ok
              {
                declared with
                scripts =
                  Some
                    (Option.value ~default:[] book.scripts
                    @ Option.value ~default:[] declared.scripts);
              }
    in
    let* () =
      match operation with
      | Some op when name_kind mapping op.entry_kind = "consent" ->
          Error "named consent operations cannot become procedures"
      | _ -> Ok ()
    in
    let repeatable_now, reason_now = classify_named book mapping in
    let repeatable = repeatable && repeatable_now in
    let reason = if repeatable_now then reason else reason_now in
    let* () = validate_generalization book traces proc in
    let* () =
      match operation with
      | None -> Ok ()
      | Some op ->
          let expected_kind =
            Option.value ~default:op.exit_kind (List.assoc_opt op.exit_kind mapping)
          in
          if
            List.exists
              (fun sentence ->
                B.resolve book.pages sentence = Ok (B.Page_kind expected_kind))
              proc.B.expect
          then Ok ()
          else Error ("operation expect must check exit kind " ^ expected_kind)
    in
    let* loaded =
      B.of_json ~file:"<learning>"
        (B.yojson_of_t
           {
             book with
             procedures =
               proc
               :: List.filter
                    (fun (old : B.procedure) -> old.slug <> proc.slug)
                    book.procedures;
           })
    in
    let names =
      List.filter_map (function B.Script s -> Some s.script | _ -> None) proc.steps
    in
    let scripts =
      List.filter (fun (s : B.script) -> List.mem s.name names) loaded.scripts
    in
    let* () =
      List.fold_left
        (fun result (script : B.script) ->
          let* () = result in
          B.check_compiled_script script.code)
        (Ok ()) scripts
    in
    let* () =
      if
        scripts = []
        || repeatable
           && List.for_all
                (fun (trace : Trace.t) -> Structural_outline.collection trace.mission)
                traces
           && List.exists
                (fun (trace : Trace.t) -> trace.structural_outline <> None)
                traces
      then Ok ()
      else
        Error
          "compiled scripts require repeatable collection operations and observed \
           structural_outline"
    in
    if
      (not repeatable) && repair = None
      && ((not agreed) || get "confirm" json <> `Bool true)
    then
      Error
        "non-repeatable generalization requires independent agreement and planner \
         confirmation"
    else if
      (not repeatable) && repair <> None
      && (get "confirm" json <> `Bool true || not (snapshot_agrees book snapshot proc))
    then
      Error
        "agreement-repair needs existing page kinds and target rows in the failing \
         snapshot"
    else Ok (proc, book, mapping, repeatable, reason)
  in
  let answer =
    let* json = planner (request "") in
    match decode json with
    | Ok proc -> Ok proc
    | Error why ->
        let* json = planner (request why) in
        decode json
  in
  update t ("compile:" ^ first.site)
    (`String (Traces.timestamp (U.gettimeofday ~caps:t.caps ())));
  match answer with
  | Error why ->
      t.warn ("learning compile dropped: " ^ why);
      result
  | Ok (proc, seed, mapping, repeatable, reason) -> (
      let gate =
        if repeatable then "replay"
        else if repair <> None then "agreement-repair"
        else "agreement"
      in
      let origin =
        match prior with
        | Some p -> Some p
        | None -> Option.bind repair (fun (p : B.procedure) -> p.provenance)
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
              Option.fold
                ~none:(List.map (name_kind mapping) (matching_path first))
                ~some:(fun (p : B.provenance) -> p.path)
                prior;
            entry_kind =
              Option.fold
                ~none:
                  (Option.fold ~none:""
                     ~some:(fun (p : B.provenance) -> p.entry_kind)
                     origin)
                ~some:(fun (op : O.t) -> op.entry_kind)
                operation;
            exit_kind =
              Option.fold
                ~none:
                  (Option.fold ~none:""
                     ~some:(fun (p : B.provenance) -> p.exit_kind)
                     origin)
                ~some:(fun (op : O.t) -> op.exit_kind)
                operation;
            signature =
              Option.fold
                ~none:
                  (Option.fold ~none:[]
                     ~some:(fun (p : B.provenance) -> p.signature)
                     origin)
                ~some:O.signature operation;
            kind_mapping = mapping;
            repeatable;
            reason;
            gate;
            repair =
              Option.fold ~none:(repair <> None)
                ~some:(fun (p : B.provenance) -> p.repair)
                prior;
            model_calls = meter.calls;
            model_cost = priced meter;
          }
      in
      let proc = B.with_learned_timeout { proc with B.provenance = Some provenance } in
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

let after_trace_unmetered t ~meter ~store ~file trace result =
  if t.config.mode = Config.Learning_mode.Off || trace.Trace.site = "unknown" then result
  else
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
              when t.config.mode = Config.Learning_mode.Auto && provenance.repeatable ->
                if
                  done_
                  && attempted.outcome = "verified"
                  && List.for_all
                       (fun (script : B.script) ->
                         List.exists
                           (fun (ran : P.run_script) ->
                             ran.script = script.name && ran.error = None)
                           attempted.scripts)
                       draft.book.scripts
                  && attempted.expectations <> []
                  && List.for_all
                       (fun (e : P.run_expectation) -> e.passed)
                       attempted.expectations
                then
                  install ?revision:attempted.revision
                    ~replayed_scripts:
                      (List.map (fun (s : P.run_script) -> s.script) attempted.scripts)
                    t draft.file draft.proc.slug result
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
                  if tries >= t.config.max_tries || List.mem draft.proc.slug !retired then (
                    (match archive t draft with Ok () -> () | Error why -> t.warn why);
                    result)
                  else
                    let p =
                      {
                        provenance with
                        B.tries;
                        last_failure =
                          Some
                            (Option.value ~default:"expectation failed" attempted.reason);
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
                            B.scripts = draft.book.playbook.scripts;
                            procedures = [ proc ];
                          }
                        in
                        compile ~prior:p ~revision:(B.draft_revision updated) t ~meter
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
        if List.mem draft.proc.slug !retired && draft.book.playbook.site = trace.site then
          match archive t draft with Ok () -> () | Error why -> t.warn why)
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
                (fun d -> d.book.playbook.site = trace.site && d.proc.slug = failure.slug)
                pending) -> (
        match
          List.find_opt
            (fun (p : B.procedure) -> p.slug = failure.slug)
            book.playbook.procedures
        with
        | Some proc ->
            compile t ~meter ~files:[ file ] ~traces:[ trace ] ~existing
              ~repair:(Some proc) ~snapshot:result.final result
        | None -> result)
    | _ when done_ ->
        (* map-op03: one independent stored trace votes once for an operation.
           compiled is historical provenance, not a whole-trace consumption bit. *)
        let candidates =
          match Traces.list store ~site:trace.site ~outcome:"done" () with
          | Ok rows -> rows
          | Error why ->
              t.warn why;
              []
        in
        let vocabulary =
          Option.to_list existing
          @ List.map
              (fun draft -> draft.book)
              (List.filter (fun draft -> draft.book.playbook.site = trace.site) pending)
        in
        let declared =
          List.concat_map (fun (book : B.loaded) -> book.playbook.pages) vocabulary
        in
        let mapping =
          List.concat_map
            (fun (book : B.loaded) -> Learning_pages.mapping book.playbook)
            vocabulary
        in
        List.fold_left
          (fun (result : P.run_result) (operation : O.t) ->
            let pending =
              proposals t |> List.filter (fun d -> d.book.playbook.site = trace.site)
            in
            let installed =
              match B.list ~caps:t.caps () with
              | Ok books ->
                  List.find_opt (fun (b : B.loaded) -> b.playbook.site = trace.site) books
              | Error _ -> existing
            in
            let covered (proc : B.procedure) =
              Option.fold ~none:false
                ~some:(fun (p : B.provenance) ->
                  p.entry_kind = operation.entry_kind
                  &&
                  if p.repeatable && operation.repeatable then
                    p.exit_kind = operation.exit_kind
                    && O.compatible p.signature (O.signature operation)
                  else p.signature = O.signature operation)
                proc.provenance
            in
            let covered =
              Option.fold ~none:false
                ~some:(fun (b : B.loaded) -> List.exists covered b.playbook.procedures)
                installed
              || List.exists (fun d -> covered d.proc) pending
            in
            let cohort =
              List.filter_map
                (fun (file, trace) ->
                  Option.map
                    (fun op -> (file, O.project trace op))
                    (List.find_opt (O.agrees operation)
                       (O.segment ~mapping ~declared trace)))
                candidates
              |> List.sort (fun (_, (a : Trace.t)) (_, (b : Trace.t)) ->
                  String.compare a.time b.time)
            in
            if
              covered || operation.entry_kind = ""
              || List.length cohort < t.config.successes
            then result
            else
              let cohort = List.filteri (fun i _ -> i < t.config.successes) cohort in
              (* A preceding operation's proposal is also vocabulary for this site's map. *)
              let existing =
                match (installed, pending) with
                | None, [] -> None
                | base, _ ->
                    let base =
                      match base with Some book -> book | None -> (List.hd pending).book
                    in
                    let playbook =
                      List.fold_left
                        (fun (book : B.t) draft ->
                          let add_page pages (page : B.page) =
                            if
                              List.exists
                                (fun (old : B.page) ->
                                  old.name = page.name
                                  || old.url_pattern = page.url_pattern)
                                pages
                            then pages
                            else pages @ [ page ]
                          in
                          let add_proc procs (proc : B.procedure) =
                            if
                              List.exists
                                (fun (old : B.procedure) -> old.slug = proc.slug)
                                procs
                            then procs
                            else procs @ [ proc ]
                          in
                          {
                            book with
                            pages =
                              List.fold_left add_page book.pages draft.book.playbook.pages;
                            procedures =
                              List.fold_left add_proc book.procedures
                                draft.book.playbook.procedures;
                          })
                        base.playbook pending
                    in
                    Some { base with playbook }
              in
              compile
                ?entry_url:(O.first_entry ~mapping ~declared trace)
                ~operation t ~meter ~files:(List.map fst cohort)
                ~traces:(List.map snd cohort) ~existing ~repair:None
                ~snapshot:result.final result)
          result
          (O.segment ~mapping ~declared trace)
    | _ -> result

(* Compile, confirmation and repair run after the reply, on the service switch,
   serialized per site. Their cost is learning state and proposal provenance, not the
   reply or the durable mission totals. *)
let after_trace t ~store ~file trace result =
  if t.config.mode = Config.Learning_mode.Off || trace.Trace.site = "unknown" then result
  else (
    schedule t ~site:trace.site (fun () ->
        let meter = empty_meter () in
        ignore (after_trace_unmetered t ~meter ~store ~file trace result);
        if meter.calls > 0 then record_account t trace.site meter);
    result)
