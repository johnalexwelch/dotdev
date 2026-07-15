# AI Working Environment

> How the toolchain fits together and how work actually gets done.

---

## The Interface: pi + Claude Code

Everything runs through **pi** — a local coding agent harness that wraps Claude Code (Anthropic's agentic tool). The terminal is the primary interface. There's no separate web app, no prompt playground. Work happens in the same terminal session as the code.

**Model**: claude-opus-4-5. Extended thinking always on, effort level high. The session runs in fullscreen TUI mode.

**What "agentic" means here**: the agent reads files, runs shell commands, edits code, calls web APIs, opens browsers, manages git, creates PRs, and spawns subagents — all in a single session. The human sets direction; the agent drives.

**Permission model**: almost everything is open by default. The hard-denies are baked in (`sudo`, `git push --force`, `rm -rf /`). The actual safety control surface is the guardian (below), not the permissions list.

---

## The Hook Pipeline

Every `Bash` call passes through two layers before and after execution.

```mermaid
flowchart TD
    A([Agent issues Bash command]) --> B

    subgraph PRE [PreToolUse]
        B[guardian\nclaude-haiku-4-5\nevaluates intent + context]
        B --> C{verdict}
        C -->|allow| D[workflow-guard\npure-Bash rule checks]
        C -->|block| STOP1([exit 2 — reason logged])
        C -->|ask| E([surface to human])
        E -->|approved| D
        E -->|denied| STOP1
        D -->|PRD + ready-for-agent\non create/edit| STOP1
        D -->|ok| EXEC
    end

    EXEC([command executes])

    subgraph POST [PostToolUse — fires on every Edit / Write]
        F[auto-lint\nruff for .py · eslint for .ts]
        G[secret scan\nAPI keys · private key headers]
        H[file size guard\nwarn above 300 lines]
        I[guardian recompile\nif guardian/*.ts changed\nnpx tsc — 30s timeout]
        J[workflow-guard post-checks\nPR open → evidence reminder\nPR merge → cleanup prompt]
    end

    EXEC --> F & G & H & J
    EXEC --> I
```

### The Guardian

TypeScript program compiled to `dist/cli.js`. Calls claude-haiku-4-5 to evaluate the command against session context and a rule set. Three outcomes: **allow** (silent), **block** (hard exit + logged reason), **ask** (surface to human).

**Why haiku**: runs on every command — ~200ms hot. Fast enough to not interrupt flow; accurate enough on things that matter.

**Why precompiled**: swapped from tsx (JIT) to precompiled `dist/cli.js`. Saves ~200ms per call. Also removed the esbuild transitive CVE. Dependencies: `@anthropic-ai/sdk` + `zod` only, zero known vulnerabilities.

**Auto-recompile**: PostToolUse detects changes to `guardian/*.ts`, runs `npx tsc`, reports `"Guardian compile FAILED — dist/ is stale"` loudly on error.

### Workflow Guard

Pure-Bash hook (no LLM). Enforces workflow protocol:

- **Pre**: blocks `ready-for-agent` label on PRD-parent issues
- **Post PR open**: warns not to claim CI success from exit code alone
- **Post PR merge**: runs `git status` + `git worktree list`, prompts cleanup-delivery

---

## The Skills Library

~90 skills in `~/.config/agents/skills/` (agent-neutral shared source; also reachable via `~/.claude/skills/`). A skill is a Markdown file with YAML frontmatter — model, reasoning level, contract (inputs/outputs/side effects), and a step-by-step playbook. Skills are executable protocols, not prompts.

Every multi-step skill opens with a **step ledger** and maintains it throughout:

```
WORKFLOW_STEPS:
| Step     | Required? | Status    | Evidence           |
|----------|-----------|-----------|--------------------|
| diagnose | required  | completed | docs/diag-xyz.md   |
| fix      | required  | pending   | -                  |
| verify   | required  | pending   | -                  |
```

Required steps can't be silently skipped — they become `blocked` and the workflow halts.

---

## Workflow Routing

**`workflow-router`** is the single entry point. It classifies the task, presents a `ROUTE_CARD` for human confirmation, runs preflight, then dispatches. Nothing bypasses it.

```mermaid
flowchart TD
    IN([any request]) --> R[workflow-router\nclassify → ROUTE_CARD → confirm]

    R --> C{work type}

    C -->|new idea / vague feature| WF[workflow-feature]
    C -->|single ready-for-agent issue| WB[workflow-build-one]
    C -->|batch of ready issues| RB[run-backlog]
    C -->|bug report| WD[workflow-debug]
    C -->|full PRD issue tree| EP[execute-prd]
    C -->|refactor / migration| DP[design-plan\n→ execute-phase]
    C -->|codebase evidence needed| RA[repo-audit\nfeeds roadmap / PRD]
    C -->|trivial / no delivery gate| DIR([direct execution])

    WF --> TRIAGE([triaged issues])
    WB --> PR([PR])
    RB --> PR
    EP --> PR
    WD --> PR
    DP --> PR
```

---

## Feature Development: `workflow-feature`

Turns a vague idea into triaged, ready-to-implement issues. **Stops before implementation** — produces the work, doesn't execute it.

```mermaid
flowchart TD
    A([idea / vague feature]) --> B

    B[grill-with-docs\nstress-test against existing docs\nand past decisions]
    B --> C[decision-log\nrecord the architectural choice]
    C --> D{quick spike\nuseful?}
    D -->|yes| E[prototype\noptional]
    D -->|no| F
    E --> F

    F[/workflow-roadmap\n⚡ HUMAN APPROVAL GATE\nmilestone plan + scope/]
    F -->|approved| G
    F -->|rejected| STOP([stop / revise])

    G[to-prd\nwrite PRD as GitHub Issue\nwith vertical slice framing]
    G --> H[to-issues\ndecompose into implementation slices\none issue = one demoable behavior]
    H --> I[triage\nclassify · label · write agent briefs]
    I --> OUT([ready-for-agent issues\n→ workflow-build-one or run-backlog])
```

---

## Building One Thing: `workflow-build-one`

The standard workhorse. Drives a single `ready-for-agent` issue from a clean worktree to a merged PR.

```mermaid
flowchart TD
    A([ready-for-agent issue]) --> B[setup-worktree\ncreate isolated branch\nfrom origin/main\nrecord WORKTREE_BASELINE_GATE]
    B --> C[preflight\ncheck acceptance criteria\nAFK safety · dependencies]
    C --> D{AFK safe?}
    D -->|no — NEEDS_HUMAN| HAND([handoff artifact\nhalt])
    D -->|yes| F

    F[implement\nSonnet — caveman narration\nduring the loop]
    F --> G

    G[workflow-review\nindependent gate\nOpus]
    G --> H{verdict}
    H -->|REQUEST CHANGES| F
    H -->|NEEDS_HUMAN| HAND
    H -->|APPROVE| I

    I{user-facing\nchange?}
    I -->|yes| J[user-journey-qa]
    I -->|no| K
    J -->|PASS| K
    J -->|FAIL| F

    K[workflow-finalize\nPR description · CI · reconcile\nrepo-policy-controlled merge]
    K --> L[cleanup-delivery\nbranch · worktree · issue close]
    L --> DONE([done])
```

**Model split**: implementation runs on Sonnet (fast). Review runs on Opus (judgment-heavy). Narration during the implementation loop is compressed ("caveman mode") — terse, no filler. Full prose returns for findings, blockers, and the final summary.

---

## AFK Batch: `run-backlog`

Batch-processes all `ready-for-agent` issues without human supervision.

```mermaid
flowchart TD
    A([run-backlog]) --> B[load outage-risk-policy\nload repo-delivery-policy]
    B --> C[fetch ready-for-agent issues]
    C --> D{dispatch mode}

    D -->|AFK default| E[omc team 1:codex\none context per issue\nnatural isolation]
    D -->|interactive| F[workflow-build-one\nsequential]

    E --> GATE
    F --> GATE

    GATE{outage risk?}
    GATE -->|AFK-safe| POL{repo policy}
    GATE -->|not AFK-safe| HAND([flag for human\nskip issue])

    POL -->|human-only repo| DRAFT([PR stays draft\nhuman reviews + merges])
    POL -->|auto-merge eligible| AUTO([auto-merge\nafter all gates pass])
```

Each issue gets its own context window via Codex dispatch — no cross-contamination between issues. The `outage-risk-policy` file (per-repo) determines AFK safety; a `priority` label cannot override it.

---

## Full PRD Tree: `execute-prd`

Drives an entire PRD from analysis through delivery — handles dependent, ordered, parent-aware execution.

```mermaid
flowchart TD
    A([parent PRD issue #N]) --> B[analyze children\norder by dependency graph]
    B --> C[generate execution brief\nfor each child]

    C --> LOOP

    subgraph LOOP [for each child issue]
        D[setup-worktree\nper-child isolation]
        D --> E[dispatch implementation\nSonnet worker]
        E --> F[workflow-review\nOpus]
        F --> G{verdict}
        G -->|APPROVE| H[workflow-finalize\nPR]
        G -->|NEEDS_HUMAN / blocked| HAND([handoff artifact\nhalt — wait for human])
        H --> NEXT{more\nchildren?}
        NEXT -->|yes| D
    end

    NEXT -->|no| I[reconcile-issues\nupdate parent issue state]
    I --> J[final handoff artifact\nwith all PRs + evidence]
    J --> DONE([done])
```

Each child issue gets its own worktree — parallel or sequential depending on dependencies. Every halt produces a handoff artifact that a fresh session can resume from cold.

---

## Bug Work: `workflow-debug`

Cardinal rule: **all bug work begins with `diagnose`**, no exceptions — even if the fix is obvious.

```mermaid
flowchart TD
    A([bug report]) --> B

    subgraph DIAG [diagnose — always first]
        B[Phase 1\nbuild a feedback loop\nreproduce reliably]
        B --> C[Phase 2\nminimise the case]
        C --> D[Phase 3\nhypothesise + rank causes]
        D --> E[Phase 4\ninstrument + test hypotheses]
        E --> F{root cause\nconfirmed?}
        F -->|no| D
        F -->|yes| G[Phase 5\nfix]
        G --> H[Phase 6\nregression test\nclean up instrumentation]
    end

    H --> ART[diagnosis artifact\ndocs/diag-date-slug.md]
    ART --> WR[workflow-review → workflow-finalize]
    WR --> DONE([PR + merged])

    B -.->|mode: quick\nskip ranking| G
    B -.->|mode: production\nread-only first\nrollback plan required| E
    B -.->|mode: regression\ngit bisect between\ngood and broken| C
```

The diagnosis artifact is evidence — it proves understanding and prevents wrong fixes. Modes: **quick** (single likely cause), **standard** (full loop), **deep** (extended instrumentation), **production** (read-only first, rollback required), **regression** (bisect from known-good).

---

## Review + Delivery

`workflow-review` and `workflow-finalize` are mandatory for every code change. Green CI, GitHub reviews, and PR comments do not substitute.

```mermaid
flowchart TD
    A([implementation complete]) --> B[workflow-review\nindependent gate\nnever the author reviewing own work]

    B --> RISK{change risk level}
    RISK -->|low: docs/config/wording| FAST[fast profile\n1 reviewer, Sonnet]
    RISK -->|normal: standard code| STD[standard profile\n1 independent reviewer, Opus]
    RISK -->|high: auth · data · infra\nmigrations · public APIs\nlarge diffs · concurrency| FULL[full profile\nmulti-lane, Opus\nsecurity + logic + tests + UX]

    FAST --> GATE[WORKFLOW_REVIEW_GATE block\nreview_profile · independent_review: true · verdict]
    STD --> GATE
    FULL --> GATE

    GATE --> V{verdict}
    V -->|REQUEST CHANGES| IMPL([back to implementation])
    V -->|NEEDS_HUMAN| HUMAN([surface to human])
    V -->|APPROVE| FIN

    subgraph FIN [workflow-finalize]
        F1[write PR description]
        F1 --> F2[resolve reviewer comments\nreceive-review + pr-responder]
        F2 --> F3[monitor CI]
        F3 --> F4[reconcile issues\nclose / update linked issues]
        F4 --> POL{repo policy}
    end

    POL -->|human-only| DRAFT([PR in draft\nhuman merges])
    POL -->|auto-merge eligible| MERGE([merge])
    MERGE --> CLEAN[cleanup-delivery\nbranch · worktree · issue close]
```

**workflow-finalize will not proceed** without a complete `WORKFLOW_REVIEW_GATE` block from an independent reviewer with `verdict: APPROVE`. If the change was made in the primary checkout instead of a worktree, it also halts.

---

## Handling Incoming Review: `receive-review` + `pr-responder`

When review comments land (bot or human), two skills work through the queue.

```mermaid
flowchart TD
    A([review comments land\nhuman or bot]) --> B

    subgraph RR [receive-review — evaluate each comment]
        B[read all open threads]
        B --> C{per comment}
        C -->|technically valid| ACT[action: fix code]
        C -->|invalid / conflicts with\nanother reviewer / wrong| PB[push back\nwith reasoning]
        C -->|needs product judgment\nor human decision| DEF[defer to human]
        C -->|nit / minor| NIX[acknowledge + minor fix]
    end

    ACT --> Q
    PB --> Q
    DEF --> Q
    NIX --> Q

    subgraph PR2 [pr-responder — process the queue]
        Q[batch all pending actions]
        Q --> R[draft code fixes\nfor actionable comments]
        R --> S{pushback replies?}
        S -->|yes| CONF([confirm with human\nbefore posting])
        S -->|no| T
        CONF -->|approved| T
        T[push fix commits\npost replies to all threads]
    end

    T --> U[workflow-review\nre-review after changes]
    U --> V([APPROVE → workflow-finalize])
```

`receive-review` evaluates correctness — it doesn't blindly agree. Suggestions that are technically wrong, conflict with other reviewers, or contradict project invariants get a reasoned pushback. Human reviewer disagreements surface to Alex before any reply goes out.

---

## Architecture + Codebase Work

```mermaid
flowchart LR
    RA[repo-audit\nmap-reduce investigation\nparallel Sonnet discovery\nOpus synthesis\nFIND-NN findings]

    RA --> RD[workflow-roadmap]
    RA --> PRD[to-prd]
    RA --> DP[design-plan]

    ICA[improve-codebase-architecture\ndeepening opportunities\ntestability + AI-navigability\nOpus]
    ICA --> DP

    DP --> EP2[execute-phase\none phase at a time\nwith review gate between]

    SC[slop-cleaner\ndocs mode: README / comments / runbooks\nanalysis mode: memos / findings / recs\nchange log + before/after word counts]
```

---

## Handoff: Universal Exit Protocol

Every workflow that halts with remaining work produces a **handoff artifact**. The handoff is what makes AFK execution recoverable — a fresh session can resume without rebuilding context.

```mermaid
flowchart TD
    ANY([any workflow halt]) --> WHY{exit reason}
    WHY -->|context limit| H
    WHY -->|human gate| H
    WHY -->|blocked dependency| H
    WHY -->|completion with remaining work| H

    H[handoff skill\ncreate artifact at\ndocs/executions/handoffs/date-slug.md]

    H --> CONTENTS["contents:\n• exit reason\n• current step ledger\n• remaining items\n• key decisions made\n• ready-to-use prompt\n  for next session"]

    CONTENTS --> TARGET{target tool}
    TARGET -->|Claude Code / pi| CLAUDE([write to docs/\nexecutions/handoffs/])
    TARGET -->|Codex| CODEX([write to project dir])
```

---

## Worktrees: Isolation Pattern

Every implementation runs in an isolated git worktree. `workflow-finalize` enforces this — it halts if the change was made in the primary checkout.

```mermaid
flowchart LR
    MAIN[origin/main\nclean baseline]

    MAIN -->|setup-worktree| WT1[~/wt/repo/issue-42-auth-fix\nbranch: fix/issue-42-auth]
    MAIN -->|setup-worktree| WT2[~/wt/repo/issue-55-metrics\nbranch: feat/issue-55-metrics]
    MAIN -->|setup-worktree| WT3[~/wt/repo/phase-2-refactor\nbranch: refactor/phase-2-...]

    WT1 -->|PR merged| MAIN
    WT2 -->|PR merged| MAIN
    WT3 -->|PR merged| MAIN

    WT1 -.->|cleanup-delivery\nafter merge| DEL1([deleted])
    WT2 -.->|cleanup-delivery\nafter merge| DEL2([deleted])
```

Each worktree records `WORKFLOW_BASE_GATE` + `WORKTREE_BASELINE_GATE` evidence before the first code change. Stacked worktrees (child branch targeting a parent branch) are allowed — `workflow-finalize` checks for `STACKED_WORKTREE_GATE` instead.

---

## Herdr: Workspace Layout

**herdr** is a terminal multiplexer + session manager. The `hdev` command creates a structured workspace:

```bash
hdev ~/projects/myapp          # full layout
hdev ~/projects/myapp --monitor  # gh-dash only
hdev ~/projects/myapp --minimal  # pi only
```

```mermaid
flowchart TD
    subgraph WS [herdr workspace — full layout]
        subgraph WORK [work tab]
            PI[pi\nleft pane\nopus + extended thinking]
            LG[lazygit\nright-top]
            YZ[yazi\nright-bottom\nfile browser]
        end
        subgraph GH [gh tab]
            DASH[gh-dash\nissues · PRs · CI]
        end
    end

    START([hdev project-dir]) --> WS
    WS --> SESSION[herdr registers session\nvia SessionStart hook\ndaemon tracks pane → agent mapping]
```

Every AI session (pi, Claude Code, Codex, opencode) registers with the herdr daemon on start. The daemon knows what's running in which pane — workspace-aware tooling.

---

## Pi Packages

26 packages. Grouped by what they enable:

**Codebase navigation**

- `pi-codemapper` — indexes the codebase (symbols, call graphs, dependencies); `map`, `search`, `outline`, `expand`, `path` operations
- `pi-lens` — LSP diagnostics, ast-grep structural search, tree-sitter rules; runs against the live language server

**Subagent orchestration**

- `pi-fork` — spawns subagents at configurable effort levels (fast/balanced/deep → haiku/sonnet/opus)
- `pi-taskflow` — orchestrates multi-agent DAGs (parallel branches, sequential chains, gated phases, map-reduce)

**Memory + context**

- `pi-observational-memory` — compresses session learnings into cross-session observations; runs on haiku
- `pi-context-cap` — warns approaching context limits
- `pi-context-inspector` — shows context composition

**Guardrails**

- `pi-dirty-repo-guard` — blocks writes on repos with uncommitted changes
- `pi-permission-gate` — confirmation prompts for destructive operations
- `pi-codex-goal` — tracks a concrete objective through multi-turn sessions

**Output efficiency**

- `pi-hypa` — compresses shell, read, grep, find, and ls output before it reaches context
- `pi-cache-optimizer` — prompt cache optimization
- `pi-better-messages-cache` — message-level caching
- `pix-optimizer` — token optimization pass

**Real-world integration**

- `pi-web-access` — web search and fetch
- `pi-agent-browser-native` — real Playwright-backed browser automation
- `pi-mcp-adapter` — MCP protocol bridge
- `@gotgenes/pi-github-tools` — GitHub MCP tools
- `pi-pr-ally` — PR review and response assistance

**Utility**

- `@narumitw/pi-caffeinate` — prevents macOS sleep during long AFK runs
- `@diegopetrucci/pi-notify` — macOS notifications when the agent needs input or completes

**Model roles**:

| Role | Model | Used for |
|---|---|---|
| fast | claude-haiku-4-5 | Quick lookups, memory compression, subagent fast mode |
| strong / thinker / vision | claude-sonnet-4-6 | Normal exploration, implementation, most subagent work |
| arbiter / reasoner | claude-opus-4-5 | Review, architecture decisions, high-stakes judgment |

**Fork effort → model**:

| Effort | Model | Thinking |
|---|---|---|
| `fast` | haiku-4-5 | off |
| `balanced` (default) | sonnet-4-6 | low |
| `deep` | opus-4-5 | medium |

---

## Claude Code Plugins

25 plugins. Active ones:

| Plugin | What it adds |
|---|---|
| `context7` | Fetches up-to-date library docs mid-session |
| `typescript-lsp` | TypeScript language server — inline errors, go-to-def, rename refactor |
| `pyright-lsp` | Python language server via Pyright |
| `playwright` | Browser test generation and execution |
| `oh-my-claudecode` | HUD status line, session telemetry, team dispatch (AFK batch) |
| `remember` | Persistent session memory across sessions |
| `superpowers` | Extended tool capabilities |
| `code-simplifier` | Surfaces complexity hotspots |
| `data-engineering` | Data pipeline and SQL tooling |
| `frontend-design` | UI/design guidance |
| `git-cleanup` | Dead branches and stale ref cleanup |
| `skill-creator` | Scaffolds new skills |
| `agent-sdk-dev` | Agent SDK development helpers |
| `claude-md-management` | CLAUDE.md context file management |
| `slack` | Slack integration |

---

## The Status Bar

Bottom of every session: **omc HUD** (oh-my-claudecode). Shows token usage, model, and session state. Cache-backed — only re-reads state when something changes.

---

## MCP Server: gbrain

Local MCP server (`~/gbrain-repo`) providing a knowledge graph interface. Runs via bun. Registered in `settings.local.json` (machine-local, not stowed). Gives any session structured query access to a personal knowledge graph.

---

## Idea Capture

```bash
idea "build a metrics alerting layer"   # AI-enriched capture
idea -q "quick note"                    # skip enrichment
```

Calls claude-haiku-4-5 to classify (tool/app/research/business/experiment/...), write a one-sentence pitch, generate tags, and suggest 3 concrete next steps. Result lands as structured frontmatter Markdown in `~/Documents/Home/Idea Bin/`. Fast enough to capture before the thought is gone.

`ideas review` and `ideas promote` move ideas through the downstream pipeline.

---

## Observability

**Langfuse** at `192.168.4.43:3050` (home network) receives traces from every Claude session. Token usage, tool calls, session duration, and model spend visible in a dashboard on the home network.

**pi-observational-memory** produces per-session compressed observations that persist across context resets — a navigable log of what was learned, decided, and done.

---

## Shell + Git

**ZSH** — minimal, modular, no oh-my-zsh. Modules load in order: configs → tools → theme.

**Key tools**:

| Tool | Replaces | Purpose |
|---|---|---|
| `eza` | `ls` | Icons, color, git status |
| `bat` | `cat` | Syntax highlight, line numbers |
| `rg` (ripgrep) | `grep` | Fast search |
| `fd` | `find` | Simpler syntax |
| `fzf` | — | Fuzzy picker for git, branches, history |
| `zoxide` (`j`) | `cd` | Frecency-based directory jump |
| `atuin` | shell history | Cross-session SQLite, Ctrl-R fuzzy |
| `starship` | PS1 | Git-aware prompt |
| `delta` | git diff pager | Side-by-side, line numbers |
| `lazygit` | git CLI | Terminal git UI |

**Git config**:

- `pull.rebase = true`, `fetch.prune = true`, `rebase.autoStash = true`, `push.autoSetupRemote = true`
- Global gitignore: macOS artifacts, Python/JS/TS build output, `.env*`, AWS credentials, Terraform state, `.omc/`, `.serena/`, `**/.claude/settings.local.json`
- Conventional commits via pre-commit hook (`commit-normalize.sh`) in any repo with `pre-commit install`

---

## Fresh Machine Bootstrap

```bash
git clone git@github-personal:johnalexwelch/dotdev.git ~/dotdev
cd ~/dotdev && bash install.sh
# DRY_RUN=1 bash install.sh   → preview without executing
```

Sequence: Homebrew → config dirs (prevents stow tree-folding) → GitHub SSH → macOS defaults → GNU Stow symlinks → guardian clone + compile → gbrain clone → pi packages → herdr integrations.

One manual step post-install: `~/.claude/settings.local.json` is created from template — contains the gbrain MCP path. All credentials are flat files in `$HOME` sourced by `env.zsh`; drop a file and it gets picked up on next shell start.
