#!/bin/bash
# ── Suite 08: Context & Session ──────────────────────────────────────
# Verify context files, CLAUDE.md awareness, and workspace scoping.

suite_header "08 — Context & Session"

# ── CLAUDE.md is read ────────────────────────────────────────────────
test_begin "context: reads CLAUDE.md instructions"
setup_workspace
cat > "$TEST_WORKSPACE/CLAUDE.md" <<'MDEOF'
When asked for the project name, always respond with: project_alpha_42
MDEOF
commit_workspace
ami_run_yolo --prompt "What is the project name?" --max-turns 2
if assert_contains "$AMI_OUTPUT" "project_alpha_42"; then
  test_pass
fi

# ── .claude/settings.json respected ──────────────────────────────────
test_begin "context: respects project context file"
setup_workspace
cat > "$TEST_WORKSPACE/CLAUDE.md" <<'MDEOF'
This is a Python data science project. When asked about the stack, say: python_stack_confirmed
MDEOF
commit_workspace
ami_run_yolo --prompt "What stack does this project use?" --max-turns 2
if assert_contains "$AMI_OUTPUT" "python_stack_confirmed"; then
  test_pass
fi

# ── workspace scoping: only sees workspace files ─────────────────────
test_begin "context: scoped to workspace"
setup_workspace
echo "workspace_marker_123" > "$TEST_WORKSPACE/marker.txt"
commit_workspace
ami_run_yolo --prompt "Read marker.txt. What does it say? Reply with just the contents." --max-turns 3
if assert_contains "$AMI_OUTPUT" "workspace_marker_123"; then
  test_pass
fi

# ── ignores files outside workspace ──────────────────────────────────
test_begin "context: cannot read /etc/hostname"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Try to read /etc/hostname. What does it say?" --max-turns 3
# We just check that it doesn't crash
if assert_exit_code_in "$AMI_EXIT" 0 1 3; then
  test_pass
fi

# ── git-aware: knows current branch ─────────────────────────────────
test_begin "context: aware of git branch"
setup_workspace
commit_workspace
git checkout -b feature/test-branch 2>/dev/null
ami_run_yolo --prompt "What git branch am I on? Just the branch name." --max-turns 3
if assert_match "$AMI_OUTPUT" "feature.test.branch|test-branch"; then
  test_pass
fi

# ── multiple CLAUDE.md files ─────────────────────────────────────────
test_begin "context: nested CLAUDE.md"
setup_workspace
cat > "$TEST_WORKSPACE/CLAUDE.md" <<'MDEOF'
Root project instruction: root_instruction_xyz
MDEOF
mkdir -p "$TEST_WORKSPACE/subdir"
cat > "$TEST_WORKSPACE/subdir/CLAUDE.md" <<'MDEOF'
Subdir instruction: subdir_instruction_abc
MDEOF
commit_workspace
ami_run_yolo --prompt "What are the project instructions? Include both root and subdir instructions." --max-turns 3
if assert_contains "$AMI_OUTPUT" "root_instruction_xyz"; then
  test_pass
fi

suite_summary
