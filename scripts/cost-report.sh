#!/usr/bin/env bash
# Generate a cost report for a SWE-bench experiment.
#
# Usage: ./cost-report.sh <language> [model-slug]
# Example: ./cost-report.sh go claude-opus-4-6

set -euo pipefail

LANG="${1:?Usage: $0 <language> [model-slug]}"
MODEL_SLUG="${2:-claude-opus-4-6}"
MODEL_SLUG="$(echo "$MODEL_SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g')"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../../swebench/$LANG/results/$MODEL_SLUG"
EVAL_DIR="$SCRIPT_DIR/../../swebench/$LANG/eval-results/$MODEL_SLUG"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "ERROR: Results not found at $RESULTS_DIR" >&2
  exit 1
fi

python3 -c "
import json, os

results_dir = '$RESULTS_DIR'
eval_dir = '$EVAL_DIR'
model_slug = '$MODEL_SLUG'

stats = []
for inst in sorted(os.listdir(results_dir)):
    if inst.startswith('run'): continue
    jf = os.path.join(results_dir, inst, f'ami-{model_slug}.json')
    if not os.path.isfile(jf): continue
    try:
        d = json.load(open(jf))
    except:
        continue

    resolved = None
    rpt = os.path.join(eval_dir, inst, 'report.json')
    if os.path.isfile(rpt):
        try:
            resolved = json.load(open(rpt)).get('resolved')
        except:
            pass

    stats.append({
        'inst': inst,
        'exit': d.get('exitReason', '?'),
        'turns': d.get('turns', 0),
        'elapsed_min': d.get('elapsedMs', 0) / 60000,
        'cost': d.get('estimatedCost', 0),
        'prompt_t': d.get('tokens', {}).get('prompt', 0),
        'comp_t': d.get('tokens', {}).get('completion', 0),
        'total_t': d.get('tokens', {}).get('total', 0),
        'resolved': resolved,
    })

if not stats:
    print('No results found.')
    exit()

total_cost = sum(s['cost'] for s in stats)
total_time = sum(s['elapsed_min'] for s in stats)
total_input = sum(s['prompt_t'] for s in stats)
total_output = sum(s['comp_t'] for s in stats)

completed = [s for s in stats if s['exit'] == 'completed']
timeouts = [s for s in stats if s['exit'] == 'timeout']
resolved = [s for s in stats if s['resolved'] == True]
unresolved = [s for s in stats if s['resolved'] == False]

print(f'=== Cost Report: {model_slug} ({len(stats)} instances) ===')
print()
print(f'Total cost:           \${total_cost:,.2f}')
print(f'Total time:           {total_time:,.0f} min ({total_time/60:,.1f} hours)')
print(f'Total input tokens:   {total_input:,}')
print(f'Total output tokens:  {total_output:,}')
print()

print(f'--- Per Instance ---')
print(f'Avg cost:             \${total_cost/len(stats):,.2f}')
print(f'Avg time:             {total_time/len(stats):,.1f} min')

if completed:
    cc = [s['cost'] for s in completed]
    ct = [s['elapsed_min'] for s in completed]
    print()
    print(f'--- Completed ({len(completed)}) ---')
    print(f'Avg cost:             \${sum(cc)/len(cc):,.2f}')
    print(f'Avg time:             {sum(ct)/len(ct):,.1f} min')

if timeouts:
    tc = [s['cost'] for s in timeouts]
    tt = [s['elapsed_min'] for s in timeouts]
    print()
    print(f'--- Timeout ({len(timeouts)}) ---')
    print(f'Avg cost:             \${sum(tc)/len(tc):,.2f}')
    print(f'Avg time:             {sum(tt)/len(tt):,.1f} min')
    print(f'Timeout overhead:     {sum(tc)/len(tc) / (sum(cc)/len(cc)) if completed and cc else 0:,.1f}x vs completed')

if resolved:
    rc = [s['cost'] for s in resolved]
    print()
    print(f'--- Resolved ({len(resolved)}) ---')
    print(f'Avg cost:             \${sum(rc)/len(rc):,.2f}')
    print(f'Total cost:           \${sum(rc):,.2f}')
    print(f'Cost per resolve:     \${total_cost/len(resolved):,.2f} (amortized over all instances)')

print()
print(f'--- Top 10 Most Expensive ---')
for s in sorted(stats, key=lambda x: -x['cost'])[:10]:
    status = 'R' if s['resolved'] else ('F' if s['resolved'] is False else '?')
    print(f'  [{status}] \${s[\"cost\"]:>8,.2f}  {s[\"elapsed_min\"]:>5.0f}min  {s[\"turns\"]:>3}t  {s[\"inst\"]}')
"
