# Integrations: Applications and Tools

This page covers the applications, tools, and agent interfaces that make up the dotdev environment.

---

## Agent Interfaces

### pi (Local Harness)

**pi** is a local Claude Code harness that runs in the terminal with extended thinking always enabled.

- **Model**: claude-opus-4-5 with high-effort reasoning
- **Interface**: Terminal TUI (fullscreen interactive mode)
- **Thinking**: Extended thinking always on; gives agent extra time for reasoning
- **Permission model**: Almost everything allowed by default; hard-denies are baked in (sudo, force-push, rm -rf /)
- **Hooks**: Passes through guardian (haiku) pre-tool-use and workflow-guard

**Starting pi**:

```bash
pi
```

Opens an interactive agent session. Type your task or name a skill.

**Naming a skill**:

```
Implement the feature from issue #42
→ pi classifies the request
→ workflow-router loads and gates the workflow
→ Skill execution begins
```

### Claude Code (Web)

Alternative interface via Claude.ai in the browser.

- **Same model**: claude-opus-4-5
- **Same hooks**: Guardian and workflow-guard apply (if connected to pi session)
- **Use case**: Quick research, exploration, or when terminal is unavailable
- **Limitation**: Direct Claude.ai sessions don't have access to local filesystem by default

---

## Development Tools

### Editor: Cursor

**Cursor** is Claude's native AI IDE built on VSCode.

- **Config**: `dotfiles/.config/cursor/settings.json`
- **Symlink**: `~/.config/cursor → ~/Library/Application Support/Cursor`
- **Features**: Inline code completion, chat sidebar, PR review, git integration
- **Integration**: Works with dotdev skills via agent instructions

### Terminal: Ghostty

**Ghostty** is a modern terminal emulator with GPU acceleration.

- **Config**: `dotfiles/.config/ghostty/config`
- **Features**: Native Wayland/X11 support, minimal lag, rich color support
- **Performance**: GPU-accelerated rendering (compared to iTerm2's CPU-heavy approach)

### Shell: Zsh

**Zsh** is the default shell with:

- **Aliases**: Modern CLI rewrites (eza, bat, rg, fd, htop, dust, duf)
- **Plugins**: zsh-autosuggestions, zsh-syntax-highlighting
- **History**: Atuin cross-session SQLite history (Ctrl-R)
- **Prompt**: Starship with Git integration
- **Git tools**: 40+ git aliases + fzf-powered pickers

See [Shell & Config](/openwiki/operations/shell-and-config.md) for details.

### Editor: Neovim

**Neovim** config for terminal-based editing.

- **Config**: `dotfiles/.config/nvim/`
- **Language servers**: Integrated LSP support
- **Git integration**: Via git.nvim + lazygit

### Git: lazygit

**lazygit** is an interactive TUI for git workflows.

- **Config**: `dotfiles/.config/lazygit/`
- **Keybindings**: Customized for dotdev workflows
- **Launch**: `lg` (from git.zsh alias)

---

## Workspace Orchestration: herdr

**herdr** is a terminal workspace orchestrator that manages panes, windows, and context for parallel work.

### herdr Layouts

Pre-configured workspace layouts for different work types:

- **Implement layout** (workspace + lazygit + yazi file browser)
- **Review layout** (gh pr diff + PR comments + editor)
- **Research layout** (notes + web search + terminal)

### hdev: Project Workspaces

Launch a herdr workspace for a project:

```bash
hdev /path/to/project [--monitor|--minimal]

# Flags:
# --monitor: Full workspace (default)
# --minimal: Minimal workspace (just panes, no preset)
```

Creates isolated workspace in herdr with:

- Separate tmux session per project
- Pane layout for implementation or review
- Git integration (lazygit open to project branch)

### hlog: Daily Logs

Snapshot herdr agent panes to daily log:

```bash
hlog                  # Create snapshot from current herdr panes
hlog --view          # View today's log
hlog --search term   # Search log history
```

Useful for:
- Capturing context before session switch
- Daily standup notes
- Session recovery after interruption

---

## Browser: Arc

**Arc** is a browser with spaces, split view, and AI integration.

- **Config**: `dotfiles/.config/arc/` (symlinked from Arc's app support)
- **Backup/restore**: `scripts/arc.sh backup|restore`
- **Integration**: Spaces for work contexts (e.g., "Code", "Research", "Admin")

**Backup workflow**:

```bash
# Backup Arc settings before major changes
scripts/arc.sh backup

# Restore if needed
scripts/arc.sh restore
```

---

## Launcher: Raycast

**Raycast** is a macOS quick launcher with custom scripts and commands.

- **Config**: `dotfiles/.config/raycast/`
- **Custom scripts**: Bash/Python snippets for frequent tasks
- **Extensions**: GitHub, Slack, AWS integrations
- **Launch**: Cmd+K (customizable)

Common custom scripts:

- `new-todo`: Quick task creation
- `toggle-vpn`: VPN control
- `aws-profile`: Quick AWS profile switch
- `git-search`: Repository search + switch

---

## Stream Deck Integration

**Stream Deck** profiles for workflow automation via hardware buttons.

- **Config**: `dotfiles/.config/streamdeck/`
- **Profiles**: Different profile per work context
- **Buttons**: Custom Lua scripts for complex actions

Example buttons:

- Start herdr workspace
- Run workflow-build-one
- Toggle Do Not Disturb
- Quick Slack updates

See [Elgato Stream Deck documentation](https://developer.elgato.com/documentation/) for button programming.

---

## Prompt: Starship

**Starship** is a cross-shell, Rust-based prompt.

- **Config**: `dotfiles/.config/starship/starship.toml`
- **Features**: Git status, language versions, runtime indicators
- **Speed**: Blazingly fast (Rust, parallel initialization)

Modules:

- **Git branch**: Current branch name
- **Git status**: Staged/unstaged/untracked indicators
- **Language indicators**: Show if directory is Python/Node/Ruby/etc.
- **Nix shell**: Show if in nix-shell
- **Command timer**: Show last command duration if > 2 seconds

---

## Local Inference: Ollama

**Ollama** runs large language models locally for research and experimentation.

- **Config**: `dotfiles/.config/ollama/`
- **Models**: Pulled on-demand (llama2, mistral, neural-chat, etc.)
- **Endpoint**: Localhost:11434 (can be integrated into tools)

**Running a model**:

```bash
ollama run mistral       # Interactive chat
ollama serve            # Start server (required for API)
```

**API usage** (in scripts/applications):

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "mistral",
  "prompt": "Write a poem"
}'
```

---

## MCP Integration

**Model Context Protocol** (MCP) servers extend agent capabilities with custom tools.

### pi MCP Servers

Configured in `dotfiles/.pi/agent/mcp.json`:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "node",
      "args": ["/path/to/graphify-context/dist/index.js"]
    },
    "ntfy": {
      "command": "node",
      "args": ["/path/to/ntfy-notify/dist/index.js"]
    }
  }
}
```

### Custom Extensions

- **graphify-context**: Load graph-based decision context for grills
- **ntfy-notify**: Send notifications to ntfy.sh for background tasks

---

## CI/CD & Automation

### GitHub Actions

Automated workflows via `.github/workflows/`:

- **openwiki-update.yml**: Auto-generate wiki documentation on push
- **pre-commit**: Run linters, secret scanners on commit

### Pre-commit Hooks

Configured in `.pre-commit-config.yaml`:

- **Trailing whitespace**: Remove at file end
- **End-of-file-fixer**: Ensure files end with newline
- **YAML lint**: Validate YAML syntax
- **Markdown lint**: Check markdown style
- **ShellCheck**: Bash linter
- **Secret scanning**: gitleaks + detect-secrets
- **Ruff**: Python linting
- **ESLint**: TypeScript/JavaScript linting

**Install hooks**:

```bash
pre-commit install
```

**Run manually**:

```bash
pre-commit run --all-files
```

---

## Data & Analytics

### GitHub Dashboard (gh-dash)

TUI dashboard for GitHub issues, PRs, and notifications.

- **Config**: `dotfiles/.config/gh-dash/`
- **Launch**: `gh dash`
- **View**: Issues, PRs, by status/label/assignee

### Homebrew (brew)

Package manager and source of truth for dependencies.

- **Config**: `Brewfile`
- **Install**: `brew bundle`
- **Update**: `brew bundle` (idempotent)

### Mise (Runtime Manager)

Multi-runtime version manager (Node, Python, Go, Rust, etc.).

- **Config**: `~/.config/mise/config.toml`
- **Usage**: `mise install` (auto-install from .tool-versions)
- **Alias**: Use `mise` or `rtx` (backwards-compatible name)

---

## Monitoring & Status

### Watchlist & CI Monitoring

Skills for tracking CI and workflow status:

- **watch-ci**: Manual CI polling and fix helper for stuck PRs
- **slack-update**: Generate and send daily engineering update to Slack

### Logging & Snapshots

- **hlog**: Snapshot herdr panes to daily log
- **session-insight**: Analyze agent sessions for insights and decisions

---

## Security & Scanning

### Secret Scanning

Multiple layers of secret detection:

- **gitleaks**: Git history scanner (`gitleaks.toml` config)
- **detect-secrets**: Baseline-based secret detection (`.secrets.baseline`)
- **guardian**: Real-time hook evaluation for sensitive commands

### Code Quality

- **ShellCheck**: Bash linter (`.shellcheckrc`)
- **Ruff**: Python linter (auto in PostToolUse)
- **ESLint**: TypeScript linter (auto in PostToolUse)
- **markdownlint**: Markdown linter (`.markdownlint.json`)

---

## Extensions & Plugins

### GitHub CLI Extensions

Installed by `gh-extensions.sh`:

- **gh-dash**: GitHub dashboard (TUI)
- **gh-eco**: Ecosystem analytics
- **gh-user-clone**: Clone all repos for a user

### Homebrew Taps

Custom formula repositories:

```bash
# Listed in Brewfile
tap "johnalexwelch/personal"
```

---

## Configuration Reference

| Tool | Config Path | Type | Notes |
|------|---|---|---|
| **Cursor** | `dotfiles/.config/cursor/` | Editor | VSCode-based AI IDE |
| **Ghostty** | `dotfiles/.config/ghostty/` | Terminal | GPU-accelerated |
| **Neovim** | `dotfiles/.config/nvim/` | Editor | Terminal-native |
| **lazygit** | `dotfiles/.config/lazygit/` | Git | Interactive TUI |
| **herdr** | `dotfiles/.config/herdr/` | Workspace | Pane orchestration |
| **Arc** | `dotfiles/.config/arc/` | Browser | Symlinked from app support |
| **Raycast** | `dotfiles/.config/raycast/` | Launcher | Custom scripts |
| **zsh** | `dotfiles/.config/zsh/` | Shell | Aliases, plugins, history |
| **Starship** | `dotfiles/.config/starship/` | Prompt | Multi-shell prompt |
| **Ollama** | `dotfiles/.config/ollama/` | ML | Local inference |
| **mcp** | `dotfiles/.pi/agent/mcp.json` | Agent | Custom MCP servers |
| **pre-commit** | `.pre-commit-config.yaml` | CI | Hook linters |
| **GitHub** | `.github/workflows/` | CI | GitHub Actions |
| **Homebrew** | `Brewfile` | Package | Dependency source of truth |

---

## Adding a New Tool

1. **Install via Homebrew** (if available):
   ```bash
   brew install my-tool
   echo 'my-tool' >> Brewfile
   ```

2. **Add config** (if needed):
   ```bash
   mkdir -p dotfiles/.config/my-tool
   cp ~/path/to/my-tool/config dotfiles/.config/my-tool/
   ```

3. **Update config-init.sh** (if top-level config dir):
   ```bash
   mkdir -p "$HOME/.config/my-tool"
   ```

4. **Re-stow**:
   ```bash
   cd ~/dotdev && stow -d . -R -t $HOME dotfiles
   ```

5. **Test**:
   ```bash
   my-tool --version
   ```

---

## See Also

- [Operations: Setup & Structure](/openwiki/operations/setup-and-structure.md) — Installation, Stow, file layout
- [Operations: Shell & Config](/openwiki/operations/shell-and-config.md) — Detailed shell setup
- [Architecture: System Design](/openwiki/architecture/system-design.md) — Agent hooks, guardian, workflow-guard
- Individual tool documentation (external links)

