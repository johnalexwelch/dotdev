---
name: workflow-feature
description: Turn an ambiguous feature idea into ready-to-triage issues (stops before implementation)
---

# Workflow Feature

## Purpose

Transform a vague feature idea into well-defined, triaged issues ready for implementation. This workflow is the "thinking" phase — it explicitly stops before any code is written.

## When to invoke

- User has a feature idea but hasn't defined it clearly
- User says "I want to build..." or "what if we..."
- Product requirements need elaboration before work can begin
- workflow-router classifies work as "ambiguous feature"

## Flow

```
grill-with-docs → to-prd → to-issues → triage
```

### Step 1: Grill (grill-with-docs)

- Interview the user about the feature idea
- Resolve ambiguities, identify constraints, clarify scope
- Update CONTEXT.md with new domain terms if discovered
- Create ADRs for significant architectural decisions
- Output: shared understanding of what to build

### Step 2: PRD (to-prd)

- Convert grilling output into a structured PRD
- Publish to issue tracker as a reference document
- Include: goal, non-goals, user stories, acceptance criteria, risks
- Output: PRD issue on GitHub

### Step 3: Issues (to-issues)

- Break PRD into vertical slices (tracer bullets)
- Each slice is independently implementable and verifiable
- Include dependency order and blocking relationships
- Output: child issues under the PRD

### Step 4: Triage (triage)

- Classify each issue: ready-for-agent vs needs-human
- Apply labels, estimate complexity, assign priority
- Flag issues that need additional context before an agent can grab them
- Output: triaged issues with appropriate labels

## Stop gate

**This workflow STOPS after triage.** It does not proceed to implementation. The output is a set of ready-for-agent issues that workflow-build-one or run-backlog can pick up later.

If the user wants to immediately proceed to building, they should invoke workflow-build-one on a specific issue after this workflow completes.

## Contract

Consumes: ambiguous feature idea (user description, conversation context)
Produces: PRD issue, child implementation issues (triaged, labeled, dependency-ordered)
Requires: gh
Side effects: creates GitHub issues and labels
Human gates: Step 1 (grilling requires user participation); Step 4 (triage decisions presented for approval)

## Context

Typical workflows: standalone (entry point for new features)
Pairs well with: workflow-build-one (picks up where this stops), run-backlog (batch execution of produced issues)
