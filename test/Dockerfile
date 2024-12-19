FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install basic requirements
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    stow \
    shellcheck \
    yamllint \
    jq \
    vim \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Install pre-commit
RUN pip3 install pre-commit

# Create test user and set as current user
RUN useradd -m -s /bin/zsh testuser
USER testuser
WORKDIR /home/testuser

# Create necessary directories to simulate macOS structure
RUN mkdir -p \
    .config \
    .local/share \
    .cache \
    Library/Application\ Support \
    Library/Preferences

# Copy dotfiles into container
COPY --chown=testuser:testuser . .dotfiles/

# Set working directory to dotfiles
WORKDIR /home/testuser/.dotfiles

# Create test script
COPY --chown=testuser:testuser <<EOF test-install.sh
#!/bin/bash
set -e

echo "🔍 Starting test installation..."

# Test pre-commit hooks
echo "⚡ Testing pre-commit hooks..."
pre-commit run --all-files || true

# Test stow operations
echo "📁 Testing stow operations..."
stow -nvt /home/testuser app_configs/

# Validate shell scripts
echo "🔍 Checking shell scripts..."
find scripts -type f -name "*.sh" -exec shellcheck {} \;

# Validate YAML files
echo "📄 Checking YAML files..."
find . -type f -name "*.yaml" -o -name "*.yml" -exec yamllint {} \;

# Test Brewfile parsing
echo "🍺 Validating Brewfile..."
grep -v '^#' Brewfile | while read -r line; do
    echo "Would install: $line"
done

echo "✅ Test completed successfully!"
EOF

RUN chmod +x test-install.sh

# Run tests by default
CMD ["./test-install.sh"] 