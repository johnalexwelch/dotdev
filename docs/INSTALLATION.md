# 🛠️ Installation Guide

This guide walks you through setting up your development environment using these dotfiles.

## 📋 Prerequisites

Before you begin, ensure you have:

```bash
# Install Command Line Tools
xcode-select --install
```

## 📥 Installation Steps

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/johnalexwelch/dotdev.git ~/.dotfiles
cd ~/.dotfiles
```

### 2️⃣ Run Installation Script

The installation script will:

- 🍺 Install Homebrew if not present
- 📦 Install GNU Stow and other dependencies
- 🔒 Install pre-commit and security tools
- ⚙️ Set up configuration files
- 🛡️ Configure security baselines

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run the installation script
./install.sh
```

### 3️⃣ Verify Installation

```bash
./scripts/test-local.sh
```

## 🔧 Configuration Components

### Stow Packages

The following configurations will be managed by GNU Stow:

- 📁 `.config/` - XDG Base Directory configurations
- 🌳 `git/` - Git configuration
- 🐚 `.zsh/` - Shell configuration

### Application Configurations

The installation includes settings for:

- 🌐 Arc browser
- 📝 Cursor editor
- 🔍 Raycast
- ⭐ Starship prompt
- 🎮 Stream Deck
- 📟 Warp terminal

### Development Tools

The following development tools will be installed via Homebrew:

- 🐍 Python development tools
- ☁️ AWS CLI
- 🐳 Docker
- 🌳 Git and related tools
- 📟 Terminal utilities

## ✨ Post-Installation

### 🐚 Shell Configuration

```bash
# Set Zsh as default shell
chsh -s $(which zsh)
```

### 🌳 Git Configuration

```bash
# Configure git user
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 🔒 Security Verification

```bash
# Test pre-commit hooks
pre-commit run --all-files

# Verify security scanning
gitleaks detect --config .gitleaks.toml
```

## ❗ Troubleshooting

### Common Issues

1. **📦 Stow Conflicts**

```bash
# Remove existing config files
rm -rf ~/.config/existing-config

# Retry stow
stow -nvt ~ .config/
```

2. **🔑 Permission Issues**

```bash
# Fix script permissions
chmod +x scripts/*.sh
```

3. **🔄 Pre-commit Hook Failures**

```bash
# Update pre-commit hooks
pre-commit autoupdate

# Clean pre-commit cache
pre-commit clean
```

### 🚨 Security Alerts

If you receive security alerts:

1. Check the `.secrets.baseline` file
2. Review `.gitleaks.toml` configuration
3. Verify no sensitive files are tracked:

```bash
git ls-files | grep -i secret
```

## 🔄 Maintenance

### Regular Updates

```bash
# Update Homebrew packages
brew update && brew upgrade

# Update pre-commit hooks
pre-commit autoupdate

# Update security baselines
detect-secrets scan > .secrets.baseline
```

### 💾 Backup

Before making significant changes:

```bash
# Create backup directory
mkdir -p ~/.dotfiles_backup

# Backup current configs
cp -r ~/.config ~/.dotfiles_backup/
```

## 💁 Support

For issues or questions:

1. Check the [README.md](../README.md)
2. Review [existing issues](https://github.com/johnalexwelch/dotdev/issues)
3. Open a new issue if needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
