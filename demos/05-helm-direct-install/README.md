# Demo 5 — Install a Helm chart directly (design; implementation in progress)

The evolution path from demo 1: the same direct-install mechanism, pointed
at a chart's OCI artifact instead of a registry+v1 bundle image. This is
demo-scope exploration of the `helm+v2` direction recorded in the Helm
brief — it is not upstream functionality and makes no catalog/lifecycle
claims. Maps to slide 10 of the talk ("Planned Helm content support").

Implementation lives on the grokspawn fork branch
`kubecon-2026-demo-helm-direct`, stacked above
`kubecon-2026-demo-direct-bundle` (which carries upstream PR #2907).

## Design

The direct installer is source-sniffing: the OCI image is pulled into a
filesystem and its content is identified. The evolution adds a second
sniffed content type:

- `Chart.yaml` at the root of the pulled artifact (standard Helm chart
  OCI layout) → Helm rendering path
- registry+v1 layout (`manifests/` + `metadata/`) → existing path

The Helm path:

1. Load the chart with the Helm chart loader.
2. Merge user values from `spec.config.inline` (the same inline config
   mechanism as demo 3; values validated against the chart's
   `values.schema.json` when present).
3. Render with the restricted deterministic subset from the Helm brief:
   reject `helm.sh/hook` and `helm.sh/resource-policy: keep` annotations,
   and reject templates using non-deterministic functions
   (random/uuid/time/env lookup) — with clear errors, not silent skips.
4. Feed the rendered objects into the existing ClusterObjectSet
   machinery: phased rollout, readiness, ownership and cleanup identical
   to registry+v1 content.

Extension points (verified on the branch):

- `internal/operator-controller/resolve/ociimage.go` — the direct
  resolver; content sniffing happens in `bundleFromFS` via
  `rukpak/bundle/source.FromFS`
- `internal/operator-controller/applier/provider.go` — the
  `ManifestProvider` interface; `RegistryV1ManifestProvider` is the
  registry+v1 implementation
- `internal/operator-controller/applier/boxcutter.go` —
  `ClusterObjectSetGenerator.GenerateRevision(ctx, bundleFS, ext, ...)`
  consumes the pulled filesystem

## What the audience will see

1. A standard chart pushed with `helm push` (or `oras`) to the demo
   registry — no operator-bundle wrapper.
2. One `ClusterExtension` with `sourceType: OCIImage` pointing at the
   chart artifact, plus inline values.
3. The chart rendered and installed through OLM's phased lifecycle; the
   resulting objects owned and cleaned up with the extension.
4. Determinism boundaries: a chart using `helm.sh/hook` (or a changing
   template function) rejected with a specific error.

## Status

- [x] Branch `kubecon-2026-demo-helm-direct` created and pushed
- [x] Chart sniffing in the direct resolver (extracted charts and
      standard `helm push` tgz artifacts)
- [x] HelmManifestProvider with the restricted subset
- [x] Inline values merge and values.schema.json validation
- [x] Unit tests (sniffing, both chart layouts, rendering, schema
      validation, hook/keep/function/dependency rejections, dispatch)
- [x] Demo content: a small self-contained chart (CRD in templates/,
      values schema) plus a non-compliant chart for the rejection beats
- [x] run.sh + recording (pending cluster validation)

Implementation commit: `9973f48b` on
`kubecon-2026-demo-helm-direct` (stacked on the direct-bundle branch).
