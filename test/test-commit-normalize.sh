#!/bin/bash
# test-commit-normalize.sh — Tests for commit-normalize.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NORMALIZE="$SCRIPT_DIR/../dotfiles/config/git/commit-normalize.sh"
TMPDIR_BASE=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
  rm -rf "$TMPDIR_BASE"
}
trap cleanup EXIT

# Run a single test case
# Usage: run_test "test name" "input message" "expected first line"
run_test() {
  local name="$1"
  local input="$2"
  local expected="$3"

  local tmpfile="$TMPDIR_BASE/msg_$$_$PASS$FAIL"
  printf '%s\n' "$input" > "$tmpfile"

  local stderr_file="$TMPDIR_BASE/stderr_$$_$PASS$FAIL"
  "$NORMALIZE" "$tmpfile" 2>"$stderr_file" || true

  local actual
  actual=$(head -1 "$tmpfile")

  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    input:    $input"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Run a test that checks stderr contains a warning
run_test_warning() {
  local name="$1"
  local input="$2"
  local expected_pattern="$3"

  local tmpfile="$TMPDIR_BASE/msg_warn_$$_$PASS$FAIL"
  printf '%s\n' "$input" > "$tmpfile"

  local stderr_file="$TMPDIR_BASE/stderr_warn_$$_$PASS$FAIL"
  "$NORMALIZE" "$tmpfile" 2>"$stderr_file" || true

  if grep -q "$expected_pattern" "$stderr_file"; then
    echo "  PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $name"
    echo "    expected stderr to contain: $expected_pattern"
    echo "    actual stderr: $(cat "$stderr_file")"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Commit Message Normalizer Tests ==="
echo ""

# --- Pass-through tests ---
echo "-- Pass-through (already valid) --"

run_test "valid conventional: feat" \
  "feat: add user authentication" \
  "feat: add user authentication"

run_test "valid conventional: fix with scope" \
  "fix(api): resolve null pointer in handler" \
  "fix(api): resolve null pointer in handler"

run_test "valid conventional: breaking change" \
  "feat!: remove deprecated endpoints" \
  "feat!: remove deprecated endpoints"

run_test "valid conventional: chore" \
  "chore: bump dependencies" \
  "chore: bump dependencies"

run_test "merge commit pass-through" \
  "Merge branch 'feature/foo' into main" \
  "Merge branch 'feature/foo' into main"

run_test "fixup commit pass-through" \
  "fixup! feat: add user auth" \
  "fixup! feat: add user auth"

run_test "squash commit pass-through" \
  "squash! fix(api): patch handler" \
  "squash! fix(api): patch handler"

run_test "revert commit pass-through" \
  "Revert \"feat: add user auth\"" \
  "Revert \"feat: add user auth\""

echo ""

# --- Emoji mapping tests ---
echo "-- Emoji to conventional type --"

run_test "sparkles -> feat" \
  $'\xe2\x9c\xa8 Add user authentication' \
  "feat: Add user authentication"

run_test "bug -> fix" \
  $'\xf0\x9f\x90\x9b Fix null pointer in handler' \
  "fix: Fix null pointer in handler"

run_test "memo -> docs" \
  $'\xf0\x9f\x93\x9d Update README with examples' \
  "docs: Update README with examples"

run_test "wrench -> chore" \
  $'\xf0\x9f\x94\xa7 Configure CI pipeline' \
  "chore: Configure CI pipeline"

run_test "recycle -> refactor" \
  $'\xe2\x99\xbb Extract validation logic' \
  "refactor: Extract validation logic"

run_test "zap -> perf" \
  $'\xe2\x9a\xa1 Optimize database queries' \
  "perf: Optimize database queries"

run_test "robot -> feat" \
  $'\xf0\x9f\xa4\x96 Create expense-analyzer agent' \
  "feat: Create expense-analyzer agent"

run_test "test_tube -> test" \
  $'\xf0\x9f\xa7\xaa Add integration tests' \
  "test: Add integration tests"

run_test "rocket -> perf" \
  $'\xf0\x9f\x9a\x80 Improve startup time' \
  "perf: Improve startup time"

run_test "lock -> fix" \
  $'\xf0\x9f\x94\x92 Fix authentication bypass' \
  "fix: Fix authentication bypass"

run_test "fire -> chore" \
  $'\xf0\x9f\x94\xa5 Remove deprecated code' \
  "chore: Remove deprecated code"

run_test "tada -> feat" \
  $'\xf0\x9f\x8e\x89 Initial release' \
  "feat: Initial release"

run_test "package -> chore" \
  $'\xf0\x9f\x93\xa6 Update dependencies' \
  "chore: Update dependencies"

run_test "art -> refactor" \
  $'\xf0\x9f\x8e\xa8 Improve code formatting' \
  "refactor: Improve code formatting"

echo ""

# --- Hybrid format tests ---
echo "-- Hybrid emoji + conventional --"

run_test "emoji + conventional passes through stripped" \
  $'\xe2\x9c\xa8 feat(api): add new endpoint' \
  "feat(api): add new endpoint"

run_test "emoji + conventional fix" \
  $'\xf0\x9f\x90\x9b fix: resolve crash on startup' \
  "fix: resolve crash on startup"

run_test "emoji + conventional with scope" \
  $'\xf0\x9f\x94\xa7 chore(deps): bump lodash' \
  "chore(deps): bump lodash"

echo ""

# --- Verb inference tests ---
echo "-- Verb to type inference --"

run_test "Add -> feat" \
  "Add user authentication" \
  "feat: Add user authentication"

run_test "Fix -> fix" \
  "Fix null pointer in handler" \
  "fix: Fix null pointer in handler"

run_test "Update -> feat" \
  "Update README with new examples" \
  "feat: Update README with new examples"

run_test "Remove -> chore" \
  "Remove deprecated endpoints" \
  "chore: Remove deprecated endpoints"

run_test "Refactor -> refactor" \
  "Refactor validation logic into module" \
  "refactor: Refactor validation logic into module"

run_test "Configure -> chore" \
  "Configure eslint for project" \
  "chore: Configure eslint for project"

run_test "Optimize -> perf" \
  "Optimize database query performance" \
  "perf: Optimize database query performance"

run_test "Document -> docs" \
  "Document API usage patterns" \
  "docs: Document API usage patterns"

run_test "Create -> feat" \
  "Create user profile page" \
  "feat: Create user profile page"

echo ""

# --- Length validation tests ---
echo "-- Length validation --"

run_test_warning "warns on long subject" \
  "feat: this is a very long commit message that definitely exceeds the seventy two character limit for subject lines" \
  "Warning: subject line is"

run_test_warning "warns on long normalized subject" \
  "Add a very long feature description that definitely exceeds the seventy two character limit for commit messages" \
  "Warning: subject line is"

echo ""

# --- Edge cases ---
echo "-- Edge cases --"

run_test "empty message (no crash)" \
  "" \
  ""

run_test "comment-only message" \
  "# This is a comment" \
  "# This is a comment"

run_test "unrecognized verb left as-is" \
  "Yolo some random change" \
  "Yolo some random change"

run_test "message with body preserved" \
  "feat: add auth
This adds OAuth2 authentication" \
  "feat: add auth"

run_test "amend commit pass-through" \
  "amend! fix: typo in handler" \
  "amend! fix: typo in handler"

echo ""

# --- Summary ---
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  exit 1
fi
