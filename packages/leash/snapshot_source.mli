val counter_script : string
(** Browser-only snapshot guard and AX/DOMSnapshot join. *)

val guard_expression : string
val guard : Yojson.Safe.t -> (string * int * float * float) option

val rows :
  ax:Yojson.Safe.t ->
  dom:Yojson.Safe.t ->
  width:float ->
  height:float ->
  (Protocol.row * int) list
