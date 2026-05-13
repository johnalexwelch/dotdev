---
name: workflow-build-one
description: Implement one ready-for-agent issue end-to-end (preflight → execute → review → ship)
---

# Workflow Build One

## Purpose

Take a single `ready-for-agent` issue and drive it from implementation through delivery. This is the standard "build one thing" workflow — the workhorse for individual issue execution.

## When to invoke

- workflow-router classifies work as "ready issue"
- User points at a specific issue and says "build this"
- run-backlog dispatches individual issue execution
- Issue has `ready-for-agent` label and clear acceptance criteria

## Flow

```
preflight → triage → execute-phase → workflow-review → [optional] user-journey-qa → workflow-finalize
```

### Step 0: Preflight
- Read the issue body and acceptance criteria
- Check `Requires` from target skills' contracts (are tools available?)
- If missing tools: halt with clear message about what's needed
- If issue is unclear: halt and ask for clarification (don't guess)

### Step 1: Triage (quick)
- Confirm issue is well-formed for autonomous execution
- Verify: clear acceptance criteria, no ambiguous requirements, no human-only decisions
- If not AFK-safe: halt with explanation of what needs human input

### Step 2: Execute (execute-phase)
- Create feature branch from main
- Implement against acceptance criteria
- Use appropriate execution profile (normal by default, strict-tdd for bugs)
- Commit incrementally with issue references

### Step 3: Review (workflow-review)
- Dispatch parallel reviewers on the diff
- If APPROVE: proceed to finalize
- If REQUEST CHANGES: iterate (max 2 rounds, then halt for human)
- If NEEDS HUMAN: halt with review findings

### Step 4: User Journey QA (optional)
Trigger when ANY of these are true:
- Issue touches frontend code
- Issue modifies user-facing behavior
- Issue changes auth, navigation, or payment flows
- Issue body mentions UX acceptance criteria

Skip when the change is purely backend/infrastructure/tooling.

### Step 5: Finalize (workflow-finalize)
- Generate PR description with issue disposition
- Monitor CI
- Reconcile issues
- Enable auto-merge

## Iteration limits

- Review iterations: max 2 before halting for human
- CI fix attempts: max 3 (inherited from watch-ci)
- Total workflow time: no hard limit, but emit progress updates every 10 minutes

## Contract

Consumes: GitHub issue (ready-for-agent, with acceptance criteria), codebase
Produces: merged PR (or ready-to-merge PR), updated issue state
Requires: gh, git, project build/test tools
Side effects: creates branch, commits, PR; may modify issue labels
Human gates: unclear issue halts; NEEDS HUMAN review halts; CI exhaustion halts; review iteration limit halts

## Context

Typical workflows: standalone (primary build workflow), run-backlog (dispatched per-issue)
Pairs well with: workflow-router (routes here), workflow-review, workflow-finalize, execute-phase
