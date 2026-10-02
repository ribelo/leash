type t = {
  entry_kind : string;
  exit_kind : string;
  entry : Trace.trace_page;
  exit : Trace.trace_page;
  steps : Trace.trace_step list;
  arguments : (int * string list) list;
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
(** Entry kind and every operation/role/label, never typed values or whole paths. *)

val project : Trace.t -> t -> Trace.t
(** Restrict existing repeatability/validation gates to this operation's evidence. *)
