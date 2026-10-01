type trace_target = { role : string; label : string }

(* trace-lg58: one derived durable format, projected from live replies because their
   snapshots, collected data and operator state carry capabilities and page text. *)
type trace_page = { url : string; title : string }
type trace_probability = { key : string; probability : float }

type trace_step = {
  n : int;
  operation : string;
  target : trace_target option;
  text : string option;
  operations : trace_probability list;
  targets : trace_probability list;
  after : trace_page;
  elapsed_ms : int;
}

type trace_procedure = {
  n : int;
  procedure : string;
  outcome : string;
  planned : bool;
  steps : trace_step list;
}

type inferred_page = { name : string; url_pattern : string }
(** kind-dnye kind-s1k2: one row of the session mapping in the trace header. *)

type t = {
  version : int;
  time : string;
  site : string;
  mission : string;
  outcome : string;
  cost : float option; [@json.null]
  duration_ms : int;
  model_calls : int;
  page_kind_path : string list;
  inferred_pages : inferred_page list;
      (** kind-dnye: generalized pattern to name, first-seen. Empty when every kind was
          declared. Missing on an older file decodes as [[]]. *)
  compiled : bool; [@json.default false]
  procedures : trace_procedure list;
  steps : trace_step list;
  final : trace_page option; [@json.null]
  error_code : string option;
}

val t_of_yojson : Yojson.Safe.t -> (t, string) result
val yojson_of_t : t -> Yojson.Safe.t
