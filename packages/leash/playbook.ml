(* run-tcuz run-r1e9 run-2lei run-84ds run-zmz8: playbooks are author-owned
   JSON data, never model-addressable browser targets. *)
module Cap = Ox_caps.Cap
module Cap_stdlib = Ox_caps.Cap_stdlib
module Cap_sys = Ox_caps.Cap_sys
module Cap_unix = Ox_caps.Cap_unix

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

(* extr-8o1h: a step that runs one of the playbook's own scripts by name; [args] are
   strings with the run's placeholders substituted, like a [use] step's. *)
type script_step = { script : string; args : Yojson.Safe.t option } [@@deriving yojson]

type step =
  | Goal of goal_step
  | Use of use_step
  | Script of script_step
  | Navigate of script_step

let step_of_yojson = function
  | `Assoc fields as json -> (
      match
        List.filter
          (fun key -> List.mem_assoc key fields)
          [ "goal"; "use"; "script"; "navigate" ]
      with
      | [ "goal" ] -> Result.map (fun x -> Goal x) (goal_step_of_yojson json)
      | [ "use" ] -> Result.map (fun x -> Use x) (use_step_of_yojson json)
      | [ "script" ] -> Result.map (fun x -> Script x) (script_step_of_yojson json)
      | [ "navigate" ] when List.length fields = 1 ->
          Result.map
            (fun x -> Navigate x)
            (script_step_of_yojson (List.assoc "navigate" fields))
      | _ -> Error "step must have exactly one of goal, use or script")
  | _ -> Error "step must be an object"

let yojson_of_step = function
  | Goal step -> yojson_of_goal_step step
  | Use step -> yojson_of_use_step step
  | Script step -> yojson_of_script_step step
  | Navigate step -> `Assoc [ ("navigate", yojson_of_script_step step) ]

type repeat_until = Expectation of string | Script_check of string

let repeat_until_of_yojson = function
  | `String sentence -> Ok (Expectation sentence)
  | `Assoc [ ("script", `String name) ] -> Ok (Script_check name)
  | _ -> Error "repeat until must be an expectation or {script: name}"

let yojson_of_repeat_until = function
  | Expectation sentence -> `String sentence
  | Script_check name -> `Assoc [ ("script", `String name) ]

type repeat = {
  next : string;
  max : int;
  until : repeat_until;
  delay_ms : int option;
  key : string;
}
[@@deriving yojson]

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
  repeat : repeat option;
  deadline_s : int option;
      (* L31 run-d82w: the same step's own deadline, still bounded by what is left of the
         run. *)
}
[@@deriving yojson]

(* extr-plaz extr-zdst: a script as the playbook writes it — a file relative to the
   playbook directory or a short inline source, and the shape its result must have. *)
type script_decl = {
  file : string option;
  source : string option;
  returns : Shape.t;
  max_bytes : int option;
}
[@@deriving yojson]

(* The section is an object of script name to declaration; the derived list codec would
   write an array, so the two functions are the object's. *)
type scripts = (string * script_decl) list

let scripts_of_yojson = function
  | `Assoc members ->
      let rec go acc = function
        | [] -> Ok (List.rev acc)
        | (name, json) :: rest -> (
            match script_decl_of_yojson json with
            | Ok decl -> go ((name, decl) :: acc) rest
            | Error why -> Error (Printf.sprintf "script %s: %s" name why))
      in
      go [] members
  | _ -> Error "scripts must be an object of script name to declaration"

let yojson_of_scripts scripts =
  `Assoc (List.map (fun (name, decl) -> (name, yojson_of_script_decl decl)) scripts)

type t = {
  site : string;
  entry : string;
  description : string;
  pages : page list;
  procedures : procedure list;
  scripts : scripts option;
}
[@@deriving yojson]

type checker =
  | Page_kind of string
  | Not_page_kind of string
  | Text of string
  | Download of string option
  | No_dialog
  | Row of string * string
  | Judgment of string

(* extr-plaz extr-k40c: a script the loader has resolved. The record is private: the only
   values of this type are the ones [validate] builds from a playbook directory, and the
   only function that hands script text to the browser takes one — so nothing a model wrote
   can become a script. *)
type script = {
  name : string;
  code : string;
  returns : Shape.t;
  max_bytes : int;
  origin : string;
}

type loaded = {
  file : string;
  dir : string option;
  playbook : t;
  checks : (string * checker list) list;
  scripts : script list;
}

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
  if starts "the page is not " s then
    let kind = after "the page is not " in
    if List.exists (fun (p : page) -> lower p.name = kind) pages then
      Ok (Not_page_kind kind)
    else Error ("unknown page kind " ^ kind)
  else if starts "the page is " s then
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
  let script_names = List.map fst (Option.value ~default:[] book.scripts) in
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
  let* () =
    match proc.repeat with
    | None -> Ok ()
    | Some repeat ->
        let* () =
          require (repeat.max > 0 && repeat.max <= 1000) "repeat max must be 1..1000"
        in
        let* () =
          require
            (repeat.next <> procedure && List.mem repeat.next slugs)
            "repeat next must name another procedure"
        in
        let next =
          List.find (fun (p : procedure) -> p.slug = repeat.next) book.procedures
        in
        let* () = require (next.repeat = None) "repeat next must not itself repeat" in
        let* () =
          match repeat.until with
          | Expectation sentence ->
              require (trim sentence <> "") "repeat until must not be empty"
          | Script_check name ->
              require
                (List.mem_assoc name (Option.value ~default:[] book.scripts))
                "repeat until script must be declared"
        in
        let* () = require (trim repeat.key <> "") "repeat key must not be empty" in
        let* () =
          require
            (Option.fold ~none:true
               ~some:(fun ms -> ms >= 0 && ms <= 60_000)
               repeat.delay_ms)
            "repeat delay_ms must be 0..60000"
        in
        let* _ =
          match repeat.until with
          | Expectation sentence -> Result.map (fun _ -> ()) (resolve book.pages sentence)
          | Script_check _ -> Ok ()
        in
        Ok ()
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
    | (Script step | Navigate step) :: tail ->
        let* () =
          require
            (List.mem step.script script_names)
            ("script step names unknown script " ^ step.script)
        in
        let* () =
          require
            (match step.args with
            | None -> true
            | Some (`Assoc fields) ->
                List.for_all (function _, `String _ -> true | _ -> false) fields
            | Some _ -> false)
            "script args must be an object of strings"
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

(* extr-plaz: a script is a file relative to its playbook directory or a short inline
   source. A file is resolved at load: no absolute path, no [..] component, and the path
   after every symlink is resolved must still be inside the directory — a link may point
   at another file of the playbook, never out of it. The text is read here, once, so a run
   works from what the operator saw at load. *)
let default_max_bytes = 8 * 1024 * 1024
let ceiling_max_bytes = 16 * 1024 * 1024
let max_inline_bytes = 4096
let max_file_bytes = 1024 * 1024

(* ^ncaps-4tjy: a directory comes with the capability to read it; a playbook decoded
   without one (a discovery seed, a proposal) cannot name a file script. *)
let read_script_file ~dir file =
  let ( let* ) = Result.bind in
  let* caps, dir =
    match dir with
    | Some (caps, dir) -> Ok (caps, dir)
    | None -> Error "a file script needs a playbook directory"
  in
  let* () =
    if file = "" then Error "file must not be empty"
    else if String.contains file '\000' then Error "file must not contain NUL"
    else if not (Filename.is_relative file) then
      Error (Printf.sprintf "file %s must be relative to the playbook directory" file)
    else if List.mem ".." (String.split_on_char '/' file) then
      Error (Printf.sprintf "file %s must not contain .." file)
    else if not (String.ends_with ~suffix:".js" file) then
      Error (Printf.sprintf "file %s must be a .js file" file)
    else Ok ()
  in
  match (Unix.realpath dir, Unix.realpath (Filename.concat dir file)) with
  | exception Unix.Unix_error (why, _, _) ->
      Error (Printf.sprintf "file %s: %s" file (Unix.error_message why))
  | root, real -> (
      if not (starts (root ^ "/") real) then
        Error (Printf.sprintf "file %s resolves outside the playbook directory" file)
      else
        match Unix.stat real with
        | exception Unix.Unix_error (why, _, _) ->
            Error (Printf.sprintf "file %s: %s" file (Unix.error_message why))
        | { Unix.st_kind = Unix.S_REG; st_size; _ } -> (
            if st_size > max_file_bytes then
              Error (Printf.sprintf "file %s is over %d bytes" file max_file_bytes)
            else
              try Ok (Cap_stdlib.In_channel.with_open_bin ~caps real In_channel.input_all)
              with Sys_error why -> Error (Printf.sprintf "file %s: %s" file why))
        | _ -> Error (Printf.sprintf "file %s is not a regular file" file))

let resolve_scripts ~file ~dir (book : t) =
  let decls = Option.value ~default:[] book.scripts in
  let refuse name why = Error (Printf.sprintf "%s: script %s: %s" file name why) in
  let rec go seen acc = function
    | [] -> Ok (List.rev acc)
    | (name, (decl : script_decl)) :: rest -> (
        if not (valid_name name) then refuse name "name must be a lowercase slug"
        else if List.mem name seen then refuse name "declared twice"
        else
          match Shape.check_returns decl.returns with
          | Error why -> refuse name why
          | Ok () -> (
              match
                Option.fold ~none:(Ok default_max_bytes)
                  ~some:(fun n ->
                    if n >= 1 && n <= ceiling_max_bytes then Ok n
                    else
                      Error (Printf.sprintf "max_bytes must be 1..%d" ceiling_max_bytes))
                  decl.max_bytes
              with
              | Error why -> refuse name why
              | Ok max_bytes -> (
                  let code =
                    match (decl.file, decl.source) with
                    | Some path, None ->
                        Result.map
                          (fun code -> (code, "file " ^ path))
                          (read_script_file ~dir path)
                    | None, Some source ->
                        if String.length source > max_inline_bytes then
                          Error
                            (Printf.sprintf
                               "inline source is over %d bytes: put it in a file"
                               max_inline_bytes)
                        else Ok (source, "inline")
                    | _ -> Error "declare exactly one of file or source"
                  in
                  match code with
                  | Error why -> refuse name why
                  | Ok (code, origin) ->
                      if String.trim code = "" then refuse name "the script is empty"
                      else if String.contains code '\000' then
                        refuse name "the script contains NUL"
                      else
                        go (name :: seen)
                          ({ name; code; returns = decl.returns; max_bytes; origin }
                          :: acc)
                          rest)))
  in
  go [] [] decls

let validate ~file ~dir (book : t) =
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
    require
      (book.site <> "" && book.site <> "." && book.site <> ".."
      && (not (String.contains book.site '/'))
      && not (String.contains book.site '\000'))
      "invalid site"
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
        | (Goal _ | Script _ | Navigate _) :: tail -> steps tail
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
  let* scripts = resolve_scripts ~file ~dir book in
  Ok { file; dir = Option.map snd dir; playbook = book; checks; scripts }

let of_json ?dir ~file json =
  match t_of_yojson json with
  | Error reason -> Error (file ^ ": " ^ reason)
  | Ok book -> validate ~file ~dir book

(* The playbook as another playbook value, validated in the same directory: what a merge
   or a planner's procedure needs, so a file script is resolved against the directory it
   came from. *)
let reads caps = (caps : < Cap.fs_read ; .. > :> Cap.fs_read)

let revalidate ~caps (book : loaded) playbook =
  validate ~file:book.file
    ~dir:(Option.map (fun dir -> (reads caps, dir)) book.dir)
    playbook

(* extr-plaz: a playbook is a directory, [<name>/playbook.json] and whatever files sit
   beside it. Errors name the playbook.json path — or the path given when it is not a
   directory at all. *)
let load ~caps dir =
  let file = Filename.concat dir "playbook.json" in
  if Sys.file_exists dir && not (Sys.is_directory dir) then
    Error (dir ^ ": a playbook is a directory holding playbook.json, not a single file")
  else if not (Sys.file_exists file) then
    if
      Sys.file_exists (Filename.concat dir "playbook.yaml")
      || Sys.file_exists (Filename.concat dir "playbook.yml")
    then
      Error (file ^ ": playbooks use JSON (<name>/playbook.json); YAML is not supported")
    else Error (file ^ ": No such file or directory")
  else
    try
      let ch = Cap_stdlib.open_in_bin ~caps file in
      Fun.protect
        ~finally:(fun () -> close_in ch)
        (fun () ->
          let json = Yojson.Safe.from_channel ch in
          of_json ~dir:(reads caps, dir) ~file json)
    with
    | Sys_error reason -> Error (file ^ ": " ^ reason)
    | Yojson.Json_error reason -> Error (file ^ ": invalid JSON: " ^ reason)

let script_named (book : loaded) name =
  List.find_opt (fun (script : script) -> script.name = name) book.scripts

let directory ~caps () =
  let home =
    match Cap_sys.getenv_opt ~caps "XDG_CONFIG_HOME" with
    | Some s when s <> "" -> s
    | _ ->
        Filename.concat
          (Option.value ~default:"." (Cap_sys.getenv_opt ~caps "HOME"))
          ".config"
  in
  Filename.concat (Filename.concat home "leash") "playbooks"

let list ~caps () =
  let dir = directory ~caps () in
  if not (Sys.file_exists dir) then Ok []
  else
    try
      let files =
        Cap_sys.readdir ~caps dir |> Array.to_list |> List.sort String.compare
      in
      let rec collect acc = function
        | [] -> Ok (List.rev acc)
        | entry :: tail ->
            let path = Filename.concat dir entry in
            if String.starts_with ~prefix:"." entry then collect acc tail
            else if Sys.is_directory path then
              match load ~caps path with
              | Error _ as error -> error
              | Ok book -> collect (book :: acc) tail
            else if
              List.exists
                (fun suffix -> String.ends_with ~suffix entry)
                [ ".json"; ".yaml"; ".yml" ]
            then
              Error (path ^ ": playbooks are directories; move it to <name>/playbook.json")
            else collect acc tail
      in
      collect [] files
    with Sys_error reason -> Error (dir ^ ": " ^ reason)

let show ~caps name =
  if
    name = "" || name = "." || name = ".." || String.contains name '/'
    || String.contains name '\\' || String.contains name '\000'
    || String.contains name '*' || String.contains name '?'
  then Error (name ^ ": invalid playbook name")
  else load ~caps (Filename.concat (directory ~caps ()) name)

(* run-m0r8: the XDG state directory proposals live in, resolved the way the config
   directory is: [$XDG_STATE_HOME/leash/proposed], [$HOME/.local/state] when the variable
   is unset. The run writes here and nowhere else — the playbook an operator authored is
   never touched automatically (story 32). *)
let proposed_directory ~caps () =
  let home =
    match Cap_sys.getenv_opt ~caps "XDG_STATE_HOME" with
    | Some s when s <> "" -> s
    | _ ->
        Filename.concat
          (Option.value ~default:"." (Cap_sys.getenv_opt ~caps "HOME"))
          ".local/state"
  in
  Filename.concat (Filename.concat home "leash") "proposed"

(* run-m0r8: write one proposed procedure to
   [<state>/leash/proposed/<site>-<slug>.json], 0600 in a private directory. A run calls
   this once a planner-written procedure has run and passed its expectations; it never
   writes to the playbook directory. *)
let propose ~caps ~site (proc : procedure) =
  let directory = proposed_directory ~caps () in
  let path = Filename.concat directory (site ^ "-" ^ proc.slug ^ ".json") in
  match Config.ensure_dir ~caps directory with
  | Error message -> Error (path ^ ": " ^ message)
  | Ok () -> (
      let json =
        Yojson.Safe.pretty_to_string (yojson_of_proposal { site; procedure = proc })
        ^ "\n"
      in
      try
        let channel =
          Cap_stdlib.open_out_gen ~caps
            [ Open_wronly; Open_creat; Open_trunc; Open_binary ]
            0o600 path
        in
        Fun.protect
          ~finally:(fun () -> close_out channel)
          (fun () -> output_string channel json);
        Cap_unix.chmod ~caps path 0o600;
        Ok path
      with Sys_error message -> Error (path ^ ": " ^ message))

(* run-3vat: the complete discovery proposal lives in XDG state, never config. *)
let propose_book ~caps (book : t) =
  let directory = proposed_directory ~caps () in
  let path = Filename.concat directory (book.site ^ ".json") in
  match (validate ~file:path ~dir:None book, Config.ensure_dir ~caps directory) with
  | Error why, _ | _, Error why -> Error why
  | Ok _, Ok () -> (
      try
        let channel =
          Cap_stdlib.open_out_gen ~caps
            [ Open_wronly; Open_creat; Open_trunc; Open_binary ]
            0o600 path
        in
        Fun.protect
          ~finally:(fun () -> close_out channel)
          (fun () ->
            output_string channel (Yojson.Safe.pretty_to_string (yojson_of_t book) ^ "\n"));
        Cap_unix.chmod ~caps path 0o600;
        Ok path
      with Sys_error why -> Error (path ^ ": " ^ why))

let read_proposal ~caps path =
  try
    let channel = Cap_stdlib.open_in_bin ~caps path in
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
let installed_for_site ~caps site =
  match list ~caps () with
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
let accept ~caps path =
  let ( let* ) = Result.bind in
  let* json =
    try Ok (Cap_stdlib.In_channel.with_open_bin ~caps path Yojson.Safe.from_channel) with
    | Sys_error why -> Error (path ^ ": " ^ why)
    | Yojson.Json_error why -> Error (path ^ ": invalid JSON: " ^ why)
  in
  if match json with `Assoc fields -> List.mem_assoc "entry" fields | _ -> false then
    let* discovered = of_json ~file:path json in
    let draft = discovered.playbook in
    (* extr-k40c: a discovered playbook was written by a model, and a script is never
       model output: a proposal carries none, whatever it declares. *)
    let* () =
      match draft.scripts with
      | None | Some [] -> Ok ()
      | Some _ -> Error (path ^ ": a proposed playbook cannot carry scripts")
    in
    let* existing =
      match installed_for_site ~caps draft.site with
      | Ok book -> Ok (Some book)
      | Error why when String.starts_with ~prefix:"no installed playbook" why -> Ok None
      | Error why -> Error why
    in
    let merged, destination, dir, replaced =
      match existing with
      | None ->
          let dir = Filename.concat (directory ~caps ()) draft.site in
          (draft, Filename.concat dir "playbook.json", Some dir, false)
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
          ({ book.playbook with pages; procedures }, book.file, book.dir, true)
    in
    let* _ =
      validate ~file:destination
        ~dir:(Option.map (fun dir -> (reads caps, dir)) dir)
        merged
    in
    let* () = Config.ensure_dir ~caps (Filename.dirname destination) in
    try
      let channel =
        Cap_stdlib.open_out_gen ~caps
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
    let* proposal = read_proposal ~caps path in
    let* (book : loaded) = installed_for_site ~caps proposal.site in
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
    let* (_ : loaded) = revalidate ~caps book merged in
    let json = Yojson.Safe.pretty_to_string (yojson_of_t merged) ^ "\n" in
    try
      let channel =
        Cap_stdlib.open_out_gen ~caps
          [ Open_wronly; Open_creat; Open_trunc; Open_binary ]
          0o600 book.file
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
  | Not_page_kind _ -> "not_page_kind"
  | Text _ -> "text"
  | Download _ -> "download"
  | No_dialog -> "no_dialog"
  | Row _ -> "row"
  | Judgment _ -> "judgment"

let yojson_of_checker = function
  | Page_kind name -> `Assoc [ ("checker", `String "page_kind"); ("kind", `String name) ]
  | Not_page_kind name ->
      `Assoc [ ("checker", `String "not_page_kind"); ("kind", `String name) ]
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

let inspect ?(code = false) book =
  let scripts =
    List.map
      (fun (script : script) ->
        `Assoc
          ([
             ("script", `String script.name);
             ("origin", `String script.origin);
             ("bytes", `Int (String.length script.code));
             ("max_bytes", `Int script.max_bytes);
             ("returns", Shape.yojson_of_t script.returns);
           ]
          @ if code then [ ("code", `String script.code) ] else []))
      book.scripts
  in
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
      ("scripts", `List scripts);
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
  | Not_page_kind kind ->
      Option.fold ~none:false ~some:(fun observed -> observed <> kind) snapshot.kind
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
