module P = Protocol

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Eta_app.Status.t list;
  models_status : unit -> P.models_status;
      (** L19: what [status] reports about the models section. The thunk reads the live
          configuration and never the key. *)
  fs : Eio.Fs.dir_ty Eio.Path.t;
  net : 'net Eio.Net.ty Eio.Resource.t;
  clock : 'clock Eio.Time.clock;
  logger : Eta_observability.Logger.t;
}

let success json = P.Success json
let failure error = P.Failure error

let enum code =
  match P.Error_code.of_string code with Ok v -> v | Error _ -> assert false

let err code message = failure P.{ code = enum code; message; detail = None }
let invalid why = err "invalid-request" ("invalid request at " ^ why)

let decode line =
  try P.decode_request (Yojson.Safe.from_string line)
  with Yojson.Json_error why -> Error ("/: " ^ why)

let unsupported = err "invalid-request" "this command is not available yet"

(* L19: the status reply is the registry's plus the models section, which only the
   listener's models service knows. A dispatch that was given no models service reports
   [null] there rather than inventing a configuration. *)
let report ?models_status tabs =
  let report = Tabs.report tabs in
  match models_status with
  | None -> report
  | Some models -> { report with P.models = Some (models ()) }

let dispatch ?(model = "unconfigured") ?levels ?decide ?text_helper ?installed
    ?models_status tabs (request : P.request) =
  let owner = request.owner in
  let lift encode = function
    | Ok result -> success (encode result)
    | Error error -> failure error
  in
  match request.command with
  | P.New args -> lift P.yojson_of_tab_info (Tabs.new_tab tabs ~owner ~url:args.url)
  | P.Snap args -> lift P.yojson_of_snapshot (Tabs.snap tabs ~owner args)
  | P.Downloads args ->
      lift P.yojson_of_downloads_result (Tabs.downloads tabs ~owner args.tab)
  | P.Text args -> lift P.yojson_of_text_result (Tabs.text tabs ~owner args)
  | P.Eval args -> lift P.yojson_of_eval_result (Tabs.eval tabs ~owner args)
  | P.Shot args -> lift P.yojson_of_shot_result (Tabs.shot tabs ~owner args)
  | P.Debug args -> lift P.yojson_of_debug_result (Tabs.debug tabs ~owner args)
  | P.Wait args -> lift P.yojson_of_action_result (Tabs.wait tabs ~owner args)
  | P.Dialog args -> lift P.yojson_of_action_result (Tabs.dialog tabs ~owner args)
  | P.Click args -> lift P.yojson_of_action_result (Tabs.click tabs ~owner args)
  | P.Fill args -> lift P.yojson_of_action_result (Tabs.fill tabs ~owner args)
  | P.Press args -> lift P.yojson_of_action_result (Tabs.press tabs ~owner args)
  | P.Select args -> lift P.yojson_of_action_result (Tabs.select tabs ~owner args)
  | P.Scroll args -> lift P.yojson_of_action_result (Tabs.scroll tabs ~owner args)
  | P.Nav args -> lift P.yojson_of_tab_info (Tabs.navigate tabs ~owner args.tab args.url)
  | P.Claim args -> lift P.yojson_of_tab_info (Tabs.claim tabs ~owner args.tab)
  | P.Release args ->
      lift P.yojson_of_released_result
        (Tabs.release tabs ~owner ?force:args.force args.tab)
  | P.Close args ->
      lift P.yojson_of_closed_result (Tabs.close tabs ~owner ?force:args.force args.tab)
  | P.Handoff args ->
      (* hand-lz3p: the one command that blocks in the registry. The listener cancels this
         handler if the client disconnects, which is a handoff ending — the tab goes back
         to its owner — not a leak. *)
      lift P.yojson_of_handoff_result
        (Tabs.handoff tabs ~owner ~reason:args.reason ~timeout_s:args.timeout_s args.tab)
  | P.Resume args -> lift P.yojson_of_resumed_result (Tabs.resume tabs ~owner args.tab)
  | P.List_tabs args ->
      success (P.yojson_of_list_result (Tabs.list tabs ~owner ~all:args.all))
  | P.Status -> success (P.yojson_of_status_result (report ?models_status tabs))
  | P.Drive args ->
      (* drive-ls3c: the text helper seam travels with the decision seam: production
         installs {!Models.text_helper}, scripted tests their own. *)
      lift P.yojson_of_drive_result
        (Tabs.drive ?decide ?text_helper tabs ~owner ~model args)
  | P.Discover args -> (
      let turns = Option.value ~default:20 args.max_turns in
      let steps = Option.value ~default:100 args.max_steps in
      let deadline_s = Option.value ~default:900 args.deadline_s in
      let cost = Option.value ~default:1. args.max_cost in
      if
        turns <= 0 || steps <= 0 || deadline_s <= 0
        || (not (Float.is_finite cost))
        || cost <= 0.
      then
        err "invalid-request" "discovery limits must be positive and cost must be finite"
      else
        let entry =
          if
            String.starts_with ~prefix:"https://" args.site
            || String.starts_with ~prefix:"http://" args.site
          then args.site
          else "https://" ^ args.site
        in
        let offset = if String.starts_with ~prefix:"https://" entry then 8 else 7 in
        let authority = String.sub entry offset (String.length entry - offset) in
        let host =
          match String.split_on_char '/' authority with head :: _ -> head | [] -> ""
        in
        if
          host = "" || String.contains host '@' || String.contains host ' '
          || String.contains host ':'
        then
          err "invalid-request"
            "discover requires a valid HTTP(S) site or URL without credentials or port"
        else
          let seed =
            Playbook.
              {
                site = host;
                entry;
                description = "Discovered " ^ host;
                pages = [];
                procedures = [];
              }
          in
          match Playbook.of_json ~file:"discovery seed" (Playbook.yojson_of_t seed) with
          | Error why -> err "invalid-request" why
          | Ok book -> (
              match Tabs.new_tab tabs ~owner ~url:(Some entry) with
              | Error error -> failure error
              | Ok info ->
                  let run_args =
                    P.
                      {
                        tab = Some info.tab;
                        mission = Option.value ~default:("Explore " ^ host) args.goal;
                        max_procedures = Some turns;
                        deadline_s = Some deadline_s;
                        dry_run = Some false;
                        expect = None;
                      }
                  in
                  lift P.yojson_of_run_result
                    (Tabs.run ?levels ~model ?decide ?text_helper ?installed
                       ~discovery:(Run.{ book; max_steps = steps; max_cost = cost }, turns)
                       tabs ~owner ~tab:info.tab run_args)))
  | P.Run args -> (
      (* run-vj48 run-4mzm: the run's upper levels are one more seam. Production installs
         {!Models.levels} — one System One client for all three levels (run-7blx) — and
         scripted tests their own; [installed] hands a test its playbooks.

         run-9ypy: a mission with no tab opens one the way the [new] command does and the
         run reuses it; the [final] snapshot names it and the run never closes it. *)
      let tab =
        match args.P.tab with
        | Some tab -> Ok tab
        | None ->
            Result.map
              (fun (info : P.tab_info) -> info.P.tab)
              (Tabs.new_tab tabs ~owner ~url:None)
      in
      match tab with
      | Error error -> failure error
      | Ok tab ->
          lift P.yojson_of_run_result
            (Tabs.run ?levels ~model ?decide ?text_helper ?installed tabs ~owner ~tab args)
      )

(* svc-p67t: a command's journal anchor contains only identifiers, never args or
   results. Commands without a tab use "-"; new does not have a handle yet. *)
let command_tab = function
  | P.New _ | P.List_tabs _ | P.Status -> "-"
  | P.Claim args | P.Resume args | P.Downloads args -> P.Handle.to_string args.tab
  | P.Release args | P.Close args -> P.Handle.to_string args.tab
  | P.Snap args -> P.Handle.to_string args.tab
  | P.Text args -> P.Handle.to_string args.tab
  | P.Shot args -> P.Handle.to_string args.tab
  | P.Debug args -> P.Handle.to_string args.tab
  | P.Eval args -> P.Handle.to_string args.tab
  | P.Nav args -> P.Handle.to_string args.tab
  | P.Click args -> P.Handle.to_string args.tab
  | P.Fill args -> P.Handle.to_string args.tab
  | P.Press args -> P.Handle.to_string args.tab
  | P.Select args -> P.Handle.to_string args.tab
  | P.Scroll args -> P.Handle.to_string args.tab
  | P.Wait args -> P.Handle.to_string args.tab
  | P.Dialog args -> P.Handle.to_string args.tab
  | P.Handoff args -> P.Handle.to_string args.tab
  | P.Drive args -> P.Handle.to_string args.tab
  | P.Run args -> (
      match args.tab with Some tab -> P.Handle.to_string tab | None -> "-")
  | P.Discover _ -> "-"

let with_command ?logger (request : P.request) f =
  Eta_observability.Context.with_fields
    [
      ("tab", command_tab request.command);
      ("owner", P.Owner.to_string request.owner);
      ("cmd", P.command_name request.command);
    ]
    (fun () ->
      Option.iter
        (fun logger -> Eta_observability.Logger.info logger "control command")
        logger;
      f ())

let handle ?(model = "unconfigured") ?levels ?decide ?text_helper ?installed
    ?models_status ?logger tabs line =
  let reply =
    match decode line with
    | Error why -> invalid why
    | Ok request ->
        with_command ?logger request (fun () ->
            dispatch ~model ?levels ?decide ?text_helper ?installed ?models_status tabs
              request)
  in
  Yojson.Safe.to_string (P.encode_reply reply)

type t = { path : string }

(* The registry bounds a url load at 30 seconds (chrome-1yn9 on [nav], chrome-qnul on
   [new]); the handler budget must outlast it plus the CDP calls around it, or a slow
   page's reply never reaches the client and its connection simply closes. *)
let load_budget = Eta.Duration.seconds 35

(* tab-0ohq tab-1lhx: a trusted input is settled by its own reply or by the popup it
   opened, so a dispatch whose reply Chrome withholds waits out the 30-second CDP deadline
   and the probes after it before it can report [browser-unavailable]. A row action gets
   the same headroom a load does; anything less and a wedged page's reply never reaches the
   client at all. *)
let cdp_budget = Eta.Duration.seconds 35

(* hand-lmd5 hand-04rb hand-phof: a handoff's budget is its own deadline plus a margin,
   never less. The listener's timeout cancels the handler it bounds, so a budget equal to
   the handoff deadline would cancel the handler at the instant it is due to answer
   [timeout]: the client would see its connection close instead of the reply. The margin
   is the human-facing side's, which a handoff whose deadline has already passed still has
   to finish: up to five seconds each for [Target.activateTarget], the Chrome-window lookup
   and the focus command (hand-rg9h), plus the reply's own egress. *)
let handoff_margin = Eta.Duration.seconds 20

let budget (request : (P.request, string) result) =
  let seconds n = Eta.Duration.seconds n in
  match request with
  | Error _ -> Some (seconds 1)
  | Ok { command = P.Wait args; _ } ->
      Some
        (Eta.Duration.ms
           (min 30000 (max 1 (Option.value ~default:30000 args.timeout_ms)) + 1000))
  | Ok { command = P.Handoff args; _ } ->
      Some (Eta.Duration.add (Tabs.handoff_timeout args.timeout_s) handoff_margin)
  | Ok { command = P.Drive args; _ } ->
      Some (seconds (max 1 (Option.value ~default:120 args.deadline_s) + 5))
  | Ok { command = P.Discover args; _ } ->
      Some (seconds (max 1 (Option.value ~default:900 args.deadline_s) + 75))
  | Ok { command = P.Run args; _ } ->
      (* run-vspj run-obtt: a run's budget is its deadline plus the margin its last steps
         need — the procedure's own bounded expectation wait (at most 30 s), a planner
         turn's correction call (at most 30 s, L32) and the reply — so the listener never
         cancels a run at the instant it is due to answer. *)
      Some (seconds (max 1 (Option.value ~default:900 args.deadline_s) + 75))
  | Ok { command = P.Shot _ | P.Eval _ | P.Text _ | P.Dialog _; _ } -> Some (seconds 35)
  | Ok { command = P.Nav _; _ } -> Some load_budget
  | Ok { command = P.New args; _ } when Tabs.waits_for_load args.url -> Some load_budget
  | Ok { command = P.Click _ | P.Fill _ | P.Press _ | P.Select _ | P.Scroll _; _ } ->
      Some cdp_budget
  | Ok _ -> Some (seconds 1)

(* hard-yi0a: Eta_ipc cancels the handler at this budget, then sends this reply
   through ordinary encode/egress. The request was already decoded, so its command
   and configured budget can be given to the caller without replaying any action. *)
let budget_exceeded (request : (P.request, string) result) budget =
  let command =
    match request with
    | Ok request -> P.command_name request.command
    | Error _ -> "invalid-request"
  in
  let budget_ms = Eta.Duration.to_ms budget in
  failure
    P.
      {
        code = enum "timeout";
        message =
          Printf.sprintf "%s ran for its full handler budget of %d ms" command budget_ms;
        detail =
          Some (`Assoc [ ("command", `String command); ("budget_ms", `Int budget_ms) ]);
      }

(* tab-x4v0 tab-0lax: the listener's 64 KiB default drops this protocol's own
   bounded shapes — a 64K-character text reply, a 64 KiB eval result or argument, a
   64 KiB fill — by closing the connection with no reply at all. 1 MiB each way covers
   every bounded shape with headroom and matches the CLI's own 1 MiB reply read. *)
let policy : Eta_ipc.Listener.policy =
  let open Eta_ipc.Listener in
  { default_policy with max_line_bytes = 1_048_576; max_reply_bytes = 1_048_576 }

(* A peer the listener turns away is a log line, never a silent close: from the
   client's side a dropped reply is indistinguishable from a dead service. A client
   that went away is routine — a killed handoff waiter disconnects mid-request — while
   a timeout, an oversize line or reply, or a budget overrun is a warning. *)
let on_peer_error logger error =
  let code, routine =
    match error with
    | `Ingress_timeout -> ("ingress_timeout", false)
    | `Ingress_too_large -> ("ingress_too_large", false)
    | `Ingress_closed -> ("ingress_closed", true)
    | `Decode _ -> ("decode", false)
    | `Handler _ -> ("handler", false)
    | `Handler_budget_exceeded -> ("handler_budget_exceeded", false)
    | `Egress_timeout -> ("egress_timeout", false)
    | `Egress_too_large -> ("egress_too_large", false)
    | `Egress_closed -> ("egress_closed", true)
    | `Disconnected -> ("disconnected", true)
  in
  let fields = [ ("code", Eta_observability.Logger.String code) ] in
  if routine then Eta_observability.Logger.debug logger ~fields "control client went away"
  else
    Eta_observability.Logger.warn logger ~fields
      "control dropped a request without a reply"

(* svc-o4wt: the socket is the configured path, not a name this module derives — a test or
   a second instance relocates it. The listener verifies the directory it sits in (0700,
   owned by the caller) and refuses a second instance on the same path. *)
let create ?(model = "unconfigured") ?levels ?decide ?text_helper ?installed ~sw ~path
    deps =
  let decode line =
    Ok (match decode line with Ok request -> Ok request | Error why -> Error why)
  in
  let handler (request : (P.request, string) result) =
    let reply =
      match request with
      | Ok request ->
          with_command ~logger:deps.logger request (fun () ->
              dispatch ~model ?levels ?decide ?text_helper ?installed
                ~models_status:deps.models_status deps.tabs request)
      | Error why -> invalid why
    in
    Ok reply
  in
  match
    Eta_ipc.Listener.run ~sw ~fs:deps.fs ~net:deps.net ~clock:deps.clock ~path ~policy
      ~decode
      ~encode:(fun reply -> Yojson.Safe.to_string (P.encode_reply reply))
      ~budget ~on_budget_exceeded:budget_exceeded ~handler
      ~on_peer_error:(on_peer_error deps.logger) ()
  with
  | Ok () -> Ok { path }
  | Error error -> Error error

let status t =
  Eta_app.Status.make ~details:[ ("socket", t.path) ] "control" Eta_app.Status.Ok
