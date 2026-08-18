#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/test/routing-eval.sh"
TMPDIR_BASE="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    rm -rf "${TMPDIR_BASE}"
}
trap cleanup EXIT

run_case() {
    local name="$1" expected="$2" golden="$3" expected_text="${4:-}"
    local output="" status=0

    set +e
    output="$(ROUTING_EVAL_GOLDEN="${golden}" bash "${SCRIPT}" --dry-run 2>&1)"
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

echo "=== routing-eval dry-run tests ==="
echo ""

REAL_GOLDEN="${ROOT}/dotfiles/.config/agents/skills/workflow-router/references/golden-routes.yaml"
run_case "real golden set passes offline schema validation" 0 \
    "${REAL_GOLDEN}" \
    "schema OK"

cat >"${TMPDIR_BASE}/missing-source.yaml" <<'EOF'
cases:
  - prompt: "Review this PR."
    expected_route: workflow-review
    notes: "missing source key"
EOF
run_case "rejects case missing source" 1 \
    "${TMPDIR_BASE}/missing-source.yaml" \
    "missing source"

cat >"${TMPDIR_BASE}/bad-source.yaml" <<'EOF'
cases:
  - prompt: "Review this PR."
    expected_route: workflow-review
    source: guessed
    notes: "illegal source value"
EOF
run_case "rejects illegal source value" 1 \
    "${TMPDIR_BASE}/bad-source.yaml" \
    "unrecognized line"

cat >"${TMPDIR_BASE}/unknown-route.yaml" <<'EOF'
cases:
  - prompt: "Review this PR."
    expected_route: nonexistent-flow-zz
    source: synthetic
    notes: "route not in SKILL.md"
EOF
run_case "rejects expected_route absent from SKILL.md" 1 \
    "${TMPDIR_BASE}/unknown-route.yaml" \
    "not found in SKILL.md"

cat >"${TMPDIR_BASE}/empty.yaml" <<'EOF'
cases:
EOF
run_case "rejects empty case list" 1 \
    "${TMPDIR_BASE}/empty.yaml" \
    "no cases found"

cat >"${TMPDIR_BASE}/stray-line.yaml" <<'EOF'
cases:
  - prompt: "Review this PR."
    expected_route: workflow-review
    source: synthetic
    notes: "ok"
  extra_key: not allowed
EOF
run_case "rejects unrecognized lines" 1 \
    "${TMPDIR_BASE}/stray-line.yaml" \
    "unrecognized line"

echo ""
echo "routing-eval: ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
