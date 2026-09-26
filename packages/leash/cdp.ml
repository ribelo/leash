type transport = {
  read : Eio_unix.source_ty Eio.Resource.t;
  write : Eio_unix.sink_ty Eio.Resource.t;
}

module Frame = struct
  type t = { input : Eio.Buf_read.t; output : Eio_unix.sink_ty Eio.Resource.t }

  let encode message = Yojson.Safe.to_string message ^ "\000"

  let of_flows ?(max_size = 1_048_576) ~read ~write () =
    { input = Eio.Buf_read.of_flow ~max_size read; output = write }

  let read t =
    if Eio.Buf_read.at_end_of_input t.input then None
    else begin
      let payload = Eio.Buf_read.take_while (fun c -> c <> '\000') t.input in
      Eio.Buf_read.char '\000' t.input;
      Some (Yojson.Safe.from_string payload)
    end

  let write t message = Eio.Flow.copy_string (encode message) t.output
end

let member name = function `Assoc fields -> List.assoc_opt name fields | _ -> None
let id message = match member "id" message with Some (`Int id) -> Some id | _ -> None

let session message =
  match member "sessionId" message with Some (`String id) -> Some id | _ -> None

let set_id message id =
  match message with
  | `Assoc fields -> `Assoc (("id", `Int id) :: List.remove_assoc "id" fields)
  | other -> other

type error = Eta_rpc.Correlator.error

type t = {
  correlator : Yojson.Safe.t Eta_rpc.Correlator.t;
  closed : Eta_rpc.Correlator.close_reason Eio.Promise.t;
  closed_u : Eta_rpc.Correlator.close_reason Eio.Promise.u;
}

let create ~sw ~clock ?max_size ?max_notifications transport =
  let frame = Frame.of_flows ?max_size ~read:transport.read ~write:transport.write () in
  let closed, closed_u = Eio.Promise.create () in
  let settle reason = ignore (Eio.Promise.try_resolve closed_u reason) in
  let read () =
    match Frame.read frame with
    | None ->
        settle `Eof;
        None
    | Some _ as message -> message
    | exception ex ->
        settle (`Read_failed ex);
        raise ex
  in
  let write message = Frame.write frame message in
  let correlator =
    Eta_rpc.Correlator.create ~sw ~clock ?max_notifications ~read ~write ~id ~set_id
      ~session ()
  in
  { correlator; closed; closed_u }

let call t ?session ?deadline method_ params =
  let message =
    `Assoc
      ([ ("method", `String method_); ("params", params) ]
      @
      match session with
      | None -> []
      | Some session -> [ ("sessionId", `String session) ])
  in
  Eta_rpc.Correlator.call t.correlator ?session ?deadline message

let events t = Eta_rpc.Correlator.notifications t.correlator
let closed t = t.closed
let stats t = Eta_rpc.Correlator.stats t.correlator
let result message = member "result" message

let error_of_reply message =
  match member "error" message with
  | Some error -> (
      match (member "code" error, member "message" error) with
      | Some (`Int code), Some (`String text) -> Some (code, text)
      | _ -> None)
  | None -> None

let close t =
  Eta_rpc.Correlator.close t.correlator;
  ignore (Eio.Promise.try_resolve t.closed_u `Closed)
