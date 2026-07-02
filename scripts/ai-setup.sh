#!/bin/bash

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=${DRY_RUN:-0}

run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "Would execute: $*"
        return 0
    fi
    "$@"
}

# Bootstrap settings.local.json from template if it doesn't exist
if [ ! -f "$HOME/.claude/settings.local.json" ]; then
    run_cmd cp "$DOTFILES/dotfiles/.claude/settings.local.template.json" "$HOME/.claude/settings.local.json"
    echo "Created ~/.claude/settings.local.json from template"
fi

# Install Headroom proxy
if command -v pip3 &>/dev/null; then
    run_cmd pip3 install --quiet headroom-ai[proxy]
else
    echo "Warning: pip3 not found — skipping headroom-ai install"
fi

# Install guardian (permission guardian for Claude Code)
GUARDIAN_DIR="$HOME/.claude/guardian"
if [ ! -d "$GUARDIAN_DIR" ]; then
    echo "Cloning guardian..."
    run_cmd git clone git@github-personal:johnalexwelch/guardian.git "$GUARDIAN_DIR"
fi
if [ -d "$GUARDIAN_DIR" ] && [ ! -f "$GUARDIAN_DIR/node_modules/.package-lock.json" ]; then
    run_cmd bash -c "cd '$GUARDIAN_DIR' && npm install --silent"
    echo "Guardian ready"
elif [ -d "$GUARDIAN_DIR" ]; then
    echo "Guardian ready (deps cached)"
fi

# Clone gbrain MCP server (optional — set INSTALL_GBRAIN=1 to enable)
if [ "${INSTALL_GBRAIN:-0}" = "1" ]; then
    GBRAIN_DIR="$HOME/gbrain-repo"
    if [ ! -d "$GBRAIN_DIR" ]; then
        echo "Cloning gbrain..."
        run_cmd git clone https://github.com/garrytan/gbrain.git "$GBRAIN_DIR"
    else
        echo "gbrain already present, skipping clone"
    fi
fi

# Install pi packages from settings.json
PI_SETTINGS="$DOTFILES/dotfiles/.pi/agent/settings.json"
if [ -f "$PI_SETTINGS" ]; then
    echo "Installing pi packages..."
    python3 -c "import json; [print(p) for p in json.load(open('$PI_SETTINGS'))['packages']]" | while read -r pkg; do
        run_cmd pi install "$pkg"
    done
else
    echo "Warning: pi settings missing — skipping pi package install"
fi

# Guardian .env — ANTHROPIC_API_KEY required, cannot be automated
GUARDIAN_ENV="$HOME/.claude/guardian/.env"
if [ ! -f "$GUARDIAN_ENV" ] && [ -d "$HOME/.claude/guardian" ]; then
    echo ""
    echo "Action required: Guardian .env missing"
    echo "  Create: $GUARDIAN_ENV"
    echo "  Contents: ANTHROPIC_API_KEY=<key from console.anthropic.com>"
    echo ""
fi

echo "AI setup complete!"
# ponytail: claude plugins need no script — enabledPlugins in stowed settings.json drives Claude directly
