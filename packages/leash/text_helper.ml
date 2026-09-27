(* L19 — the text helper's Leash-side seam (docs/issues/drive/01-drive.md, milestone 5).

   drive-ls3c drive-fh1h: L22 fills {!t} with the chat client and the {"text": string|null}
   parse; until then the drive's TYPE_TEXT branch is the stub in [Tabs.drive] and
   {!unavailable} is what a caller that asks {!Models.text_helper} gets. Nothing here
   performs I/O. *)

type field = { label : string; role : string; value : string }

type context = {
  goal : string;
  field : field;
  page_title : string;
  page_text : string;
  recent : Jev_request.recent_action list;
}

type t = { complete : context -> (string option, Protocol.error) result }

let unavailable =
  {
    complete =
      (fun (_ : context) ->
        Error
          Protocol.
            {
              code =
                (match Error_code.of_string "model-unavailable" with
                | Ok code -> code
                | Error _ -> assert false);
              message = "text helper unavailable";
              detail = Some (`Assoc [ ("code", `String "text-helper-unavailable") ]);
            });
  }
