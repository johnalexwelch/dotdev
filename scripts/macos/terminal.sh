#!/usr/bin/env bash

echo "Configuring Terminal settings..."

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Starship prompt if not already installed
if ! command -v starship &>/dev/null; then
    echo "Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh
fi

# Create .zshrc if it doesn't exist
if [ ! -f "$HOME/.zshrc" ]; then
    touch "$HOME/.zshrc"
fi

# Add Homebrew's zsh to /etc/shells if not already present
BREW_ZSH="/opt/homebrew/bin/zsh"
if ! grep -q "$BREW_ZSH" /etc/shells; then
    echo "Adding Homebrew's zsh to /etc/shells..."
    echo "$BREW_ZSH" | sudo tee -a /etc/shells
fi

# Stow ZSH configuration
cd "$DOTFILES" && stow -v -R -t "$HOME" .config/

# Install zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# Install zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Configure Starship
mkdir -p ~/.config

# Set zsh as default shell
if [ "$SHELL" != "$BREW_ZSH" ]; then
    chsh -s "$BREW_ZSH"
fi
