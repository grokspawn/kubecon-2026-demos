# Demo 4 — OLMv0 → OLMv1 migration with structured output

Migrates a live, OLMv0-managed operator to OLMv1 management using the
[library-olm](https://github.com/operator-framework/library-olm) migration
tooling. Maps to slide 8 of the talk ("OLMv0 → OLMv1 migration") and carries
the structured-output story (slide material on automation/model consumption):
the same readiness check is shown human-readable and as JSON Lines.

library-olm is pre-release (v0, APIs may change). The demo pins released
OLMv0 (v0.46.0) and OLMv1 (v1.12.0, experimental feature set) — the same
pins library-olm's own e2e uses — and builds the migration CLIs from the
`kubecon-2026-demo` branch of the grokspawn fork, which tracks upstream
main.

## What the audience sees

1. A cluster running OLMv0 with the `ecr-secret-operator` operator
   installed through a Subscription; OLMv1 installed alongside, idle.
2. `migrate-operators-v0-to-v1 check`: sixteen readiness, compatibility
   and catalog-availability findings in human-readable form. (The OLMv1
   experimental installer creates a default `operatorhubio`
   ClusterCatalog, so catalog availability is already satisfied; without
   one, the same check fails with an explicit "No ClusterCatalog found".)
3. `migrate-catalogs-v0-to-v1` adopting the operatorhubio CatalogSource
   into the ClusterCatalog.
4. `migrate-operators-v0-to-v1 check`: readiness and compatibility findings
   in human-readable form (including acknowledgement flags for known
   v0→v1 semantic differences).
5. The same check with `--output jsonl`: machine-readable records piped
   through `jq`.
6. `convert`: the operator handed off to a ClusterExtension; the OLMv0
   Subscription and InstallPlan removed; workloads keep running.
7. Verification of the resulting state, and a pointer to `rollback`.

## Prerequisites

- docker, kind, kubectl, jq, curl, asciinema, shasum
- The library-olm task clone at
  `~/devel/agent-playground/kubecon-library-olm` (branch `kubecon-2026-demo`)
- Network access (OLMv0/OLMv1 release manifests, the operatorhubio catalog
  image and the ecr-secret-operator bundle image)

## Run

```bash
./setup.sh    # kind cluster + OLMv0 + operator + OLMv1 + migration CLIs
./run.sh      # scripted demo steps
./record.sh   # same steps captured as an asciinema cast
# teardown: kind delete cluster --name kubecon-migration
```
