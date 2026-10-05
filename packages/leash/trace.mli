type trace_target = { role : string; label : string }

(* trace-lg58: one derived durable format, projected from live replies because their
   snapshots, collected data and operator state carry capabilities and page text. *)
type trace_page = { url : string; title : string }
type trace_probability = { key : string; probability : float }

type trace_step = {
  non_repeatable : bool;
  n : int;
  operation : string;
  source : string;
  error : string option;
  target : trace_target option;
  text : string option;
  operations : trace_probability list;
  targets : trace_probability list;
  after : trace_page;
  elapsed_ms : int;
}

type planner_turn = { n : int; trigger : string; answer : string; reason : string option }

type t = {
  unattended : Yojson.Safe.t list;
  version : int;
  time : string;
  site : string;
  mission : string;
  outcome : string;
  cost : float option; [@json.null]
  duration_ms : int;
  model_calls : int;
  start_url : string option;
  planner_turns : planner_turn list;
  steps : trace_step list;
  out_requested : bool; [@json.default false]
      (** map-fmt04: the mission asked for [--out]. Absent JSON is false. *)
  final : trace_page option; [@json.null]
  error_code : string option;
}

val trace_target_of_yojson : Yojson.Safe.t -> (trace_target, string) result
val t_of_yojson : Yojson.Safe.t -> (t, string) result
val yojson_of_trace_target : trace_target -> Yojson.Safe.t
val yojson_of_trace_page : trace_page -> Yojson.Safe.t
val yojson_of_t : t -> Yojson.Safe.t
