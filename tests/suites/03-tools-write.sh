#!/bin/bash
# ── Suite 03: Write Tools ──────────────────────────────────────────────
# Verify file creation and editing via bash.
# Uses bash for all file operations since it's the most reliable
# tool across model capabilities.

suite_header "03 — Write Tools"

# ── bash echo ─────────────────────────────────────────────────────────
test_begin "bash: echo command"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo hello_from_ami_test' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "hello_from_ami_test"; then
  test_pass
fi

# ── bash pipe ────────────────────────────────────────────────────────
test_begin "bash: pipe command"
ami_run_yolo --prompt "Run 'echo apple banana cherry | tr \" \" \"\n\" | head -1' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "apple"; then
  test_pass
fi

# ── bash pwd ──────────────────────────────────────────────────────────
test_begin "bash: pwd returns workspace"
ami_run_yolo --prompt "Run 'pwd' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "ami-test"; then
  test_pass
fi

# ── create file via bash ─────────────────────────────────────────────
test_begin "write: create file via bash"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run this in bash: echo 'hello world' > greeting.txt" --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/greeting.txt"; then
  test_pass
fi

# ── create file in subdirectory via bash ─────────────────────────────
test_begin "write: create file in subdirectory"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run: mkdir -p src && echo 'export const x = 1;' > src/index.ts" --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/src/index.ts"; then
  test_pass
fi

# ── bash exit code captured ──────────────────────────────────────────
test_begin "bash: non-zero exit code"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'exit 42' in bash. What was the exit code?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "42"; then
  test_pass
fi

# ── bash stderr captured ─────────────────────────────────────────────
test_begin "bash: stderr captured"
ami_run_yolo --prompt "Run 'echo error_output >&2' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "error_output"; then
  test_pass
fi

suite_summary
