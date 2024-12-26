#!/bin/bash

# Load spotlight configuration
for location in $(jq -r '.excluded_locations[]' ~/.dotdev/.config/.macos/spotlight.json); do
    sudo mdutil -i off "$location"
    sudo rm -rf "/${location}/.Spotlight-V100"
done

# Kill and restart Spotlight
killall mds >/dev/null 2>&1
sudo mdutil -i on / >/dev/null
sudo mdutil -E / >/dev/null
