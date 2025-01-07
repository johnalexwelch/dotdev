#!/bin/bash

# Define paths
ARC_EXTENSION_PATH="$HOME/Library/Application Support/Arc/User Data/Default/Extensions"
ARC_SETTINGS_PATH="$HOME/Library/Application Support/Arc/User Data/Default"
BACKUP_PATH="$HOME/.config/arc/extensions"
SETTINGS_BACKUP_PATH="$HOME/.config/arc"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_PATH"

# Function to backup settings
backup_settings() {
    echo "Backing up Arc settings..."
    
    if [ -f "$ARC_SETTINGS_PATH/Preferences" ]; then
        cp "$ARC_SETTINGS_PATH/Preferences" "$SETTINGS_BACKUP_PATH/settings.json"
        echo "Settings backup completed!"
    else
        echo "Warning: No settings file found at $ARC_SETTINGS_PATH/Preferences"
    fi
}

# Function to restore settings
restore_settings() {
    echo "Restoring Arc settings..."
    
    if [ -f "$SETTINGS_BACKUP_PATH/settings.json" ]; then
        cp "$SETTINGS_BACKUP_PATH/settings.json" "$ARC_SETTINGS_PATH/Preferences"
        echo "Settings restoration completed!"
    else
        echo "Warning: No settings backup found at $SETTINGS_BACKUP_PATH/settings.json"
    fi
}

# Function to backup extensions
backup_extensions() {
    echo "Backing up Arc extensions..."
    
    # Create manifest file
    manifest_file="$BACKUP_PATH/manifest.txt"
    : > "$manifest_file"  # Clear existing manifest
    
    # Copy extensions and create manifest
    for ext in "$ARC_EXTENSION_PATH"/*; do
        if [ -d "$ext" ]; then
            ext_name=$(basename "$ext")
            ext_version=$(ls "$ext" | sort -V | tail -n1)
            
            # Copy extension files
            mkdir -p "$BACKUP_PATH/$ext_name"
            cp -R "$ext/$ext_version"/* "$BACKUP_PATH/$ext_name/"
            
            # Add to manifest
            echo "$ext_name:$ext_version" >> "$manifest_file"
        fi
    done
    
    echo "Backup completed! Extensions saved to $BACKUP_PATH"
}

# Function to restore extensions
restore_extensions() {
    echo "Restoring Arc extensions..."
    manifest_file="$BACKUP_PATH/manifest.txt"
    
    if [ ! -f "$manifest_file" ]; then
        echo "Error: Manifest file not found at $manifest_file"
        exit 1
    fi
    
    # Make sure Arc is closed
    if pgrep -x "Arc" > /dev/null; then
        echo "Please close Arc browser before restoring extensions"
        exit 1
    fi
    
    # Read manifest and restore extensions
    while IFS=: read -r ext_name ext_version; do
        echo "Restoring extension: $ext_name"
        mkdir -p "$ARC_EXTENSION_PATH/$ext_name/$ext_version"
        cp -R "$BACKUP_PATH/$ext_name/"* "$ARC_EXTENSION_PATH/$ext_name/$ext_version/"
    done < "$manifest_file"
    
    echo "Restoration completed! Please restart Arc browser"
}

# Parse command line arguments
case "$1" in
    "backup")
        backup_extensions
        backup_settings
        ;;
    "restore")
        restore_extensions
        restore_settings
        ;;
    "backup-settings")
        backup_settings
        ;;
    "restore-settings")
        restore_settings
        ;;
    *)
        echo "Usage: $0 {backup|restore|backup-settings|restore-settings}"
        echo "  backup          - Backup Arc extensions and settings"
        echo "  restore         - Restore Arc extensions and settings"
        echo "  backup-settings - Backup only Arc settings"
        echo "  restore-settings - Restore only Arc settings"
        exit 1
        ;;
esac