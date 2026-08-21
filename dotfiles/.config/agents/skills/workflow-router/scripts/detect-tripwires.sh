#!/usr/bin/env bash
# detect-tripwires.sh — Detect bypass tripwire patterns in prompts.
# Reads prompt from stdin.
# Exit 1 + prints category when tripwire found.
# Exit 0 when clean.
#
# Categories:
#   minimizer — "just", "quick", "only", "simply" + action verb
#   approval  — "approved", "LGTM", "ship it", "already reviewed"
#   urgency   — "blocking prod", "urgent", "ASAP", "immediately"
#   compound  — "also fix", "while you're at it", "btw"
set -uo pipefail

prompt="$(cat)"
prompt_lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

# ponytail: order matters — first match wins. Combined patterns handled by
# returning first category detected (not multi-label).

# ---- Minimizers: "just/quick/only/simply" + action verb context ----
# Guard against false positives: "just" as adjective ("just and accurate",
# "just-in-time") should NOT trigger.
detect_minimizer() {
    # "just" followed by action verb (fix, push, merge, commit, update, change, etc.)
    # NOT "just" followed by noun/adjective context
    # UNLESS specific approval phrases exist ("already reviewed" takes precedence)
    if printf '%s' "$prompt_lower" | grep -Eq '\bjust\s+(fix|push|merge|commit|update|change|flip|do|run|deploy|ship|send|add)\b'; then
        if printf '%s' "$prompt_lower" | grep -Eq '\balready\s+reviewed\b'; then
            : # fall through — let approval handle
        else
            return 0
        fi
    fi
    # "quick" + action context
    # UNLESS specific urgency/approval phrases exist (those take precedence)
    if printf '%s' "$prompt_lower" | grep -Eq '\bquick\s*(fix|change|update|push|commit|merge|patch)\b'; then
        # Skip if "blocking prod" or "already reviewed" exist — let urgency/approval handle
        if printf '%s' "$prompt_lower" | grep -Eq '\bblocking\s+prod\b|\balready\s+reviewed\b'; then
            : # fall through
        else
            return 0
        fi
    fi
    if printf '%s' "$prompt_lower" | grep -Eq "\bit's a quick\b|\bit is a quick\b"; then
        return 0
    fi
    # "only need to" / "only have to"
    if printf '%s' "$prompt_lower" | grep -Eq '\bonly\s+(need|have)\s+to\b'; then
        return 0
    fi
    # "simply" + action verb
    if printf '%s' "$prompt_lower" | grep -Eq '\bsimply\s+(change|fix|update|push|merge|commit|add|remove|delete|modify)\b'; then
        return 0
    fi
    return 1
}

# ---- Approval bypass ----
detect_approval() {
    # "approved" in approval context (not the approve() function)
    if printf '%s' "$prompt_lower" | grep -Eq '\bapproved\b' && ! printf '%s' "$prompt_lower" | grep -Eq '\bapprove[d]?\s*\(\)|\bapprove[d]?\s+function\b'; then
        # Exclude "already approved" as part of V1 brief context (legitimate)
        if printf '%s' "$prompt_lower" | grep -Eq 'v1 brief.*approved|approved.*v1 brief'; then
            return 1
        fi
        return 0
    fi
    # LGTM
    if printf '%s' "$prompt_lower" | grep -Eq '\blgtm\b'; then
        return 0
    fi
    # "ship it"
    if printf '%s' "$prompt_lower" | grep -Eq '\bship\s+it\b'; then
        return 0
    fi
    # "already reviewed"
    if printf '%s' "$prompt_lower" | grep -Eq '\balready\s+reviewed\b'; then
        return 0
    fi
    return 1
}

# ---- Urgency pressure ----
detect_urgency() {
    # "blocking prod"
    if printf '%s' "$prompt_lower" | grep -Eq '\bblocking\s+prod\b'; then
        return 0
    fi
    # "urgent" (not "urgency field" — technical reference)
    if printf '%s' "$prompt_lower" | grep -Eq '\burgent\b' && ! printf '%s' "$prompt_lower" | grep -Eq '\burgency\s+field\b'; then
        return 0
    fi
    # "ASAP"
    if printf '%s' "$prompt_lower" | grep -Eq '\basap\b'; then
        return 0
    fi
    # "immediately"
    if printf '%s' "$prompt_lower" | grep -Eq '\bimmediately\b'; then
        return 0
    fi
    return 1
}

# ---- Compound scope creep ----
detect_compound() {
    # "also fix" / "also update" etc.
    if printf '%s' "$prompt_lower" | grep -Eq '\balso\s+(fix|update|change|add|remove|delete|handle|address|check|start)\b'; then
        return 0
    fi
    # "while you're at it"
    if printf '%s' "$prompt_lower" | grep -Eq "\bwhile you're at it\b|\bwhile you are at it\b"; then
        return 0
    fi
    # "and then also"
    if printf '%s' "$prompt_lower" | grep -Eq '\band\s+then\s+also\b'; then
        return 0
    fi
    # "btw" (scope creep signal)
    if printf '%s' "$prompt_lower" | grep -Eq '\bbtw\b'; then
        return 0
    fi
    return 1
}

# ---- Main detection loop ----
# Order: minimizer -> approval -> urgency -> compound
# Minimizer first (most common bypass), but detect_minimizer excludes prompts
# with specific approval/urgency phrases ("already reviewed", "blocking prod").
# Returns first match.

if detect_minimizer; then
    echo "minimizer"
    exit 1
fi

if detect_approval; then
    echo "approval"
    exit 1
fi

if detect_urgency; then
    echo "urgency"
    exit 1
fi

if detect_compound; then
    echo "compound"
    exit 1
fi

# No tripwire found
exit 0
