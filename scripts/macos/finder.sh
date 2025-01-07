#!/usr/bin/env bash

echo "Configuring Finder settings..."

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Set new Finder windows to open in Home Directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles YES

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
chflags nohidden ~/Library

# Sidebar configuration
# Remove all default items
defaults write com.apple.sidebarlists systemitems -dict-add ShowEjectables -bool true
defaults write com.apple.sidebarlists systemitems -dict-add ShowRemovable -bool true
defaults write com.apple.sidebarlists systemitems -dict-add ShowServers -bool false
defaults write com.apple.sidebarlists systemitems -dict-add ShowHardDisks -bool true

# Add Home directory and Code directory to sidebar
mysidebar=(
    "file://${HOME}/ HOME"
    "file://${HOME}/Code/ CODE"
)

# # Clear existing favorites
# defaults write com.apple.sidebarlists favorites -dict-add items -array

# # Add new favorites
# for item in "${mysidebar[@]}"; do
#     IFS=' ' read -r path label <<<"$item"
#     defaults write com.apple.sidebarlists favorites -array-add "<dict>
#         <key>Name</key>
#         <string>${label}</string>
#         <key>URL</key>
#         <string>${path}</string>
#     </dict>"
# done

# Disable all shared items
# defaults write com.apple.sidebarlists networkbrowser -dict-add CustomListProperties -array
defaults write com.apple.sidebarlists networkbrowser -dict-add ShowBonjour -bool false
defaults write com.apple.sidebarlists networkbrowser -dict-add ShowConnectedServers -bool true
defaults write com.apple.sidebarlists networkbrowser -dict-add ShowNetworkDrives -bool true

# Show servers in sidebar
defaults write com.apple.sidebarlists systemitems -dict-add ShowServers -bool true

# Enable AFP and SMB browsing
defaults write com.apple.NetworkBrowser EnableAFP -bool true
defaults write com.apple.NetworkBrowser EnableSMB -bool true

# Restart finder
killall Finder
