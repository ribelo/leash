# Google Flights click diagnosis — 2026-10-02

## Result and evidence limit

**The historical persistent no-op was not reproduced. No dispatch defect is established.** Six manual activations of **Explore destinations** on the requested HEAD reached "/travel/explore". The live investigation did reproduce the misleading *immediate* result: the baseline and four controlled comparisons initially returned the old Flights URL. Google performs asynchronous work after the trusted click, beyond Leash’s 50 ms settlement budget.

This explains an immediate unchanged observation, **not** the historical three unchanged clicks separated by multi-second model calls. Those older clicks lack event, geometry, console, and network evidence. Their exact cause remains unproved; it would be incorrect to claim that adding mouseMoved fixes them.

Raw selected observations: [evidence](<flights-click-diagnosis-2026-10-02/evidence.json>), [instrumentation](<flights-click-diagnosis-2026-10-02/probe.js>), [final screenshot](<flights-click-diagnosis-2026-10-02/explore-final.png>). Historical input: [Google2 README](<live-2026-10-02-google2/README.md>) and [mission trace](<live-2026-10-02-google2/flights/mission-1/drive.json#L563-L746>).

## Provenance and reproduction

- Tested master HEAD: `f983c07964557bf09a211a5834dace240b4e05b1`. Tracked tree was clean; the concurrent, untracked Maps3 evidence directory was preserved. Historical Google2 used 9a3b553. There is no intervening change to the click dispatch implementation; changes to tabs concern handoff/challenges, not the click path.
- Fresh private build: SHA-256 `14e87b671d4db7f04711e81f4699ba06735e3f6138d594669caf1b060b1b9c4f`. Build exit 0; Nix printed an ignored busy evaluation-cache warning.
- Chrome 152.0.7977.64, headless, remote-debugging-pipe, private profile, 1366 × 813 viewport; navigator.webdriver was false.
- All six XDG roots and downloads were private temporary directories. OPENROUTER_API_KEY was removed; learning was off. No models, real service unit, real config, existing profile, or user Chrome were used.

Build command:

```sh
timeout 900 nix develop -c env DUNE_BUILD_DIR=_build_flightsdiag bash -c 'ulimit -v 16777216; exec dune build @install'
```

Private setup followed [the harness](<../../../../scripts/live-acceptance-l53.py#L34-L43>): mktemp root; mode-0700 runtime/config/state/cache/data/downloads directories; export the corresponding XDG variables. Configuration used Chrome’s absolute binary path, an absolute profile path under that root, headless=true, tabs.cap=8, learning.mode="off", and empty handoff commands. Start the built binary with `serve --config "$XDG_CONFIG_HOME/leash/config.toml"`.

Exact start URL: https://www.google.com/travel/flights?hl=en

Exact mission, from the harness:

> On Google Flights, open Explore and stop when the Explore destinations map and destination flight prices are visible. Do not buy, book, send, upload personal data, log in, or bypass challenges. If cookie consent appears, choose Reject all only. Stop if login or a challenge is needed.

Manual sequence, with LEASH naming the private build and handles kept only in the temporary root:

```sh
"$LEASH" new 'https://www.google.com/travel/flights?hl=en'
"$LEASH" snap "$TAB" --limit 80
# Fresh profile: scroll down, snap again, click the observed Reject all row.
"$LEASH" scroll "$TAB" down
"$LEASH" snap "$TAB" --limit 80
"$LEASH" click "$TAB" "$SNAPSHOT" "$REJECT_ALL_INDEX"
# Find Explore destinations by name in a new snapshot; it was row 21.
"$LEASH" snap "$TAB" --limit 80
"$LEASH" eval "$TAB" "$(<probe.js)" --snapshot "$SNAPSHOT" --index 21
"$LEASH" net "$TAB" --limit 200
"$LEASH" click "$TAB" "$SNAPSHOT" 21
"$LEASH" eval "$TAB" 'return {url:location.href,ready:document.readyState,events:window.__diagEvents}'
"$LEASH" debug "$TAB" --limit 30
"$LEASH" net "$TAB" --limit 200
"$LEASH" shot "$TAB" /absolute/private/path/result.png
```

After baseline, each comparison opened a fresh tab at the same start URL in this isolated profile, found the row by name, and used a fresh snapshot. They reused only this profile’s Reject-all consent/cache. No automatic click replay was used.

## What actually receives the click

Baseline at page age 48.925 s:

- document.readyState="complete", visibilityState="visible", document.hasFocus()=true during eval. These are readiness observations, **not a general proof of hydration**; successful handling is the stronger evidence here.
- Target is a native **BUTTON**, not an anchor and not role=link. Its accessible label is Explore destinations. Its bounding rectangle is x=620.34375, y=526, width=110.3125, height=40.
- The quad/rectangle center is **(675.5, 546)**. elementFromPoint there returns the button’s **SPAN.VfPpkd-vQzf8d**, text Explore. Captured input has exactly those coordinates. No transparent covering element is hit.
- The button declares jscontroller="soHxf" and jsaction mappings including click:cOuCgd, mousedown:UX7yZ, mouseup:lbsD7e, mouseenter:tfO1Yc, mouseleave:JywGue, focus/blur and touch handlers. Its parent declares JIbuQc:wXjZtc. These attributes identify the JS activation path, not a native href navigation.
- Both capture and bubble listeners saw trusted **pointerdown → mousedown → pointerup → mouseup → click**, targeting that span. Buttons were 1 on down and 0 on up/click; click detail was 1. No captured event was defaultPrevented. A child swallowing the click was not observed.
- Chrome also generated pointerover/enter and mouseover/enter from the first press. An explicit mouseMoved was absent in plain-click trials, but the button still activated.
- Therefore an isTrusted rejection cannot explain these observed clicks: they are trusted. This does not prove Google has no trust checks anywhere. getEventListeners was unavailable through eval; native listener enumeration or all minified handler bodies were not inspected.
- In the final timing probe, the old button remained connected but had a zero-sized rectangle after Explore replaced the visible view. Its old geometry was no longer actionable. The post-navigation rectangle-center hit at (0,0) was the header, as expected for a hidden old view—not evidence that the original click hit the header.

## Small experiments

| Experiment | Before input | Immediate click result | Subsequent observation |
| --- | --- | --- | --- |
| Baseline, no explicit hover | Complete, page age 48.925 s | Flights URL | Explore on the next inspection |
| Cold-tab click | Complete, page age 0.794 s | Flights URL | Explore sampled 282 ms after click |
| Wait 3 s, click | Complete, page age 3.539 s | Flights URL | Explore sampled 469 ms after click |
| Wait 3 s, hover, fresh snap, click | Complete; trusted pointermove observed | Flights URL | Explore sampled 268 ms after click |
| No pre-click eval/listeners at all | Wait 3 s, snap, ordinary click | Flights URL | Immediate snap already had Explore URL but the same rows; after 5 s Explore controls and prices visible |
| Additional timing/geometry probe | Wait 3 s | Not retained in selected evidence | Explore; old target rectangle became zero-sized |

The sampled transition intervals after the captured click are (63,282] ms, (268,469] ms and (68,268] ms respectively—not exact navigation durations. Polling was every 200 ms and stopped when the URL changed.

**Hover is not the missing ingredient.** Waiting 3 s is not necessary in the successful cold-tab case, although a general load/hydration race in the old run remains possible. The no-eval control rules out the event instrumentation itself being necessary for success.

The timing probe’s first diagnostic result exceeded Leash’s output limit. The click was not repeated; bounded evidence was recovered from that same tab. A history-method wrapper recorded no calls and is not used to infer router behavior. All timing conclusions use observed URLs and trusted event timestamps.

## Network and console

The current click is not a no-op inside Google:

- New Google JS module requests followed the click. In the recovered timing probe, click capture was at 3463.4 ms; script requests began at 3465.2 and 3466.5 ms and finished at 3560.9 and 3518.2 ms. The first thus remained outstanding past a 50 ms settlement.
- Further navigation/map modules followed; in the uninstrumented control, GetExploreDestinations returned **200**, as did Maps GetViewportInfo and Maps JS resources. No failed request or uncaught exception was present in the debug ring. Request lists were compared by request ID before/after input.
- Debug contained Google’s ordinary self-XSS console warning and the Maps API loading=async performance warning; neither was a runtime exception.
- Final visible results included Paris PLN 185, London PLN 130, Rome PLN 230, and destination markers/price labels on Explore. The screenshot’s base map background was gray; do not mistake successful route/price activation for proof that every map tile had rendered.

## Leash source findings

[Actions.click](<../../../../packages/leash/actions.ml#L847-L865>) revalidates the snapshot/row, computes and hit-tests its aim, then sends **mousePressed and mouseReleased only**. There is no preceding mouseMoved. [The mouse helper](<../../../../packages/leash/actions.ml#L555-L565>) supplies x/y, button="left", buttons=1/0, clickCount=1. pointerType is omitted (CDP’s mouse default); no dwell or explicit timestamp is supplied. Chrome nevertheless synthesized the trusted DOM pointer/mouse/click sequence above. A real pointer normally moves before its press; [hover](<../../../../packages/leash/actions.ml#L1017-L1039>) provides that comparison without changing product code.

[Geometry](<../../../../packages/leash/actions.ml#L287-L304>) takes the first positive content quad’s center. [Aim](<../../../../packages/leash/actions.ml#L515-L553>) checks that target/descendant or associated label receives the point; a fully transparent cover is waited out before dispatch. The live input coordinates match the measured button center.

[Dispatch acknowledgement](<../../../../packages/leash/actions.ml#L122-L145>) means Chrome accepted input (or a documented popup/liveness path settled it), **not that Google’s async handler reached its destination**. [Manual settlement](<../../../../packages/leash/actions.ml#L587-L608>) waits two animation frames within 50 ms. Drive uses the same click with settle_after=false, then [operator settlement](<../../../../packages/leash/actions.ml#L1244-L1251>) with a 50 ms non-autocomplete deadline. [Drive](<../../../../packages/leash/drive.ml#L406-L422>) compares the next fingerprint and blocks after three unchanged non-WAIT actions. There is no site-hydration or router-completion contract in that acknowledgement.

## Cause, remaining candidates, proposed minimal fix

**Established:** the transient “dispatched but unchanged” observation is an asynchronous Google activation observed before completion. A button click initiates lazy JS/network work; the 50 ms observation budget can expire first. It is not a missing click event, an untrusted event, an incorrect fixed point, or a required hover in these live tests.

**Not established:** why all three historical clicks stayed unchanged. In that trace the model turns took seconds, so the sub-second delay measured here alone is insufficient. Remaining candidates, in evidence order:

1. **A much later or failed Google JS/module/navigation path** in the old page. Current activation demonstrably depends on post-click modules; old console/network data were not retained. A visible server-rendered button and a stable table do not prove that its app controller can complete navigation.
2. **An old-page hit-test/dispatch race or transient site state.** Current geometry and bubbling are correct, but no per-click coordinate/event capture exists for the historical actions, so those old inputs cannot be reconstructed. A now-unobserved cover/retargeting race cannot be conclusively excluded.
3. **Drive-specific timing/state interaction**, not demonstrated by manual CLI tests. The dispatch code is shared, but drive keeps its operation scope across model turns and uses its operator settlement/observation path. This investigation intentionally made no model calls; it does not claim a replay of the entire historical drive.

**Do not add mouseMoved as a claimed fix for this incident.** The smallest evidence-supported improvement is on observation: when an acknowledged click yields an unchanged fingerprint, do a bounded **read-only** re-observation (for example up to 1 s), before feeding “no progress” back or counting that action toward the three-action guard. Never redispatch the click. Validate it with a delayed SPA-navigation fixture (>50 ms), ensuring one input only and a genuinely inert button still reaches the bounded no-progress result. This would fix the demonstrated premature observation, not prove that the older persistent failure is fixed.

For the next persistent occurrence, retain before/after geometry and actual captured event target/trust, together with a bounded console/network delta before closing the tab. Only that evidence can choose between the remaining historical causes. No speculative product patch is warranted from this run alone.

## Cleanup and scope

Every diagnostic tab was closed. The verified private Leash process received SIGTERM and exited **0**; every recorded private Chrome PID was gone afterward. A temporary helper startup typo briefly created a malformed private profile directory in the unrelated working tree; that private process was stopped before browser work, the exact created directory was verified and removed, and the unrelated tree was checked clean afterward. The corrected service used only the absolute temporary profile above.

Temporary runtime/config/profile material was removed after exporting the selected evidence. The private build directory remains as requested build provenance. No product code changed, no commit was made, and unrelated Maps3 evidence was preserved.
