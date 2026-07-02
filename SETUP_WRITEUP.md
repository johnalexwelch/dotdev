# Alex Welch — Dev Environment Writeup

> Last updated: 2026-07-02. Reflects the state after the full audit + cleanup pass.

---

## 1. Repo Layout

Everything lives in `~/dotdev`. One repo, two concerns:

```
~/dotdev/
  Brewfile                  # all Homebrew formulae + casks (source of truth)
  install.sh                # idempotent bootstrap — safe to re-run
  dotfiles/                 # stowed with GNU Stow → $HOME
    .zshrc
    .gitconfig
    .gitignore_global
    .claude/                # Claude Code + pi config
    .pi/                    # pi agent config
    .config/                # zsh, starship, lazygit, cursor, arc, raycast, etc.
  scripts/
    ai-setup.sh             # guardian clone, pi packages, gbrain clone
    brew.sh                 # Homebrew bootstrap
    github.sh               # SSH key + gh auth
    herdr-setup.sh          # herdr integrations + plugins
    config-init.sh          # pre-creates dirs to prevent stow tree-folding
    macos/                  # per-surface macOS defaults
    hdev.sh, hlog.sh        # herdr workspace launchers
    arc.sh                  # Arc bookmark backup/restore
    security-init.sh        # git-secrets install
```

**GNU Stow** manages all symlinks: `stow -d ~/dotdev -R -t $HOME dotfiles`. Every file under `dotfiles/` lands at the same relative path under `$HOME`.

---

## 2. Fresh Install

```bash
git clone git@github-personal:johnalexwelch/dotdev.git ~/dotdev
cd ~/dotdev && bash install.sh
```

`install.sh` runs in order:

1. **`brew.sh`** — installs Homebrew if missing; runs `brew bundle --file=Brewfile`
2. **`config-init.sh`** — pre-creates `~/.config/{ghostty,lazygit,mcp,nvim,raycast,gh-dash,zsh,...}` so Stow can't tree-fold them
3. **`github.sh`** — generates `~/.ssh/id_ed25519`, adds to agent + keychain, authenticates with `gh`
4. **`gh-extensions.sh`** — installs `gh` CLI extensions
5. **Application symlinks** — `~/.config/arc → ~/Library/Application Support/Arc` etc. (Arc, Cursor, StreamDeck)
6. **macOS defaults** — `defaults.sh`, `finder.sh`, `dock.sh`, `spotlight.sh`, `terminal.sh`, `screen.sh`, `input_devices.sh`, `permissions.sh`
7. **`stow`** — materializes all `dotfiles/` symlinks into `$HOME`
8. **`ai-setup.sh`** — guardian, gbrain, pi packages (see §4)
9. **`herdr-setup.sh`** — herdr integrations + plugins (see §7)

`DRY_RUN=1 bash install.sh` prints every command without executing.

---

## 3. Shell — ZSH

### `.zshrc` (thin loader)

```zsh
XDG_CONFIG_HOME="$HOME/.config"
ZSH_CONFIG="$XDG_CONFIG_HOME/zsh"

# Load configs/  tools/  themes/ in order
for conf in "$ZSH_CONFIG/configs"/*.zsh; do source "$conf"; done
for conf in "$ZSH_CONFIG/tools"/*.zsh;   do source "$conf"; done
source "$ZSH_CONFIG/themes/starship.zsh"
eval "$(zoxide init zsh)"
```

Then: pin Node 22 LTS, load `GITHUB_MCP_PAT` from launchctl, Cargo PATH, bun, safe-chain, and the `idea`/`ideas` functions.

### Configs (`~/.config/zsh/configs/`)

| File | What it does |
|---|---|
| `aliases.zsh` | Modern CLI rewrites (`eza`, `bat`, `rg`, `fd`, `htop`, `dust`, `duf`) + nav shortcuts + git+docker+data aliases |
| `env.zsh` | XDG dirs, `~/bin`, `.local/bin`, Homebrew, Cursor PATH; sources credential files (`~/.anthropic`, `~/.openai`, `~/.slack`, etc.); CORA vars; GitHub MCP token alias |
| `history.zsh` | 50k HISTSIZE/SAVEHIST; dedup + reduce-blanks opts; **atuin** init (cross-session SQLite, Ctrl-R) with native up-arrow fallback |
| `plugins.zsh` | zsh-autosuggestions + zsh-syntax-highlighting config vars (installed via Brewfile, sourced separately) |
| `aws.zsh` | SSO helpers: `awsl` (login + set profile), `awsp` (switch profile), `aws-profiles`, `aws-sso-token`, `aws-sso-accounts` |
| `git.zsh` (tools/) | 40+ git aliases (`gs`, `glog`, `gpf`, etc.) + fzf-powered `ga-fzf`, `gco-fzf`, `gh-fzf`; `gnb` (branch + push -u), `gclean` (prune merged) |
| `python.zsh` (tools/) | pyenv init, virtualenv helpers |

### Prompt

**Starship** (`~/.config/starship/starship.toml`). Initialized via `eval "$(starship init zsh)"`.

### Navigation

**zoxide** (`z <partial-dir>`) initialized in `.zshrc`.

### Key Aliases

```zsh
ls   → eza --color --git --icons
cat  → bat
grep → rg
find → fd
j    → z (zoxide)
code → cursor
vim  → nvim
top  → htop
du   → dust
df   → duf
```

---

## 4. AI Tooling

### 4a. Claude Code — `settings.json`

Stowed from `dotfiles/.claude/settings.json` → `~/.claude/settings.json`.

**Model**: `opus` (claude-opus-4-5). Extended thinking always on (`alwaysThinkingEnabled`, `effortLevel: high`). Advisor model: `opus`.

**Permissions (allow all by default)**:
```
Bash(*), Read, Write, Edit, Glob, Grep, LS, WebFetch, WebSearch,
Agent, Monitor, SendMessage, Skill(*), LSP,
TeamCreate/Delete, RemoteTrigger, CronCreate/Delete/List,
EnterPlanMode/ExitPlanMode, EnterWorktree/ExitWorktree,
AskUserQuestion, NotebookEdit/Read, Task*
```

**Hard denies**:
```
sudo *, git push --force *, git push -f *, rm -rf / *, rm -rf ~*
```

`defaultMode: auto` — runs without asking for every permission.

**Env vars injected into every session**:
- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — enables multi-agent team features
- `LANGFUSE_HOST=http://192.168.4.43:3050` + `TRACE_TO_LANGFUSE=true` — traces to home-network Langfuse instance

**TUI**: fullscreen. Notifications: Ghostty. Teammate mode: tmux.

### 4b. Guardian (PreToolUse)

**What it is**: A TypeScript security layer that intercepts every `Bash` tool call before execution. Uses Claude (claude-haiku-4-5 for speed) to evaluate whether the command is safe within the current session context.

**Location**: `~/.claude/guardian/` — cloned from `github-personal:johnalexwelch/guardian`. Source is TypeScript; compiled to `dist/cli.js` by tsc.

**Runtime**: `run.sh` is a thin wrapper — `exec node ~/.claude/guardian/dist/cli.js`. No tsx, no JIT overhead.

**Auto-recompile**: the `PostToolUse Edit|Write` hook detects changes to `~/.claude/guardian/*.ts` and runs `npx tsc` immediately. If compile fails, prints `"Guardian compile FAILED — dist/ is stale"`.

**Dependencies**: `@anthropic-ai/sdk`, `zod`, `typescript`. No tsx, no esbuild — zero known vulnerabilities.

**Behavior**:
- Evaluates command intent against session context and rules
- Three outcomes: **allow** (proceed silently), **block** (exit 2, hard stop), **ask** (surface to user)
- Falls back to `ask` mode if `ANTHROPIC_API_KEY` is not set

### 4c. Workflow Guard (PreToolUse + PostToolUse)

**File**: `~/.claude/hooks/workflow-guard.sh` — a pure-Bash hook, no LLM calls.

**PreToolUse**: blocks `gh issue create/edit` from being labeled `ready-for-agent` if the issue body looks like a PRD (contains "PRD", "spec", "specification", "User Stories", etc.). PRD-parent issues must only be labeled as such; child implementation issues get the label.

**PostToolUse**:
- `gh issue create/edit + ready-for-agent` → prints checklist reminder (acceptance criteria, rollback, AFK/HITL, gates)
- `gh pr create/ready` → warns not to claim CI success from exit code alone; checks WORKFLOW gates
- `gh pr merge/close` → runs `git status` + `git worktree list`, tells agent to load `cleanup-delivery` skill

### 4d. PostToolUse Hooks

**On every `Bash` call**: workflow-guard (above).

**On every `Edit` or `Write`**:
1. **Linter/formatter** — `ruff check --fix` + `ruff format` for `.py`; `npx eslint --fix` for `.ts/.tsx`
2. **Secret scanner** — greps for `sk-*`, `AKIA*`, private key headers, `password=` literals; prints `WARNING` if found
3. **File size guard** — warns if file exceeds 300 lines
4. **Guardian recompile** — if the written file is `~/.claude/guardian/*.ts`, triggers `npx tsc` (30s timeout)

### 4e. SessionStart Hook

Two hooks run at session start:

1. **herdr agent-state** — notifies herdr server of session start (pane tracking, workspace awareness). No-ops silently if herdr isn't running.
2. **journey hook propagation** — copies `60-journey.sh` into any `remember` plugin hook dirs that don't have it yet (idempotent; ensures session journaling stays in sync across plugin updates).

### 4f. Status Line (HUD)

The bottom status bar is driven by **oh-my-claudecode**:
```
sh ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hud/omc-hud-cache.sh \
   ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hud/omc-hud.mjs
```
Installed by the `oh-my-claudecode@omc` plugin. Shows token usage, model, session info. Cache-backed to avoid slowing the prompt.

### 4g. Enabled Plugins

| Plugin | Purpose |
|---|---|
| `agent-sdk-dev` | Agent SDK development helpers |
| `claude-md-management` | `CLAUDE.md` / context file management |
| `code-simplifier` | Complexity + simplification suggestions |
| `context7` | Up-to-date library docs via Context7 |
| `data-engineering` | Data pipeline + SQL tooling |
| `frontend-design` | UI/design guidance |
| `git-cleanup` (trailofbits) | Dead branch + stale ref cleanup |
| `oh-my-claudecode` (omc) | HUD status line, session telemetry |
| `playwright` | Browser test generation + execution |
| `plugin-dev` | Plugin authoring scaffolding |
| `pyright-lsp` | Python LSP via Pyright |
| `remember` | Persistent session memory |
| `skill-creator` | New skill scaffolding |
| `slack` | Slack integration |
| `superpowers` | Extended tool capabilities |
| `typescript-lsp` | TypeScript LSP + diagnostics |

Disabled but installed: `code-review`, `commit-commands`, `feature-dev`, `figma`, `ralph-loop`, `security-guidance`, `serena`, `zeroize-audit`.

### 4h. Skills Library

`~/.claude/skills/` (symlinked from `dotfiles/.claude/skills/`) — **70+ skills**. Examples:

**Product / strategy**: `analysis-council`, `analysis-design`, `okr-generator`, `v1-idea-grill`, `v1-system-design`, `strategic-analysis-review`, `experiment-design`, `metric-council`, `metric-design`

**Engineering**: `tdd`, `implement`, `diagnose`, `workflow-debug`, `workflow-feature`, `workflow-finalize`, `workflow-review`, `run-backlog`, `pr-responder`, `pr-review`, `repo-audit`, `slop-cleaner`, `sql-review`, `lineage-audit`

**Docs / content**: `decision-log`, `decision-memo`, `handoff`, `humanizer`, `clarity-review`, `runbook-author`, `post-mortem`, `incident-retro`, `slack-update`

**Data**: `data-quality-audit`, `data-readiness-check`, `mock-data-generator`

**Agent / CHORUS ops**: `brain-ops`, `to-issues`, `to-prd`, `triage`, `herdr-launch`, `execute-prd`, `execute-phase`, `setup-worktree`

**UI / design**: `dashboard-design`, `dashboard-review`, `prototype`, `stage-v1-concept`

Stored in `skills.zip` (554KB) for distribution; individual dirs are the live version.

### 4i. `settings.local.json`

Machine-local, not stowed. Generated from `settings.local.template.json` on first `ai-setup.sh` run. Contains:

```json
{
  "mcpServers": {
    "gbrain": {
      "command": "/Users/alexwelch/.bun/bin/bun",
      "args": ["/Users/alexwelch/gbrain-repo/src/mcp/server.ts"]
    }
  }
}
```

**gbrain** — a local MCP server for knowledge graph / second-brain queries. Cloned from `github.com/garrytan/gbrain` to `~/gbrain-repo` by `ai-setup.sh`. Runs via bun.

---

## 5. Pi Agent — `settings.json`

Stowed from `dotfiles/.pi/agent/settings.json` → `~/.pi/agent/settings.json`.

**Default provider**: anthropic. **Default model**: claude-sonnet-5.

### Packages (26 total)

**Core intelligence**:
- `pi-web-access` — web search + fetch
- `pi-codex-goal` — goal tracking
- `pi-agent-browser-native` — real browser automation
- `pi-mcp-adapter` — MCP protocol bridge
- `pi-fork` (git) — subagent spawning with effort levels
- `pi-observational-memory` — cross-session memory compression
- `pi-codemapper` (git) — codebase indexing + symbol search
- `pi-lens` — LSP + diagnostics + ast-grep + tree-sitter
- `pi-taskflow` — DAG-based multi-agent orchestration

**GitHub + PR**:
- `@gotgenes/pi-github-tools` — GitHub MCP tools
- `pi-pr-ally` (git) — PR review + response
- `@diegopetrucci/pi-triage-comments` — comment triage

**Context management**:
- `@diegopetrucci/pi-context-cap` — context window cap warnings
- `@diegopetrucci/pi-context-inspector` — context usage visibility
- `@diegopetrucci/pi-dirty-repo-guard` — blocks writes on dirty repos
- `@diegopetrucci/pi-permission-gate` — permission confirmations
- `@narumitw/pi-caffeinate` — prevents macOS sleep during long runs

**Output + display**:
- `pi-tool-display` — richer tool result rendering
- `@mcowger/pi-better-messages-cache` — message cache performance
- `@hypabolic/pi-hypa` — compressed shell/read/grep/find/ls output
- `@ryan_nookpi/pi-extension-headroom` — extension memory headroom
- `pi-cache-optimizer` — prompt cache optimization
- `@xynogen/pix-optimizer` — token optimization
- `pi-observability` — session observability

**Notifications**:
- `@diegopetrucci/pi-notify` — macOS notification integration

### modelRoles

```json
{
  "fast":     "anthropic/claude-haiku-4-5",
  "strong":   "anthropic/claude-sonnet-4-6",
  "thinker":  "anthropic/claude-sonnet-4-6",
  "arbiter":  "anthropic/claude-opus-4-5",
  "vision":   "anthropic/claude-sonnet-4-6",
  "reasoner": "anthropic/claude-opus-4-5"
}
```

### Fork Efforts

Subagents spawned via `pi-fork` pick models by effort:

| Effort | Model | Thinking |
|---|---|---|
| `fast` | claude-haiku-4-5 | off |
| `balanced` (default) | claude-sonnet-4-6 | low |
| `deep` | claude-opus-4-5 | medium |

Observational memory compression runs on haiku-4-5 (cheap, high-frequency).

---

## 6. Git

`~/.gitconfig` (stowed):

- **Editor**: `code --wait` (opens Cursor)
- **Pager**: `delta` with side-by-side diffs, line numbers, navigation (`n`/`N`)
- **Default branch**: `main`
- **push**: `autoSetupRemote = true`, `default = current`
- **pull**: `rebase = true`
- **fetch**: `prune = true`
- **rebase**: `autoStash = true`
- **Global gitignore** (`~/.gitignore_global`): macOS system files, `.DS_Store`, VSCode/JetBrains dirs, Python/JS/TS artifacts, `.env*`, AWS credentials, Terraform state, `.omc/`, `.serena/`, `**/.claude/settings.local.json`

### Conventional Commits

`dotfiles/.config/git/commit-normalize.sh` — normalizes commit messages to Conventional Commits format. Two delivery paths:
1. **Pre-commit hook** — via `.pre-commit-config.yaml` (`stages: [commit-msg]`) when `pre-commit install` is run in a repo
2. **Manual** — `~/.config/git/commit-msg` searches for the script (same dir → XDG git dir → dotfiles path) when copied to a repo's `.git/hooks/`

---

## 7. Herdr

**herdr** is a terminal multiplexer + agent session manager. Integrations installed by `herdr-setup.sh`:

| Integration | What it does |
|---|---|
| `pi` | Registers pi sessions in herdr's pane registry |
| `claude` | Registers Claude Code sessions |
| `codex` | Registers Codex sessions |
| `opencode` | Registers opencode sessions |

Plugins:
- `persiyanov/herdr-fresh-worktree` — creates clean worktrees pre-attached to herdr panes
- `cloudmanic/herdr-plus` — extended herdr utilities

**Workspace launchers**:
- `hdev <path>` — opens a herdr workspace in the given directory
- `hlog <path>` — opens a log-focused herdr workspace
- `chorus`, `cora`, `mira` — project shortcuts pointing at canonical project dirs

The `herdr-agent-state.sh` SessionStart hook reports session open events to the herdr daemon (via UNIX socket). No-ops silently if the daemon isn't running.

---

## 8. Package Manager (Homebrew)

~230 formulae installed. Highlights:

**CLI modernization**: `eza`, `bat`, `ripgrep`, `fd`, `fzf`, `delta`, `zoxide`, `atuin`, `dust`, `duf`, `htop`, `jq`, `yq`

**Shell**: `zsh-autosuggestions`, `zsh-syntax-highlighting`, `starship`, `tmux`, `tree`

**Dev**: `git`, `gh`, `gitmoji`, `pre-commit`, `uv`, `bun`, `node@22`, `python`, `rust`, `go`, `nvim`, `lazygit`, `lazysql`

**AI / agents**: `claude-cmd`, `herdr`

**Cloud / infra**: `awscli`, `kubectl`, `k9s`, `terraform`, `ansible`, `docker`

**Data**: `dbt`, `astro` (Astronomer CLI)

**Security**: `git-secrets`, `gnupg`, `age`

**Misc**: `ffmpeg`, `imagemagick`, `pandoc`, `watch`, `wget`, `curl`

Casks (apps): Cursor, Arc, Ghostty, Raycast, Obsidian, Elgato Stream Deck, and others.

---

## 9. Credentials

Credentials live as flat files in `$HOME` (not stowed, not committed):

```
~/.anthropic        ANTHROPIC_API_KEY
~/.openai           OPENAI_API_KEY
~/.slack            SLACK tokens
~/.readwise         READWISE_TOKEN
~/.todoist          TODOIST_API_TOKEN
~/.asana            ASANA vars
~/.google           GOOGLE_* vars
~/.spotify          SPOTIFY vars
~/.discord          DISCORD vars
~/.redshift         REDSHIFT_URL
~/.metabase         METABASE vars
~/.trino            TRINO vars
~/.chief-of-staff-env  misc agent vars
```

`env.zsh` sources each one if it exists (`[[ -f "$HOME/$cred" ]] && source "$HOME/$cred"`). Missing files are silently skipped — no errors on fresh machines.

`GITHUB_MCP_PAT` lives in the macOS launchctl environment (set via `launchctl setenv`), not in a file. `.zshrc` reads it with `launchctl getenv`.

---

## 10. macOS Defaults

Set by `scripts/macos/`:

| Script | What it configures |
|---|---|
| `defaults.sh` | General UI preferences (animations, scroll bars, etc.) |
| `finder.sh` | Show hidden files, path bar, status bar, default folder |
| `dock.sh` | Dock size, auto-hide, hot corners |
| `spotlight.sh` | Disables Spotlight indexing of `~/Code` and drives |
| `terminal.sh` | Sets Ghostty as default terminal |
| `screen.sh` | Screenshot save location → `~/Desktop/Screenshots` |
| `input_devices.sh` | Tap-to-click, natural scroll, fast key repeat |
| `permissions.sh` | Removes quarantine attributes from selected apps |

---

## 11. CHORUS

`~/projects/legacy/chorus` — the connective tissue for the personal AI agent fleet.

**Agents**: Mira (COO/broker), Iris, Cora (infra), Cleo, Nora, Aria, Wren, Rowan.

**What CHORUS owns**: trust domains, wire contract (`protocol/`), guardian policy (`policy/`), permission layer (`guardian/`), health watchdog (`watchdog/`), runtime init (`scripts/init-runtime.sh`), agent registry (`registry.yaml`).

**Trust domains**: Work-confidential, Personal-confidential, Shared-safe, Public.

Mira brokers cross-domain actions. Agents operate autonomously within their tier; escalate to Mira for Tier-2 (routine-internal) or human for Tier-3+ (destructive / cross-domain).

---

## 12. Notable Patterns

**No oh-my-zsh** — removed. The configs manually load only what's needed.

**stow tree-folding prevention** — `config-init.sh` pre-creates every target directory before stow runs. Without this, stow symlinks the entire directory rather than individual files, breaking apps that write into those dirs.

**Guardian + pi in the same pipeline** — every Bash call goes through guardian (TypeScript LLM check, ~200ms hot) _then_ pi executes. Guardian runs from precompiled `dist/cli.js`; `tsx` is removed to eliminate the esbuild transitive vulnerability.

**DRY_RUN everywhere** — every script checks `DRY_RUN=${DRY_RUN:-0}` and routes through a `run_cmd()` wrapper. Lets you audit the full install sequence without touching the filesystem.

**Credential sourcing** — flat files in `$HOME`, sourced lazily. Adding a new service = drop a file, add its name to `env.zsh`'s loop. Nothing in dotfiles repo ever touches a secret.

**settings.local.json** — the only machine-specific Claude config. Generated once from template; never committed. Contains only the gbrain MCP server path.
