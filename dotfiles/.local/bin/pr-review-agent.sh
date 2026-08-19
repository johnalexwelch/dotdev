#!/bin/bash
# pr-review-agent.sh
# Reads the PR you're currently looking at in Chrome and runs your review
# skill against it. Read-only by design: it writes a review to a file and
# opens it. It does not post comments, push, or merge.
#
# Requires: Claude Code CLI, gh CLI (authenticated), Chrome.

set -uo pipefail

STATUS_FILE="/tmp/streamdeck-agent-status"
OUT_DIR="$HOME/Documents/pr-reviews"
mkdir -p "$OUT_DIR"

notify() { osascript -e "display notification \"$1\" with title \"PR review agent\"" >/dev/null 2>&1; }

# --- 1. What am I looking at? ---------------------------------------------
URL="$(osascript -e 'tell application "Google Chrome" to return URL of active tab of front window' 2>/dev/null)"

case "$URL" in
    https://github.com/*/pull/*) ;;
    *)
        notify "Front Chrome tab is not a GitHub PR"
        exit 1
        ;;
esac

SLUG="$(printf '%s' "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1-\2-\3#')"
OUT_FILE="$OUT_DIR/$SLUG.md"

# --- 2. Where's the checkout? ---------------------------------------------
# Point this at wherever you keep the repo. If you work across several,
# swap this for a lookup keyed on the repo name in $URL.
REPO_DIR="${DOJO_REPO_DIR:-$HOME/code}"
cd "$REPO_DIR" 2>/dev/null || {
    notify "Repo dir not found: $REPO_DIR"
    exit 1
}

# --- 3. Run it ------------------------------------------------------------
echo "running" >"$STATUS_FILE"
notify "Reviewing $SLUG…"

# No --bare: your coding-a2a skills need plugin discovery.
# dontAsk + an explicit allowlist: nothing outside this list can run.
if claude -p "/coding-a2a:workflow-review $URL" \
    --permission-mode dontAsk \
    --allowedTools "Read,Grep,Glob,Bash(gh pr view *),Bash(gh pr diff *),Bash(gh pr checks *),Bash(git diff *),Bash(git log *)" \
    --output-format json \
    --max-turns 40 \
    --max-budget-usd 3.00 \
    2>/dev/null |
    /usr/bin/python3 -c 'import sys,json; print(json.load(sys.stdin).get("result",""))' \
        >"$OUT_FILE" 2>/dev/null && [[ -s "$OUT_FILE" ]]; then
    echo "done" >"$STATUS_FILE"
    notify "Review ready — opening"
    open "$OUT_FILE"
else
    echo "failed" >"$STATUS_FILE"
    notify "Review failed — see $OUT_FILE"
fi
