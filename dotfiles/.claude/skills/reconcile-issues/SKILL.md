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

## Non-default-branch close fallback

Runs *before* the drift-detection process below and uses different semantics: this section auto-acts (no human approval) on one narrow trigger that other close paths in this skill require approval for.

### Why it exists

GitHub's native auto-close keywords (`Closes`/`Fixes`/`Resolves #N`) only fire when a PR merges into the repository's default branch. For repos whose feature PRs target a non-default branch (e.g. `staging`), referenced issues stay `OPEN` with stale `ready-for-agent` labels until a human notices. This fallback restores equivalent behavior outside GitHub's auto-close limitation.

### Trigger

Runs once per merged PR observed during `workflow-finalize` Step 4, when both conditions hold:

- `pr.merged == true`
- `pr.baseRefName != repo.defaultBranchRef.name` (read `defaultBranchRef.name` via `gh repo view --json defaultBranchRef`)

The trigger is repo-agnostic — no hardcoded list of repos, no per-repo opt-in. The check is dynamic against the repo's actual default branch at runtime.

### Behavior

For the merged PR:

1. Fetch the PR body: `gh pr view <N> --json body -q .body`
2. Parse closing-keyword references with regex `(?i)(closes|fixes|resolves) #(\d+)` — case-insensitive, multi-ref aware, **PR body only** (not commit messages, not linked-via-UI). `Addresses`, `Refs`, and `See` are intentionally non-closing per GitHub semantics and are not parsed.
3. For each unique referenced issue:
   - Fetch state: `gh issue view <N> --json state -q .state`
   - If state is `CLOSED` → skip the close call, emit log line with `action=skipped reason=already-closed`
   - Otherwise:
     - `gh issue close <N> --reason completed --comment "<comment-template>"` (template below)
     - `gh issue edit <N> --remove-label ready-for-agent` (ignore failure if the label is absent)
     - Emit log line with `action=closed`
4. Honor `RECONCILE_DRY_RUN=1` — print the intended `gh issue close`/`edit` invocations to stdout, do not execute, emit log line with `action=dry-run`.
5. **Approval-bypass scope**: this trigger is the only path in this skill that closes issues without human approval. All other close paths (drift checks 1-9 in the process below) remain approval-gated per `### 4. Take action (with gates)`.
6. **gh-account-flip retry**: when running across personal and work GitHub accounts on the same host, `gh` occasionally resolves to the wrong account and fails with `Could not resolve to a Repository`. On any error matching that string, run `gh auth switch --user johnalexwelch` once, then retry the failed call with an explicit `--repo <owner>/<repo>` flag. If retry still fails, emit log line with `action=skipped reason=gh-auth-error` and continue to the next referenced issue.

### Comment template (locked)

The comment posted on each auto-closed issue must use this template verbatim. Do not improvise wording — every auto-closed issue should be auditably uniform.

```
This issue was referenced by PR #<N> (squash SHA <sha7>) which merged into
`<baseRefName>`. GitHub's native auto-close (Closes/Fixes/Resolves keywords)
only fires for merges into the default branch (`<defaultBranch>`), so this
issue did not close automatically.

Closed by reconcile-issues (workflow-finalize Step 4) as a fallback.
```

Substitutions:

- `<N>` — the merged PR number
- `<sha7>` — first 7 chars of the squash-merge commit SHA (`gh pr view <N> --json mergeCommit -q .mergeCommit.oid | cut -c1-7`)
- `<baseRefName>` — the PR's base ref (e.g. `staging`)
- `<defaultBranch>` — the repo's default branch (e.g. `main`)

### Structured log format (locked)

Emit exactly one line per referenced issue, regardless of outcome. The format is fixed for grep/audit consumption:

```
[reconcile-staging] issue=#<N> action=<closed|skipped|dry-run> pr=#<M> sha=<sha7> reason=<short-reason>
```

`reason` should be one short hyphen-cased token:

- `auto-close-didnt-fire` — for `action=closed`
- `already-closed` — for `action=skipped` when the issue was already `CLOSED`
- `gh-auth-error` — for `action=skipped` when both auth-flip retries failed
- `dry-run-mode` — for `action=dry-run`

### Golden examples

The fallback must match the following input → output behavior. These examples are the spec's verification — when the orchestrator wants to confirm correctness, it consults this list, not a separate test harness.

#### Example 1 — PR targets default branch → no-op

**Input**

- PR #100 merged
- `baseRefName`: `main`
- `defaultBranchRef.name`: `main`
- Body: `Closes #99`

**Expected behavior**

- Trigger condition fails (`baseRefName == defaultBranchRef.name`)
- No `gh issue close`, no `gh issue edit`, no log lines emitted by this fallback
- GitHub's native auto-close handles #99

#### Example 2 — non-default base + `Closes` + OPEN issue → close

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- `defaultBranchRef.name`: `main`
- Squash SHA: `abc1234d5e6f...`
- Body: `Closes #99`
- Issue #99 state: `OPEN`

**Expected `gh` calls (in order)**

- `gh issue close 99 --reason completed --comment "<rendered template with N=100, sha7=abc1234, baseRefName=staging, defaultBranch=main>"`
- `gh issue edit 99 --remove-label ready-for-agent`

**Expected log**

```
[reconcile-staging] issue=#99 action=closed pr=#100 sha=abc1234 reason=auto-close-didnt-fire
```

#### Example 3 — non-default base + already CLOSED → skip

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- Body: `Closes #99`
- Issue #99 state: `CLOSED`

**Expected behavior**

- No `gh issue close`, no `gh issue edit`

**Expected log**

```
[reconcile-staging] issue=#99 action=skipped pr=#100 sha=abc1234 reason=already-closed
```

#### Example 4 — `RECONCILE_DRY_RUN=1` → print only

**Input**

- Same as Example 2
- Environment: `RECONCILE_DRY_RUN=1`

**Expected behavior**

- No mutating `gh` calls execute
- Stdout prints intended commands:

```
DRY-RUN: gh issue close 99 --reason completed --comment "..."
DRY-RUN: gh issue edit 99 --remove-label ready-for-agent
```

**Expected log**

```
[reconcile-staging] issue=#99 action=dry-run pr=#100 sha=abc1234 reason=dry-run-mode
```

#### Example 5 — multiple refs `Closes #46, #48` → handle both

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- Body: `Closes #46, #48`
- Issues #46 and #48 both `OPEN`

**Expected behavior**

- Regex matches both `#46` and `#48` from the single `Closes` clause
- Two independent sequences (close + remove-label) — one per issue
- Two log lines, one per issue

#### Example 6 — mixed case `closes #46 Fixes #48` → handle both

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- Body: `closes #46 Fixes #48`
- Issues #46 and #48 both `OPEN`

**Expected behavior**

- Case-insensitive regex matches both `closes` and `Fixes` keywords
- Two independent sequences (close + remove-label) — one per issue
- Two log lines, one per issue

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
