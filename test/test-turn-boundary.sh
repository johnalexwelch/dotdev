#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for TURN-BOUNDARY ENFORCEMENT after ROUTE_CARD.
# Contract: docs/executions/reflections/2026-08-20-workflow-router-bypass-via-imperative-phrasing.md
#
# TURN-BOUNDARY RULE:
# After emitting ROUTE_CARD, agent MUST:
#   1. End the turn (no more tool calls)
#   2. Include a confirmation question
#   3. Wait for user response before proceeding
#
# User "yes"/"approved"/"continue" is INPUT to routing, not bypass.
#
# TEST STRATEGY:
# Parse agent output/transcript patterns. Validator script detects:
#   - ROUTE_CARD followed by tool invocations in same turn (violation)
#   - ROUTE_CARD without trailing confirmation question (violation)
#   - User approval followed by direct action without routing (violation)
#
# ALL TESTS SHOULD FAIL INITIALLY: validate-turn-boundary.sh doesn't exist yet.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${ROOT}/dotfiles/.config/agents/skills/workflow-router/scripts/validate-turn-boundary.sh"
PASS=0
FAIL=0

# ponytail: no temp files created, cleanup placeholder for future use
cleanup() { :; }
trap cleanup EXIT

# ===========================================================================
# Assertion helpers
# ===========================================================================

assert_violation_detected() {
    local name="$1" transcript="$2" expected_violation="$3"
    local output="" status=0

    if [ ! -x "${VALIDATOR}" ]; then
        echo "  FAIL: ${name}"
        echo "    validate-turn-boundary.sh not found or not executable"
        echo "    Expected: ${VALIDATOR}"
        FAIL=$((FAIL + 1))
        return
    fi

    set +e
    output="$(printf '%s' "$transcript" | bash "${VALIDATOR}" 2>&1)"
    status=$?
    set -e

    # Validator should exit 1 (violation found) with violation type
    if [ "${status}" -ne 1 ]; then
        echo "  FAIL: ${name}"
        echo "    expected exit 1 (violation found), got ${status}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    if ! grep -Fqi "${expected_violation}" <<<"${output}"; then
        echo "  FAIL: ${name}"
        echo "    expected violation '${expected_violation}' in output"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
}

assert_no_violation() {
    local name="$1" transcript="$2"
    local output="" status=0

    if [ ! -x "${VALIDATOR}" ]; then
        echo "  FAIL: ${name}"
        echo "    validate-turn-boundary.sh not found or not executable"
        FAIL=$((FAIL + 1))
        return
    fi

    set +e
    output="$(printf '%s' "$transcript" | bash "${VALIDATOR}" 2>&1)"
    status=$?
    set -e

    # No violation should exit 0
    if [ "${status}" -ne 0 ]; then
        echo "  FAIL: ${name}"
        echo "    expected exit 0 (no violation), got ${status}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
}

# ===========================================================================
# Mock transcripts for testing
# ===========================================================================

# VIOLATION: ROUTE_CARD emitted, then tool call in SAME turn
VIOLATION_SAME_TURN_TOOL='[ASSISTANT]
I will check for existing route cards first.

ROUTE_CARD:
- Request: fix the login bug
- Classification: bug
- Selected flow: workflow-debug
- Confidence: high
- Why this flow: bug report
- Budget: one-reviewer
- Will mutate/create: worktree, PR
- Human gates: route confirmation
- Expected artifacts: fix, test
- Follow-up audit: none
- Alternatives considered: workflow-build-one (rejected)
- Confirmation needed: yes

Shall I proceed?

[TOOL_CALL: read file="src/auth.ts"]
[/ASSISTANT]'

# VIOLATION: ROUTE_CARD without confirmation question
VIOLATION_NO_CONFIRMATION='[ASSISTANT]
ROUTE_CARD:
- Request: add new feature
- Classification: feature
- Selected flow: workflow-build-one
- Confidence: high
- Why this flow: new feature
- Budget: one-reviewer
- Will mutate/create: worktree, PR
- Human gates: route confirmation
- Expected artifacts: feature, test
- Follow-up audit: none
- Alternatives considered: none
- Confirmation needed: yes
[/ASSISTANT]'

# VIOLATION: User says "yes", agent proceeds without re-routing
VIOLATION_APPROVAL_BYPASS='[USER]
yes, proceed
[/USER]
[ASSISTANT]
Great, starting immediately.

[TOOL_CALL: bash command="git checkout -b feature/new-thing"]
[TOOL_CALL: write file="src/new.ts" content="..."]
[/ASSISTANT]'

# VALID: ROUTE_CARD emitted, confirmation asked, turn ends
VALID_ROUTE_CARD='[ASSISTANT]
I will analyze this request first.

ROUTE_CARD:
- Request: fix the login bug
- Classification: bug
- Selected flow: workflow-debug
- Confidence: high
- Why this flow: bug report; diagnosis-first rule
- Budget: one-reviewer
- Will mutate/create: worktree, PR
- Human gates: route confirmation; PR merge approval
- Expected artifacts: diagnosis, fix, test, PR
- Follow-up audit: none
- Alternatives considered: workflow-build-one (rejected: bug routing rule)
- Confirmation needed: yes

Should I proceed with workflow-debug?
[/ASSISTANT]'

# VALID: ROUTE_CARD confirmed, then re-emit or proceed properly
VALID_AFTER_CONFIRMATION='[USER]
yes, proceed
[/USER]
[ASSISTANT]
Confirmed. Loading workflow-debug skill.

[SKILL_LOAD: workflow-debug]

Starting diagnosis phase...
[/ASSISTANT]'

# VALID: No ROUTE_CARD needed (pure question, no mutations)
VALID_NO_ROUTING_NEEDED='[ASSISTANT]
The file contains 3 functions:
- authenticate()
- validateToken()
- refreshSession()

Which one would you like me to examine?
[/ASSISTANT]'

# ===========================================================================
# Test cases
# ===========================================================================

echo "=== Turn-Boundary Enforcement Tests ==="
echo ""
echo "Testing ROUTE_CARD turn-boundary violations..."
echo ""

# Test 1: Same-turn tool call after ROUTE_CARD
assert_violation_detected \
    "detects tool call in same turn as ROUTE_CARD" \
    "${VIOLATION_SAME_TURN_TOOL}" \
    "same-turn-tool-call"

# Test 2: ROUTE_CARD without confirmation question
assert_violation_detected \
    "detects ROUTE_CARD without confirmation question" \
    "${VIOLATION_NO_CONFIRMATION}" \
    "missing-confirmation"

# Test 3: User approval leading to direct action (bypass)
assert_violation_detected \
    "detects approval-to-action bypass (no ROUTE_CARD after yes)" \
    "${VIOLATION_APPROVAL_BYPASS}" \
    "approval-bypass"

echo ""
echo "Testing valid patterns (should NOT trigger violations)..."
echo ""

# Test 4: Proper ROUTE_CARD with confirmation, turn ends
assert_no_violation \
    "accepts ROUTE_CARD with confirmation question and clean turn end" \
    "${VALID_ROUTE_CARD}"

# Test 5: Proper flow after confirmed ROUTE_CARD
assert_no_violation \
    "accepts tool calls after user-confirmed ROUTE_CARD + skill load" \
    "${VALID_AFTER_CONFIRMATION}"

# Test 6: No ROUTE_CARD needed (pure read-only/question)
assert_no_violation \
    "accepts turns without ROUTE_CARD when no mutations" \
    "${VALID_NO_ROUTING_NEEDED}"

# ===========================================================================
# Additional edge cases
# ===========================================================================

echo ""
echo "Testing edge cases..."
echo ""

# Compound violation: ROUTE_CARD + tool + no confirmation
COMPOUND_VIOLATION='[ASSISTANT]
ROUTE_CARD:
- Request: refactor auth
- Classification: improvement
- Selected flow: workflow-build-one
- Confidence: medium
- Why this flow: refactor
- Budget: one-reviewer
- Will mutate/create: PR
- Human gates: route confirmation
- Expected artifacts: refactor
- Follow-up audit: none
- Alternatives considered: none
- Confirmation needed: yes

[TOOL_CALL: read file="src/auth.ts"]
[/ASSISTANT]'

assert_violation_detected \
    "detects compound violation (ROUTE_CARD + tool + no confirmation)" \
    "${COMPOUND_VIOLATION}" \
    "same-turn-tool-call"

# False positive guard: "ROUTE_CARD:" mentioned in discussion (not actual card)
MENTION_NOT_CARD='[ASSISTANT]
When you see ROUTE_CARD: it means the router classified your request.
The format requires 12 fields including Request, Classification, etc.

What would you like to do?
[/ASSISTANT]'

assert_no_violation \
    "does not trigger on ROUTE_CARD mentioned in discussion (not actual card)" \
    "${MENTION_NOT_CARD}"

# Approval words in non-bypass context
APPROVAL_WITH_ROUTE='[USER]
yes, I approve this approach
[/USER]
[ASSISTANT]
Confirmed.

ROUTE_CARD:
- Request: implement caching
- Classification: feature
- Selected flow: workflow-build-one
- Confidence: high
- Why this flow: new feature
- Budget: one-reviewer
- Will mutate/create: worktree, PR
- Human gates: route confirmation
- Expected artifacts: cache impl
- Follow-up audit: none
- Alternatives considered: none
- Confirmation needed: yes

Ready to proceed with workflow-build-one?
[/ASSISTANT]'

assert_no_violation \
    "accepts ROUTE_CARD after user approval (proper flow)" \
    "${APPROVAL_WITH_ROUTE}"

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "=== Turn-Boundary Tests: ${PASS} passed, ${FAIL} failed ==="

if [ "${FAIL}" -gt 0 ]; then
    echo ""
    echo "NOTE: Failures expected in RED state."
    echo "Implementation needed: ${VALIDATOR}"
    echo ""
    echo "Validator spec:"
    echo "  - Input: agent transcript (stdin)"
    echo "  - Exit 0: no violations"
    echo "  - Exit 1: violation found, output violation type"
    echo ""
    echo "Violation types to detect:"
    echo "  - same-turn-tool-call: ROUTE_CARD + TOOL_CALL in same [ASSISTANT] block"
    echo "  - missing-confirmation: ROUTE_CARD without trailing '?' question"
    echo "  - approval-bypass: user 'yes/approved/continue' followed by mutations without ROUTE_CARD"
fi

exit "${FAIL}"
