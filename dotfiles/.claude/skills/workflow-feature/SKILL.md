---
name: workflow-feature
model: sonnet
reasoning: high
description: Turn an ambiguous feature idea into ready-to-triage issues (stops before implementation)
---

# Workflow Feature

## Purpose

Transform a vague feature idea into well-defined, triaged issues ready for implementation. This workflow is the "thinking" phase — it explicitly stops before any code is written.

All implementation issues produced by this workflow must be vertical slices of app behavior. Do not produce horizontal layer tickets such as database-only, API-only, UI-only, or tests-only work unless the ticket is independently demoable or system-verifiable.

## When to invoke

- User has a feature idea but hasn't defined it clearly
- User says "I want to build..." or "what if we..."
- Product requirements need elaboration before work can begin
- workflow-router classifies work as "ambiguous feature"

## Flow

```
Load and run `grill-with-docs` → follow `decision-log` → [prototype] → Load and run `workflow-roadmap` (approval gate) → Load and run `to-prd` → Load and run `to-issues` → Load and run `triage`
                                                         ^optional^
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


### Step 1: Grill

Load and run `grill-with-docs/SKILL.md` to:

- Interview the user about the feature idea
- Resolve ambiguities, identify constraints, clarify scope
- Capture every accepted grill answer in the decision log
- Update CONTEXT.md with new domain terms if discovered
- Create ADRs for significant architectural decisions
- Output: shared understanding of what to build plus decision-log entries

### Step 1.5: Prototype (optional)

Load and run `prototype/SKILL.md` when grilling surfaces a question that reasoning alone cannot answer:

- "Does this state model handle the case where X then Y?" → logic branch
- "What should this look like?" → UI branch
- "I need to feel out the API shape before committing" → logic branch

Skip when the grilling output is clear enough to write a PRD directly.

The prototype's *answer* (not the code) feeds into the PRD. Capture the answer in a NOTES.md or ADR before proceeding.

### Step 1.9: Design-doc gate (HARD-GATE)

**Do NOT proceed to PRD until a design is presented and the user approves it.**

Before writing the PRD, synthesize the grilling output (and prototype answer, if any) into a concise design summary:

1. **What we're building** — one paragraph
2. **Approach** — the chosen approach with trade-offs (from the grill)
3. **Key decisions** — decision-log entries, ADRs created, constraints accepted
4. **Scope boundary** — explicit non-goals
5. **Success criteria** — how we'll know it works

Present this to the user and get explicit approval. If the user pushes back, return to grilling (Step 1) — do not proceed to PRD with unresolved questions.

If grilling happened before the decision-log requirement existed, reconstruct `docs/decision-log.md` from accepted answers before this gate. Do not proceed with only an ephemeral chat summary.

This gate applies to every feature regardless of perceived simplicity. "Simple" features are where unexamined assumptions cause the most wasted work.

### Step 1.95: Roadmap gate (HARD-GATE)

**Do NOT proceed to PRD/issue creation until there is an approved roadmap artifact.**

Load and run `workflow-roadmap/SKILL.md` (or confirm an equivalent current roadmap exists) and capture:

- roadmap artifact path (`docs/roadmaps/YYYY-MM-DD-<topic>-roadmap.md`)
- explicit user approval evidence
- milestone sequencing relevant to this feature
- identified vertical-slice path for the first implementation slice

If no roadmap exists, create one and stop for approval. If one exists but is stale or lacks the target vertical slice, update it and re-approve before continuing.

### Step 2: PRD

Load and run `to-prd/SKILL.md` to:

- Convert grilling output into a structured PRD
- Publish to issue tracker as a reference document
- Include: goal, non-goals, user stories, acceptance criteria, risks
- State how the work can be split into vertical slices; if it cannot, return to design before issue creation
- Output: PRD issue on GitHub

### Step 3: Issues

Load and run `to-issues/SKILL.md` to:

- Break PRD into vertical slices (tracer bullets)
- Each slice is independently implementable and verifiable across the relevant layers of the app
- Reject horizontal breakdowns and rewrite them as thin end-to-end behaviors before publishing
- Include dependency order and blocking relationships
- Output: child issues under the PRD

### Step 4: Triage

Load and run `triage/SKILL.md` to:

- Classify each issue: ready-for-agent vs needs-human
- Apply labels, estimate complexity, assign priority
- Flag issues that need additional context before an agent can grab them
- Output: triaged issues with appropriate labels

## Stop gate

**This workflow STOPS after triage.** It does not proceed to implementation. The output is a set of ready-for-agent issues that workflow-build-one or run-backlog can pick up later.

If the user wants to immediately proceed to building, they should invoke workflow-build-one on a specific issue after this workflow completes.

## Worktree Policy

This workflow is planning/issue creation only and does not cut a code worktree. Every child issue it produces must state that implementation workflows start from a fresh worktree cut from `origin/staging`.

## Contract

Consumes: ambiguous feature idea (user description, conversation context)
Produces: PRD issue, child implementation issues (triaged, labeled, dependency-ordered)
Requires: gh
Side effects: creates GitHub issues and labels
Human gates: Step 1 grilling requires user participation; Step 1.9 design approval blocks PRD creation; Step 1.95 roadmap approval blocks PRD/issue creation; Step 4 triage decisions presented for approval

## Context

Typical workflows: standalone (entry point for new features)
Pairs well with: workflow-build-one (picks up where this stops), run-backlog (batch execution of produced issues), workflow-autonomous-backlog (module discovery through AFK handoff), prototype (optional exploration between grilling and PRD)
