# Demo 1 — Install a bundle directly

Installs a registry+v1 operator bundle from a plain OCI image reference.
No ClusterCatalog is created and no dependency resolution runs — the
`sourceType: OCIImage` path (operator-controller PR
[operator-framework#2907](https://github.com/operator-framework/operator-controller/pull/2907),
carried on this fork's `kubecon-2026-demo-direct-bundle` branch) pulls and
unpacks the bundle image itself.

This maps to slide 10 of the talk ("Install a bundle directly") and also
demonstrates slide 6 ("Namespace Management").

## What the audience sees

1. An OLMv1 cluster with no catalogs and no extensions.
2. A bundle image in a registry, identified by digest.
3. One `ClusterExtension` with `sourceType: OCIImage` and an image ref,
   omitting `spec.namespace`.
4. Installation progress and conditions.
5. The generated `kubecon-demo-operator-system` namespace and its
   ClusterObjectSet controller owner, plus the ClusterObjectDeployment,
   revision, CRD, deployment, service account and RBAC.
6. The operator's API exercised with a custom resource.
7. Deletion of the extension and the managed namespace and CRD.

## Prerequisites

- docker, kind, kubectl, skopeo, asciinema, jq, curl (all on the demo host)
- The operator-controller task clone at
  `~/devel/agent-playground/kubecon-oc-direct-bundle` on branch
  `kubecon-2026-demo-direct-bundle` (see `env.sh` for the pinned commit)
- Network access (kind node image, cert-manager, registry:3, busybox)

## Run

Use only the disposable demo cluster. `run.sh` first deletes the demo
ClusterExtension and, at the end, deletes it again. This removes the entire
managed namespace, including any unrelated resources in it; deleting the demo
CRD also deletes its custom resources in **all** namespaces. Do not put
valuable data in this cluster. `setup.sh` creates a kind cluster and
`teardown.sh` deletes it. Check the kubeconfig and cluster before running.
If cleanup stalls or an existing namespace/CRD blocks the baseline, the script
stops; inspect ownership and data before any manual cleanup. It does not
delete leftover namespaces or CRDs directly.

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
- With the experimental CRD and `BoxcutterRuntime`, omitting
  `spec.namespace` renders a managed Namespace. This bundle has no suggested
  namespace annotations, so the pinned controller uses the package-name
  fallback `kubecon-demo-operator-system`. The COD produces a COS revision
  that owns the namespace. With `spec.namespace` set, the namespace must
  already exist and is user-managed; the mode cannot be changed in place.
- Keep a bundle's resolved managed namespace stable across upgrades: changing
  its namespace metadata can delete the old namespace and everything in it
  when the old revision is archived. Use a separate migration to move it.

## Notes and caveats

- The OCIImage source type is experimental: it exists on this fork's
  branch and in the open upstream PR, not in an upstream release. The
  demo is honest evidence of the feature-gated work, not released
  behavior.
- This demo is the first full-cluster exercise of the OCIImage path; if
  it surfaces reconciler bugs, they belong in the upstream PR review.
- The demo operator container is an intentionally trivial watcher; the
  subject of the demo is the lifecycle, not the operator's logic.
- `recordings/demo-01.cast` shows the managed-namespace scenario on the
  disposable demo cluster.
