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
