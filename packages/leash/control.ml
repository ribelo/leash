module P = Protocol

type ('clock, 'net) deps = {
  tabs : Tabs.t;
  status_query : unit -> Eta_app.Status.t list;
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

let unsupported = err "invalid-request" "this command is not available in milestone 1"

let dispatch tabs (request : P.request) =
  let owner = request.owner in
  let lift encode = function
    | Ok result -> success (encode result)
    | Error error -> failure error
  in
  match request.command with
  | P.New args -> lift P.yojson_of_tab_info (Tabs.new_tab tabs ~owner ~url:args.url)
  | P.Snap args -> lift P.yojson_of_snapshot (Tabs.snap tabs ~owner args)
  | P.Nav args ->
      lift P.yojson_of_action_result (Tabs.navigate tabs ~owner args.tab args.url)
  | P.Close args -> lift P.yojson_of_closed_result (Tabs.close tabs ~owner args.tab)
  | P.List_tabs args ->
      success (P.yojson_of_list_result (Tabs.list tabs ~owner ~all:args.all))
  | P.Status -> success (P.yojson_of_status_result (Tabs.report tabs))
  | _ -> unsupported

let handle tabs line =
  let reply =
    match decode line with
    | Error why -> invalid why
    | Ok request ->
        Eta_observability.Context.with_fields
          [
            ("owner", P.Owner.to_string request.owner);
            ("cmd", P.command_name request.command);
          ]
          (fun () -> dispatch tabs request)
  in
  Yojson.Safe.to_string (P.encode_reply reply)

type t = { path : string }

(* The registry bounds a url load at 30 seconds (chrome-1yn9 on [nav], chrome-qnul on
   [new]); the handler budget must outlast it plus the CDP calls around it, or a slow
   page's reply never reaches the client and its connection simply closes. *)
let load_budget = Eta.Duration.seconds 35

let budget (request : (P.request, string) result) =
  let seconds n = Eta.Duration.seconds n in
  match request with
  | Error _ -> Some (seconds 1)
  | Ok { command = P.Wait args; _ } ->
      Some
        (Eta.Duration.ms
           (min 30000 (max 1 (Option.value ~default:30000 args.timeout_ms))))
  | Ok { command = P.Handoff args; _ } ->
      Some (seconds (max 1 (Option.value ~default:900 args.timeout_s)))
  | Ok { command = P.Drive args; _ } ->
      Some (seconds (max 1 (Option.value ~default:30 args.deadline_s)))
  | Ok { command = P.Nav _; _ } -> Some load_budget
  | Ok { command = P.New args; _ } when Tabs.waits_for_load args.url -> Some load_budget
  | Ok _ -> Some (seconds 1)

let create ~sw ~runtime_dir deps =
  let path = Filename.concat (Filename.concat runtime_dir "leash") "control.sock" in
  let decode line =
    Ok (match decode line with Ok request -> Ok request | Error why -> Error why)
  in
  let handler (request : (P.request, string) result) =
    let reply =
      match request with
      | Ok request ->
          Eta_observability.Context.with_fields
            [
              ("owner", P.Owner.to_string request.owner);
              ("cmd", P.command_name request.command);
            ]
            (fun () -> dispatch deps.tabs request)
      | Error why -> invalid why
    in
    Ok reply
  in
  match
    Eta_ipc.Listener.run ~sw ~fs:deps.fs ~net:deps.net ~clock:deps.clock ~path ~decode
      ~encode:(fun reply -> Yojson.Safe.to_string (P.encode_reply reply))
      ~budget ~handler ()
  with
  | Ok () -> Ok { path }
  | Error error -> Error error

let status t =
  Eta_app.Status.make ~details:[ ("socket", t.path) ] "control" Eta_app.Status.Ok
