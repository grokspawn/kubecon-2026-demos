# Demo 1 — Install a bundle directly

Installs a registry+v1 operator bundle from a plain OCI image reference.
No ClusterCatalog is created and no dependency resolution runs — the
`sourceType: OCIImage` path (operator-controller PR
[operator-framework#2907](https://github.com/operator-framework/operator-controller/pull/2907),
carried on this fork's `kubecon-2026-demo-direct-bundle` branch) pulls and
unpacks the bundle image itself.

This maps to slide 5 of the talk ("Install a bundle directly").

## What the audience sees

1. An OLMv1 cluster with no catalogs and no extensions.
2. A bundle image in a registry, identified by digest.
3. One `ClusterExtension` with `sourceType: OCIImage` and an image ref.
4. Installation progress and conditions.
5. The managed result: CRD, deployment, service account, RBAC — owned
   and labeled by the extension.
6. The operator's API exercised with a custom resource.
7. Deletion of the extension cleaning up everything it manages.

## Prerequisites

- docker, kind, kubectl, skopeo, asciinema, jq, curl (all on the demo host)
- The operator-controller task clone at
  `~/devel/agent-playground/kubecon-oc-direct-bundle` on branch
  `kubecon-2026-demo-direct-bundle` (see `env.sh` for the pinned commit)
- Network access (kind node image, cert-manager, registry:3, busybox)

## Run

```bash
./setup.sh    # kind cluster + OLMv1 (experimental gates) + registry + images
./run.sh      # scripted demo steps
./record.sh   # same steps captured as an asciinema cast
./teardown.sh # delete the cluster
```

## How it works

- `setup.sh` reuses the operator-controller repository's own make chain
  (`make experimental-e2e-setup`), which builds the controller image from
  the task clone, creates the `operator-controller-experimental-e2e` kind
  cluster, and deploys with experimental values. Those values enable
  `BoxcutterRuntime` (required for OCIImage sources), `DeploymentConfig`,
  and the experimental ClusterExtension CRD that includes
  `sourceType: OCIImage`.
- Demo content is served by an in-cluster registry:3 deployment whose TLS
  certificate is issued by the `olmv1-ca` ClusterIssuer. The operator
  controller already trusts that CA for image pulls
  (`--pull-cas-dir=/var/ca-certs`), so no controller changes are needed
  for the registry. Host-side pushes go through a port-forward with
  `--tls-verify=false` because the certificate's DNS names are the
  in-cluster service names.
- The bundle is a minimal, valid registry+v1 bundle: one CRD
  (`kubecondemos.demo.kubecon.io`), one CSV with a single deployment, and
  the `olm.package` property in `metadata/properties.yaml`.

## Notes and caveats

- The OCIImage source type is experimental: it exists on this fork's
  branch and in the open upstream PR, not in an upstream release. The
  demo is honest evidence of the feature-gated work, not released
  behavior.
- This demo is the first full-cluster exercise of the OCIImage path; if
  it surfaces reconciler bugs, they belong in the upstream PR review.
- The demo operator container is an intentionally trivial watcher; the
  subject of the demo is the lifecycle, not the operator's logic.
