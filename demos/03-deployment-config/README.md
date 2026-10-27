# Demo 3 — User control of extension deployments

Shows the operator-author / user configuration exchange from slide 7 of
the talk: the user applies a ClusterExtension with
`spec.config.inline.deploymentConfig`, and the rendered operator
Deployment carries those values. Configuration outside the supported
subset is rejected with a specific validation error.

The inline configuration mechanism is controlled by the
`DeploymentConfig` feature gate, which the demo cluster enables. For
registry+v1 bundles the supported subset is a frozen JSON schema derived
from OLMv0's SubscriptionConfig: `nodeSelector`, `tolerations`,
`resources`, `envFrom`, `env`, `volumes`, `volumeMounts`, `affinity` and
`annotations`, plus `watchNamespace`. The v0 `selector` field was never
used by the v0 controller and is deliberately excluded.

## What the audience sees

1. One ClusterExtension with inline `deploymentConfig`: an environment
   variable, resource requests/limits and a node selector.
2. The resulting Deployment template containing exactly those values.
3. An attempt to set the excluded `selector` field: the resource is
   accepted by the API server, but reconciliation stops with an explicit
   `InvalidConfiguration` condition naming the unknown field —
   invalid configuration never reaches the cluster's workloads.
4. Cleanup.

## Prerequisites

Demo 1's environment must be running (this demo reuses demo 1's bundle
image and registry): run `../01-direct-bundle-install/setup.sh` first.

## Run

```bash
./run.sh
./record.sh
```
