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

```
diagnose → triage → [tdd OR execute-phase] → workflow-review → [optional] user-journey-qa → workflow-finalize
```

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
- **follow-up-issue** → create issue and STOP (bug needs more work than a single fix)
- **architecture-review** → invoke improve-codebase-architecture and STOP
- **needs-human** → halt with artifact
- **unsafe-for-afk** → halt with artifact + fix plan

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
- Standard parallel review
- Security reviewer mandatory if bug was in auth/data handling
- If REQUEST CHANGES: iterate (max 2 rounds)

### Step 5: User Journey QA (optional)
- Same trigger conditions as workflow-build-one
- Additionally triggered if the bug was user-reported (not CI/automated)

### Step 6: Finalize (workflow-finalize)
- PR description references the original bug report/issue
- Includes link to diagnosis artifact in PR body
- Issue disposition: Fixes #N

## Contract

Consumes: bug report (issue, user description, or watch-ci handoff artifact), codebase
Produces: verified fix with regression test, merged PR, diagnosis artifact
Requires: gh, git, project test runner
Side effects: creates branch, commits, PR; creates diagnosis artifact file
Human gates: needs-human/unsafe-for-afk routing halts; architecture-review redirects; review iteration limit halts

## Context

Typical workflows: standalone (primary debug workflow)
Pairs well with: diagnose (mandatory first step), tdd (preferred fix approach), workflow-review, workflow-finalize
