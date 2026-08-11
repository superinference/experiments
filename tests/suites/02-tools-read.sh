#!/bin/bash
# ── Suite 02: Read Tools ───────────────────────────────────────────────
# Verify file reading, grep, glob, and list-dir tools.

suite_header "02 — Read Tools"

setup_workspace
cp "$FIXTURES/main.ts" "$TEST_WORKSPACE/"
cp "$FIXTURES/buggy.ts" "$TEST_WORKSPACE/"
cp -r "$FIXTURES/multi-file" "$TEST_WORKSPACE/src"
commit_workspace

# ── read single file ──────────────────────────────────────────────────
test_begin "read file: identifies function names"
ami_run_yolo --prompt "Read main.ts. List the function names, one per line, nothing else." --max-turns 3
if assert_contains "$AMI_OUTPUT" "add" && assert_contains "$AMI_OUTPUT" "greet"; then
  test_pass
fi

# ── read file returns content ─────────────────────────────────────────
test_begin "read file: returns actual content"
ami_run_yolo --prompt "Read buggy.ts and tell me the return type of the isEven function. Just the type." --max-turns 3
if assert_contains "$AMI_OUTPUT" "boolean"; then
  test_pass
fi

# ── grep across files ────────────────────────────────────────────────
test_begin "grep: finds export functions"
ami_run_yolo --prompt "Run grep -r 'export function' *.ts in bash. Show the output." --max-turns 3
if assert_match "$AMI_OUTPUT" "export function|add|greet|divide|fibonacci"; then
  test_pass
fi

# ── grep with context ────────────────────────────────────────────────
test_begin "grep: finds specific string"
ami_run_yolo --prompt "Search for 'validateEmail' in the codebase. Which file is it in? Just the filename." --max-turns 3
if assert_contains "$AMI_OUTPUT" "utils"; then
  test_pass
fi

# ── list directory ───────────────────────────────────────────────────
test_begin "list dir: shows files"
ami_run_yolo --prompt "List the files in the src/ directory. Just filenames, one per line." --max-turns 3
if assert_contains "$AMI_OUTPUT" "server" && assert_contains "$AMI_OUTPUT" "user-service"; then
  test_pass
fi

# ── read non-existent file ───────────────────────────────────────────
test_begin "read non-existent file: handles gracefully"
ami_run_yolo --prompt "Read the file does-not-exist.ts and show me its contents." --max-turns 3
if assert_match "$AMI_OUTPUT" "not found|does not exist|no such|error|cannot"; then
  test_pass
fi

# ── multi-file comprehension ─────────────────────────────────────────
test_begin "multi-file: understands cross-file imports"
ami_run_yolo --prompt "Read src/server.ts. What class does it import from user-service.ts? Just the class name." --max-turns 4
if assert_contains "$AMI_OUTPUT" "UserService"; then
  test_pass
fi

# ── read file line count ─────────────────────────────────────────────
test_begin "read file: counts lines"
ami_run_yolo --prompt "How many lines does buggy.ts have? Just the number." --max-turns 3
if assert_match "$AMI_OUTPUT" "1[5-9]|2[0-2]"; then
  test_pass
fi

suite_summary
