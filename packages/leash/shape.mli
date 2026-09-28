(** The declared shape of a playbook script's result (L37;
    docs/issues/extract/01-extract.md).

    A shape is a small JSON type language, decoded once into this variant. A scalar is one
    of the strings ["string"], ["number"], ["boolean"] and ["url"] (an absolute http or
    https URL); a record is an object of field name to shape, a field whose name ends in
    [?] being optional (absent or null); a list is an array of exactly one shape. A
    script's [returns] is a record or a list of records; nested lists may hold scalars.

    {[
      [ { "title": "string", "price": "number", "rating?": "number", "url": "url",
          "offers": [ { "seller": "string", "price": "number" } ] } ]
    ]} *)

type scalar = String | Number | Boolean | Url

type t = Scalar of scalar | Record of field list | List of t
and field = { name : string; optional : bool; shape : t }

val t_of_yojson : Yojson.Safe.t -> (t, string) result
(** Decodes any shape, nested at most eight deep; the error names the path of the first
    thing wrong. *)

val yojson_of_t : t -> Yojson.Safe.t
(** The shape as it is written, so a decoded shape round-trips. *)

val check_returns : t -> (unit, string) result
(** A script's [returns] is a record or a list of records (extr-zdst). *)

val validate : t -> Yojson.Safe.t -> (unit, string) result
(** Fail-closed: the first mismatch is the error, written as [<path>: <what>] with the
    path in [$[2].price] form. A missing field, a field the shape does not declare, a
    value of another type, a number that is not finite and a URL that is not absolute
    http(s) are all mismatches (extr-zdst extr-8o1h). Pure. *)

val records : Yojson.Safe.t -> int
(** How many records a validated result holds: the length of a list, one for a record. *)
