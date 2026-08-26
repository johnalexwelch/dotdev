#!/usr/bin/env bash
# routing-eval.sh — D-006 Track B golden routing eval runner.
#
# For each case in workflow-router/references/golden-routes.yaml, invokes
# `claude -p` headless (sonnet by default) prompting it to act as the
# workflow-router classification step, instructs it to output ONLY a
# `Selected flow: <skill-name>` line, and exact-string-compares the extracted
# route against expected_route. Deterministic judge — no LLM grading.
#
# Usage:
#   test/routing-eval.sh                 # full eval (needs `claude` CLI + API auth)
#   test/routing-eval.sh --dry-run       # offline: validate golden-set schema only
#   test/routing-eval.sh --case 7        # run a single case, print raw model output
#   test/routing-eval.sh --model sonnet  # model override (default: sonnet)
#
# Exit codes:
#   0  dry-run schema OK, single case PASS, or full-run pass-rate >= 80%
#   1  schema error, missing dependency, single case FAIL, or pass-rate < 80%

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Env overrides exist for the test suite (fixture golden sets).
GOLDEN="${ROUTING_EVAL_GOLDEN:-${ROOT}/dotfiles/.config/agents/skills/workflow-router/references/golden-routes.yaml}"
SKILL="${ROUTING_EVAL_SKILL:-${ROOT}/dotfiles/.config/agents/skills/workflow-router/SKILL.md}"

MODEL="sonnet"
DRY_RUN=0
ONLY_CASE=""
JUDGE_SELF_TEST=0

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --judge-self-test)
            JUDGE_SELF_TEST=1
            shift
            ;;
        --case)
            [ $# -ge 2 ] || usage
            ONLY_CASE="$2"
            shift 2
            ;;
        --model)
            [ $# -ge 2 ] || usage
            MODEL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage
            ;;
    esac
done

extract_route() {
    # Last "Selected flow:" line, stripped of markdown formatting; first token.
    local raw="$1" line=""
    line="$(printf '%s\n' "${raw}" | grep -E 'Selected flow:' | tail -n 1 || true)"
    printf '%s\n' "${line}" |
        sed -E 's/.*Selected flow:[[:space:]]*//; s/[`*_]//g; s/^[[:space:]]*//' |
        sed -E 's/^([a-z0-9-]+).*/\1/'
}

# Offline self-test for the deterministic judge: canned model-output shapes
# the extractor must survive. Run by test/test-routing-eval.sh.
judge_self_test() {
    local failures=0
    check() {
        local name="$1" raw="$2" want="$3" got=""
        got="$(extract_route "${raw}")"
        if [ "${got}" = "${want}" ]; then
            echo "  PASS: judge ${name}"
        else
            echo "  FAIL: judge ${name} (want '${want}', got '${got}')"
            failures=$((failures + 1))
        fi
    }
    check "plain line" "Selected flow: workflow-debug" "workflow-debug"
    check "backticked route" 'Selected flow: `workflow-review`' "workflow-review"
    check "bolded label and route" "**Selected flow:** **receive-review**" "receive-review"
    check "trailing prose on the line" "Selected flow: workflow-finalize (owner rule)" "workflow-finalize"
    check "multi-line output, answer embedded" $'Reasoning first.\nSelected flow: to-prd\nDone.' "to-prd"
    check "takes the LAST selected-flow line" $'Selected flow: run-backlog\nCorrection:\nSelected flow: execute-prd' "execute-prd"
    check "garbage yields empty (never a false pass)" "no route in this output" ""
    [ "${failures}" -eq 0 ]
}

if [ "${JUDGE_SELF_TEST}" -eq 1 ]; then
    if judge_self_test; then
        echo "judge self-test: OK"
        exit 0
    fi
    echo "judge self-test: FAILED" >&2
    exit 1
fi

[ -f "${GOLDEN}" ] || {
    echo "Blocked: golden set not found at ${GOLDEN}" >&2
    exit 1
}
[ -f "${SKILL}" ] || {
    echo "Blocked: router SKILL.md not found at ${SKILL}" >&2
    exit 1
}

# ---- Parse + schema-validate the golden set (offline, no deps beyond awk) --
# Constrained YAML subset, enforced here so the file cannot silently drift:
#   cases:
#     - prompt: "..."           (double-quoted, no embedded double quotes)
#       expected_route: <name>  (bare token)
#       source: log|synthetic
#       notes: "..."
# Emits one record per case: prompt \x1f expected_route \x1f source \x1f notes
parse_golden() {
    awk '
        function fail(msg) {
            printf "schema error at %s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
            bad = 1
        }
        function flush_case() {
            if (!in_case) return
            if (route == "") fail("case " n " missing expected_route")
            if (src == "") fail("case " n " missing source")
            if (notes == "") fail("case " n " missing notes")
            printf "%s\x1f%s\x1f%s\x1f%s\n", prompt, route, src, notes
        }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        /^cases:$/ { seen_cases = 1; next }
        /^  - prompt: ".*"$/ {
            if (!seen_cases) fail("case list before cases: key")
            flush_case()
            in_case = 1
            n += 1
            prompt = $0
            sub(/^  - prompt: "/, "", prompt)
            sub(/"$/, "", prompt)
            route = ""
            src = ""
            notes = ""
            if (prompt == "") fail("case " n " has empty prompt")
            next
        }
        /^    expected_route: [a-z0-9-]+$/ {
            if (!in_case) { fail("expected_route outside a case"); next }
            if (route != "") { fail("case " n " has duplicate expected_route"); next }
            route = $2
            next
        }
        /^    source: (log|synthetic)$/ {
            if (!in_case) { fail("source outside a case"); next }
            if (src != "") { fail("case " n " has duplicate source"); next }
            src = $2
            next
        }
        /^    notes: ".*"$/ {
            if (!in_case) { fail("notes outside a case"); next }
            if (notes != "") { fail("case " n " has duplicate notes"); next }
            notes = $0
            sub(/^    notes: "/, "", notes)
            sub(/"$/, "", notes)
            next
        }
        { fail("unrecognized line: " $0) }
        END {
            flush_case()
            if (n == 0) fail("no cases found")
            if (bad) exit 1
        }
    ' "${GOLDEN}"
}

PARSED=""
if ! PARSED="$(parse_golden)"; then
    echo "FAIL: golden set schema validation failed" >&2
    exit 1
fi

PROMPTS=()
EXPECTED=()
SOURCES=()
while IFS=$'\x1f' read -r c_prompt c_route c_src _; do
    PROMPTS+=("${c_prompt}")
    EXPECTED+=("${c_route}")
    SOURCES+=("${c_src}")
done <<<"${PARSED}"

TOTAL="${#PROMPTS[@]}"
LOG_COUNT=0
SYN_COUNT=0
for src in "${SOURCES[@]}"; do
    if [ "${src}" = "log" ]; then
        LOG_COUNT=$((LOG_COUNT + 1))
    else
        SYN_COUNT=$((SYN_COUNT + 1))
    fi
done

# Every expected route must exist as a whole token in the router SKILL.md
# (classification-table names; "direct" is the direct-budget route). A
# word-boundary match, not a substring match — catches typo'd hyphenated
# routes ("workflow-reviw"). Residual gap: a wrong route that is also a plain
# English word in the doc ("review") passes this check; the eval itself
# catches those as failures.
ROUTE_ERRORS=0
for route in "${EXPECTED[@]}"; do
    if ! grep -Eq "(^|[^a-z0-9-])${route}([^a-z0-9-]|\$)" "${SKILL}"; then
        echo "schema error: expected_route '${route}' not found in SKILL.md" >&2
        ROUTE_ERRORS=$((ROUTE_ERRORS + 1))
    fi
done
if [ "${ROUTE_ERRORS}" -gt 0 ]; then
    echo "FAIL: ${ROUTE_ERRORS} expected_route value(s) not present in ${SKILL}" >&2
    exit 1
fi

if [ "${DRY_RUN}" -eq 1 ]; then
    echo "dry-run: schema OK — ${TOTAL} cases (${LOG_COUNT} log, ${SYN_COUNT} synthetic); all expected routes present in SKILL.md"
    exit 0
fi

# ---- Full eval (needs claude CLI) ------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
    echo "Blocked: 'claude' CLI not found on PATH; run with --dry-run for offline schema validation" >&2
    exit 1
fi

SKILL_TEXT="$(cat "${SKILL}")"

build_prompt() {
    local request="$1"
    cat <<EOF
You are executing the classification step of the workflow-router skill for a
routing eval. The router's full SKILL.md is between the ROUTER_SKILL tags
below; the request to classify is between the USER_REQUEST tags.

Classify the request using the classification table and the routing rules
(owner-vs-sub-step, bug routing, PRD-vs-backlog, artifact review carve-outs,
prompt generation/evaluation handling).

Do not use any tools. Respond with EXACTLY one line and nothing else:
Selected flow: <skill-name>

<skill-name> must be the exact skill name from the Routes-to column,
lowercase, with no backticks, quotes, or other formatting. When the correct
route is the direct budget with no workflow dispatch, output exactly:
Selected flow: direct

<ROUTER_SKILL>
${SKILL_TEXT}
</ROUTER_SKILL>

<USER_REQUEST>
${request}
</USER_REQUEST>
EOF
}

run_case() {
    # Prints the model's raw output on FD 3 when --case debugging is active.
    local idx="$1" prompt_text="" output="" status=0
    prompt_text="$(build_prompt "${PROMPTS[idx]}")"
    set +e
    output="$(printf '%s\n' "${prompt_text}" | claude -p --model "${MODEL}" --max-turns 1 2>&1)"
    status=$?
    set -e
    if [ -n "${ONLY_CASE}" ]; then
        printf -- '--- raw model output (exit %d) ---\n%s\n---\n' "${status}" "${output}" >&3
    fi
    if [ "${status}" -ne 0 ]; then
        echo "__ERROR__"
        return 0
    fi
    extract_route "${output}"
}

evaluate_one() {
    local idx="$1" n human_n got="" verdict=""
    n=$((idx + 1))
    human_n="${n}/${TOTAL}"
    got="$(run_case "${idx}")"
    if [ "${got}" = "${EXPECTED[idx]}" ]; then
        verdict="PASS"
        printf '[%7s] PASS  %-28s (%s)\n' "${human_n}" "${EXPECTED[idx]}" "${SOURCES[idx]}"
    else
        verdict="FAIL"
        printf '[%7s] FAIL  expected=%s got=%s (%s)\n' "${human_n}" "${EXPECTED[idx]}" "${got:-<empty>}" "${SOURCES[idx]}"
        printf '          prompt: %s\n' "${PROMPTS[idx]}"
    fi
    [ "${verdict}" = "PASS" ]
}

exec 3>&1

if [ -n "${ONLY_CASE}" ]; then
    case "${ONLY_CASE}" in
        '' | *[!0-9]*)
            echo "Blocked: --case takes a 1-based case number" >&2
            exit 1
            ;;
        *) ;;
    esac
    # Force base-10: a leading zero ("09") would otherwise be read as octal
    # and abort the arithmetic below, falling through into the full paid eval.
    ONLY_CASE=$((10#${ONLY_CASE}))
    if [ "${ONLY_CASE}" -lt 1 ] || [ "${ONLY_CASE}" -gt "${TOTAL}" ]; then
        echo "Blocked: --case ${ONLY_CASE} out of range 1..${TOTAL}" >&2
        exit 1
    fi
    idx=$((ONLY_CASE - 1))
    echo "case ${ONLY_CASE}: ${PROMPTS[idx]}"
    if evaluate_one "${idx}"; then
        exit 0
    fi
    exit 1
fi

echo "=== Routing golden eval (model: ${MODEL}, ${TOTAL} cases) ==="
PASS=0
FAIL=0
i=0
while [ "${i}" -lt "${TOTAL}" ]; do
    if evaluate_one "${i}"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    i=$((i + 1))
done

RATE=$((PASS * 100 / TOTAL))
echo ""
echo "total: ${TOTAL}  pass: ${PASS}  fail: ${FAIL}  pass-rate: ${RATE}%"
if [ $((PASS * 100)) -ge $((TOTAL * 80)) ]; then
    echo "RESULT: PASS (>= 80%)"
    exit 0
fi
echo "RESULT: FAIL (< 80%)"
exit 1
