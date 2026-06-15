#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() {
    if command -v tmux >/dev/null 2>&1; then
        tmux kill-session -t dotdev-tmux-test 2>/dev/null || true
        tmux kill-session -t dotdev-package-test 2>/dev/null || true
    fi
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

run_check() {
    local name="$1"
    shift

    if "$@"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

assert_aliases_use_tmux_dev() {
    grep -q "alias dev='bash ~/dotdev/scripts/tmux-dev.sh'" "$REPO_ROOT/dotfiles/.config/zsh/configs/aliases.zsh" &&
        grep -q "alias tdev='bash ~/dotdev/scripts/tmux-dev.sh'" "$REPO_ROOT/dotfiles/.config/zsh/configs/aliases.zsh" &&
        grep -q "alias iris='bash ~/dotdev/scripts/tmux-dev.sh ~/projects/iris'" "$REPO_ROOT/dotfiles/.config/zsh/configs/aliases.zsh" &&
        grep -q "alias iris-reset='tmux kill-session -t iris'" "$REPO_ROOT/dotfiles/.config/zsh/configs/aliases.zsh" &&
        ! grep -q "scripts/dev.sh" "$REPO_ROOT/dotfiles/.config/zsh/configs/aliases.zsh"
}

assert_no_removed_dev_dependencies() {
    ! rg --hidden -n \
        "cmux|scripts/dev\\.sh|scripts/log-notifier\\.sh|log-notifier\\.sh|manaflow-ai/cmux" \
        "$REPO_ROOT" \
        --glob '!dotfiles/graphify-out/**' \
        --glob '!backups/**' \
        --glob '!outputs/**' \
        --glob '!test/test-tmux-dev.sh' \
        --glob '!.git/**'
}

assert_focus_layout() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"
    mkdir -p "$project_dir"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout focus --provider shell "$project_dir" >/dev/null

    local panes
    panes="$(tmux display-message -p -t dotdev-tmux-test:=dev "#{window_panes}")"
    local first_cmd
    first_cmd="$(tmux list-panes -t dotdev-tmux-test:=dev -F "#{pane_index}:#{pane_start_command}" | sed -n '1s/^[0-9]*://p')"
    [[ "$panes" == "3" ]] &&
        [[ "$first_cmd" == "\"sleep 60\"" || "$first_cmd" == "sleep 60" ]]
}

assert_default_layout_has_tabs() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"
    mkdir -p "$project_dir"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --provider shell "$project_dir" >/dev/null

    local windows
    windows="$(tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | sort | tr '\n' ' ')"
    [[ "$windows" == *"dev "* ]] &&
        [[ "$windows" == *"edit "* ]] &&
        [[ "$windows" == *"git "* ]] &&
        [[ "$windows" == *"issues "* ]] &&
        [[ "$windows" == *"logs "* ]] &&
        [[ "$windows" == *"prs "* ]] &&
        [[ "$windows" == *"test "* ]]
}

assert_full_layout_logs_fallback() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout full --provider shell "$project_dir" >/dev/null

    tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | grep -qx "git" || return 1
    tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | grep -qx "edit" || return 1
    tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | grep -qx "issues" || return 1
    tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | grep -qx "prs" || return 1
    tmux list-windows -t dotdev-tmux-test -F "#{window_name}" | grep -qx "logs" || return 1
    tmux capture-pane -p -t dotdev-tmux-test:=logs | grep -q "\\[logs\\] No log source detected."
}

assert_test_window_has_useful_command() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout full --provider shell "$project_dir" >/dev/null

    local test_cmd
    test_cmd="$(tmux list-panes -t dotdev-tmux-test:=test -F "#{pane_start_command}")"

    [[ "$test_cmd" == *"[test]"* ]] &&
        [[ "$test_cmd" == *"exec "* ]]
}

assert_test_window_suggests_package_command() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-package-test"
    mkdir -p "$project_dir"
    printf '{"scripts":{"test":"echo should-not-run"}}\n' >"$project_dir/package.json"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout full --provider shell "$project_dir" >/dev/null

    local test_cmd
    test_cmd="$(tmux list-panes -t dotdev-package-test:=test -F "#{pane_start_command}")"

    [[ "$test_cmd" == *"Suggested command: npm test"* ]] &&
        [[ "$test_cmd" == *"TMUX_DEV_RUN_TESTS=1"* ]] &&
        [[ "$test_cmd" != *"running: npm test"* ]]
}

assert_graph_pane_handles_missing_helper() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout focus --provider shell "$project_dir" >/dev/null

    local graph_cmd
    graph_cmd="$(tmux list-panes -t dotdev-tmux-test:=dev -F "#{pane_start_command}" | grep "graphify helper")"

    [[ "$graph_cmd" == *"graphify helper not installed"* ]] &&
        [[ "$graph_cmd" == *"exec "* ]]
}

assert_session_switch_selects_session() {
    local mockbin="$TMP_ROOT/mockbin-select"
    local log="$TMP_ROOT/session-switch-select.log"
    mkdir -p "$mockbin"

    cat >"$mockbin/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
list-sessions)
    printf 'alpha\nbeta\n'
    ;;
switch-client)
    printf 'switch:%s\n' "$3" >>"$TMUX_SWITCH_LOG"
    ;;
*)
    exit 2
    ;;
esac
EOF
    cat >"$mockbin/fzf" <<'EOF'
#!/usr/bin/env bash
head -n 1
EOF
    chmod +x "$mockbin/tmux" "$mockbin/fzf"

    TMUX_SWITCH_LOG="$log" PATH="$mockbin:$PATH" bash "$REPO_ROOT/scripts/tmux-session-switch.sh"
    grep -qx "switch:alpha" "$log"
}

assert_session_switch_cancel_is_noop() {
    local mockbin="$TMP_ROOT/mockbin-cancel"
    local log="$TMP_ROOT/session-switch-cancel.log"
    mkdir -p "$mockbin"

    cat >"$mockbin/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
list-sessions)
    printf 'alpha\n'
    ;;
switch-client)
    printf 'switch:%s\n' "$3" >>"$TMUX_SWITCH_LOG"
    ;;
*)
    exit 2
    ;;
esac
EOF
    cat >"$mockbin/fzf" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$mockbin/tmux" "$mockbin/fzf"

    TMUX_SWITCH_LOG="$log" PATH="$mockbin:$PATH" bash "$REPO_ROOT/scripts/tmux-session-switch.sh"
    [[ ! -f "$log" ]]
}

assert_legacy_status_lists_tmux_sessions() {
    local mockbin="$TMP_ROOT/mockbin-status"
    mkdir -p "$mockbin"

    cat >"$mockbin/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
list-sessions)
    printf 'alpha: 1 windows\n'
    ;;
*)
    exit 2
    ;;
esac
EOF
    chmod +x "$mockbin/tmux"

    local output
    output="$(PATH="$mockbin:$PATH" bash "$REPO_ROOT/scripts/tmux-dev.sh" status)"
    [[ "$output" == "alpha: 1 windows" ]]
}

assert_legacy_down_is_explicit_error() {
    local output status
    set +e
    output="$(bash "$REPO_ROOT/scripts/tmux-dev.sh" down 2>&1)"
    status=$?
    set -e

    [[ "$status" -eq 2 ]] &&
        [[ "$output" == *"not supported"* ]] &&
        [[ "$output" == *"tmux kill-session"* ]]
}

assert_preloaded_neovim_commands() {
    command -v tmux >/dev/null 2>&1 || {
        echo "    SKIP: tmux is not installed"
        return 0
    }

    local project_dir="$TMP_ROOT/dotdev-tmux-test"

    TMUX_DEV_NO_ATTACH=1 AI_DEV_AGENT="sleep 60" \
        bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout full --provider shell "$project_dir" >/dev/null

    local edit_cmd issues_cmd prs_cmd
    edit_cmd="$(tmux list-panes -t dotdev-tmux-test:=edit -F "#{pane_start_command}")"
    issues_cmd="$(tmux list-panes -t dotdev-tmux-test:=issues -F "#{pane_start_command}")"
    prs_cmd="$(tmux list-panes -t dotdev-tmux-test:=prs -F "#{pane_start_command}")"

    [[ "$edit_cmd" == *"Neotree reveal"* ]] &&
        [[ "$issues_cmd" == *"gh repo view"* ]] &&
        [[ "$issues_cmd" == *"Octo issue list"* ]] &&
        [[ "$prs_cmd" == *"gh repo view"* ]] &&
        [[ "$prs_cmd" == *"Octo pr list"* ]]
}

assert_no_tmux_dry_run_fallback() {
    local project_dir="$TMP_ROOT/no-tmux-project"
    mkdir -p "$project_dir"

    local output
    output="$(
        PATH="$TMP_ROOT/empty-path" TMUX_DEV_NO_ATTACH=1 SHELL=/bin/sh \
            /bin/bash "$REPO_ROOT/scripts/tmux-dev.sh" --layout focus --provider shell "$project_dir" 2>&1
    )"

    echo "$output" | grep -q "tmux is not installed" &&
        echo "$output" | grep -q "no-tmux-project"
}

echo "=== tmux dev workflow tests ==="
run_check "dev and tdev aliases use tmux-dev.sh" assert_aliases_use_tmux_dev
run_check "removed cmux/dev.sh/log-notifier dependencies are absent" assert_no_removed_dev_dependencies
run_check "focus layout creates a 3-pane dev window" assert_focus_layout
run_check "default layout creates bottom tabs" assert_default_layout_has_tabs
run_check "full layout creates a logs window with safe fallback output" assert_full_layout_logs_fallback
run_check "test window starts with a useful fallback command" assert_test_window_has_useful_command
run_check "test window suggests package command without running it" assert_test_window_suggests_package_command
run_check "graph pane handles missing helper" assert_graph_pane_handles_missing_helper
run_check "session switch selects a session" assert_session_switch_selects_session
run_check "session switch cancel exits cleanly" assert_session_switch_cancel_is_noop
run_check "legacy dev status lists tmux sessions" assert_legacy_status_lists_tmux_sessions
run_check "legacy dev down gives explicit error" assert_legacy_down_is_explicit_error
run_check "preloaded Neovim windows open tree and Octo views" assert_preloaded_neovim_commands
run_check "missing tmux has a dry-run fallback" assert_no_tmux_dry_run_fallback

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

if ((FAIL > 0)); then
    exit 1
fi
