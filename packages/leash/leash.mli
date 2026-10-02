(** Leash: a local browser service for coding agents. *)

val version : string

module Cdp : module type of Cdp
module Chrome : module type of Chrome
module Download_setup : module type of Download_setup
module Config : module type of Config
module Learning : module type of Learning
module Telemetry : module type of Telemetry
module Desktop : module type of Desktop
module Models : module type of Models
module Text_helper : module type of Text_helper
module Protocol : module type of Protocol
module Traces : module type of Traces
module Page_kind : module type of Page_kind
module Playbook : module type of Playbook
module Run : module type of Run
module Tabs : module type of Tabs
module Expiry : module type of Expiry
module Control : module type of Control
module Shape : module type of Shape
