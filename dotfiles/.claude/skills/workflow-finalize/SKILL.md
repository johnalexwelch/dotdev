---
name: workflow-finalize
description: Universal delivery closure after review passes (PR → CI → reconcile → optional retro)
---

# Workflow Finalize

## Purpose

Close the delivery loop after workflow-review approves. Handles PR creation/description, CI monitoring, issue reconciliation, and optional retrospective. Does not duplicate review or testing logic.

## When to invoke

- workflow-review returns APPROVE verdict
- After any successful implementation + review cycle
- Explicitly when work is done and needs to ship

## Precondition

workflow-review must have returned APPROVE. If it hasn't run or returned REQUEST CHANGES / NEEDS HUMAN, halt and direct back to review.

## Flow

```
describe-pr → watch-ci → reconcile-issues → [optional] post-mortem
```

### Step 1: Describe PR (describe-pr)
- Generate PR description with issue awareness
- Include disposition table for all referenced issues
- Push branch and open PR (or update existing)

### Step 2: Watch CI (watch-ci)
- Monitor GitHub Actions
- Auto-fix up to 3 attempts on failure
- If exhausted: halt with handoff artifact for diagnose
- If green: proceed

### Step 3: Reconcile Issues (reconcile-issues)
- Check referenced issues against PR dispositions
- Verify labels are consistent
- Flag any drift before merge
- If drift found: report but don't block (info-level)

### Step 4: Post-mortem (optional)
- Triggered when:
  - CI required auto-fixes (something unexpected happened)
  - Implementation deviated significantly from plan
  - Execution spanned multiple phases
- Skipped for routine single-issue work

## Completion

When all steps pass:
- Enable auto-merge on the PR (if repo supports it)
- Report final status to user

## Contract

Consumes: approved review verdict, committed code on branch, issue references
Produces: merged PR (or ready-to-merge PR with auto-merge enabled), reconciliation report
Requires: gh, git
Side effects: creates/updates PR, pushes commits (CI fixes), may enable auto-merge
Human gates: CI exhaustion halts for diagnose; post-mortem presented for review

## Context

Typical workflows: workflow-build-one (final step), workflow-debug (final step)
Pairs well with: workflow-review (precondition), describe-pr, watch-ci, reconcile-issues, post-mortem
