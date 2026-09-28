(* run-tcuz run-r1e9 run-2lei run-84ds run-zmz8: playbooks are author-owned
   JSON data, never model-addressable browser targets. *)
type page = {
  name : string;
  description : string;
  url_pattern : string option;
  text_marker : string option;
}
[@@deriving yojson]

type goal_step = { goal : string; hint : string option } [@@deriving yojson]

type use_step = { use : string; args : Yojson.Safe.t option; optional : bool option }
[@@deriving yojson]

type step = Goal of goal_step | Use of use_step

let step_of_yojson = function
  | `Assoc fields as json ->
      if List.mem_assoc "goal" fields && not (List.mem_assoc "use" fields) then
        Result.map (fun x -> Goal x) (goal_step_of_yojson json)
      else if List.mem_assoc "use" fields && not (List.mem_assoc "goal" fields) then
        Result.map (fun x -> Use x) (use_step_of_yojson json)
      else Error "step must have exactly one of goal or use"
  | _ -> Error "step must be an object"

let yojson_of_step = function
  | Goal step -> yojson_of_goal_step step
  | Use step -> yojson_of_use_step step

type procedure = {
  slug : string;
  description : string;
  args : string list option;
  steps : step list;
  expect : string list;
  expect_timeout_s : int option;
  max_steps : int option;
      (* L31 run-d82w: the cap one step of this procedure runs the operator level under;
         [None] is the operator's own default. *)
  deadline_s : int option;
      (* L31 run-d82w: the same step's own deadline, still bounded by what is left of the
         run. *)
}
[@@deriving yojson]

type t = {
  site : string;
  entry : string;
  description : string;
  pages : page list;
  procedures : procedure list;
}
[@@deriving yojson]

type checker =
  | Page_kind of string
  | Text of string
  | Download of string option
  | No_dialog
  | Row of string * string
  | Judgment of string

type loaded = { file : string; playbook : t; checks : (string * checker list) list }

(* run-m0r8: a planner-written procedure is proposed to the operator, never merged by the
   run: the proposal file names the site it belongs to and carries the procedure in the
   playbook's own schema, so the [playbook accept] command can merge it under the
   operator's hand. *)
type proposal = { site : string; procedure : procedure } [@@deriving yojson]

(* run-m0r8: what [playbook accept] did — which site, which slug, the playbook file it
   wrote and whether the slug replaced one that was already there. *)
type accepted = { site : string; slug : string; playbook : string; replaced : bool }
[@@deriving yojson]

let lower = String.lowercase_ascii
let trim = String.trim
let starts prefix s = String.starts_with ~prefix s

let contains ~needle haystack =
  let needle = lower needle and haystack = lower haystack in
  let n = String.length needle in
  let rec loop i =
    i + n <= String.length haystack && (String.sub haystack i n = needle || loop (i + 1))
  in
  loop 0

let strip_dot s =
  let s = trim s in
  if String.ends_with ~suffix:"." s then String.sub s 0 (String.length s - 1) else s

(* run-tny5 run-vbys: resolution is explicit, inspectable, and never fabricates a
   selector. An apparent page-kind typo is rejected rather than scored by JEV. *)
let resolve pages sentence =
  let s = lower (strip_dot sentence) in
  let after prefix =
    String.sub s (String.length prefix) (String.length s - String.length prefix) |> trim
  in
  if starts "the page is " s then
    let kind = after "the page is " in
    if List.exists (fun (p : page) -> lower p.name = kind) pages then Ok (Page_kind kind)
    else Error ("unknown page kind " ^ kind)
  else if starts "the page shows " s || starts "the page contains " s then
    let word =
      if starts "the page shows " s then "the page shows " else "the page contains "
    in
    let text = after word in
    if text = "" then Ok (Judgment sentence) else Ok (Text text)
  else if s = "a file was downloaded" then Ok (Download None)
  else if s = "a pdf was downloaded" || s = "a pdf file was downloaded" then
    Ok (Download (Some "application/pdf"))
  else if s = "no dialog is open" then Ok No_dialog
  else if
    starts "a " s && contains ~needle:" named " s
    && String.ends_with ~suffix:" is present" s
  then
    let rest = after "a " in
    match String.index_opt rest ' ' with
    | Some space
      when starts "named " (String.sub rest (space + 1) (String.length rest - space - 1))
      ->
        let role = String.sub rest 0 space in
        let name =
          String.sub rest (space + 7)
            (String.length rest - space - 7 - String.length " is present")
          |> trim
        in
        if name = "" then Ok (Judgment sentence) else Ok (Row (role, name))
    | _ -> Ok (Judgment sentence)
  else Ok (Judgment sentence)

let wildcard pattern value =
  let pattern = lower pattern and value = lower value in
  let pieces = String.split_on_char '*' pattern in
  match pieces with
  | [ one ] -> one = value
  | _ -> (
      let rec consume offset = function
        | [] -> true
        | [ last ] ->
            String.ends_with ~suffix:last value
            && String.length value - String.length last >= offset
        | piece :: tail ->
            let rec seek i =
              if i + String.length piece > String.length value then false
              else if String.sub value i (String.length piece) = piece then
                consume (i + String.length piece) tail
              else seek (i + 1)
            in
            seek offset
      in
      match pieces with
      | first :: tail when starts first value -> consume (String.length first) tail
      | _ -> false)

let page_kind pages ~url ~text =
  List.find_map
    (fun (page : page) ->
      if
        Option.fold ~none:false ~some:(fun p -> wildcard p url) page.url_pattern
        || Option.fold ~none:false
             ~some:(fun marker -> contains ~needle:marker text)
             page.text_marker
      then Some page.name
      else None)
    pages

let valid_name s =
  s <> ""
  && String.for_all
       (function 'a' .. 'z' | '0' .. '9' | '-' | '_' -> true | _ -> false)
       s

(* run-rq6i run-m0r8: the rules one procedure must satisfy. The loader applies them to
   every procedure of a file; L32 applies the same function to a planner's answer before
   the loop executes it and to a proposal before it is merged, because a procedure that did
   not come from a validated file can break two things a file cannot: it can call itself —
   a runaway recursion the file's cycle walk would have caught — and its expectations can
   name a page kind the playbook does not declare. [file] only names the origin in the
   message. *)
let check_procedure ?(file = "<procedure>") (book : t) (proc : procedure) =
  let ( let* ) = Result.bind in
  let procedure = proc.slug in
  let refuse reason =
    Error (Printf.sprintf "%s: procedure %s: %s" file procedure reason)
  in
  let require condition message = if condition then Ok () else refuse message in
  let unique names =
    List.length names = List.length (List.sort_uniq String.compare names)
  in
  let slugs = List.map (fun (p : procedure) -> p.slug) book.procedures in
  let* () = require (valid_name procedure) "slug must be a lowercase slug" in
  let* () = require (trim proc.description <> "") "description must not be empty" in
  let* () =
    require
      (proc.expect <> [] && List.for_all (fun s -> trim s <> "") proc.expect)
      "expect must be a non-empty list of sentences"
  in
  let* () = require (proc.steps <> []) "steps must not be empty" in
  let* () =
    require
      (Option.fold ~none:true ~some:(fun n -> n > 0 && n <= 30) proc.expect_timeout_s)
      "expect_timeout_s must be 1..30"
  in
  (* L31 run-d82w: a step's own bounds are the operator level's, so they carry its
     limits: at most 30 steps, and a deadline the drive accepts. *)
  let* () =
    require
      (Option.fold ~none:true ~some:(fun n -> n > 0 && n <= 30) proc.max_steps)
      "max_steps must be 1..30"
  in
  let* () =
    require
      (Option.fold ~none:true ~some:(fun n -> n > 0 && n <= 600) proc.deadline_s)
      "deadline_s must be 1..600"
  in
  let* () =
    require
      (Option.fold ~none:true
         ~some:(fun xs -> unique xs && List.for_all valid_name xs)
         proc.args)
      "args must be unique lowercase names"
  in
  let rec steps = function
    | [] -> Ok ()
    | Goal goal :: tail ->
        let* () = require (trim goal.goal <> "") "goal must not be empty" in
        steps tail
    | Use use :: tail ->
        let* () =
          if use.use = procedure then
            refuse ("cycle of use: " ^ procedure ^ " -> " ^ use.use)
          else require (List.mem use.use slugs) ("use of unknown slug " ^ use.use)
        in
        let* () =
          require
            (match use.args with
            | None -> true
            | Some (`Assoc fields) ->
                List.for_all (function _, `String _ -> true | _ -> false) fields
            | Some _ -> false)
            "use args must be an object of strings"
        in
        steps tail
  in
  let* () = steps proc.steps in
  let rec expectations = function
    | [] -> Ok ()
    | sentence :: tail ->
        let* _ =
          Result.map_error
            (fun reason -> Printf.sprintf "%s: procedure %s: %s" file procedure reason)
            (resolve book.pages sentence)
        in
        expectations tail
  in
  expectations proc.expect

let validate ~file (book : t) =
  let ( let* ) = Result.bind in
  let refuse ?(procedure = "<playbook>") reason =
    Error (Printf.sprintf "%s: procedure %s: %s" file procedure reason)
  in
  let require condition ?procedure message =
    if condition then Ok () else refuse ?procedure message
  in
  let unique names =
    List.length names = List.length (List.sort_uniq String.compare names)
  in
  let* () =
    require (book.site <> "" && not (String.contains book.site '/')) "invalid site"
  in
  let* () =
    require
      (starts "https://" book.entry || starts "http://" book.entry)
      "entry must be an HTTP(S) URL"
  in
  let* () =
    require
      (not (String.contains book.entry '@'))
      "entry URL must not contain credentials"
  in
  let* () = require (trim book.description <> "") "description must not be empty" in
  let names = List.map (fun (p : page) -> p.name) book.pages in
  let* () =
    require
      (unique names && List.for_all valid_name names)
      "page kind names must be unique lowercase slugs"
  in
  let* () =
    let rec pages = function
      | [] -> Ok ()
      | (p : page) :: rest ->
          let* () =
            require
              (p.url_pattern <> None || p.text_marker <> None)
              ("page kind " ^ p.name ^ " needs url_pattern or text_marker")
          in
          pages rest
    in
    pages book.pages
  in
  let* () =
    require
      (List.length book.procedures <= 200)
      "more than 200 procedures (255-option JEV ceiling)"
  in
  let slugs = List.map (fun (p : procedure) -> p.slug) book.procedures in
  let* () =
    require
      (unique slugs && List.for_all valid_name slugs)
      "procedure slugs must be unique lowercase slugs"
  in
  let rec procedures = function
    | [] -> Ok ()
    | (proc : procedure) :: rest ->
        let* () = check_procedure ~file book proc in
        procedures rest
  in
  let* () = procedures book.procedures in
  let rec visit path slug =
    if List.mem slug path then
      refuse ~procedure:slug
        ("cycle of use: " ^ String.concat " -> " (List.rev (slug :: path)))
    else
      let proc = List.find (fun (p : procedure) -> p.slug = slug) book.procedures in
      let rec steps = function
        | [] -> Ok ()
        | Goal _ :: tail -> steps tail
        | Use use :: tail ->
            let* () = visit (slug :: path) use.use in
            steps tail
      in
      steps proc.steps
  in
  let rec cycles = function
    | [] -> Ok ()
    | (p : procedure) :: tail ->
        let* () = visit [] p.slug in
        cycles tail
  in
  let* () = cycles book.procedures in
  let checks =
    List.map
      (fun (p : procedure) ->
        ( p.slug,
          List.map
            (fun sentence ->
              match resolve book.pages sentence with Ok c -> c | Error _ -> assert false)
            p.expect ))
      book.procedures
  in
  Ok { file; playbook = book; checks }

let of_json ~file json =
  match t_of_yojson json with
  | Error reason -> Error (file ^ ": " ^ reason)
  | Ok book -> validate ~file book

let load file =
  if not (String.ends_with ~suffix:".json" file) then
    Error (file ^ ": playbooks use JSON (<site>.json); YAML is not supported")
  else
    try
      let ch = open_in_bin file in
      Fun.protect
        ~finally:(fun () -> close_in ch)
        (fun () ->
          let json = Yojson.Safe.from_channel ch in
          of_json ~file json)
    with
    | Sys_error reason -> Error (file ^ ": " ^ reason)
    | Yojson.Json_error reason -> Error (file ^ ": invalid JSON: " ^ reason)

let directory () =
  let home =
    match Sys.getenv_opt "XDG_CONFIG_HOME" with
    | Some s when s <> "" -> s
    | _ -> Filename.concat (Option.value ~default:"." (Sys.getenv_opt "HOME")) ".config"
  in
  Filename.concat (Filename.concat home "leash") "playbooks"

let list () =
  let dir = directory () in
  if not (Sys.file_exists dir) then Ok []
  else
    try
      let files = Sys.readdir dir |> Array.to_list |> List.sort String.compare in
      let rec collect acc = function
        | [] -> Ok (List.rev acc)
        | file :: tail ->
            if
              String.ends_with ~suffix:".json" file
              || String.ends_with ~suffix:".yaml" file
            then
              match load (Filename.concat dir file) with
              | Error _ as error -> error
              | Ok book -> collect (book :: acc) tail
            else collect acc tail
      in
      collect [] files
    with Sys_error reason -> Error (dir ^ ": " ^ reason)

let show name =
  if
    name = "" || name = "." || name = ".." || String.contains name '/'
    || String.contains name '\\' || String.contains name '\000'
    || String.contains name '*' || String.contains name '?'
  then Error (name ^ ": invalid playbook name")
  else load (Filename.concat (directory ()) (name ^ ".json"))

(* run-m0r8: the XDG state directory proposals live in, resolved the way the config
   directory is: [$XDG_STATE_HOME/leash/proposed], [$HOME/.local/state] when the variable
   is unset. The run writes here and nowhere else — the playbook an operator authored is
   never touched automatically (story 32). *)
let proposed_directory () =
  let home =
    match Sys.getenv_opt "XDG_STATE_HOME" with
    | Some s when s <> "" -> s
    | _ ->
        Filename.concat (Option.value ~default:"." (Sys.getenv_opt "HOME")) ".local/state"
  in
  Filename.concat (Filename.concat home "leash") "proposed"

(* run-m0r8: write one proposed procedure to
   [<state>/leash/proposed/<site>-<slug>.json], 0600 in a private directory. A run calls
   this once a planner-written procedure has run and passed its expectations; it never
   writes to the playbook directory. *)
let propose ~site (proc : procedure) =
  let directory = proposed_directory () in
  let path = Filename.concat directory (site ^ "-" ^ proc.slug ^ ".json") in
  match Config.ensure_dir directory with
  | Error message -> Error (path ^ ": " ^ message)
  | Ok () -> (
      let json =
        Yojson.Safe.pretty_to_string (yojson_of_proposal { site; procedure = proc })
        ^ "\n"
      in
      try
        let channel =
          open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 path
        in
        Fun.protect
          ~finally:(fun () -> close_out channel)
          (fun () -> output_string channel json);
        Unix.chmod path 0o600;
        Ok path
      with Sys_error message -> Error (path ^ ": " ^ message))

(* run-3vat: the complete discovery proposal lives in XDG state, never config. *)
let propose_book (book : t) =
  let directory = proposed_directory () in
  let path = Filename.concat directory (book.site ^ ".json") in
  match (validate ~file:path book, Config.ensure_dir directory) with
  | Error why, _ | _, Error why -> Error why
  | Ok _, Ok () -> (
      try
        let channel =
          open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 path
        in
        Fun.protect
          ~finally:(fun () -> close_out channel)
          (fun () ->
            output_string channel (Yojson.Safe.pretty_to_string (yojson_of_t book) ^ "\n"));
        Unix.chmod path 0o600;
        Ok path
      with Sys_error why -> Error (path ^ ": " ^ why))

let read_proposal path =
  try
    let channel = open_in_bin path in
    Fun.protect
      ~finally:(fun () -> close_in channel)
      (fun () ->
        match proposal_of_yojson (Yojson.Safe.from_channel channel) with
        | Ok proposal -> Ok proposal
        | Error reason -> Error (path ^ ": " ^ reason))
  with
  | Sys_error reason -> Error (path ^ ": " ^ reason)
  | Yojson.Json_error reason -> Error (path ^ ": invalid JSON: " ^ reason)

(* run-m0r8: the installed playbook a proposal's site names. A site served by two files is
   refused rather than guessed: the operator resolves which file is the site's before the
   merge. *)
let installed_for_site site =
  match list () with
  | Error _ as error -> error
  | Ok books -> (
      match List.filter (fun (book : loaded) -> book.playbook.site = site) books with
      | [] -> Error (Printf.sprintf "no installed playbook for site %s" site)
      | [ book ] -> Ok book
      | books ->
          Error
            (Printf.sprintf "site %s is served by %d playbooks: %s" site
               (List.length books)
               (String.concat ", " (List.map (fun (book : loaded) -> book.file) books))))

(* run-m0r8: what the [playbook accept] command does — read the proposal, merge its
   procedure into the site's playbook by slug (replacing the same slug, appending
   otherwise), refuse the merge unless the merged playbook validates, and only then write
   it back. The proposal file is left where it is. *)
let accept path =
  let ( let* ) = Result.bind in
  let* json =
    try Ok (Yojson.Safe.from_file path) with
    | Sys_error why -> Error (path ^ ": " ^ why)
    | Yojson.Json_error why -> Error (path ^ ": invalid JSON: " ^ why)
  in
  if match json with `Assoc fields -> List.mem_assoc "entry" fields | _ -> false then
    let* discovered = of_json ~file:path json in
    let draft = discovered.playbook in
    let* existing =
      match installed_for_site draft.site with
      | Ok book -> Ok (Some book)
      | Error why when String.starts_with ~prefix:"no installed playbook" why -> Ok None
      | Error why -> Error why
    in
    let merged, destination, replaced =
      match existing with
      | None -> (draft, Filename.concat (directory ()) (draft.site ^ ".json"), false)
      | Some book ->
          let pages =
            book.playbook.pages
            @ List.filter
                (fun (page : page) ->
                  not
                    (List.exists
                       (fun (old : page) -> old.name = page.name)
                       book.playbook.pages))
                draft.pages
          in
          let procedures =
            List.fold_left
              (fun current (proc : procedure) ->
                if List.exists (fun (old : procedure) -> old.slug = proc.slug) current
                then
                  List.map
                    (fun (old : procedure) -> if old.slug = proc.slug then proc else old)
                    current
                else current @ [ proc ])
              book.playbook.procedures draft.procedures
          in
          ({ book.playbook with pages; procedures }, book.file, true)
    in
    let* _ = validate ~file:destination merged in
    let* () = Config.ensure_dir (Filename.dirname destination) in
    try
      let channel =
        open_out_gen
          [ Open_wronly; Open_creat; Open_trunc; Open_binary ]
          0o600 destination
      in
      Fun.protect
        ~finally:(fun () -> close_out channel)
        (fun () ->
          output_string channel (Yojson.Safe.pretty_to_string (yojson_of_t merged) ^ "\n"));
      Ok { site = draft.site; slug = "*"; playbook = destination; replaced }
    with Sys_error why -> Error (destination ^ ": " ^ why)
  else
    let* proposal = read_proposal path in
    let* (book : loaded) = installed_for_site proposal.site in
    let replaced =
      List.exists
        (fun (proc : procedure) -> proc.slug = proposal.procedure.slug)
        book.playbook.procedures
    in
    let procedures =
      if replaced then
        List.map
          (fun (proc : procedure) ->
            if proc.slug = proposal.procedure.slug then proposal.procedure else proc)
          book.playbook.procedures
      else book.playbook.procedures @ [ proposal.procedure ]
    in
    let merged = { book.playbook with procedures } in
    let* (_ : loaded) = validate ~file:book.file merged in
    let json = Yojson.Safe.pretty_to_string (yojson_of_t merged) ^ "\n" in
    try
      let channel =
        open_out_gen [ Open_wronly; Open_creat; Open_trunc; Open_binary ] 0o600 book.file
      in
      (* The operator's playbook keeps whatever mode it had: this rewrite is a merge into a
       file that already exists, and a playbook holds no secret. *)
      Fun.protect
        ~finally:(fun () -> close_out channel)
        (fun () -> output_string channel json);
      Ok
        {
          site = proposal.site;
          slug = proposal.procedure.slug;
          playbook = book.file;
          replaced;
        }
    with Sys_error message -> Error (book.file ^ ": " ^ message)

(* L31 run-xqh8: the checker's kind as the run's trace names it, which is also what
   [playbook check] reports a sentence resolved to. *)
let checker_name = function
  | Page_kind _ -> "page_kind"
  | Text _ -> "text"
  | Download _ -> "download"
  | No_dialog -> "no_dialog"
  | Row _ -> "row"
  | Judgment _ -> "judgment"

let yojson_of_checker = function
  | Page_kind name -> `Assoc [ ("checker", `String "page_kind"); ("kind", `String name) ]
  | Text value -> `Assoc [ ("checker", `String "text"); ("text", `String value) ]
  | Download mime ->
      `Assoc
        [
          ("checker", `String "download");
          ("mime", match mime with None -> `Null | Some s -> `String s);
        ]
  | No_dialog -> `Assoc [ ("checker", `String "no_dialog") ]
  | Row (role, name) ->
      `Assoc
        [ ("checker", `String "row"); ("role", `String role); ("name", `String name) ]
  | Judgment sentence ->
      `Assoc [ ("checker", `String "judgment"); ("sentence", `String sentence) ]

(* run-k8bx: a failed verification replays the whole procedure once, never just
   its last step. The L31 loop owns the trace and records a second failure. *)
let retry_once ~execute ~verify =
  execute ();
  if verify () then true
  else (
    execute ();
    verify ())

let inspect book =
  let checks =
    List.map
      (fun (slug, checkers) ->
        `Assoc
          [
            ("procedure", `String slug);
            ("checkers", `List (List.map yojson_of_checker checkers));
          ])
      book.checks
  in
  `Assoc
    [
      ("file", `String book.file);
      ("playbook", yojson_of_t book.playbook);
      ("resolved", `List checks);
    ]

type observation = {
  kind : string option;
  text : string;
  dialog : bool;
  rows : (string * string) list;
  downloads : (string * string * string) list;
}

(* run-2lei run-5rll: {name} is the format's one substitution, applied to a step's goal and
   to an expectation sentence from the values the run knows. A name with no value is left
   as it stands: the loader refused every argument a procedure does not declare, so an
   unfilled placeholder is a value the run has yet to ask for, not a defect. *)
let substitute values text =
  let buffer = Buffer.create (String.length text) in
  let rec scan i =
    if i >= String.length text then ()
    else if text.[i] = '{' then (
      match String.index_from_opt text (i + 1) '}' with
      | Some close -> (
          let name = String.sub text (i + 1) (close - i - 1) in
          match List.assoc_opt name values with
          | Some value ->
              Buffer.add_string buffer value;
              scan (close + 1)
          | None ->
              Buffer.add_char buffer text.[i];
              scan (i + 1))
      | None ->
          Buffer.add_char buffer text.[i];
          scan (i + 1))
    else (
      Buffer.add_char buffer text.[i];
      scan (i + 1))
  in
  scan 0;
  Buffer.contents buffer

(* run-tny5 run-vj48: each expectation as the sentence it is, next to the checker the
   loader resolved it to. The run substitutes its known arguments into the sentence
   first, so "the page shows {product}" is checked for the product the mission named; a
   substituted sentence the grammar no longer matches is judged by JEV rather than
   refused, because the authored form was validated at load. *)
let resolved ?(values = []) (book : t) (proc : procedure) =
  List.map
    (fun sentence ->
      let sentence = substitute values sentence in
      match resolve book.pages sentence with
      | Ok checker -> (sentence, checker)
      | Error _ -> (sentence, Judgment sentence))
    proc.expect

type checked = {
  expectation : string;
  checker : checker;
  passed : bool;
  score : float option;
}

(* run-l06s run-vbys run-xqh8: one checker against one observation. Judgment is never
   decided here — the score question is the runner's — so only the deterministic checkers
   are evaluated in code. *)
let passes checker (snapshot : observation) =
  match checker with
  | Page_kind kind -> snapshot.kind = Some kind
  | Text text -> contains ~needle:text snapshot.text
  | Download mime ->
      List.exists
        (fun (name, media, state) ->
          state = "completed" && name <> ""
          && Option.fold ~none:true
               ~some:(fun required -> contains ~needle:required media)
               mime)
        snapshot.downloads
  | No_dialog -> not snapshot.dialog
  | Row (role, name) ->
      List.exists
        (fun (r, n) -> lower r = lower role && contains ~needle:name n)
        snapshot.rows
  | Judgment _ -> assert false

(* run-l06s run-vbys: the bounded wait, keeping what each expectation came to, so the run's
   trace can say which checker decided it and — for a judgment — the score it carried. The
   result is the last observation's verdicts: the one that passed everything, or the one
   the deadline found. No sleeping after the deadline; each observation is fresh. *)
let await_results ~now ~sleep ~observe ~score ?(threshold = 0.8) ?(timeout_s = 5) checks =
  let deadline = now () +. float_of_int timeout_s in
  let evaluate () =
    let snapshot = observe () in
    List.map
      (fun (sentence, checker) ->
        match checker with
        | Judgment _ ->
            let value = score sentence snapshot in
            {
              expectation = sentence;
              checker;
              passed = value >= threshold;
              score = Some value;
            }
        | checker ->
            {
              expectation = sentence;
              checker;
              passed = passes checker snapshot;
              score = None;
            })
      checks
  in
  let rec loop () =
    let results = evaluate () in
    if List.for_all (fun (result : checked) -> result.passed) results then results
    else if now () >= deadline then results
    else (
      sleep (min 0.1 (deadline -. now ()));
      loop ())
  in
  loop ()

let await ~now ~sleep ~observe ~score ?threshold ?timeout_s checks =
  List.for_all
    (fun (result : checked) -> result.passed)
    (await_results ~now ~sleep ~observe ~score ?threshold ?timeout_s
       (List.map (fun checker -> ("", checker)) checks))
