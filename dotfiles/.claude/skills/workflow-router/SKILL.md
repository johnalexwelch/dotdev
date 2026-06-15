---
name: workflow-router
model: sonnet
reasoning: high
description: Use when a request may need routing to a project workflow, AFK execution path, planning/grill flow, review/finalize loop, or skill/workflow audit
---

# Workflow Router

## Purpose

The single routing authority for all incoming work. Classifies the task, presents a route card for confirmation, runs preflight checks, and dispatches to the appropriate workflow skill only after the user confirms the route. Replaces ad-hoc routing decisions with a consistent classification system.

## Authority

This skill is the **sole routing authority**. Per ADR-0002:

- `workflows.md` is reference documentation only — it does not route
- OMC keyword triggers (`autopilot`, `ralph`, `ultrawork`, etc.) bypass this router's classification step only. Any mutating code, commit, PR, or delivery action reached through those shortcuts must still satisfy `WORKTREE_BASELINE_GATE`, `workflow-review`, and `workflow-finalize`.
- All other work goes through this router
- The router owns classification, confirmation, preflight, and learning notes. Target workflow skills own the actual workflow behavior. Do not copy target workflow procedures into this skill.

## Audit Loop Retirement Rule

The old "Audit Loop" is not an execution route. If a prompt, transcript, repo doc, or agent memory says to run the Audit Loop, translate it into the workflow system:

- Code review gate → `workflow-review`
- Delivery closure, PR body, reviewer comments, CI, reconciliation, and final PR action → `workflow-finalize`
- Broad repo evidence gathering → `repo-audit`, then route findings through `workflow-roadmap`, `to-prd`, `to-issues`, or `design-plan`
- Multi-phase refactor execution → `design-plan` / `execute-phase`, then `workflow-review` and `workflow-finalize`

Do not dispatch `/review`, `/post-mortem`, `/describe-pr`, or `/watch-ci` as a standalone default loop unless the owning workflow explicitly calls that skill.

## Agent Budget Rule

Choose the smallest execution shape that preserves quality:

| Budget | Use when | Default review profile |
|--------|----------|------------------------|
| `direct` | Trivial ops, single-command answers, simple docs/wording edits, or small local inspections with no delivery gate | none |
| `one-reviewer` | Normal single-issue work, narrow code edits, and most skill/config changes | `fast` or `standard` |
| `multi-lane` | Auth, data, infra, migrations, public APIs, dependencies, broad refactors, concurrency/state, user-facing UX, or large diffs | `full` |
| `team` | Two or more independent workstreams benefit from parallel execution more than coordination costs | per child workflow |

Independence matters more than agent count. Do not use multiple agents merely
because a workflow says "review"; use `workflow-review`'s risk-sized
`review_profile`.

## Route Confirmation Gate

Before dispatching any non-trivial workflow, mutating workflow, scaffold, AFK run, GitHub issue/PR action, project document generation, or delivery loop, emit a `ROUTE_CARD` and wait for the user's confirmation.

Skip the confirmation gate only when all are true:

- Budget is `direct`
- The action is read-only or produces only an immediate conversational answer
- The user explicitly asked for the immediate action
- No workflow dispatch, file mutation, repo scaffold, issue creation, PR action, or AFK execution will occur

If the user explicitly names a workflow and says to run it, still emit the route card first when the workflow can mutate files, create artifacts, create issues/PRs, run AFK, or perform delivery actions.

### Route Card

Use this exact shape:

```markdown
ROUTE_CARD:
- Request:
- Classification:
- Selected flow:
- Confidence: high|medium|low
- Why this flow:
- Budget: direct|one-reviewer|multi-lane|team
- Will mutate/create:
- Human gates:
- Expected artifacts:
- Follow-up audit:
- Alternatives considered:
- Confirmation needed:
```

Rules:

- `Will mutate/create` must explicitly say `none` for read-only routes.
- `Human gates` must include every known approval point before implementation, AFK execution, PR action, or cleanup.
- `Follow-up audit` should say whether `workflow-effectiveness-audit` is expected at the end and why.
- If confidence is `low`, ask one clarifying question instead of asking the user to approve a route.
- If confidence is `medium`, recommend the best route and include the closest alternative.
- Do not perform target workflow preflight, create a worktree, scaffold a repo, write docs, create issues, or dispatch agents until the route is confirmed.

### Confirmation Language

End the route card with one concise confirmation request:

```markdown
Confirm this route and I will start `<selected-flow>`.
```

If the route is read-only and low-risk, use:

```markdown
Confirm this route and I will proceed.
```

If the user corrects the route, treat that correction as fresh routing input and produce a revised route card.

## Classification table

| Signal | Classification | Routes to |
|--------|---------------|-----------|
| "build a V1", "turn this idea into a V1", "shape this product idea", "define the MVP", loose product idea needing functionality details, "design the system for this V1", "turn this V1 brief into architecture" | **V1** | `v1-workflow` (full gated pipeline: idea grill → approval → decision-log → system design → roadmap → issues — do NOT route directly to `v1-idea-grill` or `v1-system-design`, which skips the approval gates) |
| "roadmap", "what should we build next", "feature gaps", "implementation gaps", "hardening roadmap", "product and implementation plan", multi-area sequencing across product/security/infrastructure | **product/engineering roadmap** | workflow-roadmap |
| "write OKRs", "set quarterly goals", "objectives and key results", "turn strategy into OKRs", "review these OKRs" | **OKRs** | okr-generator |
| "we're launching X", "launch plan", "launch checklist", "go-to-market checklist", "are we ready to ship", "go-live readiness" | **product launch** | product-launch-checklist |
| "autonomous module discovery", "find modules and create PRDs", "action the backlog AFK", "run backlog without outages", "autonomous backlog" | **autonomous backlog workflow** | workflow-autonomous-backlog |
| Bug report, error, "it's broken", regression | **bug** | workflow-debug |
| Vague idea, "what if we...", "I want to build..." | **ambiguous feature** | workflow-feature |
| Issue with `ready-for-agent` + clear acceptance criteria | **ready issue** | workflow-build-one |
| Parent PRD issue with child issues, "execute this PRD", "implement all children of #N", "work through this parent issue", "execute the issue tree" | **PRD execution** | execute-prd |
| Multiple ready issues, "run the backlog", AFK batch | **AFK backlog** | run-backlog |
| "Audit the repo", "state of repo", broad evidence gathering needed | **repo evidence audit** | repo-audit → workflow-roadmap / to-prd / to-issues; design-plan only for refactor-scale phase plans |
| Research question, "investigate how...", "what does X look like in the codebase", "investigate Y" | **research** | `repo-audit` (for codebase evidence) or `improve-codebase-architecture` (for deepening opportunities); findings feed `workflow-roadmap`, `to-prd`, `to-issues`, or `design-plan` |
| "Review this", "review my changes" | **review** | workflow-review |
| "Address review comments", "handle the feedback", "respond to review", PR has unresolved comments | **receive review** | receive-review |
| "cleanup", "clean up tickets", "delete branches", "remove worktrees", "stale local branches", merged/closed/abandoned delivery residue | **delivery cleanup** | cleanup-delivery |
| "Evaluate workflow effectiveness", "audit skill effectiveness", "find workflow gaps", "audit recent agent transcripts", "did this workflow skip steps" | **workflow effectiveness audit** | workflow-effectiveness-audit |
| "route this", "choose the workflow", "what flow do we need", "single wrapper", "intake", "which skill should run", "start the right workflow" | **workflow intake** | workflow-router route card, then confirmed target workflow |
| D&D, campaign, session prep, mystery, encounter, NPC, worldbuilding | **creative/D&D** | dnd-workflow |
| Executive memo, board update, strategy doc, leadership recommendation, org analysis, product engagement analysis | **executive document** | workflow-executive-doc |
| "prototype this", "try it out", "play with it", "sanity-check the model" | **prototype** | prototype |
| "write an article", "blog post", "draft", "write about" | **writing** | writing-fragments → writing-shape (argument mode) or writing-beats (narrative/beats mode) → humanizer |
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

## Roadmap Gate Rule

For feature planning that will produce PRDs and implementation issues, require an approved `workflow-roadmap` artifact before dispatching `to-prd` or `to-issues`.

- If roadmap evidence exists and is in scope: proceed.
- If roadmap is missing, stale, or out of scope: route to `workflow-roadmap` first and halt downstream dispatch until approved.
- Only an explicit user waiver may bypass this gate.

## Learning Loop

At the end of any confirmed non-trivial route, and whenever the user corrects the routing choice, produce a `ROUTER_LEARNING_NOTE`.

```markdown
ROUTER_LEARNING_NOTE:
- Initial classification:
- Confirmed classification:
- Confidence was:
- User correction:
- What made the route right or wrong:
- Accepted feedback:
- Durable destination: none|project decision log|backlog|skill-maintenance proposal|memory proposal
- Skill/workflow improvement suggested:
```

Learning rules:

- Do not silently edit memories or skills.
- Project-specific lessons go to the project decision log only when the active workflow allows writing project artifacts.
- Future-work items go to backlog only with user approval or inside a workflow that already owns issue creation.
- Reusable process lessons become `skill-maintenance` proposals.
- If the workflow was AFK, multi-stage, corrected by the user, halted for a process gap, or produced planning/execution artifacts, run or recommend `workflow-effectiveness-audit` before final closure.
- If a recommendation is accepted during a review or audit loop, classify it before persisting: project-specific, future-work, reusable process, or local wording only.

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
| Campaign docs | D&D canon-specific review unavailable | `dnd-grill` may run without docs; `dnd-grill (canon mode)` must halt or explicitly switch to lightweight `dnd-grill` with the user's consent |
| Raw material file | Writing pipeline needs input | writing-fragments can create from scratch; writing-shape and writing-beats need a file to work from |

## Process

```
1. Receive work description (user input, issue, or automated trigger)
2. Classify using signal table above
3. If ambiguous or confidence is low: ask ONE clarifying question (max 1 — don't interrogate)
4. Select the smallest safe agent budget
5. Emit ROUTE_CARD
6. Wait for user confirmation unless the route qualifies for the direct/read-only skip
7. After confirmation, run preflight on target workflow
8. If preflight passes: dispatch to target workflow
9. If preflight fails: report missing requirements
10. At completion, halt, or user correction: emit ROUTER_LEARNING_NOTE and run or recommend workflow-effectiveness-audit when triggered
```

## Contract

Consumes: work description (user input, issue body, automated trigger)
Produces: route card, confirmed workflow invocation, preflight report (if failed), router learning note
Requires: git
Side effects: none (routing is a decision, not an action)
Human gates: route confirmation before non-trivial dispatch; ambiguous classification asks one clarifying question

Runtime note: the router itself only needs git-aware workspace context; target workflows declare their own `Requires` fields.

## Context

Typical workflows: entry point (invoked implicitly or explicitly for all new work)
Pairs well with: all workflow skills (it routes to them), preflight validates their contracts
