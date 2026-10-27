#!/usr/bin/env bash
# Capture the demo as a loopable asciinema cast.
# Usage: ./record.sh [output.cast]   (default: recordings/demo-01.cast)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$SCRIPT_DIR/recordings/demo-01.cast}"
mkdir -p "$(dirname "$OUT")"

# A comfortable typing/scrolling pace for presentation playback.
export ASCIINEMA_SPEED=1
asciinema rec \
  --command "$SCRIPT_DIR/run.sh" \
  --overwrite \
  --idle-time-limit 2 \
  "$OUT"
echo "Cast written to $OUT"
echo "Replay with: asciinema play $OUT"
