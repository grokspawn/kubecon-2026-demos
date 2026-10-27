#!/usr/bin/env bash
# Demo 5: install a Helm chart directly through the ClusterExtension API.
#
# Scripted steps:
#   1. Show the chart artifact: a standard chart OCI artifact, no
#      operator-bundle wrapper, no catalog.
#   2. Apply the ClusterExtension: sourceType OCIImage pointing at the
#      chart, values through spec.config.inline.
#   3. The chart is rendered with the user's values and installed through
#      OLM's phased lifecycle: CRD, service account and deployment are
#      managed objects of a ClusterObjectSet.
#   4. Determinism boundaries: a chart with a hook annotation and a random
#      template function is rejected with specific errors.
#   5. Deleting the ClusterExtension removes the rendered content,
#      including the CRD placed in templates/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

EXT_NAME="kubecon-chart-demo"
INSTALL_NS="$HELM_INSTALL_NAMESPACE"

say()  { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()  { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"

# Idempotent reset so the demo can be re-recorded.
$K delete clusterextension $EXT_NAME kubecon-chart-bad --ignore-not-found >/dev/null 2>&1 || true
$K delete namespace $INSTALL_NS --ignore-not-found --timeout=60s >/dev/null 2>&1 || true

say "1. The install source is a standard chart OCI artifact"
cmd "oras manifest fetch --insecure --pretty $REGISTRY_LOCAL_HOST/charts/kubecon-chart-demo:0.4.0 | head -25"
cmd "cat $SCRIPT_DIR/chart/Chart.yaml"
cmd "ls $SCRIPT_DIR/chart/templates/"

say "2. One ClusterExtension: chart ref plus inline values"
cmd "cat $SCRIPT_DIR/manifests/clusterextension-chart.yaml"
cmd "$K create namespace $INSTALL_NS --dry-run=client -o yaml | $K apply -f -"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension-chart.yaml"

say "3. The chart renders and installs through OLM's lifecycle"
cmd "$K wait --for=condition=Available clusterextension/$EXT_NAME --timeout=300s"
cmd "$K get clusterextension $EXT_NAME"
cmd "$K get clusterobjectsets"
cmd "$K get crd chartdemos.demo.kubecon.io"
cmd "$K -n $INSTALL_NS get deployment,sa"
cmd "$K -n $INSTALL_NS get deployment ${EXT_NAME}-chart -o jsonpath='{.spec.replicas}'; echo ' <- user-specified replicaCount'"
cmd "$K -n $INSTALL_NS get pods"

say "4. Charts outside the supported subset are rejected with specific errors"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension-bad.yaml"
sleep 5
cmd "$K get clusterextension kubecon-chart-bad -o jsonpath='{.status.conditions}' | jq -c '[.[] | select(.type==\"Progressing\")]'"

say "5. Cleanup removes the rendered content, including the CRD"
cmd "$K delete clusterextension $EXT_NAME kubecon-chart-bad --ignore-not-found"
cmd "$K wait --for=delete clusterextension/$EXT_NAME --timeout=120s || true"
cmd "$K get crd chartdemos.demo.kubecon.io 2>/dev/null || echo 'CRD removed with the extension'"

say "Demo complete"
