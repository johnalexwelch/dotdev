#!/bin/bash

# Function to remove quarantine attributes from apps
remove_quarantine() {
    local app_dir="/Applications"
    echo "Removing quarantine attributes from applications..."
    
    # Remove quarantine attribute from all apps in /Applications
    find "$app_dir" -name "*.app" -print0 | while IFS= read -r -d '' app; do
        echo "Processing: $app"
        xattr -d com.apple.quarantine "$app" 2>/dev/null || true
    done
    
    # Also check user applications directory
    local user_app_dir="$HOME/Applications"
    if [ -d "$user_app_dir" ]; then
        find "$user_app_dir" -name "*.app" -print0 | while IFS= read -r -d '' app; do
            echo "Processing: $app"
            xattr -d com.apple.quarantine "$app" 2>/dev/null || true
        done
    fi
}

# Function to grant local network access
grant_local_network_access() {
    local bundle_id="$1"
    local app_name="$2"
    
    echo "Granting local network access to $app_name..."
    
    # Use tccutil to grant local network access
    sudo tccutil reset LocalNetworking
    sudo tccutil add LocalNetworking "$bundle_id"
}

# Function to set default browser
set_default_browser() {
    local browser="$1"
    
    # Install defaultbrowser if not already installed
    if ! command -v defaultbrowser >/dev/null 2>&1; then
        echo "Installing defaultbrowser CLI tool..."
        brew install defaultbrowser
    fi
    
    echo "Setting $browser as default browser..."
    defaultbrowser "$browser"
    
    # Also register Arc's URL schemes
    defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{
        LSHandlerRole = "all";
        LSHandlerURLScheme = "http";
        LSHandlerPreferredVersions = { LSHandlerRoleAll = "-"; };
        LSHandlerRoleAll = "company.thebrowser.Browser";
    }'
    
    defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{
        LSHandlerRole = "all";
        LSHandlerURLScheme = "https";
        LSHandlerPreferredVersions = { LSHandlerRoleAll = "-"; };
        LSHandlerRoleAll = "company.thebrowser.Browser";
    }'
}

# Remove quarantine attributes
remove_quarantine

# Set Arc as default browser
set_default_browser "arc"

# Restart relevant services
echo "Restarting relevant services..."
killall -HUP cfprefsd
killall Finder

echo "Permissions configuration complete" 