#!/usr/bin/env bash
# Demo 1 setup: cluster, OLMv1 (experimental gates), in-cluster registry,
# and demo content images. Idempotent; safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

step "Verifying operator-controller task clone ($OPCON_BRANCH @ $OPCON_EXPECTED_COMMIT)"
if [ ! -d "$OPCON_REPO_DIR" ]; then
  echo "Task clone missing: $OPCON_REPO_DIR" >&2
  echo "Create it with:" >&2
  echo "  git clone git@github.com:grokspawn/operator-controller.git $OPCON_REPO_DIR" >&2
  exit 1
fi
cd "$OPCON_REPO_DIR"
git fetch -q origin "$OPCON_BRANCH"
git checkout -q "$OPCON_BRANCH"
ACTUAL_COMMIT="$(git rev-parse HEAD)"
if [ "$ACTUAL_COMMIT" != "$OPCON_EXPECTED_COMMIT" ]; then
  echo "Task clone is at $ACTUAL_COMMIT; expected $OPCON_EXPECTED_COMMIT." >&2
  echo "Update the pin in demos/01-direct-bundle-install/env.sh after verifying changes." >&2
  exit 1
fi

step "Creating kind cluster and deploying OLMv1 with experimental feature gates"
# Chain: kind-cluster -> docker-build -> kind-load -> kind-deploy, using the
# repo's own make targets. Experimental values enable BoxcutterRuntime
# (required for OCIImage sources), DeploymentConfig and the experimental
# ClusterExtension CRD that carries sourceType: OCIImage.
make experimental-e2e-setup

step "Waiting for OLMv1 deployments"
kubectl --kubeconfig "$KUBECONFIG" wait --for=condition=Available deployments --all -n olmv1-system --timeout=300s

step "Deploying the in-cluster demo registry"
kubectl --kubeconfig "$KUBECONFIG" apply -f "$SCRIPT_DIR/manifests/registry.yaml"
kubectl --kubeconfig "$KUBECONFIG" -n "$REGISTRY_NAMESPACE" wait --for=condition=Available deployment/"$REGISTRY_NAME" --timeout=180s

step "Port-forwarding the registry to $REGISTRY_LOCAL_HOST"
if [ -n "${REGISTRY_PF_PID:-}" ] && kill -0 "$REGISTRY_PF_PID" 2>/dev/null; then
  kill "$REGISTRY_PF_PID" 2>/dev/null || true
fi
kubectl --kubeconfig "$KUBECONFIG" -n "$REGISTRY_NAMESPACE" port-forward service/"$REGISTRY_NAME" "${REGISTRY_LOCAL_PORT}:5000" >/dev/null 2>&1 &
REGISTRY_PF_PID=$!
export REGISTRY_PF_PID
for _ in $(seq 1 30); do
  if curl -ksf "https://$REGISTRY_LOCAL_HOST/v2/" >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -ksf "https://$REGISTRY_LOCAL_HOST/v2/" >/dev/null || { echo "registry port-forward failed" >&2; exit 1; }
echo "$REGISTRY_PF_PID" > "$SCRIPT_DIR/.registry-pf-pid"

step "Building and pushing demo content images"
# The registry serves TLS with a certificate for its in-cluster DNS name;
# from the host (via port-forward) the name does not match, so pushes use
# --tls-verify=false. In-cluster consumers verify the real CA chain.
pushd "$SCRIPT_DIR/bundle" >/dev/null
docker build -q -t "$DEMO_PACKAGE:$DEMO_VERSION" -f Dockerfile.operator .
docker build -q -t "$DEMO_PACKAGE-bundle:$DEMO_VERSION" -f Dockerfile.bundle .
skopeo copy --dest-tls-verify=false "docker-daemon:$DEMO_PACKAGE:$DEMO_VERSION" "docker://$REGISTRY_LOCAL_HOST/operators/$DEMO_PACKAGE:$DEMO_VERSION"
skopeo copy --dest-tls-verify=false "docker-daemon:$DEMO_PACKAGE-bundle:$DEMO_VERSION" "docker://$REGISTRY_LOCAL_HOST/bundles/$DEMO_PACKAGE-bundle:$DEMO_VERSION"
popd >/dev/null

step "Setup complete"
echo "Cluster:      $KIND_CLUSTER (kubeconfig: $KUBECONFIG)"
echo "Registry:     $REGISTRY_SERVICE_DNS (host: https://$REGISTRY_LOCAL_HOST)"
echo "Operator:     $OPERATOR_REF"
echo "Bundle:       $BUNDLE_REF"
echo "Run ./run.sh to execute the demo (./record.sh to capture it)."
