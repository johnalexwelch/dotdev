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

REPO_DIR="${DOJO_NOTES_DIR:-$HOME/notes}" # any dir with your Claude setup
OUT_DIR="$HOME/Documents/daily-briefs"
STAMP="$(date +%Y-%m-%d)"
OUT_FILE="$OUT_DIR/triage-$STAMP.md"
STATUS_FILE="/tmp/streamdeck-agent-status"

mkdir -p "$OUT_DIR"

notify() { osascript -e "display notification \"$1\" with title \"Daily planning\"" >/dev/null 2>&1; }

# --- 1. Start the triage agent in the background --------------------------
# NOTE: no --bare. Bare mode skips skill/plugin discovery, which would make
# /morning-triage unavailable. Slower startup is the price of your skills.
(
	echo "running" >"$STATUS_FILE"
	if cd "$REPO_DIR" 2>/dev/null && command -v claude >/dev/null 2>&1; then
		claude -p "/morning-triage" \
			--permission-mode dontAsk \
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
open -a "Sunsama"
sleep 1.2
osascript -e 'tell application "System Events" to keystroke "p"' >/dev/null 2>&1

notify "Planning view open — digest is running"
