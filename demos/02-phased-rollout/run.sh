#!/usr/bin/env bash
# Demo 2: observe phased resource rollout and readiness blocking.
#
# Scripted steps:
#   1. Install the rollout demo operator (direct bundle, as in demo 1).
#   2. Inspect the ClusterObjectSet the runtime created for the extension:
#      ordered phases and readiness probes.
#   3. The deployment phase cannot stabilize: its pod requires a ConfigMap
#      the demo withholds. Show the blocked status and per-object detail.
#   4. Create the missing ConfigMap; watch the phase stabilize and the
#      ClusterExtension become Ready.
#   5. Clean up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../01-direct-bundle-install/env.sh
source "$SCRIPT_DIR/../01-direct-bundle-install/env.sh"

EXT_NAME="kubecon-rollout-operator"
INSTALL_NS="kubecon-rollout-system"
COS="$EXT_NAME-1"

say()  { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()  { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"

say "1. Install the rollout demo operator"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension.yaml"
sleep 5

say "2. The runtime expresses the install as a ClusterObjectSet with ordered phases"
cmd "$K get clusterobjectsets"
cmd "$K get clusterobjectset $COS -o jsonpath='{.spec.phases}' | jq ."

say "3. Readiness blocks the rollout: the pod needs a ConfigMap we have not created"
cmd "$K -n $INSTALL_NS get pods || true"
cmd "$K -n $INSTALL_NS describe pod -l app=$EXT_NAME | tail -15"
cmd "$K get clusterobjectset $COS -o jsonpath='{.status.observedPhases}' | jq ."
cmd "$K get clusterextension $EXT_NAME -o jsonpath='{.status.conditions}' | jq ."

say "4. Create the missing ConfigMap; the rollout completes"
cmd "$K apply -f $SCRIPT_DIR/manifests/release-gate.yaml"
cmd "$K wait --for=condition=Ready clusterextension/$EXT_NAME --timeout=180s"
cmd "$K get clusterobjectset $COS -o jsonpath='{.status.observedPhases}' | jq ."
cmd "$K -n $INSTALL_NS get pods"

say "5. Clean up"
cmd "$K delete clusterextension $EXT_NAME"
cmd "$K wait --for=delete clusterextension/$EXT_NAME --timeout=120s || true"

say "Demo complete"
