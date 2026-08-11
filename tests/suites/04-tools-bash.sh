#!/bin/bash
# ── Suite 04: Bash Tool ───────────────────────────────────────────────
# Verify bash execution, env vars, exit codes, and edge cases.

suite_header "04 — Bash Tool"

# ── environment variable access ──────────────────────────────────────
test_begin "bash: reads env variable"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo \$HOME' in bash" --max-turns 2
if assert_match "$AMI_OUTPUT" "/home|/root|/Users|/tmp"; then
  test_pass
fi

# ── simple echo ─────────────────────────────────────────────────────
test_begin "bash: echo output"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo test123' in bash" --max-turns 2
if assert_contains "$AMI_OUTPUT" "test123"; then
  test_pass
fi

# ── command chaining ─────────────────────────────────────────────────
test_begin "bash: command chaining"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'mkdir -p mydir && touch mydir/file.txt && ls mydir' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "file.txt"; then
  test_pass
fi

# ── git commands work ────────────────────────────────────────────────
test_begin "bash: git log works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'git log --oneline -1' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "initial commit|init|commit"; then
  test_pass
fi

# ── max-turns enforced ───────────────────────────────────────────────
test_begin "bash: bounded by max-turns"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Say hello" --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 3; then
  test_pass
fi

suite_summary
