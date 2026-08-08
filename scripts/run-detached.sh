#!/usr/bin/env bash
# Run AMI fully detached (background) with nohup.
# Wraps run-standalone.sh for fire-and-forget execution.
#
# Usage:
#   ./run-detached.sh --prompt "Fix the bug" [all run-standalone.sh options]
#
# Prints the PID and output file locations, then returns immediately.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-./ami-output}"
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
NOHUP_LOG="$OUTPUT_DIR/nohup-${TIMESTAMP}.log"

echo "Starting AMI detached..."
echo "  nohup log: $NOHUP_LOG"

nohup bash "$SCRIPT_DIR/run-standalone.sh" "$@" --output-dir "$OUTPUT_DIR" \
  > "$NOHUP_LOG" 2>&1 &

PID=$!
echo "  PID: $PID"
echo ""
echo "Monitor with:"
echo "  tail -f $NOHUP_LOG"
echo "  kill $PID  # to stop"
