#!/usr/bin/env bash
# Tests for the post-tool-use hook
# Validates commit monitoring, dependency warnings, and empty command handling

set -euo pipefail

HOOK_PATH="$(cd "$(dirname "$0")/../../hooks" && pwd)/post-tool-use"
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

echo "=== post-tool-use hook tests ==="
echo ""

# ---------------------------------------------------------------
# Test 1: git commit -> quality reminder
# ---------------------------------------------------------------
echo "Test 1: git commit -> quality reminder"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix: resolve auth bug\""}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'commit detected\|tests\|verify'; then
    pass "git commit triggers quality reminder"
  else
    fail "Expected quality reminder for git commit" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 2: git commit --amend -> amend warning
# ---------------------------------------------------------------
echo "Test 2: git commit --amend -> amend warning"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"git commit --amend -m \"updated message\""}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'amend'; then
    pass "git commit --amend triggers amend-specific warning"
  else
    fail "Expected amend-specific warning" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 3: npm install package-name -> new dep advisory
# ---------------------------------------------------------------
echo "Test 3: npm install package-name -> new dep advisory"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"npm install lodash"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'new dependency\|lodash'; then
    pass "npm install <package> triggers new dep advisory"
  else
    fail "Expected new dependency advisory for npm install lodash" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 4: npm ci -> no new dep warning
# ---------------------------------------------------------------
echo "Test 4: npm ci -> no new dep warning"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"npm ci"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'new dependency'; then
    fail "npm ci should not trigger new dependency warning" "Got: $OUTPUT"
  else
    pass "npm ci does not trigger new dep warning"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 5: pip install -r requirements.txt -> no new dep warning
# ---------------------------------------------------------------
echo "Test 5: pip install -r requirements.txt -> no new dep warning"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"pip install -r requirements.txt"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'new dependency'; then
    fail "pip install -r should not trigger new dep warning" "Got: $OUTPUT"
  else
    pass "pip install -r requirements.txt does not trigger new dep warning"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 6: pip install newpackage -> new dep advisory
# ---------------------------------------------------------------
echo "Test 6: pip install newpackage -> new dep advisory"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"pip install requests"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'new dependency\|requests'; then
    pass "pip install <package> triggers new dep advisory"
  else
    fail "Expected new dependency advisory for pip install requests" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 7: Random bash command -> no output (valid empty JSON)
# ---------------------------------------------------------------
echo "Test 7: Random bash command -> valid empty JSON"
TMPDIR=$(setup_temp_project)
INPUT='{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'message'; then
    fail "Random command should not produce a message" "Got: $OUTPUT"
  else
    pass "Random command produces valid empty JSON"
  fi
else
  fail "Output is not valid JSON for random command" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 8: Empty command -> no output
# ---------------------------------------------------------------
echo "Test 8: Empty command -> valid empty JSON"
TMPDIR=$(setup_temp_project)
OUTPUT=$(cd "$TMPDIR" && echo "" | "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'message'; then
    fail "Empty command should not produce a message" "Got: $OUTPUT"
  else
    pass "Empty command produces valid empty JSON"
  fi
else
  fail "Output is not valid JSON for empty command" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ===============================================================
# Tests for post-tool-use-write (Write/Edit compliance)
# ===============================================================
WRITE_HOOK_PATH="$(cd "$(dirname "$0")/../../hooks" && pwd)/post-tool-use-write"

echo ""
echo "--- post-tool-use-write tests ---"
echo ""

# ---------------------------------------------------------------
# Test 9: TypeScript file with `: any` -> advisory
# ---------------------------------------------------------------
echo "Test 9: TypeScript file with : any -> suggestion"
TMPDIR=$(setup_temp_project)
TSFILE="$TMPDIR/src/service.ts"
mkdir -p "$TMPDIR/src"
echo 'export function fetch(data: any) { return data; }' > "$TSFILE"
INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TSFILE\"}}"
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$WRITE_HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'any\|unknown'; then
    pass "TypeScript : any triggers suggestion"
  else
    fail "Expected : any suggestion" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 10: Route handler without validation import -> advisory
# ---------------------------------------------------------------
echo "Test 10: Route without validation -> suggestion"
TMPDIR=$(setup_temp_project)
ROUTEFILE="$TMPDIR/src/routes.ts"
mkdir -p "$TMPDIR/src"
echo 'app.post("/users", (req, res) => { res.json({}); });' > "$ROUTEFILE"
INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$ROUTEFILE\"}}"
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$WRITE_HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'validation'; then
    pass "Route without validation triggers suggestion"
  else
    fail "Expected validation suggestion" "Got: $OUTPUT"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 11: Normal file write -> no advisory
# ---------------------------------------------------------------
echo "Test 11: Normal file write -> no suggestion"
TMPDIR=$(setup_temp_project)
NORMALFILE="$TMPDIR/src/utils.ts"
mkdir -p "$TMPDIR/src"
echo 'export const add = (a: number, b: number): number => a + b;' > "$NORMALFILE"
INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$NORMALFILE\"}}"
OUTPUT=$(cd "$TMPDIR" && echo "$INPUT" | "$WRITE_HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'Suggestion'; then
    fail "Normal write should not trigger suggestion" "Got: $OUTPUT"
  else
    pass "Normal file write produces no suggestion"
  fi
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Summary
# ---------------------------------------------------------------
echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
TOTAL=$((PASSED + FAILED))
echo "Total:  $TOTAL"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo "SOME TESTS FAILED"
  exit 1
else
  echo "ALL TESTS PASSED"
  exit 0
fi
