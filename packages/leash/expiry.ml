(* L13 — expiry and disposition (docs/issues/tab-ownership/01-tab-ownership.md, milestone
   3; ADR-0005). Stories: own-uo77 own-hslp own-2zpi own-ay3s own-nbwk own-vhqo own-5qoh.

   One fiber wakes on the clock every {!interval}, asks the registry for every tab's
   idleness, and applies {!decide} under each tab's lock. Stage 1 releases an owned tab no
   owner action has touched for the idle duration; stage 2 closes an unowned tab of agent
   origin nobody has claimed for the unclaimed duration. A human's tab is never
   auto-closed, and a tab the human holds is exempt from stage 1 while the hold lasts. *)

module P = Protocol
module Logger = Ox_observability.Logger

let interval = Ox.Duration.seconds 30

(* own-uo77 own-hslp own-2zpi own-ay3s: the whole policy, with no registry and no clock in
   it — the registry measures idleness, so both stages are checkable on their own. [Owned]
   is stage 1's only state: a handed-off tab is paused and an unowned one has nothing to
   release. Only agent origin reaches stage 2, however the tab became unowned: a human's
   page is never a timer's to take, whatever its ownership history (ADR-0005). *)
let decide ~idle ~unclaimed (tab : Tabs.idleness) =
  let idle_s = Ox.Duration.to_seconds_float idle in
  let unclaimed_s = Ox.Duration.to_seconds_float unclaimed in
  match tab.owner_state with
  | Tabs.Owned _ -> if tab.idle_for_s >= idle_s then Tabs.Release_idle else Tabs.Keep_idle
  | Tabs.Unowned -> (
      if P.Origin.to_string tab.origin <> "agent" then Tabs.Keep_idle
      else
        match tab.unowned_for_s with
        | Some unowned_for_s when unowned_for_s >= unclaimed_s -> Tabs.Close_idle
        | Some _ | None -> Tabs.Keep_idle)
  | Tabs.With_human _ -> Tabs.Keep_idle

type t = {
  tabs : Tabs.t;
  idle : Ox.Duration.t;
  unclaimed : Ox.Duration.t;
  logger : Logger.t;
}

(* Both stages are housekeeping a human may want to audit, so each one leaves a record.
   The pass runs under the tab's lock, so the record matches what was applied. *)
let note t (tab : Tabs.idleness) = function
  | Tabs.Keep_idle -> ()
  | Tabs.Release_idle ->
      Logger.info t.logger
        ~fields:
          [
            ("tab", Logger.String (P.Handle.to_string tab.handle));
            ("stage", Logger.String "release");
            ("idle_s", Logger.Float tab.idle_for_s);
          ]
        "tab released by expiry"
  | Tabs.Close_idle ->
      Logger.info t.logger
        ~fields:
          [
            ("tab", Logger.String (P.Handle.to_string tab.handle));
            ("stage", Logger.String "close");
            ("disposition", Logger.String "closed_by_ttl");
            ("unclaimed_s", Logger.Float (Option.value ~default:0. tab.unowned_for_s));
          ]
        "tab closed by expiry"

let sweep t =
  Tabs.sweep t.tabs ~decide:(fun tab ->
      let step = decide ~idle:t.idle ~unclaimed:t.unclaimed tab in
      note t tab step;
      step)

let create ~sw ?(interval = interval) ~idle ~unclaimed ~clock ~logger tabs =
  let t = { tabs; idle; unclaimed; logger } in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      (* own-uo77 own-hslp: one pass every [interval], sleeping on the same clock the
         registry reads, so a test drives the sweep with its mock clock. [spaced] never
         finishes, so the daemon runs until the switch is released; a defect inside a pass
         is left to propagate to the switch owner, as any other defect. *)
      let pass () : (unit, [ `Never ]) result =
        ignore (sweep t);
        Ok ()
      in
      ignore (Ox.Retry.repeat ~clock (Ox.Schedule.spaced interval) pass);
      `Stop_daemon);
  t
