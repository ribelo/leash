(** hdoc-8c12: markdown topics as plain text. No ANSI. *)

val render : string -> string
(** Headings become underlined titles, lists stay lists, tables become aligned columns,
    and code fences are copied verbatim. *)
