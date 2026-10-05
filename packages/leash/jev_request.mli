(* L20 — request shaping and decision (docs/issues/drive/01-drive.md, milestone 5). *)

(** The System One request a drive sends and the decision it reads back, as pure
    functions: a snapshot, the page's rendered text and the recent actions go in, one wire
    document comes out; the model's answers go in, one decision comes out.

    The shapes are jev-ultrafast's at commit {!Questions.commit}, copied and not adapted,
    because JEV was trained on exactly them. [snapshot.js] builds the action space the
    elements come from, [model.py]'s [action_space] turns it into elements and its
    [choose] into the questions, and [agent.py] records the history the recent window
    carries. {!body} writes the state's [elements] the way the reference does — index,
    label, role, value, the three states as the attribute strings Chrome reports, the
    operations the row can be given, and the option list of a select — the [operation]
    choice with jev's own label strings and the controls the page can still offer, and one
    [<operation>_target] choice for every operation that has targets. {!decide} is
    [model.py]'s [choose] after the answers arrive: it validates the operation head, then
    only the target head that operation selects, and returns the operation, the row — and
    for a select the option — the drive acts on, with the distributions. *)

type recent_action = {
  action : string;
  kind : string option;
  text : string option;
  page_changed : bool option;
}
(** One step of the window JEV sees, as [agent.py:121-148] records it: [action] is the
    action's label, [kind] its kind ([click], [fill], [select], [scroll] or [wait]),
    [text] any text it typed, and [page_changed] whether the page changed after it. All
    four keys are always on the wire and read [null] when the step has no value for them,
    which is what [model.py]'s [\{k: h.get(k) for k in (...)\}] writes (drive-y37b). The
    drive keeps its whole history and hands it over; {!body} sends the last ten, as
    [history[-10:]] does. *)

val yojson_of_recent_action : recent_action -> Yojson.Safe.t

type checked =
  | Checked
  | Unchecked
  | Mixed
      (** The three states of a checkbox, switch or radio the table reports: [checked],
          [unchecked] and the indeterminate [mixed]. Encoded as Chrome reports them — the
          attribute strings ["true"], ["false"] and ["mixed"] ([snapshot.js:63-67]), never
          booleans. *)

type select_target = { key : string; label : string; value : string; dom : int }
(** One option of a select element, as the target question offers it: [key] is the
    [<element index>:<option number>] the answer names, numbered over the options that are
    offered ([model.py:74-76]); [label] is the option action's full
    ["<select label> → <option label>"] label; [value] is the option's own value; and
    [dom] is the index the option has in the select's own option order, which is what the
    [select] action takes (tab-5deq). *)

type element = {
  index : string;
  row : int;
  label : string;
  role : string;
  value : string;
  checked : checked option;
  selected : bool option;
  expanded : bool option;
  operations : Protocol.Operation.t list;
  options : select_target list;
}
(** One element of JEV's view, numbered as JEV numbers it: [index] is the dense, one-based
    key over the elements — not the row index — and [row] is the snapshot row an action
    targets, which is what {!decision} reports back.

    [label] is the row's accessible name, or its role when the name is empty
    ([snapshot.js:61]); [role] is the row's. [value] is what the element holds now and is
    always on the wire: a select's is the labels of its selected options joined [", "]
    ([snapshot.js:70]), every other element's is the row's value or [""]
    ([snapshot.js:76-77]). [checked], [selected] and [expanded] are the row's states,
    written as the attribute strings Chrome reports.

    [operations] are the actions the page offers for the row ([snapshot.js:56-80]): a
    native select offers one select action per offered option and nothing else, so a
    select whose every option is selected or disabled is not an element at all; an
    editable text control offers [TYPE_TEXT] and then [CLICK]; a read-only one [CLICK];
    every other action target [CLICK]. A disabled row and a purely informative row are
    offered nothing and are left to the page text. [options] is the select's target list,
    empty on every other element. *)

val elements : Protocol.snapshot -> element list
(** The elements of a snapshot, in reading order, numbered afresh from ["1"]. *)

type request

val redact : (string * string) list -> request -> request

val upload_paths : string -> string list
(** revert-31w3: the absolute file paths a goal names verbatim, the only files an [upload]
    step may attach. *)

val make :
  model:string ->
  goal:string ->
  snapshot:Protocol.snapshot ->
  text:string ->
  recent:recent_action list ->
  can_scroll_down:bool ->
  can_scroll_up:bool ->
  request
(** Shapes one request. [model] is the configured System One model id; [text] is the
    page's rendered visible text from the [text] path, already bounded there; [recent] may
    be the drive's whole history, of which the last ten are sent.

    The two scroll flags are the conditions [snapshot.js:102-103] offers its scroll
    controls under: [can_scroll_down] is [scrollY + innerHeight < height - 2] and
    [can_scroll_up] is [scrollY > 0]. The drive states them, so the request offers only
    the controls that apply. *)

val without_actions : request -> (Protocol.Operation.t * int option) list -> request
(** map-op12: mask exact operation/target pairs for an unchanged page. *)

type image = { data_url : string; width : int; height : int; scale : float }
(** dmod-7w26: a viewport screenshot for a model that accepts images: a PNG data URL, its
    pixel size and the PNG-to-CSS scale. *)

val png_data_url : bytes -> string
(** [data:image/png;base64,...] for PNG bytes. *)

val with_image : request -> image -> request
(** dmod-7w26 dmod-4ky5: send the screenshot beside the state as an image part, and offer
    CLICK_AT with its two point questions. *)

val with_look : request -> bool -> request
(** dmod-mcgn: offer LOOK on this step. *)

val with_point_levels : request -> int -> request
(** The bands per axis of a CLICK_AT point (at least 2). *)

val with_coverage : request -> Yojson.Safe.t -> request
(** fly-crcc: attach exact guarded observation bounds and omissions. *)

val body : request -> Yojson.Safe.t
(** The wire document:
    [{"model": ..., "state": {"page": ..., "elements": ..., "recent_actions": ...},
     "questions": {"operation": ..., "<operation>_target": ...}}], in the reference's key
    order and with its key names. The [operation] criteria are the operations the elements
    can be given, each with jev's label string verbatim, then the controls the page offers
    — [SCROLL_DOWN] and [SCROLL_UP] under the two flags, [WAIT] always, each with the
    label [snapshot.js:102-104] gives it — then [DONE] and [BLOCKED]. *)

type decision = {
  operation : Protocol.Operation.t;
  index : int option;
  option : int option;
  confidence : float;
  target_confidence : float option;
  operation_probabilities : (string * float) list;
  target_probabilities : (string * float) list;
  targets : (string * float) list;
  point : Protocol.point option;
      (** dmod-4ky5: the CSS viewport point of a [click_at], from the two axis answers;
          [None] for every other operation. *)
}
(** What the drive acts on. [index] is the snapshot row for an operation that has a
    target, and [None] for [wait], the two scrolls, [done] and [blocked]; [option] is the
    chosen option's index in the select's own order when the target was a select option,
    and [None] otherwise — the two are the [select] action's [index] and [option]
    (tab-5deq). [targets] is the target distribution keyed by the action the drive would
    take — a row index, or ["<row>:<option>"] for a select option — which is the trace's
    form (drive-xjh6); [operation_probabilities] and [target_probabilities] are the
    model's own objects, keyed as the model answered them. *)

val decide : request -> answers:Yojson.Safe.t -> (decision, string) result
(** [answers] is the response's [answers] object. The operation answer is validated first,
    then only the target answer for the operation it chooses — an unused target head
    cannot cause an action and is not read. Every refusal is the reference's one sentence,
    ["Invalid TypeSafe response; no action executed."]: the chosen key must be one of the
    offered criteria, the distribution must carry exactly the offered keys, every number
    (the confidence among them) must be finite and within [0, 1], the distribution must
    sum to one within [0.02], and the chosen key must carry the maximum within [1e-6].
    Like the reference's validator, this reads [choice], [probabilities] and [confidence]
    only: an answer's [type] discriminant is the System One client's to decode (nso-megl),
    not this module's. *)

val trace_probabilities : decision -> Protocol.probabilities
(** The two raw distributions a trace step records: [op] keyed by JEV's operation keys,
    and [target] keyed by the action the drive took ({!decision}'s [targets]). *)

val stalled : recent_action list -> bool
(** The drive's stall rule, [agent.py:153-157] verbatim: true when the last three history
    entries all have [page_changed] [false] and a [kind] other than ["wait"] —
    [h["kind"] != "wait"] there, so an entry whose kind is unknown counts as a non-wait
    action. The drive calls it after each step with the same window {!body} sends
    (drive-4bhg). *)
