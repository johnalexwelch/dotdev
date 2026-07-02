# AI Working Environment

> How the toolchain fits together and how work actually gets done.

---

## The Interface: pi + Claude Code

Everything runs through **pi** — a local coding agent harness that wraps Claude Code (Anthropic's agentic tool). The terminal is the primary interface. There's no separate web app, no prompt playground. Work happens in the same terminal session as the code.

**Model**: claude-opus-4-5. Extended thinking always on, effort level high. The session runs in fullscreen TUI mode.

**What "agentic" means here**: the agent reads files, runs shell commands, edits code, calls web APIs, opens browsers, manages git, creates PRs, and spawns subagents — all in a single session. The human sets direction; the agent drives.

**Permission model**: almost everything is open by default. The hard-denies are baked in (`sudo`, `git push --force`, `rm -rf /`). The actual safety control surface is the guardian (below), not the permissions list.

---

## The Guardian: PreToolUse Safety Layer

Every `Bash` call goes through the guardian before execution. This is a TypeScript program (compiled to `dist/cli.js`) that calls claude-haiku-4-5 to evaluate the command against the current session context and a rule set.

**Three outcomes**: allow (silent), block (hard exit, logged reason), ask (surface to the human).

**Why haiku**: the guardian runs on every command — latency matters. Haiku is fast (~200ms hot). The rule set and session context give it enough signal to be accurate on what counts.

**Why precompiled**: the guardian used to run via tsx (TypeScript JIT). Swapped to precompiled `dist/cli.js` to shave ~200ms per call. A PostToolUse hook recompiles automatically whenever guardian source files change and reports failure loudly if the build breaks.

**Zero known vulnerabilities**: removing tsx also removed the esbuild transitive dependency that carried a low CVE. The guardian now depends only on `@anthropic-ai/sdk` and `zod`.

---

## Workflow Guard: Rule-Based Hooks

A second pre/post hook written in pure Bash — no LLM, no latency, just regex. It enforces workflow protocol rules:

**Before a `gh issue` command**: blocks PRD-parent issues from being labeled `ready-for-agent`. PRDs are specs; only child implementation issues get that label.

**After a `gh pr` open or ready**: reminds the agent not to claim CI success from exit code alone — every PR needs local validation evidence.

**After a `gh pr` merge or close**: runs `git status` + `git worktree list` and tells the agent to load the cleanup-delivery skill before deleting anything.

---

## PostToolUse Automation

Every file write or edit triggers three automatic checks without prompting:

1. **Auto-linting**: `ruff check --fix` + `ruff format` for Python; `npx eslint --fix` for TypeScript. Runs and fixes silently.
2. **Secret scanner**: greps for API key patterns (`sk-*`, `AKIA*`), private key headers, and hardcoded passwords. Prints a warning if found.
3. **File size guard**: warns at 300 lines. Structural nudge toward smaller files.

---

## The Skills Library

~89 skills in `~/.claude/skills/`. A skill is a Markdown file with YAML frontmatter — it specifies the model, reasoning level, contract (inputs/outputs/side effects), and a playbook. Skills aren't just prompts; they're executable protocols.

Every multi-step skill produces a **step ledger** at the start and maintains it throughout:

```
WORKFLOW_STEPS:
| Step         | Required? | Status    | Evidence              |
|------------- |-----------|---------- |---------------------- |
| diagnose     | required  | completed | artifact at docs/...  |
| fix          | required  | pending   | -                     |
| verify       | required  | pending   | -                     |
```

Steps can't be silently skipped. A required gate that can't run becomes `blocked` — not `skipped` — and the workflow halts.

### Workflow Routing

**`workflow-router`** is the single entry point for all work. It classifies the task, presents a route card for human confirmation, runs preflight checks, then dispatches. Work types:

| Type | Routes to |
|---|---|
| Feature idea (ambiguous) | `workflow-feature` |
| Ready issue | `workflow-build-one` |
| Batch of ready issues | `run-backlog` |
| Bug report | `workflow-debug` |
| Full PRD tree | `execute-prd` |

### Building One Thing: `workflow-build-one`

The standard workhorse. Takes a single `ready-for-agent` issue from preflight through to repo-policy-controlled PR. Flow:

```
worktree → preflight → execute → workflow-review → [user-journey-qa] → workflow-finalize
```

Implementation runs on Sonnet (fast, cheap). Review runs on Opus (judgment-heavy). The output discipline during execution is intentionally compressed ("caveman mode" — terse narration, no filler) to reduce scroll during the grind. Full prose comes back for findings, blockers, and the final summary.

### Building a Backlog: `run-backlog`

AFK batch processor for `ready-for-agent` issues. Dispatches each issue to Codex (via OMC team bridge) for natural isolation — every issue gets its own context window. Delivery behavior is controlled per-repo: `human-only` repos require a human to merge; `auto-merge-eligible` repos can merge automatically after all gates pass.

### Feature Development: `workflow-feature`

Turns a vague idea into triaged implementation issues. Flow:

```
grill-with-docs → decision-log → [prototype] → workflow-roadmap (approval gate) → to-prd → to-issues → triage
```

This workflow *stops before implementation*. It produces the work; `workflow-build-one` or `run-backlog` execute it.

### Bug Work: `workflow-debug`

Cardinal rule: **all bug work begins with `diagnose`**. Even if the fix is obvious. The diagnosis artifact proves understanding and prevents wrong fixes.

`diagnose` has five modes: quick / standard / deep / production / regression. Standard runs the full Phase 1–6 loop: build a feedback loop → reproduce → minimise → hypothesise → instrument → fix → regression-test.

### Review: `workflow-review`

Runs an independent review gate sized to the change's risk. Dispatches reviewer lanes on Opus. Four review profiles: `fast` (single integrated reviewer, Sonnet), `standard` (one independent reviewer, Opus), `full` (multiple lanes: security, logic, tests, UX), `minimal` (docs/config only).

Green CI, GitHub reviews, or Claude Code Review do not substitute for this. The workflow-review gate produces a `WORKFLOW_REVIEW_GATE` block — a structured verdict that downstream workflow-finalize checks for.

### Delivery: `workflow-finalize`

Closes the delivery loop after workflow-review approves. Handles PR description, reviewer comment resolution, CI monitoring, issue reconciliation, and the repo-policy-controlled final action. Will not proceed without an explicit `WORKFLOW_REVIEW_GATE` block from an independent review with `verdict: APPROVE`.

### Handling Incoming Review: `receive-review` + `pr-responder`

When review comments land on a PR:

1. **`receive-review`**: evaluates each comment for technical correctness. Doesn't blindly agree — declines suggestions that are wrong, conflict with other reviewers, or contradict project invariants. Produces a triage table: action / push-back / defer / acknowledge.
2. **`pr-responder`**: works through the full comment queue, drafts code fixes, posts replies. Human confirms before replies go out for pushbacks.

### Architecture Work

**`repo-audit`**: map-reduce investigation of actual codebase state. Parallel discovery agents (Sonnet) gather facts; a synthesizer (Opus) produces findings with stable `FIND-NN` IDs. Feeds into `workflow-roadmap`, `to-prd`, or `design-plan`.

**`improve-codebase-architecture`**: surfaces deepening opportunities — refactors that turn shallow modules into deep ones, improve testability, and make code more navigable.

**`slop-cleaner`**: strips LLM ceremony from docs and analysis. Two modes: `docs` (READMEs, comments, runbooks) and `analysis` (findings, memos, recommendations). Produces a change log and before/after word counts.

---

## Worktrees

Every non-trivial implementation runs in an isolated git worktree at `~/wt/<repo>/<branch-slug>/`. The main branch stays clean. Multiple in-flight features coexist without conflict.

**`setup-worktree`** handles the mechanics: resolves the workflow base branch, creates the worktree, copies `.env*`/`.tool-versions`, and records `WORKTREE_BASELINE_GATE` evidence that downstream workflow-review and workflow-finalize check for.

**workflow-finalize enforces this**: if the change was done in the primary checkout or on a branch based on local `main`, it halts and requires a valid worktree baseline.

---

## Herdr: Workspace Layout

**herdr** is a terminal multiplexer + session manager. The `hdev` command creates a structured workspace:

```bash
hdev ~/projects/myapp          # full layout
hdev ~/projects/myapp --monitor  # gh-dash only
hdev ~/projects/myapp --minimal  # pi only
```

**Full layout** (the default):
- **Work tab**: pi (left pane) | lazygit (right-top) | yazi file browser (right-bottom)
- **gh tab**: gh-dash for issue/PR/CI monitoring

Every AI session (pi, Claude Code, Codex, opencode) registers with herdr on start via the SessionStart hook. The herdr daemon tracks what's running in which pane, enabling workspace-aware tooling.

Shortcut aliases: `chorus`, `cora`, `mira` → `hdev ~/projects/...` for frequently used projects.

---

## Pi Packages

26 packages loaded into pi. Grouped by what they actually enable:

**Codebase navigation**
- `pi-codemapper` — indexes the codebase (symbols, call graphs, dependencies), enables `map`, `search`, `outline`, `expand`, `path` operations in every session
- `pi-lens` — LSP diagnostics, ast-grep structural search, tree-sitter rules; runs against the live language server

**Subagent orchestration**
- `pi-fork` — spawns subagents at configurable effort levels (fast/balanced/deep → haiku/sonnet/opus)
- `pi-taskflow` — orchestrates multi-agent DAGs (parallel branches, sequential chains, gated phases, map-reduce)

**Memory + context**
- `pi-observational-memory` — compresses session learnings into cross-session observations that survive context window resets; runs on haiku (cheap, frequent)
- `pi-context-cap` — warns approaching context limits
- `pi-context-inspector` — shows context composition

**Guardrails**
- `pi-dirty-repo-guard` — blocks writes on repos with uncommitted changes
- `pi-permission-gate` — confirmation prompts for destructive operations
- `pi-codex-goal` — tracks a concrete objective through multi-turn sessions

**Output efficiency**
- `pi-hypa` — compresses shell, read, grep, find, and ls output before it reaches the context window. Same commands, less token spend.
- `pi-cache-optimizer` — prompt cache optimization
- `pi-better-messages-cache` — message-level caching
- `pix-optimizer` — token optimization pass

**Real-world integration**
- `pi-web-access` — web search and fetch
- `pi-agent-browser-native` — real Playwright-backed browser automation (click, fill, screenshot, extract, eval)
- `pi-mcp-adapter` — MCP protocol bridge
- `@gotgenes/pi-github-tools` — GitHub MCP tools
- `pi-pr-ally` — PR review and response assistance

**Utility**
- `@narumitw/pi-caffeinate` — prevents macOS sleep during long AFK runs
- `@diegopetrucci/pi-notify` — macOS notifications when the agent needs input or completes

**Model roles** — what each tier runs on:

| Role | Model | Used for |
|---|---|---|
| fast | claude-haiku-4-5 | Quick lookups, memory compression, subagent fast mode |
| strong / thinker / vision | claude-sonnet-4-6 | Normal exploration, implementation, most subagent work |
| arbiter / reasoner | claude-opus-4-5 | Review, architecture decisions, high-stakes judgment |

**Fork effort → model mapping**:
- `fast` → haiku, thinking off
- `balanced` (default) → sonnet, low thinking
- `deep` → opus, medium thinking

---

## Claude Code Plugins

25 plugins loaded via `enabledPlugins`. Active ones:

| Plugin | What it adds |
|---|---|
| `context7` | Fetches up-to-date library docs mid-session (no stale training data) |
| `typescript-lsp` | TypeScript language server — inline errors, go-to-def, rename refactor |
| `pyright-lsp` | Python language server via Pyright |
| `playwright` | Browser test generation and execution |
| `oh-my-claudecode` | HUD status line, session telemetry, team dispatch (AFK batch mode) |
| `remember` | Persistent session memory — captures key decisions and context across sessions |
| `superpowers` | Extended tool capabilities |
| `code-simplifier` | Surfaces complexity hotspots |
| `context7` | Real-time library docs lookup |
| `data-engineering` | Data pipeline and SQL tooling |
| `frontend-design` | UI/design guidance |
| `git-cleanup` | Dead branches and stale ref cleanup |
| `skill-creator` | Scaffolds new skills |
| `agent-sdk-dev` | Agent SDK development helpers |
| `claude-md-management` | CLAUDE.md context file management |
| `slack` | Slack integration |

---

## The Status Bar

The bottom of every session: an **omc HUD** (oh-my-claudecode). Shows token usage, model, and session state. Cache-backed — only re-reads state when something changes.

---

## MCP Server: gbrain

A local MCP server (`~/gbrain-repo`) that provides a knowledge graph interface to Claude Code. Runs via bun. Registered in `settings.local.json` (machine-local, not stowed). Gives any session structured query access to a personal knowledge graph.

---

## Idea Capture

The `idea` function in `.zshrc` is the frictionless capture path:

```bash
idea "build a metrics alerting layer"
idea -q "quick note"     # skip AI enrichment
```

The first form calls claude-haiku-4-5 to:
- Classify the idea (tool / app / research / business / experiment / feature / creative / ...)
- Write a one-sentence pitch
- Generate 2–4 Obsidian tags
- Suggest 3 concrete next steps

The result lands as a structured Markdown frontmatter file in `~/Documents/Home/Idea Bin/` — title, date, category, pitch, tags, next steps. Fast enough to capture before the thought is gone.

`ideas review` and `ideas promote` move ideas through the downstream pipeline.

---

## Observability

**Langfuse** at `192.168.4.43:3050` (home network) receives traces from every Claude session. Token usage, tool calls, session duration, and model spend are visible in a dashboard when on the home network. Set via `LANGFUSE_HOST` and `TRACE_TO_LANGFUSE=true` in session env.

**pi-observational-memory** produces per-session compressed observations that persist across context resets. These accumulate over time into a navigable log of what was learned, decided, and done.

---

## Shell + Git

**ZSH** with a minimal, modular config. No oh-my-zsh. Modules load in order: configs → tools → theme.

**Key tools**:
```
eza     → ls (icons, color, git status)
bat     → cat (syntax highlight, line numbers)
rg      → grep (ripgrep, fast)
fd      → find
fzf     → fuzzy picker (git add, branch checkout, log browse)
zoxide  → cd (frecency-based, alias j)
atuin   → shell history (cross-session SQLite, Ctrl-R fuzzy)
starship → prompt
delta   → git diffs (side-by-side, line numbers, navigation)
lazygit → terminal git UI
```

**Git config**:
- `pull.rebase = true`, `fetch.prune = true`, `rebase.autoStash = true`, `push.autoSetupRemote = true`
- Global gitignore covers macOS, Python, JS/TS artifacts, `.env*`, AWS credentials, Terraform state, `.omc/`, `.serena/`, `**/.claude/settings.local.json`
- Conventional commits via pre-commit hook (`commit-normalize.sh`) — active in any repo with `pre-commit install`

**Git aliases** (selection):
```
gs    git status -sb
glog  git log --oneline --decorate --graph
gpf   git push --force-with-lease
grbi  git rebase -i
ga-fzf    interactive add with fzf + diff preview
gco-fzf   interactive branch checkout with fzf
```

---

## Fresh Machine Bootstrap

```bash
git clone git@github-personal:johnalexwelch/dotdev.git ~/dotdev
cd ~/dotdev && bash install.sh
```

`DRY_RUN=1 bash install.sh` previews every command without executing.

The install sequence: Homebrew → config dirs → GitHub SSH → macOS defaults → GNU Stow symlinks → guardian clone + compile → gbrain clone → pi packages → herdr integrations.

One machine-local file needs manual setup post-install: `~/.claude/settings.local.json` (created from template — contains the gbrain MCP path). All credentials are flat files in `$HOME` sourced by `env.zsh` — drop the file, it gets picked up next shell start.
