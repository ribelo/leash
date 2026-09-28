type page = {
  name : string;
  description : string;
  url_pattern : string option;
  text_marker : string option;
}

type goal_step = { goal : string; hint : string option }
type use_step = { use : string; args : Yojson.Safe.t option; optional : bool option }

type script_step = { script : string; args : Yojson.Safe.t option }
(** extr-8o1h: run the playbook's script [script]; [args] is an object of strings, with
    the run's [{name}] placeholders substituted before the script is called. *)

type step = Goal of goal_step | Use of use_step | Script of script_step

type repeat = {
  next : string;
  max : int;
  until : string;
  delay_ms : int option;
  key : string;
}

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
  repeat : repeat option;
  deadline_s : int option;
      (** L31 run-d82w: the step's own deadline; [None] is the operator's own default (120
          s), the loader accepts 1..600, and what is left of the run always bounds it. *)
}

type script_decl = {
  file : string option;
  source : string option;
  returns : Shape.t;
  max_bytes : int option;
}
(** extr-plaz extr-zdst: a script as `playbook.json` writes it — exactly one of a [file]
    relative to the playbook directory and a short inline [source] (at most 4096 bytes),
    the shape its result must have, and an optional bound on the size of that result
    ([max_bytes], default 8 MiB, at most 16 MiB). *)

type scripts = (string * script_decl) list
(** The [scripts] section: an object of script name to declaration. *)

type t = {
  site : string;
  entry : string;
  description : string;
  pages : page list;
  procedures : procedure list;
  scripts : scripts option;
}

type checker =
  | Page_kind of string
  | Not_page_kind of string
  | Text of string
  | Download of string option
  | No_dialog
  | Row of string * string
  | Judgment of string

type script = private {
  name : string;
  code : string;  (** The text of the script's function body, read at load. *)
  returns : Shape.t;
  max_bytes : int;
  origin : string;  (** [file <path>] or [inline]. *)
}
(** extr-plaz extr-k40c: a resolved script. The type is private — the loader is the only
    thing that makes one, from a playbook directory — and {!Reading.script}, the only
    function that hands script text to the browser, takes one. Model output can therefore
    never become a script. *)

type loaded = {
  file : string;  (** The path of [playbook.json]. *)
  dir : string option;
      (** The playbook directory; [None] for a playbook that did not come from one (a
          discovery seed), which may carry no file script. *)
  playbook : t;
  checks : (string * checker list) list;
  scripts : script list;
}

type proposal = { site : string; procedure : procedure }
(** run-m0r8: one planner-written procedure as it is proposed to the operator — the site
    it belongs to and the procedure in the playbook's own schema. *)

type accepted = { site : string; slug : string; playbook : string; replaced : bool }
(** run-m0r8: what an accepted proposal did: the site, the procedure slug, the playbook
    file written, and whether the slug replaced a procedure that was already there. *)

val t_of_yojson : Yojson.Safe.t -> (t, string) result
val yojson_of_t : t -> Yojson.Safe.t
val page_of_yojson : Yojson.Safe.t -> (page, string) result
val yojson_of_page : page -> Yojson.Safe.t

val checker_name : checker -> string
(** L31 run-xqh8: the kind of a resolved checker — ["page_kind"], ["text"], ["download"],
    ["no_dialog"], ["row"] or ["judgment"] — as a run's trace names it. *)

val resolve : page list -> string -> (checker, string) result
val page_kind : page list -> url:string -> text:string -> string option
val procedure_of_yojson : Yojson.Safe.t -> (procedure, string) result

val yojson_of_procedure : procedure -> Yojson.Safe.t
(** The procedure as the playbook's own JSON: what a planner's reply is decoded into
    (run-rq6i) and what a proposal file carries (run-m0r8). *)

val proposal_of_yojson : Yojson.Safe.t -> (proposal, string) result
val yojson_of_proposal : proposal -> Yojson.Safe.t
val yojson_of_accepted : accepted -> Yojson.Safe.t

val of_json : ?dir:string -> file:string -> Yojson.Safe.t -> (loaded, string) result
(** Validates a playbook. File scripts are resolved against [dir]: relative to it, no
    [..], and after symlinks are resolved still inside it (extr-plaz); without [dir] a
    file script is refused. *)

val revalidate : loaded -> t -> (loaded, string) result
(** [revalidate book playbook] validates another playbook value in [book]'s directory — a
    planner's procedure added, a proposal merged. *)

val load : string -> (loaded, string) result
(** [load dir] reads [dir/playbook.json] and its scripts (extr-plaz). A path that is a
    file, and a directory that holds only a [playbook.yaml], are refused with a message
    that says what a playbook is. *)

val script_named : loaded -> string -> script option

val directory : unit -> string
(** [$XDG_CONFIG_HOME/leash/playbooks]; each playbook is a subdirectory of it. *)

val list : unit -> (loaded list, string) result
(** Every subdirectory loaded, by name. A [.json] file left directly in the directory is
    refused: it is the old layout. *)

val show : string -> (loaded, string) result
(** The installed playbook whose directory is called this. *)

val check_procedure : ?file:string -> t -> procedure -> (unit, string) result
(** run-rq6i run-m0r8: the loader's own rules for one procedure, applied to a procedure
    that did not come from a validated file — a planner's answer, before the loop executes
    it, and a proposal, before it is merged. [file] only names the origin in the message.
    Beyond the file rules it refuses a procedure that calls itself and an expectation that
    names a page kind this playbook does not declare, which are the two ways a procedure
    from outside a file can fail to be runnable. *)

val proposed_directory : unit -> string
(** run-m0r8: [$XDG_STATE_HOME/leash/proposed] ([$HOME/.local/state] when the variable is
    unset), where a run writes the procedures the planner wrote and verified. The playbook
    directory is never written by a run. *)

val propose_book : t -> (string, string) result
(** Write a complete discovery proposal to XDG state, without installing it. *)

val propose : site:string -> procedure -> (string, string) result
(** run-m0r8: write one proposed procedure to [<proposed_directory>/<site>-<slug>.json],
    0600, and answer the path written. *)

val accept : string -> (accepted, string) result
(** run-m0r8: merge a proposal file into the site's installed playbook — by slug,
    replacing the same one and appending otherwise — and write that playbook back. The
    merged playbook must validate first, and a site served by no playbook, by more than
    one, or by an invalid merge is refused with nothing written. This is the operator's
    command: a run never merges a proposal itself. *)

(* run-k8bx: restart every step from the beginning after the first failed check. *)
val retry_once : execute:(unit -> unit) -> verify:(unit -> bool) -> bool

val inspect : ?code:bool -> loaded -> Yojson.Safe.t
(** The playbook, its scripts (origin, size, [returns], and with [code] their text —
    extr-lslp) and its resolved checkers. *)

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
