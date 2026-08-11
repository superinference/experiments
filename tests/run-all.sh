#!/bin/bash
# ── AMI Functional Test Runner ─────────────────────────────────────────
# Discovers and runs all test suites in tests/suites/, aggregates results.
#
# Usage:
#   ./tests/run-all.sh              # run all suites
#   ./tests/run-all.sh 01 03        # run only suites 01 and 03
#
# Environment:
#   AI_API_KEY       — required (API key for the LLM provider)
#   AI_BASE_URL      — API base URL (default: https://api.openai.com/v1)
#   AI_MODEL         — model name (default: gpt-4o)
#   TEST_WORKSPACE   — override workspace dir (default: /tmp/ami-test-workspace)
#   SCRUB_SCRIPT     — override scrubber path (default: /tmp/ami-scrub.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK="$SCRIPT_DIR/lib/framework.sh"

export TEST_WORKSPACE="${TEST_WORKSPACE:-/tmp/ami-test-workspace}"
export SCRUB_SCRIPT="${SCRUB_SCRIPT:-/tmp/ami-scrub.sh}"

# ── PATH setup ────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Pre-flight checks ─────────────────────────────────────────────────

if ! command -v ami &>/dev/null; then
  echo "AMI not found — installing..."
  curl -fsSL https://www.superinference.org/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v ami &>/dev/null; then
    echo "ERROR: install completed but 'ami' still not in PATH."
    exit 1
  fi
fi

if [ -z "${AI_API_KEY:-}" ] && [ ! -f "$HOME/.ami/frito.json" ]; then
  echo "WARNING: No API credentials found. Tests requiring API calls will fail."
fi

# ── Build scrubber ────────────────────────────────────────────────────
# Strips API key patterns from all AMI output to prevent leaks.

if [ ! -x "$SCRUB_SCRIPT" ]; then
  KEY_PREFIX="${AI_API_KEY:+${AI_API_KEY:0:8}}"
  cat > "$SCRUB_SCRIPT" <<SCRUB
#!/bin/bash
sed -e 's/AIzaSy[A-Za-z0-9_-]\{20,\}/[REDACTED]/g' \
    -e 's/ya29\.[A-Za-z0-9_-]\{20,\}/[REDACTED]/g' \
    -e 's/sk-ant-[A-Za-z0-9_-]\{20,\}/[REDACTED]/g' \
    -e 's/sk-ws-[A-Za-z0-9_.-]\{20,\}/[REDACTED]/g' \
    ${KEY_PREFIX:+-e "s/${KEY_PREFIX}[A-Za-z0-9_.-]*/[REDACTED]/g"}
SCRUB
  chmod +x "$SCRUB_SCRIPT"
fi

echo ""
echo "  AMI Functional Test Suite"
echo "  ami $(ami --version 2>/dev/null || echo 'unknown')"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

# ── Discover suites ───────────────────────────────────────────────────

TOTAL_TOTAL=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
ALL_FAILED=()
SUITE_RESULTS=()

filter_args=("$@")

for suite in "$SCRIPT_DIR"/suites/*.sh; do
  [ -f "$suite" ] || continue
  suite_basename="$(basename "$suite")"

  # If specific suites requested, skip non-matching
  if [ "${#filter_args[@]}" -gt 0 ]; then
    match=false
    for f in "${filter_args[@]}"; do
      if [[ "$suite_basename" == *"$f"* ]]; then
        match=true
        break
      fi
    done
    if ! $match; then
      continue
    fi
  fi

  # Run suite in a subshell so failures don't kill the runner
  set +e
  (
    source "$FRAMEWORK"
    source "$suite"
  )
  suite_exit=$?
  set -e

  # Read results from the suite's exported file (keyed by suite number prefix)
  suite_num="${suite_basename%%-*}"
  results_file="/tmp/ami-suite-results-$$-${suite_num}.results"
  if [ -f "$results_file" ]; then
    source "$results_file"
    rm -f "$results_file"
  fi
done

# ── Final report ──────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "  FINAL RESULTS"
echo "================================================================"

for entry in "${SUITE_RESULTS[@]:-}"; do
  [ -n "$entry" ] && echo "  $entry"
done

echo ""
echo "  Total: $TOTAL_TOTAL | Passed: $TOTAL_PASSED | Failed: $TOTAL_FAILED | Skipped: $TOTAL_SKIPPED"

if [ "${#ALL_FAILED[@]}" -gt 0 ]; then
  echo ""
  echo "  FAILED TESTS:"
  for name in "${ALL_FAILED[@]}"; do
    echo "    - $name"
  done
fi

echo "================================================================"

# ── Generate report ───────────────────────────────────────────────────

REPORT_DIR="${REPORT_DIR:-$SCRIPT_DIR/reports}"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/report-$(date -u '+%Y%m%d-%H%M%S').md"
AMI_VER="$(ami --version 2>/dev/null || echo 'unknown')"
RUN_DATE="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

{
  echo "# AMI Functional Test Report"
  echo ""
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| AMI Version | \`$AMI_VER\` |"
  echo "| Date | $RUN_DATE |"
  echo "| Runner | $(hostname 2>/dev/null || echo 'CI') |"
  echo "| Total | $TOTAL_TOTAL |"
  echo "| Passed | $TOTAL_PASSED |"
  echo "| Failed | $TOTAL_FAILED |"
  echo "| Skipped | $TOTAL_SKIPPED |"
  echo ""
  echo "## Suite Results"
  echo ""
  echo "| Suite | Result |"
  echo "|-------|--------|"
  for entry in "${SUITE_RESULTS[@]:-}"; do
    [ -n "$entry" ] && echo "| ${entry%%:*} | ${entry#*: } |"
  done
  echo ""
  if [ "${#ALL_FAILED[@]}" -gt 0 ]; then
    echo "## Failed Tests"
    echo ""
    for name in "${ALL_FAILED[@]}"; do
      echo "- $name"
    done
    echo ""
  fi
  if [ "$TOTAL_FAILED" -eq 0 ] && [ "$TOTAL_TOTAL" -gt 0 ]; then
    echo "> All tests passed."
  fi
} > "$REPORT_FILE"

echo ""
echo "  Report saved to: $REPORT_FILE"

# Write to GH Actions job summary if available
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT_FILE" >> "$GITHUB_STEP_SUMMARY"
fi

# Also print the report to stdout
cat "$REPORT_FILE"

# ── Cleanup ───────────────────────────────────────────────────────────

rm -f "$SCRUB_SCRIPT"
rm -rf "$TEST_WORKSPACE"

if [ "$TOTAL_FAILED" -gt 0 ]; then
  exit 1
fi
