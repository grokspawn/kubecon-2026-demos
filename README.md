# KubeCon NA 2026 — OLM Demo Companions

Concise, reproducible demos supporting **"The Next Era of Kubernetes Operator
Lifecycle Management"** (KubeCon + CloudNativeCon NA 2026). These are online
companions to the talk, not live presentation material.

Each demo directory contains: a scripted sequence of meaningful steps, a
reproducible environment definition (kind cluster config, manifests, pinned
images/commits), a cleanup routine, and a loopable captured recording
(asciinema minimum; browser or k9s presentations where they add clarity).

## Implementation inventory (assessed 2026-10-27)

| # | Demo concept | Implementation source | State |
|---|---|---|---|
| 1 | Direct registry+v1 bundle install | operator-controller PR [operator-framework#2907](https://github.com/operator-framework/operator-controller/pull/2907) (grokspawn), rebased to `kubecon-2026-demo-direct-bundle` | OPEN upstream; our fork carries the demo build. Requires `BoxcutterRuntime` gate. |
| 2 | Phased resource rollout / readiness | operator-controller `main` (ClusterObjectSets; ObservedPhase enrichment #3044/#3045) | Implemented behind `BoxcutterRuntime` gate (Alpha, default off). In active development. |
| 3 | User-specified deployment configuration | operator-controller `main` (`spec.config.inline.deploymentConfig`) | Implemented behind `DeploymentConfig` gate (Alpha, default off). |
| 4 | OLMv0 → OLMv1 migration + structured output | [library-olm](https://github.com/operator-framework/library-olm) `migration/` (library + example CLIs: `migrate-catalogs-v0-to-v1`, `migrate-operators-v0-to-v1`) | Implemented, pre-release v0. Needs an OLMv0 cluster fixture. |
| 5 | Helm chart direct install (evolution of #1) | New work: extend the direct-install source mechanism beyond `registry+v1` | Design exists (`helm+v2` brief); implementation is demo-scope work in this fork. Not upstream functionality. |

Deferred pending scope confirmation: catalog v2 typed-content schemas
(offline `opm`/schema-validation demo possible; OCI transport is future
work), shared successor-resolution logic (no implementation found in
library-olm), and an optional historical shared-CRD failure scenario on
OLMv0.

## Source-control layout

- Integration branch: `kubecon-2026-demo` (off synced `main`) in
  [grokspawn/operator-controller](https://github.com/grokspawn/operator-controller)
  and [grokspawn/library-olm](https://github.com/grokspawn/library-olm).
- Feature sub-branches use the `kubecon-2026-demo-<area>` naming (hyphen, not
  slash — git refs cannot hold both `kubecon-2026-demo` and
  `kubecon-2026-demo/...`).
- Task-specific clones live under `~/devel/agent-playground/`; neighboring
  project checkouts under `~/devel/operator-framework/` are never modified.
- Upstream `main` is never pushed to. All fork changes stay on
  `kubecon-2026-demo*` branches.

## Demo baseline

Every demo starts from the same verified baseline and cleans up after
itself:

- kind cluster (explicit name/context; never an ambient cluster)
- operator-controller image built from a pinned branch/commit of this fork
- feature gates set explicitly per demo
- preflight check + teardown script in each demo directory
