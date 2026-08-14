#!/usr/bin/env bash
# fzf picker for project directories -> create new workspace
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

# Collect project dirs from common locations
projects=$(find ~/projects ~/dojo ~/Code ~/dotdev -maxdepth 2 -type d -name .git -print0 2>/dev/null |
    xargs -0 -I{} dirname {} | sort -u)
[ -n "$projects" ] || projects=$(zoxide query -l 2>/dev/null | head -30)
[ -n "$projects" ] || {
    echo "No projects found"
    exit 0
}

selected=$(printf '%s\n' "$projects" | fzf --prompt='project> ' --height=60% --reverse) || exit 0
[ -n "$selected" ] && "$herdr" workspace create --cwd "$selected" --focus
