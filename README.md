# 🏠 Dotfiles

Personal dotfiles and system configuration for macOS development environment, managed with GNU Stow.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/johnalexwelch/dotdev.git ~/dotdev

# Run the installation script
cd ~/dotdev
./install.sh

# Install pre-commit hooks
pre-commit install
```

## 📁 Structure

```tree
dotdev/
├── dotfiles/                 # stowed with GNU Stow → $HOME
│   ├── .zshrc .gitconfig .gitignore_global
│   ├── .claude/              # Claude-specific: hooks/, settings.json
│   │   ├── skills → ../.config/agents/skills   # symlink to shared source
│   │   └── docs   → ../.config/agents/docs
│   ├── .pi/agent/            # pi-specific: settings.json
│   └── .config/              # XDG configs
│       ├── agents/           # AGENT-AGNOSTIC shared source
│       │   ├── skills/        # 90+ skills — single source for all agents
│       │   └── docs/          # shared agent reference
│       ├── arc/ cursor/ ghostty/ git/ gh-dash/ herdr/
│       ├── lazygit/ mcp/ nvim/ ollama/ raycast/
│       ├── starship/ streamdeck/ macos/ zsh/
├── scripts/          # Setup and configuration scripts
├── docs/             # Documentation
├── test/             # Bash test suite (run-tests.sh)
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
| [🐚 Shell](docs/SHELL.md) | ZSH setup and customization |

## 🛠️ Core Components

### 🖥️ Development Environment

| Tool | Purpose | Documentation |
|------|---------|---------------|
| 📟 Ghostty | Modern terminal | [Docs](https://ghostty.org/docs) |
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

## 🛠️ Standalone Scripts

These live in `scripts/` but are **not called by `install.sh`** — run manually as needed:

| Script | Purpose | Usage |
|--------|---------|-------|
| `arc.sh` | Backup/restore Arc browser extensions & settings | `./scripts/arc.sh backup` / `restore` |
| `hdev.sh` | Launch herdr workspace layout for a project | `hdev [project_dir] [--monitor\|--minimal]` |
| `hlog.sh` | Snapshot active herdr agent panes to daily log | `hlog` / `hlog --view` / `hlog --search` |
| `security-init.sh` | Init detect-secrets + git-secrets in a **repo** | Run inside each new repo, not at machine setup |

## 🔄 Maintenance

### 📝 Regular Updates

```bash
# Run tests to verify
./test/run-tests.sh
```

## 📄 License

MIT License - see [LICENSE](LICENSE)

## TODO

- [ ] Configure global git parameters after install (`git config --global user.email / user.name`)
