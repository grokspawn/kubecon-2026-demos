#!/usr/bin/env bash
# Demo 4 setup: a kind cluster with OLMv0 (released), a live operator
# installed through a Subscription, OLMv1 (released, experimental) alongside
# it, and the migration CLIs built from the library-olm task clone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

step "Building the migration CLIs from the library-olm task clone"
if [ ! -d "$LIBOLM_REPO_DIR" ]; then
  echo "Task clone missing: $LIBOLM_REPO_DIR" >&2
  exit 1
fi
cd "$LIBOLM_REPO_DIR"
git fetch -q origin "$LIBOLM_BRANCH"
git checkout -q "$LIBOLM_BRANCH"
make migration/build

step "Creating kind cluster $KIND_CLUSTER"
if kind get clusters 2>/dev/null | grep -q "^$KIND_CLUSTER$"; then
  kind delete cluster --name "$KIND_CLUSTER"
fi
kind create cluster --name "$KIND_CLUSTER" --config "$SCRIPT_DIR/kind-config.yaml" --image "$KIND_NODE_IMAGE"
kind export kubeconfig --name "$KIND_CLUSTER" --kubeconfig "$KUBECONFIG"
kubectl --kubeconfig "$KUBECONFIG" wait --for=condition=Ready nodes --all --timeout=5m

step "Installing OLMv0 $OLM_V0_VERSION (released)"
kubectl --kubeconfig "$KUBECONFIG" apply -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_V0_VERSION/crds.yaml"
kubectl --kubeconfig "$KUBECONFIG" wait --for=condition=Established crd/clusterserviceversions.operators.coreos.com --timeout=120s
kubectl --kubeconfig "$KUBECONFIG" apply -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/$OLM_V0_VERSION/olm.yaml"
kubectl --kubeconfig "$KUBECONFIG" -n olm wait --for=condition=Available deployment/olm-operator --timeout=300s
kubectl --kubeconfig "$KUBECONFIG" -n olm wait --for=condition=Available deployment/catalog-operator --timeout=300s

step "Installing the demo operator through OLMv0"
kubectl --kubeconfig "$KUBECONFIG" apply -f "$SCRIPT_DIR/manifests/operator-subscription.yaml"
echo "Waiting for the Subscription's CSV to install (network-dependent)..."
for _ in $(seq 1 60); do
  if kubectl --kubeconfig "$KUBECONFIG" -n "$OPERATOR_NAMESPACE" get csv 2>/dev/null | grep -q "Succeeded"; then break; fi
  sleep 10
done
kubectl --kubeconfig "$KUBECONFIG" -n "$OPERATOR_NAMESPACE" get csv,subscriptions,installplans

step "Installing OLMv1 $OLM_V1_VERSION (released, experimental feature set)"
curl -sfL "https://github.com/operator-framework/operator-controller/releases/download/$OLM_V1_VERSION/install-experimental.sh" -o "$SCRIPT_DIR/.install-experimental.sh"
echo "$OLM_V1_INSTALL_SHA256  $SCRIPT_DIR/.install-experimental.sh" | shasum -a 256 -c -
chmod +x "$SCRIPT_DIR/.install-experimental.sh"
KUBECONFIG="$KUBECONFIG" "$SCRIPT_DIR/.install-experimental.sh"
kubectl --kubeconfig "$KUBECONFIG" -n olmv1-system wait --for=condition=Available deployments --all --timeout=600s

step "Setup complete"
echo "Cluster:         $KIND_CLUSTER (kubeconfig: $KUBECONFIG)"
echo "OLMv0:           $OLM_V0_VERSION (operator $PACKAGE_NAME installed in $OPERATOR_NAMESPACE)"
echo "OLMv1:           $OLM_V1_VERSION experimental"
echo "Catalog CLI:     $MIGRATE_CATALOGS_BIN"
echo "Operator CLI:    $MIGRATE_OPERATORS_BIN"
echo "Run ./run.sh to execute the demo."
