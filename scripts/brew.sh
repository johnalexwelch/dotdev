#!/bin/bash

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Update Homebrew recipes
echo "Updating Homebrew..."
brew update

# Install all dependencies from Brewfile
echo "Installing packages from Brewfile..."
brew bundle --file="$DOTFILES/Brewfile"

# Cleanup old versions
echo "Cleaning up Homebrew..."
brew cleanup

echo "Homebrew setup complete!" 