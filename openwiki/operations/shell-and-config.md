# Operations: Shell and Configuration

This page covers shell setup (zsh, aliases, history, plugins), environment variables, and runtime configuration.

---

## Shell: ZSH

### The Loader (`.zshrc`)

The thin `.zshrc` file loads configuration in order:

```bash
# ~/.zshrc (thin loader)
XDG_CONFIG_HOME="$HOME/.config"
ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"

# Load configs/ tools/ themes/ in order
for conf in "$ZSH_CONFIG/configs"/*.zsh; do source "$conf"; done
for conf in "$ZSH_CONFIG/tools"/*.zsh;   do source "$conf"; done
source "$ZSH_CONFIG/themes/starship.zsh"
eval "$(zoxide init zsh)"
```

Everything lives under `~/.config/zsh/` — organized, decoupled, hotloadable.

### Configuration Modules

#### `~/.config/zsh/configs/` — Core Setup

| File | What it does |
|------|---|
| `aliases.zsh` | Modern CLI rewrites (eza, bat, rg, fd, htop, dust, duf) + nav shortcuts + git+docker+data aliases |
| `env.zsh` | XDG directories, PATH setup, homebrew, credential sourcing, CORA env vars |
| `history.zsh` | 50k HISTSIZE/SAVEHIST; dedup/blank reduction; Atuin init (Ctrl-R) |
| `plugins.zsh` | zsh-autosuggestions + zsh-syntax-highlighting config (installed via Brewfile) |
| `aws.zsh` | AWS SSO helpers: awsl, awsp, aws-profiles, aws-sso-token, aws-sso-accounts |

#### `~/.config/zsh/tools/` — Command Tools

| File | What it does |
|------|---|
| `git.zsh` | 40+ git aliases (gs, glog, gpf, gnb, gclean, etc.) + fzf-powered ga-fzf, gco-fzf, gh-fzf |
| `python.zsh` | pyenv init, virtualenv helpers (venv, deactivate) |

#### Theme

```bash
source ~/.config/zsh/themes/starship.zsh
```

Uses **Starship** prompt with Git integration.

---

## Modern CLI Aliases

Standard UNIX tools are replaced with modern alternatives via aliases:

| Alias | Tool | Why |
|-------|------|-----|
| `ls` | `eza` | Colors, Git status, tree view |
| `cat` | `bat` | Syntax highlighting, Git integration |
| `grep` | `rg` (ripgrep) | Fast, respects .gitignore |
| `find` | `fd` | Simpler syntax, .gitignore respect |
| `top` | `htop` | Interactive, cleaner UI |
| `du` | `dust` | Visual disk usage |
| `df` | `duf` | Cleaner disk-free output |
| `grep -r` | `rg` | Respects .gitignore by default |
| `tree` | `tree` (or `eza --tree`) | Directory structure |

See `~/.config/zsh/configs/aliases.zsh` for the full list.

---

## Git Aliases

The git toolset includes 40+ aliases in `~/.config/zsh/tools/git.zsh`:

### Status & Inspection

| Alias | Command | Purpose |
|-------|---------|---------|
| `gs` | `git status` | Short status |
| `gds` | `git diff --staged` | Staged changes |
| `glog` | `git log --oneline -n 20` | Recent commits |
| `gloga` | `git log --oneline --all --graph -n 20` | Graph view |
| `gb` | `git branch` | List branches |
| `gba` | `git branch -a` | All branches |

### Commits & Branches

| Alias | Command | Purpose |
|-------|---------|---------|
| `gc` | `git commit` | Make commit |
| `gca` | `git commit --amend` | Amend last commit |
| `gnb` | `git checkout -b ... && git push -u origin ...` | New branch + push |
| `gco` | `git checkout` | Switch branch |
| `gpf` | `git push --force-with-lease` | Force-push safely |
| `gp` | `git push` | Push |
| `gpl` | `git pull` | Pull |

### Cleanup & Maintenance

| Alias | Command | Purpose |
|-------|---------|---------|
| `gclean` | `git branch -vv | grep 'gone]' | awk '{print $1}' | xargs git branch -D` | Delete merged branches |
| `gprune` | `git fetch --prune` | Prune deleted remote branches |
| `greset` | `git reset HEAD~1` | Undo last commit (keep changes) |

### FZF-Powered (Interactive)

| Alias | Purpose |
|-------|---------|
| `ga-fzf` | Stage files interactively (fzf picker) |
| `gco-fzf` | Checkout branch interactively (fzf picker) |
| `gh-fzf` | GitHub PR picker (fzf + gh CLI) |

---

## History: Atuin

**Atuin** replaces zsh's default history with cross-session SQLite:

- **Ctrl-R**: Opens fuzzy-searchable history across all sessions
- **Fallback**: Native up-arrow still works if Atuin doesn't match
- **Size**: Unlimited (backed by database)
- **Sync**: Can sync across machines (optional, not configured by default)

Configured in `~/.config/zsh/configs/history.zsh`:

```bash
eval "$(atuin init zsh)"
```

---

## Plugins

### zsh-autosuggestions

Fish-like autosuggestions as you type. Navigate suggestions with:

- **Right arrow**: Accept suggestion
- **Ctrl+E**: End of line (reject)

### zsh-syntax-highlighting

Real-time syntax highlighting as you type:

- **Green**: Valid command
- **Red**: Invalid command
- **Cyan**: Path, option, builtin

Both installed via Brewfile, sourced in `plugins.zsh`.

---

## Environment Variables

### XDG Base Directory

```bash
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
```

All application config centralizes under `~/.config/`.

### PATH

Built in `env.zsh`:

```bash
# Order: ~/bin, ~/.local/bin, homebrew, cargo, bun, system
export PATH="$HOME/bin:$HOME/.local/bin:$(brew --prefix)/bin:$PATH"
```

### Credentials

Sourced from credential files (not tracked by git):

```bash
# env.zsh sources these at login
source ~/.anthropic       # ANTHROPIC_API_KEY
source ~/.openai          # OPENAI_API_KEY
source ~/.slack           # SLACK_TOKEN
source ~/.github          # GITHUB_TOKEN (used by gh CLI)
```

Never commit these files. Create them manually on each machine.

### CORA Variables

Custom environment variables for agent workflows:

```bash
export CORA_REPO="$HOME/code/my-repo"          # Current project
export CORA_BRANCH="main"                       # Target branch
export CORA_AGENT="claude"                      # Active agent
```

Set per-session as needed.

---

## AWS Integration

The `aws.zsh` tool provides SSO helpers:

### `awsl` — Login

```bash
awsl
```

Prompts for SSO region and starts browser login. Updates `~/.aws/config` and `~/.aws/credentials`.

### `awsp` — Switch Profile

```bash
awsp
```

Interactive fzf picker to select AWS profile. Sets `AWS_PROFILE` env var.

### `aws-profiles` — List Profiles

```bash
aws-profiles
```

Lists all configured profiles.

### `aws-sso-token` — Get Token

```bash
aws-sso-token <profile>
```

Prints SSO token for a profile.

---

## Python Helpers

The `python.zsh` tool includes:

### `pyenv` Integration

```bash
eval "$(pyenv init -)"
```

Allows per-project Python versions via `.python-version` file.

### Virtualenv Helpers

```bash
venv             # Create and activate virtualenv in current dir
deactivate       # Exit virtualenv
```

---

## Hotloading Configuration

Changes to shell config are **hotloadable** without restarting zsh:

```bash
# Edit a config file
vim ~/.config/zsh/configs/aliases.zsh

# Reload immediately
source ~/.zshrc
```

No need to restart terminal.

---

## Customization

### Add a New Alias

```bash
# Edit
vim ~/.config/zsh/configs/aliases.zsh

# Add your alias
alias myalias="command --with --options"

# Reload
source ~/.zshrc
```

### Add a New Tool

```bash
# Create tool file
cat > ~/.config/zsh/tools/my-tool.zsh << 'EOF'
# My tool setup
export MY_VAR="value"
function my-func() { ... }
EOF

# Reload
source ~/.zshrc
```

### Add Credential File

```bash
# Create credential file (not tracked)
cat > ~/.myservice << EOF
export MYSERVICE_API_KEY="secret-key"
export MYSERVICE_SECRET="secret-value"
EOF

# Source from env.zsh
echo 'source ~/.myservice' >> ~/.config/zsh/configs/env.zsh
source ~/.zshrc
```

---

## Troubleshooting

### Command Not Found After Edit

**Cause**: Changes not reloaded.

**Fix**:
```bash
source ~/.zshrc
```

### Slowdown on Startup

**Cause**: Too many files being sourced or slow command in config.

**Fix**:
```bash
# Time startup
time zsh -i -c exit

# Time individual modules
time source ~/.config/zsh/configs/aliases.zsh
# ... test each file to find the slow one
```

### History Not Persisting

**Cause**: Atuin not initialized or database corrupted.

**Fix**:
```bash
# Check Atuin status
atuin --version

# Reinitialize
eval "$(atuin init zsh)"

# Reload
source ~/.zshrc
```

### Git Aliases Not Working

**Cause**: `git.zsh` not sourced or syntax error.

**Fix**:
```bash
source ~/.config/zsh/tools/git.zsh

# Check for syntax errors
bash -n ~/.config/zsh/tools/git.zsh
```

### AWS CLI Not Finding Profile

**Cause**: `~/.aws/config` not set up or profile not selected.

**Fix**:
```bash
# List profiles
aws-profiles

# Switch profile
awsp

# Verify
echo $AWS_PROFILE
```

---

## See Also

- [Setup & Structure](/openwiki/operations/setup-and-structure.md) — Repository layout, installation, Stow
- [Starship Docs](https://starship.rs/) — Prompt customization
- [Atuin Docs](https://atuin.sh/) — History sync and backup
- [Homebrew](https://brew.sh/) — Package manager
- `~/.config/zsh/` — All configuration files (source of truth)

