(** Leash: a local browser service for coding agents. *)

val version : string

module Cdp : module type of Cdp
module Chrome : module type of Chrome
module Config : module type of Config
module Desktop : module type of Desktop
module Models : module type of Models
module Text_helper : module type of Text_helper
module Protocol : module type of Protocol
module Tabs : module type of Tabs
module Expiry : module type of Expiry
module Control : module type of Control
