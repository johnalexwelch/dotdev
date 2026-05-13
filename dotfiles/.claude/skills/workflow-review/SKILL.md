---
name: workflow-review
description: Dispatch parallel specialist reviewers and synthesize into actionable findings
---

# Workflow Review

## Purpose

Run multiple specialist reviews in parallel, then synthesize findings into a prioritized action list. This replaces ad-hoc "review this" with structured multi-perspective analysis.

## When to invoke

- Before merging any PR
- After execute-phase completes
- When workflow-build-one or workflow-debug reaches the review gate
- Explicitly by user ("review this", "review my changes")

## Reviewers

Dispatch these in parallel (each gets the same diff/changeset):

| Reviewer | Focus | Skip when |
|----------|-------|-----------|
| **Correctness** | Logic errors, off-by-ones, null handling, race conditions, edge cases | Never skip |
| **Architecture** | Coupling, cohesion, abstraction levels, dependency direction, module boundaries | Changes < 20 lines AND single file |
| **Test quality** | Coverage gaps, brittle tests, missing edge cases, test-implementation coupling | No test files changed AND no behavior changed |
| **Security & privacy** | Auth bypass, injection, data exposure, secrets, OWASP Top 10 | No user input handling AND no auth/data changes |
| **Maintainability** | Naming, complexity, documentation, readability, future-proofing | Never skip |
| **Frontend** | Accessibility, responsive behavior, UX consistency, component patterns | No frontend files changed AND no UX behavior changed |

## Process

### 1. Prepare context

- Gather the diff (staged, committed, or PR)
- Identify which files changed and their types
- Determine which reviewers to activate (see "Skip when" column)

### 2. Dispatch reviewers

- Launch each active reviewer as a parallel subagent (via OMC executor or direct dispatch)
- Each reviewer receives: the diff, relevant file contents, CONTEXT.md if present
- Each reviewer returns: list of findings with severity and confidence

### 3. Synthesize

Merge all reviewer outputs. Deduplicate overlapping findings. Prioritize:

```markdown
## Review Synthesis

### Must-fix (blocks merge)
- [Critical bugs, security issues, data loss risks]

### Should-fix (merge OK, follow-up needed)
- [Architecture concerns, test gaps, maintainability issues]

### Acceptable risks (acknowledged, no action needed)
- [Trade-offs, known limitations, intentional shortcuts]

### Human gate required
- [Decisions that need human judgment — ambiguous requirements, business logic, UX choices]
```

### 4. Verdict

- **APPROVE**: No must-fix items
- **REQUEST CHANGES**: Has must-fix items
- **NEEDS HUMAN**: Has human-gate items that block the decision

## Rules

- Only report findings the original author would agree need fixing
- No style nits unless they affect readability significantly
- Confidence threshold: only include findings with >70% confidence
- If a finding contradicts an ADR, the ADR wins — note it but don't flag it

## Contract

Consumes: diff/changeset, file contents, CONTEXT.md, ADRs
Produces: review synthesis (markdown) with verdict (APPROVE/REQUEST CHANGES/NEEDS HUMAN)
Requires: git
Side effects: none
Human gates: NEEDS HUMAN verdict halts workflow until human responds

## Context

Typical workflows: workflow-build-one, workflow-debug, workflow-finalize
Pairs well with: execute-phase, describe-pr, user-journey-qa
