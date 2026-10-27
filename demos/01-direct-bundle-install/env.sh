# Shared environment for the direct bundle install demo.

# The operator-controller task clone (branch kubecon-2026-demo-direct-bundle).
# Pinned commit is recorded in the demos repo README; setup.sh verifies it.
export OPCON_REPO_DIR="${OPCON_REPO_DIR:-$HOME/devel/agent-playground/kubecon-oc-direct-bundle}"
export OPCON_BRANCH="kubecon-2026-demo-direct-bundle"
export OPCON_EXPECTED_COMMIT="a33551f4e42d858056cb8d8191f9a70f4dcc80d5"

# kind cluster created by `make experimental-e2e-setup` (the stem of the
# pattern rules). Kubeconfig is exported by the repo's Makefile chain.
export KIND_CLUSTER="operator-controller-experimental-e2e"
export KUBECONFIG="${KUBECONFIG:-$OPCON_REPO_DIR/.kubeconfig/$KIND_CLUSTER.kubeconfig}"

# In-cluster registry (mirrors the repo's e2e testregistry pattern):
# a registry:3 deployment whose TLS certificate is issued by the olmv1-ca
# ClusterIssuer, which the operator-controller already trusts for image
# pulls via --pull-cas-dir=/var/ca-certs.
export REGISTRY_NAMESPACE="kubecon-demo-registry"
export REGISTRY_NAME="docker-registry"
export REGISTRY_SERVICE_DNS="$REGISTRY_NAME.$REGISTRY_NAMESPACE.svc.cluster.local:5000"
export REGISTRY_LOCAL_PORT="${REGISTRY_LOCAL_PORT:-55000}"
export REGISTRY_LOCAL_HOST="localhost:$REGISTRY_LOCAL_PORT"

# Demo operator content.
export BUNDLE_REF="$REGISTRY_SERVICE_DNS/bundles/kubecon-demo-operator-bundle:v0.1.0"
export OPERATOR_REF="$REGISTRY_SERVICE_DNS/operators/kubecon-demo-operator:v0.1.0"
export DEMO_PACKAGE="kubecon-demo-operator"
export DEMO_VERSION="0.1.0"
export INSTALL_NAMESPACE="kubecon-demo-system"
