let rec remove_path ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) path =
  match Unix.lstat path with
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  | stats when stats.Unix.st_kind = Unix.S_DIR ->
      (Ox_caps.Cap_sys.readdir ~caps) path
      |> Array.iter (fun name -> (remove_path ~caps) (Filename.concat path name));
      (Ox_caps.Cap_unix.rmdir ~caps) path
  | _ -> (Ox_caps.Cap_unix.unlink ~caps) path

let with_temp_dir
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) f =
  let path = (Ox_caps.Cap_stdlib.Filename.temp_file ~caps) "leash-skill-install-" "" in
  (Ox_caps.Cap_sys.remove ~caps) path;
  (Ox_caps.Cap_unix.mkdir ~caps) path 0o755;
  Fun.protect ~finally:(fun () -> (remove_path ~caps) path) (fun () -> f path)

let with_cwd ~(caps : < Ox_caps.Cap.chdir ; .. >) path f =
  let previous = Sys.getcwd () in
  Fun.protect
    ~finally:(fun () -> (Ox_caps.Cap_sys.chdir ~caps) previous)
    (fun () ->
      (Ox_caps.Cap_sys.chdir ~caps) path;
      f ())

let read ~(caps : < Ox_caps.Cap.fs_read ; .. >) path =
  (Ox_caps.Cap_stdlib.In_channel.with_open_bin ~caps) path In_channel.input_all

module Skill_install = Leash_cli_support.Skill_install

let path_exists path =
  match Unix.lstat path with
  | _ -> true
  | exception Unix.Unix_error (Unix.ENOENT, _, _) -> false

let contains haystack needle =
  let haystack_length = String.length haystack in
  let needle_length = String.length needle in
  let rec loop offset =
    if offset + needle_length > haystack_length then false
    else if String.sub haystack offset needle_length = needle then true
    else loop (offset + 1)
  in
  loop 0

let error_message error =
  error.Skill_install.failures
  |> List.map (fun failure -> failure.Skill_install.message)
  |> String.concat "; "

(* daily-yd8s: the same installer contract as Nema. *)
let test_explicit_root_installs_complete_skill
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  match
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force:false
      ~no_input:false ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "new explicit target must not prompt")
  with
  | Error error -> Alcotest.fail (error_message error)
  | Ok outcomes ->
      Alcotest.(check int) "one outcome" 1 (List.length outcomes);
      let skill = Filename.concat root "leash" in
      Alcotest.(check bool)
        "SKILL.md" true
        (Sys.file_exists (Filename.concat skill "SKILL.md"));
      Alcotest.(check string)
        "stamped entrypoint" Skill_install.show
        ((read ~caps) (Filename.concat skill "SKILL.md"));
      Alcotest.(check bool)
        "references directory" true
        (Sys.is_directory (Filename.concat skill "references"));
      Alcotest.(check bool)
        "entrypoint contents" true
        (String.starts_with ~prefix:"---\nname: leash\n"
           ((read ~caps) (Filename.concat skill "SKILL.md")))

let rec mkdir_p ~(caps : < Ox_caps.Cap.fs_write ; .. >) path =
  if path = "" || Sys.file_exists path then ()
  else (
    (mkdir_p ~caps) (Filename.dirname path);
    (Ox_caps.Cap_unix.mkdir ~caps) path 0o755)

(* daily-yd8s: the same installer contract as Nema. *)
let test_discovery_deduplicates_linked_roots
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let shared = Filename.concat home "shared-skills" in
  let codex = Filename.concat home ".codex" in
  let pi_agent = Filename.concat home ".pi/agent" in
  (mkdir_p ~caps) shared;
  (mkdir_p ~caps) codex;
  (mkdir_p ~caps) pi_agent;
  (Ox_caps.Cap_unix.symlink ~caps) shared (Filename.concat codex "skills");
  (Ox_caps.Cap_unix.symlink ~caps) shared (Filename.concat pi_agent "skills");
  let prompts = ref [] in
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:false ~no_input:false
      ~dry_run:false ~stdin_is_tty:true ~confirm:(fun action path ->
        prompts := (action, path) :: !prompts;
        true)
  with
  | Error error -> Alcotest.fail (error_message error)
  | Ok outcomes ->
      Alcotest.(check int) "one physical target" 1 (List.length outcomes);
      Alcotest.(check int) "one confirmation" 1 (List.length !prompts);
      Alcotest.(check bool)
        "installed once" true
        (Sys.file_exists (Filename.concat shared "leash/SKILL.md"))

(* daily-yd8s: the same installer contract as Nema. *)
let test_identical_explicit_target_is_current
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let run ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) () =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force:false
      ~no_input:false ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "identical target must not prompt")
  in
  (match (run ~caps) () with
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> ());
  match (run ~caps) () with
  | Error error -> Alcotest.fail (error_message error)
  | Ok [ { disposition = Skill_install.Current; _ } ] -> ()
  | Ok _ -> Alcotest.fail "expected one current outcome"

(* daily-yd8s: the same installer contract as Nema. *)
let test_empty_explicit_path_is_rejected
    ~(caps :
       < Ox_caps.Cap.chdir
       ; Ox_caps.Cap.fs_read
       ; Ox_caps.Cap.fs_write
       ; Ox_caps.Cap.tmp
       ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  (with_cwd ~caps) root @@ fun () ->
  match
    Skill_install.run ~roots:[] ~caps ~home:"" ~path:(Some "") ~force:true ~no_input:false
      ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ -> true)
  with
  | Ok _ -> Alcotest.fail "expected empty PATH failure"
  | Error error ->
      Alcotest.(check bool)
        "usage error" true
        ((List.hd error.Skill_install.failures).Skill_install.kind = Skill_install.Usage);
      Alcotest.(check bool) "cwd unchanged" false (Sys.file_exists "leash")

(* daily-yd8s: the same installer contract as Nema. *)
let test_unexpected_nodes_require_and_allow_replacement
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let run ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) ~force ~dry_run =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force ~no_input:true
      ~dry_run ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "force and dry-run must not prompt")
  in
  (match (run ~caps) ~force:false ~dry_run:false with
  | Ok _ -> ()
  | Error error -> Alcotest.fail (error_message error));
  let destination = Filename.concat root "leash" in
  let empty = Filename.concat destination "extra-empty" in
  (Ox_caps.Cap_unix.mkdir ~caps) empty 0o755;
  (match (run ~caps) ~force:false ~dry_run:true with
  | Ok [ { disposition = Skill_install.Planned_replace; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "empty directory must require replacement");
  (Ox_caps.Cap_unix.rmdir ~caps) empty;
  let linked = Filename.concat destination "extra-link" in
  (Ox_caps.Cap_unix.symlink ~caps) "/missing/leash-skill-target" linked;
  (match (run ~caps) ~force:false ~dry_run:true with
  | Ok [ { disposition = Skill_install.Planned_replace; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "symlink must require replacement");
  (match (run ~caps) ~force:true ~dry_run:false with
  | Ok [ { disposition = Skill_install.Replaced; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "force must replace unexpected nodes");
  Alcotest.(check bool) "symlink removed" false (path_exists linked)

(* daily-yd8s: the same installer contract as Nema. *)
let test_cleanup_failure_reports_completed_replacement
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let destination = Filename.concat root "leash" in
  let install ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) force confirm
      =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force ~no_input:false
      ~dry_run:false ~stdin_is_tty:true ~confirm
  in
  (match (install ~caps) false (fun _ _ -> true) with
  | Ok _ -> ()
  | Error error -> Alcotest.fail (error_message error));
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps)
    (Filename.concat destination "SKILL.md") (fun channel ->
      output_string channel "stale");
  let protected = Filename.concat destination "references" in
  let result =
    (install ~caps) false (fun _ _ ->
        (Ox_caps.Cap_unix.chmod ~caps) protected 0o000;
        true)
  in
  let backup =
    (Ox_caps.Cap_sys.readdir ~caps) root
    |> Array.to_list
    |> List.find (String.starts_with ~prefix:"leash.old-")
    |> Filename.concat root
  in
  Fun.protect
    ~finally:(fun () ->
      (Ox_caps.Cap_unix.chmod ~caps) (Filename.concat backup "references") 0o755;
      (remove_path ~caps) backup)
    (fun () ->
      match result with
      | Ok _ -> Alcotest.fail "expected backup cleanup failure"
      | Error error ->
          Alcotest.(check int)
            "replacement completed" 1
            (List.length error.Skill_install.completed);
          Alcotest.(check bool)
            "new tree installed" true
            (String.starts_with ~prefix:"---\nname: leash\n"
               ((read ~caps) (Filename.concat destination "SKILL.md")));
          Alcotest.(check int) "cleanup failure reported" 1 (List.length error.failures);
          Alcotest.(check bool)
            "cleanup permission class" true
            ((List.hd error.failures).Skill_install.kind = Skill_install.Permission))

(* daily-yd8s: the same installer contract as Nema. *)
let test_inspection_failure_is_permission_and_non_mutating
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let run ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) ~force ~dry_run =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force ~no_input:false
      ~dry_run ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "inspection failure must not prompt")
  in
  (match (run ~caps) ~force:false ~dry_run:false with
  | Ok _ -> ()
  | Error error -> Alcotest.fail (error_message error));
  let skill_md = Filename.concat root "leash/SKILL.md" in
  let original = (read ~caps) skill_md in
  (Ox_caps.Cap_unix.chmod ~caps) skill_md 0o000;
  Fun.protect
    ~finally:(fun () -> (Ox_caps.Cap_unix.chmod ~caps) skill_md 0o644)
    (fun () ->
      [ (false, true); (true, false) ]
      |> List.iter (fun (force, dry_run) ->
          match (run ~caps) ~force ~dry_run with
          | Ok _ -> Alcotest.fail "expected inspection failure"
          | Error error ->
              Alcotest.(check int)
                "nothing completed" 0
                (List.length error.Skill_install.completed);
              Alcotest.(check bool)
                "permission failure" true
                ((List.hd error.failures).Skill_install.kind = Skill_install.Permission)));
  Alcotest.(check string) "target unchanged" original ((read ~caps) skill_md)

(* daily-yd8s: the same installer contract as Nema. *)
let test_replacement_requires_consent_and_replaces_tree
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let destination = Filename.concat root "leash" in
  (mkdir_p ~caps) destination;
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps)
    (Filename.concat destination "SKILL.md") (fun channel ->
      output_string channel "stale");
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps)
    (Filename.concat destination "extra.txt") (fun channel ->
      output_string channel "remove me");
  let prompts = ref 0 in
  let run ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) answer =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force:false
      ~no_input:false ~dry_run:false ~stdin_is_tty:true ~confirm:(fun action path ->
        incr prompts;
        Alcotest.(check bool)
          "replace action" true
          (match action with
          | Skill_install.Replace -> true
          | Skill_install.Install -> false);
        Alcotest.(check string) "prompt path" destination path;
        answer)
  in
  (match (run ~caps) false with
  | Ok [ { disposition = Skill_install.Declined; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "expected declined outcome");
  Alcotest.(check string)
    "decline preserves stale file" "stale"
    ((read ~caps) (Filename.concat destination "SKILL.md"));
  (match (run ~caps) true with
  | Ok [ { disposition = Skill_install.Replaced; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "expected replaced outcome");
  Alcotest.(check int) "prompted once per run" 2 !prompts;
  Alcotest.(check bool)
    "unknown file removed" false
    (Sys.file_exists (Filename.concat destination "extra.txt"))

(* daily-yd8s: the same installer contract as Nema. *)
let test_non_tty_replacement_requires_force
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun root ->
  let destination = Filename.concat root "leash" in
  (mkdir_p ~caps) destination;
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps)
    (Filename.concat destination "SKILL.md") (fun channel ->
      output_string channel "stale");
  let run ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) force =
    Skill_install.run ~roots:[] ~caps ~home:root ~path:(Some root) ~force ~no_input:false
      ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "non-TTY operation must not prompt")
  in
  (match (run ~caps) false with
  | Error error ->
      let message = error_message error in
      Alcotest.(check bool)
        "suggests force" true
        (String.contains message '-' && String.ends_with ~suffix:"--force" message)
  | Ok _ -> Alcotest.fail "expected missing-consent failure");
  Alcotest.(check string)
    "failure preserves target" "stale"
    ((read ~caps) (Filename.concat destination "SKILL.md"));
  match (run ~caps) true with
  | Ok [ { disposition = Skill_install.Replaced; _ } ] -> ()
  | Error error -> Alcotest.fail (error_message error)
  | Ok _ -> Alcotest.fail "expected forced replacement"

(* daily-yd8s: the same installer contract as Nema. *)
let test_no_input_discovery_requires_force
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let agents = Filename.concat home ".agents" in
  (mkdir_p ~caps) agents;
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:false ~no_input:true
      ~dry_run:false ~stdin_is_tty:true ~confirm:(fun _ _ ->
        Alcotest.fail "--no-input must not prompt")
  with
  | Error error ->
      let message = error_message error in
      Alcotest.(check bool)
        "suggests force" true
        (String.ends_with ~suffix:"--force" message);
      Alcotest.(check bool)
        "does not install" false
        (Sys.file_exists (Filename.concat agents "skills/leash"))
  | Ok _ -> Alcotest.fail "expected missing-consent failure"

(* daily-yd8s: the same installer contract as Nema. *)
let test_dry_run_reports_without_prompting_or_writing
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let claude = Filename.concat home ".claude" in
  let agents_skill = Filename.concat home ".agents/skills/leash" in
  (mkdir_p ~caps) claude;
  (mkdir_p ~caps) agents_skill;
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps)
    (Filename.concat agents_skill "SKILL.md") (fun channel ->
      output_string channel "stale");
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:false ~no_input:true
      ~dry_run:true ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "dry run must not prompt")
  with
  | Error error -> Alcotest.fail (error_message error)
  | Ok outcomes ->
      let planned_install =
        List.exists
          (fun outcome ->
            outcome.Skill_install.disposition = Skill_install.Planned_install)
          outcomes
      in
      let planned_replace =
        List.exists
          (fun outcome ->
            outcome.Skill_install.disposition = Skill_install.Planned_replace)
          outcomes
      in
      Alcotest.(check bool) "reports installation" true planned_install;
      Alcotest.(check bool) "reports replacement" true planned_replace;
      Alcotest.(check bool)
        "new target absent" false
        (Sys.file_exists (Filename.concat claude "skills/leash"));
      Alcotest.(check string)
        "existing target unchanged" "stale"
        ((read ~caps) (Filename.concat agents_skill "SKILL.md"))

(* daily-yd8s: the same installer contract as Nema. *)
let test_missing_discovery_reports_checked_locations
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:false ~no_input:false
      ~dry_run:false ~stdin_is_tty:true ~confirm:(fun _ _ -> true)
  with
  | Ok _ -> Alcotest.fail "expected no-target failure"
  | Error error ->
      let message = error_message error in
      [ ".claude"; ".codex"; ".pi"; ".agents" ]
      |> List.iter (fun directory ->
          Alcotest.(check bool)
            ("reports " ^ directory) true
            (contains message (Filename.concat home directory)))

(* daily-yd8s: the same installer contract as Nema. *)
let test_discovery_rejects_invalid_home
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; .. >) () =
  [ ""; "relative/home" ]
  |> List.iter (fun home ->
      match
        Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:true ~no_input:false
          ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ -> true)
      with
      | Ok _ -> Alcotest.fail "expected invalid HOME failure"
      | Error error ->
          Alcotest.(check int) "one failure" 1 (List.length error.Skill_install.failures);
          let failure = List.hd error.failures in
          Alcotest.(check bool)
            "usage error" true
            (failure.Skill_install.kind = Skill_install.Usage))

(* daily-yd8s: the same installer contract as Nema. *)
let test_forced_discovery_reports_failure_and_continues
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let claude = Filename.concat home ".claude" in
  let codex = Filename.concat home ".codex" in
  let agents = Filename.concat home ".agents" in
  (mkdir_p ~caps) claude;
  (mkdir_p ~caps) codex;
  (mkdir_p ~caps) agents;
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps) (Filename.concat codex "skills")
    (fun channel -> output_string channel "not a directory");
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:true ~no_input:false
      ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "force must not prompt")
  with
  | Ok _ -> Alcotest.fail "expected one target failure"
  | Error error ->
      Alcotest.(check int)
        "two completed targets" 2
        (List.length error.Skill_install.completed);
      Alcotest.(check int) "one failed target" 1 (List.length error.failures);
      Alcotest.(check bool)
        "filesystem failure" true
        ((List.hd error.failures).Skill_install.kind = Skill_install.Internal);
      Alcotest.(check bool)
        "earlier target installed" true
        (Sys.file_exists (Filename.concat claude "skills/leash/SKILL.md"));
      Alcotest.(check bool)
        "later target installed" true
        (Sys.file_exists (Filename.concat agents "skills/leash/SKILL.md"))

(* daily-yd8s: the same installer contract as Nema. *)
let test_invalid_discovery_root_does_not_block_later_root
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let claude = Filename.concat home ".claude" in
  let agents = Filename.concat home ".agents" in
  (Ox_caps.Cap_stdlib.Out_channel.with_open_bin ~caps) claude (fun channel ->
      output_string channel "bad");
  (mkdir_p ~caps) agents;
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:true ~no_input:false
      ~dry_run:false ~stdin_is_tty:false ~confirm:(fun _ _ ->
        Alcotest.fail "force must not prompt")
  with
  | Ok _ -> Alcotest.fail "expected invalid discovery-root failure"
  | Error error ->
      Alcotest.(check int)
        "later target completed" 1
        (List.length error.Skill_install.completed);
      Alcotest.(check int) "invalid root reported" 1 (List.length error.failures);
      Alcotest.(check bool)
        "later target installed" true
        (Sys.file_exists (Filename.concat agents "skills/leash/SKILL.md"))

(* daily-yd8s: the same installer contract as Nema. *)
let test_declined_discovery_continues
    ~(caps : < Ox_caps.Cap.fs_read ; Ox_caps.Cap.fs_write ; Ox_caps.Cap.tmp ; .. >) () =
  with_temp_dir ~caps @@ fun home ->
  let claude = Filename.concat home ".claude" in
  let agents = Filename.concat home ".agents" in
  (mkdir_p ~caps) claude;
  (mkdir_p ~caps) agents;
  let answers = ref [ false; true ] in
  let confirm _ _ =
    match !answers with
    | answer :: rest ->
        answers := rest;
        answer
    | [] -> Alcotest.fail "unexpected extra confirmation"
  in
  match
    Skill_install.run ~roots:[] ~caps ~home ~path:None ~force:false ~no_input:false
      ~dry_run:false ~stdin_is_tty:true ~confirm
  with
  | Error error -> Alcotest.fail (error_message error)
  | Ok
      [
        { disposition = Skill_install.Declined; _ };
        { disposition = Skill_install.Installed; _ };
      ] ->
      Alcotest.(check bool)
        "declined target absent" false
        (Sys.file_exists (Filename.concat claude "skills/leash"));
      Alcotest.(check bool)
        "later target installed" true
        (Sys.file_exists (Filename.concat agents "skills/leash/SKILL.md"))
  | Ok _ -> Alcotest.fail "expected declined then installed outcomes"

let () =
  let caps = Ox_test.powerbox () in
  Alcotest.run "skill install"
    [
      ( "explicit target",
        [
          Alcotest.test_case "installs complete bundled tree" `Quick
            (test_explicit_root_installs_complete_skill ~caps);
          Alcotest.test_case "identical installation is current" `Quick
            (test_identical_explicit_target_is_current ~caps);
          Alcotest.test_case "empty path is rejected" `Quick
            (test_empty_explicit_path_is_rejected ~caps);
          Alcotest.test_case "unexpected nodes require replacement" `Quick
            (test_unexpected_nodes_require_and_allow_replacement ~caps);
          Alcotest.test_case "cleanup failure reports replacement" `Quick
            (test_cleanup_failure_reports_completed_replacement ~caps);
          Alcotest.test_case "inspection failure preserves target" `Quick
            (test_inspection_failure_is_permission_and_non_mutating ~caps);
          Alcotest.test_case "replacement requires consent" `Quick
            (test_replacement_requires_consent_and_replaces_tree ~caps);
          Alcotest.test_case "non-TTY replacement requires force" `Quick
            (test_non_tty_replacement_requires_force ~caps);
        ] );
      ( "discovery",
        [
          Alcotest.test_case "deduplicates linked skill roots" `Quick
            (test_discovery_deduplicates_linked_roots ~caps);
          Alcotest.test_case "no-input requires force" `Quick
            (test_no_input_discovery_requires_force ~caps);
          Alcotest.test_case "dry run reports planned actions" `Quick
            (test_dry_run_reports_without_prompting_or_writing ~caps);
          Alcotest.test_case "missing discovery lists checked roots" `Quick
            (test_missing_discovery_reports_checked_locations ~caps);
          Alcotest.test_case "invalid HOME is rejected" `Quick
            (test_discovery_rejects_invalid_home ~caps);
          Alcotest.test_case "decline continues discovery" `Quick
            (test_declined_discovery_continues ~caps);
          Alcotest.test_case "forced discovery continues after failure" `Quick
            (test_forced_discovery_reports_failure_and_continues ~caps);
          Alcotest.test_case "invalid root does not block later root" `Quick
            (test_invalid_discovery_root_does_not_block_later_root ~caps);
        ] );
    ]
