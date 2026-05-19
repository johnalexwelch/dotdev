---
name: workflow-finalize
description: Universal delivery closure after review passes (draft PR → reviewer comments → CI → reconcile → human merge)
---

# Workflow Finalize

## Purpose

Close the delivery loop after workflow-review approves. Handles draft PR creation/description, reviewer-comment resolution, CI monitoring, issue reconciliation, and the conditional post-mortem gate. Does not duplicate review or testing logic and never enables auto-merge.

## When to invoke

- workflow-review returns APPROVE verdict with dispatch evidence
- After any successful implementation plus explicit workflow-review cycle
- Explicitly when work is done and needs to ship

## Precondition

workflow-review must have returned APPROVE with dispatch evidence. If it hasn't run, lacks dispatch evidence, or returned REQUEST CHANGES / NEEDS HUMAN, halt and direct back to review.

Do not accept substitutes for this precondition. Green CI, passing tests, GitHub reviews, Claude Code Review, Bugbot, Codex review, resolved PR comments, or `receive-review` output are not enough unless the `workflow-review` synthesis exists and says APPROVE.

The precondition is satisfied only by a complete `WORKFLOW_REVIEW_GATE` block from `workflow-review` with `verdict: APPROVE`. If the block is absent, incomplete, or self-reported without real subagent dispatch, halt. Do not reconstruct it from prose.

The delivery branch must also have `WORKTREE_BASELINE_GATE` evidence showing it was cut from `origin/staging`, or valid `STACKED_WORKTREE_GATE` evidence showing it was cut from a clean parent branch and targets that parent branch. If the work was done in the primary checkout, on a branch based on local `main`/`staging`, or in a stacked child that targets `staging` directly, halt and require a valid worktree.

If the change is frontend or user-facing, `user-journey-qa` must also have returned PASS or have an explicit user waiver before finalization proceeds.

## Flow

```
[conditional post-mortem gate] → describe-pr → ensure draft PR → receive-review → watch-ci → reconcile-issues → verification gate
```

### Step 0.5: Conditional Post-mortem Gate

- Required before `describe-pr` for audit-loop work, multi-phase execution, significant drift, or `NEW-NN` findings.
- The post-mortem output is consumed by `describe-pr`, so do not generate the PR body first for audit-loop or multi-phase work.
- Skip only for routine single-issue work with no meaningful drift, and record `not_applicable_with_reason` in `WORKFLOW_FINALIZE_GATE`.

### Step 1: Describe PR (describe-pr)

- Load and execute `describe-pr/SKILL.md`. Do not hand-roll the PR body in `workflow-finalize`.
- `describe-pr` must write a body file under `docs/executions/.pr-bodies/` before any draft PR is created or updated.
- Pass the resolved `branch`, `base`, discovered `pr_number` if one exists, and `apply=false` when no PR exists yet. If a PR already exists, either pass `apply=true` or apply the returned body file in Step 1.5.
- The generated body must include issue awareness and a disposition table for all referenced issues when issues are discovered.
- Record describe-pr evidence for the final gate: body file path, mode (`plan_backed`, `phase_run_backed`, or `issue_only`), issue refs discovered, phase evidence status, and deviation/new-finding counts when applicable.
- If `describe-pr` halts because required phase evidence is missing for audit-loop or multi-phase work, halt finalization. Do not create a draft PR with a replacement body unless the user explicitly waives phase evidence.
- For routine single-issue work with no design plan or phase-run files, `describe-pr` must run in issue-only mode using git log/diff plus issue discovery; absence of a design plan is not a reason to skip `describe-pr`.

### Step 1.5: Ensure Draft PR Exists

- Push the branch to origin.
- If a PR exists, update the body with the file from `describe-pr`.
- If no PR exists, create one as draft with `gh pr create --draft --body-file <pr-body-path>`.
- If an existing PR is not draft, continue but do not mark it ready or enable auto-merge automatically.
- Record PR number and URL before proceeding. Do not run `receive-review` until a PR exists.

### Step 2: Resolve PR Reviewer Comments (receive-review)

- Wait for expected reviewer bots when configured for the repo (Claude, Codex, Bugbot, or repo-specific bots)
- Fetch all review-level and inline comments via GitHub
- Invoke `receive-review` on every unresolved reviewer comment
- Address accepted blockers, non-blockers, and nits; reply to declined or clarified comments with evidence
- Push review-fix commits and re-check review threads
- If any code changes were pushed after the incoming `WORKFLOW_REVIEW_GATE`, rerun `workflow-review` on the updated diff and require a new `WORKFLOW_REVIEW_GATE` with `verdict: APPROVE` before continuing
- If any blocker, unresolved human disagreement, or unanswered reviewer question remains: **halt** with auto-handoff

This gate applies to bot and human review comments. A green CI run does not override unresolved review feedback.

### Step 3: Watch CI (watch-ci)

- Monitor GitHub Actions
- Auto-fix up to 3 attempts on failure
- If any CI auto-fix changes code after the latest `WORKFLOW_REVIEW_GATE`, rerun `workflow-review` on the updated diff and require a new `WORKFLOW_REVIEW_GATE` with `verdict: APPROVE` before continuing
- If exhausted: **auto-handoff** (exit_reason: halt, remaining: CI diagnosis needed, include CI logs and what was tried) then halt
- If green: proceed

### Step 4: Reconcile Issues (reconcile-issues)

- Check referenced issues against PR dispositions
- Check for unresolved or unanswered PR reviewer comments before merge
- Verify labels are consistent
- Flag any drift before merge
- If issue-label drift found: report but don't block (info-level)
- If unresolved reviewer comments remain: block final handoff and route back to Step 2

### Step 5: Post-CI Retro Addendum (conditional)

- Triggered when:
  - CI required auto-fixes (something unexpected happened)
  - `watch-ci` discovered new follow-up work after the PR body was generated
- Append to the existing post-mortem or create a small follow-up note. Do not require `describe-pr` to consume this late addendum.
- Skip only for routine single-issue work with no CI auto-fixes and no new follow-up work.

### Step 6: Verify before handoff

Before declaring the PR ready for human review/merge, run a verification gate:

1. **Run repo verification commands** — execute the project's test/build/lint suite one final time against the PR branch. Check `package.json` scripts, `Makefile` targets, or CI workflow definitions for the canonical commands.
2. **Confirm verification passes** — do not claim "tests pass" without running them. If any command fails, halt and fix before proceeding.
3. **Confirm review comment resolution** — fetch review threads/comments one final time. If any actionable reviewer comment has no fix, reply, or explicit human waiver, halt before handoff.
4. **Confirm review freshness** — verify the latest `WORKFLOW_REVIEW_GATE` was produced after the final code-changing commit. If finalization pushed review-fix or CI-fix commits after the last review gate, halt and rerun `workflow-review`.
5. **Check for large diffs** — run `git diff --stat origin/<base>..HEAD | tail -1` and parse the file count. If **>15 files changed** or **>500 lines changed**, flag for potential PR splitting:
   - Suggest using the Cursor `split-to-prs` skill to break into reviewable chunks
   - If the changes are logically atomic (single feature, single refactor), proceed but note the size in the PR description
   - If the changes span unrelated concerns, **halt** and split before merging

### Step 7: Long-lived PR maintenance (conditional)

If the PR has been open >24 hours or has accumulated >5 review comments:

- Use the Cursor `babysit` skill pattern: triage all unresolved comments, sync with base branch if conflicts exist, and fix any new CI issues from the sync
- This step is skipped for fresh PRs that go straight through

## Completion

When all steps pass:

- Leave the PR in draft mode unless the user explicitly asks to mark it ready for review
- Do **not** enable auto-merge
- Report final status to user with **evidence** (test output, CI link, verification command results, comment-resolution summary)
- Include the required `WORKFLOW_FINALIZE_GATE` block in the final response and any handoff artifact
- When invoked by `run-backlog`, `workflow-autonomous-backlog`, Codex, or any AFK worker, always write a per-issue handoff artifact even when no follow-up work remains. Include PR URL, all gate blocks, verification evidence, review-comment resolution, CI status, issue reconciliation, and residual risks.
- If follow-up work was discovered (NEW-NN findings, post-mortem action items, reconciliation drift): **auto-handoff** (exit_reason: completion with follow-ups, remaining: the follow-up items with prompt-builder outputs)
- If no remaining work and this was not an AFK/backlog/Codex run: skip handoff
- After human merge or explicit abandonment, use `cleanup-delivery` to remove stale local worktrees/branches and reconcile ticket residue. Do not run cleanup before the human merge/abandonment decision.

## Required Gate Block

Every valid `workflow-finalize` run must emit this block verbatim:

```markdown
WORKFLOW_FINALIZE_GATE:
  worktree_baseline: origin/staging -> <branch> @ <worktree-path> OR stacked: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>
  workflow_review_gate: APPROVE
  post_mortem: completed|not_applicable_with_reason
  describe_pr: body_file=<docs/executions/.pr-bodies/...>; mode=plan_backed|phase_run_backed|issue_only; issues=<refs|none>; phase_evidence=matched|not_applicable|waived
  pr_state: draft|existing_non_draft_not_modified
  pr_number: <number>
  review_comments: all_resolved|human_waived
  ci: green
  issue_reconciliation: complete
  verification: passed
  merge_or_ready_action_taken: false
```

If this block is absent or incomplete, parent workflows must treat `workflow-finalize` as not run. `required_but_missing` is a halt state, never a completion value. A PR body, green CI, resolved comments, or a draft PR URL alone is not a valid finalization.

`workflow_review_gate: APPROVE` must refer to the latest review gate after all code-changing review fixes and CI fixes. If the branch changed after that gate, the finalization gate is invalid.

## Contract

Consumes: approved review verdict, committed code on branch, issue references, PR reviewer comments
Produces: draft PR ready for human review/merge, reconciliation report
Requires: gh, git, subagent-dispatch, project-test-runner
Side effects: creates/updates draft PR, pushes commits (review/CI fixes), posts comments
Human gates: missing workflow-review dispatch evidence; missing/failed user-journey QA for frontend or user-facing changes unless waived; unresolved reviewer comments; CI exhaustion halts for diagnose; post-mortem presented for review

## Context

Typical workflows: workflow-build-one (final step), workflow-debug (final step), workflow-autonomous-backlog (per-issue draft PR handoff)
Pairs well with: workflow-review (precondition), describe-pr, receive-review, watch-ci, reconcile-issues, cleanup-delivery, post-mortem, handoff (auto-invoked at halt or completion-with-follow-ups), split-to-prs (Cursor built-in, for large diffs), babysit (Cursor built-in, for long-lived PRs), run-backlog
