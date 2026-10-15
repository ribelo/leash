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

## Out of Scope

A JavaScript wait condition, API-discovery helpers, a client library.
