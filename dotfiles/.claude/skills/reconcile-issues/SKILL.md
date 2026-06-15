---
name: reconcile-issues
model: sonnet
reasoning: medium
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
- Fetch recent closed PRs that were not merged when checking premature close or abandoned-review drift
- Read PR bodies for issue references (Closes/Fixes/Resolves/Refs #N)
- Read PR reviews and inline comments for unresolved or unanswered reviewer feedback
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
| 10 | PR merged or closed with unresolved reviewer feedback | Review comments contain blockers/questions/suggestions with no later fix commit, reply, or explicit waiver |

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
- [ ] Reopen or follow up on PR #N review comment: [summary]
```

### 4. Take action (with gates)

**Automated (no approval needed):**

- Remove stale `in-progress` label when no PR is open
- Add `stale` label to issues with no activity >30 days

**Requires approval:**

- Closing issues
- Creating follow-up issues
- Removing `ready-for-agent` label
- Reopening PRs/issues because of unresolved reviewer feedback
- Creating follow-up work from unresolved reviewer comments

## Constraints (what this skill does NOT do)

1. **Does not** close issues directly when a PR is merely green — GitHub auto-close handles that
2. **Does not** override GitHub's auto-close semantics (Closes/Fixes/Resolves)
3. **Does not** mark partial work as complete
4. **Does not** infer product completion without evidence
5. **Does not** treat green CI or auto-merge as evidence that review comments were addressed

## Reviewer Comment Reconciliation

For each recently merged or closed PR, inspect:

```
gh api repos/<owner>/<repo>/pulls/<pr_number>/reviews
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
```

Flag reviewer-comment drift when an actionable comment has no evidence of resolution:

- No later commit appears to address the cited file/line
- No inline reply explains why the comment was declined or deferred
- No linked follow-up issue captures valid out-of-scope work
- No explicit human waiver is recorded

Classify findings:

| Severity | Condition |
|----------|-----------|
| Critical | Merged PR has unresolved blocker or requested-changes comment |
| Warning | Merged PR has unanswered non-blocking suggestion or question |
| Info | Bot review timed out or expected bot never reviewed before merge |

Recommended actions should be conservative: create follow-up issues, reopen only with approval, and never rewrite PR history.

## Output format

The primary artifact is always the drift report markdown. When running in Cursor IDE, also produce a **canvas** (`.canvas.tsx`) for the drift dashboard — the checks table, recommended actions, and issue state summary benefit from interactive rendering. Use the Cursor `canvas` skill pattern: create a `canvases/<date>-drift-report.canvas.tsx` with the structured drift data.

Skip the canvas when running headless (Codex AFK, CI, non-IDE context).

## Contract

Consumes: GitHub Issues state, merged/closed PRs with bodies and review comments, execute-phase outcome files, post-mortems, label state
Produces: structured drift report (markdown), recommended actions list, optional canvas artifact
Requires: gh
Side effects: may add/remove labels (automated subset only); may create follow-up issues (with approval)
Human gates: issue closure, follow-up creation, ready-for-agent removal, reopening PRs/issues due to unresolved review feedback

## Context

Typical workflows: workflow-finalize, run-backlog (monitoring phase)
Pairs well with: post-mortem, describe-pr, triage
