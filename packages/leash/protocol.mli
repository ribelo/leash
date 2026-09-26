type request = { v : int; owner : string; cmd : string; args : Eta_schema.json }
(** Version-one control-socket contract. Each command has a closed [args] schema; the
    result schemas include later-milestone replies as well as milestone one. *)

type error = { code : string; message : string; detail : Eta_schema.json option }
type reply = { ok : bool; result : Eta_schema.json option; error : error option }

val request_schema : request Eta_schema.t
val reply_schema : reply Eta_schema.t
val error_schema : error Eta_schema.t
val command_schemas : (string * Eta_schema.json Eta_schema.t) list
val result_schemas : (string * Eta_schema.json Eta_schema.t) list
val tab_info_schema : Eta_schema.json Eta_schema.t
val snapshot_schema : Eta_schema.json Eta_schema.t
val row_schema : Eta_schema.json Eta_schema.t
val dialog_schema : Eta_schema.json Eta_schema.t
val action_result_schema : Eta_schema.json Eta_schema.t
val debug_entry_schema : Eta_schema.json Eta_schema.t
val step_schema : Eta_schema.json Eta_schema.t
val operation_schema : Eta_schema.json Eta_schema.t
val decode_request : Yojson.Safe.t -> (request, Eta_schema.issue list) result
val encode_request : request -> (Yojson.Safe.t, Eta_schema.issue list) result
val decode_reply : Yojson.Safe.t -> (reply, Eta_schema.issue list) result
val encode_reply : reply -> (Yojson.Safe.t, Eta_schema.issue list) result
