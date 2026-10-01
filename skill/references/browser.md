# Read, act, wait, and hand off

All commands below act on your owned tab. Pass `--owner NAME` on every service call if not using `DSH_SESSION_ID`. The signatures use `TAB`, `SNAPSHOT`, `INDEX`, and `ID` for values returned by Leash, not literal arguments. Shell examples use actual variables; the optional `jq` examples need Bash and jq. Without jq, read those same fields from JSON.

`new` and `nav` preserve the registered handle when a 30 s load wait expires.
Their successful replies include `loaded:false` with the current URL/title: inspect
the tab before retrying navigation, closing it or handing it off. `loaded:true`
means load completed; other tab-info replies omit the field (field-m5jw).

If a tab session stops answering CDP, `renderer-unresponsive` carries its last
20 debug entries in `detail.entries`. A challenge or hung script is likely;
`shot` may still work and other tabs remain independent. Close the affected tab
or hand it off instead of blindly repeating input (field-cde7).

## Read the smallest useful view

| Command | What to inspect |
| --- | --- |
| `leash snap TAB [--match TEXT] [--limit N] [--offset N]` | Indexed rows plus `snapshot`, URL, title, `total`, `truncated`, `settled`, `source`, optional `reason`, and `dialog`. Default limit 120. |
| `leash text TAB [--index N] [--max-chars N]` | Visible text, optionally scoped to a row of the current snapshot. Default/maximum 65536 characters; check `truncated`. |
| `leash shot TAB PATH [--full-page]` | PNG screenshot; the reply names its path and byte count. |
| `leash debug TAB [--limit N] [--clear]` | Console messages, exceptions, and failed requests since attachment. `--clear` discards the ring after reading. |
| `leash net TAB [--match TEXT] [--type TYPE] [--limit N]` | Recent request metadata, not bodies; types include `document`, `xhr`, and `fetch`. Default 100, maximum 500. |
| `leash net TAB body ID` | Response body for a listed request ID; check `base64` and `truncated`. |
| `leash net TAB request ID` | Request method, URL, headers, and any post data; check `base64` and `truncated`. |
| `leash cookies TAB` | Cookies, including HttpOnly values. Read only when necessary; do not paste secrets into reports. |
| `leash storage TAB local` / `leash storage TAB session` | Read-only storage for this origin; check `truncated`. |
| `leash downloads TAB` | This tab's downloads: suggested name, MIME, state, `received_bytes`, `total_bytes`, and completed path when Chrome supplies it. |

`settled:true` means the document stayed stable and AX contains an interactive row, or a cheap DOM count found no interactive content. `settled:false` with `reason:"ax-tree-empty"` is not proof the page is blank: after two retakes, Leash can return up to 250 visible DOM-derived rows with `source:"dom"`. AX snapshots have `source:"ax"`; both use normal snapshot IDs and backend element identity checks. Inspect the rows and verify the expected page condition before assuming readiness. Non-password input row values reflect the current DOM value after a successful fill.

A cross-origin iframe appears as role `frame`, named by its src origin, with `state:["cross-origin"]`. It is informational, not a target for inner-frame actions. `debug` names known reCAPTCHA, hCaptcha, and Turnstile loads; use a screenshot or human handoff when a challenge blocks the task, not an attempt to solve it.

Dialogs are **state** in snapshots, tab info, and action replies. They block page reads (`text`, `eval`, `shot`) as well as input; these reads return `dialog-open`, including when a dialog opens during the read. Inspect it and use `leash dialog TAB accept` / `dismiss` deliberately, then retry the read. `snap` can still report the dialog; `leash dialog` answers one, it is not a read command. Network/debug rings are bounded and begin when the tab is created or attached/claimed; they are not a full browser history.

Downloads normally land in `~/.local/share/leash/profile/downloads` (`$XDG_DATA_HOME/leash/profile/downloads` when set, or `downloads/` under a custom `chrome.profile_dir`). A pending download has no usable completed path. Verify `state: completed` before using it; a suggested filename, received byte count or `.crdownload` file is not proof of completion.

If a download loses Chrome (`tab-gone` with `detail.disposition: browser_lost`, or a triggering navigation reports `internal`), do not repeat the crashing click/navigation blindly. Check `leash status` until running; old handles and their download tracking are gone. Inspect the downloads directory for a completed file and verify its contents/size against the source; lingering `.crdownload` files are partial, not success. Do not delete partial files without authorization. If still needed, open a new tab and retry only after the browser problem is understood and the download is safe to repeat; report recurring crashes rather than looping or restarting the shared service.

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
| `leash click TAB SNAPSHOT INDEX [--snap]` | Trusted click. A covering label of that control is clicked and reported as `via: "label"`. |
| `leash fill TAB SNAPSHOT INDEX [TEXT] [--argument-file PATH \| --stdin] [--snap]` | Fill the observed control. Password text belongs in `--argument-file` or `--stdin`, never a flag value; the reply, trace and logs never echo it. |
| `leash select TAB SNAPSHOT INDEX OPTION [--snap]` | Choose an observed option index of a native select. |
| `leash press TAB SNAPSHOT KEY [--index N] [--snap]` | Focus row N first if supplied; otherwise send to the page. Snapshot currency is checked either way. |
| `leash hover TAB SNAPSHOT INDEX [--snap]` | Move to the observed row. |
| `leash check TAB SNAPSHOT INDEX [--snap]` | Click and require the control to become checked. Already checked, or a click that does not flip it, is `state-unchanged`. |
| `leash uncheck TAB SNAPSHOT INDEX [--snap]` | The unchecked twin of `check`. |
| `leash scroll TAB up` / `leash scroll TAB down` | Scroll one viewport. `--index N` instead brings a current row into view; no snapshot ID argument. |
| `leash upload TAB SNAPSHOT INDEX PATH...` | Set local files on the observed `file-input` row, including a hidden one. Do not try to click/fill the file input. |
| `leash nav TAB URL` | Navigate to http, https, or `about:blank`; credentialed userinfo and other schemes are refused. |
| `leash dialog TAB accept [--text TEXT]` / `leash dialog TAB dismiss` | Deliberately answer the reported dialog; `--text` supplies a prompt response. |

Accepted `press` keys: Enter, Tab, Backspace, Delete, ArrowUp, ArrowDown, ArrowLeft, ArrowRight, Home, End, PageUp, PageDown, Escape/Esc, Space, lowercase a-z, digits 0-9, and the single punctuation characters `- = [ ] ; , . / '`. Unsupported names return `invalid-request` with this accepted set.

A successful action returns URL/title, `dialog`, and any owned `popups`. `snapshot` is null unless you passed `--snap`, in which case it is a fresh snapshot object (same `--match` and `--limit` as `snap`) taken after settlement. `via` is `"label"` when the click landed on the target's covering label, and omitted otherwise. The current snapshot remains valid through input that leaves the page unchanged. A newer `snap` or navigation invalidates older IDs, and a changed/removed target row is refused even with the current ID. On `stale-snapshot`, inspect `detail.snapshot` (current ID, or null when no table remains), re-snap and re-find the row; if navigation removed it, navigate back only when appropriate. Check dialogs/popups rather than assuming the original page is still the only relevant tab. Disabled, covered, or wrong-kind rows can be `row-not-actionable` even with a current snapshot.

Action `popups` carry readiness, separate from ownership: `state:"opening"` for
an empty/about:blank URL still in its first second (including dialog interruption),
`state:"blank"` when it remains blank after the bounded 1 s settle window, or
`state:"ready"` once it has a committed URL. Each includes `opener_url`. A blank
popup is not necessarily an action failure; inspect it with list/text/shot before
retrying the opener action (field-drpx).

A click that submits or navigates can return before navigation settles, with the **previous** URL/title. Do not repeat it on that evidence alone. Wait for the expected URL/text with a bounded `leash wait`, or re-snap and inspect the resulting page before acting again.

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

This call blocks, selects the live tab inside Leash's Chrome, and sends the human a notification that stays until they click Done; it does not take their focus (a raise command is opt-in config). Keep it running while the human acts; in a harness, use a tracked background job so you can communicate the request. Do not wait for the blocking call before telling the human what to do. While `state: with_human`, tab reads/actions are refused, including yours. `list --all` still shows its reason.

The notification's Done action or a second client can resume it:

```bash
leash resume "$TAB" --owner human
```

Anyone may call resume because it returns the tab to its original owner, not to the caller. An agent should do so only after the human says they are finished, not to seize it back. Timeout or disconnect also returns ownership; neither proves the human completed the task. Collect the waiting command's result, inspect any `warnings` (or `detail.warnings` on timeout), take a fresh snapshot, and verify the page the human left. `no-handoff` means no handoff is active; refresh state instead of starting/resuming repeatedly.
