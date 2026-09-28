type page = {
  name : string;
  description : string;
  url_pattern : string option;
  text_marker : string option;
}

type goal_step = { goal : string; hint : string option }
type use_step = { use : string; args : Yojson.Safe.t option; optional : bool option }
type step = Goal of goal_step | Use of use_step

type procedure = {
  slug : string;
  description : string;
  args : string list option;
  steps : step list;
  expect : string list;
  expect_timeout_s : int option;
}

type t = {
  site : string;
  entry : string;
  description : string;
  pages : page list;
  procedures : procedure list;
}

type checker =
  | Page_kind of string
  | Text of string
  | Download of string option
  | No_dialog
  | Row of string * string
  | Judgment of string

type loaded = { file : string; playbook : t; checks : (string * checker list) list }

val t_of_yojson : Yojson.Safe.t -> (t, string) result
val yojson_of_t : t -> Yojson.Safe.t
val resolve : page list -> string -> (checker, string) result
val page_kind : page list -> url:string -> text:string -> string option
val of_json : file:string -> Yojson.Safe.t -> (loaded, string) result
val load : string -> (loaded, string) result
val directory : unit -> string
val list : unit -> (loaded list, string) result
val show : string -> (loaded, string) result

(* run-k8bx: restart every step from the beginning after the first failed check. *)
val retry_once : execute:(unit -> unit) -> verify:(unit -> bool) -> bool
val inspect : loaded -> Yojson.Safe.t

type observation = {
  kind : string option;
  text : string;
  dialog : bool;
  rows : (string * string) list;
  downloads : (string * string * string) list;
}

val await :
  now:(unit -> float) ->
  sleep:(float -> unit) ->
  observe:(unit -> observation) ->
  score:(string -> observation -> float) ->
  ?threshold:float ->
  ?timeout_s:int ->
  checker list ->
  bool
