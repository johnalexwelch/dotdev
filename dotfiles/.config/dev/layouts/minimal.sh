#!/bin/bash
# Minimal layout: Claude | Git > Terminal
# Args: workspace_ref project_dir project_name traits_string
set -euo pipefail

WS="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"
TRAITS="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Claude is the initial pane (already created with workspace)
# Create right split
local_surface="$(do_split right "$WS")"

if echo "$TRAITS" | grep -q "git"; then
    # This surface is Git
    send_cmd "$WS" "$local_surface" "$(safe_cd "$PROJECT_DIR") $(git_cmd)"
    # Split down for terminal
    local_surface="$(do_split down "$WS")"
fi

send_cmd "$WS" "$local_surface" "$(safe_cd "$PROJECT_DIR")"
