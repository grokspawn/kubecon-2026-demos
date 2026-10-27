# Demo 4 shared environment.

# Pinned released versions — the same pins library-olm's own e2e uses.
export OLM_V0_VERSION="v0.46.0"
export OLM_V1_VERSION="v1.12.0"
export OLM_V1_INSTALL_SHA256="5c3c86e6d54b21ae7b0b566145ef703f8230e3f4cf4326541d42015a2a195970"

# Dedicated kind cluster (separate from demos 1-3).
export KIND_CLUSTER="kubecon-migration"
export KUBECONFIG="${KUBECONFIG:-$HOME/devel/kubecon-2026-demos/demos/04-migration/.kubeconfig}"
export KIND_NODE_IMAGE="kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"

# library-olm task clone (branch kubecon-2026-demo, tracks upstream main).
export LIBOLM_REPO_DIR="${LIBOLM_REPO_DIR:-$HOME/devel/agent-playground/kubecon-library-olm}"
export LIBOLM_BRANCH="kubecon-2026-demo"
export MIGRATE_CATALOGS_BIN="$LIBOLM_REPO_DIR/bin/migrate-catalogs-v0-to-v1"
export MIGRATE_OPERATORS_BIN="$LIBOLM_REPO_DIR/bin/migrate-operators-v0-to-v1"

# The migrated operator: available from the operatorhubio CatalogSource
# that OLMv0 installs by default; advertises AllNamespaces support.
export OPERATOR_NAMESPACE="migration-demo"
export SUBSCRIPTION_NAME="ecr-secret-operator"
export PACKAGE_NAME="ecr-secret-operator"
