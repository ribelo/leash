type t = {
  entry_kind : string;
  exit_kind : string;
  entry : Trace.trace_page;
  exit : Trace.trace_page;
  steps : Trace.trace_step list;
  arguments : (int * string list) list;
  values : string list;
  repeatable : bool;
}
(** map-op01 map-op03: a maximal run of actions on one entry page kind. The transition
    action belongs to the departing kind; DONE is result evidence. No page text, browser,
    model, or filesystem is needed. *)

val segment :
  ?mapping:(string * string) list -> ?declared:Playbook.page list -> Trace.t -> t list
(** Only done traces. Excludes off-final-host and named consent operations. [arguments]
    maps original step numbers to known mission argument names. *)

val first_entry :
  ?mapping:(string * string) list ->
  ?declared:Playbook.page list ->
  Trace.t ->
  string option
(** map-op05: first observed site URL after interstitials. *)

val signature : t -> (string * Trace.trace_target option) list

val agrees : t -> t -> bool
(** map-op03: repeatable operations share entry/exit kinds and compatible distinct
    operation/role sets (one may contain the other). Non-repeatable agreement keeps exact
    ordered operations, roles and labels. *)

val normalize_label : string list -> string -> string

val compatible :
  (string * Trace.trace_target option) list ->
  (string * Trace.trace_target option) list ->
  bool

val project : Trace.t -> t -> Trace.t
(** Restrict existing repeatability/validation gates to this operation's evidence. *)
