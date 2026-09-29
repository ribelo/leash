# Repository Guidelines

Read `CONTEXT.md` first (domain vocabulary), then `docs/milestones.md` (the plan spine and where we are), then `docs/adr/` (settled decisions), then the spec for the milestone you are working on under `docs/issues/`. Leash builds on Ox: the checkout at `/home/ribelo/projects/ribelo/ocaml/ox`, branch `master` (the former eta-next line; v1 is the `v1` tag). Pie at `/home/ribelo/projects/ribelo/pie` is the sibling service whose conventions Leash copies.

## Landing: work is done when it is committed

You are the only agent working in this repository. Each session starts with no memory of earlier ones. The git history is the only memory that lasts, so uncommitted work is effectively lost work.

- A task is finished only when its verified change is committed to local `master`. A passing build or a green test run is not finished work.
- Commit each coherent, verified slice as soon as it is done. The commit message names what changed and cites the story IDs it covers.
- Never end a session with uncommitted changes. If something is unfinished, commit it with a message that says what is unfinished and why, or record it in `docs/issues`.
- Uncommitted changes you find at the start of a session came from an earlier session of yours that did not land its work. Read the diff, verify it, then commit or finish it.
- When subagents implement slices, the coordinating session reviews each result and commits it before starting dependent work.
- Push only when the user asks.

## Compatibility before 1.0

Leash has no released users. Until 1.0, prioritize maintainability over backward compatibility: no shims, no dual paths, no migrations to preserve earlier state. The control protocol, on-disk config, and internal formats may change freely. This does not waive current-version durability or the safety defaults recorded in the ADRs.

## Stack (settled — see docs/adr)

- **OCaml 5 / OxCaml, Dune, Nix flake** with Ox pinned as a flake input, exactly Pie's build shape.
- **Ox everywhere.** Effects, streams, scopes, schedules, observability. Service composition is explicit scoped resources in one owner, not an `ox_component` tree (ADR-0007, on Pie's evidence). Leash is a dogfooding consumer: if a needed capability is an effect-shaped resource, stream, or lifecycle concern that does not name Chrome/CDP/niri, it is built in ox first (ADR-0001, ADR-0008), specified under ox's `docs/issues/` and pulled by a Leash story ID. Record any workaround for a missing Ox API in `docs/missing-ox-api.md` with an `etagap-*` ID and remove it when Ox catches up.
- **Chrome over CDP through `--remote-debugging-pipe`** (ADR-0003). No debugging port is ever opened.
- **Control socket + `leash` CLI** (Cmdliner) are the only agent-facing surface (ADR-0002). Every command is one request.
- **Config**: TOML at `$XDG_CONFIG_HOME/leash/config.toml`, fail fast at boot. `OPENROUTER_API_KEY` in the environment overrides the file. Config and protocol shapes are plain types with `[@@deriving yojson]`; no schema DSL (ADR-0009).
- **Models**: JEV through OpenRouter System One; a configurable OpenRouter text helper. Model output never becomes selectors, coordinates, shell, or JavaScript.
- **Logs** to the journal through Ox observability; OTLP export optional.

## Test seams

Three seams, chosen once; every test crosses one of them:

1. **Control protocol** (top). Tests run the service in-process and send the JSON the CLI would send. Ownership, expiry, handoff, snapshots, drive: all here.
2. **CDP message stream** (bottom). A scripted fake stands in for Chrome and speaks the same framed JSON. No real browser in unit tests.
3. **Model clients**. System One and the text helper are served by a local fake HTTP server.

Real Chrome is exercised only by the live-acceptance gate (`scripts/live-acceptance`, on demand, never in the default test run).

## Story IDs and specs

Specs live at `docs/issues/<slug>/01-<slug>.md` with `status:` frontmatter. Every user story ends with a stable ID such as `^tab-k3x9`. Tests cite the bare ID. Generate IDs with the `to-spec` skill scripts from the repository root; never invent or reuse one. An ID never changes; a story that changes meaning gets a new ID.

## Gates (run before any commit)

```sh
nix develop -c dune build @install
nix develop -c dune test
nix develop -c dune build @fmt
```

## Safety defaults that are not up for local negotiation

- Navigation accepts `http:`, `https:`, and `about:blank` only.
- Dialogs are never auto-answered.
- Actions are never retried automatically; only pre-dispatch observation may retry.
- Human-origin tabs are never auto-closed.
- The control socket is owner-only (0600) in a verified private runtime directory.
