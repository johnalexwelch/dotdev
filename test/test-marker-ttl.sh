#!/usr/bin/env bash
# test-marker-ttl.sh — Tests for routing-confirmed marker TTL/session binding
#
# These tests verify that the routing-confirmed marker:
# 1. Expires after 24h TTL
# 2. Is bound to the session that created it
# 3. Requires expires_at field
#
# EXPECTED STATE: RED (failing) — TTL/session binding not yet implemented

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="${ROOT}/dotfiles/.claude/hooks/workflow-guard.sh"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    rm -rf "${TMPDIR_BASE}"
}
trap cleanup EXIT

# Setup test repo with routing marker
setup_repo_with_marker() {
    local repo_dir="${TMPDIR_BASE}/repo-$$-${RANDOM}"
    mkdir -p "${repo_dir}/.pi"
    cd "${repo_dir}"
    git init --quiet
    echo "test" >file.txt
    git add file.txt
    git commit --quiet -m "initial" --no-verify
    echo "${repo_dir}"
}

# Simulate PreToolUse Bash event for gh issue create (mutation)
run_mutation_check() {
    local cwd="$1"
    local input
    input=$(
        cat <<EOF
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "gh issue create --title test"},
  "cwd": "${cwd}"
}
EOF
    )
    echo "$input" | bash "$GUARD" 2>&1
}

# Test helper
assert_blocked() {
    local name="$1"
    local output="$2"
    local status="$3"

    if [[ "$status" -ne 0 ]] && echo "$output" | grep -qi "blocked\|no routing evidence"; then
        echo "  PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${name} (expected block, got exit=${status})"
        FAIL=$((FAIL + 1))
    fi
}

assert_allowed() {
    local name="$1"
    local output="$2"
    local status="$3"

    if [[ "$status" -eq 0 ]]; then
        echo "  PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${name} (expected allow, got exit=${status})"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Marker TTL/Session Binding Tests ==="
echo "Expected: RED state (tests should FAIL until feature implemented)"
echo ""

# -----------------------------------------------------------------------------
# Test 1: Marker older than 24h should be REJECTED
# -----------------------------------------------------------------------------
echo "Test 1: Marker older than 24h should be rejected"
repo=$(setup_repo_with_marker)
cd "$repo"

# Create marker with expired timestamp (25 hours ago)
expired_ts=$(($(date +%s) - 90000)) # 25 hours ago
cat >.pi/routing-confirmed <<EOF
route_id: test-route-001
session_pid: $$
created_at: ${expired_ts}
expires_at: $((expired_ts + 86400))
EOF

status=0
output=$(run_mutation_check "$repo") || status=$?
assert_blocked "expired marker (>24h) rejected" "$output" "$status"

# -----------------------------------------------------------------------------
# Test 2: Marker with different session_pid should be REJECTED
# -----------------------------------------------------------------------------
echo ""
echo "Test 2: Marker with different session_pid should be rejected"
repo=$(setup_repo_with_marker)
cd "$repo"

# Create marker with different session PID
now=$(date +%s)
cat >.pi/routing-confirmed <<EOF
route_id: test-route-002
session_pid: 99999
created_at: ${now}
expires_at: $((now + 86400))
EOF

status=0
output=$(run_mutation_check "$repo") || status=$?
assert_blocked "wrong session_pid rejected" "$output" "$status"

# -----------------------------------------------------------------------------
# Test 3: Valid marker (within TTL + matching session) should be ACCEPTED
# -----------------------------------------------------------------------------
echo ""
echo "Test 3: Valid marker (within TTL + matching session) should be accepted"
repo=$(setup_repo_with_marker)
cd "$repo"

# Create valid marker
now=$(date +%s)
cat >.pi/routing-confirmed <<EOF
route_id: test-route-003
session_pid: $$
created_at: ${now}
expires_at: $((now + 86400))
EOF

status=0
output=$(run_mutation_check "$repo") || status=$?
assert_allowed "valid marker accepted" "$output" "$status"

# -----------------------------------------------------------------------------
# Test 4: Marker missing expires_at field should be REJECTED
# -----------------------------------------------------------------------------
echo ""
echo "Test 4: Marker missing expires_at field should be rejected"
repo=$(setup_repo_with_marker)
cd "$repo"

# Create marker without expires_at (legacy format)
cat >.pi/routing-confirmed <<EOF
route_id: test-route-004
session_pid: $$
EOF

status=0
output=$(run_mutation_check "$repo") || status=$?
assert_blocked "missing expires_at rejected" "$output" "$status"

# -----------------------------------------------------------------------------
# Test 5: Empty marker file should be REJECTED
# -----------------------------------------------------------------------------
echo ""
echo "Test 5: Empty marker file should be rejected"
repo=$(setup_repo_with_marker)
cd "$repo"

# Create empty marker
: >.pi/routing-confirmed

status=0
output=$(run_mutation_check "$repo") || status=$?
assert_blocked "empty marker rejected" "$output" "$status"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
echo ""

if [[ "$FAIL" -gt 0 ]]; then
    echo "RED STATE: ${FAIL} test(s) failing — TTL/session binding not yet implemented"
    echo ""
    echo "To make GREEN:"
    echo "  1. has_routing_evidence() must parse marker YAML"
    echo "  2. Check expires_at > now"
    echo "  3. Check session_pid matches current/parent process"
    echo "  4. Reject markers missing required fields"
    exit 1
fi

echo "GREEN STATE: All tests passing"
exit 0
