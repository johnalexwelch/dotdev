#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: tdev [--provider auto|codex|claude|opencode|shell] [--layout focus|code|full] [project_dir]

Options:
  -p, --provider, --agent  Choose the AI agent pane command.
  -l, --layout             Choose tmux layout: focus, code, or full. Default: full.
  -h, --help               Show this help.

Environment:
  AI_DEV_AGENT             Overrides provider selection with a raw command.
EOF
}

provider="auto"
layout="full"
project_arg="."
has_project_arg=0

case "${1:-}" in
    up | here)
        shift
        ;;
    status)
        if command -v tmux >/dev/null 2>&1; then
            tmux list-sessions
        else
            echo "tdev: tmux is not installed" >&2
        fi
        exit 0
        ;;
    down)
        echo "tdev: 'dev down' is not supported; use 'tmux kill-session -t <session>'." >&2
        exit 2
        ;;
esac

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p | --provider | --agent)
            [[ $# -ge 2 ]] || {
                echo "tdev: $1 requires a provider: auto, codex, claude, opencode, or shell" >&2
                exit 2
            }
            provider="$2"
            shift 2
            ;;
        --provider=* | --agent=*)
            provider="${1#*=}"
            shift
            ;;
        -l | --layout)
            [[ $# -ge 2 ]] || {
                echo "tdev: $1 requires a layout: focus, code, or full" >&2
                exit 2
            }
            layout="$2"
            shift 2
            ;;
        --layout=*)
            layout="${1#*=}"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --)
            shift
            [[ $# -le 1 ]] || {
                echo "tdev: expected at most one project directory" >&2
                exit 2
            }
            project_arg="${1:-.}"
            has_project_arg=1
            shift || true
            ;;
        -*)
            echo "tdev: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ "$has_project_arg" -eq 1 ]]; then
                echo "tdev: expected at most one project directory" >&2
                exit 2
            fi
            project_arg="$1"
            has_project_arg=1
            shift
            ;;
    esac
done

case "$layout" in
    focus | code | full) ;;
    *)
        echo "tdev: unknown layout '$layout'. Use focus, code, or full." >&2
        exit 2
        ;;
esac

project_dir="$(cd "$project_arg" && pwd)"
project_name="${project_dir##*/}"
session_name="${project_name//[^A-Za-z0-9_-]/-}"
agent_cmd="${AI_DEV_AGENT:-}"

if [[ -z "$agent_cmd" ]]; then
    case "$provider" in
        auto)
            if command -v codex >/dev/null 2>&1; then
                agent_cmd="codex"
            elif command -v claude >/dev/null 2>&1; then
                agent_cmd="claude"
            elif command -v opencode >/dev/null 2>&1; then
                agent_cmd="opencode"
            else
                agent_cmd="${SHELL:-zsh} -l"
            fi
            ;;
        codex | claude | opencode)
            if ! command -v "$provider" >/dev/null 2>&1; then
                echo "tdev: requested provider '$provider' is not installed or not on PATH" >&2
                exit 1
            fi
            agent_cmd="$provider"
            ;;
        shell)
            agent_cmd="${SHELL:-zsh} -l"
            ;;
        *)
            echo "tdev: unknown provider '$provider'. Use auto, codex, claude, opencode, or shell." >&2
            exit 2
            ;;
    esac
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "tdev: tmux is not installed; starting fallback command in $project_dir" >&2
    if [[ "${TMUX_DEV_NO_ATTACH:-}" == "1" ]]; then
        echo "$session_name"
        exit 0
    fi
    cd "$project_dir"
    # shellcheck disable=SC2086
    exec $agent_cmd
fi

ensure_edit_window() {
    local session="$1"
    local dir="$2"

    if tmux list-windows -t "$session" -F "#{window_name}" | grep -qx "edit"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n edit -c "$dir" "$(edit_command)"
}

ensure_issues_window() {
    local session="$1"
    local dir="$2"

    if window_exists "$session" "issues"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n issues -c "$dir" "$(octo_command issue issues)"
}

ensure_prs_window() {
    local session="$1"
    local dir="$2"

    if window_exists "$session" "prs"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n prs -c "$dir" "$(octo_command pr "pull requests")"
}

edit_command() {
    echo "nvim . +'Neotree reveal'"
}

octo_command() {
    local kind="$1"
    local label="$2"

    # shellcheck disable=SC2016 # Expand repo/PWD/SHELL inside the tmux pane shell.
    printf 'if repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" && [ -n "$repo" ]; then exec nvim +"Octo %s list $repo"; fi; echo "No GitHub repo detected for Octo %s in $PWD."; echo "Run gh repo view here or launch tdev from a GitHub-backed repo."; exec ${SHELL:-zsh} -l' "$kind" "$label"
}

window_exists() {
    local session="$1"
    local window="$2"

    tmux list-windows -t "$session" -F "#{window_name}" | grep -qx "$window"
}

window_pane_count() {
    local session="$1"
    local window="$2"

    tmux display-message -p -t "$session:=$window" "#{window_panes}"
}

git_command() {
    if command -v lazygit >/dev/null 2>&1; then
        echo "lazygit"
    else
        echo "watch -n 5 git status -sb"
    fi
}

ensure_git_window() {
    local session="$1"
    local dir="$2"

    if window_exists "$session" "git"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n git -c "$dir" "$(git_command)"
}

ensure_test_window() {
    local session="$1"
    local dir="$2"

    if window_exists "$session" "test"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n test -c "$dir" "$(test_command)"
}

ensure_logs_window() {
    local session="$1"
    local dir="$2"

    if window_exists "$session" "logs"; then
        return 0
    fi

    tmux new-window -d -t "$session" -n logs -c "$dir" "$(logs_command)"
}

graph_shell_command() {
    echo "if [ -f ~/dotdev/scripts/graphify-repo.sh ]; then bash ~/dotdev/scripts/graphify-repo.sh status; else echo '[graph] graphify helper not installed in this checkout.'; echo '[graph] Use this pane for repo notes or graph commands.'; fi; exec ${SHELL:-zsh} -l"
}

logs_command() {
    if [[ -f "$project_dir/docker-compose.yml" || -f "$project_dir/docker-compose.yaml" ]]; then
        echo "echo '[logs] docker compose detected; streaming logs.'; docker compose logs -f; exec ${SHELL:-zsh} -l"
    else
        echo "echo '[logs] No log source detected.'; echo '[logs] This tab is ready for docker compose logs -f, tail -f, or a dev server command.'; exec ${SHELL:-zsh} -l"
    fi
}

test_command() {
    local label=""
    local command=""

    if [[ -f "$project_dir/package.json" ]]; then
        label="package.json detected"
        command="npm test"
    elif [[ -f "$project_dir/Makefile" ]] && grep -Eq '^(test|check):' "$project_dir/Makefile"; then
        label="Makefile test/check target detected"
        if grep -Eq '^test:' "$project_dir/Makefile"; then
            command="make test"
        else
            command="make check"
        fi
    elif [[ -f "$project_dir/justfile" || -f "$project_dir/Justfile" ]]; then
        label="justfile detected"
        command="just test"
    elif [[ -f "$project_dir/pyproject.toml" || -f "$project_dir/pytest.ini" ]]; then
        label="Python test config detected"
        command="python -m pytest"
    elif compgen -G "$project_dir/test/test-*.sh" >/dev/null; then
        echo "echo '[test] Shell test scripts detected:'; ls -1 test/test-*.sh; echo '[test] Run one of the scripts above from this tab.'; exec ${SHELL:-zsh} -l"
    else
        echo "echo '[test] No test command detected.'; echo '[test] This tab is ready for the project test command.'; exec ${SHELL:-zsh} -l"
    fi

    if [[ -n "$command" ]]; then
        if [[ "${TMUX_DEV_RUN_TESTS:-}" == "1" ]]; then
            echo "echo '[test] $label; running: $command'; $command; exec ${SHELL:-zsh} -l"
        else
            echo "echo '[test] $label.'; echo '[test] Suggested command: $command'; echo '[test] Set TMUX_DEV_RUN_TESTS=1 before launch to run it automatically.'; exec ${SHELL:-zsh} -l"
        fi
    fi
}

split_dev_window_to_focus() {
    local session="$1"
    local dir="$2"
    local panes base_pane agent_pane second_pane

    panes="$(window_pane_count "$session" "dev")"
    if ((panes >= 3)); then
        normalize_focus_dev_window "$session"
        return 0
    fi

    base_pane="$(tmux list-panes -t "$session:=dev" -F "#{pane_id}" | sed -n '1p')"
    if ((panes == 1)); then
        agent_pane="$base_pane"
        second_pane="$(tmux split-window -h -p 33 -P -F "#{pane_id}" -t "$agent_pane" -c "$dir" "$(git_command)")"
        tmux split-window -v -p 35 -t "$second_pane" -c "$dir" "$(graph_shell_command)" >/dev/null
        normalize_focus_dev_window "$session"
        return 0
    fi

    second_pane="$(tmux list-panes -t "$session:=dev" -F "#{pane_id}" | sed -n '2p')"
    tmux split-window -v -p 35 -t "$second_pane" -c "$dir" "$(graph_shell_command)" >/dev/null
    normalize_focus_dev_window "$session"
}

normalize_focus_dev_window() {
    local session="$1"
    local first_pane agent_pane window_width main_width

    first_pane="$(tmux list-panes -t "$session:=dev" -F "#{pane_id}" | sed -n '1p')"
    agent_pane="$(
        tmux list-panes -t "$session:=dev" -F "#{pane_id}	#{pane_start_command}	#{pane_current_command}" |
            while IFS=$'\t' read -r pane_id start_command current_command; do
                if [[ "$start_command" == "$agent_cmd" ||
                    "$current_command" == codex* ||
                    "$current_command" == claude* ||
                    "$current_command" == opencode* ]]; then
                    printf '%s' "$pane_id"
                    break
                fi
            done
    )"

    if [[ -n "$agent_pane" && "$agent_pane" != "$first_pane" ]]; then
        tmux swap-pane -s "$agent_pane" -t "$first_pane"
        first_pane="$(tmux list-panes -t "$session:=dev" -F "#{pane_id}" | sed -n '1p')"
    fi

    window_width="$(tmux display-message -p -t "$session:=dev" "#{window_width}")"
    main_width=$((window_width * 67 / 100))
    tmux resize-pane -t "$first_pane" -x "$main_width" >/dev/null
    tmux select-pane -t "$first_pane"
}

ensure_focus_dev_window() {
    local session="$1"
    local dir="$2"
    local left_pane agent_pane

    if ! window_exists "$session" "dev"; then
        left_pane="$(tmux new-window -d -t "$session" -n dev -c "$dir" -P -F "#{pane_id}" "$(git_command)")"
        agent_pane="$(tmux split-window -h -p 67 -P -F "#{pane_id}" -t "$left_pane" -c "$dir" "$agent_cmd")"
        tmux split-window -v -p 35 -t "$agent_pane" -c "$dir" "$(graph_shell_command)" >/dev/null
        return 0
    fi

    split_dev_window_to_focus "$session" "$dir"
}

ensure_code_dev_window() {
    local session="$1"
    local dir="$2"
    local agent_pane

    if ! window_exists "$session" "dev"; then
        agent_pane="$(tmux new-window -d -t "$session" -n dev -c "$dir" -P -F "#{pane_id}" "$agent_cmd")"
        tmux split-window -v -p 35 -t "$agent_pane" -c "$dir" "$(graph_shell_command)" >/dev/null
        return 0
    fi

    if (($(window_pane_count "$session" "dev") == 1)); then
        agent_pane="$(tmux list-panes -t "$session:=dev" -F "#{pane_id}" | sed -n '1p')"
        tmux split-window -v -p 35 -t "$agent_pane" -c "$dir" "$(graph_shell_command)" >/dev/null
    fi
}

create_focus_layout() {
    local agent_pane helper_pane
    agent_pane="$(tmux new-session -d -s "$session_name" -n dev -c "$project_dir" -P -F "#{pane_id}" "$agent_cmd")"
    helper_pane="$(tmux split-window -h -p 33 -P -F "#{pane_id}" -t "$agent_pane" -c "$project_dir" "$(git_command)")"
    tmux split-window -v -p 35 -t "$helper_pane" -c "$project_dir" "$(graph_shell_command)" >/dev/null
    normalize_focus_dev_window "$session_name"
    tmux select-pane -t "$agent_pane"
    tmux select-window -t "$session_name:=dev"
}

create_code_layout() {
    local agent_pane
    agent_pane="$(tmux new-session -d -s "$session_name" -n dev -c "$project_dir" -P -F "#{pane_id}" "$agent_cmd")"
    tmux split-window -v -p 35 -t "$agent_pane" -c "$project_dir" "$(graph_shell_command)" >/dev/null
    tmux new-window -d -t "$session_name" -n git -c "$project_dir" "$(git_command)"
    ensure_edit_window "$session_name" "$project_dir"
    tmux select-window -t "$session_name:=edit"
}

create_full_layout() {
    create_focus_layout
    tmux new-window -d -t "$session_name" -n git -c "$project_dir" "$(git_command)"
    ensure_edit_window "$session_name" "$project_dir"
    ensure_issues_window "$session_name" "$project_dir"
    ensure_prs_window "$session_name" "$project_dir"
    ensure_test_window "$session_name" "$project_dir"
    tmux new-window -d -t "$session_name" -n logs -c "$project_dir" "$(logs_command)"
    tmux select-window -t "$session_name:=dev"
}

if tmux has-session -t "$session_name" 2>/dev/null; then
    case "$layout" in
        focus)
            ensure_focus_dev_window "$session_name" "$project_dir"
            tmux select-window -t "$session_name:=dev"
            ;;
        code)
            ensure_code_dev_window "$session_name" "$project_dir"
            ensure_git_window "$session_name" "$project_dir"
            ensure_edit_window "$session_name" "$project_dir"
            tmux select-window -t "$session_name:=edit"
            ;;
        full)
            ensure_focus_dev_window "$session_name" "$project_dir"
            ensure_git_window "$session_name" "$project_dir"
            ensure_edit_window "$session_name" "$project_dir"
            ensure_issues_window "$session_name" "$project_dir"
            ensure_prs_window "$session_name" "$project_dir"
            ensure_test_window "$session_name" "$project_dir"
            ensure_logs_window "$session_name" "$project_dir"
            tmux select-window -t "$session_name:=dev"
            ;;
    esac
    if [[ "${TMUX_DEV_NO_ATTACH:-}" == "1" ]]; then
        echo "$session_name"
        exit 0
    fi
    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    fi
    exit 0
fi

case "$layout" in
    focus) create_focus_layout ;;
    code) create_code_layout ;;
    full) create_full_layout ;;
esac

if [[ "${TMUX_DEV_NO_ATTACH:-}" == "1" ]]; then
    echo "$session_name"
    exit 0
fi

if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
