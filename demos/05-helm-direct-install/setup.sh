#!/usr/bin/env bash
# Demo 5 setup: rebuilds the demo cluster from the helm-direct branch
# (demo 1's setup with overridden branch pins), then packages and pushes
# the demo charts as standard chart OCI artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$SCRIPT_DIR/env.sh"

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

step "Building the cluster from $OPCON_BRANCH (demo 1 setup with overridden pins)"
# Demo 1's setup is idempotent: it deletes and recreates the kind cluster,
# builds the operator-controller image from the checked-out branch and
# deploys OLMv1 with the experimental feature gates, then starts the
# in-cluster demo registry.
"$SCRIPT_DIR/../01-direct-bundle-install/setup.sh"

step "Packaging and pushing the demo charts"
# Standard chart OCI artifacts (the `helm push` shape: cncf.helm config
# blob + chart tar+gzip layer), assembled as OCI layouts and pushed with
# skopeo, which handles the demo registry's TLS from the host. See
# make-chart-layout.py.
work="$(mktemp -d)"
push_chart() { # $1=chart dir $2=layout name $3=tag $4=remote path:tag
  python3 "$SCRIPT_DIR/make-chart-layout.py" "$1" "$work/$2" "$3"
  skopeo copy --insecure-policy --dest-tls-verify=false "oci:$work/$2:$3" "docker://$REGISTRY_LOCAL_HOST/$4"
  rm -rf "$work/$2"
}
push_chart "$SCRIPT_DIR/chart" kubecon-chart-demo 0.4.0 charts/kubecon-chart-demo:0.4.0
push_chart "$SCRIPT_DIR/chart-bad" kubecon-chart-bad 0.1.0 charts/kubecon-chart-bad:0.1.0
rm -rf "$work"

step "Demo 5 content ready"
echo "Good chart: $CHART_REF"
echo "Bad chart:  $BAD_CHART_REF"
echo "Run ./run.sh to execute the demo."
