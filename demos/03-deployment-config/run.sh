#!/usr/bin/env bash
# Demo 3: user control of extension deployments.
#
# Scripted steps:
#   1. Install demo 1's operator with an inline deploymentConfig: env,
#      resources and nodeSelector chosen by the user.
#   2. Show the rendered Deployment carrying the user's values.
#   3. Attempt a configuration outside the supported subset (selector);
#      validation rejects it with a specific error.
#   4. Clean up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../01-direct-bundle-install/env.sh
source "$SCRIPT_DIR/../01-direct-bundle-install/env.sh"

EXT_NAME="kubecon-demo-operator"
INSTALL_NS="kubecon-demo-system"

say()  { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()  { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"

say "1. Install with user-specified deployment configuration"
cmd "cat $SCRIPT_DIR/manifests/clusterextension-configured.yaml"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension-configured.yaml"
cmd "$K wait --for=condition=Ready clusterextension/$EXT_NAME --timeout=300s"

say "2. The rendered Deployment carries the user's values"
cmd "$K -n $INSTALL_NS get deployment kubecon-demo-operator -o yaml | sed -n '/template:/,/volumes:/p'"

say "3. Unsupported configuration is rejected"
cmd "$K apply -f $SCRIPT_DIR/manifests/clusterextension-invalid.yaml 2>&1 || true"

say "4. Clean up"
cmd "$K delete clusterextension $EXT_NAME"
cmd "$K wait --for=delete clusterextension/$EXT_NAME --timeout=120s || true"

say "Demo complete"
