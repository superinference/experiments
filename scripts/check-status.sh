#!/usr/bin/env bash
# Check status of a running SWE-bench experiment.
#
# Usage: ./check-status.sh <language> [model-slug]
# Example: ./check-status.sh go claude-opus-4-6
#          ./check-status.sh java claude-sonnet-4-6

set -euo pipefail

LANG="${1:?Usage: $0 <language> [model-slug]}"
MODEL_SLUG="${2:-claude-opus-4-6}"
MODEL_SLUG="$(echo "$MODEL_SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g')"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWEBENCH_DIR="$SCRIPT_DIR/../../swebench/$LANG"

if [[ ! -d "$SWEBENCH_DIR" ]]; then
  echo "ERROR: Directory not found: $SWEBENCH_DIR" >&2
  exit 1
fi

RESULTS_DIR="$SWEBENCH_DIR/results/$MODEL_SLUG"
EVAL_DIR="$SWEBENCH_DIR/eval-results/$MODEL_SLUG"
JSONL_FILE="$SWEBENCH_DIR/data/swebench-multilang-${LANG}.jsonl"

# Total instances
TOTAL=0
if [[ -f "$JSONL_FILE" ]]; then
  TOTAL=$(wc -l < "$JSONL_FILE")
fi

# Count results
RESULT_COUNT=0
if [[ -d "$RESULTS_DIR" ]]; then
  RESULT_COUNT=$(ls -d "$RESULTS_DIR"/*/ 2>/dev/null | grep -v '/run' | wc -l)
fi

# Count evaluated and resolved
EVAL_COUNT=0
RESOLVED=0
FAILED=0
CLOSE_GAP=0
REGRESSION=0
if [[ -d "$EVAL_DIR" ]]; then
  for d in "$EVAL_DIR"/*/; do
    name=$(basename "$d")
    [[ "$name" == run* || "$name" == failed* ]] && continue
    [[ -f "${d}report.json" ]] || continue
    EVAL_COUNT=$((EVAL_COUNT + 1))
    r=$(python3 -c "
import json
d = json.load(open('${d}report.json'))
if d.get('resolved'):
    print('RESOLVED')
else:
    f2p = d.get('FAIL_TO_PASS', {})
    f2p_s = len(f2p.get('success', []))
    f2p_f = len(f2p.get('failure', []))
    p2p_f = len(d.get('PASS_TO_PASS', {}).get('failure', []))
    if p2p_f > 0:
        print('REGRESSION')
    elif f2p_s > 0:
        print('CLOSE_GAP')
    else:
        print('FAILED')
" 2>/dev/null)
    case "$r" in
      RESOLVED) RESOLVED=$((RESOLVED + 1)) ;;
      CLOSE_GAP) CLOSE_GAP=$((CLOSE_GAP + 1)) ;;
      REGRESSION) REGRESSION=$((REGRESSION + 1)) ;;
      FAILED) FAILED=$((FAILED + 1)) ;;
    esac
  done
fi

# Active containers
AGENT_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -c "swebench-${LANG}" || true)
EVAL_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null | grep -c "git-launch" || true)

# Processes
PARALLEL_PID=$(pgrep -f "run-all-parallel.*${LANG}" 2>/dev/null | head -1 || true)
MONITOR_PID=$(pgrep -f "autonomous.*${LANG}" 2>/dev/null | head -1 || true)

# Monitor log
LOG_FILE="/tmp/${LANG}-opus-autonomous.log"
if [[ "$LANG" == "go" ]]; then
  LOG_FILE="/tmp/opus-autonomous.log"
fi

# Disk
DISK_FREE=$(df -h / | tail -1 | awk '{print $4}')
DISK_USED_PCT=$(df -h / | tail -1 | awk '{print $5}')

# ── output ──────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  SWE-bench $LANG — $MODEL_SLUG"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  %-20s %s\n" "Resolved:" "$RESOLVED / $TOTAL ($(python3 -c "print(f'{$RESOLVED*100/max($TOTAL,1):.1f}%')" 2>/dev/null))"
printf "║  %-20s %s\n" "Evaluated:" "$EVAL_COUNT / $TOTAL"
printf "║  %-20s %s\n" "Results:" "$RESULT_COUNT / $TOTAL"
printf "║  %-20s %s\n" "Remaining:" "$(( TOTAL - RESULT_COUNT )) instances"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  %-20s %s\n" "Close gaps:" "$CLOSE_GAP"
printf "║  %-20s %s\n" "Regressions:" "$REGRESSION"
printf "║  %-20s %s\n" "Failed:" "$FAILED"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  %-20s %s\n" "Agent containers:" "$AGENT_CONTAINERS"
printf "║  %-20s %s\n" "Eval containers:" "$EVAL_CONTAINERS"
printf "║  %-20s %s\n" "Pipeline PID:" "${PARALLEL_PID:-DEAD}"
printf "║  %-20s %s\n" "Monitor PID:" "${MONITOR_PID:-DEAD}"
printf "║  %-20s %s\n" "Disk free:" "$DISK_FREE ($DISK_USED_PCT used)"
echo "╠══════════════════════════════════════════════════════════╣"
if [[ -f "$LOG_FILE" ]]; then
  echo "║  Last log lines:"
  tail -3 "$LOG_FILE" | while read line; do
    printf "║    %s\n" "$line"
  done
fi
echo "╚══════════════════════════════════════════════════════════╝"
