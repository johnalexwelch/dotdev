---
name: workflow-router
description: Single authoritative entry point for classifying work and routing to the correct workflow skill
---

# Workflow Router

## Purpose

The single routing authority for all incoming work. Classifies the task, runs preflight checks, and dispatches to the appropriate workflow skill. Replaces ad-hoc routing decisions with a consistent classification system.

## Authority

This skill is the **sole routing authority**. Per ADR-0002:

- `workflows.md` is reference documentation only — it does not route
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass this router's classification step only. Any mutating code, commit, PR, or delivery action reached through those shortcuts must still satisfy `WORKTREE_BASELINE_GATE`, `workflow-review`, and `workflow-finalize`.
- All other work goes through this router

## Classification table

| Signal | Classification | Routes to |
|--------|---------------|-----------|
| "build a V1", "turn this idea into a V1", "shape this product idea", "define the MVP", loose product idea needing functionality details | **V1 idea discovery** | v1-idea-grill |
| Approved `V1_IDEA_BRIEF`, "design the system for this V1", "turn this V1 brief into architecture", "system design for V1" | **V1 system design** | v1-system-design |
| "roadmap", "what should we build next", "feature gaps", "implementation gaps", "hardening roadmap", "product and implementation plan", multi-area sequencing across product/security/infrastructure | **product/engineering roadmap** | workflow-roadmap |
| "autonomous module discovery", "find modules and create PRDs", "action the backlog AFK", "run backlog without outages", "autonomous backlog" | **autonomous backlog workflow** | workflow-autonomous-backlog |
| Bug report, error, "it's broken", regression | **bug** | workflow-debug |
| Vague idea, "what if we...", "I want to build..." | **ambiguous feature** | workflow-feature |
| Issue with `ready-for-agent` + clear acceptance criteria | **ready issue** | workflow-build-one |
| Parent PRD issue with child issues, "execute this PRD", "implement all children of #N", "work through this parent issue", "execute the issue tree" | **PRD execution** | execute-prd |
| Multiple ready issues, "run the backlog", AFK batch | **AFK backlog** | run-backlog |
| "Audit the repo", "state of repo", broad evidence gathering needed | **repo evidence audit** | repo-audit → workflow-roadmap / to-prd / to-issues; design-plan only for refactor-scale phase plans |
| Research question, "investigate how..." | **research** | RPI Chain (research → plan → implement) |
| "Review this", "review my changes" | **review** | workflow-review |
| "Address review comments", "handle the feedback", "respond to review", PR has unresolved comments | **receive review** | receive-review |
| "cleanup", "clean up tickets", "delete branches", "remove worktrees", "stale local branches", merged/closed/abandoned delivery residue | **delivery cleanup** | cleanup-delivery |
| "Evaluate workflow effectiveness", "audit skill effectiveness", "find workflow gaps", "audit recent agent transcripts", "did this workflow skip steps" | **workflow effectiveness audit** | workflow-effectiveness-audit |
| D&D, campaign, session prep, mystery, encounter, NPC, worldbuilding | **creative/D&D** | dnd-workflow |
| Executive memo, board update, strategy doc, leadership recommendation, org analysis, product engagement analysis | **executive document** | workflow-executive-doc |
| "prototype this", "try it out", "play with it", "sanity-check the model" | **prototype** | prototype |
| "write an article", "blog post", "draft", "write about" | **writing** | writing-fragments → writing-shape or writing-beats → humanizer |
| "humanize", "de-AI", "make it sound human", "remove AI patterns" | **polish** | humanizer |
| "handoff", "wrap up session", "save context for next time" | **session exit** | handoff |
| "generate prompt for", "prep for codex", "prep for AFK" | **prompt generation** | prompt-builder |

## Bug routing rule

**Never route bugs to workflow-build-one**, even if the fix appears obvious. Bugs always go to workflow-debug, which enforces diagnosis-first. This prevents:

- Fixing symptoms instead of root causes
- Missing regression tests
- Incorrect assumptions about "simple" bugs

## PRD vs backlog routing rule

**Use `execute-prd` when issues have a parent PRD and dependencies between them.** Use `run-backlog` when issues are independent and can be processed in any order.

| Signal | Route |
|--------|-------|
| "Execute PRD #N" / "implement all children" / parent issue with child task list | execute-prd |
| "Run the backlog" / batch of independent `ready-for-agent` issues | run-backlog |
| Single issue, no parent context | workflow-build-one |

If unclear: check whether the issues reference a parent. If yes → execute-prd. If no → run-backlog.

## Preflight

Before dispatching, check the target workflow's `Requires` field:

1. Read the target skill's `## Contract` section
2. For each tool in `Requires:`, verify availability:
   - CLI tools: check via `which <tool>`
   - MCP servers: check if configured
   - Project tools: check if project has expected config (package.json, Makefile, etc.)
3. If a required tool is missing:
   - Report what's missing and why it's needed
   - Suggest installation or alternative
   - Do NOT proceed with the workflow

### Worktree Baseline Gate

Before dispatching any workflow that mutates code, commits, creates a PR, or runs a delivery loop, create or require a fresh isolated worktree from `origin/staging`:

```bash
git fetch origin --prune
git worktree add -b <workflow-branch> <worktree-path> origin/staging
```

The workflow must run inside that worktree. Do not run mutating delivery workflows from the primary checkout or from a branch based on local `main`/`staging`. If `origin/staging` is missing, halt and ask the user for the replacement base.

Read-only workflows (`workflow-review`, `workflow-effectiveness-audit`, repo audits, document workflows) do not create the worktree themselves, but if they are reviewing or finalizing code changes they must verify the change branch/worktree was cut from `origin/staging`.

## Audit Routing Rule

`repo-audit` is an evidence-gathering input to the current workflow, not a separate default delivery loop.

- For product or feature gaps found by audit: route to `workflow-roadmap`, then `grill-with-docs → decision-log → to-prd → to-issues → triage`.
- For already-clear vertical implementation slices: route to `to-issues` or `triage`.
- For repo-wide refactors, migrations, or multi-phase remediation that cannot be represented cleanly as issue slices yet: route to `design-plan`, then optionally `execute-phase`.
- Do not route audits directly to `execute-phase`; a human-approved roadmap, PRD/issues, or design plan must exist first.

## Graceful degradation

These fallbacks apply only when the target workflow does not list the
missing tool in `Requires:` and does not define it as a blocking runtime
gate. If a required dependency is missing, the preflight rule above wins:
halt, report the missing requirement, and do not proceed.

| Missing tool | Impact | Behavior |
|--------------|--------|----------|
| `gh` | Can't interact with GitHub | Local-only analysis is allowed only for non-shipping workflows that do not require `gh`; delivery workflows halt |
| OMC | Can't dispatch to Codex team | Halt unless the selected workflow/mode explicitly allows Claude fallback and the user approves it |
| CORA | Can't validate contracts | Skip CORA validation only; do not skip the target workflow's own gates |
| `playwright-mcp` | Can't run UJ QA | For frontend/user-facing changes, halt for human waiver or setup; do not silently skip |
| Project test runner | Can't verify | Halt and request setup info |
| Campaign docs | D&D canon-specific review unavailable | `dnd-grill` may run without docs; `dnd-grill-with-canon` must halt or explicitly switch to lightweight `dnd-grill` with the user's consent |
| Raw material file | Writing pipeline needs input | writing-fragments can create from scratch; writing-shape and writing-beats need a file to work from |

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step. Use the exact step names from this skill and include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

Rules:

- Initialize every known step as `pending`; conditional steps remain `pending` until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status and evidence or reason.
- A step may be `skipped` only when this skill explicitly makes it optional/conditional or a routing decision stops the workflow; record the exact reason.
- Do not mark required gates as skipped. If a required gate cannot run, mark it `blocked` or `failed` and halt according to this workflow.
- At every halt, STOP, handoff, and final completion, include the final ledger in the response or artifact.
- The final ledger must distinguish `completed`, `skipped`, `blocked`, `failed`, and `not_applicable`, and every non-completed status must include a reason.

## Process

```
1. Receive work description (user input, issue, or automated trigger)
2. Classify using signal table above
3. If ambiguous: ask ONE clarifying question (max 1 — don't interrogate)
4. Run preflight on target workflow
5. If preflight passes: dispatch to target workflow
6. If preflight fails: report missing requirements
```

## Contract

Consumes: work description (user input, issue body, automated trigger)
Produces: dispatched workflow invocation, preflight report (if failed)
Requires: git
Side effects: none (routing is a decision, not an action)
Human gates: ambiguous classification asks one clarifying question

Runtime note: the router itself only needs git-aware workspace context; target workflows declare their own `Requires` fields.

## Context

Typical workflows: entry point (invoked implicitly or explicitly for all new work)
Pairs well with: all workflow skills (it routes to them), preflight validates their contracts
