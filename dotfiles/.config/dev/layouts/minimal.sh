#!/bin/bash
# Minimal layout: Claude | Git > Terminal
# Args: workspace_id project_dir project_name traits_string
set -euo pipefail

WORKSPACE="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"
TRAITS="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Claude is the initial pane (already created with workspace)
# Create right split for terminal
cmux new-split right --workspace "$WORKSPACE"

# If git repo, split the right pane: Git on top, Terminal on bottom
if echo "$TRAITS" | grep -q "git"; then
    # Right pane is focused after split — send git command here
    cmux rpc surface.send_text --text "cd $PROJECT_DIR && $(git_cmd)" --enter true
    # Split down for terminal
    cmux new-split down --workspace "$WORKSPACE"
    cmux rpc surface.send_text --text "cd $PROJECT_DIR" --enter true
else
    cmux rpc surface.send_text --text "cd $PROJECT_DIR" --enter true
fi
