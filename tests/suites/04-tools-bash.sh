#!/bin/bash
# ── Suite 04: Bash Tool ───────────────────────────────────────────────
# Verify bash execution, stderr, exit codes, and edge cases.

suite_header "04 — Bash Tool"

# ── environment variable access ──────────────────────────────────────
test_begin "bash: reads env variable"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo \$HOME' in bash. Show the output." --max-turns 2
if assert_match "$AMI_OUTPUT" "/home|/root|/Users"; then
  test_pass
fi

# ── file manipulation via bash ───────────────────────────────────────
test_begin "bash: echo redirect"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run this exact bash command and show the output: echo test123" --max-turns 2
if assert_contains "$AMI_OUTPUT" "test123"; then
  test_pass
fi

# ── command chaining ─────────────────────────────────────────────────
test_begin "bash: command chaining with &&"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'mkdir -p mydir && touch mydir/file.txt && ls mydir' in bash. Show the output." --max-turns 3
if assert_contains "$AMI_OUTPUT" "file.txt"; then
  test_pass
fi

# ── loop execution ───────────────────────────────────────────────────
test_begin "bash: for loop"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run a bash for loop: for i in 1 2 3; do echo num_\$i; done. Show the output." --max-turns 3
if assert_contains "$AMI_OUTPUT" "num_1" && assert_contains "$AMI_OUTPUT" "num_3"; then
  test_pass
fi

# ── process substitution and wc ──────────────────────────────────────
test_begin "bash: wc counts"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo -e \"line1\nline2\nline3\" | wc -l' in bash. What number does it output?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "3"; then
  test_pass
fi

# ── git commands work ────────────────────────────────────────────────
test_begin "bash: git log works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'git log --oneline -1' in bash. Show the output." --max-turns 3
if assert_match "$AMI_OUTPUT" "initial commit|init|commit"; then
  test_pass
fi

# ── timeout behavior (max-turns enforces) ────────────────────────────
test_begin "bash: long-running bounded by max-turns"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo bounded_test' in bash." --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 3; then
  test_pass
fi

suite_summary
