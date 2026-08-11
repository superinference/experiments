#!/bin/bash
# ── Suite 02: Read Tools ───────────────────────────────────────────────
# Verify file reading, grep, and directory listing tools work.

suite_header "02 — Read Tools"

setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
cp -r "$FIXTURES/multi-file" "$TEST_WORKSPACE/src"
commit_workspace

# ── read file produces output ────────────────────────────────────────
test_begin "read file: produces output"
ami_run_yolo --prompt "Read main.ts" --max-turns 2
if [ -n "$AMI_OUTPUT" ] && [ ${#AMI_OUTPUT} -gt 10 ]; then
  test_pass
else
  test_fail "empty or too short output"
fi

# ── grep via bash works ──────────────────────────────────────────────
test_begin "grep: finds pattern"
ami_run_yolo --prompt "Run 'grep -c function main.ts' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "[2-9]"; then
  test_pass
fi

# ── list directory via bash ──────────────────────────────────────────
test_begin "list dir: shows files"
ami_run_yolo --prompt "Run 'ls src/' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "server|utils|user"; then
  test_pass
fi

# ── read non-existent file ───────────────────────────────────────────
test_begin "read non-existent file: handles gracefully"
ami_run_yolo --prompt "Read the file does-not-exist.ts" --max-turns 2
if assert_match "$AMI_OUTPUT" "not found|does not exist|no such|error|cannot|Error"; then
  test_pass
fi

# ── read file via bash cat ───────────────────────────────────────────
test_begin "read file: via bash cat"
ami_run_yolo --prompt "Run 'cat main.ts' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "function|export|return"; then
  test_pass
fi

# ── count lines via bash ────────────────────────────────────────────
test_begin "read file: line count via wc"
ami_run_yolo --prompt "Run 'wc -l buggy.ts' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "1[5-9]|2[0-2]"; then
  test_pass
fi

suite_summary
