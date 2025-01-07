#!/usr/bin/env bash

# Base directories
CONFIG_DIR="$HOME/.config"
DOTFILES_CONFIG="$DOTFILES/.config"

# Create base config directory
echo "Creating config directory structure..."
mkdir -p "$CONFIG_DIR"

# Define config directories to create
config_dirs=(
    "arc"
    "cursor"
    "git"
    "macos"
    "ollama"
    "streamdeck"
    "starship"
    "warp"
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

# Use stow to create symlinks
echo "Creating symlinks with stow..."
cd "$DOTFILES" || exit
stow -v -R -t "$HOME" .config/

echo "Configuration setup complete" 