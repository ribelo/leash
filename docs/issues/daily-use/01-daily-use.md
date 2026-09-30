---
status: ready-for-agent
milestone: 10
---

# Daily use: Leash replaces chrome-cdp

## Problem Statement

Leash is built and unused. The operator wants to stop using the chrome-cdp skill and have agents use Leash instead, installed as a systemd service. Agents will be its main users, so help, errors and exit codes must tell an agent what went wrong and what to do next. Three gaps, verified on 2026-09-30:

- **Errors aren't agent-grade.** With the service down, the CLI prints a raw `Eio.Io Fs Not_found Unix_error (…)` and exits 1. Every service error exits 1 whatever its code. `--help` advertises Cmdliner's default 123/124/125, which Leash does not use.
- **The skill isn't bundled.** It lives only in dotfiles and drifts from the binary.
- **The service isn't installed.** nixos-config does not import Leash, and the API key is not wired.

## Solution

Install Leash through nixos-config like Pie and nema. Give every failure a stable code, a documented exit code and a one-line hint, from the CLI as well as the service. Bundle the skill in the binary with `leash skill install`, after nema's installer. Prove it with an agent that knows only the installed skill, working against the installed service. Then delete chrome-cdp.

## User Stories

### Installed as a service

1. As the operator, I want nixos-config to import Leash's flake and home-manager module, enable it, and wire the OpenRouter key the way Pie's and nema's units do (a wrapper reading `/run/agenix/openrouter-api-key`, failing with a clear message if it's unreadable), so that after one rebuild `leash status` answers healthy with the model key present. ^daily-0tl4
2. As the operator, I want the unit to send OTLP to inn (`otlpEnvironment`), stop cleanly with exit 0, restart on failure with a limit, and log to the journal, so that it behaves like the other services on this machine. ^daily-ki34
3. As the operator, I want the installed service headed by default on the desktop, with the niri window rule left out of this milestone, so that I can see what agents do and decide about placement later. ^daily-a341
4. As an agent, I want `leash status` to report the service version, whether Chrome is up and headed, the browser generation, whether a model key is configured, the tab count and cap, and whether the installed skill matches the bundled one, so that one command tells me whether Leash is usable. ^daily-smli

### Errors an agent can act on

5. As an agent, I want every failure the CLI prints to be one JSON object `{code, message, hint, detail?}` on stderr, including client-side failures (`service-unreachable`, `socket-permission`, `config-invalid`, `usage`), and never raw exception text, so that I can parse every error the same way. ^daily-azxe
6. As an agent, I want every error code to carry a one-line `hint` naming the next action (for example `stale-snapshot` → "run `leash snap TAB` again and use its snapshot id"; `service-unreachable` → "`systemctl --user start leash`, or pass --socket"), so that I recover without reading docs. ^daily-6pde
7. As an agent, I want every error code mapped to a distinct, documented exit code in sysexits style, as nema does: usage and invalid requests 64, stale or invalid data 65, unknown tab or request 66, service or browser or model unavailable 69, internal 70, permission (not-owner, with-human, already-owned) 77, retryable (timeout, tab-cap) 75, command-line parse 124. The agent finalizes the table and records it in `docs/protocol.md`. So that the exit status alone tells me what class of problem I have. ^daily-3bwr
8. As an agent, I want `--help` on every command to show its arguments, one or two real examples, and the exit codes it can return, and top-level `--help` to group commands (tabs, observe, act, network and debug, missions, playbooks, service, skill), so that help is enough to use a command correctly the first time. ^daily-iisr
9. As an agent, I want `leash help errors` to print the full table of codes, exit codes, meanings and hints, so that the error model is discoverable from the binary. ^daily-pb5a
10. As a maintainer, I want a table test asserting that every protocol error code has an exit code, a hint, a row in `docs/protocol.md` and a line in `leash help errors`, and that the CLI never prints non-JSON to stderr on failure, so that no new code can ship without all four. ^daily-u1k2

### The skill, bundled

11. As a maintainer, I want the skill's source in the repository (`skill/SKILL.md` plus `skill/references/`) and embedded in the binary at build time, as nema does with `gen_skill_data`, so that the skill and the binary always match. ^daily-fiwd
12. As an agent, I want `leash skill install [PATH] [--dry-run]` to install the bundled skill into PATH, or with no PATH into the agent skill directories it discovers (the same discovery rules as `nema skill install`), printing one JSON outcome per target (`installed`, `replaced`, `current`, `planned-*`), so that the skill can be installed without copying files by hand. ^daily-yd8s
13. As an agent, I want `leash skill show` to print the bundled SKILL.md, and the installed copy to carry a version stamp (Leash version and commit) that `leash status` compares with the bundled one, so that a stale skill is visible. ^daily-ulmi
14. As the operator, I want the skill rewritten from the current dotfiles version to cover the whole surface as it stands after milestone 9: ownership and the DSH owner; minimize output; the snap → action cycle; dialogs and popups; `eval` and `eval --index`; `net`, `debug`, `cookies`, `storage`; `wait` including long and `--changed-since`; `upload`, `hover`; downloads; handoff and resume; `drive` with and without a playbook, `--out`; playbooks and writing scripts with `playbook test`; the error model and exit codes; when to use `drive`, `eval`, or the raw commands. It should stay short with references for depth, so that one skill replaces chrome-cdp completely. ^daily-v6ez
15. As the operator, I want the dotfiles copy of the leash skill replaced by the installed one (the install target is the dotfiles skills directory), so that there is one source of truth: the repository. ^daily-hdex

### Acceptance and cut-over

16. As the operator, I want an acceptance run in which a fresh agent session that knows only the installed skill works against the installed systemd service and completes: open, snap, fill and click a form; read with `text` and bounded `eval`; find an API call in `net` and read its body; handle a dialog and a popup; download a file; one `drive` mission; and recover from three deliberate failures (service stopped, stale snapshot, not-owner) using only the hints. The transcript and any skill or help changes it forced should be recorded, so that Leash is proven as an agent's tool, not just a test suite. ^daily-9ggi
17. As the operator, I want L28/L18's desktop checks (the handoff raises the window and notifies; Done returns control) run on the installed headed service, with my observations recorded, so that the handoff is proven on my desktop. ^daily-n7on
18. As the operator, I want the chrome-cdp skill deleted from dotfiles after acceptance passes, and every reference to it updated: the screenshot skill, the leash skill, the upstream-sync request list (so a sync doesn't bring it back), and any AGENTS.md. So that agents have one browser tool. ^daily-6c5m
19. As the operator, I want the global and project AGENTS.md files that mention browser inspection to name Leash, so that agents reach for it by default. ^daily-mglh

### Operability

20. As an agent, I want `leash status` to succeed with a clear `service-unreachable` hint when the socket exists but the service is dead, and to distinguish "not installed", "stopped" and "Chrome restarting", so that I never mistake a stopped service for a broken page. ^daily-lqqn
21. As the operator, I want `leash config init` to print where it wrote the file, and `leash config check` to report every problem at once with the config path, so that setup mistakes are fixed in one pass. ^daily-9396
22. As a maintainer, I want the stderr ring from Chrome, the generation-lost log and the journal fields checked once on the installed service (Chrome killed with SIGKILL, service recovers, the log names the cause), so that production failure diagnosis is proven where it will happen. ^daily-9zvz
23. As an agent, I want `leash` with no arguments to print a short orientation (is the service running, how to start, the three commands to begin with) rather than the full manual, so that the first contact is useful. ^daily-k9cs
24. As the operator, I want milestone 10 closed only when every tree it touched is clean, Leash is pushed, and chrome-cdp is gone, so that there is no half-cut-over state. ^daily-l082

## Implementation Decisions

- Exit codes follow sysexits where one fits. The mapping is a single table in the protocol module used by the CLI, `help errors`, and the table test.
- Client-side errors are built in the CLI with the same record type as service errors. The CLI catches connection and decode exceptions at its one entry point.
- The skill embedding reuses nema's approach: a dune generator turns `skill/` into an OCaml module. The installer follows nema's `skill_install` (dispositions, dry-run, JSON outcomes), adapted for capabilities.
- The nixos-config change mirrors nema's unit: the shell-stack pattern, a secret wrapper, and `otlpEnvironment`. The operator rebuilds.

## Testing Decisions

- Control-protocol seam: status fields, error records and hints. CLI tests: exit codes per error class and JSON-only stderr (story 10). Installer: dispositions against a temporary directory, as nema's test does.
- Live: story 16 is an agent-run acceptance recorded in the spec; story 17 is the operator's; story 22 is on the installed service.

## Out of Scope

The niri window rule; making the repository public; new browser capabilities (iframes, raw CDP).

## Further Notes

From the operator on 2026-09-30: the agent is Leash's main user; help and error codes must be excellent; the skill is installed from the binary like nema's; chrome-cdp is deleted (git keeps its history) once Leash works.
