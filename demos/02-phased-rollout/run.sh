#!/usr/bin/env bash
# Demo 2: observe phased resource rollout through the ClusterObjectDeployment.
#
# The rollout model: the operator-controller applies one
# ClusterObjectDeployment (COD) per ClusterExtension; the COD controller
# owns the revision lifecycle, cutting immutable ClusterObjectSet (COS)
# revisions from the COD's template and managing rollout progress,
# archival and history pruning.
#
# Scripted steps:
#   1. Install the rollout demo operator (direct bundle, as in demo 1).
#   2. Inspect the ClusterObjectDeployment: one top-level object for the
#      extension, carrying the desired content template and
#      revisionHistoryLimit.
#   3. The COD controller cuts a ClusterObjectSet revision with ordered
#      phases and readiness gates.
#   4. Readiness blocks the rollout: the pod requires a ConfigMap the demo
#      withholds. The COD's Progressing condition reflects the impeded
#      rollout; the COS revision's observedPhases carries per-object
#      detail.
#   5. Create the missing ConfigMap; the revision stabilizes and the COD
#      reports the rollout complete and available.
#   6. Change the extension's deployment configuration: the COD cuts a new
#      revision, archives the previous one, and prunes history — the
#      revision lifecycle the COD controller now owns.
#   7. Clean up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../01-direct-bundle-install/env.sh
source "$SCRIPT_DIR/../01-direct-bundle-install/env.sh"

EXT_NAME="kubecon-rollout-operator"
INSTALL_NS="kubecon-rollout-system"
COD="$EXT_NAME"

say()  { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()  { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"

# Idempotent reset so the demo can be re-recorded from a clean slate.
$K delete clusterextension $EXT_NAME --ignore-not-found >/dev/null 2>&1 || true
$K wait --for=delete clusterextension/$EXT_NAME --timeout=180s >/dev/null 2>&1 || true
$K delete namespace $INSTALL_NS --ignore-not-found --timeout=60s >/dev/null 2>&1 || true

say "1. Install the rollout demo operator"
cmd "$K create namespace $INSTALL_NS --dry-run=client -o yaml | $K apply -f -"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension.yaml"
sleep 5

say "2. One ClusterObjectDeployment carries the extension's desired content"
cmd "$K get clusterobjectdeployments"
cmd "$K get clusterobjectdeployment $COD -o yaml | sed -n '/spec:/,/status:/p' | head -30"

say "3. The COD controller cuts an immutable ClusterObjectSet revision with ordered phases"
cmd "$K get clusterobjectsets"
COS="$($K get clusterobjectsets -o name | grep "/$EXT_NAME-" | head -1 | cut -d/ -f2)"
cmd "$K get clusterobjectset $COS -o jsonpath='{.spec.phases}' | jq -c '[.[] | .name]'"

say "4. Readiness blocks the rollout: the pod needs a ConfigMap we have not created"
cmd "$K -n $INSTALL_NS get pods || true"
cmd "$K -n $INSTALL_NS describe pod -l app=$EXT_NAME | tail -8"
cmd "$K get clusterobjectdeployment $COD -o jsonpath='{.status.conditions}' | jq -c '[.[] | {type, status, reason, message}]'"
cmd "$K get clusterobjectset $COS -o jsonpath='{.status.observedPhases}' | jq -c '[.[] | select(.status != \"Ready\") | {name, status, message}]'"

say "5. Create the missing ConfigMap; the rollout completes"
cmd "$K apply -f $SCRIPT_DIR/manifests/release-gate.yaml"
cmd "$K wait --for=condition=Available clusterextension/$EXT_NAME --timeout=180s"
cmd "$K get clusterobjectdeployment $COD -o jsonpath='{.status.conditions}' | jq -c '[.[] | {type, status, reason}]'"
cmd "$K -n $INSTALL_NS get pods"

say "6. A configuration change cuts a new revision; the old one archives"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension-rollout-update.yaml"
sleep 15
cmd "$K get clusterobjectsets"
cmd "$K get clusterobjectdeployment $COD -o jsonpath='{.status.conditions}' | jq -c '[.[] | select(.type==\"Progressing\")]'"
cmd "$K -n $INSTALL_NS get deployment kubecon-rollout-operator -o jsonpath='{.spec.template.spec.containers[0].env}'; echo"

say "7. Clean up"
cmd "$K delete clusterextension $EXT_NAME"
cmd "$K wait --for=delete clusterextension/$EXT_NAME --timeout=120s || true"

say "Demo complete"
