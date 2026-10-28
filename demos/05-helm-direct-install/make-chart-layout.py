#!/usr/bin/env python3
"""Build a standard Helm chart OCI artifact as an OCI layout.

Reproduces the artifact shape produced by `helm push`: a config blob with
the cncf.helm config media type carrying the chart metadata, and a single
layer with the chart tar+gzip media type. The layout can then be pushed
to a registry with skopeo (which handles the demo registry's TLS from the
host), where the controller pulls it like any other OCI artifact.

Usage: make-chart-layout.py CHART_DIR LAYOUT_DIR TAG
"""
import gzip
import hashlib
import json
import os
import shutil
import subprocess
import sys


def parse_chart_meta(chart_dir):
    meta = {}
    with open(os.path.join(chart_dir, "Chart.yaml")) as f:
        for line in f:
            if ":" in line and not line.startswith((" ", "\t", "#")):
                key, value = line.split(":", 1)
                meta[key.strip()] = value.strip().strip('"').strip("'")
    for required in ("name", "version"):
        if required not in meta:
            raise SystemExit(f"Chart.yaml is missing required field: {required}")
    return meta


def write_blob(layout_dir, data):
    digest = hashlib.sha256(data).hexdigest()
    path = os.path.join(layout_dir, "blobs", "sha256", digest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return digest, len(data)


def main():
    chart_dir, layout_dir, tag = sys.argv[1], sys.argv[2], sys.argv[3]
    chart_dir = os.path.abspath(chart_dir)
    meta = parse_chart_meta(chart_dir)

    work = os.environ.get("CHART_WORK_DIR", "/tmp")
    subprocess.run(
        ["helm", "package", os.path.basename(chart_dir.rstrip("/")),
         "--version", meta["version"], "-d", work],
        cwd=os.path.dirname(chart_dir.rstrip("/")), check=True,
        stdout=subprocess.DEVNULL)
    tgz = os.path.join(work, f"{meta['name']}-{meta['version']}.tgz")
    with open(tgz, "rb") as f:
        layer = f.read()
    os.remove(tgz)

    if os.path.isdir(layout_dir):
        shutil.rmtree(layout_dir)
    os.makedirs(os.path.join(layout_dir, "blobs", "sha256"))

    # NOTE: standard `helm push` artifacts use the
    # application/vnd.cncf.helm.config.v1+json config media type. The
    # controller's image puller (containers/image) refuses image-specific
    # operations (unpacking) on such artifacts, so this demo assembles the
    # chart with a standard OCI image config instead; the chart layer
    # keeps the cncf.helm tar+gzip media type and the filesystem layout is
    # identical. Supporting cncf.helm configs in the puller is an open
    # item for the upstream helm-content design.
    diff_id = hashlib.sha256(gzip.decompress(layer)).hexdigest()
    config = json.dumps({
        "architecture": "arm64",
        "os": "linux",
        "config": {
            "Labels": {
                "org.opencontainers.image.title": meta["name"],
                "org.opencontainers.image.version": meta["version"],
            }
        },
        "rootfs": {"type": "layers", "diff_ids": [f"sha256:{diff_id}"]},
    }).encode()
    config_digest, config_size = write_blob(layout_dir, config)
    layer_digest, layer_size = write_blob(layout_dir, layer)

    manifest = {
        "schemaVersion": 2,
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "config": {
            "mediaType": "application/vnd.oci.image.config.v1+json",
            "digest": f"sha256:{config_digest}",
            "size": config_size,
        },
        "layers": [{
            "mediaType": "application/vnd.cncf.helm.chart.content.v1.tar+gzip",
            "digest": f"sha256:{layer_digest}",
            "size": layer_size,
        }],
    }
    manifest_data = json.dumps(manifest).encode()
    manifest_digest, manifest_size = write_blob(layout_dir, manifest_data)

    index = {
        "schemaVersion": 2,
        "manifests": [{
            "mediaType": "application/vnd.oci.image.manifest.v1+json",
            "digest": f"sha256:{manifest_digest}",
            "size": manifest_size,
            "annotations": {"org.opencontainers.image.ref.name": tag},
        }],
    }
    with open(os.path.join(layout_dir, "index.json"), "w") as f:
        json.dump(index, f)
    with open(os.path.join(layout_dir, "oci-layout"), "w") as f:
        f.write('{"imageLayoutVersion": "1.0.0"}')

    print(f"{meta['name']}-{meta['version']} -> {layout_dir} (tag {tag})")


if __name__ == "__main__":
    main()
