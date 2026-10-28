#!/usr/bin/env bash
# Demo 1: install a registry+v1 operator bundle directly from an OCI image
# reference — no catalog, no dependency resolution.
#
# Scripted steps (each is announced before running):
#   1. Show the cluster state: no ClusterCatalogs, no ClusterExtensions.
#   2. Show the bundle image we will install from.
#   3. Apply the ClusterExtension with sourceType: OCIImage.
#   4. Watch installation progress and conditions.
#   5. Show the installed resources: CRD, deployment, service account, RBAC.
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

# Idempotent reset so the demo can be re-recorded from a clean slate.
$K delete clusterextension $DEMO_PACKAGE --ignore-not-found >/dev/null 2>&1 || true
$K wait --for=delete clusterextension/$DEMO_PACKAGE --timeout=120s >/dev/null 2>&1 || true
$K delete namespace $INSTALL_NAMESPACE --ignore-not-found --timeout=60s >/dev/null 2>&1 || true

say "1. Starting point: an OLMv1 cluster with no catalogs and no extensions"
cmd "$K get clustercatalogs 2>&1 | head -2"
cmd "$K get clusterextensions 2>&1 | head -2"

say "2. The install source is a plain registry+v1 bundle image"
cmd "skopeo inspect --insecure-policy --tls-verify=false docker://$REGISTRY_LOCAL_HOST/bundles/$DEMO_PACKAGE-bundle:v$DEMO_VERSION | jq -r '.Labels, .Digest'"
cmd "cat $SCRIPT_DIR/manifests/clusterextension.yaml"

say "3. Create the install namespace, then apply the ClusterExtension pointing directly at the bundle image"
cmd "$K create namespace $INSTALL_NAMESPACE --dry-run=client -o yaml | $K apply -f -"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension.yaml"

say "4. Watch installation progress"
waitfor "$K wait --for=condition=Available clusterextension/$DEMO_PACKAGE --timeout=300s || true"
cmd "$K get clusterextension $DEMO_PACKAGE -o yaml | sed -n '/status:/,\$p'"

say "5. Installed resources are owned and labeled by the extension"
cmd "$K get crd kubecondemos.demo.kubecon.io"
cmd "$K -n $INSTALL_NAMESPACE get all,sa,role,rolebinding"
cmd "$K get clusterobjectdeployments"
cmd "$K get clusterobjectsets"

say "6. Exercise the operator's API"
cmd "cat $SCRIPT_DIR/manifests/kubecondemo-example.yaml"
cmd "$K apply -f $SCRIPT_DIR/manifests/kubecondemo-example.yaml"
cmd "$K -n $INSTALL_NAMESPACE get kubecondemos"
cmd "$K -n $INSTALL_NAMESPACE get pods -l app=$DEMO_PACKAGE"

say "7. Delete the ClusterExtension; managed resources are cleaned up"
cmd "$K delete clusterextension $DEMO_PACKAGE"
waitfor "$K wait --for=delete clusterextension/$DEMO_PACKAGE --timeout=120s || true"
cmd "$K get crd kubecondemos.demo.kubecon.io 2>/dev/null || echo 'CRD removed with the extension'"
cmd "$K -n $INSTALL_NAMESPACE get all 2>/dev/null || echo 'install namespace contents removed'"

say "Demo complete"
