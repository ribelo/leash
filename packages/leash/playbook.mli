type page = {
  name : string;
  url_pattern : string option;
  text_marker : string option;
  repeatable : bool;
}
(** map-fmt01: a page kind is a name, a URL pattern or text marker, and an optional
    repeatable pin. A [description] on a page is a removed field. *)

(* map-fmt01: JEV sees [goal]; [hint] is appended to that goal, so it stays. [until] is
   removed — a procedure verifies at its end, not mid-step. *)
type goal_step = { goal : string; hint : string option }
type use_step = { use : string; args : Yojson.Safe.t option; optional : bool option }

type script_step = { script : string; args : Yojson.Safe.t option }
(** extr-8o1h: run the playbook's script [script]; [args] is an object of strings, with
    the run's [{name}] placeholders substituted before the script is called. *)

type step =
  | Goal of goal_step
  | Use of use_step
  | Script of script_step
      (** map-fmt01: a step is a goal, a [use:] of another procedure, or a script.
          [navigate] is a removed step kind; a goal covers navigation. *)

type repeat_until = Expectation of string | Script_check of string

type repeat = {
  next : string;
  max : int;
  until : repeat_until;
  delay_ms : int option;
  key : string;
}

type arg_source =
  | From_mission of { optional : bool }
  | Const of Yojson.Safe.t
      (** pbk-lww9: where a declared argument comes from. [From_mission] is filled by the
          text helper from the mission sentence ([optional] does not block when the helper
          has no value). [Const] is the value written in the file. *)

type arg_decl = { name : string; source : arg_source }
(** One argument and its source. The JSON form is an object of name to
    [{"from":"mission"}], [{"from":"mission","optional":true}] or [{"const":<value>}]. A
    list of names is the old form and is refused. *)

type procedure = {
  slug : string;
  description : string;
  args : arg_decl list option;
  steps : step list;
  expect : string list;
  repeat : repeat option;
}
(** map-fmt01: a procedure is a slug, a description JEV chooses on, args, steps, expect,
    and optional repeat. [provenance], [expect_timeout_s], [max_steps] and [deadline_s]
    are removed fields. *)

type script_decl = {
  file : string option;
  source : string option;
  description : string;
  pages : string list option;
      (** pbk-46fr: page kinds this script applies to. [None] means every page of the
          site; [Some []] is offered on none. *)
  args : arg_decl list;
  returns_json : Yojson.Safe.t option;
      (** A shape name, or an inline shape. An inline shape is the old form and is refused
          after the script file resolves (pbk-i0zl). *)
}
(** extr-plaz extr-zdst pbk-46fr pbk-lvy9 map-fmt01: a script as `playbook.json` writes it
    — exactly one of a [file] relative to the playbook directory and a short inline
    [source] (at most 4096 bytes), a one-sentence [description], and the page kinds it
    applies to. The result is bounded by {!script_max_bytes}. [max_bytes] and [origin] are
    removed fields. The result shape sits beside the script, not in this object as an
    inline shape. *)

type scripts = (string * script_decl) list
(** The [scripts] section: an object of script name to declaration. *)

type shapes = (string * Shape.t) list
(** pbk-lvy9: named result shapes. A script's [returns] is one of these names, or an
    inline shape in the script's leading comment or sidecar. *)

type t = {
  site : string;
  entry : string;
  description : string;
  pages : page list;
  procedures : procedure list;
  shapes : shapes option;
  scripts : scripts option;
  notes : string option;
      (** cut-yk93: optional free text about the site for the pilot (where things are, how
          login works), shown on every pilot turn on that site; at most {!max_notes}
          bytes. *)
}

val max_notes : int

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
  description : string;
  pages : string list option;
  args : arg_decl list;
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
val non_repeatable_context : string -> bool

val action_risk_context :
  snapshot:Protocol.snapshot -> text:string -> index:int option -> string
(** map-yzqp: target-scoped evidence; ambiguous actions retain all page warnings. *)

val non_repeatable_action : context:string -> string -> bool

val of_json :
  ?dir:Ox_caps.Cap.fs_read * string ->
  file:string ->
  Yojson.Safe.t ->
  (loaded, string) result
(** Validates a playbook. File scripts are resolved against [dir]: relative to it, no
    [..], and after symlinks are resolved still inside it (extr-plaz); without [dir] a
    file script is refused. A directory comes with the capability to read it
    (^ncaps-4tjy): a playbook decoded from a message, with no directory, touches nothing.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and local parsing callbacks;
    filesystem reads are synchronous. Cancellation: not a cancellation point; behavior of
    the delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and Yojson
    helpers and local parsing callbacks. Finalizers: owned input channels are closed on
    exit. Locking: none; reads do not reserve filesystem state. Cancellation safety: safe
    to re-run; reads leave files unchanged. [Assert_failure] can escape if an internal
    validated-playbook invariant fails. *)

val load : caps:< Ox_caps.Cap.fs_read ; .. > -> string -> (loaded, string) result
(** [load dir] reads [dir/playbook.json] and its scripts (extr-plaz). A path that is a
    file, and a directory that holds only a [playbook.yaml], are refused with a message
    that says what a playbook is.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and local parsing callbacks;
    filesystem reads are synchronous. Cancellation: not a cancellation point; behavior of
    the delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and Yojson
    helpers and local parsing callbacks. Finalizers: owned input channels are closed on
    exit. Locking: none; reads do not reserve filesystem state. Cancellation safety: safe
    to re-run; reads leave files unchanged. [Assert_failure] can escape if an internal
    validated-playbook invariant fails. *)

val script_named : loaded -> string -> script option

val offered_scripts : loaded -> url:string -> text:string -> script list
(** pbk-rai1: scripts whose [pages] match the current page kind. Absent [pages] matches
    every page, including a page of no recognised kind; [Some []] matches none. *)

val script_only_message : string
(** pbk-85m1: the loader's exact refusal when no procedure has a goal step. *)

val directory : caps:< Ox_caps.Cap.env ; .. > -> unit -> string
(** [$XDG_CONFIG_HOME/leash/playbooks]; each playbook is a subdirectory of it.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and local parsing callbacks; this
    only reads the environment. Cancellation: not a cancellation point; behavior of the
    delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and Yojson helpers
    and local parsing callbacks. Finalizers: none. Locking: none. Cancellation safety:
    safe to re-run; no resource or file is changed. *)

val list :
  caps:< Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; .. > ->
  unit ->
  (loaded list, string) result
(** Every subdirectory loaded, by name. A [.json] file left directly in the directory is
    refused: it is the old layout.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and local parsing callbacks;
    filesystem reads are synchronous. Cancellation: not a cancellation point; behavior of
    the delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and Yojson
    helpers and local parsing callbacks. Finalizers: owned input channels are closed on
    exit. Locking: none; reads do not reserve filesystem state. Cancellation safety: safe
    to re-run; reads leave files unchanged. [Assert_failure] can escape if an internal
    validated-playbook invariant fails. *)

val show :
  caps:< Ox_caps.Cap.env ; Ox_caps.Cap.fs_read ; .. > -> string -> (loaded, string) result
(** The installed playbook whose directory is called this.

    Suspension: never suspends; behavior of the delegated helpers depends on the
    synchronous Stdlib, Unix, Ox_caps and Yojson helpers and local parsing callbacks;
    filesystem reads are synchronous. Cancellation: not a cancellation point; behavior of
    the delegated helpers depends on the synchronous Stdlib, Unix, Ox_caps and Yojson
    helpers and local parsing callbacks. Finalizers: owned input channels are closed on
    exit. Locking: none; reads do not reserve filesystem state. Cancellation safety: safe
    to re-run; reads leave files unchanged. [Assert_failure] can escape if an internal
    validated-playbook invariant fails. *)

val retry_once : execute:(unit -> unit) -> verify:(unit -> bool) -> bool

val inspect : ?code:bool -> loaded -> Yojson.Safe.t
(** The playbook, its scripts (size, [returns], and with [code] their text — extr-lslp)
    and its resolved checkers. *)

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

val expect_timeout_s : int
(** map-fmt01: the one wait for a procedure's expectations. The per-procedure field and
    the learned 15 s wait are removed. *)

val script_max_bytes : int
(** map-fmt01: the one bound on a script result, 8 MiB. *)

val await_results :
  now:(unit -> float) ->
  sleep:(float -> unit) ->
  observe:(unit -> observation) ->
  score:(string -> observation -> float) ->
  ?threshold:float ->
  ?timeout_s:int ->
  (string * checker) list ->
  checked list
(** run-xflk run-vbys: {!await} with the verdicts kept. The result is the last
    observation's: the one that passed everything, or the one the deadline found. A failed
    judgment is not final before that deadline. A pass scored while the page text is still
    changing is not accepted while time remains (map-bjon). *)

val await :
  now:(unit -> float) ->
  sleep:(float -> unit) ->
  observe:(unit -> observation) ->
  score:(string -> observation -> float) ->
  ?threshold:float ->
  ?timeout_s:int ->
  checker list ->
  bool
