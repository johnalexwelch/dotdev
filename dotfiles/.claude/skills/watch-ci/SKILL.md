---
name: watch-ci
model: haiku
description: Manual slash-only CI polling and bounded fix helper for existing pull requests. Auto-routing disabled; workflow-finalize may call it internally.
disable-model-invocation: true
triggers:
  - "/watch-ci"
  - "watch ci"
  - "monitor ci"
  - "fix ci"
  - "ship pr"
persona: Release engineer driving CI to green and self-reviewing the diff before merge
inputs:
  - name: pr_number
    type: integer
    default: 0
    description: GitHub PR number. If 0, look up the PR for the current branch via `gh pr view`. If still 0 (no PR), auto-create a draft PR using `body_path` or the most recent `.pr-bodies/` file.
  - name: branch
    type: string
    default: ""
    description: Branch to watch. If empty, use the current branch (`git rev-parse --abbrev-ref HEAD`). Used for PR lookup and for `git push` of auto-fix commits.
  - name: max_attempts
    type: integer
    default: 3
    description: Maximum auto-fix attempts before halting. Cap exists alongside no-progress detection; both halt rules apply.
  - name: dry_run
    type: boolean
    default: false
    description: If true, poll and classify only. No commits, no comments, no approval. Outcome file is still written.
  - name: no_review
    type: boolean
    default: false
    description: If true, skip self-review agents only with an explicit user waiver, or with a complete WORKFLOW_REVIEW_GATE verdict APPROVE plus an explicit waiver for watch-ci self-review. Existing PR comments are still monitored and resolved.
  - name: review_quiet_minutes
    type: integer
    default: 10
    description: After all known reviewer comments are handled, continue polling for this many quiet minutes before handing the draft PR back to the user.
  - name: body_path
    type: string
    default: ""
    description: Path to a PR body file used when auto-creating the PR. If empty, fall back to the most recent `docs/executions/.pr-bodies/<date>-pr-*.md` matching the branch.
  - name: base
    type: string
    default: "main"
    description: Base branch for PR creation (only used if `pr_number == 0` and the skill auto-creates the PR).
reads:
  - docs/plans/<date>[-<slug>]-design.md (newest unless overridden in chat; read for plan context only)
  - docs/executions/.phase-runs/<date>[-<plan-slug>]-phase-<N>.md (commit-to-task mapping for review framing)
  - docs/executions/.pr-bodies/<date>-pr-*.md (for auto-PR-creation fallback body)
  - GitHub Actions runs and logs via `gh run list`, `gh run view`, `gh pr checks`, `gh run view --log-failed`
  - PR state via `gh pr view <pr> --json ...`
  - references/ci-classifier.md
  - references/approve-and-review-gates.md
  - references/pr-comment-template.md
  - references/outcome-file-template.md
  - references/exhaustion-handoff.md
  - references/examples.md
writes:
  - docs/executions/.ci-runs/<date>-pr-<N>-attempt-<M>.md (one per CI attempt this run drives)
  - docs/executions/ci-handoffs/<pr-number>-<date>.md (exhaustion handoff artifact for diagnose)
  - git commits on the PR branch (auto-fix commits, format `ci-fix(<class>): <one-liner>`)
  - PR comment via `gh pr comment` (one structured comment per `/watch-ci` invocation)
  - PR review/comment replies via `gh` while resolving reviewer feedback; never submits approval, marks ready, merges, or enables auto-merge
---

## Deprecation Status

Status: standalone use deprecated. This skill remains loadable only because `workflow-finalize` may invoke it as an implementation helper.

- Workflow owner: `workflow-finalize`
- Reason: CI watching is owned by workflow-finalize; this skill must not approve, mark ready, merge, or enable auto-merge.
- Date: 2026-05-21


# /watch-ci - Drive CI To Green And Self-Review

## Contract

Consumes: PR number or branch, GitHub Actions output, phase-run outcome files
Produces: CI status report (`docs/executions/.ci-runs/`), PR comment, optional auto-fix commits
Requires: gh, git, subagent-dispatch
Side effects: may auto-create a draft PR, push bounded fix commits, reply to reviewer comments, and post PR comments; never submits approval, marks ready, merges, or enables auto-merge
Human gates: exhaustion, no-progress, rejected push, CI timeout, out-of-scope failures, technically invalid/conflicting review feedback, unresolved reviewer comments, and non-clean reviews halt for human input

## Purpose

`/watch-ci` closes the CI/reviewer-monitoring segment inside `workflow-finalize`. It can create or watch a draft PR when invoked directly with a body file, but the normal delivery loop is `workflow-finalize`, which runs `describe-pr`, ensures the draft PR exists, resolves review comments, then invokes this skill.

The skill is intentionally constrained:

1. **Bounded loops.** Stop at `max_attempts` (default 3) or when the same failure signature appears twice in a row.
2. **Auto-fix scope discipline.** Auto-fix only `format`, `lint`, `type`, and clear single-assertion test failures. Surface `test-logic`, `build-infra`, `security`, and `unknown` to humans.
3. **Reviewer feedback is work.** Monitor review agents and incorporate blockers, non-blockers, observations, comments, questions, and nits before handoff.
4. **No readiness or merge actions.** Do not submit approval, mark ready for review, merge, or enable auto-merge. `workflow-finalize` owns any repo-policy-controlled final PR action after this skill returns green.
5. **No destructive git.** Do not force-push, reset, rebase, discard user work, or mutate tokens.
6. **Draft PR fallback.** If no PR is found for the branch, auto-create a draft PR from `body_path` or the newest matching `.pr-bodies/` file.

## Reference Loading Guide

Load references only at the point they are needed:

- `references/ci-classifier.md`: Step 2 classification, no-progress signatures, classifier maintenance, and CI error handling.
- `references/approve-and-review-gates.md`: Step 4 review-agent monitoring, reviewer-comment gate, no-approval rule, and handoff criteria.
- `references/pr-comment-template.md`: Step 5 halt comments and Step 6 green summary comments.
- `references/outcome-file-template.md`: Step 7 outcome file structure and final chat summary.
- `references/exhaustion-handoff.md`: no-progress or exhausted-attempt handoff artifacts.
- `references/examples.md`: expected behavior examples and larger workflow context.

## Core Flow

### Step 0: Preflight

- Confirm `gh auth status` succeeds and the token has at least `repo`, `pull_request`, `workflow`, and `actions:read` scopes. Abort if not; token mutation is human-only.
- Confirm this is a git repo with a clean working tree (`git status --porcelain`). Abort if dirty because auto-fix commits require a clean baseline.
- Resolve `branch`: if empty, use `git rev-parse --abbrev-ref HEAD`. Abort if still empty.
- Resolve `pr_number`:
  - If provided, validate with `gh pr view <pr_number> --json number`.
  - If `0`, try `gh pr view <branch> --json number -q .number`.
  - If still absent, auto-create a draft PR. Use `body_path` if provided; otherwise find the newest `docs/executions/.pr-bodies/<date>-pr-*.md` whose name or content references `<branch>`. If no body is available, abort and ask the user to run `/describe-pr` or pass `body_path=`.
  - Create with `gh pr create --draft --base <base> --head <branch> --title <derived-from-first-commit> --body-file <path>`, then capture the new PR number.
- Compute `<YYYY-MM-DD>`, ensure `docs/executions/.ci-runs/` exists, initialize `M = 1`, `prior_signature = None`, and `auto_fix_commits = []`.

### Step 1: Poll CI

Use `gh pr checks <pr_number> --watch` when supported. Otherwise poll:

```bash
while true; do
  status=$(gh pr checks <pr_number> --json bucket -q '.[].bucket' | sort -u)
  case "$status" in
    *fail*) break ;;
    pass) break ;;
    *) sleep 30 ;;
  esac
done
```

Cap each attempt at 30 minutes. If checks remain queued or in progress past the cap, halt for human input and record the pending state.

After polling, fetch complete check state:

```bash
gh pr checks <pr_number> --json name,bucket,workflow,event,description,detailsUrl
```

If all checks pass, go to Step 4. If any check fails, continue to Step 2.

### Step 2: Classify Failures

Fetch failed logs with `gh run view <run-id> --log-failed`, then load `references/ci-classifier.md` and classify every failed job into exactly one bucket.

### Step 3: Check Progress And Dispatch Fixes

Using `references/ci-classifier.md`, compute the failure signature. Halt if it matches `prior_signature`; otherwise set `prior_signature = sig`.

Before dispatching fixes, halt if any of these are true:

- `M > max_attempts`.
- Any failed job classifies as `test-logic`, `build-infra`, `security`, or `unknown`.
- The branch cannot be pushed without force or human intervention.

For auto-fixable classes, dispatch tightly scoped fixes and commit only the fix output:

- `format`: run the repo formatter on the changed-files set. Commit as `ci-fix(format): apply <tool> to changed files`.
- `lint`: apply linter autofixes where available, patch by hand only for non-autofixable rules. Commit as `ci-fix(lint): <one-liner from rule list>`.
- `type`: patch only the cited type errors. Commit as `ci-fix(type): tighten <symbol> at <file>:<line>`.
- `test-assertion`: patch implementation or test according to the assertion delta. Commit as `ci-fix(test): <symbol> assertion`.

After each successful fix commit, `git push origin <branch>` and append the commit hash to `auto_fix_commits`. Write the attempt outcome using `references/outcome-file-template.md`, increment `M`, and return to Step 1.

### Step 4: Monitor Review Agents And Incorporate Feedback

When checks pass, load `references/approve-and-review-gates.md`.

- If `no_review == true`, require either an explicit user waiver or a complete `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE` plus an explicit user waiver for skipping `/watch-ci` self-review. If neither exists, halt.
- If `no_review == true`, skip self-review agents only after that evidence/waiver is recorded, and still monitor and resolve any existing PR comments.
- Otherwise run the always-on OMC `security-reviewer` pass.
- Run `/review` on auto-fix commits and on any reviewer-feedback fix commits created by this skill.
- Poll PR reviews and inline comments for reviewer-agent feedback.
- Invoke `receive-review` to incorporate every actionable item: blockers, non-blockers, observations, comments, questions, and nits.
- After pushing feedback fixes, return to Step 1 because CI and reviewers may rerun.
- Continue until CI is green and no new actionable reviewer feedback arrives for `review_quiet_minutes`.

### Step 5: Halt Path

Halt for no-progress, max attempts, out-of-scope failures, rejected push, CI timeout, unresolved reviewer comments, technically invalid/conflicting feedback, or non-clean review results.

On halt:

- Write the attempt outcome using `references/outcome-file-template.md`.
- For exhaustion or no-progress, write the handoff artifact using `references/exhaustion-handoff.md`.
- Post the halt comment using `references/pr-comment-template.md`, unless `dry_run == true`.
- Surface the blocker to chat and exit non-zero.
- Do not approve, mark ready, merge, or enable auto-merge.

### Step 6: Post Comment And Hand Back PR To Caller

Reached only on green CI with self-review complete or explicitly skipped.

- Post the summary comment using `references/pr-comment-template.md`, unless `dry_run == true`.
- Do not submit `gh pr review --approve`.
- Do not mark the PR ready for review.
- Do not merge or enable auto-merge.
- Hand back the PR to the caller with evidence: CI status, feedback incorporated, unanswered comments count, and outcome file path. If invoked inside `workflow-finalize`, the PR remains draft until `workflow-finalize` applies the repo delivery policy.

### Step 7: Write Outcome File

Write `docs/executions/.ci-runs/<date>-pr-<pr_number>-attempt-<M>.md` using `references/outcome-file-template.md`. Include CI status, review-agent monitoring status, feedback incorporation summary, and remaining human actions on the final green attempt.

### Step 8: Surface To User

Use the chat summary format in `references/outcome-file-template.md`: one-sentence verdict, PR URL, outcome file path, blocker and next step when halted, or `PR checks and review monitoring are clean; final PR action remains with workflow-finalize or the user.` when clean.

## Pairing

Typical workflows: `workflow-finalize` after draft PR creation and review-comment handling, before repo-policy-controlled final action.
Pairs well with: `workflow-finalize`, `receive-review`, `setup-worktree`, `workflow-debug`.

For examples and larger workflow context, load `references/examples.md`.
