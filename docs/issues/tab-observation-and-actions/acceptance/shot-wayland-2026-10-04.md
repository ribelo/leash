# Hidden-workspace screenshots — 2026-10-04

Story: tab-qmei. Worktree: shot-fix, created from 1de122b. During this investigation another session added 948ec43 (the CONTEXT-to-GLOSSARY documentation rename) to this branch; that unrelated commit was preserved. No screenshot change was committed, and the installed service was not changed.

## Result and scope

Viewport screenshots now use the existing operation-scoped focus emulation plus one PNG screencast frame: start, receive the first frame for that page session, acknowledge, stop. They never activate a tab, raise a window, or move a workspace. A five-second budget covers capture; stream cleanup is cancellation-protected with a separate two-second CDP deadline, followed by the existing bounded focus-emulation release.

**Full-page screenshots still use Page.captureScreenshot and can fail on a hidden workspace.** They now fail after five seconds with code timeout and an explanation that a hidden Wayland window may lack a compositor frame even while the page is responsive. They are not silently replaced by viewport images.

## Diagnosis

The fault reproduces outside Leash, using the historical chrome-cdp shotStr implementation from dotfiles revision 3ce3c4b^, its original launch arguments, a private debugging port, and fresh profiles. Therefore neither Leash's pipe transport, its extra flags, nor simply omitting clip is necessary for the fault.

On this niri desktop, Chrome 150 and 152 intermittently wait for a screenshot frame on an inactive workspace. Chrome 149 passed the same old-helper trial. This suggests a version regression in the Chrome/Wayland capture path, not a universally broken niri screenshot facility. It is not a Chromium bisection or a comparison with another compositor. The older 149/150 Nix wrappers have matching launch-switch templates; the installed 152 wrapper additionally forces Wayland and carries the operator's packaged extension switches. No everyday Chrome profile was used.

The compositor-surface explanation is supported by the workspace sensitivity and by Chromium's documented [Wayland frame-callback workaround during video capture](https://github.com/chromium/chromium/commit/de4b707490acca3612e077adaa35679231ee4b35). Actual Wayland callbacks were not traced here, so the exact internal stall remains an inference. requestAnimationFrame remained live during fixed-service verification: 19 frames in 304–313 ms, with visibilityState visible on each tab. Merely emulating focus was not sufficient; combining it with the video-capture path was.

## Controlled historical comparison

Each completed row is three public pages (example.com, example.org, example.net), three rounds. Old shape is the exact historical helper: Page.getLayoutMetrics then PNG captureBeyondViewport:false with CSS visual-viewport clip and scale 1/dpr. Plain shape omits the clip. Both shapes were interleaved by round in each 152 launch; timed-out browser requests may remain pending, so those rows are not independent cold captures. The 150 and 149 launches used only the old shape, ruling out prior no-clip requests as a prerequisite for the 150 failures. All timeouts below used 30 seconds.

| Chrome / launch switches | Request shape | Successful / attempted | Successful latency (s) | Timeouts |
|---|---|---:|---:|---:|
| 152 / historical only | old helper | 5/9 | 0.060–4.487 | 4 |
| 152 / historical only | plain | 2/9 | 0.114–0.744 | 7 |
| 152 / Leash flags, port instead of pipe | old helper | 6/9 | 0.058–28.669 | 3 |
| 152 / Leash flags, port instead of pipe | plain | 2/9 | 2.346–9.078 | 7 |
| 150 / historical only | old helper | 6/9 | 0.051–19.067 | 3 |
| 149 / historical only | old helper | 9/9 | 0.051–0.102 | 0 |

An additional fresh 152 old-only run was stopped when the operator prioritized repair candidates; its one completed capture is not treated as a complete trial.

## Repair candidates

Fresh Chrome 152 for each row, Leash launch flags, hidden workspace, three tabs and three rounds. The first screencast-alone trial retained the historical 30-second deadline; remaining candidates used the intended five-second capture budget. No candidate capture focused the private window or moved it. Operator-initiated changes among other desktop windows during some long calls are retained in the evidence rather than counted as Chrome focus theft.

| Candidate | Successful / attempted | Successful latency (s) | Failure |
|---|---:|---:|---|
| Single-frame screencast alone | 0/9 | — | no frame event within 30 s |
| Target.activateTarget then captureScreenshot | 4/9 | 0.080–0.181 | 5 capture timeouts |
| Page.bringToFront then captureScreenshot | 4/9 | 0.076–0.181 | 5 capture timeouts |
| Focus emulation then captureScreenshot | 1/9 | 1.385 | 8 capture timeouts |
| **Focus emulation + first screencast frame** | **9/9** | **0.016–0.073** | **none** |

Chosen-candidate timings by page, round order: com 0.073/0.018/0.016; org 0.028/0.019/0.020; net 0.018/0.019/0.018. Focused window id 4 was unchanged before and after every capture. Target.getTargets did not expose an active-tab field; no restoration machinery is needed because the selected fix never switches tabs.

Earlier exploratory private-Leash trials also rejected fromSurface:false (1/3 successful, 10.813 s) and optimizeForSpeed:true (2/3 successful, 11.864/0.230 s), with remaining captures timing out at 30 seconds. They were sequential trials on the same browser, not clean launches. Separate-window creation was excluded by operator decision and never tested. Launch-flag alternatives were skipped after the combined screencast candidate passed.

## Actual Leash verification

The built worktree binary ran a private headed service with fresh XDG config/state/runtime and a dedicated profile. Final verification used the real Chrome binary directly, without the exploratory CDP proxy or debugging port. Its window was placed on an inactive workspace once during setup, not moved during capture.

- Nine CLI viewport captures: 9/9, 0.042–0.046 s. Focused window id 3 unchanged throughout.
- Distinct headings injected into the three public test pages appeared in the corresponding screenshots: 3/3, 0.032–0.034 s. This checks page identity and fresh content rather than merely accepting identical PNGs from the example domains.
- Full-page: 0/3, honest timeout at 5.004/5.004/5.023 s; no incorrect viewport fallback.
- Viewport captures after those full-page timeouts: 3/3 at 0.040/0.046/0.063 s.
- Fresh Chrome startup briefly acquired focus in one aborted activation trial. That launch was closed and the comparison rerun with explicit restoration before private-window placement. This is separate from capture behavior; the final capture implementation makes no desktop calls.

[Sanitized measurements and before/after focus snapshots](<shot-wayland-2026-10-04.json>) retain window ids, workspace ids and focus timestamps, but omit desktop titles, capability handles and private profiles.

## Regression and gates

Fake-CDP coverage asserts PNG start, first frame only, correct page session, acknowledgement, stop, focus release, no activation calls, malformed-frame cleanup, five-second viewport/full-page deadlines, cancellation cleanup, and modal handling. Full-page capture retains its separate request shape. Existing PNG validation and filesystem handling remain in Reading.

All final gates passed: @install; dune test (real exit status 0, EIO_BACKEND=posix); @fmt -j 1; scripts/caps-gate (EIO_BACKEND=posix, no ulimit); git diff --check. A concurrent Dune gate attempt stalled before building and was stopped; the serial rerun completed successfully. Formatter promotion returned its expected nonzero “changed files” result before the final clean format gate.

All private services, Chrome processes and focus-event recording were stopped. A process scan found no remaining Chrome or Leash process with a private test path. Private XDG/profile directories and temporary historical scripts were removed. The installed leash.service, real Leash configuration/state and operator Chrome were not changed. Source and evidence changes remain uncommitted in shot-fix.
