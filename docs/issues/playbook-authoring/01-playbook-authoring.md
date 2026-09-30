---
status: ready-for-agent
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
