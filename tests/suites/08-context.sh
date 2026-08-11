#!/bin/bash
# ── Suite 08: Context & Session ──────────────────────────────────────
# Verify workspace scoping and basic context handling.

suite_header "08 — Context & Session"

# ── workspace scoping ───────────────────────────────────────────────
test_begin "context: scoped to workspace"
setup_workspace
echo "marker_123" > "$TEST_WORKSPACE/marker.txt"
commit_workspace
ami_run_yolo --prompt "Run 'cat marker.txt' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "marker_123"; then
  test_pass
fi

# ── does not crash on external path ──────────────────────────────────
test_begin "context: handles external path"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Try to read /etc/hostname" --max-turns 3
if assert_exit_code_in "$AMI_EXIT" 0 1 3; then
  test_pass
fi

# ── git branch via bash ─────────────────────────────────────────────
test_begin "context: git branch"
setup_workspace
commit_workspace
git checkout -b feature/test-branch 2>/dev/null
ami_run_yolo --prompt "Run 'git branch --show-current' in bash" --max-turns 3
if assert_match "$AMI_OUTPUT" "feature.test.branch|test-branch"; then
  test_pass
fi

# ── reads file via bash ─────────────────────────────────────────────
test_begin "context: reads workspace files"
setup_workspace
echo '{"name":"test-app"}' > "$TEST_WORKSPACE/package.json"
commit_workspace
ami_run_yolo --prompt "Run 'cat package.json' in bash" --max-turns 3
if assert_contains "$AMI_OUTPUT" "test-app"; then
  test_pass
fi

suite_summary
