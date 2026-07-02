#!/bin/bash

# Check for dry run mode
DRY_RUN=${DRY_RUN:-0}

# Function to execute or simulate commands
run_cmd() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "Would execute: $*"
        return 0
    fi
    "$@"
}

# Base directory
DOTFILES="$HOME/dotdev"

# Install Homebrew and packages
if [ -f "$DOTFILES/scripts/brew.sh" ]; then
    run_cmd bash "$DOTFILES/scripts/brew.sh"
fi

# Create directory structure
run_cmd bash "$DOTFILES/scripts/setup.sh"

# Configure macOS
run_cmd bash "$DOTFILES/scripts/macos/defaults.sh"

# Create symlinks
# Ensure target dirs exist so Stow creates per-item symlinks (not tree-folded)
run_cmd mkdir -p "$HOME/.claude/hooks"
run_cmd mkdir -p "$HOME/.claude/skills"
run_cmd mkdir -p "$HOME/.config"
run_cmd mkdir -p "$HOME/.pi/agent"
run_cmd mkdir -p "$HOME/.config/herdr"

if [ "$DRY_RUN" = "1" ]; then
    stow -nv -R -t "$HOME" dotfiles/
else
    stow -v -R -t "$HOME" dotfiles/
fi

# AI tooling (guardian, headroom, gbrain, pi settings)
run_cmd bash "$DOTFILES/scripts/ai-setup.sh"

# Herdr integrations and plugins
run_cmd bash "$DOTFILES/scripts/herdr-setup.sh"

echo "Installation complete! Please restart your computer."
