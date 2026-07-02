# How Alex Welch Works with AI

> The goal of this setup is one thing: **make AI a reliable coworker, not a chatbot.** Every piece of infrastructure exists to close the gap between "this feels useful" and "I can depend on this."

---

## The Mental Model

The setup treats AI as a personal org of specialists — each one owns a domain, holds memory about it, and operates under clear boundaries. The overall system is called **CHORUS** (*Coordinated Hub Of Reasoning & Unified Specialists*). CHORUS is not an agent itself; it's the constitution — the shared contracts, trust rules, and registry that all agents operate under.

The daily reality is simpler than it sounds: most work happens in **pi** (a local AI coding agent) through **Claude Code** (Anthropic's agentic tool), with a library of skills that route different kinds of work through structured playbooks. The fleet of named agents (Mira, Iris, Cora, etc.) backs the bigger workflows. They connect through a file-based protocol, not API calls.

---

## The Agent Fleet

Eight agents, each with a charter — a defined mission, owned responsibilities, and explicit anti-scope (what they *don't* own). The registry is the single source of truth.

| Agent | Role | Trust Domain | What they do |
|---|---|---|---|
| **Mira** | COO / Chief of Staff | Operator-sensitive | Brokers cross-domain work, maintains prioritized stream to Alex, advises and coordinates. Broker, not warehouse — she routes, doesn't hoard. |
| **Iris** | Analytics / CDO | Work-confidential | Warehouse-validated metrics, WBR numbers, ClassDojo analytics. Separate identity, never co-mingled with personal data. |
| **Cora** | CTO / Principal Engineer | Infrastructure | Operates the platform — runtimes, homelab, NAS, the guardian, the watchdog. Custodies no other domain's data. |
| **Rowan** | Knowledge / Second Brain | Low-sensitivity | Maintains the curated knowledge corpus. Ingestion, review queue, concept page curation. |
| **Cleo** | CFO | Operator-sensitive | Household finance, budgeting, transactions. |
| **Nora** | Nutritionist | Operator-sensitive | Nutrition planning, dietary tracking, meal guidance. |
| **Wren** | Lorekeeper / Creative | Low-sensitivity | Creative writing, D&D canon. |
| **Aria** | Transcription | Low-sensitivity | Audio transcription and processing. |

**The key design choice**: agents are partitioned by *data sensitivity and credentials*, not by work-vs-life. This means Iris never touches personal data, Cleo never touches work financials, and a breach in one domain stays small. Credentials never cross domain boundaries; data crosses only by explicit, logged, approved request.

**Mira's role specifically**: she's the COO — strategic coordination, one prioritized stream to Alex, the lens through which cross-domain decisions flow. She doesn't own execution; she owns the perspective that makes execution coherent. Coordination is a function she *performs*, not her identity.

**Cora's role specifically**: she's the CTO — she builds, runs, monitors, and operates the technical substrate. She operates the shared infrastructure (guardian, watchdog, homelab) but *CHORUS governs* that infrastructure. Cora enforces the standards; she doesn't define them.

---

## The Trust Model

Every agent operates on a graduated-autonomy ladder:

- **Tier 1 — Reads**: run autonomously, no approval needed
- **Tier 2 — Routine internal actions**: run under a signed standing policy
- **Tier 3 — Outward, irreversible, or cross-domain**: require Alex's per-action signed consent

The signing key never lives in an agent. No agent can forge Alex's approval. Everything logs to a Mira-independent audit trace. There's a fail-closed kill switch (`chorus halt --level soft/medium/hard`).

The `protocol_safety` field in `registry.yaml` is a governed switch — while `false`, agents refuse all Tier-2/3 traffic. It's a Forever-Rung-0 field: only changed by human-reviewed PR, never by any agent.

---

## The Daily Toolchain

### pi + Claude Code

The primary interface for all AI-assisted work. **pi** is a local coding agent harness that wraps Claude Code (opus 4.5, extended thinking always on). Every interaction goes through pi — coding, planning, research, writing, execution.

Key configuration choices:
- **All permissions open by default** (`Bash(*)`, `Read`, `Write`, `Edit`, `WebFetch`, `WebSearch`, plus all agent/cron/worktree primitives). The guardian enforces safety; the permissions list is not the control surface.
- **Hard denies baked in**: `sudo *`, `git push --force *`, `rm -rf /`, `rm -rf ~*` — these never run regardless of what an agent requests.
- `skipDangerousModePermissionPrompt: true` — removes interrupt friction for known-safe operations.

### The Guardian

Every `Bash` call goes through the guardian *before* execution. The guardian is a TypeScript LLM layer (claude-haiku-4-5 for speed, ~200ms hot path) that evaluates the command against the current session context and a rule set.

Three outcomes: **allow** (silent proceed), **block** (hard exit 2, with reason), **ask** (surface to Alex). The guardian sees the full command, the session context, and the rules. It isn't a regex filter — it reasons about intent.

Why haiku and not opus? The guardian runs on every Bash call. Correctness matters; latency matters too. Haiku is fast and cheap; the rules and context give it enough signal to be accurate on the things that count.

The guardian compiles to `dist/cli.js` (precompiled TypeScript, no JIT). When any guardian source file changes, a PostToolUse hook runs `npx tsc` automatically and reports failure loudly if the build breaks. No stale code, no silent failures.

### Workflow Guard

A second pre/post hook written in pure Bash (no LLM, no latency). It enforces CHORUS-specific workflow rules:

- **Prevents PRD-parent issues from being labeled `ready-for-agent`** — PRDs are the spec; child implementation issues get that label. Checked by regex against the `gh` command and the issue body before it executes.
- **After a PR is opened or set to ready**: reminds the agent not to claim CI success from exit code alone — every PR needs local validation evidence.
- **After a PR is merged or closed**: runs `git status` + `git worktree list` and tells the agent to load the `cleanup-delivery` skill before deleting anything.

### PostToolUse Hooks

Every file write or edit triggers three additional checks:

1. **Auto-linting**: `ruff` for Python, `eslint` for TypeScript — run and fix automatically, no prompting.
2. **Secret scan**: greps for API key patterns, private key headers, hardcoded passwords. Warns if found.
3. **File size guard**: warns at 300 lines. The system nudges toward small files by design.

---

## The Skills Library

~70 skills stored in `~/.claude/skills/` (stowed from dotdev). Skills are Markdown files with YAML frontmatter that invoke structured playbooks — they're not just prompts, they're *protocols* with contracts, step ledgers, human gates, and handoff requirements.

Every skill that has multi-step work produces a **step ledger** at the start:

```
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| diagnose | required | pending | - |
| fix     | required | pending | - |
| verify  | required | pending | - |
```

Steps can't be skipped silently. A required gate that can't run is `blocked`, not `skipped`.

### The Workflow Stack

Work typically flows through connected skills. A feature idea:

```
grill-with-docs         (stress-test the idea against docs)
    → decision-log      (record the architectural choice)
    → [prototype]       (optional quick spike)
    → workflow-roadmap  (approval gate with Alex)
    → to-prd            (write the PRD → GitHub Issue)
    → to-issues         (decompose into vertical implementation slices)
    → triage            (classify, label, brief each issue)
    → execute-prd       (implement each child issue with a worktree + PR)
```

A bug:

```
workflow-debug
    → diagnose          (always first, no exceptions)
    → fix
    → verify            (regression test)
    → PR
```

The cardinal rule of `workflow-debug`: *bugs always begin with diagnose*. Even if the fix is obvious. The diagnosis artifact is evidence — it proves understanding and prevents wrong fixes.

### Key Skills

**`brain-ops`** — interact with the second brain (`~/Documents/Home/_brain/`). Ingest a source, query a concept, capture a thought, run the review queue, lint the brain. Rowan is the agent that owns this domain; `brain-ops` is the capability that runs inside it.

**`handoff`** — compress a session into a structured handoff document. Every workflow that halts with remaining work must produce a handoff. The handoff contains: exit reason, remaining items, current state, and a ready-to-use prompt for the next session.

**`execute-prd`** — drive a full PRD issue tree from analysis through delivery. Creates worktrees, implements each child issue in isolation, opens PRs, runs review/CI, reconciles, writes handoffs. Dispatches implementation workers on Sonnet; reserves Opus for planning and review.

**`setup-worktree`** — creates an isolated git worktree for a plan phase or issue. Every implementation starts in a clean worktree so in-progress work never contaminates the main branch or other in-flight work.

**`triage`** — routes issues through a state machine (`needs-triage` → `needs-info` → `ready-for-agent` → `ready-for-human` → `wontfix`). Writes durable agent briefs that any agent can pick up cold. Every triage comment is labeled "generated by AI."

**`cleanup-delivery`** — post-merge cleanup: branch deletion, worktree removal, issue close, artifact archival. The workflow-guard hook triggers it explicitly after every `gh pr merge`.

**`herdr-launch`** — opens a herdr workspace for a project. Pairs with `hdev` for the terminal experience.

---

## The Second Brain

`~/Documents/Home/_brain/` — a structured knowledge vault that Rowan maintains. The `idea` function in `.zshrc` is the primary capture path:

```bash
idea "build a metrics alerting layer"
```

This calls `claude-haiku-4-5` to classify the idea (tool/app/research/business/experiment/...), write a one-sentence pitch, generate tags, and suggest 3 concrete next steps. The result lands as a structured Markdown file in `~/Documents/Home/Idea Bin/`. No clipboard, no friction, captured before it's lost.

`idea -q "quick thought"` skips the AI enrichment for speed.

`ideas review` and `ideas promote` move ideas through the idea-os pipeline (via `~/projects/idea-os`).

---

## Herdr — Workspace + Session Tracking

**herdr** is a terminal multiplexer layer that tracks which agent session is running in which pane. When a pi/Claude Code/Codex/opencode session starts, herdr registers it (via the `herdr-agent-state.sh` SessionStart hook). The herdr daemon knows what's running where.

Workspace launchers:
- `hdev <path>` — open a herdr workspace in a directory
- `chorus`, `cora`, `mira` — shortcut aliases to canonical project dirs

Two plugins extend herdr:
- **fresh-worktree** — creates a clean worktree pre-attached to a herdr pane
- **herdr-plus** — extended herdr utilities

---

## The Status Line

At the bottom of every Claude Code session: an **omc HUD** (oh-my-claudecode) that shows token usage, model, and session state. It's cache-backed — the HUD script only re-reads state when something changes, not on every keystroke.

---

## Observability

**Langfuse** runs on the home network at `192.168.4.43:3050`. Every Claude session traces to it (`TRACE_TO_LANGFUSE=true`). On the home network, this gives full visibility into token usage, session duration, tool call patterns, and model spend across all sessions.

**Herdr's session registry** gives pane-level context: what's running, in what workspace, for how long.

**pi's observational memory** (pi-observational-memory) compresses session context into cross-session observations — learnings that survive context window resets. Compression runs on haiku-4-5 (cheap).

---

## Pi Package Architecture

26 packages loaded into pi, organized by purpose:

**Core reasoning + navigation**:
- `pi-codemapper` — index + navigate codebases (symbols, dependencies, call graphs)
- `pi-lens` — LSP diagnostics, ast-grep structural search, tree-sitter rules
- `pi-observational-memory` — cross-session memory via compressed observations
- `pi-fork` — spawn subagents at configurable effort levels (haiku/sonnet/opus)
- `pi-taskflow` — orchestrate multi-agent DAGs (parallel, sequential, gated)

**Context discipline**:
- `pi-context-cap` — warns when approaching context limits
- `pi-context-inspector` — shows context composition
- `pi-dirty-repo-guard` — blocks writes on dirty repos
- `pi-permission-gate` — confirmation prompts for destructive actions

**Output efficiency**:
- `pi-hypa` — compresses shell/read/grep/find/ls output before it hits the context
- `pi-cache-optimizer` — prompt cache optimization
- `pi-better-messages-cache` — message-level cache performance
- `pix-optimizer` — token optimization

**Real-world integration**:
- `pi-web-access` — web search + fetch
- `pi-agent-browser-native` — real browser automation (Playwright-backed)
- `pi-mcp-adapter` — MCP protocol bridge
- `@gotgenes/pi-github-tools` — GitHub MCP tools
- `pi-pr-ally` — PR review + response

**Model roles (what each tier runs on)**:
| Role | Model |
|---|---|
| fast | claude-haiku-4-5 |
| strong, thinker, vision | claude-sonnet-4-6 |
| arbiter, reasoner | claude-opus-4-5 |

Fork efforts (subagents):
- `fast` → haiku, no thinking
- `balanced` → sonnet, low thinking (default)
- `deep` → opus, medium thinking

---

## MCP Servers

**gbrain** — a local MCP server for knowledge graph queries, running the garrytan/gbrain server via bun. Lives at `~/gbrain-repo`, registered in `settings.local.json` (machine-local, not stowed). Gives any Claude session structured access to a knowledge graph layer.

---

## The Worktree Pattern

Every non-trivial implementation runs in an isolated git worktree (`~/wt/<repo>/<branch-slug>/`). This means:

- The main branch is always clean
- Multiple in-flight features coexist without conflict
- A failed branch just gets deleted — no cleanup of the working tree
- herdr can pin a pane to a specific worktree

The `setup-worktree` skill handles the mechanics. The `execute-prd` skill uses worktrees for every child issue in a PRD execution.

---

## What This Enables

A typical flow for a real feature:

1. **Capture**: `idea "build X"` → enriched note in Idea Bin
2. **Brief**: open pi in the relevant project, load `workflow-feature`
3. **Grill**: `grill-with-docs` stress-tests the idea against existing docs and decisions
4. **Approve**: `workflow-roadmap` produces a milestone-level plan; Alex approves the scope
5. **PRD**: `to-prd` writes the PRD as a GitHub Issue
6. **Issues**: `to-issues` decomposes into vertical implementation slices
7. **Triage**: `triage` classifies, labels, and writes agent briefs for each issue
8. **Execute**: `execute-prd` (AFK-safe) takes it from there — worktrees, branches, PRs
9. **Review**: workflow-guard checks every `gh pr` action; agent produces evidence, not just exit codes
10. **Close**: `cleanup-delivery` handles the post-merge housekeeping

At every halt (context limit, human gate, blocked dependency), the running skill produces a `handoff` artifact — a document that lets a fresh session continue exactly where things stopped, with no context rebuild.

---

## Design Philosophy

**The system is built behind real workflows, not ahead of them.** Every piece of infrastructure was added because a specific, real workflow demanded it — not speculatively. The CHORUS decision log (F1–F60+) records every design choice and the alternatives that were rejected.

**Isolation by default, coordination by exception.** Agents work independently in their domains. Cross-domain work is explicit, logged, and brokered through Mira. A compromise in one agent's domain stays small.

**Agents have anti-scope.** Every charter includes what the agent *does not own* — and who picks that up. This eliminates the "who handles this?" question that breaks every multi-agent system.

**Humans stay in the loop on the right things.** Reads are autonomous. Routine internal actions run under standing policy. Outward, irreversible, or sensitive actions need Alex's signed consent. The signing key is never in an agent.

**The workflow is the product.** Skills aren't just prompts — they're executable specifications with contracts, step ledgers, human gates, and handoff requirements. A skill that halts leaves evidence. A skill that completes leaves proof.
