#!/bin/bash
# ── AMI Functional Test Framework ──────────────────────────────────────
# Source this file in test suites. Provides:
#   ami_run         — run ami with secret scrubbing
#   assert_contains — check output contains string
#   assert_not_contains
#   assert_file_exists
#   assert_file_contains
#   assert_exit_code
#   test_begin / test_pass / test_fail / test_skip
#   setup_workspace — create a clean git workspace
#   suite_header / suite_summary

set -euo pipefail

# ── Globals ────────────────────────────────────────────────────────────

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_NAMES=()
CURRENT_TEST=""
TEST_WORKSPACE="${TEST_WORKSPACE:-/tmp/ami-test-workspace}"
SCRUB_SCRIPT="${SCRUB_SCRIPT:-/tmp/ami-scrub.sh}"
SUITE_NAME="${SUITE_NAME:-unnamed}"
SUITE_TAG="${SUITE_TAG:-00}"
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${FIXTURES:-$FRAMEWORK_DIR/../fixtures}"
FIXTURES="$(cd "$FIXTURES" 2>/dev/null && pwd || echo "")"
_SUITE_SUMMARY_CALLED=0

_framework_exit_trap() {
  if [ "$_SUITE_SUMMARY_CALLED" -eq 0 ] && [ "$TESTS_TOTAL" -gt 0 ]; then
    suite_summary
  fi
}
trap _framework_exit_trap EXIT

# ── Secret scrubbing ──────────────────────────────────────────────────

scrub() {
  if [ -x "$SCRUB_SCRIPT" ]; then
    "$SCRUB_SCRIPT"
  else
    cat
  fi
}

# ── AMI runner ─────────────────────────────────────────────────────────

ami_run() {
  # Usage: ami_run [ami flags...]
  # Runs ami with --quiet, pipes stdout through scrubber, drops stderr.
  # Captures output in $AMI_OUTPUT and exit code in $AMI_EXIT.
  # Automatically adds --model $AI_MODEL if set and not already specified.
  local tmpout ami_timeout model_flag
  tmpout=$(mktemp)
  ami_timeout="${AMI_TIMEOUT:-120}"
  model_flag=()
  if [ -n "${AI_MODEL:-}" ]; then
    local has_model=false
    for arg in "$@"; do [ "$arg" = "--model" ] && has_model=true; done
    if ! $has_model; then
      model_flag=(--model "$AI_MODEL")
    fi
  fi
  # Clean up stale AMI runtime extractions to prevent /dev/shm from filling
  find /dev/shm -maxdepth 1 -name 'si-*' -type d -mmin +2 -exec rm -rf {} + 2>/dev/null || true
  set +e
  timeout "$ami_timeout" ami "${model_flag[@]}" "$@" --quiet 2>/dev/null | scrub > "$tmpout"
  AMI_EXIT=$?
  set -e
  AMI_OUTPUT=$(cat "$tmpout")
  rm -f "$tmpout"
}

ami_run_yolo() {
  # Convenience: ami_run with --yolo --output-format text
  ami_run --yolo --output-format text "$@"
}

ami_run_json() {
  # Convenience: ami_run with --yolo --output-format json
  ami_run --yolo --output-format json "$@"
}

# ── Test lifecycle ─────────────────────────────────────────────────────

test_begin() {
  CURRENT_TEST="$1"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  printf "  %-60s " "$1"
}

test_pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "PASS"
}

test_fail() {
  local reason="${1:-}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILED_NAMES+=("$CURRENT_TEST")
  echo "FAIL"
  if [ -n "$reason" ]; then
    echo "    -> $reason"
  fi
}

test_skip() {
  local reason="${1:-}"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  echo "SKIP${reason:+ ($reason)}"
}

# ── Assertions ─────────────────────────────────────────────────────────

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qiF -- "$needle"; then
    return 0
  else
    test_fail "${msg:-expected '$needle' in output}"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qiF -- "$needle"; then
    test_fail "${msg:-unexpected '$needle' in output}"
    return 1
  else
    return 0
  fi
}

assert_match() {
  local haystack="$1" pattern="$2" msg="${3:-}"
  if echo "$haystack" | grep -qiE "$pattern"; then
    return 0
  else
    test_fail "${msg:-output did not match pattern '$pattern'}"
    return 1
  fi
}

assert_file_exists() {
  local filepath="$1" msg="${2:-}"
  if [ -f "$filepath" ]; then
    return 0
  else
    test_fail "${msg:-file '$filepath' does not exist}"
    return 1
  fi
}

assert_file_not_exists() {
  local filepath="$1" msg="${2:-}"
  if [ ! -f "$filepath" ]; then
    return 0
  else
    test_fail "${msg:-file '$filepath' should not exist}"
    return 1
  fi
}

assert_file_contains() {
  local filepath="$1" needle="$2" msg="${3:-}"
  if [ ! -f "$filepath" ]; then
    test_fail "${msg:-file '$filepath' does not exist}"
    return 1
  fi
  if grep -qF -- "$needle" "$filepath"; then
    return 0
  else
    test_fail "${msg:-file '$filepath' does not contain '$needle'}"
    return 1
  fi
}

assert_file_not_contains() {
  local filepath="$1" needle="$2" msg="${3:-}"
  if [ ! -f "$filepath" ]; then
    return 0
  fi
  if grep -qF -- "$needle" "$filepath"; then
    test_fail "${msg:-file '$filepath' unexpectedly contains '$needle'}"
    return 1
  else
    return 0
  fi
}

assert_exit_code() {
  local actual="$1" expected="$2" msg="${3:-}"
  if [ "$actual" -eq "$expected" ]; then
    return 0
  else
    test_fail "${msg:-expected exit code $expected, got $actual}"
    return 1
  fi
}

assert_exit_code_in() {
  # assert_exit_code_in $actual 0 3 — passes if actual is 0 or 3
  local actual="$1"
  shift
  for expected in "$@"; do
    if [ "$actual" -eq "$expected" ]; then
      return 0
    fi
  done
  test_fail "expected exit code in ($*), got $actual"
  return 1
}

assert_json_valid() {
  local data="$1" msg="${2:-}"
  if echo "$data" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    return 0
  else
    test_fail "${msg:-output is not valid JSON}"
    return 1
  fi
}

assert_line_count_gte() {
  local data="$1" min="$2" msg="${3:-}"
  local count
  count=$(echo "$data" | wc -l)
  if [ "$count" -ge "$min" ]; then
    return 0
  else
    test_fail "${msg:-expected >= $min lines, got $count}"
    return 1
  fi
}

# ── Workspace helpers ──────────────────────────────────────────────────

setup_workspace() {
  cd /tmp
  rm -rf "$TEST_WORKSPACE"
  mkdir -p "$TEST_WORKSPACE"
  cd "$TEST_WORKSPACE"
  git init -q
  git config user.email "ci@superinference.org"
  git config user.name "CI"
}

commit_workspace() {
  local msg="${1:-initial commit}"
  cd "$TEST_WORKSPACE"
  # Ensure there's always something to commit
  if [ -z "$(git status --porcelain)" ]; then
    touch .gitkeep
  fi
  git add -A
  git commit -q -m "$msg" --allow-empty
}

reset_workspace() {
  cd "$TEST_WORKSPACE"
  git checkout -q -- . 2>/dev/null || true
  git clean -fdq 2>/dev/null || true
}

# ── Suite reporting ────────────────────────────────────────────────────

suite_header() {
  SUITE_NAME="$1"
  SUITE_TAG="${1%% —*}"  # extract "03" from "03 — Write Tools"
  SUITE_TAG="${SUITE_TAG## }"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

suite_summary() {
  _SUITE_SUMMARY_CALLED=1
  echo ""
  echo "──────────────────────────────────────────────────────────────"
  printf "  %s: %d total, %d passed, %d failed, %d skipped\n" \
    "$SUITE_NAME" "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED"
  if [ "${#FAILED_NAMES[@]}" -gt 0 ]; then
    echo "  Failed:"
    for name in "${FAILED_NAMES[@]}"; do
      echo "    - $name"
    done
  fi
  echo "──────────────────────────────────────────────────────────────"

  # Export results for the runner to aggregate
  local results_file="/tmp/ami-suite-results-$$-${SUITE_TAG}.results"
  cat > "$results_file" <<RESEOF
TOTAL_TOTAL=\$((TOTAL_TOTAL + $TESTS_TOTAL))
TOTAL_PASSED=\$((TOTAL_PASSED + $TESTS_PASSED))
TOTAL_FAILED=\$((TOTAL_FAILED + $TESTS_FAILED))
TOTAL_SKIPPED=\$((TOTAL_SKIPPED + $TESTS_SKIPPED))
SUITE_RESULTS+=("${SUITE_TAG}: $TESTS_PASSED/$TESTS_TOTAL passed")
RESEOF
  for n in "${FAILED_NAMES[@]:-}"; do
    [ -n "$n" ] && echo "ALL_FAILED+=(\"[$SUITE_TAG] $n\")" >> "$results_file"
  done
}
