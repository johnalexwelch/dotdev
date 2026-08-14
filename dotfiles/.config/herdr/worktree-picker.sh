#!/usr/bin/env bash
# fzf picker for existing worktrees -> open in herdr workspace
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

worktrees=$("$herdr" worktree list 2>/dev/null | jq -r '.result.worktrees[]? | "\(.path)\t\(.branch // "detached")"' 2>/dev/null)
[ -n "$worktrees" ] || {
	echo "No worktrees found"
	exit 0
}

selected=$(printf '%s\n' "$worktrees" | fzf --prompt='worktree> ' --height=60% --reverse --with-nth=1 --delimiter=$'\t') || exit 0
path=$(printf '%s' "$selected" | cut -f1)
[ -n "$path" ] && "$herdr" worktree open "$path" --focus
