# Architecture: System Design

The dotdev environment is built on three pillars: **hooks** (safety), **routing** (classification), and **skills** (execution). This page explains how they fit together.

---

## The Hook Pipeline

Every Bash command passes through two safety layers: **PreToolUse** (before execution) and **PostToolUse** (after every edit/write).

### PreToolUse: Guardian + Workflow Guard

```
[Agent issues Bash command]
      ↓
  [guardian — haiku model]
  - Reads session context
  - Evaluates command intent
  - Applies rule set
  - Returns: allow | block | ask
      ↓
  [workflow-guard — pure Bash]
  - If allow: checks repo protocol
  - Blocks certain repo-specific patterns
      ↓
  [command executes]
```

#### Guardian (Real-time Intent Evaluation)

- **Language**: TypeScript, precompiled to `dist/cli.js`
- **Model**: claude-haiku-4-5 (real-time hook, ~200ms latency)
- **Inputs**: Command text, session history, agent goal, context
- **Outputs**: `allow` (silent), `block` (exit 2 + logged), `ask` (surface to human)
- **Why precompiled**: Previously used tsx (JIT) — saving ~200ms per call. Also eliminated esbuild transitive CVE.
- **Auto-recompile**: PostToolUse detects `guardian/*.ts` changes, runs `npx tsc`, reports failures loudly

The guardian is **always-on** and runs on every command. It's fast enough to not interrupt flow but accurate enough to block dangerous patterns (e.g., `git push --force`, `rm -rf /`, dangerous environment mutations).

#### Workflow Guard (Pure Bash)

Enforces workflow protocol without an LLM:

- **Pre-execution**: Blocks `ready-for-agent` label on PRD-parent issues (only children can be ready)
- **Post PR open**: Warns not to claim CI success from exit code alone; CI is the source of truth
- **Post PR merge**: Runs `git status` + `git worktree list`, prompts `cleanup-delivery` skill

### PostToolUse: Linting, Secrets, Guards

Fires on every `Edit` or `Write` file operation:

```
[command executes or file is edited]
      ↓
  [auto-lint]
  - ruff for .py files
  - eslint for .ts files
      ↓
  [secret scan]
  - Detects API keys, private key headers
  - Alerts on found patterns
      ↓
  [file-size guard]
  - Warns if file > 300 lines
      ↓
  [guardian recompile check]
  - If guardian/*.ts changed: runs npx tsc
  - 30-second timeout; reports stale dist/ loudly
      ↓
  [workflow-guard post-checks]
  - PR open → surface reviewer-comment reminder
  - PR merge → cleanup prompt
```

---

## Workflow Routing: `workflow-router`

The **single routing authority** for all incoming work. Nothing bypasses it.

### Classification

workflow-router classifies the task into one of these categories:

| Category | Example | Routed to |
|----------|---------|-----------|
| Trivial / no delivery gate | "add a comment", "generate docs" | direct execution |
| Single ready-for-agent issue | GitHub issue #42 labeled ready-for-agent | workflow-build-one |
| Batch of ready issues | Multiple #ready-for-agent issues | run-backlog (AFK) |
| Vague feature idea | "dark mode toggle" | workflow-feature → triage → issues |
| Bug report | "app crashes on startup" | workflow-debug |
| Full PRD tree | Parent issue #N with children | execute-prd |
| Refactor / migration | "move from X to Y" | design-plan → execute-phase |
| Codebase audit | "understand the state of X" | repo-audit |
| OMC keyword shortcuts | `autopilot`, `ralph`, `ultrawork` | skip router classification; still require workflow-review + workflow-finalize |

### ROUTE_CARD

After classification, router emits a **ROUTE_CARD** — a structured summary of:

- **Task classification**
- **Proposed workflow** (which skill will handle it)
- **Preflight findings** (dependencies, AFK safety, repo state)
- **Budget** (one-reviewer vs multi-lane vs team)
- **Human confirmation needed?**

The human confirms the route before execution proceeds.

### Resume Check

At startup, router checks for an in-progress run in `docs/executions/state.yaml`:

- If `status: active|paused`: Show its step ledger, ask to resume or start fresh
- On **resume**: Skip re-classification and re-preflight; dispatch to the actual frontier (verified against git worktree state)
- On **start fresh**: Overwrite state file and proceed normally

---

## Step Ledgers

Every workflow maintains a **living step ledger** — a table capturing required/optional steps, their status, and evidence.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|--------|
| Step 0: Preflight | required | completed | - |
| Step 1: Execute | required | in-progress | commit abc123 |
| Step 2: Review | required | pending | - |
```

Rules:

- Initialize all steps as `pending`
- Update to `completed`, `skipped`, `blocked`, or `failed` as they resolve
- **Required steps cannot be skipped** — they become `blocked` and the workflow halts
- Include the final ledger in every halt, handoff, and completion

The ledger is **proof of work**: a future agent can see what was attempted, what succeeded, and what was deferred.

---

## Gate Blocks

Critical workflow decisions surface as **gate blocks** — structured Markdown that captures the decision, evidence, and verdict.

### Examples

#### WORKTREE_BASELINE_GATE

Proves that `setup-worktree` ran and recorded a clean baseline:

```markdown
WORKTREE_BASELINE_GATE:
  worktree: ~/wt/issue-123
  base_branch: origin/main
  base_sha: abc123def456
  status: clean (no uncommitted changes)
  time: 2026-01-15T10:30:00Z
```

#### WORKFLOW_REVIEW_GATE

Independent review verdict after code review:

```markdown
WORKFLOW_REVIEW_GATE:
  review_profile: standard
  independent_review: true
  reviewer_model: opus
  verdict: APPROVE
  findings: [list of concerns addressed, clarity notes]
  evidence_link: [PR link or review comment link]
  time: 2026-01-15T12:45:00Z
```

#### WORKFLOW_FINALIZE_GATE

Proof that delivery is complete:

```markdown
WORKFLOW_FINALIZE_GATE:
  pr_number: 1234
  pr_url: https://github.com/johnalexwelch/dotdev/pull/1234
  ci_status: PASSED
  merged_at: 2026-01-15T14:00:00Z
  merged_by: claude-opus-4-5
  base_branch: main
  linked_issues_closed: [#42, #43]
  cleanup_status: completed
```

**Gate blocks are not prose claims.** When a workflow says "review is done", the presence of a `WORKFLOW_REVIEW_GATE` block with `verdict: APPROVE` is the evidence, not a prose statement.

---

## The Skills Library

~90 executable playbooks in `~/.config/agents/skills/`. Each is a Markdown file with:

```yaml
---
name: skill-name
model: sonnet | opus | haiku
reasoning: high | medium | low
description: 'Single-quoted description used in discovery'
---

# Skill Name

## Purpose
Concise explanation of when to use this.

## When to invoke
Conditions that trigger this skill.

## Process / Steps
Step-by-step playbook.

## Step Ledger (if multi-step)
Table of required/optional steps.

## Gate Blocks (if decision-heavy)
Structured evidence blocks.
```

### Skill Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| **Workflow orchestration** | Routing, phases, delivery | workflow-router, execute-phase, workflow-finalize |
| **Implementation** | Writing code | implement, tdd, prototype |
| **Review & validation** | Code, design, data | workflow-review, clarity-review, pr-review |
| **Analysis & design** | Planning, decisions | grill-with-docs, design-plan, repo-audit |
| **Domain-specific** | Metrics, incidents, product | metric-design, incident-triage, okr-generator |
| **Operations** | Git, config, setup | git-guardrails, setup-worktree, cleanup-delivery |

### Skill Naming Convention

- **Workflow skills** start with `workflow-`: workflow-router, workflow-build-one, workflow-finalize
- **Phase skills** start with `execute-`, `setup-`, `design-`: execute-phase, setup-worktree, design-plan
- **Domain skills** name the area: metric-design, incident-triage, okr-generator
- **Generic skills** are descriptive: grill-with-docs, clarity-review, handoff

### Skill Loading

When any prompt, transcript, or agent memory **names a skill** (e.g., "run workflow-finalize"), the skill's `SKILL.md` **must be loaded and followed**, including all required gate blocks.

**Key rule**: A prose claim that a skill ran (or "basically ran") without its gate block present in the output means it did **not** run.

---

## Concurrency & Worktree Safety

### Worktrees

Each workflow or issue gets an **isolated git worktree** created by `setup-worktree`:

```bash
# Creates ~/wt/issue-123 with isolated branch from origin/main
setup-worktree --issue 123 --base origin/main
```

Benefits:

- **Isolation**: Each work item has its own branch and directory
- **Parallelism**: Multiple issues can execute in parallel without interfering
- **Safety**: Primary checkout remains clean; all work lives in `~/wt/`

Every skill that runs code records the worktree in its gate block.

### Concurrency Guards

The system enforces several rules to prevent race conditions:

1. **Worktree baseline gate** (`setup-worktree`): Proves clean baseline before starting work
2. **Per-lane worktree precondition** (`workflow-router`): Each execution gets its own worktree
3. **Git status checks** (pre and post): Verify no uncommitted changes between phases
4. **Conflict resolution** (`resolving-merge-conflicts` skill): Structured merge conflict handling

---

## Model Selection

The environment uses different models for different phases:

| Phase | Model | Reasoning | Purpose |
|-------|-------|-----------|---------|
| **Real-time hooks** | haiku-4-5 | low | Fast guardian evaluation (~200ms) |
| **Implementation** | sonnet-4 | medium | Balanced speed/quality for writing code |
| **Review** | opus-4-5 | high | Careful judgment; never author reviewing own work |
| **Analysis/design** | opus-4-5 | high | Complex problem-solving (grills, audits) |

Workflow-build-one uses **model split**: Sonnet for mechanical implementation, Opus for design/review reasoning around it.

---

## Narration Modes

### Full Prose (Default)

Standard communication — used for findings, blockers, decisions, final handoffs, and anything that needs judgment.

### Caveman Mode (Implementation Loop)

Compressed narration during mechanical execution/implementation:

- Drop articles: "The dog runs" → "Dog runs"
- Drop filler: "It seems that the system is working" → "System working"
- Drop pleasantries: "Let me now try" → "Trying X"
- Prefer: `[thing] [action] [reason]. [next].`

Caveman mode cuts scroll and token usage during the grind. **Full prose returns** when execution ends; don't carry terse style into review or handoff.

---

## Execution Safety

### AFK Safety

Some issues can execute autonomously (AFK — away from keyboard) if they meet safety criteria:

- **Low risk**: docs, config, comments, tests
- **Medium risk**: internal code, non-public APIs, non-customer-facing
- **High risk**: auth, data mutations, public APIs, migrations, dependency bumps

`outage-risk-policy` (per-repo) determines AFK eligibility. Even AFK-safe issues still require `workflow-review` + `workflow-finalize`.

### Approval Gates

Certain workflow actions require human approval:

- **Ready-for-agent designation**: Grill → to-prd → to-issues → triage (human approval between each)
- **Route confirmation**: workflow-router shows ROUTE_CARD, waits for human confirm
- **Review verdict**: workflow-review requires independent reviewer approval to proceed
- **High-risk merges**: Human-only repos don't auto-merge; humans click the button

---

## Source References

- **Guardian**: `~/.claude/hooks/pre-tool-use.ts`
- **Workflow-guard**: `~/.claude/hooks/workflow-guard.sh`
- **Skills library**: `~/.config/agents/skills/`
- **Hook configuration**: `~/.claude/settings.json`, `~/.pi/agent/settings.json`
- **State tracking**: `docs/executions/state.yaml` (schema in `~/.config/agents/skills/_docs/state-cockpit.md`)

