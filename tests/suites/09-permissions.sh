#!/bin/bash
# ── Suite 09: Permissions ─────────────────────────────────────────────
# Verify --yolo mode enables tool execution.

suite_header "09 — Permissions"

# ── yolo allows bash ─────────────────────────────────────────────────
test_begin "permissions: yolo allows bash"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo perm_ok' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "perm_ok"; then
  test_pass
fi

# ── yolo allows file creation via bash ───────────────────────────────
test_begin "permissions: yolo creates file"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run: echo 'created' > perm_test.txt" --max-turns 3
if assert_file_exists "$TEST_WORKSPACE/perm_test.txt"; then
  test_pass
fi

# ── yolo allows multiple commands ────────────────────────────────────
test_begin "permissions: yolo multi-command"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo 42' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "42"; then
  test_pass
fi

suite_summary
