(* L22 — one model failure as the protocol's [model-unavailable]
   (docs/issues/drive/01-drive.md, milestone 5; drive-kh2u drive-ls3c).

   L19 mapped System One's failures inside [Models]. L22 gives the chat text helper the
   same closed set of {!Ox_ai.Error.t}, so the table moves here and both callers share
   it: docs/protocol.md lists the kinds, and a caller reads [detail.code] rather than the
   sentence, which is the provider's own. *)

let error_code name =
  match Protocol.Error_code.of_string name with
  | Ok code -> code
  | Error _ -> assert false

let unavailable ?(code = "unavailable") message =
  Protocol.make_error
    ~detail:(`Assoc [ ("code", `String code) ])
    (error_code (if code = "timeout" then "model-timeout" else "model-unavailable"))
    ~message

let with_kind kind (error : Protocol.error) =
  let fields = match error.detail with Some (`Assoc fields) -> fields | _ -> [] in
  {
    error with
    detail =
      Some
        (`Assoc (("model_kind", `String kind) :: List.remove_assoc "model_kind" fields));
  }

let of_eta ?kind (error : Ox_ai.Error.t) =
  let code =
    match error with
    | `Unavailable _ -> "unavailable"
    | `Timeout -> "timeout"
    | `Authentication _ -> "authentication"
    | `Invalid_response _ -> "invalid-response"
    | `Input_too_large _ -> "input-too-large"
    | `Model_mismatch _ -> "model-mismatch"
  in
  let error = unavailable ~code (Ox_ai.Error.to_string error) in
  match kind with None -> error | Some kind -> with_kind kind error
