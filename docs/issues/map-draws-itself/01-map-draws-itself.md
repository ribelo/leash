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

3. As a runner, I want a compile triggered after a drive ends `done` on a site, when the store holds at least `successes` `done` traces whose page-kind paths match (same kinds in the same order, ignoring repeats and `unknown`) and no installed procedure covers that path, so that the trigger is evidence, not a timer. ^map-cnee
4. As a runner, I want the planner given the matching traces (page-kind path, each step's kind, operation, target role and name, typed text as `{arg}` candidates, outcome), the site's existing playbook if any, and the checker vocabulary, and asked for one procedure in the playbook schema — goal steps in human language naming roles and labels not indices, expectations from the vocabulary with at least `the page is <kind>` after each navigation, args for every typed value that differed between traces — so that the draft is written in the language JEV drives. ^map-bjon
5. As a runner, I want the compiled procedure validated fail-closed by the playbook loader (the same rules as an authored one: goal steps present, args declared, expectations resolvable), a draft that fails validation retried once with the errors shown and then dropped with the reason logged, so that a draft is always a valid procedure. ^map-6xcy
6. As a runner, I want a draft to carry provenance — the trace files it was compiled from, the planner model, the time, `tries`, `last_failure` — in the proposal file, so that a procedure's origin is readable. ^map-6m3c
7. As a runner, I want a site with no playbook to receive a draft *playbook* (site, entry = the first trace's start URL, inferred `pages`, the compiled procedure), so that the first map of a site is also drawn by itself. ^map-2l5q

### Try and install (`auto`)

8. As a runner, I want, in `auto`, the procedure level offered the site's drafts alongside installed procedures (marked `draft:` in the option's description) when their path matches the mission's current page kind, so that a draft is tried exactly where it was compiled for. ^map-tval
9. As a runner, I want a draft that JEV chose and that passed its expectations installed at the end of a `done` mission — merged into the site's playbook by the `playbook accept` path, inferred `pages` promoted to declared — and reported in the drive reply as `installed: [slug]`, so that the site verifies the map. ^map-rz4w
10. As a runner, I want a tried draft that failed its expectations to stay a draft with `tries` incremented and `last_failure` set, dropped after `learning.max_tries` (default 3), so that a bad guess cannot be tried forever. ^map-igfx
11. As a runner, I want `draft` mode to compile and write proposals but never offer them to JEV, and `off` to do neither, so that the three states are exactly as named. ^map-2ga3

### Repair

12. As a runner, I want an installed procedure that fails its expectations twice (the existing planner trigger) to produce a *repair* draft — the planner given the failing trace, the procedure, and the current page — kept beside the installed one, so that a broken map is diagnosed where it broke. ^map-ptnk
13. As a runner, I want, in `auto`, the repair draft tried on the next matching mission and, on success, to *replace* the installed procedure (same slug, provenance updated, the old one kept in `proposed/retired/`), so that the map heals and the history stays. ^map-lnwr
14. As a runner, I want an installed procedure that fails `learning.retire_after` (default 5) consecutive missions with no successful repair to be retired (removed from the playbook, kept in `retired/`) so that JEV falls back to driving on the fly rather than choosing a dead procedure, so that a stale map does not trap the agent. ^map-h5ym

### Luna hands back

15. As a runner, I want the planner's answers extended with `continue` — "I have acted (navigated, dismissed, filled); resume the operator from the current page" — carrying an optional list of operator-level actions the planner performed through the same action path (never raw JS), so that Luna can hand control back to JEV instead of only writing a procedure or ending. ^map-7xrq
16. As a runner, I want the planner's actions under `continue` bounded (at most `learning.planner_actions`, default 5, each a protocol action on a snapshot row chosen by the planner from the current snapshot's rows) and recorded in the trace as planner steps, so that Luna acting is as safe and as visible as JEV acting. ^map-3qag

### Drive is the way

17. As an agent, I want `drive --tab HANDLE` to work in that tab and leave it open, and `drive` without `--tab` to open a tab and close it at the end whatever the outcome (a handoff keeps it until resume), pinned by a test, so that a mission never takes over an unrelated tab. ^map-puhi
18. As an agent, I want the skill and the orientation to say: prefer `drive` for any task that is a goal (it learns; manual commands do not), use manual commands for inspection and for steps `drive` cannot do, so that agents reach for the learning path. ^map-4fga

### Proof

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
