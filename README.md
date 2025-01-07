# 🏠 Dotfiles

Personal dotfiles and system configuration for macOS development environment, managed with GNU Stow.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/johnalexwelch/dotdev.git ~/.dotfiles

# Run the installation script
cd ~/.dotfiles
./install.sh

# Install pre-commit hooks
pre-commit install
```

## 📁 Structure

```tree
.dotfiles/
├── .config/          # Application configurations - XDG Base Directory configs
│   ├── .arc/         # Arc browser settings
│   ├── .cursor/      # Cursor editor config
│   ├── .macos/       # macOS specific settings
│   ├── .ollama/      # Ollama AI settings
│   ├── .raycast/     # Raycast finder settings
│   ├── .starship/    # Starship terminal customized settings
│   ├── .streamdeck/  # Elgato streamdeck settings
│   ├── .warp/        # Warp terminal settings
│   ├── .zsh/         # Shell configuration
│   └── git/          # Git configuration
├── scripts/          # Setup and configuration scripts
├── docs/             # Documentation
├── .pre-commit-config.yaml  # Pre-commit hook configuration
├── .gitleaks.toml    # Gitleaks security scanner config
├── .secrets.baseline # Detect-secrets baseline
└── Brewfile          # Package dependencies
```

## 🔒 Security Features

- 🔍 Comprehensive secret scanning
- 🔐 Git security hooks
- 🛡️ Environment safety checks
- ✨ Code quality automation

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| [📥 Installation](docs/INSTALLATION.md) | Detailed setup instructions |
| [⚙️ Applications](docs/APPLICATIONS.md) | App-specific settings |
| [🍎 macOS](docs/MACOS.md) | System preferences and configurations |
| [📋 Workflows](docs/WORKFLOWS.md) | Development workflow automation |
| [🐚 Shell](docs/SHELL.md) | ZSH setup and customization |

## 🛠️ Core Components

### 🖥️ Development Environment

| Tool | Purpose | Documentation |
|------|---------|---------------|
| 📟 Warp | Modern terminal | [Docs](https://docs.warp.dev) |
| 🤖 Cursor | AI-powered editor | [Guide](https://cursor.sh/docs) |
| 🌐 Arc | Browser with spaces | [Help](https://arc.net/help) |
| 🎮 Stream Deck | Workflow automation | [Docs](https://developer.elgato.com/documentation/) |

### 🔧 CLI Tools

| Tool | Purpose | Usage |
|------|---------|-------|
| 🔍 fzf | Fuzzy finder | `Ctrl+R` for history |
| 📂 eza | Modern ls | `l` for detailed view |
| 🔎 ripgrep | Fast search | `rg pattern` |
| 🌳 tree | Directory listing | `tree` for structure |

### 🚀 Productivity

| Tool | Purpose | Key Feature |
|------|---------|-------------|
| 🔍 Raycast | Quick launcher | Custom scripts |
| ⭐ Starship | Shell prompt | Git integration |
| 🤖 Ollama | Local AI | Code assistance |

## 🔄 Maintenance

### 📝 Regular Updates

```bash
# Update all tools and configurations
./scripts/update.sh

# Run tests to verify
./scripts/test.sh
```

### 🧹 Cleanup

```bash
# Clean temporary files
./scripts/cleanup.sh

# Reset configurations
./scripts/reset.sh
```

## 📄 License

MIT License - see [LICENSE](LICENSE)

## TODO

- [ ] Configure global git parameters
    ```bash
      git config --global user.email "you@example.com"
      git config --global user.name "Your Name"
    ```
- [ ] Add a script to install all the apps
- [ ] Add a script to install all the apps
- [ ] Add a script to install all the apps
