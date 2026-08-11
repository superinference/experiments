#!/bin/bash
# ── Suite 05: Agentic Behavior ────────────────────────────────────────
# Verify multi-turn, multi-tool, and reasoning capabilities.

suite_header "05 — Agentic Behavior"

# ── bug detection ────────────────────────────────────────────────────
test_begin "agentic: detects bug in code"
setup_workspace
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
commit_workspace
ami_run_yolo --prompt "Read buggy.ts. The reverseArray function has a bug — it calls sort() instead of reverse(). Confirm this bug exists by reading the file and telling me what reverseArray does wrong." --max-turns 5
if assert_match "$AMI_OUTPUT" "sort|reverse|bug|wrong|incorrect|order"; then
  test_pass
fi

# ── fix bug ──────────────────────────────────────────────────────────
test_begin "agentic: fixes bug in file"
setup_workspace
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
commit_workspace
ami_run_yolo --prompt "Read buggy.ts, find the bug in the fibonacci function, and fix it in place." --max-turns 8
if assert_file_exists "$TEST_WORKSPACE/buggy.ts"; then
  original_content=$(cat "$FIXTURES/buggy.ts")
  current_content=$(cat "$TEST_WORKSPACE/buggy.ts")
  if [ "$original_content" != "$current_content" ]; then
    test_pass
  else
    test_fail "file was not modified"
  fi
fi

# ── multi-file creation ─────────────────────────────────────────────
test_begin "agentic: creates project structure"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create these two files: 1) src/index.ts containing: export const name = 'app'; 2) tsconfig.json containing: {\"compilerOptions\":{\"strict\":true}}. Use mkdir -p src first." --max-turns 10
if assert_file_exists "$TEST_WORKSPACE/src/index.ts" && \
   assert_file_exists "$TEST_WORKSPACE/tsconfig.json"; then
  test_pass
fi

# ── refactoring ──────────────────────────────────────────────────────
test_begin "agentic: renames function across files"
setup_workspace
cp -r "$FIXTURES/multi-file" "$TEST_WORKSPACE/src"
commit_workspace
ami_run_yolo --prompt "Rename the function 'validateEmail' to 'isValidEmail' in all files under src/. Update all references." --max-turns 8
if assert_file_contains "$TEST_WORKSPACE/src/utils.ts" "isValidEmail" && \
   assert_file_not_contains "$TEST_WORKSPACE/src/utils.ts" "validateEmail"; then
  test_pass
fi

# ── code explanation ─────────────────────────────────────────────────
test_begin "agentic: explains code architecture"
setup_workspace
cp -r "$FIXTURES/multi-file" "$TEST_WORKSPACE/src"
commit_workspace
ami_run_yolo --prompt "Read all files in src/. Explain in 2-3 sentences what this application does." --max-turns 5
if assert_match "$AMI_OUTPUT" "user|server|service|http|api"; then
  test_pass
fi

# ── multi-step reasoning ────────────────────────────────────────────
test_begin "agentic: multi-step reasoning"
setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
commit_workspace
ami_run_yolo --prompt "Read main.ts and buggy.ts. Count the total number of exported functions across both files. What is the number?" --max-turns 5
if assert_match "$AMI_OUTPUT" "[5-9]"; then
  test_pass
fi

suite_summary
