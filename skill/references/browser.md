# Read, act, wait, and hand off

All commands below act on your owned tab. Pass `--owner NAME` on every service call if not using `DSH_SESSION_ID`. The signatures use `TAB`, `SNAPSHOT`, `INDEX`, and `ID` for values returned by Leash, not literal arguments. Shell examples use actual variables; the optional `jq` examples need Bash and jq. Without jq, read those same fields from JSON.

## Read the smallest useful view

| Command | What to inspect |
| --- | --- |
| `leash snap TAB [--match TEXT] [--limit N] [--offset N]` | Indexed accessibility rows plus `snapshot`, URL, title, `total`, `truncated`, `settled`, and `dialog`. Default limit 120. |
| `leash text TAB [--index N] [--max-chars N]` | Visible text, optionally scoped to a row of the current snapshot. Default/maximum 65536 characters; check `truncated`. |
| `leash shot TAB PATH [--full-page]` | PNG screenshot; the reply names its path and byte count. |
| `leash debug TAB [--limit N] [--clear]` | Console messages, exceptions, and failed requests since attachment. `--clear` discards the ring after reading. |
| `leash net TAB [--match TEXT] [--type TYPE] [--limit N]` | Recent request metadata, not bodies; types include `document`, `xhr`, and `fetch`. Default 100, maximum 500. |
| `leash net TAB body ID` | Response body for a listed request ID; check `base64` and `truncated`. |
| `leash net TAB request ID` | Request method, URL, headers, and any post data; check `base64` and `truncated`. |
| `leash cookies TAB` | Cookies, including HttpOnly values. Read only when necessary; do not paste secrets into reports. |
| `leash storage TAB local` / `leash storage TAB session` | Read-only storage for this origin; check `truncated`. |
| `leash downloads TAB` | This tab's downloads: suggested name, MIME, state, `received_bytes`, `total_bytes`, and completed path when Chrome supplies it. |

Dialogs are **state** in snapshots, tab info, and action replies. `leash dialog` answers one; it is not a read command. Downloads stay under the managed profile's downloads directory; a pending download has no usable completed path. Verify `state: completed` before using it. Network/debug rings are bounded and begin when the tab is created or attached/claimed; they are not a full browser history.

A read-only example using a fresh scratch tab:

```bash
set -o pipefail
OWNER="browser-example-$$"
TAB=$(leash new https://example.com --owner "$OWNER" | jq -er '.tab') || exit 1
leash snap "$TAB" --owner "$OWNER" --limit 20
leash text "$TAB" --owner "$OWNER" --max-chars 2000
leash shot "$TAB" /tmp/leash-example.png --owner "$OWNER"
leash net "$TAB" --owner "$OWNER" --type document --limit 5
leash debug "$TAB" --owner "$OWNER" --limit 10
leash close "$TAB" --owner "$OWNER"
```

`net` is asynchronous: entries arrive from Chrome events and can lag a navigation/action reply. A first empty ring is not proof that no request happened. Wait for a concrete page condition (`leash wait TAB --text TEXT --timeout-ms 5000`) and read `net` again; if needed, retry this read for a bounded interval. Completion-only fields such as size/duration can remain null while the request is pending.

For a network failure, list metadata first, choose an actual returned `id`, then read its body or request. The ring is per tab; never reuse an ID from another tab. `body-unavailable` may mean Chrome evicted it or there was no body, not that the request failed. Bodies, headers, cookies, storage, screenshots, and console output can contain private data; expose only the evidence needed for the requested diagnosis.

## Snapshot-bound actions

Take a fresh JSON snapshot, choose the row by its observed role/name/value/state, and carry **both** the returned `snapshot` ID and the row's `index`. Filtering/pagination preserves actual indices: row position in the output is not its index. For native selects, inspect the row's `options` and use the option's observed numeric `index`, not a label/value or a separate option row.

| Signature | Contract |
| --- | --- |
| `leash click TAB SNAPSHOT INDEX` | Trusted click on an actionable row. |
| `leash fill TAB SNAPSHOT INDEX TEXT` | Fill the observed editable control. |
| `leash select TAB SNAPSHOT INDEX OPTION` | Choose an observed option index of a native select. |
| `leash press TAB SNAPSHOT KEY [--index N]` | Focus row N first if supplied; otherwise send to the page. Snapshot currency is checked either way. |
| `leash hover TAB SNAPSHOT INDEX` | Move to the observed row. |
| `leash scroll TAB up` / `leash scroll TAB down` | Scroll one viewport. `--index N` instead brings a current row into view; no snapshot ID argument. |
| `leash upload TAB SNAPSHOT INDEX PATH...` | Set local files on the observed `file-input` row, including a hidden one. Do not try to click/fill the file input. |
| `leash nav TAB URL` | Navigate to http, https, or `about:blank`; credentialed userinfo and other schemes are refused. |
| `leash dialog TAB accept [--text TEXT]` / `leash dialog TAB dismiss` | Deliberately answer the reported dialog; `--text` supplies a prompt response. |

Accepted `press` keys: Enter, Tab, Backspace, Delete, ArrowUp, ArrowDown, ArrowLeft, ArrowRight, Home, End, PageUp, PageDown, Escape/Esc, Space, lowercase a-z, digits 0-9, and the single punctuation characters `- = [ ] ; , . / '`. Unsupported names return `invalid-request` with this accepted set.

A successful action returns URL/title, `dialog`, and any owned `popups`; its `snapshot` is null. Observe again before the next row action. Check dialogs/popups rather than assuming the original page is still the only relevant tab. Disabled, covered, or wrong-kind rows can be `row-not-actionable` even with a current snapshot.

Runnable navigation example on a disposable tab (opens the first observed link on example.com):

```bash
set -o pipefail
OWNER="browser-link-$$"
TAB=$(leash new https://example.com --owner "$OWNER" | jq -er '.tab') || exit 1
SNAP=$(leash snap "$TAB" --owner "$OWNER" --limit 20) || exit 1
SID=$(jq -er '.snapshot' <<<"$SNAP") || exit 1
INDEX=$(jq -er 'first(.rows[] | select(.role == "link") | .index)' <<<"$SNAP") || exit 1
leash click "$TAB" "$SID" "$INDEX" --owner "$OWNER" || exit 1
leash snap "$TAB" --owner "$OWNER" --limit 20
leash close "$TAB" --owner "$OWNER"
```

The example's scratch tab is the only cleanup target. For a real form, read its observed controls, fill only the requested fields, and verify their values before an authorized submission. Do not turn a whole form into a blind chain of guessed indices or repeated Enter presses.

## One-off JavaScript

`eval` takes a **function body** with `return`, not a bare expression. A JSON `--argument` binds `argument`; indexed calls bind `element` as well and require `--snapshot`. With `TAB`, `SID`, and `INDEX` set from the current snapshot, these are read-only queries:

```bash
leash eval "$TAB" 'return document.title' --owner "$OWNER"
leash eval "$TAB" 'return {tag: element.tagName, text: element.textContent}'   --snapshot "$SID" --index "$INDEX" --owner "$OWNER"
leash eval "$TAB" 'return document.querySelectorAll(argument.selector).length'   --argument '{"selector":"a"}' --owner "$OWNER"
```

Do not use eval to bypass ownership, stale-target checks, refused URLs, or a needed trusted UI action. JavaScript may change the page; writes require the same authorization as other actions. For reusable data collection, read [missions and playbooks](missions.md) instead of repeatedly injecting ad hoc scripts.

## Wait for a concrete result

`wait` conditions are ANDed. Use one or more of `--url-prefix`, `--text`, `--index-gone`, `--dialog`, and `--changed-since SNAPSHOT`; `--until` accepts their JSON form. `--timeout-ms` defaults to 30000, maximum 3600000; `--timeout` is its millisecond alias, not seconds.

For a tab navigated to example.com:

```bash
leash wait "$TAB" --text 'Example Domain' --timeout-ms 5000 --owner "$OWNER"
leash wait "$TAB" --until '{"url_prefix":"https://example.com","text":"Example Domain"}'   --timeout-ms 5000 --owner "$OWNER"
```

`--changed-since` detects navigation or DOM mutation from a remembered snapshot; it does not prove the desired outcome. Only the last eight baselines are retained. A wait holds no action lock, so it can run beside an action in another client; its polling keeps the tab active. A disconnect cancels it. A dialog interrupts ordinary waits with `dialog-open`; answer only after inspecting it. On timeout, inspect the actual page before increasing the bound or repeating anything.

## Hand the live tab to the human

For login, CAPTCHA, MFA, or a choice only the human can make, explain what is needed and use the **headed** managed browser. Do not ask for secrets in chat or automatically solve/approve a security challenge.

```bash
leash handoff "$TAB" 'Please finish sign-in, then choose Done'   --timeout-s 900 --owner "$OWNER"
```

This call blocks, activates the live tab, and attempts desktop focus/notification. Keep it running while the human acts; in a harness, use a tracked background job so you can communicate the request. Do not wait for the blocking call before telling the human what to do. While `state: with_human`, tab reads/actions are refused, including yours. `list --all` still shows its reason.

The notification's Done action or a second client can resume it:

```bash
leash resume "$TAB" --owner human
```

Anyone may call resume because it returns the tab to its original owner, not to the caller. An agent should do so only after the human says they are finished, not to seize it back. Timeout or disconnect also returns ownership; neither proves the human completed the task. Collect the waiting command's result, inspect any `warnings` (or `detail.warnings` on timeout), take a fresh snapshot, and verify the page the human left. `no-handoff` means no handoff is active; refresh state instead of starting/resuming repeatedly.
