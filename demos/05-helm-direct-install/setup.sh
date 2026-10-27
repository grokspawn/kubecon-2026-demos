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
# helm package + oras push produce the standard chart OCI artifact layout
# (chart tgz layer with the cncf.helm media types), the same shape as
# `helm push` output. The registry's TLS certificate is issued for its
# in-cluster DNS name, so the host-side push uses --insecure.
push_chart() { # $1=chart dir $2=remote ref
  local dir="$1" ref="$2" version name archive meta
  name="$(basename "$dir")"
  version="$(sed -En 's/^version: *//p' "$dir/Chart.yaml" | tr -d '"')"
  archive="$(mktemp -t kubecon-chart-XXXXXX).tgz"
  helm package "$dir" --version "$version" -d "$(dirname "$archive")" >/dev/null
  mv "$(dirname "$archive")/${name}-${version}.tgz" "$archive"
  meta="$(mktemp -t kubecon-chart-meta-XXXXXX.json)"
  # Standard helm config blob: the Chart.yaml metadata as JSON.
  python3 -c "import json,sys; print(json.dumps({'name':'$name','version':'$version','apiVersion':'v2'}))" > "$meta"
  oras push --insecure \
    --config "$meta:application/vnd.cncf.helm.config.v1+json" \
    "$REGISTRY_LOCAL_HOST/${ref#*:}:${ref##*:}" \
    "$archive:application/vnd.cncf.helm.chart.content.v1.tar+gzip" 2>&1 | tail -1
  rm -f "$archive" "$meta"
}
push_chart "$SCRIPT_DIR/chart" "charts/kubecon-chart-demo:0.4.0"
push_chart "$SCRIPT_DIR/chart-bad" "charts/kubecon-chart-bad:0.1.0"

step "Demo 5 content ready"
echo "Good chart: $CHART_REF"
echo "Bad chart:  $BAD_CHART_REF"
echo "Run ./run.sh to execute the demo."
