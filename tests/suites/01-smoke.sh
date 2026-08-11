#!/bin/bash
# ── Suite 01: Smoke Tests ──────────────────────────────────────────────
# Verify AMI is installed and can handle basic interactions.

suite_header "01 — Smoke Tests"

# ── version flag ───────────────────────────────────────────────────────
test_begin "ami --version prints version"
version_out=$(ami --version 2>/dev/null || true)
if assert_match "$version_out" "[0-9]+\.[0-9]+"; then
  test_pass
fi

# ── help flag ──────────────────────────────────────────────────────────
test_begin "ami --help shows usage"
help_out=$(ami --help 2>/dev/null || true)
if assert_contains "$help_out" "Usage" && assert_contains "$help_out" "--prompt"; then
  test_pass
fi

# ── basic prompt ───────────────────────────────────────────────────────
test_begin "basic prompt returns a response"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Say exactly: PONG" --max-turns 1
if assert_contains "$AMI_OUTPUT" "PONG"; then
  test_pass
fi

# ── arithmetic reasoning ──────────────────────────────────────────────
test_begin "arithmetic: 17 * 23"
ami_run_yolo --prompt "What is 17 * 23? Reply with just the number." --max-turns 1
if assert_contains "$AMI_OUTPUT" "391"; then
  test_pass
fi

# ── empty prompt ──────────────────────────────────────────────────────
test_begin "empty prompt exits gracefully"
set +e
ami --prompt "" --yolo --output-format text --quiet 2>/dev/null | scrub > /dev/null
empty_exit=$?
set -e
if [ "$empty_exit" -eq 0 ] || [ "$empty_exit" -eq 1 ]; then
  test_pass
else
  test_fail "unexpected exit code $empty_exit"
fi

# ── max-turns 1 limits turns ──────────────────────────────────────────
test_begin "max-turns 1 limits execution"
ami_run_yolo --prompt "Write a very long essay about the history of computing." --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 3; then
  test_pass
fi

# ── quiet mode suppresses stderr ──────────────────────────────────────
test_begin "quiet mode suppresses stderr"
stderr_out=$(timeout 60 ami --prompt "Say hello" --yolo --output-format text --max-turns 1 --quiet 2>&1 1>/dev/null | scrub || true)
if [ -z "$stderr_out" ] || ! echo "$stderr_out" | grep -qiF -- "error"; then
  test_pass
else
  test_fail "stderr contained error output"
fi

suite_summary
