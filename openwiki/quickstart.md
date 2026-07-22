# dotdev — AI-Driven Development Environment

Welcome to `dotdev`: a sophisticated personal development environment for AI-assisted engineering, built around a **skills-based workflow system** that turns ambiguous requests into structured, auditable, multi-phase work.

**Start here**: Skim the overview below, then navigate the sections based on what you're trying to understand or change.

---

## What This Is

`dotdev` is a **monorepo** that bundles:

1. **System configuration** — dotfiles for macOS (zsh, git, applications) managed with GNU Stow
2. **AI agent infrastructure** — hooks, guardrails, and skill libraries for Claude and pi agents
3. **Workflow orchestration** — ~93 skills that route requests, manage execution phases, review PRs, and close delivery
4. **Documentation** — decision logs, diagrams, runbooks, and operational guides

Everything lives in **one Git repository** (`~/dotdev`). The dotfiles symlink to `$HOME` via Stow; the skills live in `~/.config/agents/skills` and are symlinked from agent-specific config directories (`~/.claude/skills`, `~/.pi/agent`, etc.).

---

## High-Level Architecture

### The Interface Layer

You interact with this environment through **pi** (a local Claude Code harness) or **Claude Code** directly. There's no web UI — work happens in the terminal.

- **pi**: Local agent wrapper with extended thinking always on, high-effort reasoning
- **Model**: claude-opus-4-5 (reasoning) + claude-sonnet (fast implementation) + claude-haiku (real-time hooks)
- **Permission model**: Almost everything is open by default; hard-denies are baked in (`sudo`, `git push --force`, `rm -rf /`)

### The Hook Pipeline

Every Bash command passes through two safety layers:

```
[Agent issues command] 
  → PRE: guardian (claude-haiku) evaluates intent + context → allow/block/ask
  → if allow: workflow-guard (pure bash) checks repo protocol 
  → [command executes]
  → POST: auto-lint, secret scan, file-size guard, guardian recompile
```

See [Architecture: The Hook Pipeline](/openwiki/architecture/system-design.md#hook-pipeline) for details.

### The Workflow System

Every piece of work is routed through **workflow-router**, which classifies the task, confirms the route with the human, runs preflight checks, and dispatches to the appropriate skill.

**Work types**:
- **workflow-router**: Sole routing authority; classifies all incoming work
- **workflow-build-one**: Standard workhorse — one ready-for-agent issue from branch to merged PR
- **workflow-feature**: Turn a vague idea into ready-to-implement issues (stops before code)
- **workflow-debug**: Bug diagnosis → fix → regression test
- **execute-prd**: Full PRD tree execution with dependent ordering
- **run-backlog**: AFK batch processing of ready-for-agent issues
- **workflow-review**: Independent review gate with risk-sized profiles
- **workflow-finalize**: Universal delivery closure (PR body → CI → merge → cleanup)

See [Workflows](/openwiki/workflows/overview.md) for the full routing map and decision framework.

### The Skills Library

~90 executable playbooks in `~/.config/agents/skills/`. Each skill is a Markdown file with YAML frontmatter (model, reasoning level, contract) and step-by-step playbook. Skills are:

- **Domain-specific**: analysis, design, metrics, incident response, product workflows
- **Workflow-wide**: routing, execution phases, review, delivery, cleanup
- **Utility**: git guardrails, git-based debugging, data generation, documentation

Skills are the **single source of truth** — when any prompt names a skill (e.g., "run workflow-finalize"), the skill's `SKILL.md` is loaded and followed, including its required gate blocks.

See [Skills Guide](/openwiki/skills-guide/overview.md) for categories, discovery, and key clusters.

---

## Core Concepts

### Step Ledgers

Every multi-step workflow maintains a **step ledger** — a living table of required/optional steps, their status, and evidence.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence |
|------|-----------|--------|----------|
| Preflight | required | completed | - |
| Execute | required | in-progress | - |
| Review | required | pending | - |
```

Required steps can't be silently skipped — they become `blocked` and the workflow halts.

### Gate Blocks

Critical workflow decisions surface as **gate blocks** — structured Markdown that captures the decision, the evidence, and the path forward.

Examples:
- `WORKTREE_BASELINE_GATE`: Proves setup-worktree ran with clean baseline
- `WORKFLOW_REVIEW_GATE`: Independent review verdict (APPROVE, REQUEST CHANGES, NEEDS_HUMAN)
- `WORKFLOW_FINALIZE_GATE`: PR merged, cleanup done

Gate blocks are not prose claims — they're **evidence records** with specific fields and structure.

### Caveman Mode

During implementation loops, narration is compressed ("caveman style") — drop articles, filler, pleasantries; prefer `[thing] [action] [reason]. [next].` This cuts token usage during the grind. Full prose returns for findings, blockers, and final handoffs.

### Agent Habits

Recurring correction patterns discovered across sessions (ground truth over speculation, scoped searches, newly-wired tools, mutating regen tools, post-rewrite semantic sanity).

See [`docs/agents/habits.md`](../docs/agents/habits.md) for the definitive list. Referenced in [`AGENTS.md`](../AGENTS.md) and [`CLAUDE.md`](../CLAUDE.md).

---

## Repository Structure

```
~/dotdev/
├── dotfiles/                      # Stowed with GNU Stow → $HOME
│   ├── .zshrc, .gitconfig, etc.
│   ├── .claude/                   # Claude-specific config
│   │   ├── skills → ../.config/agents/skills   # symlink
│   │   ├── docs → ../.config/agents/docs
│   │   ├── hooks/
│   │   └── settings.json
│   ├── .pi/                       # pi-specific config
│   │   └── agent/
│   └── .config/
│       ├── agents/                # AGENT-AGNOSTIC shared source
│       │   ├── skills/            # 90+ skills
│       │   └── docs/              # shared reference
│       ├── zsh/                   # Shell config
│       ├── nvim/, cursor/, arc/   # Application config
│       └── ...
├── docs/                          # User-facing documentation
│   ├── INSTALLATION.md
│   ├── decision-log.md            # Persistent design decisions
│   ├── agents/, audits/, research/
│   └── executions/
├── scripts/                       # Setup + operational scripts
├── test/                          # Bash test suite
├── install.sh                     # Idempotent bootstrap
├── Brewfile                       # Homebrew dependencies
├── AI_ENVIRONMENT.md              # This system explained
├── SETUP_WRITEUP.md               # Fresh install walkthrough
├── AGENTS.md, CLAUDE.md           # Agent instruction blocks
└── llms.txt                       # Context injected to Claude
```

See [Operations: Repository Structure](/openwiki/operations/setup-and-structure.md) for details.

---

## Getting Started

### Fresh Installation

```bash
git clone git@github-personal:johnalexwelch/dotdev.git ~/dotdev
cd ~/dotdev && bash install.sh
```

`install.sh` idempotently:
1. Installs Homebrew formulae (Brewfile)
2. Pre-creates config directories to prevent Stow tree-folding
3. Generates SSH keys and authenticates GitHub
4. Installs macOS defaults
5. Runs `stow` to materialize dotfiles into `$HOME`
6. Installs guardian, gbrain, and pi packages
7. Configures herdr integrations

See [Operations: Installation](/openwiki/operations/setup-and-structure.md#installation) for the full walkthrough.

### First Work Session

1. Open the terminal; `pi` starts the local agent harness
2. Describe your task: _"I want to add a dark mode toggle to the app"_
3. **workflow-router** classifies it, shows a ROUTE_CARD, asks for confirmation
4. Router dispatches to **workflow-feature** (planning) or **workflow-build-one** (direct implementation)
5. Work proceeds through the chosen workflow until completion or handoff

See [Workflows: Routing Map](/openwiki/workflows/overview.md#routing-map) for the full decision tree.

### Shell Configuration

The environment includes:

- **~/.zshrc**: Thin loader that sources config, tools, themes in order
- **~/.config/zsh/configs/**: Aliases, environment variables, history, plugins
- **~/.config/zsh/tools/**: Git aliases (40+), Python helpers, AWS helpers
- **Atuin**: Cross-session SQLite command history (Ctrl-R)

Modern CLI aliases rewrite: `eza` (ls), `bat` (cat), `rg` (grep), `fd` (find), `htop`, `dust` (du), `duf` (df).

See [Operations: Shell](/openwiki/operations/shell-and-config.md) for the full reference.

---

## Section Navigation

| Section | Purpose |
|---------|---------|
| **[Architecture](/openwiki/architecture/system-design.md)** | System design, hook pipeline, workflow routing, skill structure, concurrency/safety guards |
| **[Workflows](/openwiki/workflows/overview.md)** | All workflow types, routing decisions, decision framework, approval gates |
| **[Skills Guide](/openwiki/skills-guide/overview.md)** | Skill categories, discovery, key clusters (design, execution, review, operations) |
| **[Operations](/openwiki/operations/setup-and-structure.md)** | Setup, installation, config, shell, scripts, maintenance |
| **[Integrations](/openwiki/integrations/applications-and-tools.md)** | Tools, applications, agent interfaces, extensions |

---

## Key Files for Agents

When making changes, start with these:

| File | Purpose | Change frequency |
|------|---------|-----------------|
| `dotfiles/.config/agents/skills/*/SKILL.md` | Skill specifications | Often; PRs go through workflow-review + workflow-finalize |
| `docs/decision-log.md` | Persistent design decisions | Append-only during grills; never edit prior entries |
| `AGENTS.md`, `CLAUDE.md` | Agent instruction blocks | Rarely; track in this wiki, update manually if critical |
| `AI_ENVIRONMENT.md` | System overview | Rarely; keep in sync with this wiki |
| `dotfiles/.config/agents/skills/_docs/state-cockpit.md` | Workflow state schema | Never; reference only |
| `dotfiles/.config/zsh/configs/` | Shell configuration | Often; hotload with `source` after editing |
| `Brewfile` | Homebrew dependencies | Often; re-run `brew bundle` after changes |

---

## Common Tasks

### Add a New Skill

1. Create `dotfiles/.config/agents/skills/my-skill/SKILL.md` with YAML frontmatter and playbook
2. Run `dotfiles/.config/agents/skills/_docs/skills-index.sh --write` to regenerate the skills index
3. Link it in the skills guide if it represents a new cluster
4. Commit and push

See [Skills Guide: Writing a Skill](/openwiki/skills-guide/overview.md#writing-a-skill).

### Update Configuration

All user-facing config is under `dotfiles/.config/`. Changes made there apply to `$HOME` after `stow`:

```bash
cd ~/dotdev
stow -d . -R -t $HOME dotfiles
```

### Run a Workflow Manually

Name a skill directly and pi will load it:

```
Run workflow-debug on issue #42
```

pi loads `workflow-debug/SKILL.md`, asks for confirmation, and proceeds. Naming a skill is a load-and-gate instruction, not a verb.

### Diagnose a Problem

1. Run `diagnose` to build a feedback loop, reproduce reliably, and find the root cause
2. Document findings in `docs/diag-<date>-<slug>.md`
3. Fix the issue, add regression tests
4. Submit through **workflow-review** and **workflow-finalize**

---

## Decision Log

Important architectural and product decisions are recorded in `docs/decision-log.md`. Each entry captures:

- **Decision ID** (DL-NNNN)
- **Date** when accepted
- **Question** the grill answered
- **Decision** that was accepted
- **Alternatives considered** and tradeoffs
- **Context** (which PRD/issue/run produced it)

The log is **append-only** — supersede decisions by adding new entries that reference the prior ID, never by editing the original.

---

## Backlog

The following areas are deferred but documented:

- **GitHub Actions workflows** (`/.github/workflows/openwiki-update.yml`) — OpenWiki GitHub Actions integration for automatic wiki updates; See the workflow file for details.
- **Herdr workspace layouts** (`scripts/hdev.sh`, `dotfiles/.config/herdr/`) — Terminal workspace orchestration; detailed in SETUP_WRITEUP.md §7.
- **Raycast integrations** (`dotfiles/.config/raycast/`) — Quick-launcher scripts and custom commands; see Raycast docs.
- **Stream Deck profiles** (`dotfiles/.config/streamdeck/`) — Workflow automation via hardware buttons; consult Elgato documentation.
- **Ollama local inference** (`dotfiles/.config/ollama/`) — Local LLM setup; documented in SETUP_WRITEUP.md §9.
- **Ghostty terminal** (`dotfiles/.config/ghostty/`) — Terminal emulator config; cross-reference [Ghostty docs](https://ghostty.org/docs).

---

## Quick Reference

**Starting from scratch?** Read this page, then [Architecture: System Design](/openwiki/architecture/system-design.md).

**Running a workflow?** Jump to [Workflows: Routing Map](/openwiki/workflows/overview.md).

**Writing or updating a skill?** See [Skills Guide: Categories & Discovery](/openwiki/skills-guide/overview.md).

**Installing on a new machine?** Follow [Operations: Installation](/openwiki/operations/setup-and-structure.md#installation).

**Configuring shell or tools?** Check [Operations: Shell & Config](/openwiki/operations/shell-and-config.md).

---

**Last updated**: 2026-01-XX (automatically generated by OpenWiki)

