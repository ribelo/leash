---
status: completed
category: enhancement
---

# Leash uses the compiler-backed capability gate

## Problem Statement

Ox row 90 replaced the Semgrep capability gate with compiler-backed `ox-lint`.
Leash still pins the older gate and installs Semgrep. The new source tier runs
without build artefacts, but its typed tier cannot decide Leash modules without
fresh local `.cmt` evidence and matching CMI fingerprints.

## Solution

Install the new gate with the Ox row-90 installation and authority-flow fixes,
and make a local build a real precondition of the capability gate.

## User Stories

1. As a Leash contributor, I want the pinned Ox revision and shell package list to install `ox_lint` without Semgrep, so that the installed capability gate uses the pinned compiler. ^capslint-hy68
2. As a Leash contributor, I want the capability gate to build first and require fresh typed evidence, so that missing or stale evidence cannot silently pass. ^capslint-i4ed

## Implementation Decisions

- Pin Ox to `d798268590c1b8f81924a7ecc1663dbe33ff3772`, including the row-90 installation and authority-flow fixes; add `ox_lint` to the existing Ox opam package list and remove only Semgrep from shell dependencies (upstream story `ncapslint-ebh6`).
- Install the executable in the opam `bin` section: `share` strips its executable bit. Rule pages and fixtures remain in `share/ox_lint`; the installed launcher resolves the sibling prefix's `bin/ox-lint`.
- Keep the installed launcher and its exit codes; the local wrapper runs `dune build @install @check` before requesting the typed tier.
- `@check` produces typed evidence for executable modules that `@install` omits, without changing executable modes or installation targets.
- Keep both build-only generator allowances with their existing reasons.
- Document the mandatory artefact-free source tier and the build-dependent typed tier in contributor gate guidance.

## Testing Decisions

- Run the installed launcher before the build to record undecided modules, then run the wrapper after a build and require zero undecided modules (`capslint-hy68`, `capslint-i4ed`).
- Run the prescribed build, test, formatting and capability gates, capturing each command's own exit code directly.
- Stop and report any capability finding rather than changing application code or adding allowances.

## Out of Scope

Application code changes, new allowances, other consumer repositories, changes to Ox, and live Chrome acceptance.

## Acceptance Evidence

- The initial row-90 revision installed the executable under `share` with mode 0644; the launcher exited 2 before scanning. The final installed executable is under `bin`, mode 0755, and its self-check passes (28 rules, exit 0).
- At the intermediate `c03cbf9` revision, the pre-build gate reported `0 findings; 73 modules with typed rules undecided (typed evidence required)` (exit 2). An install-only build left five undecided CLI/helper modules and two playbook reader signature findings. The latter were confirmed and fixed upstream as optional-tuple authority-flow false positives; no application source or allowance changed.
- `@check` removed the five missing executable annotations. Temporary byte-target reshaping was reverted; the native executable and installation targets are unchanged.
- At the final `d798268` revision, before rebuilding Leash, the installed gate reported `0 findings; 44 modules with typed rules undecided (typed evidence required)` (exit 2), because imported CMI fingerprints had changed.
- After `dune build @install @check`, the local build-first wrapper reported `0 findings; 0 modules with typed rules undecided (typed evidence required)` (exit 0).
- Final mandatory command exits were captured directly, without pipelines:

  | Command | Exit |
  | --- | --- |
  | `nix develop -c dune build @install @check` | 0 |
  | `nix develop -c dune test` | 0 |
  | `nix develop -c dune build @fmt` | 0 |
  | `nix develop -c scripts/caps-gate` | 0 |

- Tests passed: 405 cases across 34 Alcotest suites. Wrapper syntax, story-ID validation (425 IDs), and `git diff --check` also exited 0.
