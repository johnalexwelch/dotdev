#!/bin/bash

# Base directory
DOTFILES="$HOME/.dotdev"
# Create base directories
echo "Creating base directories..."
mkdir -p ~/dbtlabs ~/jarvis ~/projects

# Install Homebrew and packages
echo "Setting up Homebrew..."
bash "$DOTFILES/scripts/brew.sh"

# Setup GitHub SSH
echo "Setting up GitHub SSH..."
bash "$DOTFILES/scripts/github.sh"

# Create XDG config directory
mkdir -p "$HOME/.config"

# Create symbolic links from Library/Application Support to .config
echo "Setting up application config symlinks..."
mkdir -p "$HOME/Library/Application Support"
ln -sf "$HOME/.config/arc" "$HOME/Library/Application Support/Arc"
ln -sf "$HOME/.config/cursor" "$HOME/Library/Application Support/Cursor"
ln -sf "$HOME/.config/warp" "$HOME/Library/Application Support/Warp"
ln -sf "$HOME/.config/streamdeck" "$HOME/Library/Application Support/com.elgato.StreamDeck"

# Configure macOS settings
echo "Configuring macOS settings..."
bash "$DOTFILES/scripts/macos/defaults.sh"
bash "$DOTFILES/scripts/macos/finder.sh"
bash "$DOTFILES/scripts/macos/dock.sh"
bash "$DOTFILES/scripts/macos/spotlight.sh"
bash "$DOTFILES/scripts/macos/terminal.sh"

# Create symbolic links
cd "$DOTFILES" || exit
stow -v -R -t "$HOME" .config/

# Initialize security tools
echo "Setting up security tools..."
bash "$DOTFILES/scripts/security-init.sh"

# Make shellcheck-fix script executable
chmod +x scripts/shellcheck-fix.sh

echo "Setup complete!"
