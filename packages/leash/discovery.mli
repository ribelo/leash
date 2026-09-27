(** Who a target Chrome reports from outside the control protocol belongs to, and the
    shapes those reports arrive in.

    Chrome pushes [Target.targetCreated] for every page target in the browser — one the
    human opened in the Chrome UI, one a page opened, and one Leash itself asked for — and
    [Target.targetDestroyed] when one goes away. The registry has to decide an origin and
    an owner for those targets, and the decision is made once, when the target is first
    seen: an origin is a fact about creation and is never rewritten (ADR-0005, own-c0cl
    own-ehqa). *)

type creator = { origin : Protocol.Origin.t; owner : Protocol.Owner.t option }
(** A tab's creator as Leash knows it: the origin it passes on, and the owner that
    inherits it. Used both for what the registry knows about an opener and for what a
    target is born with. *)

val born : creator option -> creator
(** own-c0cl own-ehqa: the one origin rule. [None] — no [openerId] at all, or an opener
    the registry does not know — is human origin and nobody's, which is what a tab opened
    in the Chrome UI and a popup from a forgotten tab both are. [Some creator] is the
    opener's origin and its owner: a page's popup belongs to whoever owned the tab it came
    from, because ownership follows cause. *)

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
