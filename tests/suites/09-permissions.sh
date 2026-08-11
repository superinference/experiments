#!/bin/bash
# ── Suite 09: Permissions ─────────────────────────────────────────────
# Verify --yolo enables all tools and basic operations work.

suite_header "09 — Permissions"

# ── yolo allows bash ─────────────────────────────────────────────────
test_begin "permissions: yolo allows bash"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo permission_ok' in bash." --max-turns 3
if assert_contains "$AMI_OUTPUT" "permission_ok"; then
  test_pass
fi

# ── yolo allows file write ───────────────────────────────────────────
test_begin "permissions: yolo allows file creation"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file called test.txt containing 'created_ok'." --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/test.txt"; then
  test_pass
fi

# ── yolo allows edit ─────────────────────────────────────────────────
test_begin "permissions: yolo allows file edit"
setup_workspace
echo "before" > "$TEST_WORKSPACE/editable.txt"
commit_workspace
ami_run_yolo --prompt "Replace the word 'before' with 'after' in editable.txt." --max-turns 5
if assert_file_contains "$TEST_WORKSPACE/editable.txt" "after"; then
  test_pass
fi

# ── yolo multi-tool ──────────────────────────────────────────────────
test_begin "permissions: yolo multi-tool"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo 42' in bash. What number did it print?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "42"; then
  test_pass
fi

# ── read without yolo ───────────────────────────────────────────────
test_begin "permissions: read works without yolo"
setup_workspace
echo "readable_data" > "$TEST_WORKSPACE/info.txt"
commit_workspace
ami_run --output-format text --prompt "Read info.txt. What does it contain?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "readable_data"; then
  test_pass
fi

suite_summary
