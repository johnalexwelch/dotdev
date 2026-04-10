#!/bin/bash
# Web UI layout: Claude | Browser | Git > Logs > Terminal
# Args: workspace_id project_dir project_name traits_string
set -euo pipefail

WORKSPACE="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"
TRAITS="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

PORT=$(read_port "$PROJECT_DIR")

# Claude is the initial pane
# Create browser pane to the right
cmux new-pane --type browser --direction right --workspace "$WORKSPACE" --url "http://localhost:$PORT"

# Create terminal pane to the right of browser
cmux new-split right --workspace "$WORKSPACE"

# Right pane: Git (top)
cmux rpc surface.send_text --text "cd $PROJECT_DIR && $(git_cmd)" --enter true

# Split down for Logs
cmux new-split down --workspace "$WORKSPACE"
cmux rpc surface.send_text --text "cd $PROJECT_DIR && $(log_cmd "$PROJECT_DIR" "$PROJECT_NAME")" --enter true

# Split down for Terminal
cmux new-split down --workspace "$WORKSPACE"
cmux rpc surface.send_text --text "cd $PROJECT_DIR" --enter true
