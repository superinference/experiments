# AMI Experiments Guide

Complete reference for running AMI (Autonomous Machine Intelligence) in fully detached mode — standalone, CLI, and SWE-bench Live multilang experiments.

AMI is a statically-linked Go binary that wraps LLM APIs with agentic tool use (bash, file_edit, file_read, grep, etc.). It runs headless, produces structured output (JSON/JSONL), and integrates with Docker for sandboxed execution.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [AMI Installation](#2-ami-installation)
3. [Authentication](#3-authentication)
4. [AMI Standalone Mode](#4-ami-standalone-mode)
5. [AMI CLI Reference](#5-ami-cli-reference)
6. [AMI Configuration](#6-ami-configuration)
7. [SWE-bench Live Experiments](#7-swe-bench-live-experiments)
8. [Autonomous Monitoring](#8-autonomous-monitoring)
9. [Official Evaluation](#9-official-evaluation)
10. [Result Analysis](#10-result-analysis)
11. [Retry and Gap Closure](#11-retry-and-gap-closure)
12. [Submission Generation](#12-submission-generation)
13. [Operational Procedures](#13-operational-procedures)
14. [Functional Test Suite](#14-functional-test-suite)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|---|---|---|
| CPU | 8 cores | 16+ cores |
| RAM | 32 GB | 64+ GB |
| Disk | 500 GB free | 1.5+ TB free |
| Docker | 24.0+ | Latest stable |
| Python | 3.10+ | 3.11+ |
| OS | Linux x86_64 | Ubuntu 22.04+ |

### Software

```bash
# Docker (required for SWE-bench experiments)
docker --version

# Python + pip (required for evaluation and dataset download)
python3 --version
pip install datasets  # for HuggingFace dataset download

# jq (required for JSONL parsing)
jq --version

# Git (required for patch management and version control)
git --version

# gcloud CLI (required for Vertex AI authentication)
gcloud --version
```

### Disk Space Budget

Each SWE-bench instance requires:
- Docker image: 2-8 GB (cached after first pull)
- Agent output: 1-50 MB (traces, patches, logs)
- Eval containers: 2-10 GB temporary

For 138 Go instances with cached images: ~400-600 GB total.

---

## 2. AMI Installation

AMI is a single statically-linked binary. No runtime dependencies.

```bash
curl -fsSL https://www.superinference.org/install.sh | bash

# Verify installation
ami --version

# Default location searched by scripts
# ~/.local/bin/ami
# Override with AMI_BINARY env var
```

The binary is ~120 MB. It embeds all tool definitions and the agentic loop.

---

## 3. Authentication

AMI supports multiple LLM providers. Authentication method depends on the provider.

### 3.1 Direct API Key (Anthropic, OpenAI, Google)

```bash
# Anthropic Claude (direct API)
export AI_API_KEY="sk-ant-..."
export AI_MODEL="claude-opus-4-6"

# OpenAI
export AI_API_KEY="sk-..."
export AI_MODEL="gpt-4o"

# Google Gemini
export GOOGLE_API_KEY="AIza..."
export AI_MODEL="gemini-3.6-flash"
# OR
export AI_API_KEY="AIza..."
export AI_PROVIDER="google"
```

### 3.2 Vertex AI (GCP-managed Claude)

Vertex AI uses GCP service account credentials instead of API keys. This is the recommended method for large-scale experiments because it has higher rate limits and uses GCP billing.

```bash
# One-time setup
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Environment variables for AMI
export AI_PROVIDER="anthropic-vertex"
export ANTHROPIC_VERTEX_PROJECT_ID="your-gcp-project-id"
export AI_MODEL="claude-opus-4-6"

# Credentials location (mounted into Docker containers)
# ~/.config/gcloud/application_default_credentials.json
```

When running inside Docker, the gcloud credentials directory is bind-mounted:
```bash
-v "$HOME/.config/gcloud:/root/.config/gcloud:ro"
```

### 3.3 Verifying Authentication

```bash
# Quick test: send a one-shot prompt
ami --model claude-opus-4-6 --prompt "Say hello" --max-turns 1 --quiet

# With Vertex AI
AI_PROVIDER=anthropic-vertex \
ANTHROPIC_VERTEX_PROJECT_ID=your-project \
ami --model claude-opus-4-6 --prompt "Say hello" --max-turns 1 --quiet
```

---

## 4. AMI Standalone Mode

### 4.1 One-Shot Prompt (Fully Detached)

Run a single prompt, get structured output, exit:

```bash
ami \
  --model claude-opus-4-6 \
  --prompt "Fix the bug in main.go where the HTTP handler returns 500 instead of 404 for missing resources" \
  --max-turns 50 \
  --yolo \
  --output-format jsonl \
  --quiet \
  2>ami-stderr.log | tee ami-output.jsonl > /dev/null
```

**Flags explained:**

| Flag | Purpose |
|---|---|
| `--prompt` | Non-interactive mode: send prompt, run agent, exit |
| `--max-turns 50` | Stop after 50 agentic turns (tool calls) |
| `--yolo` | Auto-allow all tool permissions (no interactive prompts) |
| `--output-format jsonl` | Stream events as newline-delimited JSON |
| `--quiet` | Suppress stderr status messages |
| `--config` | Path to JSON config file or inline JSON |

### 4.2 Fully Detached with nohup

```bash
nohup ami \
  --model claude-opus-4-6 \
  --prompt "Refactor the authentication module to use JWT tokens" \
  --max-turns 100 \
  --yolo \
  --output-format jsonl \
  --config '{"thinking":{"enabled":true,"level":"max","budgetTokens":128000},"tokenBudget":200000}' \
  --quiet \
  2>task-stderr.log | tee task-output.jsonl > /dev/null &

echo "AMI PID: $!"
```

### 4.3 With Context Files

Attach files as additional context for the agent:

```bash
ami \
  --model claude-opus-4-6 \
  --prompt "Review this PR for security issues" \
  --context-file pr-diff.patch \
  --context-file security-policy.md \
  --max-turns 30 \
  --yolo \
  --output-format json
```

### 4.4 Reading from stdin

```bash
cat bug-report.md | ami \
  --model claude-opus-4-6 \
  --stdin \
  --max-turns 50 \
  --yolo \
  --output-format jsonl
```

### 4.5 Session Resume

AMI assigns a session ID to each run. Resume a crashed or interrupted session:

```bash
# Start with explicit session ID
ami --model claude-opus-4-6 --prompt "Fix the bug" --session-id my-session-001 --yolo

# Resume later
ami --model claude-opus-4-6 --resume my-session-001 --yolo
```

---

## 5. AMI CLI Reference

### Complete Flag Reference

```
ami [options]

Core:
  --model <model>           Model name (default: gpt-4o, env: AI_MODEL)
  --api-key <key>           API key (env: AI_API_KEY)
  --base-url <url>          API endpoint (env: AI_BASE_URL)
  --prompt <text>           Non-interactive prompt mode
  --stdin                   Read prompt from stdin

Agent Control:
  --max-turns <n>           Max agentic turns (default: 100, 0 = unlimited)
  --yolo                    Auto-allow all tool permissions
  --permission-mode <mode>  ask | auto-allow | deny-all
  --allow <pattern>         Allow specific tool pattern (repeatable)
  --deny <pattern>          Deny specific tool pattern (repeatable)

Thinking:
  --thinking <level>        off | low | medium | high | max (default: auto)
  --config <json|path>      Full config including thinking budget

Output:
  --output-format <fmt>     json | jsonl | text (default: json)
  --quiet                   Suppress stderr status messages

Session:
  --session-id <id>         Explicit session ID
  --resume [session-id]     Resume previous session

Context:
  --context-file <path>     Attach file as context (repeatable)
```

### Environment Variables

| Variable | Description |
|---|---|
| `AI_API_KEY` | API key (any provider) |
| `AI_MODEL` | Model name |
| `AI_BASE_URL` | API endpoint |
| `AI_PROVIDER` | Provider override (e.g., `anthropic-vertex`, `google`) |
| `ANTHROPIC_API_KEY` | Anthropic-specific key |
| `OPENAI_API_KEY` | OpenAI-specific key |
| `GOOGLE_API_KEY` | Google/Gemini key |
| `ANTHROPIC_VERTEX_PROJECT_ID` | GCP project for Vertex AI |

### Output Formats

**`--output-format json`** (default): Single JSON object at the end with session summary.

**`--output-format jsonl`**: Streaming events, one JSON object per line. Event types:

| Event | Description |
|---|---|
| `session_start` | Session initialized |
| `text_delta` | Agent text output (streaming) |
| `tool_use_start` | Tool invocation with `toolName` and `input` |
| `tool_use_result` | Tool execution result |
| `turn_complete` | Turn boundary |
| `usage_update` | Cumulative token/cost stats |
| `checkpoint_created` | File checkpoint after edits |
| `done` | Agent completed (clean exit) |
| `user_question` | Iteration limit re-prompt |
| `analytics_summary` | End-of-session metrics |
| `plan_mode_changed` | Agent entered/exited plan mode |
| `error` | Error event |

**`--output-format text`**: Plain text output only.

---

## 6. AMI Configuration

### Config File Format

```json
{
  "thinking": {
    "enabled": true,
    "level": "max",
    "budgetTokens": 128000
  },
  "tokenBudget": 200000
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `thinking.enabled` | bool | false | Enable extended thinking |
| `thinking.level` | string | "auto" | off, low, medium, high, max |
| `thinking.budgetTokens` | int | 8192 | Max tokens for thinking |
| `tokenBudget` | int | 100000 | Max output tokens per turn |

### Per-Model Config Files

Name config files as `ami-config-<model-slug>.json` for automatic selection:

```
ami-config-claude-opus-4-6.json     # Used when --model claude-opus-4-6
ami-config-claude-sonnet-4-6.json   # Used when --model claude-sonnet-4-6
ami-config-gemini-3.6-flash.json    # Used when --model gemini-3.6-flash
ami-config.json                     # Fallback for any model
```

The `run-instance.sh` script checks for `ami-config-${MODEL_SLUG}.json` first, falling back to `ami-config.json`.

### Recommended Configs by Model

**Opus 4.6** (highest quality, expensive):
```json
{"thinking":{"enabled":true,"level":"max","budgetTokens":128000},"tokenBudget":200000}
```

**Sonnet 4.6** (balanced):
```json
{"thinking":{"enabled":true,"level":"high","budgetTokens":64000},"tokenBudget":150000}
```

**Gemini Flash** (fast, cheap):
```json
{"thinking":{"enabled":true,"level":"medium","budgetTokens":32000},"tokenBudget":100000}
```

---

## 7. SWE-bench Live Experiments

### 7.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Host Machine                                               │
│                                                             │
│  run-all-parallel.sh                                        │
│    ├── run-instance.sh (instance A) ──┐                     │
│    ├── run-instance.sh (instance B)   │  PARALLEL slots     │
│    └── run-instance.sh (instance C) ──┘                     │
│                                                             │
│  Each run-instance.sh:                                      │
│    1. Pull Docker image for instance                        │
│    2. Start container with:                                 │
│       - AMI binary bind-mounted from host                   │
│       - GCloud creds bind-mounted from host                 │
│       - Staging dir (prompt, config, test patch)            │
│       - Results dir (output mount)                          │
│    3. Inside container:                                     │
│       a. Apply test_patch to repo at /testbed               │
│       b. Run rebuild_cmds (compile project)                 │
│       c. Run AMI agent with prompt                          │
│       d. Capture diff (agent changes only)                  │
│       e. Strip test file modifications from diff            │
│    4. Extract metrics from AMI output                       │
│    5. Run official Docker eval (inline, blocking)           │
│                                                             │
│  autonomous-opus-monitor.sh                                 │
│    - Monitors run-all-parallel.sh PID                       │
│    - Kills hung containers (>2h)                            │
│    - Git commit/push every 30 min                           │
│    - After initial pass: retry loop (up to 10 rounds)       │
│    - Categorize failures, back up each round                │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Directory Structure

```
swebench/<language>/
├── ami-config.json                    # Default AMI config
├── ami-config-claude-opus-4-6.json    # Model-specific config
├── data/
│   └── swebench-multilang-<lang>.jsonl  # Dataset (downloaded by setup.sh)
├── results/<model-slug>/
│   └── <instance-id>/
│       ├── ami-<model>-diff.patch       # Agent's code patch
│       ├── ami-<model>.json             # Metrics summary
│       ├── ami-<model>-output.jsonl     # Full streaming trace
│       ├── ami-<model>-output.json      # Final usage snapshot
│       ├── ami-<model>.stderr.log       # AMI stderr
│       ├── container.log                # Docker container stdout
│       ├── docker-pull.log              # Image pull log
│       ├── run-instance.log             # Script stdout
│       └── run-instance.stderr.log      # Script stderr
├── eval-results/<model-slug>/
│   └── <instance-id>/
│       ├── report.json                  # Official eval result
│       ├── post_patch_log.txt           # Test output log
│       └── status.json                  # Eval status
├── setup.sh                           # Download dataset
├── run-instance.sh                    # Run single instance
├── run-all-parallel.sh                # Run all instances in parallel
├── autonomous-opus-monitor.sh         # Autonomous monitoring + retry
├── evaluate-instance.sh               # Eval single instance
├── analyze-gaps.sh                    # Analyze failures
├── generate-submission.sh             # Generate preds.json
├── reeval-timeout-instances.sh        # Re-eval timed-out evals
└── retry-iteration.sh                 # Manual retry round
```

### 7.3 Step-by-Step: Running a Full Experiment

#### Step 1: Setup

```bash
cd swebench/go  # or java, rust, ts-js

# Download the dataset from HuggingFace
bash setup.sh

# Verify
wc -l data/swebench-multilang-go.jsonl
# 138 instances
```

#### Step 2: Configure Authentication

```bash
# Option A: Direct API key
export AI_API_KEY="sk-ant-..."
export AI_MODEL="claude-opus-4-6"
export AI_PROVIDER="anthropic"

# Option B: Vertex AI (recommended for scale)
export AI_MODEL="claude-opus-4-6"
export AI_PROVIDER="anthropic-vertex"
export ANTHROPIC_VERTEX_PROJECT_ID="your-gcp-project-id"
gcloud auth application-default login
```

#### Step 3: Run a Single Instance (Test)

```bash
# Test with one instance to verify everything works
bash run-instance.sh getgauge__gauge-2836

# Check output
ls results/claude-opus-4-6/getgauge__gauge-2836/
cat results/claude-opus-4-6/getgauge__gauge-2836/ami-claude-opus-4-6.json | jq .
```

#### Step 4: Run All Instances in Parallel

```bash
# Set parallelism (CRITICAL: total across all languages must not exceed 3)
export PARALLEL=2
export SKIP_EXISTING=1   # Skip instances that already have results
export MAX_TURNS=300      # Max agent turns per instance

# Run in background
nohup bash run-all-parallel.sh > /tmp/go-opus-run.log 2>&1 &
echo "Run PID: $!"
```

#### Step 5: Start Autonomous Monitor

```bash
# The monitor handles:
# - Hung container detection and killing (>2h threshold)
# - Periodic git commit/push (every 30 min)
# - Automatic retry loop after initial pass completes
# - Failure categorization and selective retry

nohup bash autonomous-opus-monitor.sh > /tmp/opus-autonomous.log 2>&1 &
echo "Monitor PID: $!"
```

#### Step 6: Check Status

```bash
# Quick status
tail -5 /tmp/opus-autonomous.log

# Detailed status
docker ps --format "{{.Names}} ({{.Status}})" | grep swebench
df -h /

# Count resolved
for d in eval-results/claude-opus-4-6/*/; do
  [[ -f "${d}report.json" ]] || continue
  python3 -c "import json; r=json.load(open('${d}report.json')); print('RESOLVED' if r.get('resolved') else '')" 2>/dev/null
done | grep -c RESOLVED
```

### 7.4 Running Multiple Languages Simultaneously

**Critical constraint: total PARALLEL across all languages must not exceed 3.**

```bash
# Terminal 1: Go (PARALLEL=2)
cd swebench/go
export PARALLEL=2
nohup bash run-all-parallel.sh > /tmp/go-opus-run.log 2>&1 &
nohup bash autonomous-opus-monitor.sh > /tmp/opus-autonomous.log 2>&1 &

# Terminal 2: Java (PARALLEL=1)
cd swebench/java
export PARALLEL=1
nohup bash run-all-parallel.sh > /tmp/java-opus-run.log 2>&1 &
nohup bash autonomous-opus-monitor.sh > /tmp/java-opus-autonomous.log 2>&1 &

# Total: 2 + 1 = 3 parallel slots
```

### 7.5 Running Different Models

Results are namespaced by model slug, so multiple models can run on the same dataset without conflicts:

```bash
# Opus run
AI_MODEL=claude-opus-4-6 AI_PROVIDER=anthropic-vertex \
  PARALLEL=2 SKIP_EXISTING=1 \
  bash run-all-parallel.sh

# Sonnet run (different model, separate results dir)
AI_MODEL=claude-sonnet-4-6 AI_PROVIDER=anthropic-vertex \
  PARALLEL=2 SKIP_EXISTING=1 \
  bash run-all-parallel.sh

# Results stored in:
# results/claude-opus-4-6/<instance>/
# results/claude-sonnet-4-6/<instance>/
```

### 7.6 Environment Variables for run-all-parallel.sh

| Variable | Default | Description |
|---|---|---|
| `AI_MODEL` | `claude-opus-4-6` | Model to use |
| `AI_PROVIDER` | `anthropic` | Provider (`anthropic`, `anthropic-vertex`, `google`) |
| `AI_API_KEY` | — | API key (not needed for Vertex) |
| `ANTHROPIC_VERTEX_PROJECT_ID` | — | GCP project for Vertex |
| `PARALLEL` | `3` | Max concurrent instances |
| `SKIP_EXISTING` | `0` | Skip instances with existing results |
| `SKIP_EVAL` | `0` | Skip inline evaluation after agent |
| `MAX_TURNS` | `200` | Max agent turns |
| `AMI_BINARY` | `~/.local/bin/ami` | Path to AMI binary |
| `REPO_FILTER` | — | Only run instances from this repo |
| `LIMIT` | — | Max number of instances to run |
| `INSTANCE_LIST` | — | File with one instance_id per line |

### 7.7 What Happens Inside a Container

Each `run-instance.sh` invocation:

1. **Pulls Docker image** — each SWE-bench instance has a pre-built Docker image with the repo at the correct commit, language toolchain, and dependencies installed
2. **Starts container** with bind mounts:
   - `/usr/local/bin/ami` ← host AMI binary (read-only)
   - `/staging/` ← prompt, config, test patch (read-only)
   - `/results/` ← output directory (read-write)
   - `/root/.config/gcloud/` ← GCP credentials (read-only, Vertex only)
3. **Inside the container:**
   - Applies `test_patch.diff` to add failing tests
   - Runs `rebuild_cmds` (compile the project)
   - Runs AMI with the prompt in `--yolo` mode
   - A watchdog process monitors turn count and kills AMI if it exceeds `MAX_TURNS`
   - After AMI exits, captures the diff between test patch commit and agent's changes
   - Strips test file modifications (tests are restored before eval)
   - Strips `.superinference/`, `.claude/` artifacts from the diff
4. **Back on host:**
   - Extracts metrics from AMI JSONL output (turns, tokens, cost, exit reason)
   - Saves structured metadata JSON
   - Renames output files with model slug
   - Runs official Docker evaluation (blocking, up to 7200s timeout)

### 7.8 The Prompt

The prompt is constructed from the dataset fields and model-specific rules:

```
You are fixing a bug in the {repo} repository ({language}).

## Bug Report
{problem_statement}

## Hints (if available)
{hints_text}

## Failing Tests
{fail_to_pass test names}

## Test Command
{test_cmds}

## Build Command
{rebuild_cmds}

## MANDATORY RULES (model-specific)
{stop rules, anti-loop rules, workflow steps}
```

Model-specific prompt appendices exist for:
- **Claude** (`CLAUDE_PROMPT`): Balanced rules with full test suite verification
- **Gemini Pro** (`GEMINI_PROMPT`): Aggressive anti-loop and stop rules
- **Gemini Flash** (`FLASH_PROMPT`): Simplified rules for faster model

---

## 8. Autonomous Monitoring

### 8.1 How the Monitor Works

`autonomous-opus-monitor.sh` is a long-running bash script designed to run unattended for up to 7 days:

**Phase 1: Monitor initial run**
- Finds the `run-all-parallel.sh` PID
- Polls every 60 seconds: counts results, evals, resolved, containers
- Kills containers running longer than `HUNG_THRESHOLD_SEC` (default: 2 hours)
- Git commits and pushes every `COMMIT_INTERVAL_SEC` (default: 30 minutes)
- After `run-all-parallel.sh` exits, waits for remaining eval containers

**Phase 2: Retry loop** (up to 10 rounds)
- Builds retry list by categorizing failures:
  - **Close miss** (all F2P tests pass but P2P regressions): always retry
  - **Partial** (some F2P tests pass): always retry
  - **Wrong fix** (no F2P tests pass): retry first 2 rounds only
  - **Build/infra** (no test results): retry first 5 rounds only
  - **Empty/no patch**: retry first 5 rounds only
- Backs up current results to `run{N}/` subdirectory
- Removes old results for retry instances (fresh attempt)
- Starts new `run-all-parallel.sh` with the retry list
- After each round, checks for flips (newly resolved instances)
- Stops after 3 consecutive rounds with no flips

### 8.2 Monitor Configuration

Edit these variables at the top of `autonomous-opus-monitor.sh`:

```bash
PARALLEL=2                    # Concurrent instances
MAX_RETRIES=10                # Max retry rounds
HUNG_THRESHOLD_SEC=7200       # Kill containers after 2h
COMMIT_INTERVAL_SEC=1800      # Git commit/push every 30 min
TOTAL_INSTANCES=138           # Total instances in dataset
```

### 8.3 Monitor Log Format

```
[2026-08-08 09:35:10] STATUS [initial-run]: results=138 eval=114 resolved=89/138 containers=1 evals=1
[2026-08-08 09:35:32] No new changes to commit
[2026-08-08 11:32:59] STATUS [retry-run1]: results=94 eval=91 resolved=91/138 containers=2 evals=1
```

Fields: `results` = instances with agent output, `eval` = instances with eval report, `resolved` = passing all tests, `containers` = active agent containers, `evals` = active eval containers.

### 8.4 Git Commit/Push Strategy

- Commits only changed files under `results/<model>/` and `eval-results/<model>/`
- Files > 100MB are automatically excluded (added to .gitignore)
- Push uses `git rebase origin/main` to handle concurrent pushes
- Retries push up to 3 times
- Never force pushes
- Never uses `git stash` (it creates new inodes and breaks Docker bind-mounted file descriptors)

---

## 9. Official Evaluation

### 9.1 Setup SWE-bench-Live Evaluator

```bash
# Clone the official repo
git clone https://github.com/SWE-bench-Live/SWE-bench-Live.git ~/SWE-bench-Live
cd ~/SWE-bench-Live
pip install -e .
```

### 9.2 How Evaluation Works

The official evaluator:
1. Takes a `preds.json` with instance ID → patch mapping
2. Starts a fresh Docker container from the instance's pre-built image
3. Applies the agent's patch
4. Runs the test suite
5. Produces `report.json` with:
   - `resolved`: boolean — all FAIL_TO_PASS tests pass AND no PASS_TO_PASS regressions
   - `FAIL_TO_PASS.success/failure`: which target tests pass/fail
   - `PASS_TO_PASS.success/failure`: which existing tests pass/break

### 9.3 Inline vs Standalone Evaluation

**Inline** (default): `run-instance.sh` runs evaluation immediately after the agent finishes, blocking the parallel slot. Uses a 7200s (2h) timeout.

```bash
# Disable inline eval to run agent-only (faster throughput)
SKIP_EVAL=1 bash run-instance.sh <instance-id>
```

**Standalone**: Evaluate a single instance manually:

```bash
bash evaluate-instance.sh <instance-id> [model-slug]
# Example:
bash evaluate-instance.sh getgauge__gauge-2836 claude-opus-4-6
```

**Batch re-evaluation** for timed-out evals:

```bash
bash reeval-timeout-instances.sh 3600  # 1h timeout per instance
```

### 9.4 Evaluation Timeout

Evals should never timeout — a correct patch should not be discarded due to eval timeout. Default: 7200s (2 hours). Some large Java projects (GWT, Armeria, Pinot) can take 2-3 hours to build and test.

---

## 10. Result Analysis

### 10.1 Analyze Gaps

```bash
bash analyze-gaps.sh
```

Output categorizes all instances:
- **RESOLVED**: All tests pass
- **CLOSE GAP**: Some FAIL_TO_PASS passed (retry candidates)
- **REGRESSION**: PASS_TO_PASS tests broke
- **FAILED**: No FAIL_TO_PASS tests passed
- **NOT EVALUATED**: No report yet

Writes `retry-close-gaps.txt` and `retry-regressions.txt` for targeted retries.

### 10.2 Per-Instance Metrics

```bash
# Read agent metrics
cat results/claude-opus-4-6/<instance>/ami-claude-opus-4-6.json | jq .

# Key fields:
# .exitReason     — "completed" or "timeout"
# .turns          — number of agentic turns
# .elapsedMs      — wall clock time
# .estimatedCost  — USD cost
# .tokens.prompt  — input tokens
# .tokens.completion — output tokens
```

### 10.3 Count Resolved

```bash
MODEL_SLUG="claude-opus-4-6"
resolved=0
for d in eval-results/$MODEL_SLUG/*/; do
  [[ -f "${d}report.json" ]] || continue
  r=$(python3 -c "import json; print(json.load(open('${d}report.json')).get('resolved','?'))")
  [[ "$r" == "True" ]] && resolved=$((resolved+1))
done
echo "Resolved: $resolved"
```

### 10.4 Cost Analysis

```bash
python3 -c "
import json, os
costs = []
for inst in os.listdir('results/claude-opus-4-6'):
    jf = f'results/claude-opus-4-6/{inst}/ami-claude-opus-4-6.json'
    if os.path.isfile(jf):
        d = json.load(open(jf))
        costs.append(d.get('estimatedCost', 0))
print(f'Total: \${sum(costs):.2f}')
print(f'Average: \${sum(costs)/len(costs):.2f}')
print(f'Instances: {len(costs)}')
"
```

---

## 11. Retry and Gap Closure

### 11.1 Automatic Retries (via Monitor)

The autonomous monitor handles retries automatically. It:
1. Categorizes failures by type
2. Backs up current results to `run{N}/` subdirectory
3. Removes old results for retry instances
4. Runs fresh attempts
5. Stops after 3 consecutive rounds with no flips

### 11.2 Manual Targeted Retry

```bash
# Retry specific instances
echo "instance__id-1" > /tmp/retry-list.txt
echo "instance__id-2" >> /tmp/retry-list.txt

INSTANCE_LIST=/tmp/retry-list.txt \
SKIP_EXISTING=0 \
PARALLEL=2 \
bash run-all-parallel.sh
```

### 11.3 Result Preservation

Results from each retry round are preserved:
```
results/claude-opus-4-6/
├── <instance-id>/          # Current (latest) result
├── run1/<instance-id>/     # Backup from retry round 1
├── run2/<instance-id>/     # Backup from retry round 2
└── run3/<instance-id>/     # Backup from retry round 3
```

Never delete raw agent output (`ami-output.jsonl`). Always `mv` or `cp`, never `rm`.

---

## 12. Submission Generation

```bash
# Generate preds.json for official submission
bash generate-submission.sh claude-opus-4-6

# Output: submission/preds.json
# Format: {"instance_id": {"model_name_or_path": "ami-claude-opus-4-6", "instance_id": "...", "model_patch": "..."}}
```

**Do not include trajs/ in submissions.** Only the preds.json with patches.

Use Git LFS only for files that would be rejected by GitHub (>100MB).

---

## 13. Operational Procedures

### 13.1 Disk Space Management

```bash
# Check disk
df -h /

# Prune stopped containers
docker container prune -f

# Prune old images (careful: keep images for instances that might be retried)
docker image prune -a --filter "until=24h" -f

# Do NOT clean images that might be reused for retries
```

### 13.2 Checking Process Health

```bash
# Monitor processes
ps aux | grep -E "(run-all-parallel|autonomous)" | grep -v grep

# Monitor containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

# Check for hung containers (>2h)
docker ps --format "{{.Names}} {{.RunningFor}}" | grep -E "(hours|hour)"
```

### 13.3 Recovering from Crashes

```bash
# If run-all-parallel dies but monitor is alive:
# The monitor detects the PID is gone and proceeds to retry phase

# If monitor dies:
# Restart it — it will find the running run-all-parallel PID
nohup bash autonomous-opus-monitor.sh > /tmp/opus-autonomous.log 2>&1 &

# If both die:
# Restart run-all-parallel first, then monitor
SKIP_EXISTING=1 PARALLEL=2 \
  nohup bash run-all-parallel.sh > /tmp/go-opus-run.log 2>&1 &
nohup bash autonomous-opus-monitor.sh > /tmp/opus-autonomous.log 2>&1 &
```

### 13.4 Git Conflict Resolution

```bash
# If push fails (non-fast-forward):
git fetch origin main
git rebase origin/main
# Resolve any conflicts
git push origin main

# NEVER force push
```

### 13.5 Model Isolation

Never mix results from different models. Results are stored in `results/<model-slug>/` directories. Verify the model slug before running:

```bash
echo "claude-opus-4-6" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g'
# claude-opus-4-6
```

---

## 14. Functional Test Suite

End-to-end tests that verify AMI works correctly against live LLM providers.

### 14.1 Structure

```
tests/
├── run-all.sh              # Test runner (discovers and runs suites)
├── lib/
│   └── framework.sh        # Assertions, AMI runner, secret scrubbing
├── fixtures/               # Sample source files for tool tests
│   ├── buggy.ts
│   ├── main.ts
│   └── multi-file/
├── suites/
│   ├── 01-smoke.sh         # Basic prompt, exit codes
│   ├── 02-tools-read.sh    # file_read tool
│   ├── 03-tools-write.sh   # file_edit / file_write tools
│   ├── 04-tools-bash.sh    # bash tool
│   ├── 05-agentic.sh       # Multi-turn agentic behavior
│   ├── 06-output-formats.sh# json / jsonl / text output
│   ├── 07-error-handling.sh# Invalid flags, missing files
│   ├── 08-context.sh       # Context files, stdin
│   ├── 09-permissions.sh   # Permission modes
│   └── 10-frito.sh         # FRITO cost-optimization routing
└── reports/                # Generated test reports (gitignored)
```

### 14.2 Running Tests

```bash
# Run all suites
./tests/run-all.sh

# Run specific suites
./tests/run-all.sh 01 03

# With Vertex AI (recommended — uses GCP Application Default Credentials)
env -u AI_API_KEY -u AI_BASE_URL -u HF_TOKEN -u GOOGLE_API_KEY -u OPENAI_API_KEY \
  AI_MODEL=claude-sonnet-4-6 \
  CLOUD_ML_REGION=us-east5 \
  ./tests/run-all.sh

# With a custom provider (e.g., Alibaba Cloud)
env -u ANTHROPIC_VERTEX_PROJECT_ID \
  AI_MODEL=qwen-flash-character \
  AI_API_KEY="your-key" \
  AI_BASE_URL="https://your-endpoint/compatible-mode/v1" \
  ./tests/run-all.sh 01
```

**Note:** When `ANTHROPIC_VERTEX_PROJECT_ID` is set in your environment, AMI auto-detects `anthropic-vertex` as the provider. Clear it (or unset conflicting API key env vars) when using non-Vertex providers. `HF_TOKEN`, `AI_API_KEY`, and other provider keys take precedence in the detection chain.

### 14.3 CI

The GitHub Actions workflow (`.github/workflows/functional-tests.yml`) runs weekly and on manual dispatch. It uses three repository secrets: `AI_API_KEY`, `AI_BASE_URL`, and `AI_MODEL`.

### 14.4 Security

All AMI output is piped through a scrubber that redacts API key patterns (`AIzaSy*`, `ya29.*`, `sk-ant-*`, `sk-ws-*`, and the first 8 chars of `AI_API_KEY`). Cleanup runs in the `always()` step.

---

## 15. Troubleshooting

### AMI produces no valid JSON output

**Cause**: AMI v0.7.2 changed the completion event from `"type":"result"` to `"type":"done"`. The exit reason detection grep must match both.

**Fix**: Ensure `run-instance.sh` uses:
```bash
grep -qE '"type":"(result|done)"' "$RESULTS_DIR/ami-output.jsonl"
```

### All instances timeout at exactly 90 min / 2h

**Cause (pre-v0.7.2)**: Victory lap loop bug — agent solves the problem but continues running until container timeout.

**Fix**: Update to AMI v0.7.2+. The loop fix ensures agents stop after calling `task_complete`.

### Docker image pull fails

**Cause**: Docker Hub rate limits (100 pulls per 6 hours for unauthenticated).

**Fix**: Login to Docker Hub (`docker login`) or cache images. The scripts skip pulls for cached images.

### Eval takes hours for large projects

**Cause**: Some projects (GWT, OpenTelemetry, Armeria) have long build/test cycles.

**Fix**: Increase eval timeout. Do not kill eval containers prematurely. A correct patch should not be discarded due to eval timeout.

### Push rejected (non-fast-forward)

**Cause**: Another process pushed first (multiple monitors, or manual push).

**Fix**: `git fetch origin main && git rebase origin/main && git push`. The monitor handles this automatically with 3 retries.

### Agent spins on bash in final turns

**Symptom**: Timeout instances show 84.8% bash tool usage with 245+ tool calls. Last 5 tool calls are almost always bash.

**Cause**: Agent enters retry loop when stuck. Normal behavior for hard instances — the agent tries different approaches until time runs out.

### Vertex AI authentication fails inside container

**Cause**: GCloud credentials not mounted or expired.

**Fix**:
```bash
# Refresh credentials on host
gcloud auth application-default login

# Verify mount in run-instance.sh
-v "$HOME/.config/gcloud:/root/.config/gcloud:ro"
```

### Container name conflict

**Cause**: Previous container with same name wasn't cleaned up.

**Fix**: `docker rm -f <container-name>` or use `docker container prune -f`.

---

## Appendix: Supported Languages

| Language | Dataset | Instances | Docker Images |
|---|---|---|---|
| Go | `SWE-bench-Live/MultiLang` split `go` | 138 | `starryzhang/sweb.eval.x86_64.*` |
| Java | `SWE-bench-Live/MultiLang` split `java` | 109 | `starryzhang/sweb.eval.x86_64.*` |
| Rust | `SWE-bench-Live/MultiLang` split `rust` | varies | `starryzhang/sweb.eval.x86_64.*` |
| TypeScript/JS | `SWE-bench-Live/MultiLang` split `ts-js` | varies | `starryzhang/sweb.eval.x86_64.*` |
| Python | `SWE-bench-Live/SWE-bench-Live` (Lite) | varies | Official SWE-bench images |

Each language has its own `swebench/<lang>/` directory with identical script structure but language-specific prompts and toolchains.

## Appendix: Observed Performance

Results from our experiments (Opus 4.6, AMI v0.7.2, Vertex AI):

| Model | Language | Resolved | Accuracy | Avg Time (completed) | Avg Cost (completed) |
|---|---|---|---|---|---|
| Opus 4.6 | Go | 92/138 (66.7%) | 78.3% | 16.2 min | $28.50 |
| Opus 4.6 | Java | 31/109 (28.4%)* | 91.2% | 27.4 min | $22.43 |
| Sonnet 4.6 | Go | 100/138 (72.5%) | — | — | — |
| Haiku 4.5 | Go | 90/138 (65.2%) | — | — | — |
| Gemini 3.6 Flash | Go | 78/138 (56.5%) | — | — | — |
| Gemini 3.1 Pro | Go | 71/138 (51.4%) | — | — | — |

*Java run still in progress at time of writing.

Timeout instances cost ~18x more than completed instances ($509 vs $28 avg). The AMI v0.7.2 loop fix reduced average completion time by 53%.
