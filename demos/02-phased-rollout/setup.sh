#!/usr/bin/env bash
# Demo 2 setup: assumes demo 1's cluster and registry are running
# (../01-direct-bundle-install/setup.sh). Builds and pushes this demo's
# content images.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../01-direct-bundle-install/env.sh
source "$SCRIPT_DIR/../01-direct-bundle-install/env.sh"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

step "Checking demo 1 environment"
if ! kubectl --kubeconfig "$KUBECONFIG" -n "$REGISTRY_NAMESPACE" get deployment "$REGISTRY_NAME" >/dev/null 2>&1; then
  echo "Demo registry not found. Run ../01-direct-bundle-install/setup.sh first." >&2
  exit 1
fi
if ! curl -ksf "https://$REGISTRY_LOCAL_HOST/v2/" >/dev/null 2>&1; then
  if [ -f "$SCRIPT_DIR/../01-direct-bundle-install/.registry-pf-pid" ]; then
    kill "$(cat "$SCRIPT_DIR/../01-direct-bundle-install/.registry-pf-pid")" 2>/dev/null || true
  fi
  kubectl --kubeconfig "$KUBECONFIG" -n "$REGISTRY_NAMESPACE" port-forward service/"$REGISTRY_NAME" "${REGISTRY_LOCAL_PORT}:5000" >/dev/null 2>&1 &
  echo $! > "$SCRIPT_DIR/../01-direct-bundle-install/.registry-pf-pid"
  for _ in $(seq 1 30); do
    curl -ksf "https://$REGISTRY_LOCAL_HOST/v2/" >/dev/null 2>&1 && break
    sleep 1
  done
fi
curl -ksf "https://$REGISTRY_LOCAL_HOST/v2/" >/dev/null || { echo "registry unreachable" >&2; exit 1; }

step "Building and pushing rollout demo images"
push_bundle() { # $1=local tag $2=remote ref
  local archive
  archive="$(mktemp /tmp/kubecon-demo-img-XXXXXX.tar)"
  docker save "$1" -o "$archive"
  skopeo copy --insecure-policy --dest-tls-verify=false "docker-archive:$archive:docker.io/library/$1" "docker://$REGISTRY_LOCAL_HOST/$2"
  rm -f "$archive"
}
pushd "$SCRIPT_DIR/bundle" >/dev/null
docker build -q -t kubecon-rollout-operator:v0.2.0 -f Dockerfile.operator .
docker build -q -t kubecon-rollout-operator-bundle:v0.2.0 -f Dockerfile.bundle .
popd >/dev/null
push_bundle "kubecon-rollout-operator-bundle:v0.2.0" "bundles/kubecon-rollout-operator-bundle:v0.2.0"
# Load the operator image onto the kind nodes (see demo 1 setup for why).
docker tag "kubecon-rollout-operator:v0.2.0" "$REGISTRY_SERVICE_DNS/operators/kubecon-rollout-operator:v0.2.0"
kind load docker-image "$REGISTRY_SERVICE_DNS/operators/kubecon-rollout-operator:v0.2.0" --name "$KIND_CLUSTER"

step "Demo 2 content ready"
echo "Run ./run.sh to execute the demo."
