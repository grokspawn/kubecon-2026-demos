#!/usr/bin/env bash
# Capture demo 2 as a loopable asciinema cast.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$SCRIPT_DIR/recordings/demo-02.cast}"
mkdir -p "$(dirname "$OUT")"
asciinema rec --command "$SCRIPT_DIR/run.sh" --overwrite --idle-time-limit 2 "$OUT"
echo "Cast written to $OUT"
