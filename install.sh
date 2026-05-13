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
mkdir -p "$HOME/.claude/skills"
mkdir -p "$HOME/.config"

if [ "$DRY_RUN" = "1" ]; then
    stow -nv -R -t "$HOME" dotfiles/
else
    stow -v -R -t "$HOME" dotfiles/
fi

echo "Installation complete! Please restart your computer."
