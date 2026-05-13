---
name: reconcile-issues
description: Detect and correct drift between GitHub Issues, PRs, labels, execution outcomes, and post-mortems
---

# Reconcile Issues

## Purpose

Compare GitHub Issues, PRs, labels, execution outcomes, and post-mortems to detect and correct drift in the issue tracker. This is a governance skill — it maintains issue hygiene, not code quality.

## When to invoke

- After a batch of PRs merge
- After execute-phase completes
- After a post-mortem is written
- Periodically (weekly or sprint boundary)
- When issue tracker feels stale or inconsistent

## Process

### 1. Gather state

- Fetch open/recently-closed issues via `gh issue list`
- Fetch recent merged PRs via `gh pr list --state merged`
- Read PR bodies for issue references (Closes/Fixes/Resolves/Refs #N)
- Read execute-phase outcome files if present (docs/executions/.phase-runs/)
- Read post-mortems if present

### 2. Run drift checks

| # | Check | Detection |
|---|-------|-----------|
| 1 | Issues that should have closed but did not | PR merged with `Closes #N` but issue still open |
| 2 | Issues closed incorrectly | Issue closed but referenced PR was reverted or failed CI |
| 3 | PRs missing issue references | Merged PR body has no issue reference |
| 4 | Stale ready-for-agent issues | Labeled `ready-for-agent` but no PR activity for >7 days |
| 5 | Partially completed issues | PR merged that addresses only part of issue acceptance criteria |
| 6 | Missing follow-up work | Post-mortem or phase outcome mentions new work not yet issued |
| 7 | Orphaned issues | No assignee, no label, no recent activity |
| 8 | Duplicate/superseded issues | Multiple issues describing same work, or later issue supersedes earlier |
| 9 | Stale labels | Labels like `in-progress`, `needs-review` on issues with no recent activity |

### 3. Produce drift report

Output a structured markdown artifact:

```markdown
## Drift Report — [date]

### Critical (action required)
- [list of issues needing immediate attention]

### Warning (should address)
- [list of drift items]

### Info (awareness only)
- [list of minor inconsistencies]

### Recommended actions
- [ ] Close #N (PR #M merged with Closes reference)
- [ ] Reopen #N (PR #M was reverted)
- [ ] Create follow-up issue for [description]
- [ ] Remove stale label from #N
```

### 4. Take action (with gates)

**Automated (no approval needed):**

- Remove stale `in-progress` label when no PR is open
- Add `stale` label to issues with no activity >30 days

**Requires approval:**

- Closing issues
- Creating follow-up issues
- Removing `ready-for-agent` label

## Constraints (what this skill does NOT do)

1. **Does not** close issues directly when a PR is merely green — GitHub auto-close handles that
2. **Does not** override GitHub's auto-close semantics (Closes/Fixes/Resolves)
3. **Does not** mark partial work as complete
4. **Does not** infer product completion without evidence

## Contract

Consumes: GitHub Issues state, merged PRs with bodies, execute-phase outcome files, post-mortems, label state
Produces: structured drift report (markdown), recommended actions list
Requires: gh
Side effects: may add/remove labels (automated subset only); may create follow-up issues (with approval)
Human gates: issue closure, follow-up creation, ready-for-agent removal

## Context

Typical workflows: workflow-finalize, run-backlog (monitoring phase)
Pairs well with: post-mortem, describe-pr, triage
