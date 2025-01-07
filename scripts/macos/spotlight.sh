#!/bin/bash

# Read the JSON file and replace $HOME with actual home directory
config=$(cat .config/.macos/spotlight.json | sed "s|\$HOME|$HOME|g")

# Ensure Applications are indexed
echo "Enabling Spotlight indexing for Applications..."
sudo mdutil -i on /Applications >/dev/null 2>&1
sudo mdutil -i on /System/Applications >/dev/null 2>&1

# Create arrays for different types of paths
declare -a standard_paths=()
declare -a pattern_paths=()

# Sort paths into appropriate arrays
while read -r location; do
    # Skip if location is empty
    [ -z "$location" ] && continue
    
    if [[ "$location" == *"**"* ]]; then
        # Strip ** from pattern and add to pattern paths
        clean_pattern=${location//\*\*/}
        pattern_paths+=("$clean_pattern")
    else
        standard_paths+=("$location")
    fi
done < <(echo "$config" | jq -r '.excluded_locations[]')

# Create a temporary plist for privacy settings
privacy_plist=$(mktemp)

# Write plist header
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>pathListArray</key>
    <array>' > "$privacy_plist"

# Define required paths that should exist
required_paths=(
    "$HOME/Library"
    "$HOME/Downloads"
)

# Handle standard paths
for location in "${standard_paths[@]}"; do
    # Skip system paths and non-existent paths
    if [[ "$location" == "/System"* ]] || [[ "$location" == "/private"* ]]; then
        echo "Skipping system path: $location"
        continue
    fi

    # Get the real path by resolving symlinks
    real_path=$(readlink -f "$location" 2>/dev/null || echo "$location")
    
    # Check if path exists
    if [ ! -e "$location" ] && [ ! -e "$real_path" ]; then
        # Only warn about required paths
        if [[ " ${required_paths[@]} " =~ " ${location} " ]]; then
            echo "Warning: Required path does not exist: $location"
        fi
        continue
    fi

    echo "Adding to Spotlight privacy list: $location"
    # Add path to privacy plist
    echo "        <string>$real_path</string>" >> "$privacy_plist"
done

# Write plist footer
echo '    </array>
</dict>
</plist>' >> "$privacy_plist"

# Import privacy settings
defaults import com.apple.Spotlight.PrivacyPreferences "$privacy_plist"

# Clean up privacy plist
rm "$privacy_plist"

# Handle pattern paths through Spotlight preferences
if [ ${#pattern_paths[@]} -gt 0 ]; then
    echo "Adding pattern-based exclusions to Spotlight preferences..."
    
    # Create temporary file for plist
    tmp_plist=$(mktemp)
    
    # Write plist header
    echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CustomSearchScopes</key>
    <array>' > "$tmp_plist"
    
    # Add each pattern
    for pattern in "${pattern_paths[@]}"; do
        echo "        <dict>
            <key>path</key>
            <string>$pattern</string>
            <key>enabled</key>
            <true/>
        </dict>" >> "$tmp_plist"
    done
    
    # Write plist footer
    echo '    </array>
</dict>
</plist>' >> "$tmp_plist"
    
    # Import the plist
    defaults import com.apple.Spotlight "$tmp_plist"
    
    # Clean up
    rm "$tmp_plist"
fi

# Configure Spotlight search categories
echo "Configuring Spotlight search categories..."
# First clear existing items
defaults delete com.apple.Spotlight orderedItems 2>/dev/null

# Create temporary file for plist
tmp_plist=$(mktemp)

# Write plist header
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>orderedItems</key>
    <array>' > "$tmp_plist"

# Add each category
while IFS="=" read -r category enabled; do
    if [ ! -z "$category" ]; then
        echo "        <dict>
            <key>enabled</key>
            <integer>$([[ "$enabled" == "true" ]] && echo "1" || echo "0")</integer>
            <key>name</key>
            <string>$category</string>
        </dict>" >> "$tmp_plist"
    fi
done < <(echo "$config" | jq -r '.search_categories | to_entries | .[] | "\(.key)=\(.value)"')

# Write plist footer
echo '    </array>
</dict>
</plist>' >> "$tmp_plist"

# Import the plist
defaults import com.apple.Spotlight "$tmp_plist"

# Clean up
rm "$tmp_plist"

echo "Restarting Spotlight..."
# Kill and restart Spotlight
killall mds >/dev/null 2>&1

# Re-enable indexing for root volume
sudo mdutil -i on / >/dev/null
sudo mdutil -E / >/dev/null

echo "Spotlight configuration complete"
