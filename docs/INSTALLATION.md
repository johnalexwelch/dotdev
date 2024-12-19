# Installation Guide

## Prerequisites

- macOS 12.0 or later
- Command Line Tools for Xcode
- Administrator privileges
- Python 3.8 or later
- pre-commit

## Step-by-Step Installation

1. **Install Command Line Tools**

```bash
xcode-select --install
```

2. **Clone Repository**

```bash
git clone https://github.com/johnalexwelch/dotdev.git ~/.dotfiles
cd ~/.dotfiles
```

3. **Install pre-commit hooks**

```bash
# Install pre-commit
brew install pre-commit

# Install the pre-commit hooks
pre-commit install
```

4. **Run Installation Script**

```bash
./install.sh
```

4. **Post-Installation**

- Configure GitHub authentication
- Set up SSH keys
- Customize application settings

## Manual Steps

Some configurations require manual intervention:

1. **System Preferences**
   - Enable Full Disk Access for Terminal
   - Configure Touch ID for sudo
   - Set up Screen Saver

2. **Application Setup**
   - Sign in to Arc browser
   - Configure Cursor editor
   - Set up Stream Deck

## Troubleshooting

Common issues and solutions:

1. **Homebrew Installation Fails**

   ```bash
   # Reset Homebrew
   rm -rf /opt/homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Stow Conflicts**

   ```bash
   # Remove existing config
   rm ~/.config/conflicting_file
   # Retry stow
   stow -R app_configs
   ```
