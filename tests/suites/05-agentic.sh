#!/bin/bash
# ── Suite 05: Agentic Behavior ────────────────────────────────────────
# Verify multi-turn tool use works. Short timeouts to conserve quota.

suite_header "05 — Agentic Behavior"

# ── read and respond ─────────────────────────────────────────────────
test_begin "agentic: read and respond"
setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Run 'cat main.ts' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "function|export|add|greet"; then
  test_pass
fi

# ── bash then report ─────────────────────────────────────────────────
test_begin "agentic: bash then report"
setup_workspace
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Run 'echo hello_agent' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "hello_agent"; then
  test_pass
fi

# ── create file via bash ─────────────────────────────────────────────
test_begin "agentic: create file"
setup_workspace
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Run: echo 'test content' > output.txt" --max-turns 3
if assert_file_exists "$TEST_WORKSPACE/output.txt"; then
  test_pass
fi

# ── multi-step bash ──────────────────────────────────────────────────
test_begin "agentic: multi-step bash"
setup_workspace
commit_workspace
AMI_TIMEOUT=90 ami_run_yolo --prompt "Run these two commands: 'mkdir -p data' then 'echo done > data/status.txt'" --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/data/status.txt"; then
  test_pass
fi

suite_summary
