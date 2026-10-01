---
status: ready-for-agent
milestone: 11
---

# The help is the documentation

## Problem Statement

The operator asked for an explanation of every CLI parameter and for the specification of a playbook, and found neither in the binary: `leash help` has one topic (`errors`), `leash playbook --help` lists subcommands without saying what a playbook is, and options such as `--owner` were a flag with a default and no meaning. The playbook format and the authoring procedure live in the skill, which drifts from the binary whenever a row changes a format — exactly what the version stamp in `status` exists to detect. Documentation that ships inside the binary cannot be stale against it, and a tool that will be used from other harnesses needs its documentation in the one place every harness has: the executable.

## Solution

One set of Markdown topic files in the repository, embedded at build and rendered by both `leash help <topic>` and the skill's references (the skill's reference files *are* the topics, generated, not hand-written twice). Every option on every command has a one-line meaning in `--help`. The skill shrinks to when-to-use and one rule per topic, pointing at `leash help`.

## User Stories

1. As an agent, I want `leash help` to list its topics, and `leash help TOPIC` to print one: `handles` (the capability model and the one tab rule), `playbooks` (the format, field by field, with the worked example), `authoring` (the procedure for writing one), `expectations` (the checker vocabulary with an example each), `drive` (missions, lanes, options, reading a trace), `scripts` (what a script is, `pages`, `returns`, args, how JEV chooses one), `errors` (the table), so that everything I need is in the binary. ^hdoc-ztwo
2. As a maintainer, I want the topics to be Markdown files under `docs/help/` embedded at build (the same generator as the skill), rendered to the terminal as plain text with headings and tables kept readable (no ANSI), so that one file is the source for both the binary and the skill. ^hdoc-8c12
3. As a maintainer, I want the skill's `references/*.md` generated from the same topic files at build (a dune rule, checked in, with a test that the checked-in copy equals the generated one), so that the skill cannot say something the binary does not. ^hdoc-jh7u
4. As an agent, I want every option of every command to carry a one-line meaning and, where it matters, its default and its bound (`--limit N  rows to return, default 50, max 250`), with a test that no option's doc is empty, so that `--help` is enough to call any command. ^hdoc-05q1
5. As an agent, I want `leash playbook --help` to open with three lines on what a playbook is and point at `leash help playbooks`, and `leash drive --help` likewise at `leash help drive`, so that the subcommand help is a door to the topic. ^hdoc-socc
6. As an agent, I want `leash help playbooks` to include the complete JSON of the books.toscrape.com example with a sentence per field, and the list of every loader refusal with its message, so that I can write a valid playbook from the help alone. ^hdoc-vh8m
7. As an agent, I want the first-run orientation (bare `leash`) to say in one paragraph: what Leash is, that `new` returns a handle you must keep, the tab rule, that models need an API key (where it comes from, which provider, that it is the operator's), and the three commands to start with, so that the first contact tells a newcomer everything that would otherwise be a surprise. ^hdoc-fixp
8. As a maintainer, I want `docs/protocol.md` to stay the wire contract and to link each error and field to its help topic, so that the two documents divide the work: wire shapes there, meaning here. ^hdoc-6vvm
9. As a maintainer, I want the skill's `SKILL.md` cut to: when to use Leash, the ownership-free handle rule, minimize output, the three safety rules, and 'run `leash help TOPIC` for the rest', under 60 lines, so that the skill is a pointer, not a copy. ^hdoc-65jx
10. As a maintainer, I want nothing in the help or the topics to name DSH, `DSH_SESSION_ID`, niri, or this machine's paths, with a test grepping the embedded topics for those strings, so that the documentation is as portable as the binary. ^hdoc-2264
11. As a maintainer, I want a fresh agent (`subagent_claude_sonnet`) given only `leash --help` and `leash help` — no skill — to write and run a playbook for automationexercise.com, with its transcript and every gap recorded and fixed in the topics, so that the help is proven sufficient on its own. ^hdoc-vqj7
12. As the operator, I want `leash help` to work with no service running, so that documentation never depends on the daemon. ^hdoc-em5c

## Implementation Decisions

- Topics are embedded with the existing `gen_skill_data` mechanism, generalized to a `docs/help/` directory. Rendering: a minimal Markdown-to-terminal pass (headings, lists, tables as aligned columns, code fences verbatim).
- The skill's references directory is produced by the same rule; `skill install` installs the generated tree.
- Option docs live beside their Cmdliner definitions; the non-empty-doc test walks the command tree.

## Testing Decisions

- Unit: every topic renders; generated references equal checked-in; no empty option doc; no harness-specific strings. Live: story 11.

## Out of Scope

Man pages beyond Cmdliner's; localisation.
