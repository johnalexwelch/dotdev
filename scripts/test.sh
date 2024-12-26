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

# Test shell formatting tools
if ! command -v shfmt &>/dev/null; then
    echo "❌ shfmt not found"
    exit 1
else
    echo "✅ shfmt installed"
fi

# Test security tools
echo "🔒 Testing security configurations..."

# Check detect-secrets
if ! command -v detect-secrets &>/dev/null; then
    echo "❌ detect-secrets not found"
    exit 1
else
    echo "✅ detect-secrets installed"
fi

# Check git-secrets
if ! command -v git-secrets &>/dev/null; then
    echo "❌ git-secrets not found"
    exit 1
else
    echo "✅ git-secrets installed"
fi

# Check gitleaks
if ! command -v gitleaks &>/dev/null; then
    echo "❌ gitleaks not found"
    exit 1
else
    echo "✅ gitleaks installed"
fi

# Verify baseline files exist
if [ ! -f .secrets.baseline ]; then
    echo "❌ .secrets.baseline missing"
    exit 1
else
    echo "✅ .secrets.baseline exists"
fi

# Test YAML formatting tools
if ! command -v yamlfmt &>/dev/null; then
    echo "❌ yamlfmt not found"
    exit 1
else
    echo "✅ yamlfmt installed"
fi

echo "✅ Test completed successfully!"
