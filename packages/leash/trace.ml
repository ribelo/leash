type trace_target = { role : string; label : string } [@@deriving yojson]

(* trace-lg58: one derived durable format, projected from live replies because their
   snapshots, collected data and operator state carry capabilities and page text. *)
type trace_page = { url : string; title : string } [@@deriving yojson]
type trace_probability = { key : string; probability : float } [@@deriving yojson]

type trace_step = {
  non_repeatable : bool; [@json.default false]
  n : int;
  operation : string;
  source : string; [@json.default "operator"]
  error : string option;
  target : trace_target option;
  text : string option;
  operations : trace_probability list;
  targets : trace_probability list;
  after : trace_page;
  elapsed_ms : int;
}
[@@deriving yojson]

type trace_procedure = {
  n : int;
  procedure : string;
  outcome : string;
  planned : bool;
  steps : trace_step list;
}
[@@deriving yojson]

type inferred_page = { name : string; url_pattern : string } [@@deriving yojson]

type t = {
  version : int;
  time : string;
  site : string;
  mission : string;
  outcome : string;
  cost : float option; [@json.null]
  duration_ms : int;
  model_calls : int;
  start_url : string option; [@json.default None]
  page_kind_path : string list;
  inferred_pages : inferred_page list; [@json.default []]
  compiled : bool; [@json.default false]
  procedures : trace_procedure list;
  steps : trace_step list;
  final : trace_page option; [@json.null]
  error_code : string option;
}
[@@deriving yojson]
