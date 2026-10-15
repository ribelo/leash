---
status: completed
milestone: 17
---

# Eval is the one script command

## Problem Statement

ADR-0017. Agents write programs that collect data from logged-in sites with their own JavaScript. `eval` capped results at 64 KiB and every call at 30 s, and reported the overrun as `renderer-unresponsive`. `script run` had 8 MiB results but string-only arguments, a returns-shape check from the playbook era, and was a second way to do the same thing.

## User Stories

1. As an agent, I want one `leash eval` command that takes the body inline or from `--file PATH` and the argument from `--argument JSON` or `--argument-file PATH`, with `script run`, its returns shapes, its string arguments and `--out` removed, so that there is one way to run my JavaScript. ^evl-gign
2. As an agent, I want `--timeout-ms` (default 30000, at most 600000) to be the deadline of the call, and the listener budget to follow it, so that a body can wait inside the page or page through a long list in one call. ^evl-iskk
3. As an agent, I want a call that ran out of its deadline while the page still answers to be `script-timeout`, and `renderer-unresponsive` only when the page does not answer a probe, so that I do not retry a hang that is not one. ^evl-i702
4. As an agent, I want the body bounded at 1 MiB and the argument and result at 8 MiB each, with the control listener and the CLI sized for them, so that internal API replies fit. ^evl-p515
5. As an agent, I want `leash help eval`, the skill, the protocol, the error table and the glossary to describe this, so that I do not use the removed command. ^evl-agmn
6. As the operator, I want the build installed on this machine and checked on real Chrome (a body longer than 30 s, a result over 64 KiB, a timeout, a disconnected client), so that the programs that use Leash get it. ^evl-zcj0

## Further Notes

Live check, 2026-10-15, build 7cc840f (`nix build .#leash`) as an isolated headless instance on its own socket and profile, real Chrome 154, https://example.com (evl-zcj0):

- a 35 s body from `--file` with a 300 KB `--argument-file`, `--timeout-ms 60000`: value returned after 35.0 s;
- a 3 MiB result: returned; a 9 MiB result: `too-large`;
- a 10 s promise with `--timeout-ms 3000`: `script-timeout` after 3.0 s, `detail.timeout_ms` 3000;
- `while (true) {}` with `--timeout-ms 3000`: `renderer-unresponsive` after 7.0 s (deadline, then a failed probe);
- a client killed 3 s into a 60 s body: the next eval on the tab answered in 4 ms; an in-page `fetch` of the page's own URL answered 200.

The development switch (`~/.cache/opam/5.4.0+ox`) holds Ox master c034d4f, which Leash's pinned Ox 2206bec does not build against. The four gates ran in a copy of the tree with Ox 2206bec vendored (`(vendored_dirs vendor)`) and `OX_LINT` set to that Ox's ox-lint. nixos-config 4b94c40 pins this build; it is installed with `nixos-rebuild switch`.

## Out of Scope

A JavaScript wait condition, API-discovery helpers, a client library.
