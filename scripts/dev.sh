#!/bin/bash
set -euo pipefail

# dev — project-type-aware cmux workspace manager
# Usage:
#   dev up [dir]      Create workspace for project
#   dev down          Teardown current project workspace
#   dev status        List active workspaces
#   dev [dir]         Reconnect or create workspace

DOTFILES="$HOME/dotdev"
LAYOUTS_DIR="$HOME/.config/dev/layouts"
SESSIONS_DIR="$HOME/.dev-sessions"

# --- Helpers ---

detect_traits() {
  bash "$DOTFILES/scripts/detect-project.sh" "$1"
}

traits_to_profile() {
  local traits="$1"
  if echo "$traits" | grep -q "web"; then
    echo "web-ui"
  elif echo "$traits" | grep -qE "^(python|node|go|rust|dbt)$"; then
    echo "standard"
  else
    echo "minimal"
  fi
}

workspace_name() {
  local dir="$1"
  local name
  name="$(basename "$dir")"
  # Handle collisions: if another workspace has this name for a different dir,
  # append parent dir name
  if cmux rpc workspace.list 2>/dev/null | grep -q "\"$name\""; then
    local existing_cwd
    existing_cwd="$(cmux rpc workspace.list 2>/dev/null | grep -A1 "\"$name\"" | grep cwd | head -1)"
    if [[ -n "$existing_cwd" ]] && ! echo "$existing_cwd" | grep -q "$dir"; then
      name="${name}-$(basename "$(dirname "$dir")")"
    fi
  fi
  echo "$name"
}

activate_env() {
  local project_dir="$1"
  local traits="$2"

  # Python: sync deps and activate venv
  if echo "$traits" | grep -q "python"; then
    if [[ -f "$project_dir/pyproject.toml" ]] && command -v uv &>/dev/null; then
      echo "  [dev] Syncing Python environment..."
      (cd "$project_dir" && uv sync 2>&1 | sed 's/^/  [uv] /')
    fi
  fi

  # Node: ensure correct version and deps
  if echo "$traits" | grep -q "node"; then
    if command -v fnm &>/dev/null && [[ -f "$project_dir/.node-version" || -f "$project_dir/.nvmrc" ]]; then
      echo "  [dev] Switching Node version..."
      (cd "$project_dir" && fnm use 2>&1 | sed 's/^/  [fnm] /')
    fi
  fi
}

start_services() {
  local project_dir="$1"
  local traits="$2"

  if echo "$traits" | grep -q "docker"; then
    if [[ -f "$project_dir/docker-compose.yml" || -f "$project_dir/docker-compose.yaml" ]]; then
      echo "  [dev] Starting Docker services..."
      (cd "$project_dir" && docker compose up -d 2>&1 | sed 's/^/  [docker] /')
    fi
  fi
}

run_health_checks() {
  local conf_file="$1"
  if [[ -f "$conf_file" ]]; then
    # Source in subshell to get CHECKS array without polluting env
    local checks
    checks=$(bash -c "source '$conf_file' 2>/dev/null; for c in \"\${CHECKS[@]}\"; do echo \"\$c\"; done")
    if [[ -n "$checks" ]]; then
      echo "  [dev] Running health checks..."
      while IFS= read -r check; do
        if ! eval "$check" &>/dev/null; then
          echo "  [dev] Health check failed: $check"
          return 1
        fi
      done <<< "$checks"
    fi
  fi
  return 0
}

# --- Commands ---

cmd_up() {
  local project_dir
  project_dir="$(cd "${1:-.}" && pwd)"
  local name
  name="$(workspace_name "$project_dir")"
  local conf_file="$SESSIONS_DIR/${name}.conf"

  echo "[dev] Setting up workspace: $name"
  echo "[dev] Project: $project_dir"

  # Check if workspace already exists
  if cmux rpc workspace.list 2>/dev/null | grep -q "\"$name\""; then
    echo "[dev] Workspace '$name' already exists. Focusing..."
    cmux rpc workspace.select --name "$name"
    return 0
  fi

  # Detect traits
  local traits
  traits="$(detect_traits "$project_dir")"
  local traits_string
  traits_string="$(echo "$traits" | tr '\n' ',')"
  echo "[dev] Detected traits: $traits_string"

  # Health checks from legacy config
  if ! run_health_checks "$conf_file"; then
    echo "[dev] Aborting due to failed health checks."
    return 1
  fi

  # Environment activation
  activate_env "$project_dir" "$traits"

  # Start services
  start_services "$project_dir" "$traits"

  # Resolve layout profile
  local profile
  profile="$(traits_to_profile "$traits")"
  echo "[dev] Using layout: $profile"

  # Create workspace
  local ws_id
  ws_id="$(cmux new-workspace --name "$name" --cwd "$project_dir" --id-format uuids 2>/dev/null)"
  echo "[dev] Created workspace: $name"

  # Build layout
  if [[ -f "$LAYOUTS_DIR/${profile}.sh" ]]; then
    bash "$LAYOUTS_DIR/${profile}.sh" "$name" "$project_dir" "$name" "$traits_string"
  else
    echo "[dev] Warning: layout '$profile' not found, using minimal"
    bash "$LAYOUTS_DIR/minimal.sh" "$name" "$project_dir" "$name" "$traits_string"
  fi

  cmux notify --title "dev" --body "Workspace '$name' ready ($profile)" 2>/dev/null || true
  echo "[dev] Workspace '$name' is ready."
}

cmd_down() {
  local project_dir
  project_dir="$(pwd)"
  local name
  name="$(workspace_name "$project_dir")"

  echo "[dev] Tearing down workspace: $name"

  # Stop docker if running
  if [[ -f "$project_dir/docker-compose.yml" || -f "$project_dir/docker-compose.yaml" ]]; then
    echo "  [dev] Stopping Docker services..."
    docker compose down 2>&1 | sed 's/^/  [docker] /'
  fi

  # Close workspace
  cmux rpc workspace.close --name "$name" 2>/dev/null || true
  echo "[dev] Workspace '$name' torn down."
}

cmd_status() {
  echo "[dev] Active workspaces:"
  cmux rpc workspace.list 2>/dev/null || echo "  (none or cmux not running)"
}

# --- Main ---

case "${1:-}" in
  up)
    shift
    cmd_up "${1:-}"
    ;;
  down)
    cmd_down
    ;;
  status)
    cmd_status
    ;;
  -h|--help)
    echo "Usage: dev [up|down|status] [dir]"
    echo ""
    echo "  dev up [dir]   Create workspace (default: current dir)"
    echo "  dev down       Teardown workspace for current dir"
    echo "  dev status     List active workspaces"
    echo "  dev [dir]      Reconnect or create workspace"
    ;;
  *)
    # No subcommand: reconnect or create
    project_dir="${1:-.}"
    project_dir="$(cd "$project_dir" && pwd)"
    name="$(workspace_name "$project_dir")"
    if cmux rpc workspace.list 2>/dev/null | grep -q "\"$name\""; then
      cmux rpc workspace.select --name "$name"
    else
      cmd_up "$project_dir"
    fi
    ;;
esac
