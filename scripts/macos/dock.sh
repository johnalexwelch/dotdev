#!/usr/bin/env bash

echo "Configuring Dock settings..."

# Clear existing dock items
defaults write com.apple.dock persistent-apps -array

# Add applications to dock in desired order
apps=(
    # Communication & Planning
    "/Applications/Slack.app"
    "/Applications/Notion.app"
    "/Applications/Notion Calendar.app"
    "/Applications/Sunsama.app"
    "spacer"
    # Browsers & AI
    "/Applications/Arc.app"
    "/Applications/Cursor.app"
    "/Applications/Claude.app"
    "spacer"
    # Media
    "/Applications/Spotify.app"
)

for app in "${apps[@]}"; do
    if [ "$app" = "spacer" ]; then
        defaults write com.apple.dock persistent-apps -array-add '{
            "tile-data" = {};
            "tile-type" = "spacer-tile";
        }'
    elif [ -d "$app" ]; then
        defaults write com.apple.dock persistent-apps -array-add "<dict>
            <key>tile-data</key>
            <dict>
                <key>file-data</key>
                <dict>
                    <key>_CFURLString</key>
                    <string>file://${app}/</string>
                    <key>_CFURLStringType</key>
                    <integer>15</integer>
                </dict>
                <key>file-type</key>
                <integer>41</integer>
                <key>bundle-identifier</key>
                <string>$(defaults read "${app}/Contents/Info" CFBundleIdentifier)</string>
                <key>dock-extra</key>
                <false/>
            </dict>
            <key>tile-type</key>
            <string>file-tile</string>
        </dict>"
    else
        echo "Warning: ${app} not found"
    fi
done

# Other dock settings
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock autohide -bool false
defaults write com.apple.dock tilesize -int 70

# Restart dock to apply changes
killall Dock
