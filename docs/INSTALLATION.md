# 🛠️ Installation Guide

This guide walks you through setting up your development environment using these dotfiles.

## 📋 Prerequisites

Before you begin, ensure you have:

| Tool | Purpose | Installation |
|------|---------|--------------|
| 🍎 Xcode CLI | Development tools | `xcode-select --install` |
| 🔑 SSH Key | GitHub access | [📝 Guide](https://docs.github.com/authentication/connecting-to-github-with-ssh) |
| 🎯 Git | Version control | Included in Xcode CLI |

## 📥 Installation Steps

### 1️⃣ Clone Repository

```bash
# Clone the repository
git clone https://github.com/johnalexwelch/dotdev.git ~/dotdev
cd ~/dotdev
```

### 2️⃣ Run Installation

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run installation
./install.sh
```

## 🔧 What Gets Installed

### 📦 Package Managers

| Tool | Purpose | Documentation |
|------|---------|---------------|
| 🍺 Homebrew | macOS package manager | [📚 Docs](https://docs.brew.sh) |
| 📦 npm | Node.js package manager | [📘 Docs](https://docs.npmjs.com) |
| 🐍 pip | Python package manager | [📗 Guide](https://pip.pypa.io) |

### 🛠️ Development Tools

| Category | Tools |
|----------|-------|
| 📝 Editors | Cursor, VSCode |
| 📟 Terminal | Warp, iTerm2 |
| 🐳 Containers | Docker, OrbStack |
| ☁️ Cloud | AWS CLI, gcloud |
| 🔨 Build Tools | gcc, make |

### 🔒 Security Tools

| Tool | Purpose | Documentation |
|------|---------|---------------|
| 🔍 detect-secrets | Secret scanning | [📚 Docs](https://github.com/Yelp/detect-secrets) |
| 🕵️ gitleaks | Git security scanner | [📘 Guide](https://github.com/zricethezav/gitleaks) |
| 🔐 git-secrets | AWS credential scanner | [📗 Docs](https://github.com/awslabs/git-secrets) |

## ✅ Post-Installation

### 🔍 Verify Installation

```bash
# Run tests
./test/run-tests.sh

# Check security baseline
./scripts/security-init.sh
```

### 🔧 Configure Git

```bash
# Set your Git credentials
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 🚨 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| 🔒 Permission denied | `chmod +x scripts/*.sh` |
| 📦 Homebrew fails | Run `xcode-select --install` |
| 🔗 Symlink conflicts | Remove existing config files |

## 🔄 Updates

### Regular Maintenance

```bash
# Update packages
brew update && brew upgrade

# Update dotfiles
git pull origin main
./install.sh
```
