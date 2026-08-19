#!/bin/bash
# pr-review-agent.sh
# Reads the PR you're currently looking at in Chrome and runs your review
# skill against it. Read-only by design: it writes a review to a file and
# opens it. It does not post comments, push, or merge.
#
# Requires: Claude Code CLI, gh CLI (authenticated), Chrome.

# Stream Deck invokes scripts without an interactive shell — load deck config
# from untracked ~/.streamdeck and pin PATH explicitly. Sourced before
# `set -u` so an unset reference in the hand-authored file degrades instead
# of aborting.
# shellcheck disable=SC1090
[[ -f "$HOME/.streamdeck" ]] && source "$HOME/.streamdeck"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

set -uo pipefail

# Single status slot shared by all deck agent keys — last writer wins.
# Private per-user $TMPDIR, not world-writable /tmp.
STATUS_FILE="${TMPDIR:-/tmp}/streamdeck-agent-status"
OUT_DIR="$HOME/Documents/pr-reviews"
mkdir -p "$OUT_DIR"

# Message passed as argv, never interpolated into AppleScript source —
# tab-URL-derived text must stay data, not code.
notify() {
    osascript -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title "PR review agent"' \
        -e 'end run' -- "$1" >/dev/null 2>&1
}

# --- 1. What am I looking at? ---------------------------------------------
URL="$(osascript -e 'tell application "Google Chrome" to return URL of active tab of front window' 2>/dev/null)"

# Numeric PR pages only — /pull/new/<branch> and friends must not pass.
case "$URL" in
    https://github.com/*/pull/[0-9]*) ;;
    *)
        notify "Front Chrome tab is not a GitHub PR"
        exit 1
        ;;
esac

SLUG="$(printf '%s' "$URL" | sed -E 's#https://github.com/([^/]+)/([^/]+)/pull/([0-9]+).*#\1-\2-\3#')"
# Belt and braces: a slug that still contains a slash is not a filename.
case "$SLUG" in
    */*)
        notify "Could not parse PR URL"
        exit 1
        ;;
esac
OUT_FILE="$OUT_DIR/$SLUG.md"

# --- 2. Where's the checkout? ---------------------------------------------
# Point this at wherever you keep the repo. If you work across several,
# swap this for a lookup keyed on the repo name in $URL.
REPO_DIR="${DOJO_REPO_DIR:-$HOME/dojo}"
cd "$REPO_DIR" 2>/dev/null || {
    notify "Repo dir not found: $REPO_DIR"
    exit 1
}

# --- 3. Run it ------------------------------------------------------------
echo "running" >"$STATUS_FILE"
notify "Reviewing $SLUG…"

# No --bare: your coding-a2a skills need plugin discovery.
# dontAsk + an explicit allowlist: nothing outside this list can run.
# --strict-mcp-config with no --mcp-config: user-scope MCP servers never
# load — this review needs only gh/git, so fail closed on everything else.
if claude -p "/coding-a2a:workflow-review $URL" \
    --strict-mcp-config \
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
