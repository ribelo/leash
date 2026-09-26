(** Leash: a local browser service for coding agents. *)

val version : string

module Cdp : module type of Cdp
module Chrome : module type of Chrome
module Config : module type of Config
module Protocol : module type of Protocol
