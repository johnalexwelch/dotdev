---
name: workflow-build-one
description: Implement one ready-for-agent issue end-to-end (preflight → execute → review → draft PR handoff)
---

# Workflow Build One

## Purpose

Take a single `ready-for-agent` issue and drive it from implementation through draft PR handoff. This is the standard "build one thing" workflow — the workhorse for individual issue execution.

## When to invoke

- workflow-router classifies work as "ready issue"
- User points at a specific issue and says "build this"
- run-backlog dispatches individual issue execution
- Issue has `ready-for-agent` label and clear acceptance criteria

## Flow

```
per-issue origin/staging worktree → preflight → triage → execute-phase → workflow-review → [conditional blocking] user-journey-qa → workflow-finalize
```

## Per-Issue Worktree Invariant

Every root issue must cut its own fresh isolated worktree from `origin/staging` before implementation starts. Stacked dependent issues may instead cut their own fresh worktree from a clean parent branch when the parent PR has complete gate evidence and the child PR targets the parent branch. This is mandatory for single-issue runs, `run-backlog` dispatches, and manual invocations.

Do not reuse another issue's worktree. Do not work from the primary checkout. Do not start from local `main`, local `staging`, or an already-dirty branch. If the worktree cannot be created or verified, halt before changing code.

### Step 0: Preflight

- Read only issue metadata needed to derive the branch/worktree name and detect obvious blockers. Do not search or read repo code from the primary checkout.
- Check `Requires` from target skills' contracts (are tools available?)
- If missing tools: **auto-handoff** (exit_reason: halt, remaining: install missing tools then retry) and halt
- If issue is unclear: **auto-handoff** (exit_reason: halt, blocker: what's ambiguous and what question to answer) and halt
- Create a fresh isolated worktree for this issue before any implementation.
  Root issue:
  `git fetch origin --prune && git worktree add -b <issue-branch> <worktree-path> origin/staging`
  Stacked dependent issue:
  `git fetch origin --prune && git worktree add -b <child-branch> <child-worktree-path> <parent-branch>`
- Run the rest of this workflow from inside that worktree. If already inside a worktree, verify it has `WORKTREE_BASELINE_GATE` or valid `STACKED_WORKTREE_GATE`; otherwise halt and recreate it.
- Record `WORKTREE_BASELINE_GATE: origin/staging -> <issue-branch> @ <worktree-path>` or `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete` in the handoff/final summary.
- From inside the worktree, invoke or re-run `prompt-builder` to gather repo/code context, decision-log rationale, determine execution strategy, identify files to read, and discover verification commands. A prompt-builder output created outside the per-issue worktree is bootstrap context only; it does not satisfy repo/code context gathering.

### Step 1: Triage (quick)

- Confirm issue is well-formed for autonomous execution
- Verify: clear acceptance criteria, no ambiguous requirements, no human-only decisions
- If not AFK-safe: halt with explanation of what needs human input

### Step 2: Execute (execute-phase)

- Use the branch/worktree created from `origin/staging` or a valid stacked parent branch; do not create feature branches from local `main` or the primary checkout
- Implement against acceptance criteria
- Honor relevant decision-log entries and accepted tradeoffs; do not re-open settled choices unless implementation evidence invalidates them
- Use appropriate execution profile (normal by default, strict-tdd for bugs)
- Commit incrementally with issue references

### Step 3: Review (workflow-review)

- Load and run `workflow-review/SKILL.md` explicitly. Do not treat tests, green CI, GitHub reviews, Claude Code Review, Bugbot, Codex review, or resolved PR comments as satisfying this step.
- Dispatch parallel reviewers on the diff
- Require dispatch evidence from `workflow-review`: active lanes, subagent types, skipped-with-reason conditional lanes, and synthesized verdict
- Require the `WORKFLOW_REVIEW_GATE` block with `verdict: APPROVE`. If the block is missing or incomplete, treat review as not run and halt.
- If APPROVE: proceed to finalize
- If REQUEST CHANGES: iterate (max 2 rounds, then **auto-handoff** with review findings and halt)
- If NEEDS HUMAN: **auto-handoff** (exit_reason: halt, blocker: what the reviewer flagged and what decision is needed) and halt

### Step 4: User Journey QA (conditional blocking gate)

Trigger when ANY of these are true:

- Issue touches frontend code
- Issue modifies user-facing behavior
- Issue changes auth, navigation, or payment flows
- Issue body mentions UX acceptance criteria

Skip when the change is purely backend/infrastructure/tooling.

When triggered, this is a blocking gate. Proceed to `workflow-finalize` only when `user-journey-qa` returns PASS or the user explicitly waives the QA risk. If QA returns FAIL/PARTIAL or cannot run because journeys, app URL, or Playwright MCP are unavailable, **auto-handoff** with the QA blocker and halt.

### Step 5: Finalize (workflow-finalize)

- Load and run `workflow-finalize/SKILL.md`; do not replace it with direct PR creation commands.
- `workflow-finalize` owns `describe-pr`, so the worker must preserve the generated PR body file path and `describe_pr` evidence in `WORKFLOW_FINALIZE_GATE`.
- Open or update a **draft PR**
- Resolve and respond to all reviewer comments: blockers, non-blockers, nits, questions, and declined suggestions
- Monitor CI
- Reconcile issues
- Do **not** enable auto-merge; leave final merge/mark-ready decision to the user
- Require the `WORKFLOW_FINALIZE_GATE` block before completion. If missing, auto-handoff with blocker: `workflow-finalize did not run to completion`.

## Iteration limits

- Review iterations: max 2 before auto-handoff and halt
- CI fix attempts: max 3 (inherited from watch-ci, auto-handoff on exhaustion)
- Total workflow time: no hard limit, but emit progress updates every 10 minutes

## Exit behavior

Every halt produces an auto-handoff. Every completion checks for follow-up work. No workflow exit should lose context.

## Contract

Consumes: GitHub issue (ready-for-agent, with acceptance criteria), codebase
Produces: draft PR ready for human review/merge, updated issue state
Requires: gh, git, subagent-dispatch, project-test-runner
Side effects: creates branch, commits, PR; may modify issue labels
Human gates: unclear issue halts (with auto-handoff); NEEDS HUMAN review halts (with auto-handoff); user-journey QA failure/unavailability halts unless waived (with auto-handoff); CI exhaustion halts (with auto-handoff); review iteration limit halts (with auto-handoff)

Runtime note: project build/test tools are required for verification and are discovered from repo files (`package.json`, `Makefile`, CI workflows, language-specific config). Per-issue worktree creation from `origin/staging` is a hard precondition, not a convenience step.

## Context

Typical workflows: standalone (primary build workflow), run-backlog (dispatched per-issue)
Pairs well with: workflow-router (routes here), workflow-review, workflow-finalize, execute-phase, prompt-builder (provides pre-gathered execution context)
