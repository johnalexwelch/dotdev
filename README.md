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
├── .config/          # Application configurations - XDG Base Directory configs
│   ├── .arc/         # Arc browser settings
│   ├── .cursor/      # Cursor editor config
│   ├── .macos/       # macOS specific settings
│   ├── .ollama/      # Ollama AI settings
│   ├── .raycast/     # Raycast finder settings
│   ├── .starship/    # Starship terminal customized settings
│   ├── .streamdeck/  # Elgato stremdeck settings
│   ├── .warp/        # Warp terminal settings
│   ├── .zsh/         # Shell configuration
│   └── git/          # Git configuration
├── scripts/        # Setup and configuration scripts
├── docs/           # Documentation
└── install.sh      # Main setup script
└── Brewfile        # Package dependencies
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

### Testing
- **Test Scripts**: Use `scripts/test.sh` to simulate installation commands without executing them.
- **Local Test Suite**: Use `scripts/test-local.sh` to run a comprehensive test suite, including pre-commit hooks, stow operations, shell script validation, and Brewfile checks. Ensure that `stow` is installed before running this script.

## 📝 License

MIT License - see [LICENSE](LICENSE)
