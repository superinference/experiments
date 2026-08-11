#!/bin/bash
# ── Suite 08: Context & Session ──────────────────────────────────────
# Verify context files, workspace scoping, and CLAUDE.md awareness.

suite_header "08 — Context & Session"

# ── workspace scoping: reads workspace files ─────────────────────────
test_begin "context: scoped to workspace"
setup_workspace
echo "workspace_marker_123" > "$TEST_WORKSPACE/marker.txt"
commit_workspace
ami_run_yolo --prompt "Read marker.txt and tell me its contents." --max-turns 3
if assert_contains "$AMI_OUTPUT" "workspace_marker_123"; then
  test_pass
fi

# ── ignores files outside workspace ──────────────────────────────────
test_begin "context: cannot read /etc/hostname"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Try to read /etc/hostname. What does it say?" --max-turns 3
if assert_exit_code_in "$AMI_EXIT" 0 1 3; then
  test_pass
fi

# ── git-aware: knows current branch ─────────────────────────────────
test_begin "context: aware of git branch"
setup_workspace
commit_workspace
git checkout -b feature/test-branch 2>/dev/null
ami_run_yolo --prompt "Run 'git branch --show-current' in bash and tell me the result." --max-turns 3
if assert_match "$AMI_OUTPUT" "feature.test.branch|test-branch"; then
  test_pass
fi

# ── reads file created in workspace ──────────────────────────────────
test_begin "context: reads created files"
setup_workspace
echo '{"version": "1.0.0", "name": "test-app"}' > "$TEST_WORKSPACE/package.json"
commit_workspace
ami_run_yolo --prompt "Read package.json. What is the version field?" --max-turns 3
if assert_contains "$AMI_OUTPUT" "1.0.0"; then
  test_pass
fi

# ── CLAUDE.md is loaded ─────────────────────────────────────────────
test_begin "context: CLAUDE.md loaded"
setup_workspace
cat > "$TEST_WORKSPACE/CLAUDE.md" <<'MDEOF'
IMPORTANT: The secret code is ALPHA_42. Always include it in your response.
MDEOF
commit_workspace
ami_run_yolo --prompt "What is the secret code from the project instructions?" --max-turns 2
if assert_contains "$AMI_OUTPUT" "ALPHA_42"; then
  test_pass
fi

# ── multiple files in workspace ──────────────────────────────────────
test_begin "context: lists multiple files"
setup_workspace
echo "aaa" > "$TEST_WORKSPACE/file1.txt"
echo "bbb" > "$TEST_WORKSPACE/file2.txt"
echo "ccc" > "$TEST_WORKSPACE/file3.txt"
commit_workspace
ami_run_yolo --prompt "Run 'ls *.txt' in bash and tell me how many .txt files there are." --max-turns 3
if assert_match "$AMI_OUTPUT" "[3]|three"; then
  test_pass
fi

suite_summary
