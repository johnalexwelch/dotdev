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
2. **Parse closing references** — match GitHub's native auto-close grammar: case-insensitive, multi-ref aware, **PR body only** (not commit messages, not linked-via-UI). For each closing-keyword anchor (`closes`, `fixes`, `resolves`), capture every `#<digits>` token that follows in a comma- and/or-`and`-separated list until the next non-issue-ref token. `Addresses`, `Refs`, and `See` are intentionally non-closing per GitHub semantics and are not parsed.

   Forms the parser must handle:

   - Single-keyword form: `Closes #99` → matches `#99`
   - Multi-issue comma form: `Closes #46, #48` → matches `#46` and `#48`
   - Multi-issue "and" form: `Closes #46 and #48` → matches `#46` and `#48`
   - Multi-issue mixed-conjunction form: `Closes #46, #48, and #50` → matches `#46`, `#48`, and `#50`
   - Mixed-keyword form: `closes #46 Fixes #48` → matches `#46` under `closes`, `#48` under `Fixes`
   - Non-closing form: `Refs #99` / `Addresses #99` / `See #99` → no match

   **Implementation note**: a naive single regex of the form `(?i)(closes|fixes|resolves) #(\d+)` matches only the first `#N` after each keyword and is insufficient. Executors must either (a) extend the regex to capture trailing `(?:\s*(?:,|\band\b)\s*#(\d+))*` clauses, or (b) implement a two-pass parse — find keyword anchors, then for each anchor consume the comma- and `and`-separated `#N` list that follows. Both yield the same set of issue numbers.
3. For each unique referenced issue:
   - Fetch state: `gh issue view <N> --json state -q .state`
   - If state is `CLOSED` → skip the close call, emit log line with `action=skipped reason=already-closed`
   - Otherwise:
     - `gh issue close <N> --reason completed --comment "<comment-template>"` (template below)
     - `gh issue edit <N> --remove-label ready-for-agent` (ignore failure if the label is absent)
     - Emit log line with `action=closed`
4. Honor `RECONCILE_DRY_RUN=1` — print the intended `gh issue close`/`gh issue edit` invocations to stdout in the `DRY-RUN: <command>` format shown in Example 4 below, do not execute the mutating calls, **and** emit one structured log line per referenced issue with `action=dry-run reason=dry-run-mode`. The stdout print and the structured log line are both emitted in dry-run mode.
5. **Approval-bypass scope**: this trigger is the only path in this skill that closes issues without human approval. All other close paths (drift checks 1-9 in the process below) remain approval-gated per `### 4. Take action (with gates)`.
6. **gh-account-flip retry**: when running across personal and work GitHub accounts on the same host, `gh` occasionally resolves to the wrong account and fails with `Could not resolve to a Repository`. On any error matching that string, run `gh auth switch --user johnalexwelch` once, then retry the failed call with an explicit `--repo <owner>/<repo>` flag. If retry still fails, emit log line with `action=skipped reason=gh-auth-error` and continue to the next referenced issue.

### Comment template (locked)

The comment posted on each auto-closed issue must use this template verbatim. Do not improvise wording — every auto-closed issue should be auditably uniform.

```text
This issue was referenced by PR #<N> (merge SHA <sha7>) which merged into
`<baseRefName>`. GitHub's native auto-close (Closes/Fixes/Resolves keywords)
only fires for merges into the default branch (`<defaultBranch>`), so this
issue did not close automatically.

Closed by reconcile-issues (workflow-finalize Step 4) as a fallback.
```

Substitutions (executors MUST validate each value against the expected character class before interpolating into the template; reject and skip with `reason=invalid-substitution` on mismatch):

- `<N>` — the merged PR number, integer (`[0-9]+`)
- `<sha7>` — first 7 chars of the merge commit SHA, regardless of merge strategy (`gh pr view <N> --json mergeCommit -q .mergeCommit.oid | cut -c1-7`); expected hex (`[0-9a-f]{7}`). If `mergeCommit.oid` is null (rare immediate-post-merge race), skip the issue with `reason=merge-sha-unavailable`.
- `<baseRefName>` — the PR's base ref (e.g. `staging`); expected refname (`[A-Za-z0-9/_.-]+`)
- `<defaultBranch>` — the repo's default branch (e.g. `main`); expected refname (`[A-Za-z0-9/_.-]+`)

The template wording uses "merge SHA" rather than "squash SHA" so the comment remains accurate across squash-merge, merge-commit, and rebase strategies. Repos that strictly squash-merge see no functional difference.

### Structured log format (locked)

Emit exactly one line per referenced issue, regardless of outcome. The format is fixed for grep/audit consumption:

```
[reconcile-staging] issue=#<N> action=<closed|skipped|dry-run> pr=#<M> sha=<sha7> reason=<short-reason>
```

`reason` is one short hyphen-cased token from this fixed enum. New reasons require a spec edit, not an executor improvisation.

- `auto-close-didnt-fire` — for `action=closed`
- `already-closed` — for `action=skipped` when the issue was already `CLOSED`
- `gh-auth-error` — for `action=skipped` when the auth-flip retry also failed
- `issue-not-found` — for `action=skipped` when `gh issue view` returns 404 (issue deleted or never existed)
- `label-remove-failed` — for `action=skipped` on `gh issue edit --remove-label` failures that are NOT "label absent" (the absent case is silent on the edit call but emits a normal `action=closed` line; this token captures rate-limit / permission / API errors only)
- `merge-sha-unavailable` — for `action=skipped` when `mergeCommit.oid` is null
- `invalid-substitution` — for `action=skipped` when any substitution value fails its character-class validation
- `dry-run-mode` — for `action=dry-run`

When the PR body contains no closing-keyword refs at all, the fallback emits **no log lines** — silent inactivity is the correct signal when there is nothing to reconcile. (To audit "the fallback ran but found nothing", consult the parent `workflow-finalize` Step 4 invocation log, not this skill's structured-log output.)

Issues referenced by a PR are processed **sequentially in regex-match order**. A failure on one issue does not abort processing of the remaining issues; each issue gets its own independent log line.

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

#### Example 7 — gh-account-flip retry exhausted → skip with `gh-auth-error`

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- Body: `Closes #99`
- Issue #99 state: `OPEN`
- First `gh issue close 99 ...` call fails with `Could not resolve to a Repository`
- After `gh auth switch --user johnalexwelch`, the retry call with `--repo johnalexwelch/dotdev` also fails with `Could not resolve to a Repository`

**Expected behavior**

- No final `gh issue close` mutation (both attempts errored)
- No `gh issue edit --remove-label` (skipped because the close itself failed)
- Continue to the next referenced issue if any

**Expected log**

```text
[reconcile-staging] issue=#99 action=skipped pr=#100 sha=abc1234 reason=gh-auth-error
```

#### Example 8 — non-closing refs only → no-op (no log lines)

**Input**

- PR #100 merged
- `baseRefName`: `staging`
- Body: `Refs #99 and Addresses #100. See also #101.`
- Issues #99, #100, #101 all `OPEN`

**Expected behavior**

- Regex matches zero closing-keyword anchors (`Refs`, `Addresses`, `See` are explicitly non-closing per GitHub semantics)
- No `gh issue close`, no `gh issue edit`
- **No log lines emitted** by this fallback (silent inactivity is the correct signal when there is nothing to reconcile; cf. the reason-enum note above)
- GitHub's own auto-close also leaves all three issues open — this fallback matches that behavior intentionally

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
