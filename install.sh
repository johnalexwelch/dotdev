#!/bin/bash

# Base directory
DOTFILES="$HOME/.dotdev"

# Install Homebrew and packages
if [ -f "$DOTFILES/scripts/brew.sh" ]; then
    bash "$DOTFILES/scripts/brew.sh"
fi

# Create directory structure
bash "$DOTFILES/scripts/setup.sh"

# Configure macOS
bash "$DOTFILES/scripts/macos/defaults.sh"

# Create symlinks
stow -v -R -t "$HOME" config/

echo "Installation complete! Please restart your computer." 