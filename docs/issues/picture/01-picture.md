---
status: completed
milestone: 13
---

# Operate the picture — L58

## Decision and scope

ADR-0013 withdraws the agent-authored coordinate prohibition. A streamed browser, VNC-style application or canvas may expose no DOM row for the desired control. Coordinates are first-class, not a point-to-row adapter. Rows remain preferable when they name the control, and retain revalidation. This slice extends the existing managed browser, control protocol and pilot; it does not add an OS-input service, another browser or milestone 14 work.

## User stories

### Coordinate clicks

As an agent operating a picture, I want to click a point even when it names no row. When the agent sends `click TAB --at X,Y` or `dblclick TAB --at X,Y`, Leash shall dispatch the requested viewport-CSS point and return its hit-test evidence. The existing `click TAB ROW` path shall retain revalidation; coordinates shall not be converted into a row. ^pic-egvj

### Coordinate scrolling and dragging

As an agent operating a streamed pane, I want gestures to reach that pane rather than the outer page. When the agent sends `scroll TAB --at X,Y --dy N` or `drag TAB --from X,Y --to X,Y`, Leash shall dispatch the wheel or held-pointer gesture at those viewport-CSS points and return what was hit at the relevant points. ^pic-f2hy

### Focused typing

As an agent operating a picture, I want to type into the control I focused without inventing a row. When the agent sends `type TAB TEXT`, Leash shall type into the currently focused element without a row target, retaining protected secret transport; `press` shall retain its existing behaviour. ^pic-33hm

### Hit and screenshot evidence

As an agent choosing picture points, I want the image and coordinates to agree. When Leash returns a `shot`, it shall report image dimensions, viewport dimensions in CSS pixels and the image-to-viewport scale, including HiDPI (L44). Coordinate replies shall describe the hit, with role/label when available or no element when none exists; a canvas/stream host shall not be presented as an identified drawn control. When `--shot` is given on an action, Leash shall return a post-action screenshot path. Coordinate action evidence shall retain the points, hit and screenshots rather than claim a successful outcome from dispatch alone. ^pic-ncu1

### Mixed-page observations

As an agent working on a page with both DOM controls and a picture, I want one image aligned with the named controls. When the agent sends `snap TAB --with-image`, Leash shall return a screenshot and every row's box in viewport CSS pixels, with the screenshot's scale and viewport; row actions shall still revalidate. ^pic-7nv6

### Pilot picture acts

As an operator giving the pilot a mission on a picture, I want it to act on what it sees. When the pilot chooses `click_at`, focused `type` or `drag`, Leash shall execute the first-class picture act under the existing turn, step, deadline, capability, dialog and consequential-action policies. It shall preserve protected secret references and shall not automatically retry a possibly executed act. ^pic-7ozf

### Pilot image observations

As an operator giving the pilot a picture-only mission, I want it to see the screen rather than empty rows. When the pilot requests `observe --image`, Leash shall supply the current screenshot as model image input with viewport/scale information. While the page has no useful rows, Leash shall also supply that image without requiring a row to describe the target. ^pic-k4ij

### Agent guidance

As an agent using Leash, I want guidance that matches the supported action targets. When the agent reads the bundled skill or `help browser`, Leash shall explain screenshot-and-coordinate workflows for streamed browsers and canvas, CSS-pixel conversion, mixed-page observations and the preference for revalidated rows when they exist; it shall no longer prohibit model-chosen coordinates. ^pic-1jrz

### Fake-browser contract gate

As a maintainer, I want each command's dispatch and reply proved without a real browser. When the default test suite runs, Leash shall exercise every new coordinate command, focused typing, screenshot metadata, post-action evidence and `snap --with-image` across the control/CDP fake-browser seams, and exercise image-aware pilot decisions through the fake model seam. ^pic-cqcf

### Local canvas live gate

As an operator, I want proof that a picture-only control works before attempting authentication. When the live gate runs against a local canvas with a drawn button and no corresponding DOM action row, Leash shall operate it by screenshot and coordinates and independently verify the canvas page's resulting state; evidence shall record CSS/image alignment and the hit/post-action screenshots. ^pic-iomj

## Landing order

1. ADR-0013 and AGENTS.md policy reversal (delivered separately).
2. This L58 specification and map row.
3. Coordinate commands, focused typing and hit/screenshot evidence with fake-browser tests.
4. `snap --with-image` and row boxes with fake-browser tests.
5. Bounded image-aware pilot acts and observations with fake-model tests.
6. Bundled skill and `help browser`.
7. Local canvas gate.

One verified pushed commit per step. Only afterward resume L57F: U5, U10, U9, U7, U8, in that order and under their existing IDs.

## Open stories

The coordinate slice implements `pic-egvj`, `pic-f2hy`, `pic-33hm` and `pic-ncu1`. Control/CDP tests cover every new command, fractional CSS dispatch versus native integer hit samples, canvas-host/empty-hit evidence, HiDPI and full-page scale, private before/after PNGs and refused-drag button release. CLI tests cover the picture forms, mixed/nonfinite input and protected text sources.

`pic-7nv6` implements `snap --with-image`: a private measured viewport PNG and each row's native viewport-CSS border box, explicitly null when unavailable. Native box evidence is not device-scaled and does not become row identity; row revalidation retains its existing targets. The control/CDP and CLI tests cover image admission, 2× PNG/CSS alignment, unavailable boxes, private PNGs and observation without input.

`pic-7ozf` and `pic-k4ij` give the pilot `click_at`, focused `type`, `drag` and `observe --image`. Picture acts run under the existing tab lock, policies and secret transport; known row boxes under a point feed the consent and consequential-action checks without becoming row targets. The screenshot reaches the model as a PNG image part of the Ox chat request (Ox `2e9bfc0f`, row 93), and its text facts state the measured PNG-to-CSS scale without the private path. With this, `pic-cqcf` is complete: the fake-model tests cover the image wire, correction and the pilot acts. No live success is inferred from these fake-browser results.

`pic-1jrz` adds `leash help browser` and the skill's browser reference (one text, diff-tested): a picture page is worked by `snap --with-image` and viewport-CSS coordinates, rows are preferred when they name the control, and the skill no longer forbids model-chosen coordinates.

`pic-iomj` passed on 2026-10-05 ([evidence](acceptance/live-2026-10-05-canvas/result.json)). [scripts/live-acceptance-l58](../../../scripts/live-acceptance-l58) serves a loopback page whose only content is a canvas with a "Launch" button drawn at a random point, starts a private headless service with its own XDG directories and Chrome profile, and drives one mission with the real pilot (`openai/gpt-6-luna`, reasoning `max`, learning off). The page records each canvas click in its own state and posts it to the harness, so the outcome does not rest on the pilot's reply. Run: `secret-env ai -- scripts/live-acceptance-l58 EVIDENCE_DIR` after `dune build @install`.

- No DOM action row named the button; the snapshot PNG was 1366×813 for a 1366×813 CSS viewport, scale 1 ([alignment](acceptance/live-2026-10-05-canvas/alignment.json), [before](acceptance/live-2026-10-05-canvas/before.png)).
- With no useful rows, the pilot's first turn received the screenshot as an image part automatically (the same capture `observe --image` requests); it did not need to ask for one. It answered `act` with `click_at` (308, 282) inside the drawn button at (218, 250, 180×64), then `done`: "The canvas shows Launched." Two model calls, $0.00097 ([pilot clicks](acceptance/live-2026-10-05-canvas/pilot-clicks.json)).
- The hit evidence names the canvas host, not a drawn control; the canvas recorded exactly one click, inside the button, and its own state read `launched` ([server hits](acceptance/live-2026-10-05-canvas/server-hits.json), [page state](acceptance/live-2026-10-05-canvas/after-page-state.json), [after](acceptance/live-2026-10-05-canvas/after.png)). No private Chrome survived the service.

The gate found a defect first ([pre-fix run](acceptance/live-2026-10-05-canvas/pre-fix/pilot-clicks.json)): the pilot's first `click_at` failed before dispatch because its before-screenshot got no screencast frame within 5 s. The public path engages focus emulation around a picture act; the pilot path did not, and a background headless tab paints no frame without it. The pilot path now engages it too, and the fake-browser picture-pilot test asserts that every capture runs under focus emulation. The passing run used a build of 06bffcd plus that fix, which lands in the same commit.
