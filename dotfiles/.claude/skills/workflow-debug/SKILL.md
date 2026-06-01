---
name: workflow-debug
description: Bug diagnosis to fix (all bug work begins with diagnose, no exceptions)
---

# Workflow Debug

## Purpose

Drive a bug from report through diagnosis to verified fix. The cardinal rule: **all bug work begins with diagnose.** Even if the fix appears obvious, run diagnose first — it builds the artifact that proves understanding and prevents wrong fixes.

## When to invoke

- workflow-router classifies work as "bug"
- User reports a bug or unexpected behavior
- CI failure that isn't a simple lint/format issue
- Regression detected
- watch-ci exhausts auto-fix attempts and produces handoff artifact

## Cardinal rule

**Never route bugs to workflow-build-one**, even if the fix appears trivial. Bugs must go through diagnosis to:

1. Confirm the root cause (not just the symptom)
2. Produce evidence (the diagnosis artifact)
3. Determine if the fix is AFK-safe
4. Identify regression test needs

## Flow

```text
root worktree from origin/staging OR valid stacked worktree from parent branch → diagnose → triage → [tdd OR execute-phase] → workflow-review → [conditional blocking] user-journey-qa → workflow-finalize
```

## Workflow Progress Reporting

At the start of every run, display a step ledger before executing or dispatching any step. Use the exact step names from this skill and include conditional or optional steps.

```markdown
WORKFLOW_STEPS:
| Step | Required? | Status | Evidence / Skip Reason |
|------|-----------|--------|------------------------|
| <step name> | required|conditional|optional | pending|completed|skipped|blocked|failed|not_applicable | <evidence, reason, or -> |
```

Rules:

- Initialize every known step as `pending`; conditional steps remain `pending` until their trigger is evaluated.
- As each step finishes or is skipped, update the ledger with the new status and evidence or reason.
- A step may be `skipped` only when this skill explicitly makes it optional/conditional or a routing decision stops the workflow; record the exact reason.
- Do not mark required gates as skipped. If a required gate cannot run, mark it `blocked` or `failed` and halt according to this workflow.
- At every halt, STOP, handoff, and final completion, include the final ledger in the response or artifact.
- The final ledger must distinguish `completed`, `skipped`, `blocked`, `failed`, and `not_applicable`, and every non-completed status must include a reason.


### Step 0: Worktree Baseline Gate

- Run `git fetch origin --prune`.
- Create a fresh isolated worktree for this issue/bug before diagnosis or implementation.
  Root bug:
  `git worktree add -b <bugfix-branch> <worktree-path> origin/staging`.
  Stacked dependent bug:
  `git worktree add -b <child-branch> <child-worktree-path> <parent-branch>`.
- Run diagnosis, implementation, review, and finalization from inside that worktree.
- If already inside a worktree, verify it has `WORKTREE_BASELINE_GATE` or valid `STACKED_WORKTREE_GATE`; otherwise halt and recreate it.
- Do not reuse another issue's worktree or work from the primary checkout.
- Record `WORKTREE_BASELINE_GATE: origin/staging -> <bugfix-branch> @ <worktree-path>` or `STACKED_WORKTREE_GATE: origin/staging -> <parent-branch> -> <child-branch> @ <child-worktree-path>; parent_pr: #<n>; parent_gates: complete` in the diagnosis artifact and final handoff.

### Step 1: Diagnose (diagnose)

- Select mode based on bug characteristics:
  - Simple/clear reproduction → **quick** mode
  - Standard bug → **standard** mode
  - Intermittent/complex → **deep** mode
  - Live system issue → **production** mode
  - Was working before → **regression** mode
- Produce diagnosis artifact
- Emit routing recommendation

### Step 2: Triage routing decision

Based on diagnose routing output:

- **direct-fix** → proceed to Step 3
- **follow-up-issue** → create issue, **auto-handoff** (exit_reason: completion with follow-ups, remaining: the created issue), and STOP
- **architecture-review** → invoke improve-codebase-architecture, **auto-handoff** (exit_reason: halt, remaining: architecture review findings to act on), and STOP
- **needs-human** → **auto-handoff** (exit_reason: halt, blocker: what the human needs to decide, include diagnosis artifact path) and halt
- **unsafe-for-afk** → **auto-handoff** (exit_reason: halt, blocker: what makes it unsafe, include fix plan and diagnosis artifact) and halt

### Step 3: Implement fix

Choose approach based on bug nature:

| Condition | Approach |
|-----------|----------|
| Behavior bug (wrong output) | **tdd** — write failing test first, then fix |
| Crash/exception | **execute-phase** with strict-tdd profile |
| Performance regression | **execute-phase** with normal profile |
| Configuration/environment | **execute-phase** with safe profile |

In ALL cases: the regression test from the diagnosis artifact must be written.

### Step 4: Review (workflow-review)

- Load and run `workflow-review/SKILL.md` explicitly
- Risk-sized review with independent review evidence: `standard` by default for bug fixes, `full` when the root cause touches auth/data/infra/concurrency/broad behavior, and `fast` only for narrow test-only or non-production fixes
- Require review profile, active lanes, independent reviewer context/subagent types, skipped-with-reason conditional lanes, and synthesized verdict
- Require the `WORKFLOW_REVIEW_GATE` block with `review_profile`, `independent_review: true`, and `verdict: APPROVE`. If missing or incomplete, review has not run.
- Security reviewer mandatory if bug was in auth/data handling
- If REQUEST CHANGES: iterate (max 2 rounds)
- Do not treat tests, green CI, GitHub reviews, Claude Code Review, Bugbot, Codex review, or resolved PR comments as satisfying this step

### Step 5: User Journey QA (conditional blocking gate)

- Same trigger conditions as workflow-build-one
- Additionally triggered if the bug was user-reported (not CI/automated)
- When triggered, this is a blocking gate. Proceed to `workflow-finalize` only when `user-journey-qa` returns PASS or the user explicitly waives the QA risk. If QA returns FAIL/PARTIAL or cannot run because journeys, app URL, or Playwright MCP are unavailable, **auto-handoff** with the QA blocker and halt.

### Step 6: Finalize (workflow-finalize)

- PR description references the original bug report/issue
- Includes link to diagnosis artifact in PR body
- Issue disposition: Fixes #N
- Completion requires the `WORKFLOW_FINALIZE_GATE` block. If missing, halt with auto-handoff; do not report the bug as shipped or ready.

## Contract

Consumes: bug report (issue, user description, or watch-ci handoff artifact), codebase
Produces: verified fix with regression test, draft PR ready for human review/merge, diagnosis artifact
Requires: gh, git, subagent-dispatch, project-test-runner
Side effects: creates branch, commits, PR; creates diagnosis artifact file
Human gates: needs-human/unsafe-for-afk routing halts (with auto-handoff); architecture-review redirects (with auto-handoff); user-journey QA failure/unavailability halts unless waived (with auto-handoff); review iteration limit halts (with auto-handoff via workflow-finalize)

Runtime note: the repo's test runner is required for verification and is discovered from project files or CI workflows.

## Context

Typical workflows: standalone (primary debug workflow)
Pairs well with: diagnose (mandatory first step), tdd (preferred fix approach), workflow-review, workflow-finalize, handoff (auto-invoked at every halt point)

## Exit behavior

Every halt and every STOP in this workflow produces an auto-handoff with full context for the next session. No exit should lose diagnostic state.

Before exiting after any source changes, enforce the Partial-Completion Contract from `workflow-build-one`. The executor must be in exactly one state:

- Complete: all changes committed and pushed to the remote branch.
- WIP-paused: current progress committed with a `wip:` prefix in the subject line, naming exactly what remains, then pushed.
- Rolled back: `git reset --hard <baseline>` leaves the worktree clean.

Run `git status --short` before exit. If any source file shows `M` or `??`, the contract is not satisfied; commit or reset and re-check before exiting. The diagnosis artifact and handoff must record the chosen exit state, pushed commit or reset baseline, and final `git status --short` result.
