(* OxCaml local mode annotations below are not parsed by ocamlformat 0.29.
   Keep this file in .ocamlformat-ignore until the formatter supports them. *)
module P = Protocol
module J = Jev_request

type observation = {
  snapshot : P.snapshot;
  text : string;
  can_scroll_down : bool;
  can_scroll_up : bool;
  fingerprint : string;
}

type handler = {
  observe : unit -> (observation, P.error) result;
  decide : J.request -> (J.decision, P.error) result;
  text_value : Text_helper.context -> (string option, P.error) result;
  act : observation -> J.decision -> text:string option -> (P.action_result, P.error) result;
}

(* drive-ls3c: what a type_text step needs before it acts. [Nothing] is every other
   operation and a dry run; [Value] is the text helper's answer, which the act writes; and
   [Missing] is the model's null — the value is missing — which ends the drive [blocked]
   naming the field. *)
type wanted = Nothing | Value of string | Missing of string

(* Each operation has an internal callback and a local-only public use. A token cannot
   escape the dynamic extent of run; even a nested drive has its own effect constructors. *)
type token = {
  observe : unit -> (observation, P.error) result;
  decide : J.request -> (J.decision, P.error) result;
  text_value : Text_helper.context -> (string option, P.error) result;
  act : observation -> J.decision -> string option -> (P.action_result, P.error) result;
}
let observe (t : token @ local) () = t.observe ()
let decide (t : token @ local) request = t.decide request
let text_value (t : token @ local) context = t.text_value context
let act (t : token @ local) page choice text = ((t.act page) choice) text

let operation name = match P.Operation.of_string name with Ok x -> x | Error _ -> assert false
let op_name = P.Operation.to_string
let status name = match P.Drive_status.of_string name with Ok x -> x | Error _ -> assert false
let internal message =
  let code = match P.Error_code.of_string "internal" with Ok x -> x | Error _ -> assert false in
  P.{ code; message; detail = None }
let ms seconds = max 0 (int_of_float (seconds *. 1000.))
let result ?reason status steps (final : observation) =
  P.{ status; steps = List.rev steps; final = final.snapshot; reason }

(* drive-y7v8: an error names its cause, so the agent reading the trace knows whether
   to hand off, retry, or give up. *)
let failed what (error : P.error) =
  Printf.sprintf "%s failed (%s): %s" what
    (P.Error_code.to_string error.P.code)
    error.P.message

(* drive-n3ld: the dialog itself is in the final snapshot dialog field in full; the
   reason names its kind. Popups are the caller tabs to list; the reason counts them. *)
let dialog_reason (dialog : P.dialog) =
  "dialog open: " ^ P.Dialog_kind.to_string dialog.P.kind

let popup_reason popups =
  match List.length popups with
  | 1 -> "1 popup opened"
  | n -> Printf.sprintf "%d popups opened" n
let history (step : P.step) changed =
  J.{ action = op_name step.operation;
      kind = Some (if step.operation = operation "type_text" then "fill"
                   else if step.operation = operation "scroll_up" || step.operation = operation "scroll_down" then "scroll"
                   else op_name step.operation);
      text = step.text; page_changed = Some changed }

let loop (t : token) ~now ~model ~(args : P.drive_args) ~dry_run =
  let started = now () in
  let deadline = started +. float_of_int (Option.value ~default:120 args.P.deadline_s) in
  let cap = Option.value ~default:30 args.P.max_steps in
  let with_steps steps error =
    if error.P.code <> (match P.Error_code.of_string "model-unavailable" with Ok x -> x | Error _ -> assert false)
    then error
    else let code = match error.detail with
      | Some (`Assoc fields) -> (match List.assoc_opt "code" fields with Some x -> x | None -> `String "unavailable")
      | _ -> `String "unavailable" in
      { error with detail = Some (`Assoc ["code", code; "steps", `List (List.map P.yojson_of_step (List.rev steps))]) }
  in
  (* drive-ls3c drive-fh1h: the context a type_text decision is asked from, built from
     the element JEV chose — the same row the request offered — and the drive's own
     history, oldest first. jev's field_context is this, bounded by the text helper when
     it writes the request. *)
  let context page choice recent =
    match choice.J.index with
    | None -> Error (internal "a type_text decision names no field")
    | Some index ->
      (match List.find_opt (fun (element : J.element) -> element.row = index)
               (J.elements page.snapshot) with
       | None -> Error (internal (Printf.sprintf "row %d is not in the snapshot of a type_text decision" index))
       | Some element ->
         Ok Text_helper.{ goal = args.P.goal;
           field = { label = element.label; role = element.role; value = element.value };
           page_title = page.snapshot.title; page_text = page.text;
           recent = List.rev recent })
  in
  (* A dry run and every operation that is not type_text ask nothing; a terminal one has
     already decided. A null answer ends the drive [blocked] with the field named, before
     anything reaches the browser. *)
  let ask_text page choice recent ~terminal =
    if dry_run || terminal || choice.J.operation <> operation "type_text" then Ok Nothing
    else match context page choice recent with
      | Error error -> Error error
      | Ok context ->
        (match text_value t context with
         | Ok (Some value) -> Ok (Value value)
         | Ok None -> Ok (Missing context.Text_helper.field.label)
         | Error error -> Error error)
  in
  match observe t () with
  | Error e -> Error (with_steps [] e)
  | Ok first ->
    let rec go n page steps recent =
      if now () >= deadline then Ok (result (status "deadline") steps page)
      else if n >= cap then Ok (result (status "step-cap") steps page)
      else if page.snapshot.dialog <> None then
        let reason = Option.map dialog_reason page.snapshot.dialog in
        Ok (result ?reason (status "error") steps page)
      else
        let request = J.make ~model ~goal:args.goal ~snapshot:page.snapshot ~text:page.text
          ~recent:(List.rev recent) ~can_scroll_down:page.can_scroll_down ~can_scroll_up:page.can_scroll_up in
        match decide t request with
        | Error error -> Error (with_steps steps error)
        | Ok choice ->
          let op = choice.operation in
          let terminal = op = operation "done" || op = operation "blocked" in
          let record text (next : observation) steps =
            let step = P.{ n = n + 1; snapshot = page.snapshot.snapshot;
              operation = op; index = choice.index;
              probabilities = J.trace_probabilities choice; text;
              after = { url = next.snapshot.url; title = next.snapshot.title };
              elapsed_ms = ms (now () -. started) } in
            (step :: steps, history step (page.fingerprint <> next.fingerprint)) in
          let step text =
            let outcome = if dry_run || terminal then Ok None
              else Result.map (fun a -> Some a) (act t page choice text) in
            match outcome with
            | Error error when P.Error_code.to_string error.code = "stale-snapshot" ->
                (match observe t () with Error e -> Error (with_steps steps e)
                 | Ok refreshed -> go (n + 1) refreshed steps recent)
            | Error act_error ->
              let steps, _ = record text page steps in
              let reason = failed ("the " ^ op_name op ^ " action") act_error in
              Ok (result ~reason (status "error") steps page)
            | Ok action ->
              let next = if dry_run || terminal then Ok page else observe t () in
              (match next with
               | Error observe_error ->
                 let steps, _ = record text page steps in
                 let reason = failed "observe after the action" observe_error in
                 Ok (result ~reason (status "error") steps page)
               | Ok next ->
                 let steps, entry = record text next steps in
                 let recent = entry :: recent in
                 let interrupted =
                   match action with
                   | Some acted -> (
                       match (acted.dialog, acted.popups) with
                       | Some dialog, _ -> Some (dialog_reason dialog)
                       | None, _ :: _ -> Some (popup_reason acted.popups)
                       | None, [] -> None)
                   | None -> None
                 in
                 (match interrupted with
                  | Some reason -> Ok (result ~reason (status "error") steps next)
                  | None when op = operation "done" ->
                      Ok (result (status "done") steps next)
                  | None when op = operation "blocked" || dry_run || J.stalled (List.rev recent)
                    -> Ok (result (status "blocked") steps next)
                  | None -> go (n + 1) next steps recent))
          in
          match ask_text page choice recent ~terminal with
          | Error error -> Error (with_steps steps error)
          | Ok (Missing field) ->
            (* drive-ls3c: the model answered null — the value is missing — so the drive
               ends blocked with the field named and the decision in the trace. *)
            let steps, _ = record None page steps in
            Ok (result ~reason:(Printf.sprintf "no value for field %S" field)
                  (status "blocked") steps page)
          | Ok (Value value) -> step (Some value)
          | Ok Nothing -> step None
    in go 0 first [] []

let run ~(handler : handler) ~now ~model ~(args : P.drive_args) ~dry_run =
  if Option.value ~default:30 args.P.max_steps < 1 ||
     Option.value ~default:120 args.deadline_s < 1 then
    Error P.{code=(match Error_code.of_string "invalid-request" with Ok x -> x | Error _ -> assert false);
      message="drive max_steps and deadline_s must be positive";detail=None}
  else
    let module M = struct
      type _ Effect.t += Observe : (observation, P.error) result Effect.t
      type _ Effect.t += Decide : J.request -> (J.decision, P.error) result Effect.t
      type _ Effect.t += Text : Text_helper.context -> (string option, P.error) result Effect.t
      type _ Effect.t += Act : observation * J.decision * string option -> (P.action_result, P.error) result Effect.t
    end in
    let token = {
      observe = (fun () -> Effect.perform M.Observe);
      decide = (fun request -> Effect.perform (M.Decide request));
      text_value = (fun context -> Effect.perform (M.Text context));
      act = (fun page choice text -> Effect.perform (M.Act (page, choice, text)));
    } in
    Effect.Deep.match_with (fun () -> loop token ~now ~model ~args ~dry_run) ()
      { retc = Fun.id; exnc = raise;
        effc = (fun (type a) (eff : a Effect.t) -> match eff with
          | M.Observe -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.observe ()))
          | M.Decide request -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.decide request))
          | M.Text context -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.text_value context))
          | M.Act (page, choice, text) -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.act page choice ~text))
          | _ -> None) }
