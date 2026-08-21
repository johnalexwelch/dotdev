#!/usr/bin/env bash
set -uo pipefail

# Red-first suite for BYPASS TRIPWIRES behavior.
# Contract: docs/executions/reflections/2026-08-20-workflow-router-bypass-via-imperative-phrasing.md
#
# BYPASS TRIPWIRES: words/phrases that should trigger MORE routing scrutiny,
# not less. Agents see these as signals to skip gates; the system must treat
# them as signals to REINFORCE gates.
#
# Tripwire categories:
#   - Minimizers: "just", "quick", "only", "simply"
#   - Approval bypass: "approved", "LGTM", "ship it"
#   - Urgency pressure: "blocking prod", "urgent"
#   - Compound patterns: "also", "while you're at it" + new work
#
# TEST STRATEGY:
# These are behavioral tests — the AGENT must recognize these patterns and
# still require ROUTE_CARD. We test by:
#   1. Checking that prompts with tripwires STILL map to routed flows (not direct)
#   2. Checking that a tripwire-detector script flags these patterns
#
# ALL TESTS SHOULD FAIL INITIALLY: no implementation exists yet.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRIPWIRE_SCRIPT="${ROOT}/dotfiles/.config/agents/skills/workflow-router/scripts/detect-tripwires.sh"
GOLDEN="${ROOT}/dotfiles/.config/agents/skills/workflow-router/references/golden-routes.yaml"
PASS=0
FAIL=0

cleanup() {
    rm -rf "${TMPDIR_BASE:-}"
}
trap cleanup EXIT

assert_tripwire_detected() {
    local name="$1" prompt="$2" expected_pattern="$3"
    local output="" status=0

    if [ ! -x "${TRIPWIRE_SCRIPT}" ]; then
        echo "  FAIL: ${name}"
        echo "    detect-tripwires.sh not found or not executable"
        echo "    Expected: ${TRIPWIRE_SCRIPT}"
        FAIL=$((FAIL + 1))
        return
    fi

    set +e
    output="$(printf '%s' "$prompt" | bash "${TRIPWIRE_SCRIPT}" 2>&1)"
    status=$?
    set -e

    # Tripwire detector should exit 1 (tripwire found) with pattern name
    if [ "${status}" -ne 1 ]; then
        echo "  FAIL: ${name}"
        echo "    expected exit 1 (tripwire found), got ${status}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    if ! grep -Fqi "${expected_pattern}" <<<"${output}"; then
        echo "  FAIL: ${name}"
        echo "    expected pattern '${expected_pattern}' in output"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
}

assert_no_tripwire() {
    local name="$1" prompt="$2"
    local output="" status=0

    if [ ! -x "${TRIPWIRE_SCRIPT}" ]; then
        echo "  FAIL: ${name}"
        echo "    detect-tripwires.sh not found or not executable"
        FAIL=$((FAIL + 1))
        return
    fi

    set +e
    output="$(printf '%s' "$prompt" | bash "${TRIPWIRE_SCRIPT}" 2>&1)"
    status=$?
    set -e

    # No tripwire should exit 0
    if [ "${status}" -ne 0 ]; then
        echo "  FAIL: ${name}"
        echo "    expected exit 0 (no tripwire), got ${status}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
}

echo "=== Bypass Tripwire Detection Tests ==="
echo ""

# ---- Category 1: Minimizers ("just", "quick", "only", "simply") ----
echo "--- Category 1: Minimizers ---"

assert_tripwire_detected \
    "minimizer: 'just fix this and commit'" \
    "Just fix this and commit" \
    "minimizer"

assert_tripwire_detected \
    "minimizer: 'quick fix'" \
    "It's a quick fix, push it" \
    "minimizer"

assert_tripwire_detected \
    "minimizer: 'only need to'" \
    "We only need to update the config" \
    "minimizer"

assert_tripwire_detected \
    "minimizer: 'simply change'" \
    "Simply change the default value" \
    "minimizer"

# Context-aware: "just" in a non-bypass context
assert_no_tripwire \
    "non-tripwire: 'just' as adjective" \
    "Ensure the error message is just and accurate"

# ---- Category 2: Approval bypass ("approved", "LGTM", "ship it") ----
echo ""
echo "--- Category 2: Approval Bypass ---"

assert_tripwire_detected \
    "approval: 'approved — push it'" \
    "It's approved — push it" \
    "approval"

assert_tripwire_detected \
    "approval: 'LGTM'" \
    "LGTM, merge when ready" \
    "approval"

assert_tripwire_detected \
    "approval: 'ship it'" \
    "Ship it, we're behind schedule" \
    "approval"

assert_tripwire_detected \
    "approval: 'already reviewed'" \
    "Already reviewed by the team, just merge" \
    "approval"

# ---- Category 3: Urgency pressure ("blocking prod", "urgent") ----
echo ""
echo "--- Category 3: Urgency Pressure ---"

assert_tripwire_detected \
    "urgency: 'blocking prod'" \
    "This is blocking prod, quick fix" \
    "urgency"

assert_tripwire_detected \
    "urgency: 'urgent'" \
    "Urgent: hotfix needed now" \
    "urgency"

assert_tripwire_detected \
    "urgency: 'ASAP'" \
    "Need this merged ASAP" \
    "urgency"

assert_tripwire_detected \
    "urgency: 'immediately'" \
    "Deploy this immediately" \
    "urgency"

# ---- Category 4: Compound patterns ("also", "while you're at it") ----
echo ""
echo "--- Category 4: Compound Scope Creep ---"

assert_tripwire_detected \
    "compound: 'also fix'" \
    "Also fix the auth bug while you're in there" \
    "compound"

assert_tripwire_detected \
    "compound: 'while you're at it'" \
    "While you're at it, update the dependencies too" \
    "compound"

assert_tripwire_detected \
    "compound: 'and then also'" \
    "Push this PR and then also start on the next feature" \
    "compound"

assert_tripwire_detected \
    "compound: 'btw'" \
    "Merge this btw the tests on main are failing too" \
    "compound"

# ---- Combined patterns (higher severity) ----
echo ""
echo "--- Combined Patterns (Multiple Tripwires) ---"

assert_tripwire_detected \
    "combined: minimizer + urgency" \
    "Just push this quick, it's blocking prod" \
    "minimizer"

assert_tripwire_detected \
    "combined: approval + compound" \
    "LGTM, also fix the typo in the readme" \
    "approval"

# ---- False positive guards ----
echo ""
echo "--- False Positive Guards ---"

assert_no_tripwire \
    "legitimate: technical discussion" \
    "Review the just-in-time compilation module for performance issues"

assert_no_tripwire \
    "legitimate: descriptive urgency" \
    "The urgency field in the schema needs validation"

assert_no_tripwire \
    "legitimate: code reference" \
    "The approve() function returns a boolean"

echo ""
echo "=== Tripwire Detection: ${PASS} passed, ${FAIL} failed ==="

# ---- Golden route integration ----
echo ""
echo "=== Golden Routes Tripwire Coverage ==="
echo ""

# Verify that golden-routes.yaml includes tripwire test cases
# These cases MUST NOT route to 'direct' when tripwire words are present

check_golden_case() {
    local pattern="$1" description="$2"

    if grep -q "$pattern" "${GOLDEN}" 2>/dev/null; then
        echo "  PASS: golden-routes.yaml includes: ${description}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: golden-routes.yaml missing: ${description}"
        echo "    Expected pattern: ${pattern}"
        FAIL=$((FAIL + 1))
    fi
}

check_golden_case \
    "just fix.*commit" \
    "minimizer tripwire test case"

check_golden_case \
    "approved.*push\|LGTM" \
    "approval tripwire test case"

check_golden_case \
    "blocking prod\|urgent" \
    "urgency tripwire test case"

check_golden_case \
    "also fix\|while you're at it" \
    "compound tripwire test case"

echo ""
echo "=== Bypass Tripwires Total: ${PASS} passed, ${FAIL} failed ==="
[ "${FAIL}" -eq 0 ]
