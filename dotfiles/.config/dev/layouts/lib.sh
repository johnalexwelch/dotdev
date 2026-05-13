#!/bin/bash
# Shared helpers for layout profile scripts.
# Source this, don't execute it.

DOTFILES="$HOME/dotdev"

# Pick the best git UI available
git_cmd() {
    if command -v lazygit &>/dev/null; then
        echo "lazygit"
    else
        echo "watch -n 5 git status -sb"
    fi
}

# Build the log command based on traits
log_cmd() {
    local project_dir="$1"
    local project_name="$2"
    if [[ -f "$project_dir/docker-compose.yml" || -f "$project_dir/docker-compose.yaml" ]]; then
        echo "docker compose logs -f 2>&1 | $DOTFILES/scripts/log-notifier.sh $project_name"
    else
        echo "echo 'No log source detected. Use this pane for log tailing.'"
    fi
}

# Split and return the new surface ref
# Usage: surface=$(do_split right "$workspace")
do_split() {
    local direction="$1"
    local ws="$2"
    local output
    output="$(cmux new-split "$direction" --workspace "$ws" 2>&1)"
    echo "$output" | awk '{print $2}'
}

# Send a command to a specific surface (appends \n for Enter)
send_cmd() {
    local ws="$1"
    local surface="$2"
    local cmd="$3"
    cmux send --workspace "$ws" --surface "$surface" "$cmd\n"
}

# cd using builtin to avoid zoxide alias; chpwd guard in _dev_auto_launch handles re-entry
safe_cd() {
    local dir="$1"
    echo "builtin cd -- $dir 2>/dev/null;"
}

# Read port from .project-type (default 3000)
read_port() {
    local project_dir="$1"
    if [[ -f "$project_dir/.project-type" ]]; then
        local port
        port=$(grep -E '^port=' "$project_dir/.project-type" | head -1 | cut -d= -f2 | xargs)
        [[ -n "$port" ]] && echo "$port" && return
    fi
    echo "3000"
}
