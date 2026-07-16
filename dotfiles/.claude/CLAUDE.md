<!-- OMC:START -->
<!-- OMC:VERSION:4.14.4 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>

- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
Every dispatched agent gets an explicit completion contract: changes committed AND pushed, gates verified (lint/type/tests green), a one-line PASS/FAIL verdict, and the PR number reported. If blocked, stop and report the exact blocker — never leave staged-but-uncommitted work.
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.
<!-- OMC:END -->

<!-- User customizations -->
# Code standards (on-demand)

Language/stack coding standards are **not** auto-loaded into every session (they're waste in DnD, writing, and analysis sessions). When doing code work, read the relevant file(s) from `~/.claude/code-standards-reference/`:

- `python.md`, `typescript.md` — language conventions
- `api-design.md` — error envelopes, pagination, retries, versioning
- `dependencies.md` — pinning, lockfiles, when to add a dep
- `logging.md` — logger setup, levels, what not to log

Universal rules (git, security, coding-standards, task-context) remain in `~/.claude/rules/` and auto-load. The workflow loop map moved to `~/.claude/reference/workflows.md` (on-demand) — the `workflow-router` skill is the live routing authority and fires regardless; read the reference only when you need the full route table.

# graphify

- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

# Check for existing solutions first (prior-art check)

Before building anything custom — integration, plugin, wrapper, helper, script, config glue — first check if someone already solved it. Building custom when an off-the-shelf solution exists is the default failure mode.

**Required check order before writing code:**

1. **Official extensions/plugins** for the tool in play (e.g. `pi-extension-*`, `claude-*`, `vscode-*`, language package registries). Search the tool's docs, GitHub org, and npm/pypi/cargo by the obvious name.
2. **Repo + dotfiles search** — `rg`/`grep` for the integration name across `~/dotdev`, `~/.claude`, `~/.pi`, current repo. Often already wired.
3. **Web search** with `[tool A] [tool B] integration` and `[tool A] extension for [tool B]` — at least one query before custom work.
4. **Ask the user** if a quick search returns ambiguous candidates rather than guessing.

**Only build custom when:** prior-art search came back empty OR existing solution is materially inadequate (state why in one line). Cite what was checked.

Example failure to avoid: hand-rolling Pi↔Headroom glue when `pi-extension-headroom` already exists. Always check `pi-extension-*` namespace before custom Pi integrations.

# Delivery routing (apply before any code edit)

Any request that will result in a commit or push to tracked code must be routed through `workflow-router` before the first code edit. Do not start delivery work in the primary checkout or on `main` — cut a worktree from the workflow base and land via a PR, even when CI is disabled/manual-only (the PR is the review/merge boundary regardless of automated checks). A code-delivery task is never the `direct` budget.

# Fable-style working habits (apply every session)

Derived from measured Fable-corpus vs Opus behavioral analysis (`~/.cora/session-playbooks/fable-style-opus/`).
Fable completes tasks in ~14 turns vs Opus ~17; 43% cheaper per task at same prices.

1. **Inspect before editing** — read relevant files/symbols before first mutation.
2. **Plan briefly** before first tool call when task has more than one step.
3. **Batch related reads**, then make the smallest surgical edit that satisfies the task.
4. **Tight tool cadence** — precise reads, one focused edit, one focused check.
5. **Verify after edits** — run the smallest meaningful check.
6. **Reassess on failure** — diagnose cause before trying another edit.
7. **Cite evidence before claiming done** — command output, test result, diff, or file line.
8. **No unnecessary scaffolding** — avoid new deps, hooks, or global config changes unless the task proves it needs them.
