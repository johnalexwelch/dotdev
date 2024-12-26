#!/usr/bin/env bash
# ~/.macos

# Exit on error
set -e

echo "🚀 Starting Mac development environment setup..."

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'
# Ask for sudo upfront
sudo -v

# Keep sudo alive
while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &

# Install Xcode Command Line Tools
if ! command -v xcode-select &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
fi

# Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Source all configuration files
source "${BASH_SOURCE%/*}/dock.sh"
source "${BASH_SOURCE%/*}/finder.sh"
source "${BASH_SOURCE%/*}/general.sh"
source "${BASH_SOURCE%/*}/input_devices.sh"
source "${BASH_SOURCE%/*}/screen.sh"
source "${BASH_SOURCE%/*}/spotlight.sh"
source "${BASH_SOURCE%/*}/terminal.sh"
