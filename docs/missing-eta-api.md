# Missing Eta APIs used by Leash

Record every workaround for an Eta gap here with an `etagap-*` ID before writing it, and remove it when Eta provides the API. Planned capabilities that are tracked as Eta tickets (`etaproc`, `etarpc`, `etaipc`, `etaso`) are not gaps: Leash waits for them.

## etagap-43zf — a fake child's standard output cannot be scripted (hand-phof)

`Eta_test.Process` scripts a spawned child's *exit* (`Exit`, `Block_until_signal`) and nothing
else, so a test cannot make a fake command print a line. The human-facing side of a handoff
needs exactly that: the notification command's Done action reaches the service as a line on
its stdout (`notify-send --action done=Done` prints `done`), and without scripted output the
resume path has no test at the seam L17 names.

Workaround: Leash's test support carries `Scripted_commands`, a stand-in for
`Leash.Desktop.runner` that records argv and replays `Print`/`Exit`/`Failure`/`Block` per
command. The real runner (`Eta_process.Child`) is still exercised through eta_test's fake
process manager for argv, exit statuses, the five-second deadline, retirement and a missing
binary, so the gap is only the scripted stdout. Remove this entry, and the scripted runner
with it, once `Eta_test.Process` can script standard output.
