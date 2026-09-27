module P = Protocol

let human =
  match P.Origin.of_string "human" with Ok origin -> origin | Error _ -> assert false

type creator = { origin : P.Origin.t; owner : P.Owner.t option }

(* own-c0cl own-ehqa: a target with no opener — a tab the human opened in the Chrome UI, a
   tab a page opened in a window of its own, anything whose opener Leash never saw — is
   human origin and nobody's, so an agent can claim it. A target whose opener is a known
   tab is its opener's: the same origin and the same owner, because ownership follows
   cause. The rule runs once per target; later reports never rewrite what it decided. *)
let born = function None -> { origin = human; owner = None } | Some creator -> creator

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
