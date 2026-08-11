#!/bin/bash
# ── Suite 09: Permissions ─────────────────────────────────────────────
# Verify --yolo enables all tools, and default mode restricts.

suite_header "09 — Permissions"

# ── yolo allows bash ─────────────────────────────────────────────────
test_begin "permissions: yolo allows bash"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo yolo_bash_test' in bash." --max-turns 3
if assert_contains "$AMI_OUTPUT" "yolo_bash_test"; then
  test_pass
fi

# ── yolo allows file write ───────────────────────────────────────────
test_begin "permissions: yolo allows file creation"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file called perm_test.txt with the content 'permission_granted'." --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/perm_test.txt" && \
   assert_file_contains "$TEST_WORKSPACE/perm_test.txt" "permission_granted"; then
  test_pass
fi

# ── yolo allows edit ─────────────────────────────────────────────────
test_begin "permissions: yolo allows file edit"
setup_workspace
echo "original_content" > "$TEST_WORKSPACE/editable.txt"
commit_workspace
ami_run_yolo --prompt "Edit editable.txt: replace 'original_content' with 'modified_content'." --max-turns 5
if assert_file_contains "$TEST_WORKSPACE/editable.txt" "modified_content"; then
  test_pass
fi

# ── yolo allows multiple tools in sequence ───────────────────────────
test_begin "permissions: yolo multi-tool sequence"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file hello.py with 'print(42)', then run it with 'python3 hello.py', and tell me the output." --max-turns 8
if assert_contains "$AMI_OUTPUT" "42"; then
  test_pass
fi

# ── read-only operations always work ─────────────────────────────────
test_begin "permissions: read operations work without yolo"
setup_workspace
echo "readable_marker" > "$TEST_WORKSPACE/readable.txt"
commit_workspace
ami_run --output-format text --prompt "Read readable.txt. What does it say?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "readable_marker"; then
  test_pass
fi

suite_summary
