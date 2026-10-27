#!/usr/bin/env bash
# Demo 4: OLMv0 → OLMv1 migration with structured output.
#
# Scripted steps:
#   1. Starting point: an operator running under OLMv0 (Subscription/CSV),
#      with OLMv1 installed alongside but managing nothing.
#   2. Operator eligibility before catalog preparation: the check fails
#      because no ClusterCatalog exists yet — catalog migration comes first.
#   3. Migrate the CatalogSource to a ClusterCatalog.
#   4. Check the operator's migration readiness (human-readable).
#   5. The same check as JSON Lines — machine-readable, for automation.
#   6. Convert the operator to OLMv1 management.
#   7. Verify the result: ClusterExtension managing the operator, OLMv0
#      Subscription and InstallPlan removed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

say()  { printf '\n\033[1;35m### %s\033[0m\n' "$*"; }
cmd()  { printf '\033[1;36m$ %s\033[0m\n' "$*"; eval "$*"; }

K="kubectl --kubeconfig $KUBECONFIG"
CATALOGS_BIN="$MIGRATE_CATALOGS_BIN --kubeconfig $KUBECONFIG"
OPERATORS_BIN="$MIGRATE_OPERATORS_BIN --kubeconfig $KUBECONFIG"

say "1. Starting point: an OLMv0-managed operator, OLMv1 idle alongside it"
cmd "$K -n $OPERATOR_NAMESPACE get subscription,csv,deployment"
cmd "$K get clustercatalogs 2>/dev/null || echo 'No ClusterCatalogs yet'"
cmd "$K get clusterextensions 2>/dev/null || echo 'No ClusterExtensions yet'"

say "2. Eligibility check before catalog preparation fails with a clear reason"
cmd "$OPERATORS_BIN check $SUBSCRIPTION_NAME -n $OPERATOR_NAMESPACE || true"

say "3. Migrate the catalog: CatalogSource → ClusterCatalog"
cmd "$CATALOGS_BIN"
cmd "$K get clustercatalogs"

say "4. Check the operator's migration readiness"
cmd "$OPERATORS_BIN check --all"
cmd "$OPERATORS_BIN check $SUBSCRIPTION_NAME -n $OPERATOR_NAMESPACE"

say "5. The same check as structured output, for automation"
cmd "$OPERATORS_BIN check $SUBSCRIPTION_NAME -n $OPERATOR_NAMESPACE --output jsonl | tee /tmp/migration-check.jsonl | jq -c '.'"
cmd "jq -r 'select(.type==\"result\") | .data' /tmp/migration-check.jsonl >/dev/null 2>&1 && echo 'JSONL output is machine-parseable' || true"

say "6. Convert the operator to OLMv1 management"
cmd "$OPERATORS_BIN convert $SUBSCRIPTION_NAME -n $OPERATOR_NAMESPACE"

say "7. Verify the handoff"
cmd "$K get clusterextension"
cmd "$K -n $OPERATOR_NAMESPACE get clusterextension 2>/dev/null || true"
cmd "$K -n $OPERATOR_NAMESPACE get subscription,csv 2>/dev/null || echo 'OLMv0 Subscription and CSV are gone'"
cmd "$K -n $OPERATOR_NAMESPACE get deployment"
cmd "$K get clusterobjectsets 2>/dev/null || true"

say "Rollback is available if the migration needs to be undone"
cmd "$MIGRATE_OPERATORS_BIN --help | sed -n '1,25p'"

say "Demo complete"
