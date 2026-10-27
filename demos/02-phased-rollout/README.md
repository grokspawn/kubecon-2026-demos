# Demo 2 — Inspect phased resource rollouts

Shows the ClusterObjectSet machinery behind a ClusterExtension install:
ordered phases, readiness gating, blocked-rollout status with per-object
detail, and recovery when the blocker is resolved. This maps to slide 6 of
the talk ("Inspect phased resource rollouts").

The ClusterObjectSet API and the Boxcutter runtime are in active
development upstream and controlled by the `BoxcutterRuntime` feature
gate, which the demo cluster enables.

## What the audience sees

1. A direct bundle install (as in demo 1) creating a ClusterObjectSet.
2. The revision's spec: phases in order, with readiness probes.
3. A deliberately blocked rollout — the operator pod requires a ConfigMap
   that does not exist — with the pod stuck in
   `CreateContainerConfigError`, the owning phase unable to stabilize,
   and `status.observedPhases` reporting the failure detail.
4. Creating the missing ConfigMap; the phase stabilizes and the
   ClusterExtension reports Ready.
5. Cleanup.

## Prerequisites

Demo 1's environment must be running (cluster, OLMv1 with experimental
gates, in-cluster registry): run
`../01-direct-bundle-install/setup.sh` first, then `./setup.sh` here.

## Run

```bash
./setup.sh
./run.sh
./record.sh
```

## Design notes

- The blocking mechanism is a required-but-withheld ConfigMap volume. It
  needs no controller cooperation: the kubelet refuses to create the
  container, the deployment's readiness probe cannot pass, and the
  ClusterObjectSet phase reports it. Any real-world blocker (image pull
  failure, failing probe, missing dependency) produces the same
  observability.
- The `status.observedPhases` display benefits from the recent upstream
  enrichment (status, completedAt, message, per-object details).
- Upstream also supports `spec.progressDeadlineMinutes`, which turns a
  stalled rollout into an explicit `ProgressDeadlineExceeded` condition;
  the recorded demo shows the blocked-then-recovered path instead, which
  is the more useful story.
