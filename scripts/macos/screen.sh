#!/usr/bin/env bash

echo "Configuring Screen settings..."

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots in PNG format
defaults write com.apple.screencapture type -string "png"

# Save screenshots to the Desktop/Screenshots folder
mkdir -p "${HOME}/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"

# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# Set keyboard shortcut for clipboard screenshots
# Create the directory if it doesn't exist
mkdir -p ~/Library/KeyBindings

# Create or update the custom key bindings file
cat >~/Library/KeyBindings/DefaultKeyBinding.dict <<EOL
{
    "@\$F5" = (selectAll:, copy:);  # CMD + SHIFT + F5
}
EOL

# Configure screenshot to clipboard shortcut
defaults write com.apple.screencapture "keyboard-screenshot-clipboard" -string "@\$F5"

# Restart SystemUIServer to apply changes
killall SystemUIServer
