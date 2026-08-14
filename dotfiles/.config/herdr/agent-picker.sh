#!/usr/bin/env bash
# fzf picker for installed integrations -> start agent in current pane's cwd
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

agents=$("$herdr" integration list 2>/dev/null | jq -r '.result.integrations[]? | .id' 2>/dev/null)
[ -n "$agents" ] || {
	echo "No integrations found"
	exit 0
}

selected=$(printf '%s\n' "$agents" | fzf --prompt='agent> ' --height=60% --reverse) || exit 0
[ -n "$selected" ] || exit 0

# Get current pane's cwd
cwd=$("$herdr" pane current 2>/dev/null | jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty' 2>/dev/null)
cwd="${cwd:-$(pwd)}"

"$herdr" workspace create --cwd "$cwd" --focus
# ponytail: workspace create spawns default agent; if specific agent needed,
# would need `herdr pane run` with the integration command
