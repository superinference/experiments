#!/usr/bin/env bash
# Compare results across models for a given language.
#
# Usage: ./compare-models.sh <language>
# Example: ./compare-models.sh go

set -euo pipefail

LANG="${1:?Usage: $0 <language>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVAL_BASE="$SCRIPT_DIR/../../swebench/$LANG/eval-results"
RESULTS_BASE="$SCRIPT_DIR/../../swebench/$LANG/results"
JSONL_FILE="$SCRIPT_DIR/../../swebench/$LANG/data/swebench-multilang-${LANG}.jsonl"

if [[ ! -d "$EVAL_BASE" ]]; then
  echo "ERROR: No eval-results at $EVAL_BASE" >&2
  exit 1
fi

TOTAL=0
if [[ -f "$JSONL_FILE" ]]; then
  TOTAL=$(wc -l < "$JSONL_FILE")
fi

echo "=== Model Comparison: SWE-bench $LANG ($TOTAL instances) ==="
echo ""
printf "%-30s %8s %8s %8s %10s\n" "Model" "Resolved" "Eval'd" "Rate" "Accuracy"
printf "%-30s %8s %8s %8s %10s\n" "-----" "--------" "------" "----" "--------"

for model_dir in "$EVAL_BASE"/*/; do
  model_slug=$(basename "$model_dir")
  [[ "$model_slug" == run* ]] && continue

  resolved=0
  evaluated=0
  for d in "$model_dir"/*/; do
    name=$(basename "$d")
    [[ "$name" == run* || "$name" == failed* ]] && continue
    [[ -f "${d}report.json" ]] || continue
    evaluated=$((evaluated + 1))
    r=$(python3 -c "import json; print(json.load(open('${d}report.json')).get('resolved','?'))" 2>/dev/null)
    [[ "$r" == "True" ]] && resolved=$((resolved + 1))
  done

  if [[ $TOTAL -gt 0 ]]; then
    rate=$(python3 -c "print(f'{$resolved*100/$TOTAL:.1f}%')" 2>/dev/null)
  else
    rate="?"
  fi
  if [[ $evaluated -gt 0 ]]; then
    accuracy=$(python3 -c "print(f'{$resolved*100/$evaluated:.1f}%')" 2>/dev/null)
  else
    accuracy="?"
  fi

  printf "%-30s %5d/%d %5d/%d %8s %10s\n" "$model_slug" "$resolved" "$TOTAL" "$evaluated" "$TOTAL" "$rate" "$accuracy"
done

echo ""
echo "Rate = resolved / total instances"
echo "Accuracy = resolved / evaluated instances"
