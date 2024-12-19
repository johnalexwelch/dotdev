#!/usr/bin/env bash

echo "Configuring General UI/UX settings..."

# Set computer name (as done via System Preferences → Sharing)
sudo scutil --set ComputerName "awelch"
sudo scutil --set HostName "awelch"
sudo scutil --set LocalHostName "awelch"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "awelch"

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false 