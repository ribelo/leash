---
status: completed
milestone: 10
---

# Authoring playbooks: the skill teaches an agent to write one

## Problem Statement

In nine cases out of ten a playbook will be written by a coordinating agent given an instruction like "make a playbook for Allegro so I can manage my shop" — not by Luna inside Leash. The bundled skill covers using Leash and inspecting playbooks, and says nothing about writing one: what a procedure is, how to name page kinds, when a step is a goal and when a script, how to write an `expect` that resolves to a checker, where args come from. An agent reading it today would write what the books example was. Nema's skill is the model: what the tool is, how to use it, and how its artefacts are shaped.

## Solution

A fifth reference, `skill/references/authoring.md`, written as a procedure an agent follows from "study the site" to "live run", with the rewritten books example as its worked case, verified by an agent that knows only the skill writing a playbook for a second site and driving it.

## User Stories

1. As an agent, I want `authoring.md` to open with what a playbook is in five lines (site, entry, page kinds, procedures with goal steps JEV drives, scripts as JEV's tools, expectations checked by code), so that I know the shape before the steps. ^auth-cv0y
2. As an agent, I want the authoring procedure in order: study the site with `snap`, `text`, `net` on the pages the task touches; name the page kinds and their URL patterns or text markers; write each procedure's goal steps in plain language; add a script only where bulk reading or a file is needed and write its `returns` beside it; declare every arg with its source; write `expect` sentences from the checker vocabulary; `playbook check`; `playbook test` each script on a real page; a `--dry-run` mission; a live mission with `--out`; read the trace — so that I do it in the order that catches mistakes earliest. ^auth-m5ho
3. As an agent, I want the checker vocabulary listed with one example each ("the page is <kind>", "the page shows <text>", "a file was downloaded", "no dialog is open", "a <role> named <text> is present") and the note that any other sentence falls through to a JEV score question, so that I write expectations code can verify. ^auth-47fd
4. As an agent, I want the rules stated as rules — every procedure has a goal step; a script declares `pages`, `description`, `returns`, its args; a procedure's `expect` names the page kind it lands on; payment, messaging and deletion never sit inside a `repeat` or a retried procedure — so that `playbook check` refusals are not surprises. ^auth-249z
5. As an agent, I want the worked example to be the rewritten books.toscrape.com playbook shown in full with a sentence on each choice, so that I can copy its shape. ^auth-ovd4
6. As an agent, I want a short section on how the mission sentence reaches args (the text helper fills `{category}` from "collect every book in Mystery") with the advice to name args as the user would say them, so that missions and playbooks meet. ^auth-avng
7. As a maintainer, I want the reference verified: an agent that knows only the installed skill (`subagent_claude_sonnet`) is asked to write a playbook for automationexercise.com covering search, open product, add to cart, view cart (stopping before checkout), and to drive one mission through it; its transcript and every point where the reference failed it are recorded, and the reference fixed, so that the skill is proven on the case the operator described. ^auth-v3sc
8. As a maintainer, I want `SKILL.md` to point at `authoring.md` in one line under the missions bullet, and the `leash` skill's description to mention writing playbooks, so that the reference is found. ^auth-75l0

## Implementation Decisions

- The reference is written after `playbook-scripts` lands; it documents that format only.
- Written in the style of the existing references: rules and tables, no prose padding, under 200 lines.

## Testing Decisions

- Story 7 is the test.

## Out of Scope

Discovery (Luna writing playbooks) — kept, deprioritised, mentioned in one line as "exists; propose-and-accept".

## Verification (auth-v3sc), 2026-10-01

A fresh `subagent_claude_sonnet` session, told to use only the installed skill (Leash c263971, skill current) and not the Leash checkout, wrote `automationexercise.com` from scratch (search, open product, add to cart, view cart, stop before checkout), installed it, tested both scripts, dry-ran and drove it on the installed service.

- Live run 1: `blocked` — the search goal started on the home page, which has no search box; ten scroll/BLOCKED steps, 16 calls, $0.0015, 13.8 s.
- Live run 2 after its fix (a "Open the Products page" goal with `until` first): `done`; `search-product`, `open-product`, `add-to-cart`, `view-cart`, `add-product-to-cart` all verified on attempt 1; one `script-record` (`read-cart`: Blue Top, Rs. 500, quantity 1); 22 calls (operator 16, text helper 3, procedure 2, playbook 1), $0.0029, 20.5 s. The agent confirmed the cart independently with `text`/`snap` and never clicked checkout.

Where the reference failed it (22 points reported), and what changed:

| Finding | Fix |
| --- | --- |
| "Every playbook has a procedure with a goal step" read as playbook-level; the loader applies it per procedure, and the refusal carried the `script-invalid` hint about returns shapes | Rule restated per procedure; new error code `playbook-invalid` (exit 65) for load/check/accept refusals, with its own hint (protocol, errors table, cram) |
| Composition of a multi-stage task never explained; how procedures are chosen unknown | New "Composing a task" section: one procedure per stage, chosen one at a time on `description`, all but `repeat.next` helpers stay choices |
| Dry run reads `blocked`, does not open `--url`, cannot catch a control on another page | Stated in step 9 |
| Goals run wherever the tab is | Stated in step 3, with the navigation-goal-plus-`until` pattern |
| A BLOCKED trace was hard to read | Step 10 names the pattern (scrolls alternating with BLOCKED near 0.5) and what it means |
| `until` before any action undocumented | "checked only after an action" |
| `snap`/`--match` are viewport-scoped; `text` is CSS-rendered and `wait --text` case-sensitive; unnamed controls | Step 1 |
| JS dialog vs HTML modal for `no dialog is open` | Checker table |
| Add-to-cart replay | Rule on mild repeatable actions |
| Empty list validity; `url_pattern` wildcard semantics | Steps 8 and checker section |
| Source pointer into the checkout | Removed; the complete example is in the reference |

Not changed here: consent-banner handling (the site showed none), mission-argument quoting (worked), string vs number prices (author's choice), `text`/`snap` title lag and a one-off `shot` timeout (browser reference / L48 territory).
