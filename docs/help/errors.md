# Errors

Each row is one code the service or the CLI can return. The wire object is
`{code,message,hint,detail?}`. Exit status is the class, not 1. Field meaning
is in the other topics; this table is the code, when it is used, and the next
action.

| code | exit | meaning | hint |
| --- | --- | --- | --- |
| `invalid-request` | 64 | malformed JSON, unknown command, or bad arguments | fix the request; `leash <command> --help` names the arguments and one example |
| `ambiguous` | 66 | take matches several tabs; detail.matches lists them without handles | narrow the URL, title or label selector |
| `no-match` | 66 | take matches no tab | read `leash list` and use a matching URL prefix, title or label |
| `taken` | 77 | the tab already has a live handle | ask the holder for the handle |
| `with-human` | 77 | the tab is handed to the human; commands are refused until resume | the human holds this tab; wait, or return it with `leash resume TAB` |
| `tab-gone` | 66 | the handle names a closed tab; detail.disposition is closed_by_handle, closed_by_idle, closed_externally, or browser_lost | open a new tab with `leash new` |
| `unknown-tab` | 66 | no tab and no tombstone for the handle | that handle is not a tab; open a new tab with `leash new`, or ask the holder for the handle |
| `stale-snapshot` | 65 | the snapshot id or target row no longer matches the current page | read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting |
| `no-such-row` | 66 | the index is not in the snapshot | that index is not in the snapshot; `leash snap TAB` and use a listed index |
| `body-unavailable` | 66 | net body or request has no body to read, or Chrome has evicted it | that body is gone; `leash net TAB` and read a request that still has one |
| `unknown-request` | 66 | the tab's ring holds no request with that id | that id is not in the tab's ring; `leash net TAB` and use a listed id |
| `row-not-actionable` | 65 | the row is not visible, is disabled, is covered, or is the wrong kind of control | pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload` |
| `state-unchanged` | 65 | a check or uncheck did not change the control's checked state | snap and read the row's state; the control did not toggle, so pick another row or click its label |
| `dialog-open` | 65 | a dialog blocks page reads and actions; answer it first | answer it with `leash dialog TAB accept` or `leash dialog TAB dismiss`, then retry |
| `no-dialog` | 64 | dialog was asked with nothing to answer | nothing is open; `leash snap TAB` and call dialog only when a dialog is shown |
| `no-handoff` | 64 | resume on a tab nobody is waiting on | nobody is waiting; `leash handoff TAB REASON` starts one, and only then does `leash resume TAB` finish it |
| `canceled-by-operator` | 77 | the operator canceled or dismissed the handoff notification | stop this mission; do not retry without a new instruction from the operator |
| `headless` | 69 | a handoff or notification asked for a human, but the browser is headless | nobody can see a headless browser: finish without the human or stop and report what is needed |
| `url-refused` | 64 | scheme is not http, https, or about:blank, or the URL has userinfo | use an http or https URL with no userinfo, or about:blank |
| `tab-cap` | 75 | no capacity for a new tab | close a tab with `leash close TAB`, then retry `leash new` |
| `timeout` | 75 | wait, handoff, or a bounded operation ran out of time; a handoff's detail.warnings lists the steps that failed | retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB` |
| `renderer-unresponsive` | 75 | a tab session CDP call exceeded its deadline; detail.entries carries its last debug entries | the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off |
| `browser-unavailable` | 69 | Chrome is restarting | Chrome is restarting; retry `leash status` in a few seconds |
| `model-unavailable` | 69 | System One or the text helper failed, or no API key is configured; detail.code is missing-key, unavailable, timeout, authentication, invalid-response, input-too-large, model-mismatch, or text-helper-unavailable | read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry |
| `model-timeout` | 75 | a model call exceeded its per-call deadline | the model provider timed out; retry, or raise models.<kind>_timeout |
| `too-large` | 65 | expression, argument, result, fill text, or a script result is over its bound | shrink the text, expression, argument, or files under the bound and retry |
| `script-failed` | 65 | an eval expression or script threw, rejected, or could not be compiled; message carries the engine error | read message; fix the expression, script, or page; a script is the body of an async function of args |
| `script-invalid` | 65 | a script's result does not fit its returns block; message is the first mismatch | the result missed its returns shape; message is the first bad path, so fix the script or the returns |
| `internal` | 70 | a defect; the message carries no page content | a defect, not a page failure; retry once, then report the message |
| `service-unreachable` | 69 | the CLI could not connect to the control socket | `systemctl --user start leash`, or pass --socket |
| `not-installed` | 69 | no leash.service unit is installed | Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash` |
| `service-stopped` | 69 | the leash unit is installed but inactive | `systemctl --user start leash`, then `leash status`; a brief service-restarting (75) right after start is normal - retry; tabs and snapshots from before the stop are gone, so re-open them |
| `service-restarting` | 75 | the leash unit is activating or auto-restarting, or Chrome's generation is being relaunched | Leash is restarting; retry `leash status` in a few seconds |
| `socket-permission` | 77 | the CLI was denied access to the control socket | the control socket is not readable; check its permissions, or pass --socket |
| `permission-denied` | 77 | the CLI was denied access to a filesystem path | check the path's permissions, or pass another path |
| `config-invalid` | 65 | the configuration file is missing, unreadable, or invalid | fix the reported problems; `leash config check` lists every one with the config path |
| `usage` | 64 | the command was invoked wrongly; the arguments do not match its synopsis | `leash <command> --help` shows the arguments and an example |
| `cli-parse` | 124 | Cmdliner rejected the command line; the command did not run | the command line did not parse; `leash <command> --help` shows the accepted form |
| `invalid-response` | 70 | the service reply was not a protocol object the CLI could decode | the service reply was not a protocol object; check `leash status` and retry |
