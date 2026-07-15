#!/bin/bash

# Invariant: idempotent — integrations skip if current; plugins need a running herdr server + network.
DRY_RUN=${DRY_RUN:-0}

run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "Would execute: $*"
        return 0
    fi
    "$@"
}

# Install agent integrations (idempotent — reinstall updates outdated hooks)
for integration in pi claude codex opencode cursor; do
    run_cmd herdr integration install "$integration"
done

# Install plugins — requires herdr server running (plugin builds need it)
if [ "$DRY_RUN" != "1" ] && ! herdr status server &>/dev/null; then
    echo "Warning: herdr server not running — skipping plugin install. Launch herdr, then re-run scripts/herdr-setup.sh"
    exit 0
fi
install_plugin() {  # <source> [extra args...]
    run_cmd herdr plugin install "$@" --yes || echo "Warning: plugin install failed ($1) — retry manually"
}
install_plugin persiyanov/herdr-fresh-worktree
install_plugin cloudmanic/herdr-plus
install_plugin JacquesvanWyk/herdr-hunk            # autodiff-on-finish + fzf hunk picker (needs fzf, hunk)
install_plugin milkyskies/herdr-attention          # prefix+a: jump to next agent needing attention
install_plugin paulbkim-dev/vim-herdr-navigation   # ctrl+hjkl across panes <-> nvim splits
install_plugin usrivastava92/herdr-wakeup/plugin --ref v0.1.0  # hold wake assertion while agents work
install_plugin shoaibkhanz/herdr-active-agent-jump # prefix+alt+a: cycle in-flight agents
install_plugin wyattjoh/herdr-plugin-gh-pr         # PR/CI status in sidebar (needs gh, bun)
install_plugin Davidcreador/herdr-token-dashboard  # prefix+$: per-pane token/cost dashboard (needs go)
install_plugin thanhdat77/herdr-picker-plus        # prefix+alt+p: unified fuzzy picker (needs cargo)
install_plugin trapple/herdr-focus                 # focus blocked/done + terminal-to-front (opt global hotkey)
install_plugin makyinmars/herdr-context.nvim       # nvim: stage code as agent context (pairs w/ nvim spec)

# Local plugin: auto-layout new workspaces/worktrees as agent | nvim + yazi.
run_cmd herdr plugin link "$HOME/dotdev/herdr-plugins/pi-dev-layout" 2>/dev/null || true

# wakeup needs an explicit start per session (not auto-started on restart)
run_cmd herdr plugin action invoke start --plugin herdr-wakeup 2>/dev/null || true

echo "Herdr setup complete!"
