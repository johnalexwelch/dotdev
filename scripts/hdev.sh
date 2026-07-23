#!/usr/bin/env bash
# hdev — herdr workspace setup for AI development
# Replaces tmux-dev.sh for herdr-based workflows
#
# Usage:
#   hdev [project_dir]              # full layout: pi | lazygit+shell, gh tab
#   hdev [project_dir] --monitor    # gh-dash only (CI/issue monitoring)
#   hdev [project_dir] --minimal    # pi only
#
# Aliases: see ~/.config/zsh/tools/git.zsh

set -euo pipefail

# ── args ────────────────────────────────────────────────────────────────────

PROJECT_ARG="."
LAYOUT="full"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --monitor)
            LAYOUT="monitor"
            shift
            ;;
        --minimal)
            LAYOUT="minimal"
            shift
            ;;
        --help | -h)
            echo "Usage: hdev [project_dir] [--monitor|--minimal]"
            exit 0
            ;;
        -*)
            echo "hdev: unknown option: $1" >&2
            exit 2
            ;;
        *)
            PROJECT_ARG="$1"
            shift
            ;;
    esac
done

PROJECT_DIR="$(cd "$PROJECT_ARG" && pwd)"
PROJECT_NAME="${PROJECT_DIR##*/}"

# ── guard ────────────────────────────────────────────────────────────────────

if [[ "${HERDR_ENV:-}" != "1" ]]; then
    echo "hdev: not inside herdr (HERDR_ENV != 1)" >&2
    echo "hdev: launch herdr first, then run hdev from a herdr pane" >&2
    exit 1
fi

# ── helpers ──────────────────────────────────────────────────────────────────

_jq() { jq -r "$1" <<<"$2"; }

pane_split() {
    local pane="$1" dir="$2"
    herdr pane split "$pane" --direction "$dir" --no-focus |
        jq -r '.result.pane.pane_id'
}

tab_create() {
    local ws="$1" label="$2"
    herdr tab create --workspace "$ws" --label "$label" --no-focus |
        jq -r '.result.root_pane.pane_id'
}

# ── create workspace ─────────────────────────────────────────────────────────

echo "⧗ $PROJECT_NAME ($LAYOUT)..."

WS_JSON=$(herdr workspace create --cwd "$PROJECT_DIR" --label "$PROJECT_NAME" --no-focus)
WS_ID=$(_jq '.result.workspace.workspace_id' "$WS_JSON")
ROOT=$(_jq '.result.root_pane.pane_id' "$WS_JSON")

# ── layouts ──────────────────────────────────────────────────────────────────

case "$LAYOUT" in

    full)
        # work tab: pi (left) | lazygit (right-top) + shell (right-bottom)
        herdr pane run "$ROOT" "pi"

        LG=$(pane_split "$ROOT" right)
        herdr pane run "$LG" "lazygit"

        YZ=$(pane_split "$LG" down)
        herdr pane run "$YZ" "yazi $PROJECT_DIR"

        # gh tab: gh-dash
        GH=$(tab_create "$WS_ID" "gh")
        herdr pane run "$GH" "gh dash"
        ;;

    monitor)
        # single pane: gh-dash
        herdr pane run "$ROOT" "gh dash"
        ;;

    minimal)
        # single pane: pi
        herdr pane run "$ROOT" "pi"
        ;;

esac

# focus the new workspace
herdr workspace focus "$WS_ID"

echo "✓ $PROJECT_NAME ready"
