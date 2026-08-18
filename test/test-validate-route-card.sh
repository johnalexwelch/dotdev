#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/dotfiles/.config/agents/skills/workflow-router/scripts/validate-route-card.sh"
PASS=0
FAIL=0

run_case() {
    local name="$1" expected="$2" input="$3" expected_text="${4:-}"
    local output="" status=0

    set +e
    output="$(printf '%s\n' "${input}" | bash "${SCRIPT}" 2>&1)"
    status=$?
    set -e

    if [ "${status}" -ne "${expected}" ]; then
        echo "  FAIL: ${name}"
        echo "    expected status ${expected}, got ${status}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    if [ -n "${expected_text}" ] && ! grep -Fq "${expected_text}" <<<"${output}"; then
        echo "  FAIL: ${name}"
        echo "    expected output to contain: ${expected_text}"
        echo "    output: ${output}"
        FAIL=$((FAIL + 1))
        return
    fi

    echo "  PASS: ${name}"
    PASS=$((PASS + 1))
}

VALID_CARD='ROUTE_CARD:
- Request: fix the flaky login test
- Classification: bug
- Selected flow: workflow-debug
- Confidence: high
- Why this flow: bug report; diagnosis-first rule
- Budget: one-reviewer
- Will mutate/create: worktree, fix commit, PR
- Human gates: route confirmation; PR merge approval
- Expected artifacts: diagnosis note, regression test, PR
- Follow-up audit: skill-system-audit not expected (single-issue run)
- Alternatives considered: workflow-build-one (rejected: bug routing rule)
- Confirmation needed: yes'

echo "=== validate-route-card tests ==="
echo ""

run_case "accepts a complete valid card" 0 \
    "${VALID_CARD}" \
    "ROUTE_CARD valid"

run_case "rejects missing header" 1 \
    "$(grep -v '^ROUTE_CARD:' <<<"${VALID_CARD}")" \
    "missing ROUTE_CARD: header"

run_case "rejects missing field (Human gates)" 1 \
    "$(grep -v '^- Human gates:' <<<"${VALID_CARD}")" \
    "missing field: Human gates"

run_case "rejects empty field (Request)" 1 \
    "$(sed 's/^- Request:.*/- Request:/' <<<"${VALID_CARD}")" \
    "empty field: Request"

run_case "rejects illegal Confidence value" 1 \
    "$(sed 's/^- Confidence:.*/- Confidence: certain/' <<<"${VALID_CARD}")" \
    "invalid Confidence: 'certain'"

run_case "rejects illegal Budget value" 1 \
    "$(sed 's/^- Budget:.*/- Budget: solo/' <<<"${VALID_CARD}")" \
    "invalid Budget: 'solo'"

run_case "accepts every legal Budget value" 0 \
    "$(sed 's/^- Budget:.*/- Budget: multi-lane/' <<<"${VALID_CARD}")"

# BSD sed cannot insert newlines portably; use awk to expand the field into a
# nested list form.
NESTED_CARD="$(awk '
    /^- Will mutate\/create:/ {
        print "- Will mutate/create:"
        print "  - worktree"
        print "  - PR"
        next
    }
    { print }
' <<<"${VALID_CARD}")"

run_case "accepts empty field with nested list values" 0 \
    "${NESTED_CARD}"

run_case "reports multiple problems at once" 1 \
    "$(grep -v -e '^- Human gates:' -e '^- Budget:' <<<"${VALID_CARD}")" \
    "missing field: Budget"

run_case "rejects empty input" 1 \
    "" \
    "missing field: Request"

echo ""
echo "validate-route-card: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
