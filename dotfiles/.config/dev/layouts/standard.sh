#!/bin/bash
# Standard layout: Claude | Git > Logs > Terminal
# Args: workspace_id project_dir project_name traits_string
set -euo pipefail

WORKSPACE="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"
TRAITS="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Claude is the initial pane
# Create right split
cmux new-split right --workspace "$WORKSPACE"

# Right pane: Git (top)
cmux rpc surface.send_text --text "cd $PROJECT_DIR && $(git_cmd)" --enter true

# Split down for Logs
cmux new-split down --workspace "$WORKSPACE"
cmux rpc surface.send_text --text "cd $PROJECT_DIR && $(log_cmd "$PROJECT_DIR" "$PROJECT_NAME")" --enter true

# Split down for Terminal
cmux new-split down --workspace "$WORKSPACE"
cmux rpc surface.send_text --text "cd $PROJECT_DIR" --enter true
