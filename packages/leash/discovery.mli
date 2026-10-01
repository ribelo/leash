type target = {
  id : string;
  session : string option;
      (** [Some] only when the report is an attachment ([Target.attachedToTarget]). *)
  url : string option;
  title : string option;
  opener : string option;  (** The target id of the tab that opened this one. *)
}
(** The page [TargetInfo] members of docs/cdp-shapes.md that Leash reads. *)

val announced : Yojson.Safe.t -> target option
(** The page target in a [Target.targetCreated] or [Target.targetInfoChanged]
    notification's params, sessionless: Chrome announces a target before it attaches to
    it. [None] for a target Leash does not track — a non-page target, or params without a
    target id. *)

val attached : Yojson.Safe.t -> target option
(** The page target in a [Target.attachedToTarget] notification's params, carrying the
    session it was attached under. [None] for a non-page target. *)

val destroyed : Yojson.Safe.t -> string option
(** The target id of a [Target.targetDestroyed] notification's params (own-teh1). *)
