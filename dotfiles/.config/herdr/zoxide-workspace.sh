#!/usr/bin/env bash
# Steal of den-tanui/herdr-zoxide: fzf a zoxide dir -> open as a herdr workspace.
set -euo pipefail
dir=$(zoxide query -l | fzf --prompt='workspace> ' --height=60% --reverse) || exit 0
[ -n "$dir" ] && "${HERDR_BIN_PATH:-herdr}" workspace create --cwd "$dir" --focus
