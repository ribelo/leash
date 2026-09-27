(** Leash: a local browser service for coding agents. *)

val version : string

module Cdp : module type of Cdp
module Chrome : module type of Chrome
module Config : module type of Config
module Protocol : module type of Protocol
module Tabs : module type of Tabs
module Expiry : module type of Expiry
module Control : module type of Control
