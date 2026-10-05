module P = Protocol

let ( let* ) = Result.bind

type caps = < Ox_caps.Cap.fs_write ; Ox_caps.Cap.network >

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Ox_app.Status.t list;
  models_status : unit -> P.models_status;
      (** L19: what [status] reports about the models section. The thunk reads the live
          configuration and never the key. *)
  fs : Eio.Fs.dir_ty Eio.Path.t;
  net : 'net Eio.Net.ty Eio.Resource.t;
  clock : 'clock Eio.Time.clock;
  logger : Ox_observability.Logger.t;
  caps : caps;
}

let success json = P.Success json
let failure error = P.Failure error

let enum code =
  match P.Error_code.of_string code with Ok v -> v | Error _ -> assert false

let err code message = failure (P.make_error (enum code) ~message)
let invalid why = err "invalid-request" ("invalid request at " ^ why)

let decode line =
  try P.decode_request (Yojson.Safe.from_string line)
  with Yojson.Json_error why -> Error ("/: " ^ why)

let unsupported = err "invalid-request" "this command is not available yet"

(* L19: the status reply is the registry's plus the models section, which only the
   listener's models service knows. A dispatch that was given no models service reports
   [null] there rather than inventing a configuration. *)
let report ?models_status ?chrome_pid tabs =
  let report = Tabs.report tabs in
  let models = Option.map (fun models -> models ()) models_status in
  let running =
    match P.Chrome_phase.to_string report.chrome with "running" -> true | _ -> false
  in
  let pid = if running then Option.bind chrome_pid (fun pid -> pid ()) else None in
  {
    report with
    P.models;
    pid;
    key_present = (match models with Some models -> models.configured | None -> false);
  }

let dispatch ?pilot ?(planner_actions = 5) ?traces ?logger ?(model = "unconfigured")
    ?models ?levels ?decide ?text_helper ?installed ?models_status ?chrome_pid tabs
    (request : P.request) =
  let meter = Tabs.meter () in
  let decide, text_helper =
    match models with
    | None -> (decide, text_helper)
    | Some models ->
        ( Some
            (fun ~deadline request ->
              Models.decide ~deadline
                ~on_usage:(Tabs.note_usage meter "operator")
                models request),
          Some
            (fun () ->
              Models.text_helper ~on_usage:(Tabs.note_usage meter "text_helper") models)
        )
  in
  let lift encode = function
    | Ok result -> success (encode result)
    | Error error -> failure error
  in
  match request.command with
  | P.New args ->
      lift P.yojson_of_tab_info (Tabs.new_tab ?label:args.label tabs ~url:args.url)
  | P.Snap args -> lift P.yojson_of_snapshot (Tabs.snap tabs args)
  | P.Downloads args -> lift P.yojson_of_downloads_result (Tabs.downloads tabs args.tab)
  | P.Text args -> lift P.yojson_of_text_result (Tabs.text tabs args)
  | P.Eval args -> lift P.yojson_of_eval_result (Tabs.eval tabs args)
  | P.Shot args -> lift P.yojson_of_shot_result (Tabs.shot tabs args)
  | P.Debug args -> lift P.yojson_of_debug_result (Tabs.debug tabs args)
  | P.Wait args -> lift P.yojson_of_action_result (Tabs.wait tabs args)
  | P.Net args -> lift P.yojson_of_net_result (Tabs.net tabs args)
  | P.Net_body args -> lift P.yojson_of_net_body_result (Tabs.net_body tabs args)
  | P.Net_request args -> lift P.yojson_of_net_request_result (Tabs.net_request tabs args)
  | P.Cookies args -> lift P.yojson_of_cookies_result (Tabs.cookies tabs args)
  | P.Storage args -> lift P.yojson_of_storage_result (Tabs.storage tabs args)
  | P.Playbook_test args ->
      lift P.yojson_of_playbook_test_result (Tabs.playbook_test ?installed tabs args)
  | P.Playbook_check args ->
      lift P.yojson_of_playbook_check_result (Tabs.playbook_check ?installed tabs args)
  | P.Upload args -> lift P.yojson_of_action_result (Tabs.upload tabs args)
  | P.Hover args -> lift P.yojson_of_action_result (Tabs.hover tabs args)
  | P.Check args -> lift P.yojson_of_action_result (Tabs.check tabs args)
  | P.Uncheck args -> lift P.yojson_of_action_result (Tabs.uncheck tabs args)
  | P.Dialog args -> lift P.yojson_of_action_result (Tabs.dialog tabs args)
  | P.Click args -> lift P.yojson_of_action_result (Tabs.click tabs args)
  | P.Click_at args -> lift P.yojson_of_action_result (Tabs.click_at tabs args)
  | P.Dblclick args -> lift P.yojson_of_action_result (Tabs.dblclick tabs args)
  | P.Scroll_at args -> lift P.yojson_of_action_result (Tabs.scroll_at tabs args)
  | P.Drag args -> lift P.yojson_of_action_result (Tabs.drag tabs args)
  | P.Type args -> lift P.yojson_of_action_result (Tabs.type_text tabs args)
  | P.Fill args -> lift P.yojson_of_action_result (Tabs.fill tabs args)
  | P.Press args -> lift P.yojson_of_action_result (Tabs.press tabs args)
  | P.Select args -> lift P.yojson_of_action_result (Tabs.select tabs args)
  | P.Scroll args -> lift P.yojson_of_action_result (Tabs.scroll tabs args)
  | P.Nav args -> lift P.yojson_of_tab_info (Tabs.navigate tabs args.tab args.url)
  | P.Take args -> lift P.yojson_of_tab_info (Tabs.take tabs args)
  | P.Close args -> lift P.yojson_of_closed_result (Tabs.close tabs args.tab)
  | P.Handoff args ->
      (* hand-lz3p: the one command that blocks in the registry. The listener cancels this
         handler if the client disconnects, which is a handoff ending — the tab goes back
         to agent control — not a leak. *)
      lift P.yojson_of_handoff_result
        (Tabs.handoff tabs ~reason:args.reason ~timeout_s:args.timeout_s args.tab)
  | P.Resume args -> lift P.yojson_of_resumed_result (Tabs.resume tabs args.tab)
  | P.List_tabs -> success (P.yojson_of_list_result (Tabs.list tabs))
  | P.Status ->
      success (P.yojson_of_status_result (report ?models_status ?chrome_pid tabs))
  | P.Drive args ->
      (* trace-qe8c trace-uovo: persist a projection before reply encoding, including
         errors during tab acquisition. No trace I/O is performed without a store. *)
      let capture =
        Option.map
          (fun store ->
            Traces.capture
              ~mission:(P.redact_string args.secrets args.P.mission)
              ~now:(Traces.now store))
          traces
      in
      let on_page ~url ~kind = Option.iter (fun c -> Traces.page c ~url ~kind) capture in
      let on_arguments values =
        Option.iter (fun c -> Traces.arguments c values) capture
      in
      let on_step step = Option.iter (fun c -> Traces.step c step) capture in
      let on_planner_step step =
        Option.iter (fun c -> Traces.planner_step c step) capture
      in
      let keep outcome =
        match (traces, capture) with
        | Some store, Some capture ->
            Eio.Cancel.protect (fun () ->
                let now = Traces.now store in
                let trace = Traces.finish capture ~now outcome in
                let trace = { trace with out_requested = args.out <> None } in
                let warn what why =
                  Option.iter
                    (fun logger ->
                      Ox_observability.Logger.warn logger
                        ~fields:[ ("error", Ox_observability.Logger.String why) ]
                        what)
                    logger
                in
                match Traces.write store trace with
                | Error why ->
                    warn "drive trace write failed" why;
                    outcome
                | Ok path -> (
                    (match
                       Traces.prune store ~site:trace.P.Trace.site ~dry_run:false ~now ()
                     with
                    | Ok _ -> ()
                    | Error why -> warn "drive trace retention failed" why);
                    match outcome with
                    | Ok result -> Ok { result with P.trace_path = Some path }
                    | Error error ->
                        let fields =
                          match error.P.detail with
                          | Some (`Assoc fields) -> fields
                          | _ -> []
                        in
                        Error
                          {
                            error with
                            P.detail =
                              Some (`Assoc (("trace_path", `String path) :: fields));
                          }))
        | _ -> outcome
      in
      let outcome =
        try
          let tab =
            match args.P.tab with
            | Some tab -> Ok tab
            | None ->
                Result.map
                  (fun (info : P.tab_info) -> info.P.tab)
                  (Tabs.new_tab tabs ~url:None)
          in
          match tab with
          | Error error -> Error error
          | Ok tab -> (
              let cleanup () =
                if args.P.tab = None then
                  Eio.Cancel.protect (fun () ->
                      (* Exceptional cleanup must preserve the original failure. *)
                      let _closed_owned_tab = Tabs.close tabs tab in
                      ())
              in
              let outcome =
                try
                  Tabs.run ?pilot ~planner_actions ~on_page ~on_step ~on_planner_step
                    ~on_arguments ~meter ?levels ~model ?decide ?text_helper ?installed
                    tabs ~tab args
                with exn ->
                  cleanup ();
                  raise exn
              in
              match outcome with
              | Ok result
                when List.mem
                       (P.Run_status.to_string result.P.status)
                       [ "handoff"; "handoff-expired"; "canceled-by-operator" ]
                     || result.detail <> None ->
                  outcome
              | _ when args.P.tab <> None -> outcome
              | _ -> (
                  match Eio.Cancel.protect (fun () -> Tabs.close tabs tab) with
                  | Ok _ -> outcome
                  | Error error -> Error error))
        with exn ->
          (* Keep records the terminal state; the original exception is re-raised. *)
          let _recorded_interruption =
            keep (Error (P.make_error (enum "internal") ~message:"drive interrupted"))
          in
          raise exn
      in
      lift P.yojson_of_run_result (keep outcome)

(* svc-p67t: a command's journal anchor contains only identifiers, never args or
   results. Commands without a tab use "-"; new does not have a handle yet. *)
let with_command ?logger (request : P.request) f =
  Ox_observability.Context.with_fields
    [ ("cmd", P.command_name request.command) ]
    (fun () ->
      Option.iter
        (fun logger -> Ox_observability.Logger.info logger "control command")
        logger;
      f ())

let handle ?pilot ?(planner_actions = 5) ?traces ?(model = "unconfigured") ?models ?levels
    ?decide ?text_helper ?installed ?models_status ?chrome_pid ?logger tabs line =
  let reply =
    match decode line with
    | Error why -> invalid why
    | Ok request ->
        with_command ?logger request (fun () ->
            dispatch ?pilot ~planner_actions ?traces ?logger ~model ?models ?levels
              ?decide ?text_helper ?installed ?models_status ?chrome_pid tabs request)
  in
  Yojson.Safe.to_string (P.encode_reply reply)

type t = { path : string }

(* The registry bounds a url load at 30 seconds (chrome-1yn9 on [nav], chrome-qnul on
   [new]); the handler budget must outlast it plus the CDP calls around it, or a slow
   page's reply never reaches the client and its connection simply closes. *)
let load_budget = Ox.Duration.seconds 35

(* tab-0ohq tab-1lhx: a trusted input is settled by its own reply or by the popup it
   opened, so a dispatch whose reply Chrome withholds waits out the 30-second CDP deadline
   and the probes after it before it can report [browser-unavailable]. A row action gets
   the same headroom a load does; anything less and a wedged page's reply never reaches the
   client at all. *)
let cdp_budget = Ox.Duration.seconds 35

(* hand-lmd5 hand-04rb hand-phof: a handoff's budget is its own deadline plus a margin,
   never less. The listener's timeout cancels the handler it bounds, so a budget equal to
   the handoff deadline would cancel the handler at the instant it is due to answer
   [timeout]: the client would see its connection close instead of the reply. The margin
   is the human-facing side's, which a handoff whose deadline has already passed still has
   to finish: up to five seconds each for [Target.activateTarget], the Chrome-window lookup
   and the focus command (hand-rg9h), plus the reply's own egress. *)
let handoff_margin = Ox.Duration.seconds 20

let budget ?(pilot = Config.default.pilot) ?(handoff_timeout_s = 300)
    (request : (P.request, string) result) =
  let seconds n = Ox.Duration.seconds n in
  match request with
  | Error _ -> Some (seconds 1)
  | Ok { command = P.Wait args; _ } ->
      (* hard-sr9v: a wait may last an hour, and the handler budget is derived from the
         wait's own bound plus a second for the reply, so the listener never cancels a
         wait at the instant it is due to answer [timeout]. *)
      Some
        (Ox.Duration.ms
           (min Reading.max_wait_ms (max 1 (Option.value ~default:30_000 args.timeout_ms))
           + 1000))
  | Ok { command = P.Handoff args; _ } ->
      Some
        (Ox.Duration.add
           (Tabs.handoff_timeout ~default:handoff_timeout_s args.timeout_s)
           handoff_margin)
  | Ok { command = P.Drive args; _ } ->
      (* run-vspj run-obtt: a run's budget is its deadline plus the margin its last steps
         need — the procedure's own bounded expectation wait (at most 30 s), a planner
         turn's correction call (at most 30 s, L32) and the reply — so the listener never
         cancels a run at the instant it is due to answer. *)
      Some
        (seconds
           (max 1 (Option.value ~default:pilot.deadline_s args.deadline_s)
           + handoff_timeout_s + 75))
  | Ok { command = P.Snap args; _ } when args.with_image = Some true -> Some cdp_budget
  | Ok { command = P.Shot _ | P.Eval _ | P.Text _ | P.Dialog _ | P.Playbook_test _; _ } ->
      (* A script may await a fetch; the CDP call's own deadline is 30 s. *)
      Some (seconds 35)
  | Ok { command = P.Playbook_check _; _ } ->
      (* A blank tab opens, each script compiles in one call, and the tab closes. *)
      Some (seconds 35)
  | Ok { command = P.Nav _; _ } -> Some load_budget
  | Ok { command = P.New args; _ } when Tabs.waits_for_load args.url -> Some load_budget
  | Ok
      {
        command =
          ( P.Click _ | P.Click_at _ | P.Dblclick _ | P.Scroll_at _ | P.Drag _ | P.Type _
          | P.Fill _ | P.Press _ | P.Select _ | P.Scroll _ | P.Upload _ | P.Hover _
          | P.Check _ | P.Uncheck _ | P.Net_body _ | P.Net_request _ | P.Cookies _
          | P.Storage _ );
        _;
      } ->
      Some cdp_budget
  | Ok _ -> Some (seconds 1)

(* hard-yi0a: Ox_ipc cancels the handler at this budget, then sends this reply
   through ordinary encode/egress. The request was already decoded, so its command
   and configured budget can be given to the caller without replaying any action. *)
let budget_exceeded (request : (P.request, string) result) budget =
  let command =
    match request with
    | Ok request -> P.command_name request.command
    | Error _ -> "invalid-request"
  in
  let budget_ms = Ox.Duration.to_ms budget in
  failure
    (P.make_error
       ~detail:(`Assoc [ ("command", `String command); ("budget_ms", `Int budget_ms) ])
       (enum "timeout")
       ~message:
         (Printf.sprintf "%s ran for its full handler budget of %d ms" command budget_ms))

(* tab-x4v0 tab-0lax: the listener's 64 KiB default drops this protocol's own
   bounded shapes — a 64K-character text reply, a 64 KiB eval result or argument, a
   64 KiB fill — by closing the connection with no reply at all. 1 MiB each way covers
   every bounded shape with headroom and matches the CLI's own 1 MiB reply read. *)
(* hard-ovbx: a response body is bounded to 1 MiB, and JSON escaping can make a body that
   size several times larger on the wire, so a reply may be up to 8 MiB.

   hard-b1na: sixty-four requests may be in flight at once, not ox_ipc's default sixteen.
   A long `wait` holds its connection for as long as an hour, so ten agents with half
   their tabs waiting must not queue the other half behind them — and a wait is cheap: it
   takes no tab lock and one fiber. *)
let policy : Ox_ipc.Listener.policy =
  let open Ox_ipc.Listener in
  {
    default_policy with
    peers = 64;
    max_line_bytes = 1_048_576;
    max_reply_bytes = 8_388_608;
  }

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
  let fields = [ ("code", Ox_observability.Logger.String code) ] in
  if routine then Ox_observability.Logger.debug logger ~fields "control client went away"
  else
    Ox_observability.Logger.warn logger ~fields
      "control dropped a request without a reply"

(* svc-o4wt: the socket is the configured path, not a name this module derives — a test or
   a second instance relocates it. The listener verifies the directory it sits in (0700,
   owned by the caller) and refuses a second instance on the same path. *)
let create ?pilot ?(planner_actions = 5) ?traces ?(model = "unconfigured") ?models ?levels
    ?decide ?text_helper ?installed ?chrome_pid ~sw ~path deps =
  let decode line =
    Ok (match decode line with Ok request -> Ok request | Error why -> Error why)
  in
  let handler (request : (P.request, string) result) =
    let reply =
      match request with
      | Ok request ->
          with_command ~logger:deps.logger request (fun () ->
              dispatch ?pilot ~planner_actions ?traces ~logger:deps.logger ~model ?models
                ?levels ?decide ?text_helper ?installed ~models_status:deps.models_status
                ?chrome_pid deps.tabs request)
      | Error why -> invalid why
    in
    Ok reply
  in
  match
    Ox_ipc.Listener.run ~caps:deps.caps ~sw ~fs:deps.fs ~net:deps.net ~clock:deps.clock
      ~path ~policy ~decode
      ~encode:(fun reply -> Yojson.Safe.to_string (P.encode_reply reply))
      ~budget:(budget ?pilot ~handoff_timeout_s:(Tabs.handoff_timeout_s deps.tabs))
      ~on_budget_exceeded:budget_exceeded ~handler
      ~on_peer_error:(on_peer_error deps.logger) ()
  with
  | Ok () -> Ok { path }
  | Error error -> Error error

let status t =
  Ox_app.Status.make ~details:[ ("socket", t.path) ] "control" Ox_app.Status.Ok
