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
if [ "$DRY_RUN" = "1" ]; then
    stow -nv -R -t "$HOME" config/
else
    stow -v -R -t "$HOME" config/
fi

echo "Installation complete! Please restart your computer."
