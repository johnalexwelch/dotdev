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
    basename "$dir"
}

find_workspace_ref() {
    local title="$1"
    cmux list-workspaces 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for w in data.get('workspaces', []):
        if w.get('title') == sys.argv[1]:
            print(w['ref'])
            break
except: pass
" "$title" 2>/dev/null
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
            echo "  [dev] Starting Docker services (background)..."
            (cd "$project_dir" && docker compose up -d --quiet-pull &>/dev/null &)
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
            done <<<"$checks"
        fi
    fi
    return 0
}

run_pre_start() {
    local conf_file="$1"
    local project_dir="$2"
    if [[ -f "$conf_file" ]]; then
        local cmds
        cmds=$(bash -c "source '$conf_file' 2>/dev/null; for c in \"\${PRE_START[@]}\"; do echo \"\$c\"; done")
        if [[ -n "$cmds" ]]; then
            echo "  [dev] Running pre-start hooks..."
            while IFS= read -r cmd; do
                [[ -z "$cmd" ]] && continue
                echo "  [dev] Running: ${cmd:0:80}..."
                if ! (cd "$project_dir" && eval "$cmd" 2>&1 | sed 's/^/  [pre-start] /'); then
                    echo "  [dev] WARNING: pre-start command failed (continuing anyway)"
                fi
            done <<<"$cmds"
        fi
    fi
}

# --- Commands ---

cmd_here() {
    local project_dir
    project_dir="$(cd "${1:-.}" && pwd)"
    local name
    name="$(workspace_name "$project_dir")"
    local ws="${CMUX_WORKSPACE_ID:-}"
    local terminal_surface="${CMUX_SURFACE_ID:-}"

    if [[ -z "$ws" ]]; then
        echo "[dev] Error: not running inside cmux"
        return 1
    fi

    echo "[dev] Applying layout to current workspace: $name"

    # Detect traits
    local traits
    traits="$(detect_traits "$project_dir")"
    echo "[dev] Detected traits: $(echo "$traits" | tr '\n' ',')"

    # Environment activation & services
    activate_env "$project_dir" "$traits"
    start_services "$project_dir" "$traits"

    # Rename workspace to project name
    cmux rename-workspace --workspace "$ws" "$name" 2>/dev/null

    # Source layout helpers (send_cmd, do_split, etc.)
    source "$LAYOUTS_DIR/lib.sh"

    # Layout: Claude (left) | Git (top-right) > Logs (mid-right) > Terminal (bottom-right)
    # The user's current pane becomes the terminal on the right.

    # Split left from terminal → Claude on left, terminal pushed right
    local claude_output claude_surface
    claude_output="$(cmux new-split left --workspace "$ws" --surface "$terminal_surface" 2>&1)"
    claude_surface="$(echo "$claude_output" | awk '{print $2}')"
    send_cmd "$ws" "$claude_surface" "cmux claude-teams"

    # Split up from terminal → Git above terminal on the right
    if echo "$traits" | grep -q "git"; then
        local git_output git_surface
        git_output="$(cmux new-split up --workspace "$ws" --surface "$terminal_surface" 2>&1)"
        git_surface="$(echo "$git_output" | awk '{print $2}')"
        if command -v lazygit &>/dev/null; then
            send_cmd "$ws" "$git_surface" "lazygit -p $project_dir"
        else
            send_cmd "$ws" "$git_surface" "watch -n 5 'git -C $project_dir status -sb'"
        fi

        # Split down from git → Logs between git and terminal
        if echo "$traits" | grep -q "docker"; then
            local logs_output logs_surface
            logs_output="$(cmux new-split down --workspace "$ws" --surface "$git_surface" 2>&1)"
            logs_surface="$(echo "$logs_output" | awk '{print $2}')"
            send_cmd "$ws" "$logs_surface" "docker compose -f $project_dir/docker-compose.yml logs -f 2>/dev/null || docker compose -f $project_dir/docker-compose.yaml logs -f"
        fi
    fi

    # Browser pane for web projects
    if echo "$traits" | grep -q "web"; then
        local port
        port=$(read_port "$project_dir")
        cmux new-pane --type browser --direction right --workspace "$ws" --url "http://localhost:$port" 2>/dev/null
    fi

    cmux notify --title "dev" --body "Layout ready: $name" 2>/dev/null || true
    echo "[dev] Layout applied."
}

cmd_up() {
    local project_dir
    project_dir="$(cd "${1:-.}" && pwd)"
    local name
    name="$(workspace_name "$project_dir")"
    local conf_file="$SESSIONS_DIR/${name}.conf"

    echo "[dev] Setting up workspace: $name"
    echo "[dev] Project: $project_dir"

    # Check if workspace already exists
    local existing_ref
    existing_ref="$(find_workspace_ref "$name")"
    if [[ -n "$existing_ref" ]]; then
        echo "[dev] Workspace '$name' already exists ($existing_ref). Focusing..."
        cmux select-workspace --workspace "$existing_ref"
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

    # Pre-start hooks (auth, etc.)
    run_pre_start "$conf_file" "$project_dir"

    # Start services
    start_services "$project_dir" "$traits"

    # Resolve layout profile
    local profile
    profile="$(traits_to_profile "$traits")"
    echo "[dev] Using layout: $profile"

    # Create workspace (output: "OK workspace:N")
    echo "[dev] Creating workspace: $name"
    local ws_output
    ws_output="$(cmux new-workspace --name "$name" --cwd "$project_dir" --command "cmux claude-teams" 2>&1)"
    local ws_ref
    ws_ref="$(echo "$ws_output" | awk '{print $2}')"
    if [[ -z "$ws_ref" || "$ws_ref" != workspace:* ]]; then
        echo "[dev] WARNING: Could not create workspace: $ws_output"
        return 1
    fi
    echo "[dev] Created workspace: $name ($ws_ref)"

    # Build layout
    if [[ -f "$LAYOUTS_DIR/${profile}.sh" ]]; then
        bash "$LAYOUTS_DIR/${profile}.sh" "$ws_ref" "$project_dir" "$name" "$traits_string"
    else
        echo "[dev] Warning: layout '$profile' not found, using minimal"
        bash "$LAYOUTS_DIR/minimal.sh" "$ws_ref" "$project_dir" "$name" "$traits_string"
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
    local ws_ref
    ws_ref="$(find_workspace_ref "$name")"
    if [[ -n "$ws_ref" ]]; then
        cmux close-workspace --workspace "$ws_ref" 2>/dev/null || true
    fi
    echo "[dev] Workspace '$name' torn down."
}

cmd_status() {
    echo "[dev] Active workspaces:"
    cmux list-workspaces 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for w in data.get('workspaces', []):
        sel = ' *' if w.get('selected') else '  '
        print(f\"{sel} {w['ref']}: {w['title']} ({w.get('current_directory','')})\" )
except: print('  (none or cmux not running)')
" 2>/dev/null || echo "  (none or cmux not running)"
}

# --- Main ---

case "${1:-}" in
    up)
        shift
        cmd_up "${1:-}"
        ;;
    here)
        shift
        cmd_here "${1:-}"
        ;;
    down)
        cmd_down
        ;;
    status)
        cmd_status
        ;;
    -h | --help)
        echo "Usage: dev [up|here|down|status] [dir]"
        echo ""
        echo "  dev up [dir]   Create new workspace (default: current dir)"
        echo "  dev here [dir] Add supporting panes to current workspace"
        echo "  dev down       Teardown workspace for current dir"
        echo "  dev status     List active workspaces"
        echo "  dev [dir]      Reconnect or create workspace"
        ;;
    *)
        # No subcommand: reconnect or create
        project_dir="${1:-.}"
        project_dir="$(cd "$project_dir" && pwd)"
        name="$(workspace_name "$project_dir")"
        ws_ref="$(find_workspace_ref "$name")"
        if [[ -n "$ws_ref" ]]; then
            cmux select-workspace --workspace "$ws_ref"
        else
            cmd_up "$project_dir"
        fi
        ;;
esac
