# Execution Reflection: Root-Cause Fixes for Workflow Skipping

**Date**: 2026-08-21
**PR**: #207 (merged at 71d51f5)
**Issue**: 2026-08-20 incident — three sessions bypassed all workflow gates

## What Was Fixed

### Root Cause 1: Delegation Collapse

**Problem**: Orchestrator treated "spin up sub-agents for X" as literal instruction, not routing trigger.
**Fix**: Team-budget work MUST delegate via taskflow — orchestrator prohibited from direct implementation.

### Root Cause 2: Turn-Boundary Violation

**Problem**: Agent committed without approval, treating prior approval of analysis as approval for implementation.
**Fix**: `validate-turn-boundary.sh` state-machine detects approval→commit patterns; pre-commit hook enforces routing evidence.

### Root Cause 3: Approval Bypass

**Problem**: User "yes" interpreted as blanket authorization instead of input to routing.
**Fix**: Explicit prohibition: user approval is INPUT to routing, never a bypass. Pre-commit checks require ROUTE_CARD marker.

## How It Was Fixed

### 1. TDD-First Approach

Tests written before implementation:

- `test-delegation-enforcement.sh` (4 cases)
- `test-turn-boundary.sh` (9 cases via `validate-turn-boundary.sh`)
- Golden route expansions for imperative phrasing

### 2. Implementation

- **Ambient habit** (docs/agents/habits.md) — fires before any skill loads
- **Imperative Trigger Patterns** (workflow-router/SKILL.md) — catches "spin up sub-agents" at classification
- **Pre-Dispatch Self-Check** (workflow-router/SKILL.md) — catches missing ROUTE_CARD before mutating actions
- **Routing Prerequisite sections** added to 5 orchestrator skills
- **Pre-commit hooks** hardened in both `.githooks/` and `dotfiles/.config/git/hooks/`

### 3. Review

`workflow-review` APPROVED with two P2 observations (golden routes sparse, validator post-hoc only) — neither blocking.

## Defense Layers Now in Place

```
Layer 0: Ambient Habit (docs/agents/habits.md)
         ↓ always loaded, catches before any skill
Layer 1: Imperative Trigger Patterns (workflow-router)
         ↓ catches "spin up sub-agents" at classification
Layer 2: Pre-Dispatch Self-Check (workflow-router)
         ↓ catches missing ROUTE_CARD before mutating actions
Layer 3: Routing Prerequisite (5 orchestrator skills)
         ↓ catches direct skill load without routing
Layer 4: Pre-commit hooks (.githooks/ + dotfiles hooks)
         ↓ catches commit without routing evidence
Layer 5: Golden Routes Eval (CI)
         ↓ catches regression in classification
```

## Lessons Learned

1. **TDD delegation worked well**: Subagent wrote tests first → clear acceptance criteria → implementation followed naturally. Same pattern should be default for behavior fixes.

2. **Multiple defense layers required**: Single gate (router classification) insufficient. Post-incident pattern: ambient habit (L0) + skill-level checks (L1-3) + mechanical enforcement (L4-5).

3. **Imperative phrasing ≠ literal instruction**: "Spin up sub-agents" describes WHAT, not HOW. Router determines how. This must be explicit in agent instructions.

4. **Same-session re-occurrence is diagnostic gold**: After adding L1-4, immediate commit attempt without routing proved skill-level guards insufficient → led to L0 ambient habit.

## Test Results

```
test-bypass-tripwires.sh:     26/26 passed
test-delegation-enforcement.sh: 4/4 passed
test-env-validation.sh:        6/6 passed
```

## Evidence

- PR: <https://github.com/alexwelch/dotdev/pull/207>
- Merge commit: 71d51f5
- Review: `.pi/plans/2026-08-21-workflow-router-207/review.md` (APPROVED)
- Postmortem: `docs/executions/reflections/2026-08-20-workflow-router-bypass-via-imperative-phrasing.md`
