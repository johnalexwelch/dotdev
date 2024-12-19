# Dotfiles

Personal dotfiles and system configuration for macOS development environment, managed with GNU Stow.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/johnalexwelch/dotdev.git ~/.dotfiles

# Run the installation script
cd ~/.dotfiles
./install.sh
```

## 📁 Structure

```
.dotfiles/
├── app_configs/           # Application configurations
│   ├── .config/          # XDG Base Directory configs
│   │   ├── arc/         # Arc browser settings
│   │   ├── cursor/      # Cursor editor config
│   │   ├── git/         # Git configuration
│   │   ├── warp/        # Warp terminal settings
│   │   └── zsh/         # Shell configuration
│   └── .macos/          # macOS specific settings
├── scripts/              # Setup and configuration scripts
├── docs/                 # Documentation
└── Brewfile             # Package dependencies
```

## 📚 Documentation

- [Installation Guide](docs/INSTALLATION.md) - Detailed setup instructions
- [Application Configs](docs/APPLICATIONS.md) - Application-specific settings
- [macOS Settings](docs/MACOS.md) - System preferences and configurations
- [Warp Workflows](docs/WORKFLOWS.md) - Terminal workflow automation
- [Shell Configuration](docs/SHELL.md) - ZSH setup and customization

## 🛠️ Components

### System Configuration
- Automated macOS preferences setup
- Application installation via Homebrew
- Development environment configuration
- SSH and Git setup

### Applications
- Terminal: Warp with custom workflows
- Editor: Cursor with extensions
- Browser: Arc with spaces configuration
- Stream Deck profiles for development

### Development Tools
- Python environment management
- Git workflow optimization
- AWS CLI configuration
- Docker development setup

## 📝 License

MIT License - see [LICENSE](LICENSE)
