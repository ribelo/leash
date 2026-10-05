(* hand-0ibq hand-ihcg: one rule; the tab lock guards the recheck and close. *)
let interval = Ox.Duration.seconds 30

let decide ~idle (tab : Tabs.idleness) =
  if
    Protocol.Origin.to_string tab.origin = "agent"
    && (not tab.with_human)
    && tab.idle_for_s >= Ox.Duration.to_seconds_float idle
  then Tabs.Close_idle
  else Tabs.Keep_idle

type t = { tabs : Tabs.t; idle : Ox.Duration.t }

let sweep t = Tabs.sweep t.tabs ~decide:(decide ~idle:t.idle)

let create ~sw ?(interval = interval) ~idle ~clock ~logger:_ tabs =
  let t = { tabs; idle } in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      let pass () : (unit, [ `Never ]) result =
        ignore (sweep t);
        Ok ()
      in
      (* The spaced schedule owns repetition; termination has no sweep value to report. *)
      let _schedule_ended = Ox.Retry.repeat ~clock (Ox.Schedule.spaced interval) pass in
      `Stop_daemon);
  t
