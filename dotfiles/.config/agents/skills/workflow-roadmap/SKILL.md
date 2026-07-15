---
name: workflow-roadmap
model: opus
reasoning: high
description: Use when creating a product and implementation roadmap from product goals, repo state, feature gaps, implementation gaps, architecture/infrastructure gaps, security hardening needs, or "what should we build next?" questions.
---

# Workflow Roadmap

## Purpose

Create an evidence-backed roadmap that connects product direction to implementation order. This workflow researches feature gaps, implementation gaps, architecture, infrastructure, security, reliability, hardening, and workflow readiness before recommending what to build next.

This is a discovery and sequencing workflow. It does not create issues, write implementation plans, or modify code until the roadmap is approved.

Development roadmap items must lead toward vertical slices of app behavior. Do not recommend horizontal sequencing such as "build all data models," "then all APIs," "then all UI" unless those are explicitly reframed into independently verifiable end-to-end slices.

## Contract

Consumes: product goals, repo state, decision log, existing PRDs/issues, audits, ADRs, `CONTEXT.md`
Produces: roadmap artifact with milestones, evidence, dependencies, risks, hardening work, and next workflow per item
Requires: git, gh
Side effects: writes a roadmap artifact only after user approval
Human gates: roadmap approval before creating PRDs, issues, implementation plans, or backlog runs

## Context

Typical workflows: strategic planning before `workflow-feature`, `to-prd`, `design-plan`, `to-issues`, or `workflow-autonomous-backlog`
Pairs well with: repo-audit, improve-codebase-architecture, decision-log, grill-with-docs, prototype, security-reviewer, to-prd, design-plan, to-issues

## When To Use

Use when:

- The user asks for a roadmap, sequencing, milestones, or "what should we build next?"
- A product area needs deep discovery before PRDs or implementation plans.
- Feature work, infrastructure, security, reliability, and hardening need to be ordered together.
- Existing issues or PRDs feel like a pile rather than a coherent plan.
- The repo may have hidden implementation gaps, incomplete features, or hardening debt.

Do not use when:

- There is one clear ready-for-agent issue.
- The task is a narrow bug fix.
- The user has an approved implementation plan and wants execution.
- The user only wants a repo health audit; use `repo-audit`.
- The user only wants module deepening opportunities; use `improve-codebase-architecture`.

## Flow

```text
goals/context
  -> research lanes
  -> evidence synthesis
  -> roadmap milestones
  -> human approval
  -> to-prd / design-plan / to-issues / prototype / needs-human
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

## Research Lanes

Run the lanes that fit the request. For broad roadmap work, dispatch read-only subagents in parallel and require evidence, not vibes.

### 1. Product And Feature Gaps

Look for:

- missing user flows
- incomplete or inconsistent capabilities
- unclear V1/V2 boundaries
- missing empty, loading, error, permission, and recovery states
- user journeys implied by docs but absent from code
- feature requests or TODOs not represented in issues

### 2. Implementation Gaps

Look for:

- partially implemented features
- TODOs, dead paths, unused abstractions, and placeholder code
- missing vertical slices across UI/API/data/tests
- critical behavior without tests
- migrations or data changes started but not completed
- issue acceptance criteria not reflected in code

### 3. Architecture And Infrastructure

Use `improve-codebase-architecture` as the architecture lens when module quality matters.

Look for:

- shallow modules, fake seams, and over-coupled callers
- unclear data ownership and public interfaces
- CI/CD, deploy, environment, and rollback gaps
- observability and operational support gaps
- monorepo or service boundaries that obscure ownership

### 4. Security And Hardening

Use `security-reviewer` or a dedicated security pass when risk is meaningful.

Look for:

- authentication and authorization gaps
- secrets/config handling problems
- input validation and unsafe parsing
- dependency or supply-chain risks
- abuse, spam, fraud, rate-limit, and tenant-isolation concerns
- missing audit logs or privileged-action safeguards

### 5. Reliability And Operations

Look for:

- background job failure modes
- retries, idempotency, and duplicate processing risks
- migration safety and rollback paths
- monitoring, alerting, and support diagnostics
- failure handling for third-party integrations
- data recovery and manual remediation paths

### 6. Docs And Workflow Readiness

Look for:

- stale or missing ADRs
- missing `docs/decision-log.md` entries for settled choices
- unclear `CONTEXT.md` domain language
- PRDs without issue breakdowns
- issues not ready for AFK execution
- missing handoffs, verification commands, or cleanup policy

## Synthesis Rules

Every roadmap item must include:

- **Evidence:** file paths, issue refs, audit findings, or explicit user input.
- **User or operational value:** why it matters.
- **Work type:** feature, implementation gap, architecture, infrastructure, security, reliability, docs/process.
- **Dependency relationship:** what must happen before it.
- **Risk:** low, medium, high, or needs-human.
- **Confidence:** high, medium, low.
- **Accepted tradeoffs:** relevant `decision-log` entries or "none found."
- **Vertical slice path:** the first end-to-end behavior this item should make real, or why the item is not yet ready for PRD/issues.
- **Recommended next workflow:** exactly one of:
  - `prototype`
  - `grill-with-docs`
  - `to-prd`
  - `design-plan` (only for refactor-scale, migration, or multi-phase remediation that cannot yet be expressed as vertical issue slices)
  - `to-issues`
  - `repo-audit`
  - `improve-codebase-architecture`
  - `workflow-autonomous-backlog`
  - `needs-human`
- **Backlog transition plan:** whether this item needs a PRD parent, can go
  directly to issue breakdown, has expected child dependencies, and should route
  next to `to-prd`, `to-issues`, `design-plan`, or `needs-human`.

Do not bury risk. If a roadmap item changes product behavior, public interfaces, data model, auth/payment behavior, infrastructure, rollout strategy, or security posture, mark a human gate.

## Roadmap Artifact

**One canonical roadmap per scope.** Default path:

```text
docs/roadmap.md
```

Never create a dated roadmap sibling (`docs/roadmaps/YYYY-MM-DD-*.md`) — that is how roadmaps fork and rot. A genuinely separate topic gets `docs/roadmaps/<topic>.md` (no date). When a roadmap is superseded, move it to `docs/roadmaps/archive/` with a banner; update the canonical, do not spawn a new file. Where a repo ships the check, `python3 scripts/chorus/validate.py roadmap` fails on a competing/dated file.

Roadmaps are **capability-altitude and ordered by dependency**, not status trackers. Group items into **Now / Next / Later** bands; order falls out of each item's `depends on`. New idea → append an item with its deps; do not renumber.

Use this structure:

```markdown
# Roadmap: {topic}

## Executive Summary

## Inputs And Scope

## Decision Context
- Relevant decision-log entries
- ADRs or product decisions that constrain the roadmap

## Current State

## Feature Gaps

## Implementation Gaps

## Architecture And Infrastructure Gaps

## Security And Hardening Gaps

## Reliability And Operations Gaps

## Capability Roadmap (Now / Next / Later)

### Now

#### {capability}
Outcome (what exists when done):
Unlocks (what becomes possible next):
Effort: S | M | L | XL
Priority: P0 | P1 | P2
Depends on: {other capabilities, or —}
Feature work:
Implementation work:
Architecture/infrastructure work:
Security/hardening work:
Risks:
Verification:
Recommended next workflows:
Backlog transition plan:

### Next

#### {capability}
...

### Later

#### {capability}
...

> `unlocks` is a scope gut-check: if a capability's unlock is thin, it is probably mis-scoped or mis-ordered.
> `priority` is value/urgency and is independent of order — a P0 can still wait on a dependency; a P2 can jump if it unblocks others.

## Dependency Map

## Human Gates

## Not Doing Yet

## Recommended Next Actions
```

## Approval Gate

Before creating PRDs, issues, design plans, or autonomous backlog work:

1. Present the roadmap summary, milestones, top risks, and recommended next actions.
2. Ask for explicit approval or edits.
3. Record accepted roadmap decisions in `docs/decision-log.md`.
4. Only then invoke the downstream workflow for the approved next step.

## Anti-Patterns

- Do not restate execution state (issue status, board progress, agent state, per-issue rollups) in the roadmap. That is what drifts. Order by `depends on`; status lives in GitHub issues + the workboard. The roadmap holds capabilities, not their current build status.
- Do not create a dated or per-run roadmap file. One canonical roadmap per scope; archive superseded versions to `docs/roadmaps/archive/`.
- Do not turn every finding into a roadmap item. Sequence only the work that advances the stated outcome.
- Do not create an infrastructure-first roadmap unless infrastructure is a real blocker.
- Do not treat security/hardening as a final cleanup phase when it affects architecture or product trust.
- Do not dispatch implementation agents from this workflow.
- Do not re-run `repo-audit` wholesale when a scoped research lane is enough.
