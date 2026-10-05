# Browser: rows and pictures

## Observe, choose, act, verify

Use rows when they identify the desired control; row actions revalidate the snapshot. For canvas, VNC, Wiser or a streamed browser with no useful rows, use `leash snap TAB --with-image` and read its PNG before choosing a point. Coordinates are first-class: no row lookup or point-to-row conversion is required.

The snapshot carries each row's viewport-CSS box, or null when unavailable. Its image reports PNG width/height, CSS viewport and scale factor. Map PNG pixels to CSS by dividing by the reported scale. Never multiply input coordinates by devicePixelRatio; a 2× image does not double CSS input. Do not use off-viewport points from a full-page PNG.

```sh
leash snap TAB --with-image
leash click TAB --at 120,80 --shot
leash dblclick TAB --at 120,80 --shot
leash scroll TAB --at 120,80 --dy 360 --shot
leash drag TAB --from 120,80 --to 260,160 --shot
leash type TAB --stdin --shot
leash press TAB Enter
```

Points may be fractional CSS values. Wheel deltas are signed CSS pixels, positive down. `type` inserts bounded literal text into the already-focused control; stdin and `--file PATH` retain protected text transport. `press` is unchanged. Never mix point input with row/snapshot arguments.

## Read evidence honestly

Pointer replies retain a before PNG and native hit evidence; `--shot` requests an after PNG. Focused type has only optional after evidence. The requested fractional point and floored native hit-test sample are separate. A hit may be empty; a canvas or stream host is not an identified drawn control. Images and dispatch are not authorization or proof of completion. Inspect the resulting page or artifact independently and never repeat an uncertain action. Dialogs are never automatically answered.

## Image-aware missions

The pilot receives real PNG image parts automatically when no useful rows are available, and can explicitly request `observe --image`. Observation consumes a bounded turn but sends no input. Measured viewport/scale remains in its text facts; private image paths do not. Pilot actions include `click_at`, focused `type` and `drag` under existing deadlines, action limits, protected secrets, dialog and consequential-action policies. The CLI spelling remains `click --at`. JEV navigation legs are unchanged.
