---
status: ready-for-agent
milestone: 12
---

# The map draws itself: compile, try, install, repair

## Problem Statement

Every mission on a new site pays full JEV price forever, and the only playbooks that exist are hand-written. The operator wants playbooks created and maintained automatically — he will not review them — and sites change, so installed procedures must repair themselves. ADR-0011 sets the rule: compile from successful traces, verify on the live site, install what worked, repair what failed. Three configured states: `off`, `draft`, `auto`.

## Solution

After a drive on a site, if `learning.mode` is not `off` and the site's trace store holds `learning.successes` (default 2) successful traces sharing a page-kind path not covered by an installed procedure, the planner compiles a draft procedure (and, with no playbook yet, a draft playbook with inferred `pages`). In `draft`, it is written to `proposed/` and reported. In `auto`, the next matching mission on that site tries the draft as a procedure; success installs it (merging into the site's playbook); failure keeps it as a draft with the failure attached for the next compile. When an installed procedure fails its expectations twice, the planner's repair answer replaces it only after the repaired procedure succeeds. The planner gains `continue` so Luna can act and hand back to JEV.

## User Stories

### Configuration

1. As the operator, I want `[learning] mode = "off" | "draft" | "auto"` (default `draft`), `successes = 2`, `planner_model` and `planner_reasoning` (defaults `openai/gpt-6-luna`, `max`), so that the behaviour is one setting and the model one more. ^map-0by0
2. As the operator, I want `leash status` to report the learning mode, the number of drafts waiting, and the last compile per site, so that the system's learning state is visible in one place. ^map-w62c

### Compile

3. *(Retired 2026-10-02, replaced by map-op01–map-op05: whole-path matching compiled footprints, not operations.)* ~~As a runner, I want a compile triggered after a drive ends `done` on a site, when the store holds at least `successes` `done` traces whose page-kind paths match … ^map-cnee~~

#### Operations, not missions (operator review 2026-10-02)

30. As a runner, I want every successful trace segmented at page-kind transitions into *operations* — the steps taken on one page kind that end where the next kind begins or the mission's result is read (search-place, open-place-details, set-dates, read-prices, add-to-cart) — each recorded with its entry kind, exit kind, steps (operation, target role and label, typed text) and the mission arguments that fed them, so that the unit of learning is something a user would ask for again in another mission. ^map-op01
31. As a runner, I want each operation compiled as its own procedure with its own args and `expect` (exit kind plus the operation's result), and a mission then run as a chain of installed procedures JEV picks one at a time, so that a map is a set of reusable moves, not one replay of one mission. ^map-op02
32. As a runner, I want agreement and the compile trigger judged per operation across traces — for repeatable operations, the same entry and exit kinds and compatible distinct (operation, role) sets, ignoring order and repeated scrolls, with optional click/scroll/wait extras allowed only if all type_text/select role pairs remain present; labels generalize supplied arguments, typed values, date/number/currency fragments and are compiler evidence, not equality identity; for non-repeatable operations, the original ordered operation and exact role+label agreement with only typed text differing — not per whole path, so that two Maps runs that both search and open a place agree on those operations even when their URL sequences differ. ^map-op03
33. As a runner, I want the compiler to name each page kind from the page — its title and visible content (`flights-explore`, `maps-place`, `consent`) — and write that name with the generalized URL pattern into `pages`, never a URL-derived name like `travel-slug` or `m`, so that JEV and a reader understand the map. Traces keep the inferred URL-shape key; the compiler maps it to the named kind. ^map-op04
34. As a runner, I want a compiled playbook's `entry` to be the first URL after any consent or interstitial was cleared, never a consent redirect, so that a fresh agent starts on the site. ^map-op05
37. As a runner, I want the compiler to emit declared-return read-only collection scripts alongside repeatable procedures, the loader to refuse navigation, submission, input/event, network, storage and dynamic-code references, and installation to require JEV selecting the draft, every script actually succeeding, and non-empty passing expectations, so that titles/prices become structured data rather than a bare DONE. Manual acceptance cannot bypass this replay gate. ^map-op08
38. As a runner, I want every done collection trace to retain a final-page tag/class skeleton of repeated containers bounded to 4096 bytes, without text nodes, attributes, field values or URLs, and the compiler to receive that structural_outline, so that it writes extraction selectors from observed structure without keeping page text or secrets. ^map-op09
35. As a maintainer, I want no compiled procedure installed with fewer than two goal steps unless it is a `use:` sub-procedure (L46's loader rule), so that a single click is not mistaken for a map. ^map-op06
4. As a runner, I want the planner given the matching traces (page-kind path, each step's kind, operation, target role and name, typed text as `{arg}` candidates, outcome), the site's existing playbook if any, and the checker vocabulary, and asked for one procedure in the playbook schema — goal steps in human language naming roles and labels not indices, expectations from the vocabulary with at least `the page is <kind>` after each navigation, args for every typed value that differed between traces — so that the draft is written in the language JEV drives. ^map-bjon
5. As a runner, I want the compiled procedure validated fail-closed by the playbook loader (the same rules as an authored one: goal steps present, args declared, expectations resolvable), a draft that fails validation retried once with the errors shown and then dropped with the reason logged, so that a draft is always a valid procedure. ^map-6xcy
6. As a runner, I want a draft to carry provenance — the trace files it was compiled from, the planner model, the time, `tries`, `last_failure` — in the proposal file, so that a procedure's origin is readable. ^map-6m3c
7. As a runner, I want a site with no playbook to receive a draft *playbook* (site, entry = the first trace's start URL, inferred `pages`, the compiled procedure), so that the first map of a site is also drawn by itself. ^map-2l5q

### Try and install (`auto`)

8. As a runner, I want, in `auto`, the procedure level offered the site's drafts alongside installed procedures (marked `draft:` in the option's description) when their path matches the mission's current page kind, so that a draft is tried exactly where it was compiled for. ^map-tval
9. As a runner, I want a draft that JEV chose and that passed its expectations installed at the end of a `done` mission — merged into the site's playbook by the `playbook accept` path, inferred `pages` promoted to declared — and reported in the drive reply as `installed: [slug]`, so that the site verifies the map. ^map-rz4w
23. As a runner, I want the compiler to classify each compiled procedure `repeatable` or `non-repeatable` from its page-kind path and operations — a `submit`/`press Enter`/click on a page kind whose name or observed text marks payment, checkout confirmation, upload, posting, sending or deletion is non-repeatable; everything else is repeatable — recorded in the draft's provenance with the reason, so that the gate that applies is decided before any try. ^map-yzqp
24. As a playbook author, I want a playbook's `pages` entries to accept `"repeatable": false` (and the compiler to honour it over its own classification), so that a site's irreversible pages can be pinned by hand when the inference is wrong. ^map-wm4v
25. As a runner, I want a `non-repeatable` draft never offered to JEV as a try and never replayed; instead, when `successes` independent `done` traces agree — same page-kind path, same operation and target role+label at each step, only typed text differing — the planner is shown the agreement and asked to confirm the generalization, and on confirmation the draft is installed with provenance `gate: agreement`, so that an order or an upload procedure is installed on evidence that cannot come from a second order. ^map-nh2e
26. As a runner, I want repair of a `non-repeatable` procedure to replace the installed one when the planner's repair agrees with the failing trace's observed page (the page kinds and the rows it would act on exist in that trace's snapshot), with provenance `gate: agreement-repair`, and never by re-running the mission, so that a broken checkout procedure heals without a second checkout. ^map-itbt
27. As a runner, I want `repeatable` drafts and repairs to use the replay gate exactly as stories 8–10 and 13 describe, with provenance `gate: replay`, so that both gates exist and each procedure says which installed it. ^map-pd0q
28. As the operator, I want `leash playbook show` to display each procedure's gate and provenance, and `status` to count installed-by-replay and installed-by-agreement per site, so that how the map was verified is visible. ^map-b3kk
29. As a maintainer, I want the live loop (story 19) extended with a non-repeatable case on a harmless site — a form whose submit is recorded by the test server, run twice with different values — showing the agreement gate installing without a third submit, so that gate B is proven as gate A is. ^map-fxra
10. As a runner, I want a tried draft that failed its expectations to stay a draft with `tries` incremented and `last_failure` set, dropped after `learning.max_tries` (default 3), so that a bad guess cannot be tried forever. ^map-igfx
11. As a runner, I want `draft` mode to compile and write proposals but never offer them to JEV, and `off` to do neither, so that the three states are exactly as named. ^map-2ga3

### Repair

12. As a runner, I want an installed procedure that fails its expectations twice (the existing planner trigger) to produce a *repair* draft — the planner given the failing trace, the procedure, and the current page — kept beside the installed one, so that a broken map is diagnosed where it broke. ^map-ptnk
13. As a runner, I want, in `auto`, the repair draft tried on the next matching mission and, on success, to *replace* the installed procedure (same slug, provenance updated, the old one kept in `proposed/retired/`), so that the map heals and the history stays. ^map-lnwr
14. As a runner, I want an installed procedure that fails `learning.retire_after` (default 5) consecutive missions with no successful repair to be retired (removed from the playbook, kept in `retired/`) so that JEV falls back to driving on the fly rather than choosing a dead procedure, so that a stale map does not trap the agent. ^map-h5ym

### Luna hands back

15. As a runner, I want the planner's answers extended with `continue` — "I have acted (navigated, dismissed, filled); resume the operator from the current page" — carrying an optional list of operator-level actions the planner performed through the same action path (never raw JS), so that Luna can hand control back to JEV instead of only writing a procedure or ending. ^map-7xrq
16. As a runner, I want the planner's actions under `continue` bounded (at most `learning.planner_actions`, default 5, each a protocol action on a snapshot row chosen by the planner from the current snapshot's rows) and recorded in the trace as planner steps, so that Luna acting is as safe and as visible as JEV acting. ^map-3qag

39. As a runner, I want Luna to answer done with a nonempty one-line result and nonempty evidence sentences in the existing expectation vocabulary, verified against the live page by the mission checker before a terminal done returns its answer and trace; failed evidence consumes that planner turn and continues the bounded loop, while notify remains non-terminal, so that a result read from a cafe or flight page can end a mission without a new procedure. ^map-op10

40. As the operator, I want planner and operator accept-all, agree-to-all and allow-all consent clicks refused when the same snapshot offers reject, decline or necessary-only, with the refusal reason shown to JEV and the decline choice still clickable, including Accept all / Reject all and Zaakceptuj wszystko / Odrzuć wszystko, so that consent defaults to decline even when a mission asks to accept. ^map-op11

### Drive is the way

17. As an agent, I want `drive --tab HANDLE` to work in that tab and leave it open, and `drive` without `--tab` to open a tab and close it at the end whatever the outcome (a handoff keeps it until resume), pinned by a test, so that a mission never takes over an unrelated tab. ^map-puhi
18. As an agent, I want the skill and the orientation to say: prefer `drive` for any task that is a goal (it learns; manual commands do not), use manual commands for inspection and for steps `drive` cannot do, so that agents reach for the learning path. ^map-4fga

41. As a runner, I want an action whose operation and target leave the page unchanged removed from the next JEV prediction on that page until the page changes, while other targets and operations remain available, so that repeated Rating clicks cannot consume the mission on the same ineffective action and the guard is an action-space mask, not only a stall counter. ^map-op12

### Proof

36. As the operator, I want the live gates to use missions a user would actually ask, four per site varying the arguments not the task — Flights: "find the cheapest flight from Warsaw to Lisbon next month and tell me its price and dates" (then other city pairs/months); Maps: "find the Eiffel Tower, then find a cafe near it with a rating over 4 and give me its name and address" (then other landmarks); books: collect a category's titles and prices (other categories) — and the acceptance criterion to be: a fresh agent, given only the installed playbook, completes a fifth mission with different arguments at lower cost than mission one — not that a procedure was installed. The installed playbooks are recorded in full in this spec. ^map-op07

19. As a maintainer, I want a live test on books.toscrape.com starting with no playbook: two on-the-fly missions, a compile, a third mission in `auto` that tries and installs the draft, a fourth that uses the installed procedure at lower cost — with JEV calls and cost per mission recorded, so that the loop is shown end to end on a site built for it. ^map-4lw2
20. As a maintainer, I want the same loop on two non-critical real sites (Google Flights and Google Maps, or two others of the operator's choosing) with the compiled playbooks and their cost curves recorded, so that inference and compile are seen on real page shapes. ^map-ngyr
21. As a maintainer, I want a repair test: install the books procedure, change the example site's expectation (a renamed page kind in the test fixture), run until the procedure fails twice, and show the repair replacing it, so that healing is proven. ^map-zz7q
22. As a maintainer, I want `discover` removed as a command, its stories retired, and its spec marked superseded by this one, so that there is one way to explore — driving. ^map-gkww

## Implementation Decisions

- The compiler is a planner turn with a new prompt; output decoded as a playbook procedure (or playbook) by the existing types; validation by the existing loader; writing by `Playbook.propose`.
- Path matching: page-kind lists with consecutive repeats collapsed and `unknown` removed; equality of lists.
- `continue` actions are protocol actions (`click`, `fill`, `press`, `scroll`, `nav` within the site) on rows the planner names by index from the snapshot it was shown; the same revalidation as any action.
- Install/replace/retire go through the `playbook accept` code with provenance; `retired/` is under `proposed/`.
- The planner model defaults to Luna at `max` reasoning; the compile prompt and the repair prompt are versioned in `planner.ml`.

## Testing Decisions

- Protocol seam with scripted traces and a fake planner for compile/try/install/repair/retire and the three modes; `continue` with scripted actions; the drive tab rule. Live: stories 19–21.

## Out of Scope

Feeding past traces to JEV at run time (rejected, ADR-0011); cross-site procedures; human review tooling.

## Further Notes

Operator, 2026-10-01: automatic means create and install; three config states; Luna at maximum reasoning; `drive` is what agents should use; test on non-critical sites (Google Flights, Google Maps, books.toscrape.com), with Amazon and Allegro as the hard cases. Coordinator's departure, with the operator's trust: install is gated by the site (a draft must drive one mission successfully as a procedure), not by compile — a wrong generalization installed blind would cost every future mission and nobody would see it. Threshold `successes` defaults to 2; set to 1 to compile from a single run.

## Acceptance checkpoint — 2026-10-02 (not complete)

Repository gates pass after independent review repairs: immutable draft revision/page binding, conservative repeatability across repair, authored pins, no planner-mediated unsafe replay, complete agreement target checks, draft dry-run, and locked acceptance. Learning costs are included in mission and durable trace totals.

- **Replay gate passes on Books:** four missions, total costs $0.000434154, $0.000954754, $0.000281820, $0.000282366. Mission 2 compiled; mission 3 selected and verified the draft then installed; mission 4 used the installed procedure. [Evidence](acceptance/live-2026-10-02/README.md).
- **Agreement gate passes on a harmless form:** two independent submissions, alpha-test and beta-test, and exactly two server writes after browser shutdown. Agreement installed without a third submission; 9 total model calls, $0.001727862 including compilation. Explicit-port preservation fixed the earlier validation failure. [Evidence](acceptance/live-2026-10-02-form-final/README.md).
- **Maps remains failed:** successful page goals produced inconsistent page-kind paths, and ambient safety detection marked search actions non-repeatable. No compilation occurred. Strict agreement has not been weakened.
- **Flights remains failed:** mission 2 hit a covered click point; destination prices were not loaded. The harness originally mistook the PLN currency selector for a priced result; the report corrects that false positive.

The required two-Google-site learning curves and real-site repair evidence remain open. L53 is not complete; L55/L54 have not started. Failure-history counters are still per-site/per-slug and are not cross-process transactions.
