#!/usr/bin/env bash
# hlog — snapshot active herdr agent panes to a daily log
#
# Usage:
#   hlog           # snapshot all agent panes, append to today's log
#   hlog --view    # tail today's log
#   hlog --search  # fzf search across all logs
#
# Log location: ~/.local/share/hlog/YYYY-MM-DD.jsonl

set -euo pipefail

LOG_DIR="${HOME}/.local/share/hlog"
TODAY_LOG="${LOG_DIR}/$(date +%Y-%m-%d).jsonl"

if [[ "${HERDR_ENV:-}" != "1" ]]; then
    echo "hlog: not inside herdr (HERDR_ENV != 1)" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

case "${1:-}" in

    --view | -v)
        if [[ -f "$TODAY_LOG" ]]; then
            jq -r '"\(.ts) [\(.workspace)/\(.pane_id)] \(.status)\n\(.tail)\n---"' "$TODAY_LOG" | less -R
        else
            echo "hlog: no log for today yet — run hlog to snapshot"
        fi
        exit 0
        ;;

    --search | -s)
        if ls "$LOG_DIR"/*.jsonl &>/dev/null; then
            cat "$LOG_DIR"/*.jsonl |
                jq -r '"\(.ts) [\(.workspace)/\(.pane_id)] \(.status)\n\(.tail)"' |
                fzf --ansi --multi
        else
            echo "hlog: no logs found in $LOG_DIR"
        fi
        exit 0
        ;;

esac

# ── snapshot ──────────────────────────────────────────────────────────────────

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PANES=$(herdr pane list | jq -c '.result.panes[]')
COUNT=0

while IFS= read -r pane; do
    PANE_ID=$(echo "$pane" | jq -r '.pane_id')
    STATUS=$(echo "$pane" | jq -r '.agent_status // "unknown"')
    WS_ID=$(echo "$pane" | jq -r '.pane_id | split(":")[0]')

    # skip unknown/unfocused shells with no agent activity
    [[ "$STATUS" == "unknown" ]] && continue

    TAIL=$(herdr pane read "$PANE_ID" --source recent-unwrapped --lines 30 2>/dev/null |
        tail -20 |
        sed 's/[[:space:]]*$//' ||
        echo "(no output)")

    jq -nc \
        --arg ts "$TS" \
        --arg pane_id "$PANE_ID" \
        --arg workspace "$WS_ID" \
        --arg status "$STATUS" \
        --arg tail "$TAIL" \
        '{ts: $ts, pane_id: $pane_id, workspace: $workspace, status: $status, tail: $tail}' \
        >>"$TODAY_LOG"

    ((COUNT++))
    echo "  ✓ $PANE_ID ($STATUS)"

done <<<"$PANES"

echo "hlog: $COUNT panes → $TODAY_LOG"
