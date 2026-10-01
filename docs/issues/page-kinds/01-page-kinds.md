---
status: ready-for-agent
milestone: 12
---

# Page kinds are inferred

## Problem Statement

Page kinds are the semantic state the upper JEV levels decide on (measured: page kind + recent procedures 4/5; raw URL 2/5). Today they exist only when a playbook declares them. On a site with no playbook — the starting condition of every new site — JEV sees a raw URL, and a trace has no page-kind column, so there is nothing to compile a procedure on.

## Solution

With no playbook, Leash infers a page kind from the URL's shape (path segments with ids and numbers generalized: `/oferta/<id>`, `/listing`, `/cart`) and the title's stable part, stable within a session, shown to JEV in place of the URL, recorded in the trace, and offered to the compiler as the draft's `pages` section.

## User Stories

1. As a runner, I want a page kind inferred for any page without a declared kind: the URL path with numeric and hex segments and UUIDs replaced by `<id>`, query stripped, plus the title with the site name and any trailing counters removed, named like `oferta-<id>` or `listing`, so that every page has a semantic label. ^kind-a7uy
2. As a runner, I want inferred kinds stable within a session (the same shape maps to the same name) and the mapping recorded in the trace header, so that a path reads as `[home, listing, oferta-<id>, cart]`. ^kind-dnye
3. As a runner, I want the operator and procedure levels' state to carry the inferred kind where a declared one would go, with the measurement of story 18 of `run` repeated on one site without a playbook (inferred kinds vs raw URL, five states), so that the substitution is evidence. ^kind-ir9l
4. As a maintainer, I want a declared kind always to win over an inferred one on the same page, and an inferred kind never to be written to a playbook except by the compiler as a proposal, so that playbooks stay authored or compiled, never accreted. ^kind-4qke
5. As a maintainer, I want the inference to be a pure function with table tests over twenty real URL/title pairs from Allegro, Amazon, Google Flights, Google Maps and books.toscrape.com, so that the shapes it produces are seen. ^kind-jdcs
6. As an agent, I want `list` and `snap` to show the page kind (declared or inferred, marked which), so that a page's kind is visible outside a drive. ^kind-tdrv
7. As a maintainer, I want the compiler to receive the inferred mapping as the draft's `pages` with URL patterns generalized from the observed URLs, so that a compiled playbook has the vocabulary it needs on day one. ^kind-s1k2

## Implementation Decisions

- Inference: path segments matching `^[0-9]+$`, `^[0-9a-f]{8,}$`, UUIDs → `<id>`; segments longer than 40 chars → `<slug>`; title split on ` - `, ` | `, ` — `, drop the part equal to the site name.
- Names are the last meaningful path segment plus `<id>` markers; collisions get a numeric suffix within the session.

## Testing Decisions

- Pure tables (story 5); protocol seam for `list`/`snap` fields; the measurement (story 3) recorded in the spec.

## Out of Scope

Learning kinds across sessions (the compiler persists them into a playbook instead).
