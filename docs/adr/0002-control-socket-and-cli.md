# One agent-facing surface: the control socket and the leash CLI

Agents today drive Chrome by running a script through bash. We keep that shape: the Leash service serves a private Unix-domain socket in the user's runtime directory with line-delimited JSON requests and replies, and the `leash` CLI (Cmdliner) is a thin encoder for it. Every CLI command is exactly one protocol request; there is no other API. The socket is user-only (0600) in a verified private directory, with bounded concurrent peers and per-peer deadlines, following Pie's control-socket rules.

## Considered options

- **HTTP/JSON on localhost from day one.** Rejected: needs an auth story before it is safe, and nothing local needs it. It can be added later as a thin adapter over the same protocol.
- **A DSH plugin registering tools as the primary surface.** Rejected: couples Leash to one harness and hides it from bash-driven agents. A plugin can wrap the CLI later.

## Consequences

- The envelope is `v`, `cmd`, and `args`. A caller name is not part of the protocol (ADR-0010).
- Replies are typed: one `ok` shape per command, one closed set of error codes (see `docs/protocol.md`). Errors are for agents to read, so they are short and specific.
- The CLI does no interpretation beyond encoding arguments and printing the reply as compact JSON (`--pretty` for humans).
