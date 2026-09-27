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
  act : observation -> J.decision -> (P.action_result, P.error) result;
}

(* Each operation has an internal callback and a local-only public use. A token cannot
   escape the dynamic extent of run; even a nested drive has its own effect constructors. *)
type token = {
  observe : unit -> (observation, P.error) result;
  decide : J.request -> (J.decision, P.error) result;
  act : observation -> J.decision -> (P.action_result, P.error) result;
}
let observe (t : token @ local) () = t.observe ()
let decide (t : token @ local) request = t.decide request
let act (t : token @ local) page choice = (t.act page) choice

let operation name = match P.Operation.of_string name with Ok x -> x | Error _ -> assert false
let op_name = P.Operation.to_string
let status name = match P.Drive_status.of_string name with Ok x -> x | Error _ -> assert false
let ms seconds = max 0 (int_of_float (seconds *. 1000.))
let result ?reason status steps (final : observation) =
  P.{ status; steps = List.rev steps; final = final.snapshot; reason }
let history (step : P.step) changed =
  J.{ action = op_name step.operation;
      kind = Some (if step.operation = operation "type_text" then "fill"
                   else if step.operation = operation "scroll_up" || step.operation = operation "scroll_down" then "scroll"
                   else op_name step.operation);
      text = step.text; page_changed = Some changed }

let loop (t : token) ~now ~model ~args ~dry_run =
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
  match observe t () with
  | Error e -> Error (with_steps [] e)
  | Ok first ->
    let rec go n page steps recent =
      if now () >= deadline then Ok (result (status "deadline") steps page)
      else if n >= cap then Ok (result (status "step-cap") steps page)
      else if page.snapshot.dialog <> None then Ok (result (status "error") steps page)
      else
        let request = J.make ~model ~goal:args.goal ~snapshot:page.snapshot ~text:page.text
          ~recent:(List.rev recent) ~can_scroll_down:page.can_scroll_down ~can_scroll_up:page.can_scroll_up in
        match decide t request with
        | Error error -> Error (with_steps steps error)
        | Ok choice ->
          let op = choice.operation in
          let terminal = op = operation "done" || op = operation "blocked" in
          let outcome = if dry_run || terminal || op = operation "type_text" then Ok None
            else Result.map (fun a -> Some a) (act t page choice) in
          let record (next : observation) steps =
            let step = P.{ n = n + 1; snapshot = page.snapshot.snapshot;
              operation = op; index = choice.index;
              probabilities = J.trace_probabilities choice; text = None;
              after = { url = next.snapshot.url; title = next.snapshot.title };
              elapsed_ms = ms (now () -. started) } in
            (step :: steps, history step (page.fingerprint <> next.fingerprint)) in
          match outcome with
          | Error error when P.Error_code.to_string error.code = "stale-snapshot" ->
              (match observe t () with Error e -> Error (with_steps steps e)
               | Ok refreshed -> go (n + 1) refreshed steps recent)
          | Error _ ->
            let steps, _ = record page steps in
            Ok (result (status "error") steps page)
          | Ok action ->
            let next = if dry_run || terminal then Ok page else observe t () in
            (match next with
             | Error _ ->
               let steps, _ = record page steps in
               Ok (result (status "error") steps page)
             | Ok next ->
               let steps, entry = record next steps in
               let recent = entry :: recent in
               if action <> None && ((match action with Some a -> a.dialog <> None || a.popups <> [] | None -> false)) then
                 Ok (result (status "error") steps next)
               else if op = operation "done" then Ok (result (status "done") steps next)
               else if op = operation "type_text" then
                 Ok (result ~reason:"text helper unavailable" (status "blocked") steps next)
               else if op = operation "blocked" || dry_run || J.stalled (List.rev recent) then
                 Ok (result (status "blocked") steps next)
               else go (n + 1) next steps recent)
    in go 0 first [] []

let run ~(handler : handler) ~now ~model ~args ~dry_run =
  if Option.value ~default:30 args.P.max_steps < 1 ||
     Option.value ~default:120 args.deadline_s < 1 then
    Error P.{code=(match Error_code.of_string "invalid-request" with Ok x -> x | Error _ -> assert false);
      message="drive max_steps and deadline_s must be positive";detail=None}
  else
    let module M = struct
      type _ Effect.t += Observe : (observation, P.error) result Effect.t
      type _ Effect.t += Decide : J.request -> (J.decision, P.error) result Effect.t
      type _ Effect.t += Act : observation * J.decision -> (P.action_result, P.error) result Effect.t
    end in
    let token = {
      observe = (fun () -> Effect.perform M.Observe);
      decide = (fun request -> Effect.perform (M.Decide request));
      act = (fun page choice -> Effect.perform (M.Act (page, choice)));
    } in
    Effect.Deep.match_with (fun () -> loop token ~now ~model ~args ~dry_run) ()
      { retc = Fun.id; exnc = raise;
        effc = (fun (type a) (eff : a Effect.t) -> match eff with
          | M.Observe -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.observe ()))
          | M.Decide request -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.decide request))
          | M.Act (page, choice) -> Some (fun (k : (a, (P.drive_result, P.error) result) Effect.Deep.continuation) -> Effect.Deep.continue k (handler.act page choice))
          | _ -> None) }
