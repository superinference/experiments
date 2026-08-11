#!/bin/bash
# ── Suite 06: Output Formats ─────────────────────────────────────────
# Verify JSON, JSONL, text output modes.

suite_header "06 — Output Formats"

# ── text output produces content ────────────────────────────────────
test_begin "format: text output works"
setup_workspace
commit_workspace
ami_run_yolo --prompt "Say hello" --max-turns 1
if [ -n "$AMI_OUTPUT" ] && [ ${#AMI_OUTPUT} -gt 1 ]; then
  test_pass
else
  test_fail "empty or no text output"
fi

# ── json output is valid ─────────────────────────────────────────────
test_begin "format: json output is valid JSON"
setup_workspace
commit_workspace
ami_run_json --prompt "Say hello" --max-turns 1
if assert_json_valid "$AMI_OUTPUT"; then
  test_pass
fi

# ── json has content ────────────────────────────────────────────────
test_begin "format: json has content"
if [ -n "$AMI_OUTPUT" ] && [ ${#AMI_OUTPUT} -gt 2 ]; then
  test_pass
else
  test_fail "JSON output is empty or too short"
fi

# ── jsonl output ─────────────────────────────────────────────────────
test_begin "format: jsonl output has valid lines"
setup_workspace
commit_workspace
ami_run --yolo --output-format jsonl --prompt "Say hello" --max-turns 1
first_line=$(echo "$AMI_OUTPUT" | head -1)
if [ -n "$first_line" ]; then
  if echo "$first_line" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    test_pass
  else
    test_fail "first JSONL line is not valid JSON"
  fi
else
  test_fail "no output in JSONL mode"
fi

# ── json with tool use ──────────────────────────────────────────────
test_begin "format: json captures tool use"
setup_workspace
commit_workspace
ami_run_json --prompt "Run 'echo test' in bash" --max-turns 3
if assert_json_valid "$AMI_OUTPUT"; then
  test_pass
fi

suite_summary
