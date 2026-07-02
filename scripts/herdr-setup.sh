#!/bin/bash

DRY_RUN=${DRY_RUN:-0}

run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "Would execute: $*"
        return 0
    fi
    "$@"
}

# Install agent integrations (idempotent — herdr skips if already current)
for integration in pi claude codex opencode; do
    run_cmd herdr integration install "$integration"
done

# Install plugins — requires herdr server running (plugin builds need it)
if [ "$DRY_RUN" != "1" ] && ! herdr status server &>/dev/null; then
    echo "Warning: herdr server not running — skipping plugin install. Launch herdr, then re-run scripts/herdr-setup.sh"
    exit 0
fi
run_cmd herdr plugin install persiyanov/herdr-fresh-worktree --yes || echo "Warning: fresh-worktree plugin install failed — retry manually"
run_cmd herdr plugin install cloudmanic/herdr-plus --yes || echo "Warning: herdr-plus plugin install failed — retry manually"

echo "Herdr setup complete!"
