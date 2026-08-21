#!/usr/bin/env bash
# validate-turn-boundary.sh — Turn-boundary enforcement for ROUTE_CARD.
#
# Reads agent transcript from stdin. Detects:
#   - same-turn-tool-call: ROUTE_CARD + tool invocation in same [ASSISTANT] block
#   - missing-confirmation: ROUTE_CARD without trailing `?` confirmation question
#   - approval-bypass: User "yes"/"approved"/"continue" followed by mutations without ROUTE_CARD
#
# Exit: 0 no violation; 1 violation (prints type to stderr)

set -euo pipefail

INPUT="$(cat)"

# ============================================================================
# Helpers
# ============================================================================

# True if the text contains a real ROUTE_CARD (not just a mention).
# Real card: "ROUTE_CARD:" on own line followed by "- Request:" field.
has_route_card() {
    local text="$1"
    printf '%s\n' "$text" | grep -Eq '^[[:space:]]*ROUTE_CARD:[[:space:]]*$' &&
        printf '%s\n' "$text" | grep -Eq '^[[:space:]]*- Request:'
}

# True if the text contains tool invocations.
has_tool_call() {
    local text="$1"
    printf '%s\n' "$text" | grep -Eq '\[TOOL_CALL:|<function_calls>|<invoke'
}

# True if the text ends with a confirmation question (? before block end).
has_confirmation_question() {
    local text="$1"
    # Strip trailing whitespace and check last non-empty line ends with ?
    printf '%s\n' "$text" | grep -v '^[[:space:]]*$' | tail -n 1 | grep -Eq '\?[[:space:]]*$'
}

# True if the text contains approval words.
is_approval() {
    local text="$1"
    printf '%s\n' "$text" | grep -Eiq '\b(yes|approved|approve|continue|proceed)\b'
}

# ============================================================================
# Sequential block processing
# ============================================================================

PREV_WAS_APPROVAL=0
IN_ASSISTANT=0
IN_USER=0
ASSISTANT_BLOCK=""
USER_BLOCK=""

while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" == "[ASSISTANT]" ]]; then
        IN_ASSISTANT=1
        ASSISTANT_BLOCK=""
        continue
    fi

    if [[ "$line" == "[/ASSISTANT]" ]]; then
        IN_ASSISTANT=0

        # Check 1: ROUTE_CARD + tool call in same turn
        if has_route_card "$ASSISTANT_BLOCK" && has_tool_call "$ASSISTANT_BLOCK"; then
            echo "same-turn-tool-call" >&2
            exit 1
        fi

        # Check 2: ROUTE_CARD without confirmation question
        if has_route_card "$ASSISTANT_BLOCK" && ! has_confirmation_question "$ASSISTANT_BLOCK"; then
            echo "missing-confirmation" >&2
            exit 1
        fi

        # Check 3: Approval bypass (user approved but no ROUTE_CARD, has tool calls)
        if [ "$PREV_WAS_APPROVAL" -eq 1 ]; then
            if has_tool_call "$ASSISTANT_BLOCK" && ! has_route_card "$ASSISTANT_BLOCK"; then
                # Exception: skill loads are allowed after approval
                if ! printf '%s\n' "$ASSISTANT_BLOCK" | grep -Eq '\[SKILL_LOAD:'; then
                    echo "approval-bypass" >&2
                    exit 1
                fi
            fi
        fi

        PREV_WAS_APPROVAL=0
        ASSISTANT_BLOCK=""
        continue
    fi

    if [[ "$line" == "[USER]" ]]; then
        IN_USER=1
        USER_BLOCK=""
        continue
    fi

    if [[ "$line" == "[/USER]" ]]; then
        IN_USER=0
        if is_approval "$USER_BLOCK"; then
            PREV_WAS_APPROVAL=1
        else
            PREV_WAS_APPROVAL=0
        fi
        USER_BLOCK=""
        continue
    fi

    if [ "$IN_ASSISTANT" -eq 1 ]; then
        ASSISTANT_BLOCK+="$line"$'\n'
    fi

    if [ "$IN_USER" -eq 1 ]; then
        USER_BLOCK+="$line"$'\n'
    fi
done <<<"$INPUT"

# No violations found
exit 0
