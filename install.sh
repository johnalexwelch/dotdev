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

# Homebrew + packages
run_cmd bash "$DOTFILES/scripts/brew.sh"

# Project dirs
run_cmd mkdir -p ~/dbtlabs ~/jarvis ~/projects

# Config dir structure (mkdir only — no stow here)
DOTFILES="$DOTFILES" run_cmd bash "$DOTFILES/scripts/config-init.sh"

# GitHub SSH + CLI extensions
run_cmd bash "$DOTFILES/scripts/github.sh"
run_cmd bash "$DOTFILES/scripts/gh-extensions.sh"

# App config symlinks
run_cmd mkdir -p "$HOME/Library/Application Support"
run_cmd ln -sf "$HOME/.config/arc" "$HOME/Library/Application Support/Arc"
run_cmd ln -sf "$HOME/.config/cursor" "$HOME/Library/Application Support/Cursor"
run_cmd ln -sf "$HOME/.config/streamdeck" "$HOME/Library/Application Support/com.elgato.StreamDeck"

# macOS defaults
run_cmd bash "$DOTFILES/scripts/macos/defaults.sh"
run_cmd bash "$DOTFILES/scripts/macos/finder.sh"
run_cmd bash "$DOTFILES/scripts/macos/dock.sh"
run_cmd bash "$DOTFILES/scripts/macos/spotlight.sh"
run_cmd bash "$DOTFILES/scripts/macos/terminal.sh"
run_cmd bash "$DOTFILES/scripts/macos/screen.sh"
run_cmd bash "$DOTFILES/scripts/macos/input_devices.sh"
run_cmd bash "$DOTFILES/scripts/macos/permissions.sh"

# Create symlinks
# Ensure target dirs exist so Stow creates per-item symlinks (not tree-folded)
run_cmd mkdir -p "$HOME/.claude/hooks"
run_cmd mkdir -p "$HOME/.claude/skills"
run_cmd mkdir -p "$HOME/.config"
run_cmd mkdir -p "$HOME/.pi/agent"
run_cmd mkdir -p "$HOME/.config/herdr"

if [ "$DRY_RUN" = "1" ]; then
    stow -d "$DOTFILES" -nv -R -t "$HOME" dotfiles
else
    stow -d "$DOTFILES" -v -R -t "$HOME" dotfiles
fi

# AI tooling (guardian, headroom, gbrain, pi settings)
run_cmd bash "$DOTFILES/scripts/ai-setup.sh"

# Herdr integrations and plugins
run_cmd bash "$DOTFILES/scripts/herdr-setup.sh"

echo "Installation complete! Please restart your computer."
