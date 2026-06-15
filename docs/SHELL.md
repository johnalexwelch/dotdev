# 🐚 Shell Configuration

This guide details the shell configurations and customizations included in these dotfiles.

## 📦 Components

| Component | Purpose | Location |
|-----------|---------|----------|
| 🐚 ZSH | Main shell | `.zshrc` |
| ⭐ Starship | Custom prompt | `.config/starship/starship.toml` |
| 🔧 Aliases | Command shortcuts | `.config/zsh/configs/aliases.zsh` |
| 🌍 Environment | Variables & paths | `.config/zsh/configs/env.zsh` |
| 🎨 Theme | Shell styling | `.config/zsh/themes/starship.zsh` |

## 🛠️ Features

### 🔍 Smart Search

| Tool | Purpose | Shortcut |
|------|---------|----------|
| 🔎 fzf | Fuzzy finder | `Ctrl+R` |
| 📂 z | Directory jumper | `z <pattern>` |
| 🔍 ripgrep | Fast search | `rg <pattern>` |

### 📝 Command Line Tools

| Tool | Replaces | Purpose |
|------|----------|---------|
| 📊 eza | ls | Modern file listing |
| 🐱 bat | cat | Syntax highlighting |
| 📈 htop | top | Process management |
| 🌳 tree | ls -R | Directory trees |
| 💾 duf | df | Disk usage |

### ⚡ Productivity Shortcuts

```bash
# Directory Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'
alias d='dirs -v'

# File Operations
alias l='eza -la'
alias ll='eza -l'
alias lt='eza --tree'
alias cat='bat'

# Git Shortcuts
alias g='git'
alias gs='git status'
alias gc='git commit'
alias gp='git push'
```

## 🎨 Theme & Styling

### 🎯 Starship Prompt

```toml
# Starship configuration
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"

[git_branch]
symbol = "🌱 "
```

### 🎨 Color Scheme

| Element | Color | Usage |
|---------|-------|--------|
| 📝 Prompt | Green | Active prompt |
| ⚠️ Warnings | Yellow | Alerts |
| ❌ Errors | Red | Error messages |
| 🔗 Links | Blue | File links |

## ⚙️ Configuration

### 🔧 Environment Setup

```bash
# Path configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Tool configuration
export EDITOR='nvim'
export VISUAL='code'
export PAGER='less'
```

### 🏃 Performance Optimization

```bash
# Cache optimization
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

# History settings
HISTSIZE=10000
SAVEHIST=10000
```

## 🔄 Updates & Maintenance

### 🔄 Regular Updates

```bash
# Update shell packages and tools
./scripts/setup.sh

# Rebuild completion cache
rm -f ~/.zcompdump; compinit
```

### 🔍 Troubleshooting

| Issue | Solution |
|-------|----------|
| 🐌 Slow startup | Run `zprof` to profile |
| 🔄 Completion issues | Rebuild cache |
| 🎨 Theme broken | Check Starship install |

## 📚 Resources

- [🐚 ZSH Documentation](https://zsh.sourceforge.io/Doc/)
- [⭐ Starship Manual](https://starship.rs/guide/)

### Environment

- Location: `dotfiles/.config/zsh/configs/env.zsh`
- Path configuration
- XDG Base Directory specification
- Default applications
- Locale settings

### History Management

- Location: `dotfiles/.config/zsh/configs/history.zsh`
- Extended history with timestamps
- Duplicate handling
- Search configuration
- Session sharing

### Aliases

- Location: `dotfiles/.config/zsh/configs/aliases.zsh`
- Modern CLI alternatives
- Navigation shortcuts
- Git operations
- Docker commands

### Tool-specific Configuration

#### Git Integration

- Location: `dotfiles/.config/zsh/tools/git.zsh`
- Custom functions
- Branch management
- Interactive operations
- Status shortcuts

#### AWS Tools

- Location: `dotfiles/.config/zsh/configs/aws.zsh`
- Profile management
- Session configuration
- Service shortcuts
- Region selection

#### Python Development

- Location: `dotfiles/.config/zsh/tools/python.zsh`
- Virtual environment handling
- Package management
- Project initialization
- Testing shortcuts

### Plugin System

#### Core Plugins

- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-completions
- fzf integration

#### Configuration

- Auto-suggestions strategy
- Syntax highlighting rules
- Completion behavior
- Key bindings

## Starship Prompt

### Configuration

- Location: `dotfiles/.config/starship/starship.toml`
- Custom format
- Module settings
- Color scheme
- Icons and symbols

### Features

- Git status integration
- Python environment
- AWS profile
- Command duration
- Error indication
