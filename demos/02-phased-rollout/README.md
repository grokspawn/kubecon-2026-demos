# Demo 2 — Inspect phased resource rollouts

Shows the rollout machinery behind a ClusterExtension install through the
**ClusterObjectDeployment** model: the operator-controller applies one
ClusterObjectDeployment (COD) per extension; the COD controller owns the
revision lifecycle, cutting immutable ClusterObjectSet (COS) revisions
from the COD's template and managing rollout progress, archival and
history pruning (`revisionHistoryLimit`, default 5). This maps to slide 7
of the talk ("Inspect phased resource rollouts").

This is the current upstream architecture (operator-controller #3058,
"Apply a ClusterObjectDeployment instead of managing ClusterObjectSets",
merged 2026-10-28), replacing the earlier model where the
operator-controller managed COS revisions directly. ClusterObjectSets
remain as the immutable revision objects beneath the COD.

The ClusterObjectDeployment and Boxcutter runtime are in active
development upstream and controlled by the `BoxcutterRuntime` feature
gate, which the demo cluster enables.

## What the audience sees

1. A direct bundle install (as in demo 1) creating a
   ClusterObjectDeployment for the extension.
2. The COD's spec: desired content template and revision history limit.
3. The COD controller cutting a ClusterObjectSet revision with ordered
   phases and readiness gates.
4. A deliberately blocked rollout — the operator pod requires a ConfigMap
   that does not exist — with the COD's Progressing condition reflecting
   the impeded rollout and the revision's `observedPhases` reporting
   per-object failure detail.
5. Creating the missing ConfigMap; the revision stabilizes and the COD
   reports the rollout complete and available.
6. A deployment-config change cutting a new revision; the previous
   revision archives — the revision lifecycle the COD controller owns.
7. Cleanup.

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
  container, the deployment's readiness probe cannot pass, and the COD's
  Progressing condition plus the revision's `observedPhases` report it.
  Any real-world blocker produces the same observability.
- The impeded-rollout reasons on the COD's Progressing condition
  (RevisionPreconditionsNotMet, RevisionObjectCollision,
  RevisionInvalidSpecification, ProgressDeadlineExceeded) are new
  upstream work; the demo shows the blocked-then-recovered path, which is
  the most useful story.
