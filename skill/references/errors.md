# Errors and safe recovery

## Read the record, then follow its hint

Every failed CLI invocation writes **one compact JSON record** on stderr, including argument parsing, local configuration, connection, ownership, and browser/model failures:

```json
{"code":"stale-snapshot","message":"snapshot is stale; snap again","hint":"run `leash snap TAB` again and use its snapshot id"}
```

The shape is `{code,message,hint,detail?}`. `hint` is always present; `detail` is optional. There is no stdout protocol-error envelope to unwrap. `--pretty` does not pretty-print errors. Preserve the exit code, parse stderr if needed, and **follow the hint** within the task's authorization. Run `leash help errors` for every code, exit, meaning, and exact hint; `leash COMMAND --help` gives the accepted form. Do not classify failures by matching English message text.

| Exit | Class | Codes |
| --- | --- | --- |
| 64 | Usage / invalid request | `invalid-request`, `usage`, `no-dialog`, `no-handoff`, `url-refused` |
| 65 | Invalid configuration / page or script data | `config-invalid`, `stale-snapshot`, `row-not-actionable`, `dialog-open`, `too-large`, `script-failed`, `script-invalid` |
| 66 | Unknown / gone resource | `tab-gone`, `unknown-tab`, `no-such-row`, `body-unavailable`, `unknown-request` |
| 69 | Unavailable | `service-unreachable`, `browser-unavailable`, `model-unavailable` |
| 70 | Internal / invalid service reply | `internal`, `invalid-response` |
| 75 | Retryable condition | `timeout`, `tab-cap` |
| 77 | Permission / ownership | `not-owner`, `already-owned`, `with-human`, `socket-permission`, `permission-denied` |
| 124 | CLI parsing; command did not run | `cli-parse` |

Exit 75 is **not** permission to replay any action. A timeout, connection loss, or tab disappearance can follow a dispatched click, fill, press, upload, submission, or mission. Inspect the page, result, partial trace, downloads, or other task evidence first. If the outcome remains uncertain and repeating could cause harm, stop and ask the user. `drive` may also return a non-completion status inside a successful JSON reply; inspect that status even when the CLI exits 0.

## Common recovery recipes

### Service down: service-unreachable (69)

1. Read `detail.socket` and check the intended endpoint/configuration. Do not redirect to another browser or create a parallel service against the same profile.
2. Check `systemctl --user status leash`. If starting the installed service is authorized, run `systemctl --user start leash`, then `leash status` with your owner.
3. If setup fails, use `leash config check` and the service journal. A deliberate custom service needs the matching `--socket PATH` or `--config FILE` on client calls.
4. After reconnection, inspect live tabs before repeating work that may already have been sent.

For `browser-unavailable`, Chrome is restarting: check status again after a short bounded delay. Re-observe; do not reuse old handles/snapshot assumptions. A forced restart is not the first recovery step for a shared service.

### Stale snapshot (65) or no-such-row (66)

Run `leash snap TAB` again using the same owner. Choose the intended row from the new role/name/value/state and use its actual `index` with the **new `snapshot` ID**. Do not merely substitute a new ID into an old guessed index. Filtering/pagination does not renumber rows. For indexed eval, refresh both `--snapshot` and `--index`. Indexed scroll/text use the current table rather than accepting a snapshot argument.

If the page keeps moving, narrow the snapshot or wait for a concrete stable condition. `row-not-actionable` means disabled, covered, invisible, or wrong-kind input: inspect the obstruction/control, scroll if needed, and use `upload` for a file input. Do not bypass it with synthetic eval clicks.

### Tab gone (66)

Read `detail.disposition`: `closed_by_owner`, `closed_by_ttl`, `closed_externally`, or `browser_lost`. The handle is dead; `claim` cannot resurrect it. Use `leash list --all` to orient, then `leash new URL` if a replacement is still needed and authorized. A profile login may persist, but the tab's in-memory/page state may not.

For `unknown-tab`, obtain a real live handle from `list --all` or `new`; do not invent one. Before reopening/repeating a checkout, message, or other submission, verify whether it completed elsewhere.

### Not owner / already-owned (77)

Verify that your `--owner` or `DSH_SESSION_ID` has not changed, then run `leash list --all`. If the intended tab is unowned and the task permits it, `leash claim TAB` takes it. If another caller owns it, ask them to release it or open your own tab. `already-owned` on claim is a state refusal, not an invitation to impersonate the owner. Never use force-close/release to steal the tab.

### With the human (77)

Use `list --all` to see the handoff reason. Wait for the human's Done/resume signal. Call `leash resume TAB` only after they finish or explicitly authorize returning control. Then collect the blocked handoff result and take a fresh snapshot. Do not resume automatically merely because your next command was refused. For handoff timeout inspect `detail.warnings`; failed focus/notification may explain why the human never saw the request.

### Tab cap (75)

Check `leash status` and `leash list`. Close only your own unneeded disposable tabs, then retry `new` (or reuse an appropriate owned tab via `drive --tab`). If all tabs are needed or belong to others, ask the operator. Do not force-close another owner's tab or silently raise the service cap. Installed playbook syntax checks also need temporary-tab capacity.

## Other failures

- **`dialog-open` / `no-dialog`:** inspect the reported dialog; deliberately choose `leash dialog TAB accept` or `dismiss`, with `--text` for a prompt. Take a new snapshot before retrying. `no-dialog` means there is nothing to answer; refresh state.
- **`no-handoff`:** no active handoff exists. Check state instead of repeatedly resuming or creating a new handoff to silence the error.
- **`timeout`:** inspect completion first. For a genuinely unfinished wait, use a bounded larger `--timeout-ms`; for handoff, inspect warnings and coordinate with the human. Seconds flags (`--timeout-s` for handoff, `--deadline-s` for drive) are different from wait's milliseconds.
- **`unknown-request` / `body-unavailable`:** list `net TAB` again and choose an actual retained request ID. Bodies may be absent or evicted; do not treat missing history as proof that no request occurred.
- **`config-invalid`:** run `leash config check`, fix the named problems/path when authorized, then recheck. Do not overwrite the whole configuration to bypass one error.
- **`model-unavailable`:** inspect `detail.code` and the partial drive trace (`steps` or `procedures` when present). Possible provider detail codes include `missing-key`, `unavailable`, `timeout`, `authentication`, `invalid-response`, `input-too-large`, `model-mismatch`, and `text-helper-unavailable`. Fix credentials/model configuration or stop; no keys in reports. Provider retries are already bounded inside Leash.
- **`script-failed` / `script-invalid`:** read the message and first mismatched data path, repair the authored script/declared `returns` or page assumption, then run `playbook check` and `playbook test` as appropriate. A script test executes code; do not repeat a mutating script blindly.
- **`too-large`:** narrow text, rows, input, expression, argument, files, or script output. Do not discard the declared output shape or size bound.
- **`url-refused`:** use http/https without credentialed userinfo, or `about:blank`. Do not bypass the restriction with another command.
- **`invalid-request` / `usage` / `cli-parse`:** consult the exact command help and correct its arguments. `cli-parse` means the command did not run; it is safe to correct parsing without worrying about that invocation's dispatch.
- **`socket-permission` / `permission-denied`:** inspect the named path's owner/mode or choose a permitted path. Do not make the private socket/profile world-readable or switch to another user's service.
- **`internal` / `invalid-response`:** check status and retry an observation once if safe. If it persists, report the code/message and relevant nonsecret context as a defect. Do not dump page content or automatically replay a dispatched mutation.
