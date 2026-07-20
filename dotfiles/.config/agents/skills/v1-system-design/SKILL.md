---
name: v1-system-design
model: opus
reasoning: high
description: Designs a technical system to support an approved V1 product brief. Called by v1-workflow as Step 3 — invoke directly only when you explicitly want just this step in isolation (you already have an approved V1_IDEA_BRIEF). For full V1 work (idea → design → issues), use v1-workflow instead.
---

# V1 System Design

## Effort

**Think hard** before proposing structure — system-design decisions are expensive to reverse. Favor reasoning depth over speed.

## Contract

Consumes: approved `V1_IDEA_BRIEF`, decision log, repo context when building in an existing codebase, constraints
Produces: `V1_SYSTEM_DESIGN` with modules, interfaces, data, integrations, risks, rollout, and implementation slices
Requires: git when inspecting an existing repo
Side effects: none by default; may create PRDs/issues only when the user explicitly asks to continue
Human gates: missing or unapproved V1 brief halts; high-risk architecture decisions require user approval

## Context

Typical workflows: technical design after V1 idea discovery
Pairs well with: decision-log, grill-with-docs, improve-codebase-architecture, to-prd, to-issues, workflow-autonomous-backlog

## Purpose

Turn an approved non-technical V1 brief into a system design that can be implemented safely. The design should support the V1 promise without overbuilding V2 architecture.

## Process

### 1. Validate input

Require an approved `V1_IDEA_BRIEF`. If it is missing, incomplete, or not approved, halt and run `grill-with-docs` in V1 product discovery mode.

Read the decision log entries produced by that grill. If the brief has accepted recommendations but no decision-log entries, reconstruct them before technical design.

### 2. Inspect context

If designing for an existing repo:

- Read product/domain context and ADRs when present.
- Explore only the areas relevant to the V1 brief.
- Use `improve-codebase-architecture` when the design depends on existing module seams.

If designing greenfield, state assumptions and avoid pretending repo evidence exists.

### 3. Design from behavior backward

Map the V1 user flow to system responsibilities:

- user actions and system responses
- state/data that must exist
- external integrations
- permissions and trust boundaries
- background or async work
- observability and support needs
- failure modes and rollback

### 4. Define modules

For each proposed Module include:

- responsibility
- Interface callers need to know
- Implementation hidden behind the Interface
- seams and adapters
- data owned or touched
- tests at the Interface
- rollout and rollback risk

Prefer fewer deep Modules over many shallow pass-through Modules. Apply the deletion test before naming a Module.

### 5. Produce the design

Return this artifact:

```markdown
V1_SYSTEM_DESIGN:
  source_brief:
  design_summary:
  decision_log_entries:
  user_flow_to_system_flow:
  modules:
    - name:
      responsibility:
      interface:
      implementation:
      seams_adapters:
      data:
      tests:
      rollout_rollback:
  integrations:
  data_model:
  security_privacy_trust:
  observability:
  risks_and_human_gates:
  implementation_slices:
  verification_plan:
  explicit_non_goals:
  recommended_next_step: to-prd|to-issues|prototype|needs-human
```

## Rules

- Every technical decision must trace back to the V1 brief.
- Do not add platform, scaling, or abstraction work that the V1 brief does not need.
- Mark public API, data model, auth/payment, infrastructure, or irreversible rollout decisions as human gates.
- Do not implement code from this skill. Hand off to `to-prd`, `to-issues`, `prototype`, or `workflow-autonomous-backlog`.
