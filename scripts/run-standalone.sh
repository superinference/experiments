#!/usr/bin/env bash
# Run AMI standalone in fully detached mode on a local codebase.
#
# Usage:
#   ./run-standalone.sh --prompt "Fix the null pointer in auth.go" [options]
#   ./run-standalone.sh --prompt-file bug-report.md [options]
#
# Required env (one of):
#   AI_API_KEY                  API key for the model provider
#   ANTHROPIC_VERTEX_PROJECT_ID Vertex AI project (uses gcloud creds)
#
# Options:
#   --prompt <text>       Prompt text (required unless --prompt-file)
#   --prompt-file <path>  Read prompt from file
#   --model <model>       Model (default: claude-opus-4-6)
#   --max-turns <n>       Max turns (default: 100)
#   --output-dir <dir>    Output directory (default: ./ami-output)
#   --config <path>       AMI config file
#   --thinking <level>    off|low|medium|high|max (default: max)
#   --context <file>      Context file (repeatable)

set -euo pipefail

# ── defaults ────────────────────────────────────────────────────────
MODEL="${AI_MODEL:-claude-opus-4-6}"
MAX_TURNS=100
OUTPUT_DIR="./ami-output"
THINKING="max"
PROMPT=""
PROMPT_FILE=""
CONFIG_FILE=""
CONTEXT_FILES=()

# ── parse args ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --thinking) THINKING="$2"; shift 2 ;;
    --context) CONTEXT_FILES+=("$2"); shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROMPT" && -z "$PROMPT_FILE" ]]; then
  echo "ERROR: --prompt or --prompt-file required" >&2
  exit 1
fi

if [[ -n "$PROMPT_FILE" ]]; then
  PROMPT=$(cat "$PROMPT_FILE")
fi

# ── find AMI binary ────────────────────────────────────────────────
AMI_BINARY="${AMI_BINARY:-$HOME/.local/bin/ami}"
if [[ ! -f "$AMI_BINARY" ]]; then
  AMI_BINARY="$(command -v ami 2>/dev/null || true)"
fi
if [[ -z "$AMI_BINARY" || ! -f "$AMI_BINARY" ]]; then
  echo "ERROR: AMI binary not found. Set AMI_BINARY env var." >&2
  exit 1
fi

# ── build args ──────────────────────────────────────────────────────
MODEL_SLUG="$(echo "$MODEL" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g')"
mkdir -p "$OUTPUT_DIR"

AMI_ARGS=(
  --model "$MODEL"
  --prompt "$PROMPT"
  --max-turns "$MAX_TURNS"
  --thinking "$THINKING"
  --yolo
  --output-format jsonl
  --quiet
)

if [[ -n "$CONFIG_FILE" ]]; then
  AMI_ARGS+=(--config "$CONFIG_FILE")
fi

for cf in "${CONTEXT_FILES[@]}"; do
  AMI_ARGS+=(--context-file "$cf")
done

# API key
if [[ -n "${AI_API_KEY:-}" ]]; then
  AMI_ARGS+=(--api-key "$AI_API_KEY")
fi

# ── run ─────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
JSONL_FILE="$OUTPUT_DIR/ami-${MODEL_SLUG}-${TIMESTAMP}.jsonl"
STDERR_FILE="$OUTPUT_DIR/ami-${MODEL_SLUG}-${TIMESTAMP}.stderr.log"

echo "Starting AMI (model=$MODEL, max_turns=$MAX_TURNS, thinking=$THINKING)"
echo "Output: $JSONL_FILE"
echo "Stderr: $STDERR_FILE"
echo ""

"$AMI_BINARY" "${AMI_ARGS[@]}" 2>"$STDERR_FILE" | tee "$JSONL_FILE" > /dev/null
EXIT_CODE=$?

# ── extract summary ────────────────────────────────────────────────
if [[ -f "$JSONL_FILE" && -s "$JSONL_FILE" ]]; then
  LAST_USAGE=$(grep '"usage_update"' "$JSONL_FILE" | tail -1)
  if [[ -n "$LAST_USAGE" ]]; then
    echo "$LAST_USAGE" | python3 -c "
import json, sys
d = json.load(sys.stdin)
s = d.get('stats', {})
print(f'Turns: {s.get(\"turnCount\", \"?\")}')
print(f'Tokens: {s.get(\"totalTokens\", \"?\")}')
print(f'Cost: \${s.get(\"totalCost\", 0):.2f}')
" 2>/dev/null || true
  fi

  if grep -qE '"type":"(result|done)"' "$JSONL_FILE" 2>/dev/null; then
    echo "Exit: completed"
  else
    echo "Exit: timeout/interrupted"
  fi
fi

echo ""
echo "AMI exited with code $EXIT_CODE"
echo "Full trace: $JSONL_FILE"
