# Compose the service from explicit scoped resources, not an eta_component tree

Leash's long-lived parts are few and their dependencies form a line: managed Chrome (a supervised process), the CDP session over its pipe, the tab registry with its expiry sweep, the model clients, and the control listener. We decided to compose them with Eta's ordinary scoped resources (`acquire_release`, `with_background`, `Schedule`-driven restart inside the Chrome supervisor) in one lexical owner, and not to use `eta_component`'s desired-state tree.

The evidence is Pie's. Pie adopted `eta_component` in August 2026 (ADR-0001 there) and removed it a month later in "Remove shadow component orchestration": the component graph had become a shadow of the real data path, with capabilities stored in `Obj.t` refs and unchecked casts, supervision retrying a dummy graph while the actual resources were opened elsewhere, and fabricated health reported through status. Pie's disposition — use Eta resource and worker scopes where they actually provide lifecycle guarantees; do not replace `eta_component` with a homegrown framework either — is the rule Leash follows from the start.

## Considered options

- **eta_component tree, as first specified.** Rejected on Pie's evidence: a declarative tree is not process supervision, and Leash has no runtime reconfiguration, dynamic enablement, or provider swapping that would earn the layer.
- **A homegrown registry of services.** Rejected for the same reason Pie rejected it: it is the shadow graph again with a different name.

## Consequences

- One application owner builds the resources in dependency order; Chrome loss is handled inside the Chrome supervisor by generation bump and event, not by tearing down siblings.
- `leash status` reports state read from the real resources (the supervisor's generation, the registry's counts), never a component phase.
- `eta_component` leaves the dependency list. If a real reconfiguration need appears later, the decision is reopened with that need in hand.
