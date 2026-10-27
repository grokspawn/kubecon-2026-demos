# Demo 5 environment: the direct Helm chart install runs on the
# kubecon-2026-demo-helm-direct branch, which carries the content-sniffed
# Helm rendering path stacked on the direct bundle installer.
# OPCON_BRANCH/OPCON_EXPECTED_COMMIT are consumed by demo 1's env.sh
# (sourced below), whose defaults they override.
export OPCON_BRANCH="kubecon-2026-demo-helm-direct"
export OPCON_EXPECTED_COMMIT="9973f48b6e8936c56d3a50558e12c4bfd91b9540"

# shellcheck source=../01-direct-bundle-install/env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../01-direct-bundle-install/env.sh"

export CHART_REF="$REGISTRY_SERVICE_DNS/charts/kubecon-chart-demo:0.4.0"
export BAD_CHART_REF="$REGISTRY_SERVICE_DNS/charts/kubecon-chart-bad:0.1.0"
export HELM_INSTALL_NAMESPACE="kubecon-chart-system"
