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
│   ├── test.sh       # Script to test installation
│   └── test-local.sh # Script to run local tests
├── docs/             # Documentation
├── .pre-commit-config.yaml  # Pre-commit hook configuration
├── .gitleaks.toml    # Gitleaks security scanner config
├── .secrets.baseline # Detect-secrets baseline
└── Brewfile          # Package dependencies
```

## 🔒 Security Features

### Pre-commit Hooks

The repository includes comprehensive pre-commit hooks for security and code quality:

- **🔍 Secrets Detection**:

  - Gitleaks
  - Detect-secrets
  - Git-secrets (AWS credentials)
  - Talisman

- **🔐 Certificate & Key Protection**:

  - Private keys
  - Certificates
  - SSL/TLS keys
  - X509 certificates

- **🛡️ Environment Safety**:

  - `.env` files
  - AWS credentials
  - API keys
  - Other sensitive environment variables

- **✨ Code Quality**:
  - Shell script validation (shellcheck)
  - YAML/JSON validation
  - Markdown linting
  - File formatting

### Setup Security Tools

```bash
# Install pre-commit hooks
pre-commit install

# Generate initial secrets baseline
detect-secrets scan > .secrets.baseline
```

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed setup instructions
- [Application Configs](docs/APPLICATIONS.md) - Application-specific settings
- [macOS Settings](docs/MACOS.md) - System preferences and configurations
- [Warp Workflows](docs/WORKFLOWS.md) - Terminal workflow automation
- [Shell Configuration](docs/SHELL.md) - ZSH setup and customization

## 🛠️ Components

### System Configuration

- 🖥️ Automated macOS preferences setup
- 🍺 Application installation via Homebrew
- ⚙️ Development environment configuration
- 🔑 SSH and Git setup

### Applications

- 📟 Terminal: Warp with custom workflows
- 📝 Editor: Cursor with extensions
- 🌐 Browser: Arc with spaces configuration
- 🎮 Stream Deck profiles for development

### Development Tools

## 🛠️ Development Tools

### Core Tools

| Tool        | Purpose                   | Documentation                                       |
| ----------- | ------------------------- | --------------------------------------------------- |
| 🍺 Homebrew | Package manager for macOS | [Docs](https://docs.brew.sh)                        |
| 📦 GNU Stow | Symlink farm manager      | [Manual](https://www.gnu.org/software/stow/manual/) |
| 🐚 Zsh      | Modern shell              | [Wiki](https://zsh.sourceforge.io/Doc/)             |
| ⭐ Starship | Cross-shell prompt        | [Docs](https://starship.rs/guide/)                  |

### Development Environment

| Tool       | Purpose              | Documentation                             |
| ---------- | -------------------- | ----------------------------------------- |
| 🐍 Python  | Programming language | [Docs](https://docs.python.org)           |
| 🐳 Docker  | Containerization     | [Docs](https://docs.docker.com)           |
| ☁️ AWS CLI | Cloud management     | [User Guide](https://aws.amazon.com/cli/) |
| 🌳 Git     | Version control      | [Docs](https://git-scm.com/doc)           |

### Applications

| Application    | Purpose                 | Documentation                                       |
| -------------- | ----------------------- | --------------------------------------------------- |
| 📟 Warp        | Modern terminal         | [Docs](https://docs.warp.dev)                       |
| 📝 Cursor      | AI-powered editor       | [Docs](https://cursor.sh/docs)                      |
| 🌐 Arc         | Browser with workspaces | [Help](https://arc.net/help)                        |
| 🎮 Stream Deck | Workflow automation     | [Docs](https://developer.elgato.com/documentation/) |
| 🔍 Raycast     | Productivity launcher   | [Manual](https://manual.raycast.com)                |

### Security Tools

| Tool              | Purpose                 | Documentation                                    |
| ----------------- | ----------------------- | ------------------------------------------------ |
| 🔒 pre-commit     | Git hooks framework     | [Docs](https://pre-commit.com)                   |
| 🕵️ Gitleaks       | Secret scanning         | [Docs](https://github.com/zricethezav/gitleaks)  |
| 🛡️ detect-secrets | Secret detection        | [Docs](https://github.com/Yelp/detect-secrets)   |
| 🔐 git-secrets    | AWS credential scanning | [Docs](https://github.com/awslabs/git-secrets)   |
| 🚨 Talisman       | Security validation     | [Docs](https://github.com/thoughtworks/talisman) |

### Shell Utilities

| Tool       | Purpose               | Documentation                                                       |
| ---------- | --------------------- | ------------------------------------------------------------------- |
| 🔍 fzf     | Fuzzy finder          | [Wiki](https://github.com/junegunn/fzf/wiki)                        |
| 📂 exa     | Modern ls replacement | [Docs](https://the.exa.website)                                     |
| 🔎 ripgrep | Fast searcher         | [Guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) |
| 🌳 tree    | Directory listing     | [Manual](http://mama.indstate.edu/users/ice/tree/tree.1.html)       |

## 📄 License

MIT License - see [LICENSE](LICENSE)
