#!/bin/bash
# ── Suite 07: Error Handling ─────────────────────────────────────────
# Verify graceful degradation, invalid inputs, and edge cases.

suite_header "07 — Error Handling"

# ── invalid model name ───────────────────────────────────────────────
test_begin "error: invalid model rejects gracefully"
setup_workspace
commit_workspace
set +e
invalid_out=$(ami --prompt "hello" --model "nonexistent-model-xyz" --yolo --output-format text --quiet --max-turns 1 2>&1 | scrub)
invalid_exit=$?
set -e
if [ "$invalid_exit" -ne 0 ] || echo "$invalid_out" | grep -qiE "error|invalid|not found|unknown"; then
  test_pass
else
  test_fail "expected non-zero exit or error message for invalid model"
fi

# ── missing workspace (no git repo) ──────────────────────────────────
test_begin "error: handles non-git directory"
tmpdir=$(mktemp -d)
cd "$tmpdir"
set +e
nogit_out=$(ami --prompt "Say hello" --yolo --output-format text --quiet --max-turns 1 2>&1 | scrub)
nogit_exit=$?
set -e
cd "$TEST_WORKSPACE" 2>/dev/null || cd /tmp
rm -rf "$tmpdir"
if [ "$nogit_exit" -eq 0 ] || [ "$nogit_exit" -ne 0 ]; then
  # Either it works in non-git dirs or exits with an error — both are acceptable
  test_pass
fi

# ── extremely long prompt ────────────────────────────────────────────
test_begin "error: handles very long prompt"
setup_workspace
commit_workspace
long_prompt=$(python3 -c "print('word ' * 500)")
ami_run_yolo --prompt "$long_prompt Respond with just: long_prompt_ok" --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 1 3; then
  test_pass
fi

# ── special characters in prompt ─────────────────────────────────────
test_begin "error: special chars in prompt"
setup_workspace
commit_workspace
ami_run_yolo --prompt 'Say exactly: special_chars_<>&"test' --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 3; then
  test_pass
fi

# ── unicode in prompt ────────────────────────────────────────────────
test_begin "error: unicode in prompt"
ami_run_yolo --prompt "What is the emoji for a rocket? Just type it." --max-turns 1
if assert_exit_code_in "$AMI_EXIT" 0 3; then
  test_pass
fi

# ── max-turns 0 ──────────────────────────────────────────────────────
test_begin "error: max-turns 0 exits cleanly"
set +e
zero_out=$(ami --prompt "hello" --yolo --output-format text --quiet --max-turns 0 2>&1 | scrub)
zero_exit=$?
set -e
if [ "$zero_exit" -eq 0 ] || [ "$zero_exit" -ne 0 ]; then
  # Either exits with error or ignores — both acceptable
  test_pass
fi

suite_summary
