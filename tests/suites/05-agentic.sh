#!/bin/bash
# ── Suite 05: Agentic Behavior ────────────────────────────────────────
# Verify multi-turn, multi-tool, and reasoning capabilities.
# Uses short timeouts and low max-turns to stay within free-tier quotas.

suite_header "05 — Agentic Behavior"

# ── bug detection ────────────────────────────────────────────────────
test_begin "agentic: detects bug in code"
setup_workspace
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Read buggy.ts and tell me what the reverseArray function does. Be brief." --max-turns 3
if assert_match "$AMI_OUTPUT" "sort|reverse|array|arr"; then
  test_pass
fi

# ── fix bug ──────────────────────────────────────────────────────────
test_begin "agentic: fixes bug in file"
setup_workspace
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "In buggy.ts, the reverseArray function calls .sort() but should call .reverse(). Fix it." --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/buggy.ts"; then
  if assert_file_contains "$TEST_WORKSPACE/buggy.ts" "reverse"; then
    test_pass
  fi
fi

# ── multi-file creation ─────────────────────────────────────────────
test_begin "agentic: creates file"
setup_workspace
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Create a file called app.ts with the content: export const name = 'app';" --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/app.ts"; then
  test_pass
fi

# ── code explanation ─────────────────────────────────────────────────
test_begin "agentic: explains code"
setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Read main.ts and list the function names defined in it." --max-turns 3
if assert_match "$AMI_OUTPUT" "add|subtract|greet"; then
  test_pass
fi

# ── multi-step reasoning ────────────────────────────────────────────
test_begin "agentic: multi-step reasoning"
setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Read main.ts. How many functions are exported? Reply with the number." --max-turns 3
if assert_match "$AMI_OUTPUT" "[2-4]"; then
  test_pass
fi

# ── read and edit ───────────────────────────────────────────────────
test_begin "agentic: read then edit"
setup_workspace
echo "hello world" > "$TEST_WORKSPACE/data.txt"
commit_workspace
AMI_TIMEOUT=45 ami_run_yolo --prompt "Read data.txt, then replace 'world' with 'universe' in it." --max-turns 5
if assert_file_contains "$TEST_WORKSPACE/data.txt" "universe"; then
  test_pass
fi

suite_summary
