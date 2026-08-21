#!/usr/bin/env bash
# test-env-validation.sh — Tests for ROUTED_SESSION/ROUTE_CARD_ID validation
#
# Issue: env vars currently bypass routing with ANY value:
#   ROUTED_SESSION=1 git commit -m "bypass"
#   ROUTE_CARD_ID=fake gh pr create
#
# These tests encode the CORRECT behavior (should FAIL until fix is implemented):
# - Env vars must validate against actual stored route evidence
# - Arbitrary values should be rejected

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/dotfiles/.claude/hooks/workflow-guard.sh"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

# Simulate workflow-guard invocation
run_guard() {
    local tool_cmd="$1"
    shift
    local input
    input=$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$tool_cmd" "$TMPDIR_BASE/repo")
    if [ $# -gt 0 ]; then
        env "$@" bash "$SCRIPT" <<<"$input" 2>&1
    else
        bash "$SCRIPT" <<<"$input" 2>&1
    fi
}

# Test helper: assert exit code
assert_status() {
    local name="$1" expected="$2" tool_cmd="$3"
    shift 3

    set +e
    output=$(run_guard "$tool_cmd" "$@")
    actual=$?
    set -e

    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        echo "    expected exit=$expected, got exit=$actual"
        echo "    output: $output"
        FAIL=$((FAIL + 1))
    fi
}

setup_test_repo() {
    rm -rf "$TMPDIR_BASE/repo"
    mkdir -p "$TMPDIR_BASE/repo/.pi"
    git -C "$TMPDIR_BASE/repo" init -q
    touch "$TMPDIR_BASE/repo/file.txt"
    git -C "$TMPDIR_BASE/repo" add .
}

# Create valid route evidence (simulates routing-confirm.sh)
create_valid_route() {
    local route_id="$1"
    cat >"$TMPDIR_BASE/repo/.pi/routing-confirmed" <<EOF
route_id: $route_id
confirmed_at: $(date -Iseconds)
session_pid: $$
EOF
}

echo "=== Env Validation Tests ==="
echo ""
echo "NOTE: These tests should FAIL until proper validation is implemented."
echo "Current workflow-guard accepts ANY value for ROUTED_SESSION/ROUTE_CARD_ID."
echo ""

setup_test_repo

# -----------------------------------------------------------------------------
# Test 1: ROUTED_SESSION=1 without actual route → SHOULD BLOCK (currently passes)
# -----------------------------------------------------------------------------
echo "Test 1: ROUTED_SESSION=1 without stored route evidence"
# ponytail: This test WILL FAIL currently — that's the point (TDD red state)
assert_status "arbitrary ROUTED_SESSION=1 should be rejected" 2 \
    "git commit -m 'test'" \
    ROUTING_ENFORCE=block ROUTED_SESSION=1

# -----------------------------------------------------------------------------
# Test 2: ROUTE_CARD_ID=fake without matching ledger → SHOULD BLOCK
# -----------------------------------------------------------------------------
echo ""
echo "Test 2: ROUTE_CARD_ID=fake without matching ledger entry"
setup_test_repo
assert_status "arbitrary ROUTE_CARD_ID=fake should be rejected" 2 \
    "git commit -m 'test'" \
    ROUTING_ENFORCE=block ROUTE_CARD_ID=fake

# -----------------------------------------------------------------------------
# Test 3: ROUTE_CARD_ID with matching .pi/routing-confirmed → SHOULD ALLOW
# -----------------------------------------------------------------------------
echo ""
echo "Test 3: ROUTE_CARD_ID matching stored route evidence"
setup_test_repo
create_valid_route "valid-route-123"
assert_status "ROUTE_CARD_ID matching routing-confirmed should pass" 0 \
    "git commit -m 'test'" \
    ROUTE_CARD_ID=valid-route-123

# -----------------------------------------------------------------------------
# Test 4: ROUTED_SESSION from routing-confirm.sh output format → SHOULD ALLOW
# -----------------------------------------------------------------------------
echo ""
echo "Test 4: ROUTED_SESSION matching session_pid from routing-confirmed"
setup_test_repo
# Create route evidence with specific session_pid
cat >"$TMPDIR_BASE/repo/.pi/routing-confirmed" <<EOF
route_id: session-route
confirmed_at: $(date -Iseconds)
session_pid: 12345
EOF
assert_status "ROUTED_SESSION matching session_pid should pass" 0 \
    "git commit -m 'test'" \
    ROUTED_SESSION=12345

# -----------------------------------------------------------------------------
# Test 5: Edge case - route_id mismatch
# -----------------------------------------------------------------------------
echo ""
echo "Test 5: ROUTE_CARD_ID not matching stored route_id"
setup_test_repo
create_valid_route "actual-route-abc"
assert_status "ROUTE_CARD_ID not matching stored route_id should reject" 2 \
    "git commit -m 'test'" \
    ROUTING_ENFORCE=block ROUTE_CARD_ID=different-route-xyz

# -----------------------------------------------------------------------------
# Test 6: Valid marker file alone (no env var) → SHOULD ALLOW (existing behavior)
# -----------------------------------------------------------------------------
echo ""
echo "Test 6: Valid marker file without env var (baseline - existing behavior)"
setup_test_repo
create_valid_route "marker-only-route"
assert_status "routing-confirmed file alone should pass" 0 \
    "git commit -m 'test'"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Results: Passed=$PASS Failed=$FAIL"
echo ""
echo "Expected failures in RED state:"
echo "  - Test 1: ROUTED_SESSION=1 without evidence (currently accepts any value)"
echo "  - Test 2: ROUTE_CARD_ID=fake (currently accepts any value)"
echo "  - Test 5: route_id mismatch (no validation against stored route)"
echo "═══════════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
