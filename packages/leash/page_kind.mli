(* kind-a7uy kind-dnye kind-jdcs kind-s1k2: page kinds inferred from a URL's shape.

   Digits, hex of eight or more, UUIDs, and separator-free alphanumeric tokens of
   eight or more that mix a letter and a digit become [<id>]. A content slug — longer
   than 40 characters, two or more hyphens, a [+] or a capital, or ending [_<digits>]
   — becomes [<slug>]. A short word plus [ -<digits>] ([page-2]) stays [word-<id>].
   Segments that are only a [ref=], an [@] coordinate, or a [!] blob are dropped, and
   the pattern then ends in [*]. The name is the last static segment plus the
    placeholders after it. Observed static siblings under the same static prefix
    merge into [<slug>], updating earlier mappings and draft pages. Other static name
    collisions get a numeric suffix. Non-HTTP(S) pages have no kind. *)

type t = {
  name : string;
      (** The kind, such as [listing] or [oferta-<id>]. Stable for one pattern inside a
          session. *)
  url_pattern : string;
      (** The observed URL with the query and fragment removed and id or slug segments
          replaced. The compiler turns this into a playbook pattern. *)
  title : string;  (** The title with the site-name part and a trailing counter removed. *)
}

val is_page : url:string -> bool
(** kind-a7uy: only HTTP(S) pages are eligible for inference. *)

val infer : url:string -> title:string -> t
(** One URL and title, with no memory of earlier pages. Non-web URLs return empty name and
    pattern and are never stored by {!observe}. *)

type session
(** kind-dnye: the names given during one drive. The same generalized pattern always
    receives the same name. *)

val session : unit -> session

val observe : session -> url:string -> title:string -> t
(** [observe session ~url ~title] returns the canonical pattern and name, merging observed
    siblings into [<slug>] (kind-dnye). Re-observing an earlier URL resolves its updated
    mapping. Unrelated static name collisions receive [-2], [-3], … *)

type source = Declared | Inferred

val classify :
  session -> declared:string option -> url:string -> title:string -> t * source
(** kind-4qke: for web pages, [Some name] wins and is not stored in the session. [None] is
    {!observe}. Non-web pages never receive a declared or inferred kind. *)

type draft_page = { name : string; url_pattern : string }
(** kind-s1k2: one entry of a draft [pages] section. The compiler writes the playbook;
    this value is not a playbook. *)

val playbook_name : string -> string
(** map-bjon: convert abstract kind placeholders into valid playbook slug components:
    [books-<slug>] becomes [books-slug]. Inference itself keeps the abstract names. *)

val playbook_pattern : string -> string
(** map-bjon: convert abstract [<id>] and [<slug>] URL segments to executable [*]
    wildcards. Existing wildcards and trailing path annotations are preserved. *)

val inferred_pages : session -> draft_page list
(** kind-s1k2: abstract observed patterns and names, in first-seen order. Durable evidence
    retains placeholders rather than executable wildcard projections. *)

val draft_pages : session -> draft_page list
(** The session's mapping, first-seen order, using executable playbook wildcard patterns.
*)
