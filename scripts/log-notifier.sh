#!/bin/bash
# Pipe log output through this to get cmux notifications on errors.
# Usage: docker compose logs -f 2>&1 | log-notifier.sh [project-name]
#
# Passes all input through to stdout unchanged.

PROJECT="${1:-logs}"

# Error patterns (extended regex)
PATTERNS='(Traceback \(most recent call last\)|(ERROR|FATAL|CRITICAL)\b|exited with code [^0]|UnhandledPromiseRejection|ECONNREFUSED)'

while IFS= read -r line; do
    echo "$line"
    if echo "$line" | grep -qE "$PATTERNS"; then
        cmux notify \
            --title "$PROJECT" \
            --body "$(echo "$line" | head -c 200)" 2>/dev/null || true
    fi
done
