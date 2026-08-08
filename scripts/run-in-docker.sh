#!/usr/bin/env bash
# Run AMI inside a Docker container on a local repo.
# Useful for sandboxed execution or matching SWE-bench behavior locally.
#
# Usage:
#   ./run-in-docker.sh --image ubuntu:22.04 --repo /path/to/repo --prompt "Fix the bug"
#
# Required env (one of):
#   AI_API_KEY                  API key
#   ANTHROPIC_VERTEX_PROJECT_ID Vertex AI project

set -euo pipefail

# ── defaults ────────────────────────────────────────────────────────
IMAGE=""
REPO_DIR=""
PROMPT=""
MODEL="${AI_MODEL:-claude-opus-4-6}"
MAX_TURNS=100
OUTPUT_DIR="./ami-docker-output"

# ── parse args ──────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --repo) REPO_DIR="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$IMAGE" || -z "$REPO_DIR" || -z "$PROMPT" ]]; then
  echo "ERROR: --image, --repo, and --prompt are all required" >&2
  exit 1
fi

REPO_DIR="$(cd "$REPO_DIR" && pwd)"

# ── find AMI binary ────────────────────────────────────────────────
AMI_BINARY="${AMI_BINARY:-$HOME/.local/bin/ami}"
if [[ ! -f "$AMI_BINARY" ]]; then
  AMI_BINARY="$(command -v ami 2>/dev/null || true)"
fi
if [[ -z "$AMI_BINARY" || ! -f "$AMI_BINARY" ]]; then
  echo "ERROR: AMI binary not found. Set AMI_BINARY env var." >&2
  exit 1
fi

# ── setup ───────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d /tmp/ami-docker-stage-XXXXXX)"
trap "rm -rf $STAGING_DIR" EXIT

echo "$PROMPT" > "$STAGING_DIR/prompt.txt"

# ── build inner script ──────────────────────────────────────────────
cat > "$STAGING_DIR/run.sh" <<'INNER_EOF'
#!/bin/bash
set -euo pipefail

cd /workdir
PROMPT=$(cat /staging/prompt.txt)

API_KEY_ARG=""
if [[ -n "${AI_API_KEY:-}" ]]; then
  API_KEY_ARG="--api-key $AI_API_KEY"
fi

ami \
  $API_KEY_ARG \
  --model "__MODEL__" \
  --prompt "$PROMPT" \
  --max-turns __MAX_TURNS__ \
  --yolo \
  --output-format jsonl \
  --quiet 2>/results/ami-stderr.log | tee /results/ami-output.jsonl > /dev/null || true

echo "Container work complete."
INNER_EOF

sed -i "s/__MODEL__/$MODEL/g" "$STAGING_DIR/run.sh"
sed -i "s/__MAX_TURNS__/$MAX_TURNS/g" "$STAGING_DIR/run.sh"
chmod +x "$STAGING_DIR/run.sh"

# ── docker args ─────────────────────────────────────────────────────
DOCKER_ARGS=(
  --rm
  --shm-size=5g
  -v "$AMI_BINARY:/usr/local/bin/ami:ro"
  -v "$STAGING_DIR:/staging:ro"
  -v "$OUTPUT_DIR:/results"
  -v "$REPO_DIR:/workdir"
  -w /workdir
)

# Auth
if [[ -n "${ANTHROPIC_VERTEX_PROJECT_ID:-}" ]]; then
  DOCKER_ARGS+=(-e "ANTHROPIC_VERTEX_PROJECT_ID=$ANTHROPIC_VERTEX_PROJECT_ID")
  DOCKER_ARGS+=(-v "$HOME/.config/gcloud:/root/.config/gcloud:ro")
elif [[ -n "${AI_API_KEY:-}" ]]; then
  DOCKER_ARGS+=(-e "AI_API_KEY=$AI_API_KEY")
fi

# ── run ─────────────────────────────────────────────────────────────
CONTAINER_NAME="ami-docker-$(date +%s)-$$"
echo "Starting Docker container ($CONTAINER_NAME) ..."
echo "  Image:  $IMAGE"
echo "  Repo:   $REPO_DIR"
echo "  Model:  $MODEL"
echo "  Output: $OUTPUT_DIR"
echo ""

docker run \
  --name "$CONTAINER_NAME" \
  "${DOCKER_ARGS[@]}" \
  "$IMAGE" \
  bash /staging/run.sh 2>&1 | tee "$OUTPUT_DIR/container.log"

echo ""
echo "Done. Output in $OUTPUT_DIR/"
