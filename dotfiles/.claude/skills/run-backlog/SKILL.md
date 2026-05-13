---
name: run-backlog
description: AFK backlog orchestrator — batch-process ready-for-agent issues via Codex (default) or Claude
---

# Run Backlog

## Purpose

Autonomously process a queue of `ready-for-agent` issues without human supervision. Defaults to dispatching via Codex (through OMC team bridge) for natural isolation — each issue gets its own context and produces its own PR.

## When to invoke

- User says "run the backlog" or "process ready issues"
- Scheduled/periodic execution (e.g., overnight AFK run)
- After workflow-feature produces a batch of triaged issues
- When issue count with `ready-for-agent` label exceeds threshold

## Execution modes

| Mode | Dispatch | When to use |
|------|----------|-------------|
| **Codex** (default) | `omc team 1:codex` per issue | AFK runs, batch processing, issues needing isolation |
| **Claude** | Sequential workflow-build-one invocations | Interactive sessions, when user wants to observe |

## Flow

### Phase 1: Plan
1. Query GitHub Issues: `gh issue list --label ready-for-agent --state open --json number,title,labels,body`
2. Filter out issues marked `blocked`, `needs-human`, or `in-progress`
3. Rank by:
   - Priority label (critical > high > medium > low)
   - Dependencies (unblocked issues first)
   - Age (older issues first, as tiebreaker)
4. Produce work queue artifact:

```markdown
## Work Queue — [date]
| # | Issue | Priority | Dependencies | Est. Complexity |
|---|-------|----------|--------------|-----------------|
| 1 | #N title | high | none | small |
| 2 | #M title | medium | #N | medium |
```

5. Present queue for approval (or auto-approve in AFK mode)

### Phase 2: Dispatch
For each issue in queue order:
1. Apply `in-progress` label
2. Dispatch:
   - **Codex mode**: `omc team 1:codex` with issue context (title, body, acceptance criteria, repo)
   - **Claude mode**: invoke workflow-build-one directly
3. Each dispatch is independent — failure of one does not block others

### Phase 3: Monitor
1. Poll PR status: `gh pr list --state open --json number,title,statusCheckRollup`
2. For each completed dispatch:
   - PR merged → update issue label to `done`, remove `in-progress`
   - PR failed CI → leave for watch-ci auto-fix (or flag for human if exhausted)
   - PR needs review → leave (workflow-build-one handles its own review cycle)
   - Dispatch failed → remove `in-progress`, add `needs-human` label, log failure
3. After all dispatches complete: invoke reconcile-issues for drift check
4. Produce summary:

```markdown
## Backlog Run Summary — [date]
- Dispatched: N issues
- Merged: M
- Pending review: P
- Failed: F (listed below)
- Duration: Xh Ym

### Failures
- #N: [reason]
```

## State management

All state lives in GitHub Issues (labels):
- `ready-for-agent` → ready for pickup
- `in-progress` → currently being worked
- `done` → completed
- `needs-human` → requires human intervention
- `blocked` → dependency not met

Work queue artifact is written to `docs/executions/backlog-runs/[date].md` for audit trail.

## Safety

- Max concurrent dispatches: 5 (prevent resource exhaustion)
- Max total issues per run: 20 (prevent runaway)
- Skip issues with `needs-human` or `blocked` labels
- If an issue's acceptance criteria are unclear, skip it and add `needs-human` label
- Never dispatch issues that reference each other (dependency conflict) simultaneously

## Contract

Consumes: GitHub Issues (ready-for-agent labeled), repo access
Produces: PRs (one per issue), backlog run summary, updated issue labels
Requires: gh, omc (for Codex mode)
Side effects: creates branches/PRs, modifies issue labels, writes run summary file
Human gates: work queue approval (skipped in AFK mode); failed dispatches flagged

## Context

Typical workflows: standalone (periodic AFK execution), after workflow-feature (processes produced issues)
Pairs well with: workflow-build-one (Claude mode), reconcile-issues (post-run cleanup), triage (pre-run preparation)
