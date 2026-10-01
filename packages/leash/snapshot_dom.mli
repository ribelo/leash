val expression : selector:string -> string

val rows :
  call:(string -> Yojson.Safe.t -> (Yojson.Safe.t, Protocol.error) result) ->
  context:int ->
  selector:string ->
  ((Protocol.row * int) list, Protocol.error) result
(** field-jkx6: at most 250 visible rows with tag/ARIA roles and backend node identities.
    Remote objects live in an isolated-world object group released before returning. *)
