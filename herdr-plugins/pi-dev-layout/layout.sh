#!/usr/bin/env bash
# On workspace/worktree creation, decorate the agent pane with nvim + yazi on the right:
#   +----------------+--------+
#   |                | nvim   |
#   |  agent (pi)    +--------+
#   |                | yazi   |
#   +----------------+--------+
# Opt out globally: touch "$(herdr plugin config-dir pi-dev-layout)/off"
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
command -v jq >/dev/null 2>&1 || exit 0
log() { printf '%s\n' "$*"; }  # -> herdr plugin log list --plugin pi-dev-layout

# Tunables (ponytail: hard-coded defaults, override via env if ever needed)
RIGHT_CMD="${PI_LAYOUT_RIGHT_CMD:-nvim}"       # top-right
BOTTOM_CMD="${PI_LAYOUT_BOTTOM_CMD:-yazi}"     # bottom-right
RIGHT_RATIO="${PI_LAYOUT_RIGHT_RATIO:-0.62}"   # split point for agent|right column
BOTTOM_RATIO="${PI_LAYOUT_BOTTOM_RATIO:-0.5}"  # split point for nvim|yazi

cfg="${HERDR_PLUGIN_CONFIG_DIR:-}"
[ -n "$cfg" ] && [ -e "$cfg/off" ] && { log "skip: layout off"; exit 0; }

evt="${HERDR_PLUGIN_EVENT_JSON:-}"
[ -n "$evt" ] || { log "skip: no event json"; exit 0; }
log "EVENT: $evt"   # ponytail: raw dump for first-run field discovery; harmless to keep

ws="$(printf '%s' "$evt" | jq -r '.data.workspace.workspace_id // .data.workspace_id // .data.worktree.workspace_id // .workspace_id // empty')"
[ -n "$ws" ] || { log "skip: no workspace_id"; exit 0; }

# Dedup + race guard: claim the workspace atomically (mkdir is atomic, so if
# created + focused fire together only one invocation wins).
state="${HERDR_PLUGIN_STATE_DIR:-$HOME/.cache/pi-dev-layout}"; mkdir -p "$state" 2>/dev/null
marker="$state/$(printf '%s' "$ws" | tr -c 'A-Za-z0-9' _).done"
mkdir "$marker" 2>/dev/null || { log "skip: already claimed $ws"; exit 0; }

# Wait for the agent pane to exist (herdr spawns it around create time).
panes=""; for _ in 1 2 3 4 5 6 7 8; do
  panes="$("$herdr" pane list --workspace "$ws" 2>/dev/null | jq -c '.result.panes // []' 2>/dev/null)"
  n="$(printf '%s' "$panes" | jq 'length' 2>/dev/null || echo 0)"
  [ "${n:-0}" -ge 1 ] && break
  sleep 0.4
done
n="$(printf '%s' "$panes" | jq 'length' 2>/dev/null || echo 0)"
# Only decorate a pristine workspace (exactly one pane) so we never disturb a manual
# layout. Release the claim on any non-decorate exit so nothing is permanently blocked.
[ "${n:-0}" = "1" ] || { log "skip: pane count=$n (not pristine)"; rmdir "$marker" 2>/dev/null; exit 0; }

primary="$(printf '%s' "$panes" | jq -r '.[0].pane_id')"
cwd="$(printf '%s' "$panes" | jq -r '.[0].foreground_cwd // .[0].cwd // empty')"
[ -n "$primary" ] || { log "skip: no primary pane"; rmdir "$marker" 2>/dev/null; exit 0; }
log "decorating ws=$ws primary=$primary cwd=$cwd"

split() { # <pane> <right|down> <ratio> -> echoes new pane_id
  "$herdr" pane split "$1" --direction "$2" --ratio "$3" --no-focus ${cwd:+--cwd "$cwd"} 2>/dev/null \
    | jq -r '.result.pane.pane_id // empty'
}

right="$(split "$primary" right "$RIGHT_RATIO")"
[ -n "$right" ] || { log "err: right split failed"; exit 0; }
"$herdr" pane run "$right" "$RIGHT_CMD" >/dev/null 2>&1

bottom="$(split "$right" down "$BOTTOM_RATIO")"
[ -n "$bottom" ] && "$herdr" pane run "$bottom" "$BOTTOM_CMD" >/dev/null 2>&1

# All splits used --no-focus, so focus stayed on the agent pane. Nothing to restore.
log "done ws=$ws right=$right bottom=${bottom:-none}"
