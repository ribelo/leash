module P = Protocol
module Cap_unix = Ox_caps.Cap_unix
module Cap_sys = Ox_caps.Cap_sys
module Cap_stdlib = Ox_caps.Cap_stdlib

type caps =
  < Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.time >

type retention = { count : int; [@json.default 20] days : int [@json.default 30] }
[@@deriving yojson]

module Retention = struct
  type t = retention = { count : int; days : int }

  let default = { count = 20; days = 30 }

  let of_values ~count ~days =
    if count < 1 || count > 10000 then Error "retention.count must be between 1 and 10000"
    else if days < 1 || days > 3650 then Error "retention.days must be between 1 and 3650"
    else Ok { count; days }

  let yojson_of_t = yojson_of_retention
  let decode = retention_of_yojson

  let t_of_yojson json =
    match decode json with
    | Error _ as e -> e
    | Ok { count; days } -> of_values ~count ~days
end

type t = { caps : caps; root : string; retention : Retention.t }

let create ~caps ?root ?(retention = Retention.default) () =
  let root =
    match root with
    | Some p -> p
    | None ->
        let state =
          match Cap_sys.getenv_opt ~caps "XDG_STATE_HOME" with
          | Some p when p <> "" -> p
          | _ -> Filename.concat (Cap_sys.getenv ~caps "HOME") ".local/state"
        in
        Filename.concat state "leash/traces"
  in
  { caps :> caps; root; retention }

let root t = t.root
let now t = Cap_unix.gettimeofday ~caps:t.caps ()
let ( let* ) = Result.bind

let protect f =
  try Ok (f ()) with
  | Sys_error why -> Error why
  | Unix.Unix_error (code, fn, path) ->
      Error (Printf.sprintf "%s %s: %s" fn path (Unix.error_message code))
  | Yojson.Json_error why -> Error why

let timestamp at =
  let tm = Unix.gmtime at in
  let micros = int_of_float ((at -. floor at) *. 1000000.) in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d.%06dZ" (tm.tm_year + 1900) (tm.tm_mon + 1)
    tm.tm_mday tm.tm_hour tm.tm_min tm.tm_sec micros

(* trace-qe8c: PSL's exact, wildcard and exception rules, longest matching suffix. *)
let suffixes =
  lazy
    (let exact = Hashtbl.create 10000
     and wildcard = Hashtbl.create 200
     and exceptions = Hashtbl.create 20 in
     String.split_on_char '\n' Public_suffix_data.rules
     |> List.iter (fun line ->
         let line = String.trim line in
         if line = "" || String.starts_with ~prefix:"//" line then ()
         else if String.starts_with ~prefix:"!" line then
           Hashtbl.replace exceptions (String.sub line 1 (String.length line - 1)) ()
         else if String.starts_with ~prefix:"*." line then
           Hashtbl.replace wildcard (String.sub line 2 (String.length line - 2)) ()
         else Hashtbl.replace exact line ());
     (exact, wildcard, exceptions))

let site url =
  let host =
    let lower = String.lowercase_ascii url in
    let prefix =
      if String.starts_with ~prefix:"https://" lower then Some 8
      else if String.starts_with ~prefix:"http://" lower then Some 7
      else None
    in
    Option.bind prefix (fun start ->
        let authority =
          String.sub url start (String.length url - start)
          |> String.split_on_char '/' |> List.hd |> String.split_on_char '?' |> List.hd
          |> String.split_on_char '#' |> List.hd
        in
        let authority = List.rev (String.split_on_char '@' authority) |> List.hd in
        if String.starts_with ~prefix:"[" authority then
          Option.map
            (fun stop -> String.sub authority 1 (stop - 1))
            (String.index_opt authority ']')
        else Some (List.hd (String.split_on_char ':' authority)))
  in
  match host with
  | None -> None
  | Some host -> (
      let host = String.lowercase_ascii host in
      let host =
        if String.ends_with ~suffix:"." host then
          String.sub host 0 (String.length host - 1)
        else host
      in
      if host = "" then None
      else
        match Unix.inet_addr_of_string host with
        | _ -> Some host
        | exception Failure _ ->
            let labels = String.split_on_char '.' host in
            let exact, wildcard, exceptions = Lazy.force suffixes in
            let n = List.length labels in
            let rec loop suffix count best exception_count =
              match suffix with
              | [] -> (best, exception_count)
              | _ :: tail ->
                  let name = String.concat "." suffix in
                  let best = if Hashtbl.mem exact name then max best count else best in
                  let best =
                    if tail <> [] && Hashtbl.mem wildcard (String.concat "." tail) then
                      max best count
                    else best
                  in
                  let exception_count =
                    if Hashtbl.mem exceptions name then Some (count - 1)
                    else exception_count
                  in
                  loop tail (count - 1) best exception_count
            in
            let best, except = loop labels n 1 None in
            let keep = min n (1 + Option.value ~default:best except) in
            let rec drop k xs =
              if k <= 0 then xs
              else match xs with [] -> [] | _ :: rest -> drop (k - 1) rest
            in
            Some (String.concat "." (drop (n - keep) labels)))

let component value =
  value <> "" && value <> "." && value <> ".."
  && String.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '.' | '-' | '_' | ':' -> true
         | _ -> false)
       value

let directory path =
  let st = Unix.lstat path in
  if st.Unix.st_kind <> Unix.S_DIR then
    raise (Sys_error (path ^ ": not a directory (symlinks refused)"))

let rec mkdir ~caps path =
  match Unix.lstat path with
  | st ->
      if st.Unix.st_kind <> Unix.S_DIR then
        raise (Sys_error (path ^ ": directory required (symlinks refused)"))
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> (
      let parent = Filename.dirname path in
      if parent <> path then mkdir ~caps parent;
      try Cap_unix.mkdir ~caps path 0o700
      with Unix.Unix_error (Unix.EEXIST, _, _) -> directory path)

let read ~caps path =
  let* json =
    protect (fun () ->
        let before = Unix.lstat path in
        if before.Unix.st_kind <> Unix.S_REG || before.st_size > 8388608 then
          raise (Sys_error "trace must be a regular file of at most 8 MiB");
        let ch = Cap_stdlib.open_in_bin ~caps path in
        Fun.protect
          ~finally:(fun () -> close_in_noerr ch)
          (fun () ->
            let after = Unix.fstat (Unix.descr_of_in_channel ch) in
            if after.st_kind <> Unix.S_REG || after.st_size > 8388608 then
              raise (Sys_error "trace must be a regular file of at most 8 MiB");
            if before.st_ino <> after.st_ino || before.st_dev <> after.st_dev then
              raise (Sys_error "trace file changed while opening");
            Yojson.Safe.from_string (really_input_string ch after.st_size)))
  in
  P.drive_trace_of_yojson json

let list t ?site ?outcome () =
  if Option.fold ~none:false ~some:(fun s -> not (component s)) site then
    Error "invalid site filter"
  else
    let* files =
      protect (fun () ->
          match Unix.lstat t.root with
          | exception Unix.Unix_error (Unix.ENOENT, _, _) -> []
          | _ ->
              directory t.root;
              let sites =
                match site with
                | Some s -> [ s ]
                | None -> Array.to_list (Cap_sys.readdir ~caps:t.caps t.root)
              in
              List.concat_map
                (fun name ->
                  if not (component name) then []
                  else
                    let dir = Filename.concat t.root name in
                    match Unix.lstat dir with
                    | exception Unix.Unix_error (Unix.ENOENT, _, _) -> []
                    | st when st.Unix.st_kind = Unix.S_LNK ->
                        raise (Sys_error "trace site symlink refused")
                    | st when st.Unix.st_kind <> Unix.S_DIR -> []
                    | _ ->
                        Cap_sys.readdir ~caps:t.caps dir
                        |> Array.to_list
                        |> List.filter_map (fun file ->
                            if Filename.check_suffix file ".json" then
                              Some (Filename.concat dir file)
                            else None))
                sites)
    in
    let rec load acc = function
      | [] ->
          Ok
            (List.sort
               (fun (pa, a) (pb, b) ->
                 let order = String.compare b.P.Trace.time a.P.Trace.time in
                 if order = 0 then String.compare pb pa else order)
               acc)
      | path :: rest ->
          let* trace = read ~caps:t.caps path in
          if trace.P.Trace.site <> Filename.basename (Filename.dirname path) then
            Error "trace site disagrees with directory"
          else if Option.fold ~none:true ~some:(( = ) trace.P.Trace.outcome) outcome then
            load ((path, trace) :: acc) rest
          else load acc rest
    in
    load [] files

let prune t ?site ~dry_run ~now () =
  let* entries = list t ?site () in
  let counts = Hashtbl.create 16 in
  let cutoff = timestamp (now -. float_of_int (t.retention.days * 86400)) in
  let doomed =
    List.filter_map
      (fun (path, trace) ->
        let count =
          1 + Option.value ~default:0 (Hashtbl.find_opt counts trace.P.Trace.site)
        in
        Hashtbl.replace counts trace.site count;
        let uncompiled = trace.outcome = "done" && not trace.compiled in
        if
          uncompiled
          || (count <= t.retention.count && String.compare trace.time cutoff >= 0)
        then None
        else Some path)
      entries
  in
  let* () =
    if dry_run then Ok ()
    else protect (fun () -> List.iter (Cap_unix.unlink ~caps:t.caps) doomed)
  in
  Ok doomed

let write t (trace : P.drive_trace) =
  if not (component trace.site && component trace.outcome && component trace.time) then
    Error "unsafe trace header path"
  else
    protect (fun () ->
        let json = Yojson.Safe.pretty_to_string (P.yojson_of_drive_trace trace) ^ "\n" in
        if String.length json > 8388608 then raise (Sys_error "trace exceeds 8 MiB");
        mkdir ~caps:t.caps t.root;
        Cap_unix.chmod ~caps:t.caps t.root 0o700;
        let dir = Filename.concat t.root trace.site in
        mkdir ~caps:t.caps dir;
        Cap_unix.chmod ~caps:t.caps dir 0o700;
        let rec save attempt =
          let stamp =
            if attempt = 0 then trace.time
            else
              let n = String.length trace.time in
              if n = 0 || trace.time.[n - 1] <> 'Z' then
                raise (Sys_error "UTC timestamp required")
              else String.sub trace.time 0 (n - 1) ^ Printf.sprintf "%03dZ" attempt
          in
          let path = Filename.concat dir (stamp ^ "-" ^ trace.outcome ^ ".json") in
          let temp = path ^ ".tmp" in
          try
            let fd =
              Cap_unix.openfile_write ~caps:t.caps temp
                [ Unix.O_CREAT; Unix.O_EXCL; Unix.O_WRONLY; Unix.O_CLOEXEC ]
                0o600
            in
            let ch = Unix.out_channel_of_descr fd in
            Fun.protect
              ~finally:(fun () ->
                close_out_noerr ch;
                try Cap_unix.unlink ~caps:t.caps temp
                with Unix.Unix_error (Unix.ENOENT, _, _) -> ())
              (fun () ->
                output_string ch json;
                flush ch;
                (* link is exclusive, unlike rename: a same-time drive cannot overwrite evidence. *)
                Cap_unix.link ~caps:t.caps temp path);
            path
          with Unix.Unix_error (Unix.EEXIST, _, _) when attempt < 999 ->
            save (attempt + 1)
        in
        save 0)

type capture = {
  mission : string;
  started : float;
  mutable first : string option;
  mutable kinds : string list;
  mutable pages : (string * string) list;
  mutable last_page : (string * string option) option;
  mutable steps : P.step list;
}

let capture ~mission ~now =
  {
    mission;
    started = now;
    first = None;
    kinds = [];
    pages = [];
    last_page = None;
    steps = [];
  }

let page t ~url ~kind ~pattern =
  if t.first = None then t.first <- site url;
  (match (pattern, kind) with
  | Some pattern, Some name
    when not (List.exists (fun (seen, _) -> seen = pattern) t.pages) ->
      t.pages <- (pattern, name) :: t.pages
  | _ -> ());
  if t.last_page <> Some (url, kind) then (
    Option.iter (fun k -> t.kinds <- k :: t.kinds) kind;
    t.last_page <- Some (url, kind))

(* trace-zbb9: Drive publishes acknowledged execution before observing, then
   refines that same step with its after-page. Do not count the refinement twice. *)
let step t (step : P.step) =
  t.steps <-
    (match t.steps with
    | previous :: rest when previous.P.n = step.n && previous.snapshot = step.snapshot ->
        step :: rest
    | _ -> step :: t.steps)

let probability key_ok = function
  | `Assoc fields ->
      List.filter_map
        (fun (key, value) ->
          if not (key_ok key) then None
          else
            let number =
              match value with
              | `Float n -> Some n
              | `Int n -> Some (float_of_int n)
              | _ -> None
            in
            Option.bind number (fun probability ->
                if Float.is_finite probability then Some P.Trace.{ key; probability }
                else None))
        fields
  | _ -> []

let safe_step n (s : P.step) : P.Trace.trace_step =
  {
    n;
    operation = P.Operation.to_string s.operation;
    target =
      Option.map
        (fun t -> P.Trace.{ role = t.P.target_role; label = t.target_label })
        s.target;
    text = s.text;
    operations =
      probability (fun key -> Result.is_ok (P.Operation.of_string key)) s.probabilities.op;
    targets =
      probability
        (fun key -> key = "NONE" || Option.is_some (int_of_string_opt key))
        s.probabilities.target;
    after = { url = s.after.url; title = s.after.title };
    elapsed_ms = s.elapsed_ms;
  }

let finish t ~now outcome =
  let procedures, cost, model_calls, final, outcome_name, error_code =
    match outcome with
    | Ok result ->
        ( result.P.procedures,
          result.model_cost,
          result.model_calls,
          Some P.Trace.{ url = result.final.url; title = result.final.title },
          P.Run_status.to_string result.status,
          None )
    | Error error ->
        let procedures =
          match error.P.detail with
          | Some (`Assoc fields) -> (
              match List.assoc_opt "procedures" fields with
              | Some (`List xs) ->
                  List.filter_map
                    (fun x -> Result.to_option (P.run_procedure_of_yojson x))
                    xs
              | _ -> [])
          | _ -> []
        in
        let fields =
          match error.P.detail with Some (`Assoc fields) -> fields | _ -> []
        in
        let calls =
          match List.assoc_opt "model_calls" fields with Some (`Int n) -> n | _ -> 0
        in
        let cost =
          match List.assoc_opt "model_cost" fields with
          | Some (`Float n) when Float.is_finite n -> Some n
          | Some (`Int n) -> Some (float_of_int n)
          | _ -> None
        in
        (procedures, cost, calls, None, "error", Some (P.Error_code.to_string error.code))
  in
  let procedures =
    List.mapi
      (fun i (p : P.run_procedure) ->
        P.Trace.
          {
            n = i + 1;
            procedure = p.slug;
            outcome = p.outcome;
            planned = p.planned;
            steps =
              List.concat_map (fun (d : P.run_drive) -> d.steps) p.drives
              |> List.mapi (fun i s -> safe_step (i + 1) s);
          })
      procedures
  in
  let steps = List.rev t.steps |> List.mapi (fun i s -> safe_step (i + 1) s) in
  P.Trace.
    {
      version = 1;
      time = timestamp now;
      site = Option.value ~default:"unknown" t.first;
      mission = t.mission;
      outcome = outcome_name;
      cost;
      duration_ms = max 0 (int_of_float ((now -. t.started) *. 1000.));
      model_calls;
      page_kind_path = List.rev t.kinds;
      inferred_pages =
        List.rev_map (fun (url_pattern, name) -> P.Trace.{ name; url_pattern }) t.pages;
      compiled = false;
      procedures;
      steps;
      final;
      error_code;
    }
