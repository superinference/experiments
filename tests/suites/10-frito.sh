#!/bin/bash
# ── Suite 10: FRITO Routing ──────────────────────────────────────────
# Verify FRITO model routing when AMI_FRITO is set.

suite_header "10 — FRITO Routing"

# ── skip if no FRITO config ──────────────────────────────────────────
if [ -z "${AMI_FRITO:-}" ] && [ ! -f "$HOME/.ami/frito.json" ]; then
  test_begin "frito: skip (no AMI_FRITO or frito.json)"
  test_skip "AMI_FRITO not set and ~/.ami/frito.json not found"

  suite_summary
  return 0 2>/dev/null || exit 0
fi

# ── basic frito prompt ───────────────────────────────────────────────
test_begin "frito: basic prompt works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Say exactly: frito_routing_ok" --max-turns 1
if assert_contains "$AMI_OUTPUT" "frito_routing_ok"; then
  test_pass
fi

# ── frito tool use ───────────────────────────────────────────────────
test_begin "frito: tool use works"
setup_workspace
echo "frito_marker_content" > "$TEST_WORKSPACE/frito_test.txt"
commit_workspace
ami_run_yolo --prompt "Read frito_test.txt. What does it say?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "frito_marker_content"; then
  test_pass
fi

# ── frito file creation ──────────────────────────────────────────────
test_begin "frito: file creation works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file called frito_output.txt with the text 'frito_created'." --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/frito_output.txt" && \
   assert_file_contains "$TEST_WORKSPACE/frito_output.txt" "frito_created"; then
  test_pass
fi

# ── frito bash execution ─────────────────────────────────────────────
test_begin "frito: bash execution works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo frito_bash_confirmed' in bash." --max-turns 3
if assert_contains "$AMI_OUTPUT" "frito_bash_confirmed"; then
  test_pass
fi

# ── frito multi-turn ─────────────────────────────────────────────────
test_begin "frito: multi-turn task"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo hello_frito > frito_multi.txt && cat frito_multi.txt' in bash. Show the output." --max-turns 5
if assert_contains "$AMI_OUTPUT" "hello_frito"; then
  test_pass
fi

suite_summary
