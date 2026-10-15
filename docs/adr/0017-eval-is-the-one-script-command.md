# Eval is the one script command

Decision of the operator, 2026-10-15, after an outside-in review of how agents run their own JavaScript. The case was a data-collection program (YouTube Studio statistics) that ran on `leash eval` with a 64 KiB result bound and a 30 s call deadline, polled the page by starting a new `leash eval` process every second, and retried `renderer-unresponsive` errors that were the deadline, not a hung page.

Programs that agents write to collect data from logged-in sites are a supported use. `eval` is the only command that runs the agent's own JavaScript. It takes the body inline or from `--file`, any JSON argument inline or from `--argument-file`, and `--timeout-ms` up to ten minutes (default 30 s). The body is at most 1 MiB; the argument and the result are at most 8 MiB each. A call that runs out of its deadline while the page still answers is `script-timeout`; `renderer-unresponsive` is kept for a page that does not answer.

This amends ADR-0016: `leash script run`, its `returns` shape check, its string-only `--arg` values and `--out` are removed. The calling program checks the result; shell redirection writes files. Leash adds no JavaScript wait condition and no API-discovery helpers: a body waits inside the page, and `net` already shows request headers and bodies.
