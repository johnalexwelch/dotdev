---
name: run-backlog
model: sonnet
reasoning: medium
description: AFK backlog orchestrator — batch-process ready-for-agent issues via Codex (default) or Claude, with repo-policy-controlled draft vs auto-merge delivery
---

# Run Backlog

## Purpose

Autonomously process a queue of `ready-for-agent` issues without human supervision. Defaults to dispatching via Codex (through OMC team bridge) for natural isolation — each issue gets its own context and produces its own PR. Final PR handling is controlled by `references/repo-delivery-policy.md`: protected repos remain human-only, while other repos may mark ready and enable GitHub auto-merge after all gates pass.

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

Before Phase 1, load `references/outage-risk-policy.md` and `references/repo-delivery-policy.md`.

- `outage-risk-policy.md` decides whether an issue is AFK-safe; a priority label does not override it.
- `repo-delivery-policy.md` decides whether the current repository is `human-only` or `auto-merge-eligible`.

### Phase 0: Resolve repository delivery policy

1. Resolve the current repository with `gh repo view --json nameWithOwner`.
2. Compare `nameWithOwner` against `references/repo-delivery-policy.md`.
3. Record the result in the queue artifact:

```markdown
REPO_DELIVERY_POLICY:
  repository: <owner/name>
  mode: human-only|auto-merge-eligible
  source: run-backlog/references/repo-delivery-policy.md
  final_action_allowed: draft_handoff_only|mark_ready_and_enable_auto_merge
```

If repository identity cannot be resolved, halt before dispatch. Do not guess and do not default to auto-merge.

### Phase 1: Plan

1. Query GitHub Issues: `gh issue list --label ready-for-agent --state open --json number,title,labels,body`
2. Filter out issues marked `blocked`, `needs-human`, `ready-for-human`, or `in-progress`. Do not filter out `needs-human-review`; that label means the agent may implement but a human must validate the PR.
3. Exclude issues that violate `references/outage-risk-policy.md`, including unclear acceptance criteria, missing verification commands, high-risk release categories, missing rollback expectations, or outage-risk classifications of `high`/`excluded` without explicit human approval for that issue
4. For dependency chains, choose one of:
   - **sequential wait**: dependent issue waits until the parent PR is merged
   - **stacked development**: dependent issue may run before merge only when the parent PR has clean gate evidence and the dependent PR targets the parent branch
5. Rank by:
   - Priority label (critical > high > medium > low)
   - Dependencies (unblocked issues first)
   - Age (older issues first, as tiebreaker)
6. Produce work queue artifact:

```markdown
## Work Queue — [date]
| # | Issue | Priority | Dependencies | Stack mode | Risk | Human review | Verification | Est. Complexity |
|---|-------|----------|--------------|------------|------|--------------|--------------|-----------------|
| 1 | #N title | high | none | root | low | not required | test command | small |
| 2 | #M title | medium | #N | stacked-on-#N | medium-approved | required | lint+test | medium |
```

7. Present queue for approval. Auto-approve only when the user explicitly requested unattended/AFK backlog execution in this invocation; otherwise halt for approval. Record the approval evidence and `REPO_DELIVERY_POLICY` in the queue artifact.

### Phase 2: Dispatch

For each issue in queue order:

1. Apply `in-progress` label
2. Create or require the issue's worktree before repo/code context gathering:
   - **Root issue**: create from `origin/staging`.
   - `git fetch origin --prune && git worktree add -b <issue-branch> <issue-worktree-path> origin/staging`
   - Record `WORKTREE_BASELINE_GATE: origin/staging -> <issue-branch> @ <issue-worktree-path>` in the queue artifact.
   - **Stacked dependent issue**: only allowed when the parent PR has `WORKTREE_BASELINE_GATE`, `WORKFLOW_REVIEW_GATE` with `review_profile`, `independent_review: true`, and `verdict: APPROVE`, a complete `WORKFLOW_FINALIZE_GATE`, green CI, and no unresolved reviewer comments.
   - Create the dependent worktree from the parent branch, target the dependent PR at the parent branch, and record:
     `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete`
   - If worktree creation fails, remove `in-progress`, add `needs-human`, and do not dispatch.
3. Generate prompt via `prompt-builder` from inside that per-issue worktree:
   - Pass the issue number and target tool (codex or claude)
   - prompt-builder gathers repo/code context only after the per-issue worktree exists, determines execution strategy, and produces a structured prompt
   - In Codex mode, the generated prompt is the primary input to the dispatch (Codex cannot ask clarifying questions)
   - In Claude mode, the prompt seeds workflow-build-one with pre-gathered context
   - The prompt must instruct the worker to use this per-issue worktree, verify either `WORKTREE_BASELINE_GATE` or `STACKED_WORKTREE_GATE`, and include the matching gate evidence in the handoff.
   - If the prompt lacks the per-issue worktree/stack command or gate requirement, do not dispatch the issue; regenerate the prompt or mark the issue `needs-human`.
   - If the issue has `needs-human-review`, `Human review: required`, or an equivalent human-review gate, the prompt must include the issue's concrete `## Reviewer validation steps` and instruct the worker to preserve them through `describe-pr`/`workflow-finalize` so the PR body ends with that section.
   - The prompt must include `REPO_DELIVERY_POLICY` and instruct the worker to follow it:
      - `human-only`: create or update only a draft PR unless an existing non-draft PR already exists; do not mark ready, approve, merge, or enable auto-merge.
      - `auto-merge-eligible`: after all required gates pass, mark the PR ready and enable GitHub auto-merge. Prefer auto-merge over direct immediate merge.
      - Human-review-required issues override auto-merge eligibility: leave the PR draft or otherwise blocked for human validation, and do not mark ready, merge, or enable auto-merge until the human validation is complete.
   - The prompt must include the Partial-Completion Contract from `workflow-build-one`: before exit the worker must be Complete (all changes committed and pushed), WIP-paused (pushed `wip:` commit naming exactly what remains), or Rolled back (`git reset --hard <baseline>` with a clean worktree).
   - The prompt must require final `git status --short`; if any source file shows `M` or `??`, the worker must commit or reset and re-check before exiting.
4. Dispatch:
   - **Codex mode**: require `omc`; if unavailable, halt for user approval before switching modes. Do not silently downgrade AFK isolation to direct Claude execution.
   - **Claude mode**: invoke workflow-build-one with the generated prompt as context
5. Each dispatch is independent — failure of one does not block others

### Phase 3: Monitor

1. Poll PR status: `gh pr list --state open --json number,title,isDraft,statusCheckRollup`
2. For each completed dispatch:
   - PR or handoff lacks `WORKTREE_BASELINE_GATE: origin/staging -> ...` or valid `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> ...` → flag `needs-human`; do not accept work from primary checkout or a local-main branch
   - Stacked PR does not target its parent branch, or parent gate evidence is missing/stale → flag `needs-human`
   - PR lacks a complete `WORKFLOW_REVIEW_GATE` block with `review_profile`, `independent_review: true`, and `verdict: APPROVE` → flag `needs-human`; green CI or GitHub/Claude/Codex/Bugbot review does not satisfy the review gate
   - PR lacks a complete `WORKFLOW_FINALIZE_GATE` block → flag `needs-human`; a PR URL, draft PR, or green CI alone does not satisfy finalization
   - Issue has `needs-human-review`, `Human review: required`, or an equivalent human-review gate, but the PR body does not end with `## Reviewer validation steps` → flag `needs-human`; rerun finalization only after the issue contains concrete reviewer validation steps
   - PR or handoff lacks Partial-Completion Contract evidence → flag `needs-human`; require one of Complete, WIP-paused, or Rolled back plus final `git status --short`
   - Handoff reports dirty source files after final `git status --short` → flag `needs-human`; do not accept work that exits with uncommitted source changes
   - `human-only` repo: PR is not draft and does not have `pr_state: existing_non_draft_not_modified` in `WORKFLOW_FINALIZE_GATE` → flag `needs-human`; do not mark ready or accept silently promoted PRs
   - `auto-merge-eligible` repo with no human-review requirement: PR is not marked ready or does not have auto-merge enabled after all gates pass → rerun finalization once; if still missing, flag `needs-human`
   - Human-review-required issue: require `WORKFLOW_FINALIZE_GATE.pr_state: pending_human_validation` or an equivalent draft/pending-human state; do not mark the issue `done` until human validation is recorded or the PR is merged by a human
   - PR failed CI → leave for watch-ci auto-fix (or flag for human if exhausted)
   - PR needs review → leave (workflow-build-one handles its own review cycle)
   - PR merged by GitHub auto-merge and all required gate blocks are present → update issue label to `done`, remove `in-progress`
   - Dispatch failed → remove `in-progress`, add `needs-human` label, log failure
3. Re-check `references/outage-risk-policy.md`; if a completed PR touched an excluded/high-risk category that was not approved, label `needs-human` and do not mark the issue done
4. After all dispatches complete: invoke reconcile-issues for drift check
5. Produce summary:

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

6. **Auto-handoff** at end of run:
   - Always produce a handoff, even on 100% success (the summary alone is valuable context)
   - exit_reason: `backlog run complete`
   - remaining: failed issues (with error context), pending-review PRs, any `needs-human` items flagged during run
   - Include AFK approval evidence, queue risk decisions, repo delivery policy, PR final action status, and gate status for every dispatched issue
   - Include prompt-builder outputs for any failed issues that are retryable
   - Store at `docs/executions/handoffs/<date>-backlog-run.md`

## State management

All state lives in GitHub Issues (labels):

- `ready-for-agent` → ready for pickup
- `in-progress` → currently being worked
- `done` → completed
- `needs-human` → requires human intervention
- `needs-human-review` → agent may implement, but PR requires human validation before completion/merge
- `blocked` → dependency not met

Work queue artifact is written to `docs/executions/backlog-runs/[date].md` for audit trail.

## Safety

- Max concurrent dispatches: 5 (prevent resource exhaustion)
- Max total issues per run: 20 (prevent runaway)
- Skip issues with `needs-human` or `blocked` labels
- Do not skip `needs-human-review`; carry its reviewer validation steps into the worker prompt and final PR body.
- If an issue's acceptance criteria are unclear, skip it and add `needs-human` label
- Never dispatch dependency chains in parallel unless using the stacked development rules above.
- Every dispatched root issue must create its own fresh `origin/staging` worktree before code changes; stacked dependent issues must create their own fresh worktree from the clean parent branch. Shared worktrees and primary-checkout work are invalid.
- Every dispatched worker must satisfy the Partial-Completion Contract before exit: Complete and pushed, WIP-paused with a pushed `wip:` commit naming exactly what remains, or Rolled back to the baseline with a clean worktree. A dirty source tree after `git status --short` is never an acceptable AFK exit.
- Apply `references/outage-risk-policy.md` before dispatch and again before marking outcomes successful
- Apply `references/repo-delivery-policy.md` before dispatch and before any final PR action
- `human-only` repos: do not mark PRs ready, approve, merge, enable auto-merge, force-push, rebase, or perform destructive git in an AFK run
- `auto-merge-eligible` repos: after all required gates pass, mark PRs ready and enable GitHub auto-merge; do not force-push, rebase, or perform destructive git

## Contract

Consumes: GitHub Issues (ready-for-agent labeled), repo access
Produces: PRs (one per issue), backlog run summary, updated issue labels
Requires: gh, omc, git, subagent-dispatch, project-test-runner
Side effects: creates branches/PRs, modifies issue labels, writes run summary file
Human gates: work queue approval unless explicitly AFK-approved in the current invocation; high-risk outage categories require explicit issue-level approval; failed dispatches flagged; PRs lacking workflow-review independent review evidence flagged `needs-human`; release/merge remains human-only only for repositories listed as `human-only` in `references/repo-delivery-policy.md`

Runtime note: requirements are conservative because the default mode is Codex and Claude fallback delegates to `workflow-build-one`. If the user explicitly selects Claude mode and `omc` is the only missing dependency, halt and ask whether to proceed in Claude mode; do not silently downgrade.

## Mode-Specific Preflight Gates

Before Phase 1:

- If mode is Codex/default: require `gh` and `omc`. If `omc` is unavailable, halt unless the user explicitly approves switching to Claude mode.
- If mode is Claude: require `gh`, `git`, `subagent-dispatch`, and `project-test-runner` because execution delegates to `workflow-build-one`.
- Do not dispatch any issue until the selected mode's requirements pass.

## Context

Typical workflows: standalone (periodic AFK execution), after workflow-feature (processes produced issues), workflow-autonomous-backlog (module discovery through backlog handoff)
Pairs well with: workflow-build-one (Claude mode), reconcile-issues (post-run cleanup), triage (pre-run preparation), prompt-builder (generates per-issue prompts before dispatch), handoff (mandatory end-of-run exit), workflow-effectiveness-audit (post-run governance)
