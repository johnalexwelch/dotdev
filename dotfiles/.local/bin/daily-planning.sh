#!/bin/bash
# daily-planning.sh
# The 9am key. Kicks off your morning triage digest in the background, then
# puts you straight into Sunsama's daily planning view so you can plan while
# the agent reads Slack and email. Notifies when the digest is ready.
#
# Order matters: the slow thing starts first.
#
# Requires: Sunsama desktop app, Claude Code CLI on PATH.

set -uo pipefail

# Stream Deck invokes scripts without an interactive shell, so ~/.zshrc (and
# the env.zsh it sources) never runs. Load deck config from untracked
# ~/.streamdeck and pin PATH explicitly.
# shellcheck disable=SC1090
[[ -f "$HOME/.streamdeck" ]] && source "$HOME/.streamdeck"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

REPO_DIR="${DOJO_REPO_DIR:-$HOME/dojo}" # any dir with your Claude setup
OUT_DIR="$HOME/Documents/daily-briefs"
STAMP="$(date +%Y-%m-%d)"
OUT_FILE="$OUT_DIR/triage-$STAMP.md"
# Single status slot shared by all deck agent keys — last writer wins.
# Private per-user $TMPDIR, not world-writable /tmp.
STATUS_FILE="${TMPDIR:-/tmp}/streamdeck-agent-status"

mkdir -p "$OUT_DIR"

# Message passed as argv, never interpolated into AppleScript source —
# calendar/Slack-derived text must stay data, not code.
notify() {
    osascript -e 'on run argv' \
        -e 'display notification (item 1 of argv) with title "Daily planning"' \
        -e 'end run' -- "$1" >/dev/null 2>&1
}

# --- 1. Start the triage agent in the background --------------------------
# NOTE: no --bare. Bare mode skips skill/plugin discovery, which would make
# /morning-triage unavailable. Slower startup is the price of your skills.
# The digest reads attacker-authored text (email, Slack), so the agent runs
# with mutating tools denied: prompt injection can at worst shape the digest,
# never execute code or write files. MCP readers stay available.
(
    echo "running" >"$STATUS_FILE"
    if cd "$REPO_DIR" 2>/dev/null && command -v claude >/dev/null 2>&1; then
        claude -p "/morning-triage" \
            --permission-mode dontAsk \
            --disallowedTools "Bash,Write,Edit,NotebookEdit" \
            --output-format json \
            --max-turns 40 \
            --max-budget-usd 2.00 \
            2>/dev/null |
            /usr/bin/python3 -c 'import sys,json; print(json.load(sys.stdin).get("result",""))' \
                >"$OUT_FILE" 2>/dev/null
        if [[ -s "$OUT_FILE" ]]; then
            echo "done" >"$STATUS_FILE"
            notify "Triage digest ready"
        else
            echo "failed" >"$STATUS_FILE"
            notify "Triage produced no output"
        fi
    else
        echo "failed" >"$STATUS_FILE"
        notify "Could not run claude in $REPO_DIR"
    fi
) >/dev/null 2>&1 &

# --- 2. Put you in Sunsama's daily planning view --------------------------
open -a "Sunsama" || {
    notify "Sunsama not installed"
    exit 1
}
sleep 1.2
# Only send the keystroke if Sunsama actually became frontmost — a blind
# keystroke lands in whatever app has focus.
FRONT="$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)"
if [[ "$FRONT" == "Sunsama" ]]; then
    osascript -e 'tell application "System Events" to keystroke "p"' >/dev/null 2>&1
    notify "Planning view open — digest is running"
else
    notify "Sunsama not frontmost — digest is running, open planning manually"
fi
