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
  max_steps : int option;
      (** L31 run-d82w: the cap the operator level runs one of this procedure's steps
          under; [None] is the operator's own default (30), and the loader accepts 1..30.
      *)
  deadline_s : int option;
      (** L31 run-d82w: the step's own deadline; [None] is the operator's own default (120
          s), the loader accepts 1..600, and what is left of the run always bounds it. *)
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

val checker_name : checker -> string
(** L31 run-xqh8: the kind of a resolved checker — ["page_kind"], ["text"], ["download"],
    ["no_dialog"], ["row"] or ["judgment"] — as a run's trace names it. *)

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

val substitute : (string * string) list -> string -> string
(** run-2lei run-84ds run-5rll: a placeholder in braces is replaced by the value the run
    knows for it, in a step's goal or an expectation sentence. A name with no value is
    left as it stands. *)

val resolved : ?values:(string * string) list -> t -> procedure -> (string * checker) list
(** run-tny5 run-vj48 run-5rll: the procedure's expectations as sentences next to the
    checkers they resolve to, so a trace can say which checker decided each one. The known
    arguments are substituted into each sentence first — a "page shows" sentence naming
    the product placeholder is checked for the product the mission named — and a sentence
    the grammar no longer matches after substitution is judged by JEV rather than refused:
    its authored form was validated at load. *)

type checked = {
  expectation : string;
  checker : checker;
  passed : bool;
  score : float option;
      (** The JEV score of a [Judgment] checker; [None] for every checker code decided. *)
}
(** run-xqh8: one expectation's verdict, which is what a run's trace records. *)

val await_results :
  now:(unit -> float) ->
  sleep:(float -> unit) ->
  observe:(unit -> observation) ->
  score:(string -> observation -> float) ->
  ?threshold:float ->
  ?timeout_s:int ->
  (string * checker) list ->
  checked list
(** run-l06s run-vbys: {!await} with the verdicts kept. The result is the last
    observation's: the one that passed everything, or the one the deadline found. *)

val await :
  now:(unit -> float) ->
  sleep:(float -> unit) ->
  observe:(unit -> observation) ->
  score:(string -> observation -> float) ->
  ?threshold:float ->
  ?timeout_s:int ->
  checker list ->
  bool
