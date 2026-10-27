#!/usr/bin/env bash
# Demo 1 teardown: remove demo resources, the kind cluster, and the
# registry port-forward. Leaves the task clone untouched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

if [ -f "$SCRIPT_DIR/.registry-pf-pid" ]; then
  PF_PID="$(cat "$SCRIPT_DIR/.registry-pf-pid")"
  if kill -0 "$PF_PID" 2>/dev/null; then
    step "Stopping registry port-forward (pid $PF_PID)"
    kill "$PF_PID" 2>/dev/null || true
  fi
  rm -f "$SCRIPT_DIR/.registry-pf-pid"
fi

step "Deleting kind cluster $KIND_CLUSTER"
cd "$OPCON_REPO_DIR"
make "kind-clean-$KIND_CLUSTER" 2>/dev/null || kind delete cluster --name "$KIND_CLUSTER" 2>/dev/null || true

step "Teardown complete"
