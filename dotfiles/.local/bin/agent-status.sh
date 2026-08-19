#!/bin/bash
# agent-status.sh
# Prints one word: idle | running | done | failed
# Point a Stateful Executor key at this with a 15s poll and set matchers on
# the output to swap the icon. This is the key that makes a background agent
# visible instead of invisible.
#
# Press-to-clear: run with `--clear` to reset to idle after you've seen it.

set -uo pipefail

# Private per-user $TMPDIR, not world-writable /tmp. Must match the path the
# writer scripts (daily-planning.sh, pr-review-agent.sh) use.
STATUS_FILE="${TMPDIR:-/tmp}/streamdeck-agent-status"

if [[ "${1:-}" == "--clear" ]]; then
    echo "idle" >"$STATUS_FILE"
fi

cat "$STATUS_FILE" 2>/dev/null || echo "idle"
