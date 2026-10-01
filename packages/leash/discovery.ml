module P = Protocol

type target = {
  id : string;
  session : string option;
  url : string option;
  title : string option;
  opener : string option;
}

let member name = function `Assoc fields -> List.assoc_opt name fields | _ -> None
let text name json = match member name json with Some (`String v) -> Some v | _ -> None

let page info =
  match text "targetId" info with
  | Some id when text "type" info = Some "page" ->
      Some
        {
          id;
          session = None;
          url = text "url" info;
          title = text "title" info;
          opener = text "openerId" info;
        }
  | _ -> None

let announced params = Option.bind (member "targetInfo" params) page

let attached params =
  Option.map
    (fun target -> { target with session = text "sessionId" params })
    (announced params)

let destroyed params = text "targetId" params
