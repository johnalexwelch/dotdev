#!/bin/bash
# routing-confirm.sh — Write routing confirmation marker
# Called by workflow-router after user confirms a route card.
#
# Usage: routing-confirm.sh [route_id]
# Creates .pi/routing-confirmed in current repo or $HOME/.pi/

set -euo pipefail

route_id="${1:-$(date +%s)}"
timestamp="$(date -Iseconds)"
created_at="$(date +%s)"
expires_at="$((created_at + 86400))"  # 24h TTL

# Find repo root or use home
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$repo_root" ]]; then
    marker_dir="$repo_root/.pi"
else
    marker_dir="$HOME/.pi"
fi

mkdir -p "$marker_dir"

cat >"$marker_dir/routing-confirmed" <<EOF
route_id: $route_id
confirmed_at: $timestamp
created_at: $created_at
expires_at: $expires_at
session_pid: $$
EOF

echo "✓ Routing confirmed: $marker_dir/routing-confirmed"
