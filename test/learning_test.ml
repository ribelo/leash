(* pilot-c77y pilot-3egp pilot-oijk: memory only, no models or browser. *)
module L = Leash.Learning
module B = Leash.Playbook
module C = Leash.Config

let ok = function Ok x -> x | Error why -> Alcotest.fail why

let rec remove ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
  match Unix.lstat path with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  | st when st.Unix.st_kind = Unix.S_DIR ->
      Array.iter
        (fun name -> (remove ~caps) (Filename.concat path name))
        ((Ox_caps.Cap_sys.readdir ~caps) path);
      (Ox_caps.Cap_unix.rmdir ~caps) path
  | _ -> (Ox_caps.Cap_unix.unlink ~caps) path

let temp
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) f =
  let dir = (Ox_caps.Cap_stdlib.Filename.temp_file ~caps) "leash-map-" "" in
  (Ox_caps.Cap_unix.unlink ~caps) dir;
  (Ox_caps.Cap_unix.mkdir ~caps) dir 0o700;
  let keys = [ "XDG_CONFIG_HOME"; "XDG_STATE_HOME" ] in
  let old = List.map (fun k -> (k, (Ox_caps.Cap_sys.getenv_opt ~caps) k)) keys in
  List.iter (fun key -> (Ox_caps.Cap_unix.putenv ~caps) key dir) keys;
  Fun.protect
    ~finally:(fun () ->
      List.iter
        (fun (k, v) -> (Ox_caps.Cap_unix.putenv ~caps) k (Option.value ~default:"" v))
        old;
      (remove ~caps) dir)
    (fun () -> f dir)

let with_memory
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) ?(config = C.default.learning) f =
  (temp ~caps) (fun _ ->
      Eio_main.run (fun _ ->
          Eio.Switch.run (fun sw ->
              let warnings = ref [] in
              let t =
                L.create ~sw ~caps ~config ~warn:(fun s -> warnings := s :: !warnings) ()
              in
              f t;
              L.await_pending t;
              Alcotest.(check (list string)) "no warnings" [] !warnings)))

let record t =
  L.record_legs t ~site:"example.com" ~mission:"Find Ada"
    ~args:[ ("name", "Ada") ]
    ~legs:[ "Search Ada"; "Open Ada" ] ~expect:[ "Ada is visible" ]

let pick t =
  match L.candidates t ~site:"example.com" ~kind:None with
  | [ (p, origin) ] -> (p, origin)
  | _ -> Alcotest.fail "expected one memory candidate"

let recording
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) (fun t ->
      record t;
      L.await_pending t;
      let p, origin = pick t in
      Alcotest.(check string) "parameterized mission" "Find {name}" p.description;
      Alcotest.(check (list string)) "expect" [ "{name} is visible" ] p.expect;
      Alcotest.(check int) "legs" 2 (List.length p.steps);
      (match p.steps with
      | B.Goal { goal; _ } :: _ -> Alcotest.(check string) "goal" "Search {name}" goal
      | _ -> Alcotest.fail "goal steps");
      (match origin with `Draft _ -> () | _ -> Alcotest.fail "must start as draft");
      record t;
      L.await_pending t;
      ignore (pick t);
      Alcotest.(check int)
        "site isolation" 0
        (List.length (L.candidates t ~site:"other.com" ~kind:None)))

let replay
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) (fun t ->
      record t;
      L.await_pending t;
      let p, origin = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      let _, origin = pick t in
      (match origin with
      | `Installed -> ()
      | _ -> Alcotest.fail "verified replay installs");
      record t;
      L.await_pending t;
      ignore (pick t))

let failed
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) ~config:{ C.default.learning with max_tries = 2 } (fun t ->
      record t;
      L.await_pending t;
      let p, origin = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Done ~verified:false;
      L.await_pending t;
      let _, origin = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Failed ~verified:false;
      L.await_pending t;
      Alcotest.(check int)
        "retired after bound" 0
        (List.length (L.candidates t ~site:"example.com" ~kind:None)))

let stale
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) (fun t ->
      record t;
      L.await_pending t;
      let p, _ = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, `Draft "stale") ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      match snd (pick t) with
      | `Draft _ -> ()
      | _ -> Alcotest.fail "stale revision installed")

let single_leg
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) (fun t ->
      L.record_legs t ~site:"example.com" ~mission:"Find Ada"
        ~args:[ ("name", "Ada"); ("short", "a") ]
        ~legs:[ "Open Ada" ] ~expect:[ "Ada visible" ];
      L.await_pending t;
      let p, origin = pick t in
      (match p.steps with
      | [ B.Goal { goal; _ } ] ->
          Alcotest.(check string) "placeholder not rewritten" "Open {name}" goal
      | _ -> Alcotest.fail "one goal");
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      match snd (pick t) with
      | `Installed -> ()
      | _ -> Alcotest.fail "single leg installs")

let installed_retirement
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) ~config:{ C.default.learning with retire_after = 2 } (fun t ->
      record t;
      L.await_pending t;
      let p, origin = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      for _ = 1 to 2 do
        L.after_mission t ~site:"example.com"
          ~used:[ (p.slug, `Installed) ]
          ~outcome:`Failed ~verified:false;
        L.await_pending t
      done;
      Alcotest.(check int)
        "installed retired" 0
        (List.length (L.candidates t ~site:"example.com" ~kind:None)))

let repair
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) (fun t ->
      record t;
      L.await_pending t;
      let p, origin = pick t in
      L.after_mission t ~site:"example.com"
        ~used:[ (p.slug, origin) ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      for _ = 1 to 2 do
        L.after_mission t ~site:"example.com"
          ~used:[ (p.slug, `Installed) ]
          ~outcome:`Failed ~verified:false;
        L.await_pending t
      done;
      let draft =
        List.find
          (fun (_, origin) -> match origin with `Draft _ -> true | _ -> false)
          (L.candidates t ~site:"example.com" ~kind:None)
      in
      L.after_mission t ~site:"example.com"
        ~used:[ (fst draft |> fun p -> (p.B.slug, snd draft)) ]
        ~outcome:`Done ~verified:true;
      L.await_pending t;
      for _ = 1 to 4 do
        L.after_mission t ~site:"example.com"
          ~used:[ (p.slug, `Installed) ]
          ~outcome:`Failed ~verified:false;
        L.await_pending t
      done;
      Alcotest.(check bool)
        "repair reset consecutive failures" true
        (List.exists
           (fun (_, origin) -> origin = `Installed)
           (L.candidates t ~site:"example.com" ~kind:None)))

let off
    ~(caps :
       < Ox_caps.Cap.env
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.time
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  (with_memory ~caps) ~config:{ C.default.learning with mode = C.Learning_mode.Off }
    (fun t ->
      record t;
      L.await_pending t;
      Alcotest.(check int)
        "disabled memory" 0
        (List.length (L.candidates t ~site:"example.com" ~kind:None)))

let config () =
  Alcotest.(check string)
    "default auto" "auto"
    (C.Learning_mode.to_string C.default.learning.mode);
  List.iter
    (fun key ->
      match C.t_of_yojson (`Assoc [ ("learning", `Assoc [ (key, `Int 2) ]) ]) with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail ("accepted removed " ^ key))
    [ "successes"; "planner_model"; "planner_reasoning"; "planner_actions"; "timeout_s" ];
  Alcotest.(check int) "pilot turns" 12 C.default.pilot.turns;
  Alcotest.(check int) "pilot deadline" 600 C.default.pilot.deadline_s;
  Alcotest.(check string)
    "pilot reasoning" "max"
    (C.Text.to_string C.default.models.planner_reasoning);
  List.iter
    (fun (key, value) ->
      match C.t_of_yojson (`Assoc [ ("pilot", `Assoc [ (key, `Int value) ]) ]) with
      | Error _ -> ()
      | Ok _ -> Alcotest.fail "out-of-bounds pilot budget")
    [ ("turns", 0); ("turns", 101); ("deadline_s", 29); ("deadline_s", 3601) ];
  match C.t_of_yojson (`Assoc [ ("learning", `Assoc [ ("mode", `String "draft") ]) ]) with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "withdrawn draft mode accepted"

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "pilot memory"
    [
      ( "seam",
        List.map
          (fun (name, f) -> Alcotest.test_case name `Quick f)
          [
            ("record and deduplicate", recording ~caps);
            ("verified replay", replay ~caps);
            ("failure bound", failed ~caps);
            ("stale revision", stale ~caps);
            ("single leg and overlaps", single_leg ~caps);
            ("installed retirement", installed_retirement ~caps);
            ("repair resets failures", repair ~caps);
            ("off", off ~caps);
            ("config", config);
          ] );
    ]
