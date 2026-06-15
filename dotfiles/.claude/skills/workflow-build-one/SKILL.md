---
name: workflow-build-one
model: sonnet
reasoning: medium
description: Implement one ready-for-agent issue end-to-end (preflight → execute → review → repo-policy-controlled PR handoff)
---

# Workflow Build One

## Model selection

Run implementation steps on **Sonnet** (`model: sonnet`); reserve **Opus** for the design/review reasoning around them.

## Output discipline (during execution only)

While running the mechanical execution/implementation loop, compress **routine progress narration** to caveman style — drop articles, filler, and pleasantries; prefer `[thing] [action] [reason]. [next].` This cuts scroll and output tokens during the grind.

Snap back to **full prose** for anything that needs judgment: findings, scope violations, blockers, `NEEDS_HUMAN` gates, decisions/tradeoffs, and the final summary/handoff. The terseness is scoped to the loop — it ends when execution ends; do not carry it into the review or handoff that follows. See `caveman` for the full compression rules.

## Purpose

Take a single `ready-for-agent` issue and drive it from implementation through repo-policy-controlled PR handoff. This is the standard "build one thing" workflow — the workhorse for individual issue execution.

## When to invoke

- workflow-router classifies work as "ready issue"
- User points at a specific issue and says "build this"
- run-backlog dispatches individual issue execution
- Issue has `ready-for-agent` label and clear acceptance criteria

## Flow

```
per-issue workflow-base worktree → preflight → triage → execute-phase → workflow-review → [conditional blocking] user-journey-qa → workflow-finalize
```

## Workflow Progress Reporting

At the start of every run, display a step ledger **before executing or dispatching any step**. Use the exact step names from this skill and include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| Step 0: Preflight | required | pending | - |
| Step 1: Triage | required | pending | - |
| Step 2: Execute | required | pending | - |
| Step 3: Review (workflow-review) | required | pending | - |
| Step 4: User Journey QA | conditional | pending | - |
| Step 5: Finalize (workflow-finalize) | required | pending | - |
```

Rules:

- Initialize every step as `pending`. Update each to `completed`, `skipped`, `blocked`, or `failed` as it resolves.
- Steps 3 and 5 **cannot be skipped**. If they cannot run, mark `blocked` and halt.
- Step 4 may be `skipped` only for purely backend/infrastructure/tooling changes — record the reason.
- Include the final ledger in every halt, handoff, and completion response.
- A step is only `completed` when its required gate block exists in the output: Step 3 requires `WORKFLOW_REVIEW_GATE`, Step 5 requires `WORKFLOW_FINALIZE_GATE`.

## Per-Issue Worktree Invariant

Every root issue must cut its own fresh isolated worktree from the resolved workflow base before implementation starts. Load `setup-worktree/references/base-branch-policy.md`, record `WORKFLOW_BASE_GATE`, and use the resolved remote ref in all worktree gates. Stacked dependent issues may instead cut their own fresh worktree from a clean parent branch when the parent PR has complete gate evidence and the child PR targets the parent branch. This is mandatory for single-issue runs, `run-backlog` dispatches, and manual invocations.

Do not reuse another issue's worktree. Do not work from the primary checkout. Do not start from local `main`, local `staging`, or an already-dirty branch. If the worktree cannot be created or verified, halt before changing code.

### Step 0: Preflight

- Read only issue metadata needed to derive the branch/worktree name and detect obvious blockers. Do not search or read repo code from the primary checkout.
- Check `Requires` from target skills' contracts (are tools available?)
- If missing tools: **auto-handoff** (exit_reason: halt, remaining: install missing tools then retry) and halt
- If issue is unclear: **auto-handoff** (exit_reason: halt, blocker: what's ambiguous and what question to answer) and halt
- Create a fresh isolated worktree for this issue before any implementation.
  Root issue:
  `git fetch origin --prune && git worktree add -b <issue-branch> <worktree-path> <workflow-base-ref>`
  Stacked dependent issue:
  `git fetch origin --prune && git worktree add -b <child-branch> <child-worktree-path> <parent-branch>`
- Run the rest of this workflow from inside that worktree. If already inside a worktree, verify it has `WORKTREE_BASELINE_GATE` or valid `STACKED_WORKTREE_GATE`; otherwise halt and recreate it.
- Record `WORKFLOW_BASE_GATE` and `WORKTREE_BASELINE_GATE: <workflow-base-ref> -> <issue-branch> @ <worktree-path>` or `STACKED_WORKTREE_GATE: <workflow-base-ref> -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete` in the handoff/final summary.
- From inside the worktree, invoke or re-run `prompt-builder` to gather repo/code context, decision-log rationale, determine execution strategy, identify files to read, and discover verification commands. A prompt-builder output created outside the per-issue worktree is bootstrap context only; it does not satisfy repo/code context gathering.

### Step 1: Triage (quick)

- Confirm issue is well-formed for autonomous execution
- Verify: clear acceptance criteria, no ambiguous requirements, no human-only decisions
- If not AFK-safe: halt with explanation of what needs human input

### Step 2: Execute (execute-phase)

- Use the branch/worktree created from the resolved workflow base or a valid stacked parent branch; do not create feature branches from local `main` or the primary checkout
- Implement against acceptance criteria
- Honor relevant decision-log entries and accepted tradeoffs; do not re-open settled choices unless implementation evidence invalidates them
- Use appropriate execution profile (normal by default, strict-tdd for bugs)
- Commit incrementally with issue references

### Step 3: Review (workflow-review)

- **Use the Skill tool to invoke `workflow-review`** — do not inline review logic, self-review, or skip the skill invocation. "Load and run" means invoke the skill. Do not treat tests, green CI, GitHub reviews, Claude Code Review, Bugbot, Codex review, or resolved PR comments as satisfying this step.
- Select a risk-sized `review_profile` in `workflow-review`: `fast` for small low-risk changes, `standard` for normal issue work, `full` for broad or high-risk changes
- Require independent review evidence from `workflow-review`: review profile, active lanes, independent reviewer context/subagent types, skipped-with-reason conditional lanes, and synthesized verdict
- Require the `WORKFLOW_REVIEW_GATE` block with `review_profile`, `independent_review: true`, and `verdict: APPROVE`. If the block is missing or incomplete, treat review as not run and halt.
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

- **Use the Skill tool to invoke `workflow-finalize`**. Do not replace it with direct `gh pr create` or any other PR creation commands — `workflow-finalize` owns PR creation, description, CI monitoring, and issue reconciliation.
- `workflow-finalize` owns `describe-pr`, so the worker must preserve the generated PR body file path and `describe_pr` evidence in `WORKFLOW_FINALIZE_GATE`.
- Open or update a PR according to the caller's `REPO_DELIVERY_POLICY` when supplied:
  - `human-only` or no policy supplied: create/update a draft PR and leave final merge/mark-ready decisions to the user.
  - `auto-merge-eligible`: after all required gates pass, allow `workflow-finalize` to mark the PR ready and enable GitHub auto-merge.
- Resolve and respond to all reviewer comments: blockers, non-blockers, nits, questions, and declined suggestions
- Monitor CI
- Reconcile issues
- Do **not** approve, directly merge, force-push, rebase, or perform destructive git. Auto-merge may be enabled only by `workflow-finalize` when `REPO_DELIVERY_POLICY.mode: auto-merge-eligible`.
- Require the `WORKFLOW_FINALIZE_GATE` block before completion. If missing, auto-handoff with blocker: `workflow-finalize did not run to completion`.

## Iteration limits

- Review iterations: max 2 before auto-handoff and halt
- CI fix attempts: max 3 (inherited from watch-ci, auto-handoff on exhaustion)
- Total workflow time: no hard limit, but emit progress updates every 10 minutes

## Exit behavior

Every halt produces an auto-handoff. Every completion checks for follow-up work. No workflow exit should lose context.

## Pre-Completion Gate

Before declaring done, reporting completion, or producing a handoff, verify ALL three gate blocks exist in your output for this run:

1. **`WORKFLOW_BASE_GATE` and `WORKTREE_BASELINE_GATE`** — confirm isolated worktree from the resolved workflow base
2. **`WORKFLOW_REVIEW_GATE`** with `review_profile`, `independent_review: true`, and `verdict: APPROVE` — confirms `workflow-review` ran with independent evidence
3. **`WORKFLOW_FINALIZE_GATE`** — confirms `workflow-finalize` ran to completion

If any block is absent, **do not claim completion**. Load and run the missing skill via the Skill tool now, or produce an auto-handoff explaining why it could not run.

This check applies even when:

- The PR exists and CI is green
- Tests pass locally
- You reviewed the diff yourself
- PR comments are resolved

None of those substitute for the gate blocks. The gate blocks are the proof of record.

## Partial-Completion Contract

Before exiting, the executor MUST be in ONE of these three states. This is binding regardless of remaining token budget:

**A. Complete.** All changes committed and pushed to the remote branch.

**B. WIP-paused.** Current progress committed with a `wip:` prefix in the subject line, naming exactly what remains. Pushed.

**C. Rolled back.** `git reset --hard <baseline>` to leave the worktree clean.

Verification before exit: run `git status --short`. If ANY line shows `M` or `??` for a source file in the project tree, the contract is not satisfied. Commit or reset, then re-run `git status --short` until the worktree satisfies A, B, or C.

The final response and any handoff artifact must state which exit state was chosen, the commit pushed or baseline reset to, and the final `git status --short` result.

## Contract

Consumes: GitHub issue (ready-for-agent, with acceptance criteria), codebase
Produces: PR ready for human review/merge or auto-merge according to repo delivery policy, updated issue state
Requires: gh, git, subagent-dispatch, project-test-runner
Side effects: creates branch, commits, PR; may modify issue labels
Human gates: unclear issue halts (with auto-handoff); NEEDS HUMAN review halts (with auto-handoff); user-journey QA failure/unavailability halts unless waived (with auto-handoff); CI exhaustion halts (with auto-handoff); review iteration limit halts (with auto-handoff)

Runtime note: project build/test tools are required for verification and are discovered from repo files (`package.json`, `Makefile`, CI workflows, language-specific config). Per-issue worktree creation from the resolved workflow base is a hard precondition, not a convenience step.

## Context

Typical workflows: standalone (primary build workflow), run-backlog (dispatched per-issue)
Pairs well with: workflow-router (routes here), workflow-review, workflow-finalize, execute-phase, prompt-builder (provides pre-gathered execution context)
