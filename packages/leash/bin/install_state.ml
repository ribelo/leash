(* daily-lqqn daily-smli: classify a down `leash status` from a fixture or from
   `systemctl show` text. This module does not run systemd. *)

type observation = {
  load_state : string;
  active_state : string;
  sub_state : string;
  binary_present : bool;
}

type diagnosis = Not_installed | Stopped | Restarting | Unreachable

let normalize text = String.lowercase_ascii (String.trim text)

let unit_present obs =
  match normalize obs.load_state with
  | "" | "not-found" | "masked" | "error" | "unknown" -> false
  | _ -> true

let diagnose obs =
  let active = normalize obs.active_state in
  let sub = normalize obs.sub_state in
  let restarting =
    active = "activating" || active = "deactivating" || sub = "auto-restart"
  in
  let stopped = active = "inactive" || active = "failed" || active = "dead" in
  if not (unit_present obs) then Not_installed
  else if restarting then Restarting
  else if stopped then Stopped
  else Unreachable

let code = function
  | Not_installed -> "not-installed"
  | Stopped -> "service-stopped"
  | Restarting -> "service-restarting"
  | Unreachable -> "service-unreachable"

let message diagnosis obs =
  match diagnosis with
  | Not_installed when not obs.binary_present ->
      "Leash is not installed: no leash.service unit and no leash binary"
  | Not_installed -> "Leash is not installed: no leash.service unit"
  | Stopped -> "leash.service is installed but stopped"
  | Restarting -> "leash.service is activating or restarting"
  | Unreachable -> "cannot reach the Leash service"

let fields text =
  String.split_on_char '\n' text
  |> List.filter_map (fun line ->
      let line = String.trim line in
      if line = "" || String.starts_with ~prefix:"#" line then None
      else
        match String.index_opt line '=' with
        | None -> None
        | Some at ->
            let key = String.trim (String.sub line 0 at) in
            let value =
              String.trim (String.sub line (at + 1) (String.length line - at - 1))
            in
            Some (key, value))

let get key ~default fields = Option.value ~default (List.assoc_opt key fields)

let of_fixture text =
  let fields = fields text in
  {
    load_state = get "load" ~default:"" fields;
    active_state = get "active" ~default:"" fields;
    sub_state = get "sub" ~default:"" fields;
    binary_present = get "binary" ~default:"absent" fields = "present";
  }

let of_systemctl ~binary_present text =
  let fields = fields text in
  {
    load_state = get "LoadState" ~default:"" fields;
    active_state = get "ActiveState" ~default:"" fields;
    sub_state = get "SubState" ~default:"" fields;
    binary_present;
  }
