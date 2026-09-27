val counter_script : string
(** Browser-only snapshot guard and AX/DOMSnapshot join.

    [rows] keeps a control whose accessible name is empty — an unlabelled native select, a
    bare text input, an icon button — with its role, an empty name, and the value it holds
    or, when it holds none, the placeholder that is the only other thing naming it
    (tab-zc36). A row that is only informative still needs a name. *)

val guard_expression : string
val guard : Yojson.Safe.t -> (string * int * float * float * float * float) option

val rows :
  ax:Yojson.Safe.t ->
  dom:Yojson.Safe.t ->
  width:float ->
  height:float ->
  scroll_x:float ->
  scroll_y:float ->
  (Protocol.row * int) list
