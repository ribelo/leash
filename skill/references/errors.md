# Errors and safe recovery

## Read the record, then follow its hint

Every failed CLI invocation writes **one compact JSON record** on stderr, including argument parsing, local configuration, connection, capability, and browser/model failures:

```json
{"code":"stale-snapshot","message":"the snapshot or target row is no longer current","hint":"read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting","detail":{"snapshot":null}}
```

The shape is `{code,message,hint,detail?}`. `hint` is always present; `detail` is optional. There is no stdout protocol-error envelope to unwrap. `--pretty` does not pretty-print errors. Preserve the exit code, parse stderr if needed, and **follow the hint** within the task's authorization. Run `leash help errors` for every code, exit, meaning, and exact hint; `leash COMMAND --help` gives the accepted form. Do not classify failures by matching English message text.

This table matches `leash help errors` (daily-c4cl, daily-9ggi).

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
| `url-refused` | 64 | scheme is not http, https, or about:blank, or the URL has userinfo | use an http or https URL with no userinfo, or about:blank |
| `tab-cap` | 75 | no capacity for a new tab | close a tab with `leash close TAB`, then retry `leash new` |
| `renderer-unresponsive` | 75 | a tab session CDP call exceeded its deadline; detail.entries carries its last debug entries | the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off |
| `timeout` | 75 | wait, handoff, or a bounded operation ran out of time; a handoff's detail.warnings lists the steps that failed | retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB` |
| `browser-unavailable` | 69 | Chrome is restarting | Chrome is restarting; retry `leash status` in a few seconds |
| `model-unavailable` | 69 | System One or the text helper failed, or no API key is configured; detail.code is missing-key, unavailable, timeout, authentication, invalid-response, input-too-large, model-mismatch, or text-helper-unavailable | read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry |
| `model-timeout` | 75 | a model call exceeded its per-call deadline | the model provider timed out; retry, or raise models.<kind>_timeout |
| `too-large` | 65 | expression, argument, result, fill text, or a script result is over its bound | shrink the text, expression, argument, or files under the bound and retry |
| `script-failed` | 65 | a playbook script threw, rejected, or could not be compiled; message carries what it threw | read message; fix the script or the page, then `leash playbook test` |
| `script-invalid` | 65 | a playbook script's result does not fit its returns; message is the first mismatch | the result missed its returns shape; message is the first bad path, so fix the script or the returns |
| `playbook-invalid` | 65 | a playbook failed validation (load, check or accept); message names the rule | fix the playbook as the message says, then `leash playbook check ./DIR`; the skill's authoring reference lists the rules |
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

Exit 75 is **not** permission to replay any action. A timeout, connection loss, or tab disappearance can follow a dispatched click, fill, press, upload, submission, or mission. Inspect the page, result, partial trace, downloads, or other task evidence first. If the outcome remains uncertain and repeating could cause harm, stop and ask the user. `drive` may also return a non-completion status inside a successful JSON reply; inspect that status even when the CLI exits 0.

## Common recovery recipes

### Service connection failures

All commands classify a missing socket using the same systemd observation: `not-installed` (69) means no user unit, `service-stopped` (69) means an installed inactive unit, `service-restarting` (75) means activating/auto-restarting, and `service-unreachable` (69) means the active or unknown service still has no usable socket. Follow that code's hint; an absent unit needs installation, not repeated start attempts.

1. Read `detail.socket` and check the intended endpoint/configuration. Do not redirect to another browser or create a parallel service against the same profile.
2. Check `systemctl --user status leash`. If starting the installed service is authorized, run `systemctl --user start leash`, then `leash status` with the same handle.
3. If setup fails, use `leash config check` and the service journal. A deliberate custom service needs the matching `--socket PATH` or `--config FILE` on client calls.
4. After reconnection, inspect live tabs before repeating work that may already have been sent.

For `browser-unavailable`, Chrome is restarting: check status again after a short bounded delay. Re-observe; do not reuse old handles/snapshot assumptions. A forced restart is not the first recovery step for a shared service.

### Stale snapshot (65) or no-such-row (66)

Every `stale-snapshot` has the same message and `detail.snapshot`: the current ID, or null if no current table exists. A newer snap or navigation invalidates older IDs; input that leaves the page unchanged keeps the current ID valid. The target row may still have changed role/name, disappeared, or belong to a previous document. Run `leash snap TAB` again using the same handle. Choose the intended row from the new role/name/value/state and use its actual `index` with the **new `snapshot` ID**. If the intended row is gone, re-find it on the current page, or navigate back when appropriate and snap again. Do not merely substitute a new ID into an old guessed index. Filtering/pagination does not renumber rows. For indexed eval, refresh both `--snapshot` and `--index`. Indexed scroll/text use the current table rather than accepting a snapshot argument.

If the page keeps moving, narrow the snapshot or wait for a concrete stable condition. `row-not-actionable` means disabled, covered, invisible, or wrong-kind input: inspect the obstruction/control, scroll if needed, and use `upload` for a file input. Do not bypass it with synthetic eval clicks.

### Tab gone (66)

Read `detail.disposition`: `closed_by_handle`, `closed_by_idle`, `closed_externally`, or `browser_lost`. The handle is dead; it cannot be resurrected. Use `leash list` to orient, then `leash new URL` if a replacement is still needed and authorized. A profile login may persist, but the tab's in-memory/page state may not.

For `unknown-tab`, obtain a real live handle from `new`, `take`, or its holder; do not invent one. Before reopening/repeating a checkout, message, or other submission, verify whether it completed elsewhere.

### Take refused

`ambiguous` includes handle-free metadata for each matching tab: narrow the URL, title, or exact label. `no-match` means refresh the listing. `taken` means a capability already exists; ask its holder to share that handle or open another tab. A human hold must not be bypassed.

### With the human (77)

Use `list` to see the human hold. Wait for the human's Done/resume signal. Call `leash resume TAB` only after they finish or explicitly authorize returning control. Then collect the blocked handoff result and take a fresh snapshot. Do not resume automatically merely because your next command was refused. For handoff timeout inspect `detail.warnings`; failed focus/notification may explain why the human never saw the request.

### Tab cap (75)

Check `leash status` and `leash list`. Close only your own unneeded disposable tabs, then retry `new` (or reuse an appropriate tab whose handle you have via `drive --tab`). If all tabs are needed or belong to others, ask the operator. Do not close a tab without the handle and authorization or silently raise the service cap. Installed playbook syntax checks also need temporary-tab capacity.

## Other failures

- **`dialog-open` / `no-dialog`:** inspect the reported dialog; deliberately choose `leash dialog TAB accept` or `dismiss`, with `--text` for a prompt. Take a new snapshot before retrying. `no-dialog` means there is nothing to answer; refresh state.
- **`no-handoff`:** no active handoff exists. Check state instead of repeatedly resuming or creating a new handoff to silence the error.
- **`renderer-unresponsive`:** inspect `detail.entries` (the tab's last 20 debug-ring entries) for a challenge or hung script. `shot` may still work, as may other tabs. Close the affected tab or hand it off; do not blindly replay a mutation. Browser-level calls still use `timeout`.
- **`timeout`:** inspect completion first. For a genuinely unfinished wait, use a bounded larger `--timeout-ms`; for handoff, inspect warnings and coordinate with the human. Seconds flags (`--timeout-s` for handoff, `--deadline-s` for drive) are different from wait's milliseconds.
- **`unknown-request` / `body-unavailable`:** list `net TAB` again and choose an actual retained request ID. Bodies may be absent or evicted; do not treat missing history as proof that no request occurred.
- **`config-invalid`:** run `leash config check`, fix the named problems/path when authorized, then recheck. Do not overwrite the whole configuration to bypass one error.
- **`model-timeout` (75):** a model call exceeded its per-call deadline. Inspect the partial trace/page before retrying; when authorized, raise `models.<kind>_timeout` (`jev_timeout`, `text_timeout`, or `planner_timeout`).
- **`model-unavailable`:** inspect `detail.code` and the partial drive trace (`steps` or `procedures` when present). Possible provider detail codes include `missing-key`, `unavailable`, `timeout`, `authentication`, `invalid-response`, `input-too-large`, `model-mismatch`, and `text-helper-unavailable`. Fix credentials/model configuration or stop; no keys in reports. Provider retries are already bounded inside Leash.
- **`script-failed` / `script-invalid`:** read the message and first mismatched data path, repair the authored script/declared `returns` or page assumption, then run `playbook check` and `playbook test` as appropriate. A script test executes code; do not repeat a mutating script blindly.
- **`too-large`:** narrow text, rows, input, expression, argument, files, or script output. Do not discard the declared output shape or size bound.
- **`url-refused`:** use http/https without credentialed userinfo, or `about:blank`. Do not bypass the restriction with another command.
- **`invalid-request` / `usage` / `cli-parse`:** consult the exact command help and correct its arguments. `cli-parse` means the command did not run; it is safe to correct parsing without worrying about that invocation's dispatch. A drive `--url` that is not http(s) without userinfo, or a `--max-steps` of 0 or less, is `usage` and names a correct example. That is not a missing playbook.
- **`socket-permission` / `permission-denied`:** inspect the named path's permissions or choose a permitted path. Do not make the private socket or profile world-readable.
- **`internal` / `invalid-response`:** check status and retry an observation once if safe. If it persists, report the code/message and relevant nonsecret context as a defect. Do not dump page content or automatically replay a dispatched mutation.
