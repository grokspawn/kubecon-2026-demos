# Demo implementation plan

Status: scoping complete for demos 1–5; secondary areas awaiting
confirmation.

## Confirmed demos

### 1. Direct bundle install (`demos/01-direct-bundle-install/`)
- **What the audience sees:** install an operator from a plain OCI bundle
  image reference with no catalog prepared; inspect resolved version,
  installed resources, and the extension's status.
- **Implementation:** grokspawn PR #2907 content, rebased onto current
  operator-controller `main` as `kubecon-2026-demo-direct-bundle`
  (cherry-picks of 3c8f758, 5c8acce, bf8d1fa; build + resolve tests pass).
- **Build/deploy:** kind cluster; operator-controller image from the
  sub-branch; `--feature-gates=BoxcutterRuntime=true`.
- **Recording:** terminal (kubectl + describe/status), asciinema.

### 2. Phased rollout and readiness (`demos/02-phased-rollout/`)
- **What the audience sees:** ClusterExtension install progress through
  ordered phases; a deliberately blocked readiness probe; inspection of
  per-phase/per-object status (`ObservedPhase` detail); resolution of the
  blocker and completion.
- **Implementation:** upstream `main` as-is. No fork code required.
- **Build/deploy:** kind cluster; operator-controller from `kubecon-2026-demo`
  integration branch (tracks main); `BoxcutterRuntime=true`.
- **Recording:** k9s watching the ClusterObjectSet/ClusterExtension status
  fields, plus terminal. In active development upstream; pin the commit.

### 3. User-specified deployment configuration (`demos/03-deployment-config/`)
- **What the audience sees:** the operator-author/user configuration
  exchange: apply a ClusterExtension with
  `spec.config.inline.deploymentConfig` (replica count, resource limits,
  env), inspect the resulting Deployment, attempt an unsupported override
  and see validation reject it.
- **Implementation:** upstream `main` as-is. `DeploymentConfig=true` gate.
- **Recording:** terminal, asciinema.

### 4. OLMv0 → OLMv1 migration with structured output (`demos/04-migration/`)
- **What the audience sees:** a cluster running OLMv0 with an installed
  operator; catalog migration to a v1 ClusterCatalog; operator eligibility
  check with human-readable **and** structured (machine-readable) output;
  dry-run preview; conversion; verification; (rollback path if stable
  enough to show).
- **Implementation:** library-olm `migration/` example binaries built from
  the `kubecon-2026-demo` branch (tracks upstream main). OLMv0 fixture
  from the operator-lifecycle-manager checkout.
- **Recording:** terminal, asciinema. This demo carries concept 5
  (structured-output automation) — pipe the JSON output into `jq` and a
  tiny summary script.

### 5. Helm chart direct install (`demos/05-helm-direct-install/`)
- **What the audience sees:** the evolution path from demo 1 — a chart's
  OCI artifact installed through the same direct-install mechanism with
  inline values, rendered through OLM's manifest lifecycle. Deterministic
  rendering boundaries (rejected hook/keep annotations, changing-template
  functions) shown as validation failures where the subset rejects them.
- **Implementation:** new demo-scope code on
  `kubecon-2026-demo-helm-direct` stacked above the direct-bundle
  sub-branch: extend source sniffing/dispatch to chart artifacts and reuse
  the Helm manifest provider. Clearly labeled as an exploration of the
  `helm+v2` direction; not upstream functionality.
- **Recording:** terminal, asciinema.

## Secondary areas (not started)

- **Catalog v2 typed content:** offline demo possible (schema validation of
  mixed v1/v2 FBC documents). Requires implementing `olm.bundle.v2` /
  `olm.package.v2` parsing in the operator-registry fork — medium effort,
  design fidelity risk (lifecycle schema still TBD upstream).
- **Shared successor-resolution logic:** no implementation found in
  library-olm today; would be net-new library work. Defer unless we want
  to demo a proposal.
- **Historical shared-CRD failure (optional):** OLMv0 on kind; two
  operators claiming the same CRD from different namespaces; observe the
  failure mode referenced by the talk's history section. Low cost, high
  narrative value.

## Environment notes

- Demo host: macOS arm64. Kubebuilder envtest assets under
  `/usr/local/kubebuilder/bin` are x86_64 and fail locally — controller
  test suites that need envtest require arm64 assets (setup-envtest)
  before they can run on this machine.
- kubectl, kind, k9s, asciinema are installed and available.
- No ambient cluster is used; demos create explicitly named kind clusters
  and tear them down.
