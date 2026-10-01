---
status: ready-for-agent
milestone: 12
---

# Drive is the default: hard-site acceptance

## Problem Statement

The learning loop is proven on sites built for it. The operator named the hard cases: Amazon and Allegro — consent dialogs, A/B layouts, anti-bot pages, variable first-result pages. If the map draws itself there, it draws itself anywhere.

## Solution

Headed, on the operator's desktop, with the operator present for CAPTCHAs: the learning loop on Allegro (search, open offer, add to cart, view cart — never pay) and on Amazon (search, open product, read price — never add to cart or pay), each from no playbook, recorded.

## User Stories

1. As the operator, I want the Allegro loop run headed on my desktop with me present: two on-the-fly missions, compile, try-and-install, a fourth mission on the installed procedure, with every CAPTCHA or login handed off to me and the handoffs counted, so that the hard case is seen with the human in the loop where the design puts them. ^dflt-uq7d
2. As the operator, I want the Amazon loop likewise, read-only (search, open, read a price), so that a second hard site with a different shape is covered. ^dflt-rjaf
3. As a maintainer, I want the compiled playbooks for both sites committed under `examples/playbooks/` with their provenance, so that they are the worked examples for hard sites. ^dflt-q2nf
4. As a maintainer, I want every failure during the runs diagnosed to its cause and filed as a hardening story (not fixed by rewording), so that the hard sites improve Leash rather than the mission text. ^dflt-mzfn
5. As the operator, I want the cost curve per site (mission 1 → 4) in the spec, so that 'cheaper the second time' is a number. ^dflt-yivj
6. As a maintainer, I want the on-the-fly inferred page kinds on both sites compared to what a human would name them, in a table, so that the inference's quality on real sites is recorded. ^dflt-b64h
7. As the operator, I want nothing bought, added to a cart on Amazon, or submitted beyond Allegro's cart, enforced by the mission expectations and checked by me after, so that the hard-site runs are safe. ^dflt-zbfx

## Implementation Decisions

- Operator-present run; the script pauses for handoffs; results pasted into the spec.

## Testing Decisions

- The runs are the test.

## Out of Scope

Fixing site-specific issues in the runs themselves (they become stories).
