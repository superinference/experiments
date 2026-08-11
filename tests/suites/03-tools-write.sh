#!/bin/bash
# ── Suite 03: Write Tools ──────────────────────────────────────────────
# Verify file creation, editing, and bash tool.

suite_header "03 — Write Tools"

# ── bash echo ─────────────────────────────────────────────────────────
test_begin "bash: echo command"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'echo hello_from_ami_test' in bash. Show me the output." --max-turns 3
if assert_contains "$AMI_OUTPUT" "hello_from_ami_test"; then
  test_pass
fi

# ── bash multi-command ────────────────────────────────────────────────
test_begin "bash: multi-command with pipe"
ami_run_yolo --prompt "Run: echo 'apple banana cherry' | tr ' ' '\n' | sort | head -1. Just show the output." --max-turns 3
if assert_contains "$AMI_OUTPUT" "apple"; then
  test_pass
fi

# ── bash pwd ──────────────────────────────────────────────────────────
test_begin "bash: pwd returns workspace"
ami_run_yolo --prompt "Run pwd in bash. Show just the path." --max-turns 3
if assert_contains "$AMI_OUTPUT" "ami-test"; then
  test_pass
fi

# ── create new file ──────────────────────────────────────────────────
test_begin "write: create new file"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file called hello.ts with a function hello() that returns 'world'." --max-turns 5
if assert_file_exists "$TEST_WORKSPACE/hello.ts" && \
   assert_file_contains "$TEST_WORKSPACE/hello.ts" "hello" && \
   assert_file_contains "$TEST_WORKSPACE/hello.ts" "world"; then
  test_pass
fi

# ── edit existing file ───────────────────────────────────────────────
test_begin "edit: modify existing file"
setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
commit_workspace
ami_run_yolo --prompt "Edit main.ts: add a multiply function that takes two numbers and returns a*b." --max-turns 5
if assert_file_contains "$TEST_WORKSPACE/main.ts" "multiply"; then
  test_pass
fi

# ── edit preserves existing content ──────────────────────────────────
test_begin "edit: preserves existing functions"
if assert_file_contains "$TEST_WORKSPACE/main.ts" "add" && \
   assert_file_contains "$TEST_WORKSPACE/main.ts" "greet"; then
  test_pass
fi

# ── create multiple files ────────────────────────────────────────────
test_begin "write: create multiple files"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Create a file called config.ts with: export interface Config { host: string; port: number; }. Then create a file called index.ts with: import { Config } from './config';" --max-turns 10
if assert_file_exists "$TEST_WORKSPACE/config.ts" && \
   assert_file_exists "$TEST_WORKSPACE/index.ts"; then
  test_pass
fi

# ── create file in subdirectory ──────────────────────────────────────
test_begin "write: create file in new subdirectory"
setup_workspace
commit_workspace
ami_run_yolo --prompt "First run 'mkdir -p src' in bash. Then create the file src/math.ts with: export function sum(nums: number[]): number { return nums.reduce((a, b) => a + b, 0); }" --max-turns 8
if assert_file_exists "$TEST_WORKSPACE/src/math.ts" && \
   assert_file_contains "$TEST_WORKSPACE/src/math.ts" "sum"; then
  test_pass
fi

# ── bash exit code captured ──────────────────────────────────────────
test_begin "bash: non-zero exit code reported"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Run 'exit 42' in bash. Tell me the exit code." --max-turns 3
if assert_contains "$AMI_OUTPUT" "42"; then
  test_pass
fi

# ── bash stderr captured ─────────────────────────────────────────────
test_begin "bash: stderr captured"
ami_run_yolo --prompt "Run 'echo error_output >&2' in bash. Show me what was printed." --max-turns 3
if assert_contains "$AMI_OUTPUT" "error_output"; then
  test_pass
fi

suite_summary
