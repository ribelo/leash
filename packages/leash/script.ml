(* ADR-0016 scr-run: a script is a JavaScript file the agent brings to [leash script run].
   It runs once on the tab's page as the body of an async function of [args], read-only;
   its result is bounded and, when the file opens with a [/** returns: SHAPE */] block,
   validated against that shape. Nothing is installed or remembered. *)

type t = { name : string; code : string; returns : Shape.t option }

let max_bytes = 8 * 1024 * 1024

let returns_comment code =
  let trimmed = String.trim code in
  let prefix = "/** returns:" in
  if not (String.starts_with ~prefix trimmed) then Ok None
  else
    let rest =
      String.sub trimmed (String.length prefix)
        (String.length trimmed - String.length prefix)
    in
    let rec close i =
      if i + 1 >= String.length rest then None
      else if rest.[i] = '*' && rest.[i + 1] = '/' then Some i
      else close (i + 1)
    in
    match close 0 with
    | None -> Error "returns block is missing */"
    | Some i -> (
        let text = String.trim (String.sub rest 0 i) in
        try Ok (Some (Yojson.Safe.from_string text))
        with Yojson.Json_error why -> Error ("returns block: " ^ why))

let of_source ~name code =
  if String.length code > 1024 * 1024 then Error "the script is over 1 MiB"
  else
    match returns_comment code with
    | Error why -> Error why
    | Ok None -> Ok { name; code; returns = None }
    | Ok (Some json) -> (
        match Shape.t_of_yojson json with
        | Error why -> Error ("returns: " ^ why)
        | Ok shape -> Ok { name; code; returns = Some shape })
