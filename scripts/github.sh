#!/bin/bash

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI not found. Installing via Homebrew..."
    brew install gh
fi

# Check if SSH key already exists
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo "Setting up new SSH key for GitHub..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate new SSH key with provided email
    read -p "Enter your GitHub email: " github_email
    ssh-keygen -t ed25519 -C "$github_email" -f "$HOME/.ssh/id_ed25519" -N ""
    
    # Start ssh-agent and add key
    eval "$(ssh-agent -s)"
    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
    
    # Add config file to store keys in keychain
    if [ ! -f "$HOME/.ssh/config" ]; then
        cat > "$HOME/.ssh/config" << EOL
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOL
    fi
fi

# Login to GitHub and add SSH key
echo "Authenticating with GitHub..."
gh auth login -s admin:public_key -w

# Add SSH key to GitHub if it exists and isn't already added
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo "Adding SSH key to GitHub..."
    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" -t "$(scutil --get ComputerName) (Added on $(date '+%Y-%m-%d'))"
fi

echo "GitHub setup complete!"