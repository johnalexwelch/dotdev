#!/bin/bash

# Set up test environment
TEST_DIR="$(mktemp -d)"
BACKUP_DIR="$(mktemp -d)"

echo "🔍 Testing installation in $TEST_DIR"
echo "📦 Backup directory: $BACKUP_DIR"

# Function to clean up test environment
cleanup() {
    echo "🧹 Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    rm -rf "$BACKUP_DIR"
}

# Set up trap to clean up on exit
trap cleanup EXIT

# Create test environment structure
mkdir -p "$TEST_DIR"/{.config,.local/share,.cache}

# Function to simulate commands without executing them
simulate_command() {
    echo "Would execute: $*"
}

# Override dangerous commands
alias rm="simulate_command rm"
alias mv="simulate_command mv"
alias ln="simulate_command ln"
alias brew="simulate_command brew"
alias defaults="simulate_command defaults"

# Test installation
echo "🚀 Starting test installation..."

# Test stow commands
echo "📁 Testing stow operations..."
stow -nvt "$TEST_DIR" app_configs/

# Test brew installation
echo "🍺 Testing Homebrew installation..."
grep -v '^#' Brewfile | while read -r line; do
    echo "Would install: $line"
done

# Test macOS defaults
echo "⚙️ Testing macOS defaults..."
for script in scripts/macos/*.sh; do
    echo "Would execute: $script"
    bash -n "$script" # Syntax check only
done

echo "✅ Test completed successfully!" 