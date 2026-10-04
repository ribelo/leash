---
status: completed
milestone: 8
---

# Hardening 3: the first real field report

## Problem Statement

On 2026-09-30 an agent used the installed Leash (`094deda`) for real work the operator wanted done: registering accounts on DVIDS, Europeana, api.data.gov and DPLA, confirming them from Gmail, testing the keys. It got four of six. Its report lists eight bugs, and they group by cause into four defects, one of which is a design leak from L45.

1. **`snap` hides password fields (found on Europeana and DVIDS).** L45 applied the operator-level rule — JEV is never offered a password field as a target, which is right — to the agent-facing `snap`, which is wrong: the agent is the party that should type the password, `fill` targets by snapshot index, and hiding the field pushed the agent to `eval` with a native value setter, which is worse for secrets than `fill`. `fly-eoqg`'s rule belongs to the operator's element table only.
2. **A frozen page freezes the tab (Pixabay with Cloudflare Turnstile; the blank Google sign-in popup).** After the first load, every CDP call on the tab (`eval`, `nav`, `shot`) ran to its 30 s deadline while `snap`/`text` still answered; a `new` timed out yet created the tab, which then answered `unknown-tab` until `list` re-registered it. The service treats one tab's stuck renderer as a per-call timeout with no diagnosis, and the tab's registration is not atomic with the reply.
3. **`click` refuses a control covered by its own label (custom checkboxes on Europeana).** `row-not-actionable: covered at its click point` — correct as a hit test, wrong as a verdict: the covering element is the `<label for=>` of the target, and clicking it *is* the intended action.
4. **`settled` and `nav` report readiness that is not there.** `snap` returned 0 rows with `settled:true` on Gmail, pro.europeana.eu and the popup; `nav` returned `timeout` on pages that had in fact loaded (Gmail, Pixabay). Rows appeared seconds later on Europeana and never on Gmail, whose AX tree the agent had to bypass with `eval`. Snapshot row `value`s were also missing after a `fill` that had taken effect.

Plus three small things: cross-origin iframes (Flickr's reCAPTCHA) are invisible in `snap` so an agent cannot know a CAPTCHA blocks it; `click` answers with `snapshot:null` so long forms cost one `snap` per step; a `usage` error for a missing argument does not name which.

## Solution

Password fields return to `snap` for the agent (with `value` never echoed), and stay excluded from the operator's table. Per-tab CDP failures get a diagnosis (`renderer-unresponsive`, with the Turnstile/CAPTCHA signal from `debug` folded in) and tab registration becomes atomic with `new`'s reply. `click` follows a covering `<label for>` to its control. `settled` waits for the AX tree to be non-trivially populated or reports why it is not; `nav`'s timeout says what did happen. Cross-origin iframes appear as a row. Row actions may return a fresh snapshot on request.

## User Stories

### Password fields (design leak)

1. As an agent, I want `snap` to list password inputs as rows with role `textbox` and `state: ["password"]`, never a `value`, so that I can `fill` a password by index the way I fill any field. ^field-8bzc
2. As an agent, I want `fill` on a password row to accept its text from `--argument-file` or from stdin (`--stdin`) as well as the argument, and never to echo the value in its reply, the trace or a log line, so that a secret never sits on a command line or in a transcript. ^field-5sdo
3. As a maintainer, I want the operator-level element table (what JEV is offered) to keep excluding password, file and hidden inputs, with a test that the two tables differ exactly on those rows, so that the agent's view and the model's view are two rules, each right for its reader. ^field-sazr
4. As a maintainer, I want the fill-then-snap consistency the agent saw broken fixed: after a `fill` that took effect, the next snapshot's row shows the `value` for non-password fields, with a test on a React-controlled input, so that an agent can verify its own input. ^field-cct4

### A frozen page

5. As an agent, I want a per-tab CDP call that exceeds its deadline reported as `renderer-unresponsive` with `detail` carrying the last `debug` ring entries (a Turnstile/CAPTCHA warning, `ERR_CONNECTION_REFUSED`) and a hint ("the page's renderer is not answering; a bot-detection challenge or a hung script is likely; `shot` may still work; close the tab or hand off"), so that the agent learns *why* rather than `timeout` eight times. ^field-cde7
6. As an agent, I want `new` and `nav` to register the tab before waiting for load, and a load that times out to reply with the tab handle, its current URL and title, and `loaded:false`, so that a timeout never loses the handle and never claims the navigation did not happen. ^field-m5jw
7. As an agent, I want a popup that opens with an empty URL to be reported as `popups[].state: "opening"`, and a popup still blank after the settle window as `blank` with the opener's URL, so that a blank Google sign-in window is a fact, not a mystery. ^field-drpx
8. As a maintainer, I want one frozen-renderer test with the fake browser (a session that stops answering `Runtime.evaluate` while `Page.captureScreenshot` still answers) asserting the diagnosis, the working `shot`, and that other tabs are unaffected, so that the case is pinned. ^field-zr9n

### click follows a label

9. As an agent, I want `click` on a row whose click point is covered by a `<label>` whose `for` names the row's element (or which contains it) to dispatch on the label instead, reported as `via: label`, so that custom checkboxes and radios are clickable by index. ^field-uls3
10. As an agent, I want `check TAB SNAPSHOT INDEX` and `uncheck` as explicit commands that verify the control's `checked` state afterward and fail with `state-unchanged` if it did not flip, so that toggling a control is a verified action. ^field-guda

### settled, nav and heavy pages

11. As an agent, I want `settled:true` to mean the AX tree returned at least one interactive row *or* the page has no interactive content (checked by a cheap `document.querySelector` count), and otherwise `settled:false` with `reason: "ax-tree-empty"`, so that 0 rows on Gmail is reported as not ready rather than as an empty page. ^field-lp65
12. As an agent, I want `snap` on a page whose AX tree stays empty after two retakes to fall back to a DOM-derived row table (visible interactive elements by `querySelectorAll`, with roles inferred from tag and ARIA), marked `source: "dom"`, so that heavy pages like Gmail remain workable without `eval`. ^field-jkx6
13. As an agent, I want cross-origin iframes to appear in `snap` as a row with role `frame`, its `src` origin, and `state: ["cross-origin"]`, and a `debug` entry when a known challenge origin (reCAPTCHA, hCaptcha, Turnstile) loads, so that a CAPTCHA is visible before I wonder why nothing works. ^field-vji1

### Cost of long forms

14. As an agent, I want `--snap` on `click`, `fill`, `select`, `press`, `hover` and `check` to return a fresh snapshot in the reply (with the same `--match`/`--limit` options as `snap`), so that a long form costs one call per step instead of two. ^field-swvb
15. As an agent, I want a `usage` error for a missing positional to name the argument and the command's synopsis (`click: SNAPSHOT is missing; usage: click TAB SNAPSHOT INDEX`), so that an empty variable is diagnosed at the call. ^field-uqvp
16. As a maintainer, I want the field report recorded under `docs/research/2026-09-30-field-report/` with the eight findings mapped to stories, and the live gate extended with a registration-style form (password field, custom checkbox label, controlled input) served locally, so that the case that found these cannot regress. ^field-i4x0

## Implementation Decisions

- Password rows: the AX join keeps `INPUT[type=password]` for `snap` and strips its value; the operator script's `safe` filter is unchanged. Two functions, one table each.
- `renderer-unresponsive`: the per-call deadline stays; the mapping from `\`Timeout` on a *session* call (not a browser-level call) becomes the new code, with the tab's debug ring tail attached.
- Label following: at revalidation, when the top element at the click point is a `LABEL` whose `control` is the target (or which contains it), the dispatch point becomes the label's; reported in `via`.
- DOM fallback table: computed by a bounded script (250 rows, same bounds as the AX table), rows get fresh indices in the same snapshot id space; actions on `dom` rows revalidate by element identity as today.
- `--snap` on actions reuses the snapshot path after settlement; the reply's `snapshot` field is then non-null and documented.
- `fill --stdin` reads up to the existing 64 KiB bound.

## Testing Decisions

- Protocol seam with the fake browser for every story; live gate page for story 16. The frozen-renderer fake (story 8) is the one new fake behaviour.

## Out of Scope

Solving CAPTCHAs; interacting inside cross-origin iframes (visible only); OAuth popups' internals.

## Further Notes

Delivered 2026-10-01. Live gate `scripts/live-acceptance-l48` (private headless Chrome, `scripts/live/registration.html` served on 127.0.0.1): password row in `snap` as textbox/password without a value; `fill --stdin` on it with nothing echoed (the page's field held 14 characters); `fill --snap` returned a snapshot whose Email row showed the typed value on a controlled-style input; `check` on the label-styled checkbox succeeded `via: label` and the next snap showed it checked; a second `check` answered `state-unchanged`; `click` with an empty SNAPSHOT answered `usage` naming it — all PASS. Deviations: the controlled input is a self-contained native-setter page, not React (no React dependency in the tree); `source:"ax"` is always on the wire (the codec cannot omit a default). The frozen-renderer, DOM-fallback and iframe stories are covered by the fake browser only; no public page reliably reproduces them. The field report is in `docs/research/2026-09-30-field-report/`.

Source: an agent's report of 2026-09-30 after registering four API keys through Leash and Gmail. What worked: `new`/`list`, `fill` with Polish letters, `eval --argument` for secrets, `net body`, `debug` naming Turnstile, popup reporting, screenshots, reading confirmation links from Gmail. The agent also noted the installed skill was stale — closed by L44.
## Later field reports (2026-10-04)

Two defects the operator hit while using Leash on his own work after L48, filed here rather than in a new milestone because they are the same kind of finding: a real page broke a rule that looked right in tests. Both are fixed and pushed; the commits cite these story IDs.

23. As the operator, I want a click whose hit test lands on a node inside the target row's shadow root to count as a hit, so that a web component's own ripple or feedback layer is not mistaken for something covering the control. YouTube Studio refused the "Add" button on subtitles and the confirmation control in the delete dialog with `row-not-actionable: the row is covered at its click point` on 2026-10-03 and again on 2026-10-04, although nothing covered them: the hit answered with a node inside the button's shadow root, and `subtree_contains` walked children and pseudo-elements but not `shadowRoots`. Fixed in 1de122b: the describe pierces (`pierce: true`) and the walk follows `shadowRoots`; a fake-CDP regression fails without the fix. ^hard-s4ht
24. As the operator, I want `leash shot` to return a viewport screenshot while the Chrome window sits on a workspace I am not looking at, because that is where Leash lives and screenshots stopped working there. On 2026-10-04, with the window on an inactive niri workspace, `shot` timed out after 30 s with `renderer-unresponsive` on 2 of 3 tabs while `requestAnimationFrame` ran at ~64 fps and every tab reported itself visible. Reproduced outside Leash with the old chrome-cdp helper: Chrome 152 5/9, Chrome 150 6/9, Chrome 149 9/9 — a Chrome 150+ regression under a hidden Wayland surface, not a Leash fault. Fixed in ad5d8e2: a viewport shot takes one frame from `Page.startScreencast` under the focus emulation the service already sets (9/9 at 16–73 ms, no tab switch, no window raise, no focus change on the operator's desktop); `--full-page` keeps `Page.captureScreenshot` with a 5 s bound and an error naming the cause. Measurements and the trial matrix are in [acceptance/shot-wayland-2026-10-04.md](../tab-observation-and-actions/acceptance/shot-wayland-2026-10-04.md). ^hard-wayp
