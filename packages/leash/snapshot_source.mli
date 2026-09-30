val counter_script : string
(** Browser-only snapshot guard and AX/DOMSnapshot join.

    [rows] keeps a control whose accessible name is empty — an unlabelled native select, a
    bare text input, an icon button — with its role, an empty name, and the value it holds
    or, when it holds none, the placeholder that is the only other thing naming it
    (tab-zc36). A row that is only informative still needs a name. *)

val world_name : string
(** The isolated world [counter_script] and [guard_expression] run in (chrome-9ex7): the
    guard is Leash's, so it never becomes a global the page's own scripts can see. *)

val guard_expression : string

val guard : Yojson.Safe.t -> (string * int * float * float * float * float) option
(** Epoch, mutation count, and device-scaled viewport width, height and scroll offsets, in
    the same coordinates as Chrome DOMSnapshot bounds (daily-9ggi). *)

val row_role : string -> string
(** Normalize Chrome AX roles identically for snapshot rows and action revalidation
    (daily-9ggi). *)

val rows :
  ax:Yojson.Safe.t ->
  dom:Yojson.Safe.t ->
  width:float ->
  height:float ->
  scroll_x:float ->
  scroll_y:float ->
  (Protocol.row * int) list

val text_limit : int
(** fly-iodm: visible viewport text is cut at 6,000 characters. *)

val element_limit : int
(** fly-iodm: at most 250 action candidates are offered; the rest are omitted. *)

val scroll_delta : int
(** fly-2pn7: page scroll moves 560 CSS pixels, as snapshot.js does. *)

val wait_s : float
(** fly-2pn7: WAIT is 100 ms. *)

val observe_attempts : int
(** fly-4mio fly-2pn7: a navigating or inconsistent read is tried at most ten times. *)

val observe_retry_s : float
(** fly-4mio: 20 ms between those attempts. *)

val operator_mark : string
(** Prefix of {!operator_expression}, so a scripted peer can tell this read from the
    snapshot guard. *)

val operator_expression : string
(** One DOM evaluation of the visible viewport: text, scroll, omission and the semantic
    marker. [null] means the document is navigating (fly-crcc fly-iodm). *)

type unsupported_state = Iframe | Shadow_root | Canvas | Nested_scroll_container

type coverage = {
  text_truncated : bool;
  omitted_elements : int;
  can_scroll_up : bool;
  can_scroll_down : bool;
  coverage : string;
  unsupported_states : unsupported_state list;
}
(** fly-9363 fly-crcc: what one guarded read actually covered. [coverage] is the
    vocabulary string, not a second JSON document. *)

val coverage_string :
  text_truncated:bool ->
  omitted_elements:int ->
  can_scroll_up:bool ->
  can_scroll_down:bool ->
  string
(** Fixed-order vocabulary, [+] joined, no other tokens: [viewport] always; [truncated]
    when text was cut at {!text_limit}; [omitted] when {!element_limit} candidates were
    dropped; [above] when the page can scroll up; [below] when it can scroll down.
    [viewport] alone means the visible page fitted. *)

val coverage_of :
  unsupported_states:unsupported_state list ->
  text_truncated:bool ->
  omitted_elements:int ->
  can_scroll_up:bool ->
  can_scroll_down:bool ->
  coverage

val coverage_json : coverage -> Yojson.Safe.t
(** The object [Drive.run]'s coverage hook returns: [text_truncated], [omitted_elements],
    [can_scroll_up], [can_scroll_down], [coverage], and [unsupported_states]. The last is
    an array of [iframe], [shadow-root], [canvas], [nested-scroll-container] flags
    detected in the visible viewport. Closed shadow roots are not exposed by this DOM
    read. *)

type semantics = {
  role : string;
  label : string;
  value : string;
  checked : string option;
  read_only : bool;
  href : string option;
  context : string;
}
(** One visible control's meaning, without geometry (fly-4lmg). *)

type operator_read = {
  url : string;
  title : string;
  text : string;
  time_origin : float;
  scroll_x : float;
  scroll_y : float;
  scroll_height : float;
  viewport_width : float;
  viewport_height : float;
  can_scroll_up : bool;
  can_scroll_down : bool;
  semantics : semantics list;
  marker : string;
  coverage : coverage;
}

type operator_reply =
  | Payload of operator_read
  | Navigating
  | Foreign
      (** [Foreign] is a peer that did not execute the expression — the scripted fake's
          guard object — and is not a navigating document. *)

val parse_operator : Yojson.Safe.t -> operator_reply

val settle_mark : string
(** Prefix of the post-input settle expression (fly-2pn7). *)

val settle_expression : autocomplete:bool -> string
(** Autocomplete waits up to 200 ms for a visible option; other input waits two frames or
    50 ms. *)
