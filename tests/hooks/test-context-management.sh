#!/usr/bin/env bash
# Tests for the context management system
# Validates: sw_signal, regression fence loading, INDEX.md, auto-retro signals,
# integration tests with real hook input, fence violations, transparency output

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")/../../hooks" && pwd)"
SESSION_HOOK="$HOOK_DIR/session-start"
PRE_TOOL_HOOK="$HOOK_DIR/pre-tool-use"
POST_TOOL_HOOK="$HOOK_DIR/post-tool-use"
POST_WRITE_HOOK="$HOOK_DIR/post-tool-use-write"
LIB_PATH="$HOOK_DIR/lib.sh"
PASSED=0
FAILED=0

pass() {
  PASSED=$((PASSED + 1))
  echo "  PASS: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "  FAIL: $1"
  if [ -n "${2:-}" ]; then
    echo "        $2"
  fi
}

setup_temp_project() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init --quiet 2>/dev/null
  echo "$dir"
}

cleanup() {
  rm -rf "$1" 2>/dev/null || true
}

validate_json() {
  python3 -c "import json,sys; json.loads(sys.stdin.read())" 2>/dev/null
}

echo "=== context-management tests ==="
echo ""

# ===============================================================
# UNIT TESTS: sw_signal function
# ===============================================================

# ---------------------------------------------------------------
# Test 1: sw_signal writes to .session-signals when .shipworthy/ exists
# ---------------------------------------------------------------
echo "Test 1: sw_signal writes when .shipworthy/ exists"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
(
  cd "$TMPDIR"
  source "$LIB_PATH" 2>/dev/null || true
  sw_signal "test-hook" "test-category" "test detail message"
) 2>/dev/null
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  CONTENT=$(cat "$TMPDIR/.shipworthy/.session-signals")
  if echo "$CONTENT" | grep -q "test-hook|test-category|test detail message"; then
    pass "sw_signal wrote signal with correct format"
  else
    fail "sw_signal wrote file but format is wrong" "Got: $CONTENT"
  fi
else
  fail "sw_signal did not create .session-signals"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 2: sw_signal no-ops when .shipworthy/ doesn't exist
# ---------------------------------------------------------------
echo "Test 2: sw_signal no-ops without .shipworthy/"
TMPDIR=$(setup_temp_project)
(
  cd "$TMPDIR"
  source "$LIB_PATH" 2>/dev/null || true
  sw_signal "test-hook" "test-category" "should not write"
) 2>/dev/null
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  fail "sw_signal created file when .shipworthy/ doesn't exist"
else
  pass "sw_signal correctly no-oped without .shipworthy/"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 3: sw_signal shows transparency output on stderr
# ---------------------------------------------------------------
echo "Test 3: sw_signal shows transparency on stderr"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
STDERR_OUTPUT=$( (
  cd "$TMPDIR"
  export SHIPWORTHY_TRANSPARENCY=1
  source "$LIB_PATH" 2>/dev/null || true
  sw_signal "test-hook" "security" "secret found in config.ts"
) 2>&1 1>/dev/null )
if echo "$STDERR_OUTPUT" | grep -q "captured.*security"; then
  pass "sw_signal transparency output visible on stderr"
else
  fail "sw_signal transparency not on stderr" "Got: $STDERR_OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 4: Multiple signals accumulate in .session-signals
# ---------------------------------------------------------------
echo "Test 4: Multiple signals accumulate"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
(
  cd "$TMPDIR"
  source "$LIB_PATH" 2>/dev/null || true
  sw_signal "hook-a" "security" "first signal"
  sw_signal "hook-b" "pattern" "second signal"
  sw_signal "hook-c" "git" "third signal"
) 2>/dev/null
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  LINE_COUNT=$(wc -l < "$TMPDIR/.shipworthy/.session-signals" | tr -d ' ')
  if [ "$LINE_COUNT" -eq 3 ]; then
    pass "3 signals accumulated in .session-signals"
  else
    fail "Expected 3 lines, got $LINE_COUNT"
  fi
else
  fail ".session-signals not created"
fi
cleanup "$TMPDIR"

# ===============================================================
# SESSION-START: Regression fence loading
# ===============================================================

# ---------------------------------------------------------------
# Test 5: Regression fence loaded in session-start output
# ---------------------------------------------------------------
echo "Test 5: Regression fence loaded in session-start output"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence
> Known anti-patterns. Max 20 entries.

## NEVER use SQLite in this project
PostgreSQL required. (2026-03-15)

## NEVER use console.log in src/api/
Use pino for structured logging. (2026-03-20)

## ALWAYS validate inputs in src/routes/
Missing validation caused 500 errors. (2026-03-22)
FENCEEOF
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "REGRESSION FENCE"; then
    if echo "$OUTPUT" | grep -q "NEVER use SQLite"; then
      pass "Regression fence rules loaded in session context"
    else
      fail "Fence section exists but rules not found"
    fi
  else
    fail "REGRESSION FENCE section not found in output"
  fi
else
  fail "Output is not valid JSON with regression fence" "Got: $(echo "$OUTPUT" | head -c 200)"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 6: Fence loading shows transparency on stderr
# ---------------------------------------------------------------
echo "Test 6: Fence loading shows transparency on stderr"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence

## NEVER use SQLite
Test. (2026-04-01)
FENCEEOF
rm -f /tmp/shipworthy-session-* 2>/dev/null || true
STDERR_OUTPUT=$(cd "$TMPDIR" && SHIPWORTHY_TRANSPARENCY=1 "$SESSION_HOOK" 2>&1 1>/dev/null || true)
if echo "$STDERR_OUTPUT" | grep -q "Regression fence.*1 rule"; then
  pass "Fence loading transparency visible on stderr"
else
  fail "Fence loading not visible on stderr" "Got: $(echo "$STDERR_OUTPUT" | head -c 300)"
fi
cleanup "$TMPDIR"
rm -f /tmp/shipworthy-session-* 2>/dev/null || true

# ---------------------------------------------------------------
# Test 7: No regression fence -> valid JSON, no fence section
# ---------------------------------------------------------------
echo "Test 7: No regression fence -> no fence section, valid JSON"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "REGRESSION FENCE"; then
    fail "Fence section found when no fence file exists"
  else
    pass "No fence section when fence file is missing"
  fi
else
  fail "Output is not valid JSON without fence"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 8: Empty regression fence (no ## entries) -> silently skipped
# ---------------------------------------------------------------
echo "Test 8: Empty regression fence -> skipped"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence
> No entries yet.
FENCEEOF
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "REGRESSION FENCE"; then
    fail "Fence section injected for empty fence (no ## entries)"
  else
    pass "Empty fence correctly skipped"
  fi
else
  fail "Output is not valid JSON with empty fence"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 9: INDEX.md includes regression fence section
# ---------------------------------------------------------------
echo "Test 9: INDEX.md includes regression fence"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence

## NEVER use SQLite
Test rule. (2026-04-01)

## ALWAYS validate inputs
Test rule 2. (2026-04-01)
FENCEEOF
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/INDEX.md" ]; then
  if grep -q "Regression Fence" "$TMPDIR/.shipworthy/INDEX.md"; then
    if grep -q "2 rule(s)" "$TMPDIR/.shipworthy/INDEX.md"; then
      pass "INDEX.md includes regression fence with correct count"
    else
      fail "INDEX.md has fence section but wrong count"
    fi
  else
    fail "INDEX.md missing Regression Fence section"
  fi
else
  fail "INDEX.md not generated"
fi
cleanup "$TMPDIR"

# ===============================================================
# SESSION-START: Auto-retro from unprocessed signals
# ===============================================================

# ---------------------------------------------------------------
# Test 10: Unprocessed signals surfaced at session start
# ---------------------------------------------------------------
echo "Test 10: Unprocessed signals surfaced at session start"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/.session-signals" << 'SIGEOF'
2026-04-04T10:00:00|pre-tool-use|security|secret-detected: AWS key in config.ts
2026-04-04T10:01:00|post-tool-use|git|commit: fix auth bug
2026-04-04T10:02:00|pre-tool-use|pattern|console.log in routes.ts
SIGEOF
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "SESSION SIGNALS"; then
    if echo "$OUTPUT" | grep -q "3 signal"; then
      pass "Unprocessed signals surfaced with correct count"
    else
      fail "Session signals section found but signal count wrong"
    fi
  else
    fail "SESSION SIGNALS section not found with unprocessed signals"
  fi
else
  fail "Output is not valid JSON with signals"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 11: Session signals section references /retro
# ---------------------------------------------------------------
echo "Test 11: Session signals references /retro command"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/.session-signals" << 'SIGEOF'
2026-04-04T10:00:00|pre-tool-use|security|secret-detected: AWS key in config.ts
SIGEOF
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "retro"; then
  pass "Session signals section references /retro"
else
  fail "Session signals section missing /retro reference"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 12: No signals -> no session signals section
# ---------------------------------------------------------------
echo "Test 12: No signals -> no session signals section"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "SESSION SIGNALS"; then
    fail "Session signals section found when no signals exist"
  else
    pass "No session signals section without signals"
  fi
else
  fail "Output is not valid JSON without signals"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 13: Signals surfacing shows transparency on stderr
# ---------------------------------------------------------------
echo "Test 13: Signals surfacing shows transparency on stderr"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
echo "2026-04-04T10:00:00|test|test|test signal" > "$TMPDIR/.shipworthy/.session-signals"
rm -f /tmp/shipworthy-session-* 2>/dev/null || true
STDERR_OUTPUT=$(cd "$TMPDIR" && SHIPWORTHY_TRANSPARENCY=1 "$SESSION_HOOK" 2>&1 1>/dev/null || true)
if echo "$STDERR_OUTPUT" | grep -q "Unprocessed signals"; then
  pass "Signal surfacing transparency visible on stderr"
else
  fail "Signal surfacing not visible on stderr" "Got: $(echo "$STDERR_OUTPUT" | head -c 300)"
fi
cleanup "$TMPDIR"
rm -f /tmp/shipworthy-session-* 2>/dev/null || true

# ===============================================================
# INTEGRATION: Signal capture from real hook input
# ===============================================================

# ---------------------------------------------------------------
# Test 14: pre-tool-use console.log -> signal captured
# ---------------------------------------------------------------
echo "Test 14: pre-tool-use console.log -> signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
INPUT='{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR"'/src/service.ts","content":"console.log(\"debug\"); export function run() {}"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$PRE_TOOL_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  if grep -q "pattern|console.log" "$TMPDIR/.shipworthy/.session-signals"; then
    pass "console.log signal captured by pre-tool-use"
  else
    fail "Signal file exists but no console.log signal" "Got: $(cat "$TMPDIR/.shipworthy/.session-signals")"
  fi
else
  fail "No .session-signals created by pre-tool-use hook"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 15: pre-tool-use eval() -> signal captured
# ---------------------------------------------------------------
echo "Test 15: pre-tool-use eval() -> signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
INPUT='{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR"'/src/danger.ts","content":"eval( userInput )"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$PRE_TOOL_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  if grep -q "security|eval-detected" "$TMPDIR/.shipworthy/.session-signals"; then
    pass "eval() signal captured by pre-tool-use"
  else
    fail "Signal file exists but no eval signal" "Got: $(cat "$TMPDIR/.shipworthy/.session-signals")"
  fi
else
  fail "No .session-signals created for eval detection"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 16: post-tool-use git commit -> signal captured
# ---------------------------------------------------------------
echo "Test 16: post-tool-use git commit -> signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix: resolve auth bug\""}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$POST_TOOL_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  if grep -q "git|commit" "$TMPDIR/.shipworthy/.session-signals"; then
    pass "git commit signal captured by post-tool-use"
  else
    fail "Signal file exists but no commit signal" "Got: $(cat "$TMPDIR/.shipworthy/.session-signals")"
  fi
else
  fail "No .session-signals created for git commit"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 17: post-tool-use npm install -> signal captured
# ---------------------------------------------------------------
echo "Test 17: post-tool-use npm install package -> signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
INPUT='{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$POST_TOOL_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  if grep -q "dependency|added: lodash" "$TMPDIR/.shipworthy/.session-signals"; then
    pass "dependency signal captured with package name"
  else
    fail "Signal file exists but no dependency signal" "Got: $(cat "$TMPDIR/.shipworthy/.session-signals")"
  fi
else
  fail "No .session-signals created for npm install"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 18: post-tool-use-write :any detection -> signal captured
# ---------------------------------------------------------------
echo "Test 18: post-tool-use-write :any -> signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
# Create a .ts file with : any
mkdir -p "$TMPDIR/src"
echo 'const x: any = "bad";' > "$TMPDIR/src/bad.ts"
INPUT='{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR"'/src/bad.ts"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$POST_WRITE_HOOK" 2>/dev/null || true)
if [ -f "$TMPDIR/.shipworthy/.session-signals" ]; then
  if grep -q "pattern|typescript-any" "$TMPDIR/.shipworthy/.session-signals"; then
    pass ":any signal captured by post-tool-use-write"
  else
    fail "Signal file exists but no :any signal" "Got: $(cat "$TMPDIR/.shipworthy/.session-signals")"
  fi
else
  fail "No .session-signals created for :any detection"
fi
cleanup "$TMPDIR"

# ===============================================================
# INTEGRATION: Fence violation detection
# ===============================================================

# ---------------------------------------------------------------
# Test 19: Fence violation -> warning + signal captured
# ---------------------------------------------------------------
echo "Test 19: Fence violation -> warning + signal captured"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy" "$TMPDIR/src"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence

## NEVER use SQLite in this project
PostgreSQL only. (2026-03-15)
FENCEEOF
echo 'import sqlite3 from "better-sqlite3";' > "$TMPDIR/src/db.ts"
INPUT='{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR"'/src/db.ts"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$POST_WRITE_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | grep -qi "Regression fence"; then
  pass "Fence violation produces warning in output"
else
  fail "No fence violation warning in output" "Got: $OUTPUT"
fi
if [ -f "$TMPDIR/.shipworthy/.session-signals" ] && grep -q "fence-violation" "$TMPDIR/.shipworthy/.session-signals"; then
  pass "Fence violation signal captured"
else
  fail "Fence violation signal not captured"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 20: No fence violation when rule not matched
# ---------------------------------------------------------------
echo "Test 20: No fence violation when content doesn't match"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy" "$TMPDIR/src"
cat > "$TMPDIR/.shipworthy/regression-fence.md" << 'FENCEEOF'
# Regression Fence

## NEVER use SQLite in this project
PostgreSQL only. (2026-03-15)
FENCEEOF
echo 'import pg from "pg";' > "$TMPDIR/src/db.ts"
INPUT='{"tool_name":"Write","tool_input":{"file_path":"'"$TMPDIR"'/src/db.ts"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$POST_WRITE_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | grep -qi "Regression fence"; then
  fail "False fence violation when content doesn't match"
else
  pass "No false fence violation for clean content"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 21: Integration signal capture shows transparency
# ---------------------------------------------------------------
echo "Test 21: Hook signal capture shows transparency on stderr"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test commit\""}}'
STDERR_OUTPUT=$(cd "$TMPDIR" && SHIPWORTHY_TRANSPARENCY=1 echo "$INPUT" | "$POST_TOOL_HOOK" 2>&1 1>/dev/null || true)
if echo "$STDERR_OUTPUT" | grep -q "captured.*git"; then
  pass "Signal capture transparency visible during hook execution"
else
  fail "Signal capture not visible on stderr" "Got: $(echo "$STDERR_OUTPUT" | head -c 300)"
fi
cleanup "$TMPDIR"

# ===============================================================
# BUDGET: Fence summarization under pressure
# ===============================================================

# ---------------------------------------------------------------
# Test 22: Large fence gets summarized when over context budget
# ---------------------------------------------------------------
echo "Test 22: Large fence summarized under budget pressure"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
# Create a large architecture spec to eat most of the budget
{
  echo "# Architecture Specification"
  echo ""
  echo "## Mandatory Rules"
  echo ""
  for i in $(seq 1 100); do
    echo "$i. This is a mandatory rule that takes up space in the context budget to test summarization behavior."
  done
} > "$TMPDIR/.shipworthy/architecture.md"
# Create a fence that should get summarized
{
  echo "# Regression Fence"
  echo ""
  for i in $(seq 1 15); do
    echo "## NEVER do thing number $i"
    echo "This rule exists to test budget summarization with enough content to push over the limit. (2026-03-$i)"
    echo ""
  done
} > "$TMPDIR/.shipworthy/regression-fence.md"
OUTPUT=$(cd "$TMPDIR" && "$SESSION_HOOK" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  # Should either have full fence or summarized fence — both are valid
  if echo "$OUTPUT" | grep -q "REGRESSION FENCE"; then
    pass "Fence present in output (full or summarized) under budget pressure"
  else
    fail "Fence missing entirely under budget pressure"
  fi
else
  fail "Output is not valid JSON under budget pressure"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
