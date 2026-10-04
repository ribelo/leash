# Coordinate actions are first-class

On 2026-10-05 the operator withdrew the coordinate prohibition introduced by the first agent session on 2026-09-26: it was never the operator's decision. Streamed remote browsers (including AWS AgentCore and Wiser's browser pane), VNC-style applications and canvas pages expose a picture, not DOM rows for the controls inside that picture. Restricting actions to rows makes these screens inoperable.

Decision: **coordinates are first-class action targets, alongside revalidated rows.** Prefer rows when they name the intended control; use screenshots and coordinates when the page is a picture. Coordinate actions dispatch the requested point directly, not a point-to-row lookup followed by a row action.

- Row-targeted actions retain their snapshot and element revalidation.
- Coordinates are viewport CSS pixels. Screenshot replies report the viewport, image dimensions and scale so image points can be converted without a HiDPI guess (L44).
- Coordinate actions record the requested points and what the browser hit-test found: role/label when available, otherwise the actual surface or no element. A canvas or streamed surface hit does not identify the drawn control inside it. Screenshots are action evidence; `--shot` returns a post-action screenshot path. Neither a hit-test nor a screenshot alone asserts that the mission succeeded.
- A mixed-page observation can return an image and row boxes together. The pilot can request an image and receives one when there are no useful rows; its coordinate clicks, focused typing and drags have the same mission bounds as its other acts.
- Existing tab capabilities, navigation policy, dialog policy, authorization for consequential actions and prohibition on uncertain action retries remain in force. Model output still never becomes selectors, shell or JavaScript.

This supersedes ADR-0004's row-only action-target and human-only screenshot restrictions, and the coordinate clause in AGENTS.md. It does not introduce a second row-reference system or weaken row revalidation. L58 specifies the commands and proves the picture workflow first on a local canvas, then through Wiser's streamed browser with the operator present for Okta.
