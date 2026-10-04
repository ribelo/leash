module P = Protocol

type t = { mutable frame : Yojson.Safe.t Eio.Promise.u option }

let create () = { frame = None }
let obj xs = `Assoc xs
let str s = `String s
let ( let* ) = Result.bind
let field key = function `Assoc fields -> List.assoc_opt key fields | _ -> None

let error code message =
  let code =
    match P.Error_code.of_string code with Ok code -> code | Error _ -> assert false
  in
  P.make_error code ~message

let timeout_error () =
  {
    (error "timeout"
       "screenshot produced no frame within 5s; headed Chrome on a hidden Wayland \
        workspace may have no compositor frame even when the page is responsive")
    with
    hint = "keep the window visible or retry later; Leash will not activate or move it";
  }

let observe t event =
  match (t.frame, field "method" event, field "params" event) with
  | Some resolve, Some (`String "Page.screencastFrame"), Some params ->
      t.frame <- None;
      Eio.Promise.resolve resolve params
  | _ -> ()

let capture t ~call ~stop ~within ~full_page =
  if full_page then
    within (fun () ->
        call "Page.captureScreenshot"
          (obj [ ("format", str "png"); ("captureBeyondViewport", `Bool true) ]))
  else
    let promise, resolve = Eio.Promise.create () in
    t.frame <- Some resolve;
    Fun.protect
      ~finally:(fun () ->
        t.frame <- None;
        Eio.Cancel.protect stop)
      (fun () ->
        within (fun () ->
            let* _ =
              call "Page.startScreencast"
                (obj [ ("format", str "png"); ("everyNthFrame", `Int 1) ])
            in
            let frame = Eio.Promise.await promise in
            match (field "data" frame, field "sessionId" frame) with
            | Some (`String data), Some (`Int session) ->
                let* _ =
                  call "Page.screencastFrameAck" (obj [ ("sessionId", `Int session) ])
                in
                Ok (obj [ ("data", str data) ])
            | _ ->
                Error
                  (error "internal" "browser omitted screenshot frame data or sessionId")))
