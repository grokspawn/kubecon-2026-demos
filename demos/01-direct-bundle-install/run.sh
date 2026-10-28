#!/usr/bin/env bash
# Demo 1: install a registry+v1 operator bundle directly from an OCI image
# reference — no catalog, no dependency resolution.
#
# Scripted steps (each is announced before running):
#   1. Show the cluster state: no ClusterCatalogs, no ClusterExtensions.
#   2. Show the bundle image we will install from.
#   3. Apply the ClusterExtension with sourceType: OCIImage.
#   4. Watch installation progress and conditions.
#   5. Show the managed namespace, its revision owner and installed resources.
#   6. Exercise the operator's API with a custom resource.
#   7. Delete the ClusterExtension and show managed cleanup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

say()    { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()    { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }
waitfor(){ printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"

# Refuse to delete resources unless the selected context is the named kind
# demo cluster and all nodes report that cluster's kind provider ID.
context="$(kubectl --kubeconfig "$KUBECONFIG" config current-context)"
if [ "$context" != "kind-$KIND_CLUSTER" ]; then
  echo "Refusing to run against context $context; expected kind-$KIND_CLUSTER." >&2
  exit 1
fi
kubectl --kubeconfig "$KUBECONFIG" get nodes -o json | jq -e --arg prefix "kind://docker/$KIND_CLUSTER/" \
  '(.items | length) > 0 and all(.items[]; (.spec.providerID // "") | startswith($prefix))' >/dev/null || {
  echo "Refusing to run: node provider IDs do not match the demo cluster." >&2
  exit 1
}

# Reset only this extension. Its deletion can delete the managed namespace and
# CRD, including resources created by others; use only the disposable demo cluster.
say "Resetting the demo extension (its managed namespace and CRD contents may be deleted)"
$K delete clusterextension "$DEMO_PACKAGE" --ignore-not-found --timeout=120s

# GC is asynchronous. Do not delete a leftover namespace or CRD directly: it
# could belong to someone else. Fail rather than silently recording a dirty run.
wait_absent() {
  local kind="$1" name="$2" found
  found="$($K get "$kind" "$name" --ignore-not-found -o name)"
  if [ -n "$found" ]; then
    $K wait --for=delete "$kind/$name" --timeout=120s || {
      echo "$kind/$name still exists; inspect it before cleaning up and retrying." >&2
      return 1
    }
  fi
}
wait_absent clusterobjectdeployment "$DEMO_PACKAGE"
wait_absent namespace "$INSTALL_NAMESPACE"
wait_absent crd kubecondemos.demo.kubecon.io

if [ "$($K get clustercatalogs -o json | jq '.items | length')" != 0 ] ||
   [ "$($K get clusterextensions -o json | jq '.items | length')" != 0 ]; then
  echo "Baseline requires no catalogs or extensions; inspect the demo cluster before retrying." >&2
  exit 1
fi

say "1. Starting point: an OLMv1 cluster with no catalogs and no extensions"
cmd "$K get clustercatalogs 2>&1 | head -2"
cmd "$K get clusterextensions 2>&1 | head -2"

say "2. The install source is a plain registry+v1 bundle image"
cmd "skopeo inspect --insecure-policy --tls-verify=false docker://$REGISTRY_LOCAL_HOST/bundles/$DEMO_PACKAGE-bundle:v$DEMO_VERSION | jq -r '.Labels, .Digest'"
cmd "cat $SCRIPT_DIR/manifests/clusterextension.yaml"

say "3. Apply the ClusterExtension without spec.namespace; OLM creates the install namespace"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension.yaml"

say "4. Watch installation progress"
waitfor "$K wait --for=condition=Available clusterextension/$DEMO_PACKAGE --timeout=300s"
cmd "$K get clusterextension $DEMO_PACKAGE -o yaml | sed -n '/status:/,\$p'"

say "5. The managed namespace belongs to a ClusterObjectSet revision beneath the ClusterObjectDeployment"
cmd "$K get namespace $INSTALL_NAMESPACE -o json | jq '{name: .metadata.name, owners: .metadata.ownerReferences}'"
$K get namespace "$INSTALL_NAMESPACE" -o json | jq -e 'any(.metadata.ownerReferences[]?; .apiVersion == "olm.operatorframework.io/v1" and .kind == "ClusterObjectSet" and .controller == true)' >/dev/null || {
  echo "Expected a ClusterObjectSet controller owner on $INSTALL_NAMESPACE." >&2
  exit 1
}
cmd "$K get crd kubecondemos.demo.kubecon.io"
cmd "$K -n $INSTALL_NAMESPACE get all,sa,role,rolebinding"
cmd "$K get clusterobjectdeployments"
cmd "$K get clusterobjectsets"

say "6. Exercise the operator's API"
cmd "cat $SCRIPT_DIR/manifests/kubecondemo-example.yaml"
cmd "$K apply -f $SCRIPT_DIR/manifests/kubecondemo-example.yaml"
cmd "$K -n $INSTALL_NAMESPACE get kubecondemos"
cmd "$K -n $INSTALL_NAMESPACE get pods -l app=$DEMO_PACKAGE"

say "7. Delete the ClusterExtension; its managed namespace and CRD (including their contents) are deleted"
cmd "$K delete clusterextension $DEMO_PACKAGE --timeout=120s"
wait_absent clusterobjectdeployment "$DEMO_PACKAGE"
wait_absent namespace "$INSTALL_NAMESPACE"
wait_absent crd kubecondemos.demo.kubecon.io
cmd "$K get namespace $INSTALL_NAMESPACE --ignore-not-found"
cmd "$K get crd kubecondemos.demo.kubecon.io --ignore-not-found"

say "Demo complete"
