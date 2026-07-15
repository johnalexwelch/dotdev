#!/usr/bin/env bash

# Base directories
CONFIG_DIR="$HOME/.config"
DOTFILES_CONFIG="${DOTFILES:?DOTFILES must be set}/.config"

# Create base config directory
echo "Creating config directory structure..."
mkdir -p "$CONFIG_DIR"

# Define config directories to create.
# Real dirs here force Stow to create per-item symlinks instead of tree-folding
# a whole subtree, so agent-specific files can coexist with shared source.
config_dirs=(
    "agents"
    "arc"
    "cursor"
    "gh-dash"
    "ghostty"
    "herdr"
    "git"
    "hunk"
    "lazygit"
    "macos"
    "mcp"
    "nvim"
    "ollama"
    "openwiki"
    "raycast"
    "streamdeck"
    "starship"
    "zsh"
)

# Create config directories in both locations
for dir in "${config_dirs[@]}"; do
    # Create in home directory
    mkdir -p "$CONFIG_DIR/$dir"
    echo "Created $CONFIG_DIR/$dir"

    # Create in dotfiles directory
    mkdir -p "$DOTFILES_CONFIG/$dir"
    echo "Created $DOTFILES_CONFIG/$dir"
done

# Create subdirectories for specific configs
mkdir -p "$DOTFILES_CONFIG/zsh/conf.d"

echo "Config directory structure created"

echo "Configuration setup complete"
# ponytail: stow handled by install.sh over full dotfiles/ — no partial stow here
