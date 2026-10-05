val host : string -> string option
(** The lowercase host of an http(s) URL, without userinfo or port; [None] for any other
    URL. *)

val is_page : url:string -> bool
(** Whether the URL is an http(s) page. *)
