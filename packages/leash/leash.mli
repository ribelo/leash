(** Leash: a local browser service for coding agents. *)

val version : string

module Config : module type of Config
module Protocol : module type of Protocol
