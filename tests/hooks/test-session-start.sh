#!/usr/bin/env bash
# Tests for the session-start hook
# Validates JSON output, architecture injection, tech debt, tier detection, JSON escaping

set -euo pipefail

HOOK_PATH="$(cd "$(dirname "$0")/../../hooks" && pwd)/session-start"
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

echo "=== session-start hook tests ==="
echo ""

# ---------------------------------------------------------------
# Test 1: Output is valid JSON
# ---------------------------------------------------------------
echo "Test 1: Output is valid JSON"
TMPDIR=$(setup_temp_project)
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  pass "Output is valid JSON"
else
  fail "Output is not valid JSON" "Got: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 2: With architecture.md present, rules are injected
# ---------------------------------------------------------------
echo "Test 2: Architecture.md present -> rules injected"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/architecture.md" << 'ARCHEOF'
# Architecture Specification

## Mandatory Rules

1. **No any types** -- strict mode required.
2. **Tests required** -- every module must have tests.
ARCHEOF
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "Mandatory Rules"; then
    pass "Architecture rules are injected in output"
  else
    fail "Architecture rules not found in output"
  fi
else
  fail "Output is not valid JSON with architecture.md"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 3: Without architecture.md, shows NOT FOUND message
# ---------------------------------------------------------------
echo "Test 3: No architecture.md -> optional notice"
TMPDIR=$(setup_temp_project)
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "ARCHITECTURE SPECIFICATION"; then
    pass "Architecture notice displayed"
  else
    fail "Architecture notice missing"
  fi
else
  fail "Output is not valid JSON without architecture.md"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 4: With tech-debt.md, debt count surfaced
# ---------------------------------------------------------------
echo "Test 4: tech-debt.md present -> debt count surfaced"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/tech-debt.md" << 'DEBTEOF'
## Item 1: Fix auth token refresh
Needs refactoring.

## Item 2: Remove legacy API v1
Deprecated endpoint still active.

## Item 3: Update dependencies
Several outdated packages.
DEBTEOF
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "3 tech debt item"; then
    pass "Tech debt count (3) surfaced"
  else
    fail "Tech debt count not found or incorrect" "Output: $OUTPUT"
  fi
else
  fail "Output is not valid JSON with tech-debt.md"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 5: JSON escaping - newlines, quotes, backslashes
# ---------------------------------------------------------------
echo "Test 5: JSON escaping handles special characters"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
cat > "$TMPDIR/.shipworthy/architecture.md" << 'SPECEOF'
# Architecture

## Mandatory Rules

1. Use "double quotes" in strings.
2. Escape \ backslashes properly.
3. Handle	tabs and
newlines gracefully.
4. Special chars: <, >, &, $, !, @, #
SPECEOF
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  pass "JSON escaping handles special characters"
else
  fail "JSON escaping broke with special characters" "Output: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 6: Running from subdirectory still finds architecture.md
# ---------------------------------------------------------------
echo "Test 6: Subdirectory execution finds architecture.md"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy"
mkdir -p "$TMPDIR/src/components"
cat > "$TMPDIR/.shipworthy/architecture.md" << 'SUBEOF'
# Architecture

## Mandatory Rules

1. **Rule from root** -- should be found from subdirectory.
SUBEOF
OUTPUT=$(cd "$TMPDIR/src/components" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -q "Mandatory Rules"; then
    pass "Architecture found from subdirectory"
  else
    fail "Architecture not found from subdirectory"
  fi
else
  fail "Output not valid JSON from subdirectory"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 7: Empty/missing SKILL.md -> graceful fallback, valid JSON
# ---------------------------------------------------------------
echo "Test 7: Missing SKILL.md -> graceful fallback"
TMPDIR=$(setup_temp_project)
# The hook reads SKILL.md from the plugin root. We test with a project
# that has no plugin structure - should still produce valid JSON.
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  pass "Graceful fallback with missing SKILL.md"
else
  fail "Invalid JSON on missing SKILL.md" "Output: $OUTPUT"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 8: Tier detection - no package.json = builder
# ---------------------------------------------------------------
echo "Test 8: Tier detection - no package.json = builder"
TMPDIR=$(setup_temp_project)
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi "BUILDER"; then
    pass "No package.json detected as builder tier"
  else
    fail "Expected builder tier for empty project" "Output snippet: $(echo "$OUTPUT" | head -c 300)"
  fi
else
  fail "Output not valid JSON for tier detection"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 9: Tier detection - package.json but no tests = builder
# ---------------------------------------------------------------
echo "Test 9: Tier detection - package.json, no tests = builder"
TMPDIR=$(setup_temp_project)
echo '{"name":"test","version":"1.0.0"}' > "$TMPDIR/package.json"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi "BUILDER"; then
    pass "Package.json without tests detected as builder"
  else
    fail "Expected builder tier for project without tests" "Output snippet: $(echo "$OUTPUT" | head -c 300)"
  fi
else
  fail "Output not valid JSON for builder detection"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 10: Tier detection - package.json + tests = maker
# ---------------------------------------------------------------
echo "Test 10: Tier detection - package.json + tests = maker"
TMPDIR=$(setup_temp_project)
echo '{"name":"test","version":"1.0.0"}' > "$TMPDIR/package.json"
mkdir -p "$TMPDIR/tests"
echo "test('hello', () => {});" > "$TMPDIR/tests/sample.test.js"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi "MAKER"; then
    pass "Package.json with tests (no CI) detected as maker"
  else
    fail "Expected maker tier for project with tests but no CI" "Output snippet: $(echo "$OUTPUT" | head -c 300)"
  fi
else
  fail "Output not valid JSON for maker detection"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 11: Tier detection - package.json + tests + CI = engineer
# ---------------------------------------------------------------
echo "Test 11: Tier detection - package.json + tests + CI = engineer"
TMPDIR=$(setup_temp_project)
echo '{"name":"test","version":"1.0.0"}' > "$TMPDIR/package.json"
mkdir -p "$TMPDIR/tests"
echo "test('hello', () => {});" > "$TMPDIR/tests/sample.test.js"
mkdir -p "$TMPDIR/.github/workflows"
echo "name: CI" > "$TMPDIR/.github/workflows/ci.yml"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi "ENGINEER"; then
    pass "Full project detected as engineer tier"
  else
    fail "Expected engineer tier for project with tests and CI" "Output snippet: $(echo "$OUTPUT" | head -c 300)"
  fi
else
  fail "Output not valid JSON for engineer detection"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 12: Fast diagnosis - no .gitignore detected
# ---------------------------------------------------------------
echo "Test 12: Fast diagnosis - no .gitignore = suggestion detected"
TMPDIR=$(setup_temp_project)
echo '{"name":"test","version":"1.0.0"}' > "$TMPDIR/package.json"
mkdir -p "$TMPDIR/tests"
echo "test('x', () => {});" > "$TMPDIR/tests/a.test.js"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'Status\|suggestion'; then
    pass "Fast diagnosis surfaces project status"
  else
    fail "Expected project status section in output" "Output snippet: $(echo "$OUTPUT" | head -c 400)"
  fi
else
  fail "Output not valid JSON for diagnosis test"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 13: Fast diagnosis - all checks pass for well-configured project
# ---------------------------------------------------------------
echo "Test 13: Fast diagnosis - well-configured project"
TMPDIR=$(setup_temp_project)
echo '{"name":"test","version":"1.0.0"}' > "$TMPDIR/package.json"
mkdir -p "$TMPDIR/tests"
echo "test('x', () => {});" > "$TMPDIR/tests/a.test.js"
mkdir -p "$TMPDIR/.github/workflows"
echo "name: CI" > "$TMPDIR/.github/workflows/ci.yml"
mkdir -p "$TMPDIR/.shipworthy"
echo "# Arch" > "$TMPDIR/.shipworthy/architecture.md"
echo ".env" > "$TMPDIR/.gitignore"
echo '{"extends":["eslint:recommended"]}' > "$TMPDIR/.eslintrc.json"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'looking good'; then
    pass "Well-configured project shows looking good"
  else
    fail "Expected 'looking good' for well-configured project" "Output snippet: $(echo "$OUTPUT" | head -c 400)"
  fi
else
  fail "Output not valid JSON for well-configured project"
fi
cleanup "$TMPDIR"

# ---------------------------------------------------------------
# Test 14: In-progress plans surfaced
# ---------------------------------------------------------------
echo "Test 14: In-progress plans surfaced at session start"
TMPDIR=$(setup_temp_project)
mkdir -p "$TMPDIR/.shipworthy/plans"
echo "# Plan: User Auth" > "$TMPDIR/.shipworthy/plans/user-auth.md"
OUTPUT=$(cd "$TMPDIR" && "$HOOK_PATH" 2>/dev/null || true)
if echo "$OUTPUT" | validate_json; then
  if echo "$OUTPUT" | grep -qi 'IN-PROGRESS PLANS\|user-auth'; then
    pass "In-progress plans surfaced"
  else
    fail "Expected in-progress plans in output" "Output snippet: $(echo "$OUTPUT" | head -c 400)"
  fi
else
  fail "Output not valid JSON with plans"
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
