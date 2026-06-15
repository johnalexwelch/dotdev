#!/usr/bin/env bash
set -euo pipefail

if ! session="$(tmux list-sessions -F '#S' | fzf --prompt='tmux> ')"; then
    exit 0
fi
[[ -n "$session" ]] || exit 0
tmux switch-client -t "$session"
