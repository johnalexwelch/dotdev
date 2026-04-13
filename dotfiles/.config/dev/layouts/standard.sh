#!/bin/bash
# Standard layout: Claude | Git > Logs > Terminal
# Args: workspace_ref project_dir project_name traits_string
set -euo pipefail

WS="$1"
PROJECT_DIR="$2"
PROJECT_NAME="$3"
TRAITS="$4"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Claude is the initial pane
# Create right split — Git
git_surface="$(do_split right "$WS")"
send_cmd "$WS" "$git_surface" "$(safe_cd "$PROJECT_DIR") $(git_cmd)"

# Split down — Logs
logs_surface="$(do_split down "$WS")"
send_cmd "$WS" "$logs_surface" "$(safe_cd "$PROJECT_DIR") $(log_cmd "$PROJECT_DIR" "$PROJECT_NAME")"

# Split down — Terminal
term_surface="$(do_split down "$WS")"
send_cmd "$WS" "$term_surface" "$(safe_cd "$PROJECT_DIR")"
