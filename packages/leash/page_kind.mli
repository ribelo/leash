(* kind-a7uy kind-dnye kind-jdcs kind-s1k2: page kinds inferred from a URL's shape.

   Digits, hex of eight or more, UUIDs, and separator-free alphanumeric tokens of
   eight or more that mix a letter and a digit become [<id>]. A content slug — longer
   than 40 characters, two or more hyphens, a [+] or a capital, or ending [_<digits>]
   — becomes [<slug>]. A short word plus [ -<digits>] ([page-2]) stays [word-<id>].
   Segments that are only a [ref=], an [@] coordinate, or a [!] blob are dropped, and
   the pattern then ends in [*]. The name is the last static segment plus the
   placeholders after it. A session remembers the first name of each pattern; only a
   static name that collides gets a numeric suffix. *)

type t = {
  name : string;
      (** The kind, such as [listing] or [oferta-<id>]. Stable for one pattern inside a
          session. *)
  url_pattern : string;
      (** The observed URL with the query and fragment removed and id or slug segments
          replaced. The compiler turns this into a playbook pattern. *)
  title : string;  (** The title with the site-name part and a trailing counter removed. *)
}

val infer : url:string -> title:string -> t
(** One URL and title, with no memory of earlier pages. *)

type session
(** kind-dnye: the names given during one drive. The same generalized pattern always
    receives the same name. *)

val session : unit -> session

val observe : session -> url:string -> title:string -> t
(** [observe session ~url ~title] is {!infer}, except a pattern already seen returns its
    first name, and a new pattern whose name is already taken gets [-2], [-3], …
    (kind-dnye). *)

type source = Declared | Inferred

val classify :
  session -> declared:string option -> url:string -> title:string -> t * source
(** kind-4qke: [Some name] wins and is not entered in the session's mapping. [None] is
    {!observe}. *)

type draft_page = { name : string; url_pattern : string }
(** kind-s1k2: one entry of a draft [pages] section. The compiler writes the playbook;
    this value is not a playbook. *)

val draft_pages : session -> draft_page list
(** The session's mapping, first-seen order: each name and its generalized [url_pattern].
*)
