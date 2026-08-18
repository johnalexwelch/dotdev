#!/usr/bin/env bash
# validate-route-card.sh — D-006 Track B ROUTE_CARD schema validator.
#
# Reads a route card from stdin and asserts the shape defined in
# workflow-router/SKILL.md § Route Card:
#   - a `ROUTE_CARD:` header line
#   - all 12 required `- <Field>:` lines
#   - every field non-empty (an empty field line is allowed only when an
#     indented list of values follows it)
#   - Confidence in {high, medium, low}
#   - Budget in {direct, one-reviewer, multi-lane, team}
#
# Usage: validate-route-card.sh < route-card.md
# Exit:  0 valid; 1 invalid (lists every missing/invalid field on stderr)

set -euo pipefail

REQUIRED_FIELDS=(
    "Request"
    "Classification"
    "Selected flow"
    "Confidence"
    "Why this flow"
    "Budget"
    "Will mutate/create"
    "Human gates"
    "Expected artifacts"
    "Follow-up audit"
    "Alternatives considered"
    "Confirmation needed"
)

INPUT="$(cat)"
ERRORS=()

if ! grep -Eq '^[[:space:]]*ROUTE_CARD:[[:space:]]*$' <<<"${INPUT}"; then
    ERRORS+=("missing ROUTE_CARD: header line")
fi

# Returns the value portion of a `- <Field>:` line, or fails when the field
# line is absent. Trims surrounding whitespace.
field_value() {
    local field="$1" line=""
    line="$(grep -E "^[[:space:]]*- ${field}:" <<<"${INPUT}" | head -n 1 || true)"
    if [ -z "${line}" ]; then
        return 1
    fi
    # `@` delimiters: field names may contain `/` (Will mutate/create).
    printf '%s\n' "${line}" |
        sed -E "s@^[[:space:]]*- ${field}:[[:space:]]*@@; s@[[:space:]]+\$@@"
}

# True when the field line is immediately followed by an indented list item
# (multi-value fields may carry their values as nested bullets).
has_nested_values() {
    local field="$1"
    grep -A 1 -E "^[[:space:]]*- ${field}:[[:space:]]*$" <<<"${INPUT}" |
        tail -n 1 |
        grep -Eq '^[[:space:]]{2,}- .+'
}

for field in "${REQUIRED_FIELDS[@]}"; do
    value=""
    if ! value="$(field_value "${field}")"; then
        ERRORS+=("missing field: ${field}")
        continue
    fi
    if [ -z "${value}" ] && ! has_nested_values "${field}"; then
        ERRORS+=("empty field: ${field}")
    fi
done

CONFIDENCE=""
if CONFIDENCE="$(field_value "Confidence")" && [ -n "${CONFIDENCE}" ]; then
    case "${CONFIDENCE}" in
        high | medium | low) ;;
        *)
            ERRORS+=("invalid Confidence: '${CONFIDENCE}' (legal: high|medium|low)")
            ;;
    esac
fi

BUDGET=""
if BUDGET="$(field_value "Budget")" && [ -n "${BUDGET}" ]; then
    case "${BUDGET}" in
        direct | one-reviewer | multi-lane | team) ;;
        *)
            ERRORS+=("invalid Budget: '${BUDGET}' (legal: direct|one-reviewer|multi-lane|team)")
            ;;
    esac
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
    echo "ROUTE_CARD invalid (${#ERRORS[@]} problem(s)):" >&2
    for err in "${ERRORS[@]}"; do
        echo "  - ${err}" >&2
    done
    exit 1
fi

echo "ROUTE_CARD valid (${#REQUIRED_FIELDS[@]}/${#REQUIRED_FIELDS[@]} required fields present)"
