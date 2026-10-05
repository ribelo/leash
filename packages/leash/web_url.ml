(* cut-0oal: the two facts about a URL the runner needs once inferred page kinds are gone —
   whether it is a web page, and its host, which names the site of a trace. *)

let take_until s stops =
  let stop =
    List.fold_left
      (fun best c ->
        match String.index_opt s c with Some i -> min best i | None -> best)
      (String.length s) stops
  in
  String.sub s 0 stop

let host url =
  match String.index_opt url ':' with
  | Some i when i + 3 <= String.length url && String.sub url i 3 = "://" ->
      let scheme = String.lowercase_ascii (String.sub url 0 i) in
      let rest = String.sub url (i + 3) (String.length url - i - 3) in
      let authority = take_until rest [ '/'; '?'; '#' ] in
      let authority =
        match String.rindex_opt authority '@' with
        | None -> String.lowercase_ascii authority
        | Some at ->
            String.lowercase_ascii
              (String.sub authority (at + 1) (String.length authority - at - 1))
      in
      let host =
        if String.starts_with ~prefix:"[" authority then
          match String.index_opt authority ']' with
          | Some last -> String.sub authority 0 (last + 1)
          | None -> authority
        else take_until authority [ ':' ]
      in
      if scheme = "http" || scheme = "https" then Some host else None
  | _ -> None

let is_page ~url = Option.is_some (host url)
